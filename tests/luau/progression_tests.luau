--!strict
-- AAA Phase 3 (D-068): progression and friends. Open Practice across leagues (one "Open" Practice
-- queue), Legend Retirement undone (Leagues.unretire), no Legend suggestion until breeding, the
-- last racing horse never retires, and the core-playtest switch.
local Horse = require("../../game/src/shared/Horse")
local Profile = require("../../game/src/shared/Profile")
local Leagues = require("../../game/src/shared/Leagues")
local Career = require("../../game/src/shared/Career")
local RaceQueues = require("../../game/src/shared/RaceQueues")
local RaceSession = require("../../game/src/shared/RaceSession")
local RaceMath = require("../../src/RaceMath")
local GameConfig = require("../../game/src/shared/GameConfig")
local fs = require("@lune/fs")

local DAY = 86400
local T0 = 20000 * DAY + 3600
local STATS = { speed = 50, accel = 50, stamina = 50, grit = 50 }
local POT = { speed = 80, accel = 80, stamina = 80, grit = 80 }
local LANES = GameConfig.lanes
local ORDER = { "dirt", "turf" }

local function rngOf(seed: number)
	local s = seed
	return {
		NextInteger = function(_self, lo: number, hi: number): number
			s = (s * 1103515245 + 12345) % 2147483648
			return lo + math.floor((hi - lo + 1) * s / 2147483648)
		end,
	}
end

local function stable(n: number)
	local p = Profile.new(T0)
	p.flags.starterPicked = true
	Profile.addHorse(p, Horse.starter(Profile.newHorseId(p), "Comet", "bay", rngOf(3), T0))
	for k = 1, n do
		local h = Horse.new(Profile.newHorseId(p), "Horse" .. k, "grey", STATS, POT, T0)
		h.origin, h.paid = "market", 400
		Profile.addHorse(p, h)
	end
	return p
end

