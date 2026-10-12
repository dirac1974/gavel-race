--!strict
-- Breeding (D-080 provisional, amends D-047): pure rules on a Profile, tested under Lune. Mirrors
-- src/breeding.py exactly (tests/fixtures/breeding.json, `python tests/test_breeding.py --write`).
--   Numbers: GameConfig.breeding (and career.legacyMax). Randomness only from the rng passed in
--   (rng:NextNumber()), drawn in a fixed order: one per stat in STATS order (Potential noise), then
--   one for the coat. Rounding is floor(x + 0.5).
--   The foal is rolled ONCE, in Breeding.confirm, and stored on p.breeding.pending; arrival only
--   reads it back. There is no reroll: a second confirm is refused while a foal is on the way.
--   Owner races are p.totals.races (counted races). The stable-wide wait between foals
--   (foalEveryRaces from confirm, p.breeding.nextAt) and arrival count them; the only clock is
--   "the next UTC day you play".

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")

local Breeding = {}

Breeding.STATS = { "speed", "accel", "stamina", "grit" }
Breeding.LEAGUES = { "Rookie", "Bronze", "Silver", "Gold", "Champion" }
-- Horse.COATS order: the coat roll walks it
Breeding.COATS = { "bay", "chestnut", "grey", "black", "palomino", "pinto", "appaloosa", "buckskin", "dun", "roan", "white", "chestnut_blaze" }

local function cfgOf(cfg: any?): any
	return cfg or GameConfig.breeding
end

local function legacyMaxOf(legacyMax: number?): number
	return legacyMax or GameConfig.career.legacyMax
end

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function num(x: any, default: number?): number
	local v = tonumber(x)
	if v == nil or v ~= v then return default or 0 end
	return v
end

local function count(n: any): number
	local x = tonumber(n)
	if x == nil or x ~= x or x <= 0 then return 0 end
	return math.floor(math.min(x, 1e9))
end

local function leagueIndex(league: any): number
	return (table.find(Breeding.LEAGUES, league) or 1) - 1
end

local function horseRaces(h: any): number
	return count(if typeof(h.record) == "table" then h.record.races else 0)
end

local function isLegend(h: any): boolean
	return h.legend ~= nil and h.legend ~= false
end

function Breeding.day(now: number): number
	return now // 86400
end

-- Potential ------------------------------------------------------------------------------

function Breeding.bestStat(potential: any): string
	local best = Breeding.STATS[1]
	for i = 2, #Breeding.STATS do
		local k = Breeding.STATS[i]
		if num(potential[k]) > num(potential[best]) then best = k end
	end
	return best
end

-- { stat = bonus }: each Legend parent adds legacyMax to its own best stat; the same best stat
-- twice still gets legacyMax once.
function Breeding.legacy(potA: any, potB: any, legendA: boolean, legendB: boolean, legacyMax: number?): { [string]: number }
	local lm = legacyMaxOf(legacyMax)
	local out = {}
	for _, k in Breeding.STATS do out[k] = 0 end
	if legendA then out[Breeding.bestStat(potA)] = lm end
	if legendB then out[Breeding.bestStat(potB)] = lm end
	return out
end

function Breeding.expectedPotential(potA: any, potB: any, legendA: boolean?, legendB: boolean?, cfg: any?, legacyMax: number?): { [string]: number }
	local c = cfgOf(cfg)
	local bonus = Breeding.legacy(potA, potB, legendA == true, legendB == true, legacyMax)
	local out = {}
	for _, k in Breeding.STATS do
		local mid = c.parentShare * (num(potA[k]) + num(potB[k])) / 2 + (1 - c.parentShare) * c.breedAnchor
		out[k] = math.min(c.potMax, math.max(c.potMin, round(mid) + bonus[k]))
	end
	return out
end

