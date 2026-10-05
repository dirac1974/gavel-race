--!strict
-- Leagues and careers (D-013, D-046). Pure rules on horse records, tested under Lune.
--   Each horse climbs Rookie → Bronze → Silver → Gold → Champion. League Points from races
--   unlock its league's Cup race (D-013 thresholds); a Cup win promotes the horse and
--   starts its points again in the new league. No demotion.
--   A Cup race pays 3B to the winner (other places as usual).
--   Over-strong horses: once a horse's best Rating passes its league's ceiling, its Cup
--   opens at once and that league's regular cash races close to it (Practice stays open), so
--   a fully trained horse can't farm the Rookies.
--   Retiring is always the player's choice: a Hall of Fame plaque keeps the career record.

local Leagues = {}

Leagues.ORDER = { "Rookie", "Bronze", "Silver", "Gold", "Champion" }
Leagues.UNLOCK = { Rookie = 100, Bronze = 110, Silver = 1400, Gold = 3000 } -- GameConfig.stakesUnlockPoints (the D-013 Stakes race points)
Leagues.CEILING = { Rookie = 58, Bronze = 68, Silver = 78, Gold = 88 }      -- best Rating that closes regular races
Leagues.CUP_PURSE = 3                                                   -- × B for the winner
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
	if card.league and card.league ~= h.league then
		return false, string.format("That race is for %s horses. %s is %s.", card.league, h.name, h.league)
	end
	if card.practice then return true, nil end
	if card.cup then
		if Leagues.cupOpen(h, bestRating) then return true, nil end
		return false, string.format("%s needs %d more League Points for the Cup", h.name, Leagues.pointsToCup(h) or 0)
	end
	if Leagues.overCeiling(h, bestRating) then
		return false, string.format("%s is too strong for %s races now. Win the Cup to move up!", h.name, h.league)
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

-- Retire a horse into the Hall of Fame (player's choice). Returns the plaque.
function Leagues.retire(p: any, id: string, now: number): any
	local index = nil
	for i, h in p.horses do
		if h.id == id then index = i end
	end
	if not index then return nil end
	local h = table.remove(p.horses, index)
	if typeof(p.hallOfFame) ~= "table" then p.hallOfFame = {} end
	local plaque = {
		name = h.name, coat = h.coat, league = h.league, races = h.record.races, wins = h.record.wins,
		places = h.record.places, cash = h.record.cash, retired = now,
	}
	table.insert(p.hallOfFame, 1, plaque)
	while #p.hallOfFame > Leagues.MAX_PLAQUES do table.remove(p.hallOfFame) end
	if p.activeHorse == id then p.activeHorse = if p.horses[1] then p.horses[1].id else nil end
	return plaque
end

return Leagues
