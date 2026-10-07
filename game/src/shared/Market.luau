--!strict
-- More horses (D-037): the Market Corral, taming wild horses on the Trail, and stalls.
-- Pure rules on a Profile, tested under Lune.
--   Market: a weekly stock seeded by the week (the same on every server), personal to each
--   player (buying one never takes it from anyone else: no "only 2 left"). Coats are separate
--   from stats, so collecting is never a chase for power; price follows Potential, shown as a
--   🌱 family-line hint until the vet reveals the numbers. Green Cash only, never Robux.
--   Taming: wild horses in the meadow carry natural rare coats. Offer a treat and win their
--   trust in a gentle rhythm game; one new friend a day.
--   Stalls: start with 2; Green Cash builds more, up to 6. Extra horses live in the free
--   pasture (they can't race until stalled). At most MAX_HORSES in all.

local Horse = if script then require(script.Parent.Horse) :: any else require("./Horse")
local Profile = if script then require(script.Parent.Profile) :: any else require("./Profile")

local Market = {}

Market.MAX_HORSES = 20
Market.STALL_PRICES = { [3] = 300, [4] = 800, [5] = 2000, [6] = 4000 } -- price of the Nth stall
Market.STOCK_SIZE = 5
Market.WILD_COATS = { "pinto", "appaloosa", "buckskin", "dun", "roan", "white" }
Market.MARKET_COATS = { "bay", "chestnut", "grey", "black", "palomino", "chestnut_blaze", "pinto", "dun", "roan" }
Market.TAME_TREATS = { "treat", "apple", "carrot" }
Market.STYLES = { "FrontRunner", "Stalker", "Closer" }

local function week(now: number): number
	return (now // 86400 + 3) // 7
end
Market.week = week

local function lcg(seed: number)
	local s = seed % 2147483647
	if s <= 0 then s += 2147483646 end
	local rng = {}
	function rng:NextNumber(): number
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
	function rng:NextInteger(lo: number, hi: number): number
		return lo + math.floor(self:NextNumber() * (hi - lo + 1))
	end
	return rng
end
Market.lcg = lcg

-- Bloodline level 1..3 from average Potential (shown as sprouts, not stars: D-064).
function Market.stars(potential: { [string]: number }): number
	local sum = 0
	for _, k in Horse.STATS do sum += potential[k] end
	local avg = sum / #Horse.STATS
	return if avg >= 84 then 3 elseif avg >= 76 then 2 else 1
end

-- The family line on a market card (D-064: 🌱 = good family line): "Family 🌱🌱".
Market.FAMILY_ICON, Market.FAMILY_EMOJI = "sprout", "🌱"
function Market.familyLine(level: number): string
	local n = math.clamp(math.floor(tonumber(level) or 1), 1, 3)
	return "Family " .. string.rep(Market.FAMILY_EMOJI, n)
end

function Market.price(h: any): number
	local potSum, statSum = 0, 0
	for _, k in Horse.STATS do
		potSum += h.potential[k]
		statSum += h.stats[k]
	end
	-- 250 for a plain young horse, rising steeply with bloodline, a little with current stats.
	local avgPot, avgStat = potSum / 4, statSum / 4
	local p = 250 + math.max(0, avgPot - 65) ^ 2 * 2.2 + math.max(0, avgStat - 40) * 12
	return math.floor(p / 10 + 0.5) * 10
end

-- This week's stock: listings with id, name, coat, style, stats, potential, price, stars.
function Market.stock(now: number): { any }
	local w = week(now)
	local rng = lcg(w * 7919 + 17)
	local NameGen = if script then require(script.Parent.NameGen) :: any else require("./NameGen")
	local out = {}
	for k = 1, Market.STOCK_SIZE do
		local coat = Market.MARKET_COATS[rng:NextInteger(1, #Market.MARKET_COATS)]
		local stats, potential = {}, {}
		local tier = rng:NextNumber()
		local potLo = if tier > 0.85 then 82 elseif tier > 0.5 then 72 else 62
		local potHi = if tier > 0.85 then 95 elseif tier > 0.5 then 86 else 78
		for _, s in Horse.STATS do
			stats[s] = rng:NextInteger(40, 52)
			potential[s] = math.max(stats[s] + 5, rng:NextInteger(potLo, potHi))
		end
		local first = NameGen.FIRST[rng:NextInteger(1, #NameGen.FIRST)]
		local second = NameGen.SECOND[rng:NextInteger(1, #NameGen.SECOND)]
		local listing = {
			id = string.format("m%d_%d", w, k),
			name = NameGen.build(first, second) or first,
			coat = coat,
			style = Market.STYLES[rng:NextInteger(1, #Market.STYLES)],
			stats = stats,
			potential = potential,
		}
		listing.price = Market.price(listing)
		listing.stars = Market.stars(potential)
		table.insert(out, listing)
	end
	return out
end

-- What a client may see about a listing (Potential only as stars).
function Market.viewListing(l: any, bought: boolean): { [string]: any }
	return { id = l.id, name = l.name, coat = l.coat, style = l.style, stats = table.clone(l.stats), price = l.price, stars = l.stars, bought = bought }
end

local function ensure(p: any)
	if typeof(p.market) ~= "table" then p.market = {} end
	p.market.bought = if typeof(p.market.bought) == "table" then p.market.bought else {}
	p.market.tameDay = tonumber(p.market.tameDay) or -1
end
Market.ensure = ensure

function Market.canAddHorse(p: any): boolean
	return #p.horses < Market.MAX_HORSES
end

-- Buy listing `id` from this week's stock. Returns (ok, message, horse?).
function Market.buy(p: any, id: string, now: number): (boolean, string, any)
	ensure(p)
	local listing = nil
	for _, l in Market.stock(now) do
		if l.id == id then listing = l end
	end
	if not listing then return false, "That horse has gone home. The market restocks every week!", nil end
	if p.market.bought[id] then return false, listing.name .. " already lives with you!", nil end
	if not Market.canAddHorse(p) then return false, "Your stable is full of friends!", nil end
	if not Profile.spendCash(p, listing.price) then return false, "Not enough Green Cash yet. Races, chores and jobs earn more!", nil end
	local h = Horse.new(Profile.newHorseId(p), listing.name, listing.coat, listing.stats, listing.potential, now)
	h.style = listing.style
	h.origin, h.paid = "market", listing.price -- what rehoming pays half of (D-059)
	Profile.addHorse(p, h)
	p.market.bought[id] = true
	-- keep the record small: forget purchases from old weeks
	for key in p.market.bought do
		local wk = tonumber(string.match(key, "^m(%d+)_"))
		if wk and wk < week(now) - 1 then p.market.bought[key] = nil end
	end
	local where = if Profile.isStalled(p, h.id) then "in a stall" else "in the pasture"
	return true, string.format("Welcome home, %s! (%s)", h.name, where), h
end

-- Wild horses wander the meadow from a shared seed and the server clock, so every client and
-- the server agree where each one is. Horse i has coat WILD_COATS[i].
Market.WILD_LEG = 14 -- seconds per wander leg: graze for the first half, walk the second

local function wildPoint(meadow: any, i: number, n: number): (number, number)
	local rng = lcg(i * 1013 + n * 7907 + 5)
	local a, r = rng:NextNumber() * math.pi * 2, math.sqrt(rng:NextNumber()) * (meadow.radius - 14)
	return meadow.x + math.cos(a) * r, meadow.z + math.sin(a) * r
end

-- Position of wild horse i at time t: (x, z, dirX, dirZ, walking 0..1).
function Market.wildPosition(meadow: any, i: number, t: number): (number, number, number, number, number)
	local tt = t / Market.WILD_LEG + i * 0.37
	local n = math.floor(tt)
	local f = tt - n
	local walk = math.clamp((f - 0.5) * 2, 0, 1)
	local eased = walk * walk * (3 - 2 * walk)
	local ax, az = wildPoint(meadow, i, n)
	local bx, bz = wildPoint(meadow, i, n + 1)
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	if len > 0.1 then dx, dz = dx / len, dz / len else dx, dz = 0, -1 end
	return ax + (bx - ax) * eased, az + (bz - az) * eased, dx, dz, walk
end

-- Taming --------------------------------------------------------------------------
function Market.canTame(p: any, now: number): (boolean, string?)
	ensure(p)
	if p.market.tameDay == now // 86400 then return false, "You made a new friend today. Come back tomorrow!" end
	if not Market.canAddHorse(p) then return false, "Your stable is full of friends!" end
	for _, item in Market.TAME_TREATS do
		if Profile.itemCount(p, item) > 0 then return true, nil end
	end
	return false, "Bring a carrot, apple or sugar cube to make friends"
end

-- A successful taming: uses a treat; the new horse has a natural rare coat and surprise
-- Potential. `coat` is the wild horse's coat; `rng` has NextInteger.
function Market.tame(p: any, coat: string, rng: any, now: number): (boolean, string, any)
	local ok, why = Market.canTame(p, now)
	if not ok then return false, why :: string, nil end
	if not table.find(Market.WILD_COATS, coat) then coat = Market.WILD_COATS[1] end
	for _, item in Market.TAME_TREATS do
		if Profile.takeItem(p, item, 1) then break end
	end
	local NameGen = if script then require(script.Parent.NameGen) :: any else require("./NameGen")
	local stats, potential = {}, {}
	for _, s in Horse.STATS do
		stats[s] = rng:NextInteger(35, 48)
		potential[s] = math.max(stats[s] + 5, rng:NextInteger(60, 95))
	end
	local name = NameGen.build(NameGen.FIRST[rng:NextInteger(1, #NameGen.FIRST)], NameGen.SECOND[rng:NextInteger(1, #NameGen.SECOND)]) or "Wildflower"
	local h = Horse.new(Profile.newHorseId(p), name, coat, stats, potential, now)
	h.style = Market.STYLES[rng:NextInteger(1, #Market.STYLES)]
	h.origin, h.paid = "tamed", 0
	Profile.addHorse(p, h)
	p.market.tameDay = now // 86400
	return true, string.format("%s trusts you now and is coming home!", h.name), h
end

-- Stalls --------------------------------------------------------------------------
function Market.nextStallPrice(p: any): number?
	return Market.STALL_PRICES[p.stalls + 1]
end

function Market.buyStall(p: any): (boolean, string)
	local price = Market.nextStallPrice(p)
	if not price then return false, "Your barn is as big as it gets!" end
	if not Profile.spendCash(p, price) then return false, string.format("A new stall costs %d Green Cash", price) end
	p.stalls += 1
	Profile.fillStalls(p) -- the first pasture horse moves in
	Profile.fixActive(p)
	return true, string.format("New stall built! You have %d stalls now", p.stalls)
end

-- Rehoming (D-059, stage 7) ------------------------------------------------------------
-- At the Market Corral a horse can join Sunny Meadow Riding School. The school pays rehome.share
-- of what you paid for it (h.paid), never more and never the market price, so buying and rehoming
-- always costs Green Cash; tamed and gifted horses pay 0 and give a goodbye rosette (once per
-- horse). For rehome.undoHours it can come back at the same price, with its name and stats.
local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")

function Market.rehomeValue(h: any): number
	local paid = math.max(0, math.floor(tonumber(h.paid) or 0))
	return math.min(paid, math.floor(paid * GameConfig.rehome.share))
end

-- Why this horse can't be rehomed, or nil. `busy` as Leagues.retireBlock.
function Market.rehomeBlock(p: any, id: string, busy: any?, now: number?): string?
	local Leagues = if script then require(script.Parent.Leagues) :: any else require("./Leagues")
	if not GameConfig.rehome.enabled then return "The riding school is closed today" end
	local h = Profile.horse(p, id)
	if not h then return "No such horse" end
	if h.origin == "starter" then return h.name .. " was your first horse. Friends forever!" end
	if h.legend ~= nil then return h.name .. " is a Legend and lives with you!" end
	if Profile.racers(p) <= 1 then return "Keep one horse racing with you!" end
	local waiting = 0
	for _, e in (if typeof(p.rehomed) == "table" then p.rehomed else {}) do
		if now == nil or now < e.expires then waiting += 1 end
	end
	if waiting >= GameConfig.rehome.maxWaiting then return "The riding school is full. Try again soon!" end
	return Leagues.retireBlock(h.name, id, busy or {}, "Rehome")
end

-- Horses whose undo window has closed leave for good.
function Market.pruneRehomed(p: any, now: number)
	if typeof(p.rehomed) ~= "table" then p.rehomed = {} end
	for i = #p.rehomed, 1, -1 do
		if now >= p.rehomed[i].expires then table.remove(p.rehomed, i) end
	end
end

-- Rehome a horse. Returns (ok, message, entry): entry = { horse, cash, rosette, at, expires }.
-- The cash is not counted as earned (totals.cashEarned), so it never moves a job along.
function Market.rehome(p: any, id: string, now: number, busy: any?): (boolean, string, any)
	Market.pruneRehomed(p, now)
	local why = Market.rehomeBlock(p, id, busy, now)
	if why then return false, why, nil end
	local h = Profile.removeHorse(p, id)
	if not h then return false, "No such horse", nil end
	local cash = Market.rehomeValue(h)
	p.cash += cash
	local rosette = false
	if cash == 0 and not h.goodbyeRosette then
		h.goodbyeRosette, rosette = true, true
		p.goodbyeRosettes = (tonumber(p.goodbyeRosettes) or 0) + 1
	end
	local entry = { horse = h, cash = cash, at = now, expires = now + GameConfig.rehome.undoHours * 3600 }
	table.insert(p.rehomed, entry)
	return true, string.format("%s is joining %s!", h.name, GameConfig.rehome.school),
		{ name = h.name, coat = h.coat, id = h.id, cash = cash, rosette = rosette, days = GameConfig.rehome.undoHours // 24 }
end

-- Bring a rehomed horse back within the undo window, at the same price the school paid.
function Market.undoRehome(p: any, id: string, now: number): (boolean, string, any)
	Market.pruneRehomed(p, now)
	local index = nil
	for i, e in p.rehomed do
		if e.horse.id == id then index = i end
	end
	if not index then return false, "That horse has settled in at the school", nil end
	local e = p.rehomed[index]
	if Profile.horse(p, id) then
		table.remove(p.rehomed, index)
		return false, e.horse.name .. " already lives with you!", nil
	end
	if not Market.canAddHorse(p) then return false, "Your stable is full of friends!", nil end
	if p.cash < e.cash then return false, string.format("Bringing %s home needs 💵 %d", e.horse.name, e.cash), nil end
	p.cash -= e.cash
	table.remove(p.rehomed, index)
	local h = e.horse
	h.stall = nil
	Profile.addHorse(p, h)
	return true, string.format("Welcome back, %s!", h.name), h
end

-- Rename with word chips (NameGen), same rules as the starter.
function Market.rename(p: any, id: string, first: string?, second: string?): (boolean, string)
	local NameGen = if script then require(script.Parent.NameGen) :: any else require("./NameGen")
	local h = Profile.horse(p, id)
	if not h then return false, "No such horse" end
	local name = NameGen.build(first, second)
	if not name then return false, "Pick words for the name" end
	h.name = name
	return true, "Hello, " .. name .. "!"
end

return Market
