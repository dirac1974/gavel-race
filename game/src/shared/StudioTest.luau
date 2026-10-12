--!strict
-- Studio test block (playtest 2026-10-12): puts the active horse into a long-horizon state on join, so
-- ageing, the legs run and the vet, the class path and the Cup bar can be seen without racing hundreds
-- of times. Applied by Profiles on profile load ONLY when RunService:IsStudio() is true (the caller
-- passes it as `isStudio`); a live server never applies it. Everything in GameConfig.studioTest is off
-- by default (0 / false). It writes the real save fields, so the cards show the real states:
--   horseRaces    h.record.races                  (Ageing: Veteran at ageing.veteranAt)
--   horseWins     h.record.wins, h.leagueWins[h.league] (ClassPath steps, Top Horse at classes.topWins)
--   nearPotential each stat raised to ageing.peakShare of its Potential (decline waits for this)
--   legsRun       h.legs.run, h.legs.raceAt = now   (Legs: chip at warnAt, VET CHECK at runLimit)
--   leaguePoints  h.points                          (the Cup bar: points / stakesUnlockPoints[league])
--   legsFromRaces GameConfig.legs.fromRaces on this server (false = keep the real value)
--   breedReady    (D-080) two parents ready: the active horse and a second (added if needed) at
--                 breeding.minParentRaces races, the active one in breeding.needLeague; cash >= the
--                 needLeague fee; p.breeding.nextAt cleared; a foal on the way arrives at once

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")
local Ageing = if script then require(script.Parent.Ageing) :: any else require("./Ageing")
local Legs = if script then require(script.Parent.Legs) :: any else require("./Legs")
local Leagues = if script then require(script.Parent.Leagues) :: any else require("./Leagues")
local Horse = if script then require(script.Parent.Horse) :: any else require("./Horse")

local StudioTest = {}

StudioTest.KEYS = { "horseRaces", "horseWins", "nearPotential", "legsRun", "leaguePoints", "legsFromRaces", "breedReady" }

local function count(x: any): number?
	local n = tonumber(x)
	if n == nil or n ~= n or n <= 0 or n >= 1e9 then return nil end
	return math.floor(n)
end

-- Is anything switched on?
function StudioTest.active(cfg: any?): boolean
	local c = cfg or GameConfig.studioTest
	if typeof(c) ~= "table" then return false end
	return count(c.horseRaces) ~= nil or count(c.horseWins) ~= nil or c.nearPotential == true
		or count(c.legsRun) ~= nil or count(c.leaguePoints) ~= nil or typeof(c.legsFromRaces) == "number" or c.breedReady == true
end

-- (D-080) Two horses ready to be parents, the fee in hand, no wait.
local function breedReady(data: any, h: any, now: number, lines: { string })
	local B = GameConfig.breeding
	local need = B.minParentRaces
	local order = Leagues.ORDER or { "Rookie", "Bronze", "Silver", "Gold", "Champion" }
	local function atLeast(league: any): boolean
		return (table.find(order, league) or 1) >= (table.find(order, B.needLeague) or 2)
	end
	h.record.races = math.max(h.record.races, need)
	if not atLeast(h.league) then h.league = B.needLeague end
	local other = nil
	for _, o in data.horses do
		if o ~= h and o.lent == nil then other = o break end
	end
	if not other and #data.horses < B.stableCap - 1 then
		local id = "h" .. (tonumber(data.nextHorseId) or (#data.horses + 1))
		data.nextHorseId = (tonumber(data.nextHorseId) or (#data.horses + 1)) + 1
		local s = Horse.STARTER_STAT
		other = Horse.new(id, "Maple", "grey", { speed = s, accel = s, stamina = s, grit = s },
			{ speed = 78, accel = 78, stamina = 78, grit = 78 }, now)
		other.origin, other.paid = "gift", 0
		Legs.ensure(other)
		Ageing.ensure(other)
		table.insert(data.horses, other) -- in the pasture (no stall): parents need none
		table.insert(lines, "added Maple (grey) as the second parent")
	end
	if other then other.record.races = math.max(other.record.races, need) end
	local fee = B.fee[B.needLeague] or 0
	data.cash = math.max(tonumber(data.cash) or 0, fee)
	if typeof(data.breeding) == "table" then
		data.breeding.nextAt = nil
		for _, e in (if typeof(data.breeding.pending) == "table" then data.breeding.pending else {}) do e.atRaces = 0 end
	end
	table.insert(lines, string.format("breedReady: %s and %s at %d races, cash %d", h.name, other and other.name or "?", need, data.cash))
end

-- Apply the block to profile `data` (Profile shape) at `now`. Returns the log lines (empty when off or
-- not in Studio). `activeHorse` finds the horse (Profile.activeHorse; passed in to keep this module free
-- of Profile).
function StudioTest.apply(data: any, now: number, isStudio: boolean, activeHorse: (any) -> any?, cfg: any?): { string }
	local c = cfg or GameConfig.studioTest
	local lines: { string } = {}
	if not isStudio or not StudioTest.active(c) then return lines end
	if typeof(c.legsFromRaces) == "number" then
		GameConfig.legs.fromRaces = math.max(0, math.floor(c.legsFromRaces))
		table.insert(lines, "legs.fromRaces = " .. GameConfig.legs.fromRaces)
	end
	local h = data and activeHorse(data)
	if not h then
		table.insert(lines, "no active horse yet: pick one, then Stop and Play again")
		return lines
	end
	local races, wins = count(c.horseRaces), count(c.horseWins)
	if races then
		h.record.races = races
		table.insert(lines, "races = " .. races)
	end
	if wins then
		h.record.wins = wins
		h.record.races = math.max(h.record.races, wins)
		h.record.places = math.max(tonumber(h.record.places) or 0, wins)
		Leagues.wins(h)[h.league or "Rookie"] = wins
		table.insert(lines, string.format("wins = %d (in %s)", wins, h.league or "Rookie"))
	end
	if c.nearPotential == true then
		local share = GameConfig.ageing.peakShare
		for _, k in Ageing.STATS do
			local pot = tonumber(h.potential[k]) or 0
			if pot > 0 then h.stats[k] = math.max(tonumber(h.stats[k]) or 0, math.min(pot, math.ceil(pot * share))) end
		end
		table.insert(lines, string.format("stats at %.0f%% of Potential", Ageing.peakShare(h.stats, h.potential) * 100))
	end
	if races or wins or c.nearPotential == true then
		local from = Ageing.note(h) -- the real rule: declineFrom once a Veteran at its peak
		table.insert(lines, "ageing: " .. Ageing.stage(h.record.races, h.legend ~= nil) .. ", declineFrom = " .. tostring(from))
	end
	local run = count(c.legsRun)
	if run then
		local l = Legs.ensure(h)
		l.run, l.raceAt = math.min(run, 1000), now -- raceAt = now, or the rest rule clears the run
		table.insert(lines, "legs run = " .. l.run)
	end
	if c.breedReady == true then breedReady(data, h, now, lines) end
	local points = count(c.leaguePoints)
	if points then
		h.points = points
		table.insert(lines, string.format("League Points = %d (Cup at %s)", points, tostring(Leagues.UNLOCK[h.league or "Rookie"])))
	end
	return lines
end

return StudioTest