-- One NextNumber per stat, in STATS order.
function Breeding.foalPotential(potA: any, potB: any, legendA: boolean, legendB: boolean, rng: any, cfg: any?, legacyMax: number?): { [string]: number }
	local c = cfgOf(cfg)
	local bonus = Breeding.legacy(potA, potB, legendA, legendB, legacyMax)
	local out = {}
	for _, k in Breeding.STATS do
		local u = rng:NextNumber()
		local mid = c.parentShare * (num(potA[k]) + num(potB[k])) / 2 + (1 - c.parentShare) * c.breedAnchor
		local x = mid + c.noise * (2 * u - 1)
		out[k] = math.min(c.potMax, math.max(c.potMin, round(x) + bonus[k]))
	end
	return out
end

function Breeding.startStats(potential: any, cfg: any?): { [string]: number }
	local c = cfgOf(cfg)
	local out = {}
	for _, k in Breeding.STATS do out[k] = math.min(c.startMax, round(c.startShare * num(potential[k]))) end
	return out
end

-- 1..3 sprouts from mean Potential (Market.stars thresholds).
function Breeding.familyLevel(potential: any, cfg: any?): number
	local c = cfgOf(cfg)
	local sum = 0
	for _, k in Breeding.STATS do sum += num(potential[k]) end
	local avg = sum / #Breeding.STATS
	return if avg >= c.familyLevels[2] then 3 elseif avg >= c.familyLevels[1] then 2 else 1
end

-- Coats ----------------------------------------------------------------------------------

function Breeding.surpriseCoats(coatA: string, coatB: string, cfg: any?): { string }
	local c = cfgOf(cfg)
	local fam = {}
	for _, coat in { coatA, coatB } do
		for _, s in (c.surprise[coat] or {}) do fam[s] = true end
	end
	local out = {}
	for _, coat in Breeding.COATS do
		if fam[coat] and coat ~= coatA and coat ~= coatB then table.insert(out, coat) end -- never a parent's own coat
	end
	return out
end

-- What the card shows before paying, and what the roll uses:
-- { parents = { {coat, chance}, ... } (one row when both share a coat), surprise = { chance, coats },
--   chances = { [coat] = chance } (sums to 1) }.
function Breeding.coatChances(coatA: string, coatB: string, cfg: any?): any
	local c = cfgOf(cfg)
	local each, sur = c.coatParentEach, c.coatSurprise
	local coats = Breeding.surpriseCoats(coatA, coatB, c)
	if #coats == 0 then each, sur = each + sur / 2, 0 end
	local chances = {}
	for _, coat in Breeding.COATS do
		local p = 0
		if coat == coatA then p += each end
		if coat == coatB then p += each end
		if table.find(coats, coat) then p += sur / #coats end
		if p > 0 then chances[coat] = p end
	end
	local parents = if coatA == coatB then { { coatA, each + each } } else { { coatA, each }, { coatB, each } }
	return { parents = parents, surprise = { chance = sur, coats = coats }, chances = chances }
end

function Breeding.rollCoat(chances: { [string]: number }, u: number): string?
	local acc, last = 0, nil
	for _, coat in Breeding.COATS do
		local p = chances[coat] or 0
		if p > 0 then
			acc += p
			last = coat
			if u < acc then return coat end
		end
	end
	return last
end

-- Fees and selling ------------------------------------------------------------------------

-- The fee by the higher parent league, or nil below the first fee league.
function Breeding.fee(leagueA: string?, leagueB: string?, cfg: any?): number?
	local c = cfgOf(cfg)
	local top = Breeding.LEAGUES[math.max(leagueIndex(leagueA), leagueIndex(leagueB)) + 1]
	return c.fee[top]
end

-- A bred horse sells like a Market horse with h.paid = the fee (Market.rehomeValue must accept
-- origin "bred"): rehome.share of it plus the capped record bonus. Always under the fee.
function Breeding.sellValue(paid: any, wins: any, cups: any): number
	local p = math.max(0, math.floor(num(paid)))
	local base = math.min(p, math.floor(p * GameConfig.rehome.share))
	local s = GameConfig.sell
	local bonus = s.perWin * math.max(0, math.floor(num(wins))) + s.perCup * math.max(0, math.floor(num(cups)))
	return base + math.max(0, math.min(s.recordBonusCap, bonus))
