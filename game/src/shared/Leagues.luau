--!strict
-- Leagues and careers (D-013, D-046). Pure rules on horse records, tested under Lune.
--   Each horse climbs Rookie → Bronze → Silver → Gold → Champion. League Points from races
--   unlock its league's Cup race (D-013 thresholds); a Cup win promotes the horse and
--   starts its points again in the new league. No demotion.
--   A Cup race pays 3B to the winner (other places as usual).
--   Over-strong horses: once a horse's best Rating passes its league's ceiling, its Cup
--   opens at once and that league's regular cash races close to it (Practice stays open), so
--   a fully trained horse can't farm the Rookies.
--   Retiring is always the player's choice: a Legend (D-059) keeps its stats in the Hall of Fame
--   paddock, and a plaque keeps its career record.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")

local Leagues = {}

Leagues.ORDER = { "Rookie", "Bronze", "Silver", "Gold", "Champion" }
Leagues.UNLOCK = GameConfig.stakesUnlockPoints -- the D-013 Stakes race points
Leagues.CEILING = GameConfig.leagueCeiling      -- best base Rating that closes regular races
Leagues.CUP_PURSE = GameConfig.cupPurseB        -- × B for the winner
Leagues.MAX_PLAQUES = 50

function Leagues.next(league: string): string?
	local i = table.find(Leagues.ORDER, league)
	return if i and i < #Leagues.ORDER then Leagues.ORDER[i + 1] else nil
end

-- Points still needed for the Cup (0 when it's open); nil in the top league.
function Leagues.pointsToCup(h: any): number?
	local need = Leagues.UNLOCK[h.league]
	if not need then return nil end
	return math.max(0, need - (h.points or 0))
end

function Leagues.overCeiling(h: any, bestRating: number): boolean
	local ceiling = Leagues.CEILING[h.league]
	return ceiling ~= nil and bestRating > ceiling
end

-- Can this horse race in its league's Cup?
function Leagues.cupOpen(h: any, bestRating: number): boolean
	if not Leagues.next(h.league) then return false end
	return Leagues.pointsToCup(h) == 0 or Leagues.overCeiling(h, bestRating)
end

-- Can this horse enter a race card? (card = { league, cup, practice })
function Leagues.canEnter(h: any, card: any, bestRating: number): (boolean, string?)
	if h.legend ~= nil then return false, h.name .. " is a Legend now. Ride for fun!" end -- D-059
	if card.league and card.league ~= h.league then
		return false, string.format("That race is for %s horses. %s is %s.", card.league, h.name, h.league)
	end
	if card.practice then return true, nil end
	if card.cup then
		if Leagues.cupOpen(h, bestRating) then return true, nil end
		return false, string.format("%s needs %d more League Points for the Cup", h.name, Leagues.pointsToCup(h) or 0)
	end
	if Leagues.overCeiling(h, bestRating) then
		return false, string.format("%s is too good for %s now. Win the Cup!", h.name, h.league)
	end
	return true, nil
end

-- A Cup win: up a league, points start again. Returns the new league or nil.
function Leagues.promote(h: any): string?
	local nxt = Leagues.next(h.league)
	if not nxt then return nil end
	h.league = nxt
	h.points = 0
	return nxt
end

-- Why a horse can't retire (or be rehomed, D-059) right now, or nil (D-065): never one that's
-- racing, queued, ridden or on a training ride. `busy` is the owner's state: racing, inLine (any
-- horse), racingHorse, ridingHorse (the horse ids from the player's attributes) and trainingRide.
-- `verb` is "Retire" (the default) or "Rehome".
function Leagues.retireBlock(name: string, id: string, busy: any, verb: string?): string?
	local v = verb or "Retire"
	if busy.racing or busy.inLine or busy.racingHorse == id then return v .. " after your race!" end
	if busy.trainingRide and (busy.ridingHorse == nil or busy.ridingHorse == id) then
		return string.format("%s is on a training ride. %s after it!", name, v)
	end
	if busy.ridingHorse == id then return string.format("You can't %s %s while riding. Hop off first!", string.lower(v), name) end
	return nil
end

-- Legend Retirement (D-059, stage 7): the player's choice, for a Veteran (career.veteranAt races,
-- unless career.retireNeedsVeteran is off). The horse stays yours: it moves to the Hall of Fame
-- paddock, keeps its stats and can still be ridden, and its stall goes to the first pasture horse
-- (the other stalls never shift). A plaque keeps its record. Your last racing horse stays racing.
-- Returns (plaque, nil) or (nil, why).
function Leagues.retire(p: any, id: string, now: number): (any, string?)
	local Profile = if script then require(script.Parent.Profile) :: any else require("./Profile")
	local Career = if script then require(script.Parent.Career) :: any else require("./Career")
	local h = Profile.horse(p, id)
	if not h then return nil, "No such horse" end
	if h.legend ~= nil then return nil, h.name .. " is already a Legend!" end
	if not Career.canBeLegend(h) then
		return nil, string.format("Legends need %d races. Keep going!", GameConfig.career.veteranAt)
	end
	if Profile.racers(p) <= 1 then return nil, "Keep one horse racing with you!" end
	h.legend = now
	h.legendAsked = true
	h.stall = nil
	Profile.fillStalls(p)
	Profile.fixActive(p)
	if typeof(p.hallOfFame) ~= "table" then p.hallOfFame = {} end
	local plaque = {
		name = h.name, coat = h.coat, league = h.league, races = h.record.races, wins = h.record.wins,
		places = h.record.places, cash = h.record.cash, cups = h.record.cups or 0, retired = now,
		legend = true, horseId = h.id,
	}
	table.insert(p.hallOfFame, 1, plaque)
	while #p.hallOfFame > Leagues.MAX_PLAQUES do table.remove(p.hallOfFame) end
	return plaque, nil
end

-- The one-time Legend suggestion was shown (either answer): never shown again for this horse.
function Leagues.markAsked(p: any, id: string): boolean
	for _, h in p.horses do
		if h.id == id then
			h.legendAsked = true
			return true
		end
	end
	return false
end

return Leagues