local function claim(c: any, league: string, kind: string)
	c.card.league, c.card.cup, c.card.practice = league, kind == "cup", kind == "practice"
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Open Practice --------------------------------------------------------------------------------
	do
		check(GameConfig.queue.openPractice == true and Leagues.openPractice(), "queue.openPractice is on")
		local rookie = Horse.new("r", "Rookie One", "bay", STATS, POT, T0)
		local bronze = Horse.new("b", "Bronze One", "grey", STATS, POT, T0)
		rookie.league, bronze.league = "Rookie", "Bronze"
		check(Leagues.canEnter(bronze, { league = "Rookie", practice = true }, 50), "a Bronze horse joins a Rookie Practice")
		check(Leagues.canEnter(rookie, { league = "Gold", practice = true }, 50), "a Rookie horse joins a Gold Practice")
		check(not Leagues.canEnter(bronze, { league = "Rookie" }, 50), "cash races still keep leagues apart")
		check(not Leagues.canEnter(bronze, { league = "Rookie", cup = true }, 50), "and Cups too")
		bronze.legend = T0
		check(not Leagues.canEnter(bronze, { league = "Bronze", practice = true }, 50), "a Legend still doesn't race, Practice included")
		bronze.legend = nil

		local key = RaceQueues.key("Bronze", "practice")
		check(key == "Open|practice" and RaceQueues.key("Gold", "practice") == key, "one Practice queue for every league")
		check(RaceQueues.key("Bronze", "race") == "Bronze|race" and RaceQueues.key("Bronze", "cup") == "Bronze|cup",
			"races and Cups keep a queue per league")
		check(RaceQueues.cardKey({ league = "Silver", practice = true }) == key, "a Practice card of any league serves the Open queue")

		-- Friends in Gold and Rookie wait together; the card is always claimed at openPracticeLeague.
		local s = RaceQueues.new()
		local courses = {
			dirt = { id = "dirt", card = { league = "Bronze", cup = false, practice = false }, queue = { "b1" }, current = nil },
			turf = { id = "turf", card = { league = nil, cup = false, practice = false }, queue = {}, current = nil },
		}
		check(GameConfig.queue.openPracticeLeague == "Rookie" and RaceQueues.claimLeague("Gold", "practice") == "Rookie"
			and RaceQueues.claimLeague("Gold", "race") == "Gold", "Open Practice runs at Rookie settings; races at their own league")
		RaceQueues.join(s, "goldFriend", "Gold", "practice", 1)
		RaceQueues.join(s, "rookieFriend", "Rookie", "practice", 2)
		check(RaceQueues.waitingWith(s, "goldFriend") == 2, "friends in different leagues share the Practice line")
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(courses.turf.queue[1] == "goldFriend" and courses.turf.queue[2] == "rookieFriend", "both go to the same course")
		check(courses.turf.card.practice and courses.turf.card.league == "Rookie", "a Gold rider first still gets a Rookie card")
		check(#courses.dirt.queue == 1, "the Bronze race card is untouched")
		-- A later Silver rider asking for the friends' course gets it.
		RaceQueues.join(s, "silverFriend", "Silver", "practice", 3, "turf")
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(courses.turf.queue[3] == "silverFriend", "a rider who asks for a friend's Practice course joins it")

		-- Race with a friend while alone in line (code review B1): the rider leaves course 1 and joins
		-- the friend's Practice on course 2 (RaceService.joinQueue with `follow`).
		do
			local s2 = RaceQueues.new()
			local cs = {
				dirt = { id = "dirt", card = { league = "Bronze", cup = false, practice = true }, queue = { "me" }, current = nil },
				turf = { id = "turf", card = { league = "Rookie", cup = false, practice = true }, queue = { "friend" }, current = nil },
			}
			check(RaceQueues.canTake(cs.turf, RaceQueues.key("Bronze", "practice"), LANES), "the friend's Practice course can take me")
			table.remove(cs.dirt.queue, 1) -- leaveLine
			RaceQueues.join(s2, "me", "Bronze", "practice", 5, "turf")
			RaceQueues.pump(s2, cs, ORDER, LANES, claim)
			check(cs.turf.queue[2] == "me" and #cs.dirt.queue == 0, "alone on course 1 -> the friend's course 2")
			local src = fs.readFile("game/src/server/RaceService.server.luau")
			local follow = string.find(src, "leaveLine(player) -- follow the friend", 1, true)
			local shortcut = string.find(src, "if RaceQueues.cardKey(c.card) == key then", 1, true)
			check(follow ~= nil and shortcut ~= nil and follow < shortcut, "joinQueue follows the friend before its same-card and alone shortcuts")
		end

		-- Practice with equal horses: every lane the same Rating, base chance 1/8, draws untouched.
		do
			check(GameConfig.queue.practiceEqualHorses == true, "queue.practiceEqualHorses is on")
			local lanes = {}
			for k, r in { 47, 75, 32, 35.5, 29, 38, 30, 34 } do lanes[k] = { id = tostring(k), rating = r } end
			RaceSession.equalizeRatings(lanes)
			local ratings = {}
			for k, l in lanes do ratings[k] = l.rating end
			local q = RaceMath.baseChances(ratings, { T = 22, qFloor = GameConfig.qFloor, kappa = 1, rFloor = GameConfig.rFloor })
			local equal = true
			for _, x in q do equal = equal and math.abs(x - 1 / 8) < 1e-12 end
			check(equal and lanes[1].id == "1", "equal horses: every base chance is 1/8")
		end

		-- Switched off: Practice is per league again (D-061).
		GameConfig.queue.openPractice = false
		check(RaceQueues.key("Bronze", "practice") == "Bronze|practice", "openPractice = false: a Practice queue per league")
		check(not Leagues.canEnter(bronze, { league = "Rookie", practice = true }, 50), "openPractice = false: own league's Practice only")
		check(Leagues.canEnter(bronze, { league = "Bronze", practice = true }, 50), "openPractice = false: own Practice still open")
		GameConfig.queue.openPractice = true
	end

	-- Legend Retirement can be undone ----------------------------------------------------------
	do
		local p = stable(2)
		p.stalls = 2
		Profile.repairStalls(p)
		local starter, a, b = p.horses[1], p.horses[2], p.horses[3]
		check(starter.stall ~= nil and a.stall ~= nil and b.stall == nil, "two stalls, one horse in the pasture")
		a.record.races, a.record.wins, a.points, a.league = 360, 20, 70, "Silver"
		local plaque = Leagues.retire(p, a.id, T0)
		check(plaque ~= nil and a.legend == T0 and b.stall ~= nil, "a Veteran retires; the pasture horse takes its stall")
		check(#p.hallOfFame == 1, "one plaque")

		check(not select(1, Leagues.unretire(p, starter.id)), "a racing horse can't be brought back")
		check(not select(1, Leagues.unretire(p, "nope")), "only your horses")
		for label, busy in { racing = { racing = true }, queued = { inLine = true }, riding = { ridingHorse = a.id },
			training = { trainingRide = true } } do
			local ok, why = Leagues.unretire(p, a.id, busy)
			check(not ok and why ~= nil and a.legend ~= nil, "busy: not now (" .. label .. ")")
		end
		local ok, why = Leagues.unretire(p, a.id, {})
		check(ok and why == nil and a.legend == nil, "back to the races")
		check(a.league == "Silver" and a.points == 70 and a.record.races == 360 and a.record.wins == 20,
			"same league, points and record")
		check(a.stall == nil and Profile.racers(p) == 3, "a full barn: it waits in the pasture, racing again")
		check(#p.hallOfFame == 0, "its Legend plaque comes down")
		check(Leagues.canEnter(a, { league = "Silver" }, 50), "it can enter its league's races")
		check(not Career.suggestLegend(a), "never suggested again")
		-- With a free stall it moves straight in.
		Leagues.retire(p, a.id, T0)
		p.stalls = 3
		Leagues.unretire(p, a.id, {})
		check(a.stall == 3 and Profile.isStalled(p, a.id), "a free stall: straight in")
		Leagues.retire(p, a.id, T0 + 1)
		Leagues.unretire(p, a.id, {})
		Leagues.retire(p, a.id, T0 + 2)
		check(#p.hallOfFame == 1 and p.hallOfFame[1].retired == T0 + 2, "retiring again: one plaque, the new one")
	end

	-- The last racing horse (the starter when it's alone) never retires -----------------------------
	do
		local solo = stable(0)
		solo.horses[1].record.races = 400
		local pl, why = Leagues.retire(solo, solo.horses[1].id, T0)
		check(pl == nil and why ~= nil and solo.horses[1].legend == nil, "the starter, your only racer, can't retire")
	end

	-- No Legend suggestion until breeding; careers off means no Legends ----------------------------
	do
		check(GameConfig.career.suggest == false, "career.suggest = false")
		local h = Horse.new("v", "Vet", "bay", STATS, POT, T0)
		h.record.races = 400
		check(not Career.suggestLegend(h) and Career.canBeLegend(h), "a Veteran isn't asked, but can still choose Legend")
		GameConfig.career.enabled = false
		check(not Career.canBeLegend(h), "career.enabled = false: no Legend button")
		local v = Career.view(h)
		check(v.line == "" and v.toNextBadge == nil, "career.enabled = false: no career row")
		local p = stable(1)
		p.horses[2].record.races = 400
		local pl, why = Leagues.retire(p, p.horses[2].id, T0)
		check(pl == nil and why == "Legends are resting today!", "careers off: the right reason, not 'needs 350 races'")
		GameConfig.career.enabled = true
	end

	-- Core-playtest switch -------------------------------------------------------------------------
	do
		check(GameConfig.corePlaytest == false, "corePlaytest is off by default")
		check(GameConfig.spa.enabled and GameConfig.visit.enabled and GameConfig.career.enabled and GameConfig.rehome.enabled
			and GameConfig.comeback.photo and GameConfig.comeback.horseBook, "every meta feature on by default")
		check(#GameConfig.applyCorePlaytest(GameConfig) == 0, "off: the helper changes nothing")
		local cfg: any = { corePlaytest = true }
		for _, path in GameConfig.CORE_PLAYTEST_OFF do
			cfg[path[1]] = table.clone((GameConfig :: any)[path[1]])
		end
		local off = GameConfig.applyCorePlaytest(cfg)
		check(#off == 6, "on: six flags switched off")
		check(not cfg.spa.enabled and not cfg.visit.enabled and not cfg.career.enabled and not cfg.rehome.enabled
			and cfg.comeback.photo == false and cfg.comeback.horseBook == false, "Spa, visits, careers, rehoming, Photo Finish, Horse Book off")
		check(cfg.comeback.welcome ~= nil and cfg.comeback.welcome.enabled, "everything else is left alone")
		check(GameConfig.spa.enabled and GameConfig.comeback.photo, "the live config is untouched")
	end
end