end

-- Eligibility -----------------------------------------------------------------------------

local function state(p: any): any
	if typeof(p.breeding) ~= "table" then p.breeding = {} end
	local b = p.breeding
	if typeof(b.pending) ~= "table" then b.pending = {} end
	return b
end
Breeding.state = state

function Breeding.ownerRaces(p: any): number
	return count(if typeof(p.totals) == "table" then p.totals.races else 0)
end

-- Owner races until the stable can start its next foal (0 = now): one foal per foalEveryRaces owner
-- races, counted from confirm, whichever horses are the parents (p.breeding.nextAt).
function Breeding.nextFoalIn(p: any): number
	local at = state(p).nextAt
	if at == nil then return 0 end
	return math.max(0, math.floor(num(at)) - Breeding.ownerRaces(p))
end

-- Kept for callers: the stable-wide wait (the horse no longer matters).
function Breeding.restLeft(p: any, _id: string?): number
	return Breeding.nextFoalIn(p)
end

function Breeding.find(p: any, id: string?): any
	for _, h in (if typeof(p.horses) == "table" then p.horses else {}) do
		if h.id == id then return h end
	end
	return nil
end

function Breeding.busyBlock(h: any, busy: any?): string?
	local b = busy or {}
	if b.racing or b.inLine or b.racingHorse == h.id then return "After your race!" end
	if b.ridingHorse == h.id or (b.trainingRide and b.ridingHorse == nil) then return "Out riding" end
	return nil
end

-- Why this horse can't be a parent now (the greyed reason), or nil.
function Breeding.horseBlock(p: any, h: any, busy: any?, cfg: any?): string?
	local c = cfgOf(cfg)
	if h == nil then return "No such horse" end
	if h.lent ~= nil then return "Lent" end
	if not isLegend(h) and horseRaces(h) < c.minParentRaces then return `Needs {c.minParentRaces} races` end
	return Breeding.busyBlock(h, busy)
end

-- Why these two can't be parents now, or nil. The stable first, then the horses.
function Breeding.pairBlock(p: any, idA: string, idB: string, busy: any?, cfg: any?): string?
	local c = cfgOf(cfg)
	if not c.enabled then return "The Foaling Barn is closed today" end
	local st = state(p)
	if #st.pending >= c.maxWaiting then return "A foal is on the way!" end
	local left = Breeding.nextFoalIn(p)
	if left > 0 then return if left == 1 then "Next foal in 1 race" else `Next foal in {left} races` end
	local horses = if typeof(p.horses) == "table" then #p.horses else 0
	if horses + #st.pending >= c.stableCap then return "Make room first" end
	if idA == idB then return "Pick two different horses" end
	local a, b = Breeding.find(p, idA), Breeding.find(p, idB)
	for k = 1, 2 do
		local h = if k == 1 then a else b -- not `{ a, b }`: a nil hole would skip the missing horse
		local why = Breeding.horseBlock(p, h, busy, c)
		if why then
			if h == nil then return why end
			return `{h.name or "This horse"}: {why}`
		end
	end
	local need = leagueIndex(c.needLeague)
	if math.max(leagueIndex(a.league), leagueIndex(b.league)) < need or Breeding.fee(a.league, b.league, c) == nil then
		return `One parent needs {c.needLeague}`
	end
	return nil
end

-- Confirm and arrival ---------------------------------------------------------------------

-- The card before paying: sprouts, coat chances, fee. No randomness.
function Breeding.preview(p: any, idA: string, idB: string, cfg: any?, legacyMax: number?): any
	local c = cfgOf(cfg)
	local a, b = Breeding.find(p, idA), Breeding.find(p, idB)
	if a == nil or b == nil then return nil end
	local exp = Breeding.expectedPotential(a.potential, b.potential, isLegend(a), isLegend(b), c, legacyMax)
	return { family = Breeding.familyLevel(exp, c), coats = Breeding.coatChances(a.coat, b.coat, c),
		fee = Breeding.fee(a.league, b.league, c), afterRaces = c.foalAfterRaces, newDay = c.foalAfterNewDay }
end

-- Pay the fee and roll the foal once (server only). Returns (ok, message, pending). The pending
-- foal holds everything arrival needs: Potential, start stats, coat, fee, parents, atRaces, day.
function Breeding.confirm(p: any, idA: string, idB: string, now: number, rng: any, busy: any?, cfg: any?, legacyMax: number?): (boolean, string, any)
	local c = cfgOf(cfg)
	local why = Breeding.pairBlock(p, idA, idB, busy, c)
	if why then return false, why, nil end
	local a, b = Breeding.find(p, idA), Breeding.find(p, idB)
	local price = Breeding.fee(a.league, b.league, c) :: number
	if num(p.cash) < price then return false, `A foal needs {price} Green Cash`, nil end
	local pot = Breeding.foalPotential(a.potential, b.potential, isLegend(a), isLegend(b), rng, c, legacyMax)
	local tbl = Breeding.coatChances(a.coat, b.coat, c)
	local coat = Breeding.rollCoat(tbl.chances, rng:NextNumber())
	p.cash = math.floor(num(p.cash)) - price
	local st = state(p)
	local races = Breeding.ownerRaces(p)
	st.nextAt = races + c.foalEveryRaces
	local pending = { parents = { idA, idB }, fee = price, potential = pot, stats = Breeding.startStats(pot, c),
		coat = coat, atRaces = races + c.foalAfterRaces, day = Breeding.day(now) }
	table.insert(st.pending, pending)
	return true, "A foal is on the way! 🍼", pending
end

-- The stored foal on the way (read-only use), or nil.
function Breeding.pending(p: any): any
	return state(p).pending[1]
end

-- After foalAfterRaces owner races, or on a later UTC day (foalAfterNewDay).
function Breeding.ready(pending: any, races: number, now: number, cfg: any?): boolean
	local c = cfgOf(cfg)
	if pending == nil then return false end
	if races >= pending.atRaces then return true end
	return c.foalAfterNewDay == true and Breeding.day(now) > pending.day
end

-- The new horse's record from the stored roll: Young, Rookie, origin "bred", paid = the fee. The
-- server builds it with Horse.new and adds these fields (Horse.ORIGINS must accept "bred").
function Breeding.foalHorse(pending: any, id: string, name: string, now: number, cfg: any?): any
	local c = cfgOf(cfg)
	return {
		id = id, name = name, coat = pending.coat, style = "Stalker",
		stats = table.clone(pending.stats), potential = table.clone(pending.potential), league = "Rookie",
		points = 0, bond = c.bond, record = { races = 0, wins = 0, places = 0, cash = 0, cups = 0 },
		born = now, origin = "bred", parents = table.clone(pending.parents), paid = pending.fee,
	}
end

-- Takes the first ready foal off the pending list and returns its horse record (the server adds it
-- with Profile.addHorse, which finds a stall), or nil when none is ready.
function Breeding.arrive(p: any, id: string, name: string, now: number, cfg: any?): any
	local c = cfgOf(cfg)
	local st = state(p)
	local first = st.pending[1]
	if first == nil or not Breeding.ready(first, Breeding.ownerRaces(p), now, c) then return nil end
	table.remove(st.pending, 1)
	return Breeding.foalHorse(first, id, name, now, c)
end

-- HorseLook size for a Young horse: youngScaleFrom at race 0, 1.0 at ageing.youngRaces.
function Breeding.youngScale(races: any, cfg: any?, youngRaces: number?): number
	local c = cfgOf(cfg)
	local yr = youngRaces or GameConfig.ageing.youngRaces
	local n = count(races)
	if n >= yr then return 1 end
	return c.youngScaleFrom + (1 - c.youngScaleFrom) * n / yr
end

return Breeding
