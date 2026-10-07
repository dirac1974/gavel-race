--!strict
-- Stage 1 of docs/plans/horse-life-and-retention.md (D-065, D-061 core, D-058 label, D-064
-- basics): per-league race queues, decorators that can't block ProfileSync, the Ready / Napping
-- label, no retiring a horse in use, and the dock's size floors.
local RaceQueues = require("../../game/src/shared/RaceQueues")
local Profile = require("../../game/src/shared/Profile")
local Horse = require("../../game/src/shared/Horse")
local Advice = require("../../game/src/shared/Advice")
local Leagues = require("../../game/src/shared/Leagues")
local DockLayout = require("../../game/src/shared/DockLayout")
local GameConfig = require("../../game/src/shared/GameConfig")

local LANES = GameConfig.lanes
local ORDER = { "dirt", "turf" }

local function makeRng(seed0: number)
	local seed = seed0
	local function nextNumber(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	return {
		NextNumber = function(_self, lo: number?, hi: number?): number
			local u = nextNumber()
			if lo and hi then return lo + (hi - lo) * u end
			return u
		end,
		NextInteger = function(_self, lo: number, hi: number): number
			return lo + math.floor(nextNumber() * (hi - lo + 1))
		end,
	}
end

local function course(id: string, league: string?, kind: string?, riders: { string }, racing: boolean)
	return {
		id = id,
		card = { league = league, cup = kind == "cup", practice = kind == "practice" },
		queue = riders,
		current = if racing then {} else nil,
	}
end

local function claim(c: any, league: string, kind: string)
	c.card.league, c.card.cup, c.card.practice = league, kind == "cup", kind == "practice"
end

-- A race starts on a course: its riders leave the line and the next card opens (RaceService).
local function startRace(c: any)
	c.current = {}
	table.clear(c.queue)
	c.card = { league = nil, cup = false, practice = false }
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Lockout (D-061): Bronze holds dirt (filling), a race runs on turf whose next card a Bronze
	-- rider has already taken. A Rookie waits, never gets a Bronze card, then gets dirt as soon as
	-- dirt's race starts and its next card opens.
	do
		local s = RaceQueues.new()
		local courses = {
			dirt = course("dirt", "Bronze", "race", { "bronze1" }, false),
			turf = course("turf", "Bronze", "race", { "bronze2" }, true),
		}
		RaceQueues.join(s, "rookie", "Rookie", "race", 10)
		local moved = RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(moved == 0 and RaceQueues.isWaiting(s, "rookie"), "a Rookie waits while both cards are Bronze")
		check(not table.find(courses.dirt.queue, "rookie") and not table.find(courses.turf.queue, "rookie"),
			"a Rookie is never put on a Bronze card")
		check(RaceQueues.bestCourse(courses, ORDER, RaceQueues.key("Rookie", "race"), LANES) == nil,
			"bestCourse finds no course for the Rookie")
		-- Another Bronze rider joins: straight onto a Bronze card (the fuller one not racing).
		RaceQueues.join(s, "bronze3", "Bronze", "race", 11)
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(table.find(courses.dirt.queue, "bronze3") ~= nil, "a Bronze rider joins the Bronze card that isn't racing")
		-- Dirt's race starts: its next card opens and goes to the waiting Rookie.
		startRace(courses.dirt)
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(not RaceQueues.isWaiting(s, "rookie") and courses.dirt.queue[1] == "rookie", "the Rookie gets the first free course")
		check(courses.dirt.card.league == "Rookie" and not courses.dirt.card.cup and not courses.dirt.card.practice,
			"the free course's card is claimed for Rookie races")
	end

	-- A course whose race is running, with its next card open, takes the Rookie for that next race;
	-- the Bronze course filling up never does.
	do
		local s = RaceQueues.new()
		local courses = {
			dirt = course("dirt", "Bronze", "race", { "b1", "b2" }, false),
			turf = course("turf", nil, nil, {}, true),
		}
		RaceQueues.join(s, "rookie", "Rookie", "race", 5, "dirt") -- picked dirt: only a wish
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(courses.turf.queue[1] == "rookie" and courses.turf.card.league == "Rookie", "a wish for another league's card is ignored")
		check(#courses.dirt.queue == 2, "the Bronze line is untouched")
	end

	-- Two leagues waiting: the longest wait claims the course that frees up; the other keeps waiting.
	do
		local s = RaceQueues.new()
		local courses = {
			dirt = course("dirt", "Bronze", "race", { "b1" }, true),
			turf = course("turf", "Silver", "cup", { "s1" }, true),
		}
		RaceQueues.join(s, "gold1", "Gold", "race", 20)
		RaceQueues.join(s, "rookie1", "Rookie", "race", 12)
		RaceQueues.join(s, "rookie2", "Rookie", "race", 25)
		check(RaceQueues.pump(s, courses, ORDER, LANES, claim) == 0, "nobody moves while every card is claimed")
		check(RaceQueues.waitingWith(s, "rookie2") == 2 and RaceQueues.waitingWith(s, "gold1") == 1, "riders wait with their league")
		startRace(courses.turf)
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(courses.turf.card.league == "Rookie", "the longest wait (Rookie since 12) claims the free course")
		check(courses.turf.queue[1] == "rookie1" and courses.turf.queue[2] == "rookie2", "the whole Rookie queue goes, in order")
		check(RaceQueues.isWaiting(s, "gold1") and not RaceQueues.isWaiting(s, "rookie2"), "Gold keeps waiting for the next course")
		startRace(courses.dirt)
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(courses.dirt.card.league == "Gold" and courses.dirt.queue[1] == "gold1", "then Gold gets the next one")
	end

	-- Nobody waits through a race while a course sits idle: an open idle course beats a racing
	-- course whose next card is already this league's.
	do
		local s = RaceQueues.new()
		local courses = {
			dirt = course("dirt", "Bronze", "race", { "b1" }, true),
			turf = course("turf", nil, nil, {}, false),
		}
		RaceQueues.join(s, "b2", "Bronze", "race", 1)
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(courses.turf.queue[1] == "b2" and courses.turf.card.league == "Bronze", "the idle course takes the rider now")
	end

	-- Kinds are separate queues: a Bronze Cup rider never joins a Bronze race card.
	do
		local s = RaceQueues.new()
		local courses = {
			dirt = course("dirt", "Bronze", "race", { "b1" }, false),
			turf = course("turf", nil, nil, {}, false),
		}
		RaceQueues.join(s, "cup1", "Bronze", "cup", 1)
		RaceQueues.pump(s, courses, ORDER, LANES, claim)
		check(courses.turf.queue[1] == "cup1" and courses.turf.card.cup and courses.turf.card.league == "Bronze",
			"a Cup rider claims an open course for the Bronze Cup")
		check(#courses.dirt.queue == 1, "not the Bronze race card")
	end

	-- A full card of your league is not a course you can join; leaving and rejoining.
	do
		local full = {}
		for k = 1, LANES do full[k] = "b" .. k end
		local s = RaceQueues.new()
		local courses = {
			dirt = course("dirt", "Bronze", "race", full, false),
			turf = course("turf", "Rookie", "race", { "r1" }, false),
		}
		check(RaceQueues.bestCourse(courses, ORDER, "Bronze|race", LANES) == nil, "a full card takes nobody")
		RaceQueues.join(s, "b9", "Bronze", "race", 3)
		RaceQueues.join(s, "b9", "Bronze", "race", 9) -- same queue: keeps the place
		check(s.queues["Bronze|race"].riders[1].at == 3, "joining your own queue again keeps your place")
		RaceQueues.join(s, "b9", "Bronze", "practice", 10)
		check(s.queues["Bronze|race"] == nil and RaceQueues.waitingWith(s, "b9") == 1, "another kind is another queue")
		check(RaceQueues.leave(s, "b9") and not RaceQueues.isWaiting(s, "b9") and next(s.queues) == nil, "leaving empties the queue")
		check(not RaceQueues.leave(s, "b9"), "leaving twice is harmless")
	end

	-- Property: whatever the state, bestCourse only returns a course this queue can join (its own
	-- card with room, or an open course with nobody in line), and pump never mixes leagues or kinds.
	do
		local rng = makeRng(4242)
		local leagues = { "Rookie", "Bronze", "Silver", "Gold" }
		local kinds = { "race", "cup", "practice" }
		local bad, mixed = 0, 0
		for trial = 1, 400 do
			local courses = {}
			for _, id in ORDER do
				local open = rng:NextNumber() < 0.35
				local n = if open then (if rng:NextNumber() < 0.2 then 1 else 0) else rng:NextInteger(1, LANES)
				local riders = {}
				for k = 1, n do riders[k] = id .. trial .. "_" .. k end
				courses[id] = course(id, if open then nil else leagues[rng:NextInteger(1, 4)], if open then nil else kinds[rng:NextInteger(1, 3)],
					riders, rng:NextNumber() < 0.4)
			end
			local s = RaceQueues.new()
			local leagueOf: { [string]: string } = {}
			for k = 1, rng:NextInteger(1, 12) do
				local league, kind = leagues[rng:NextInteger(1, 4)], kinds[rng:NextInteger(1, 3)]
				local who = "w" .. trial .. "_" .. k
				leagueOf[who] = RaceQueues.key(league, kind)
				local c = RaceQueues.bestCourse(courses, ORDER, leagueOf[who], LANES)
				if c then
					local ck = RaceQueues.cardKey(c.card)
					if not ((ck == leagueOf[who] and #c.queue < LANES) or (ck == nil and #c.queue == 0)) then bad += 1 end
				end
				RaceQueues.join(s, who, league, kind, rng:NextNumber(0, 100), if rng:NextNumber() < 0.5 then ORDER[rng:NextInteger(1, 2)] else nil)
			end
			RaceQueues.pump(s, courses, ORDER, LANES, claim)
			for _, id in ORDER do
				local c = courses[id]
				if #c.queue > LANES then mixed += 1 end
				for _, who in c.queue do
					if leagueOf[who] and leagueOf[who] ~= RaceQueues.cardKey(c.card) then mixed += 1 end
				end
			end
		end
		check(bad == 0, `bestCourse returned an unjoinable course {bad} times`)
		check(mixed == 0, `pump put a rider on another league's or kind's card {mixed} times`)
	end

	-- Decorators (D-065): one that throws is skipped and reported; the view still has the rest.
	do
		local T0 = 20000 * 86400
		local p = Profile.new(T0)
		Profile.addHorse(p, Horse.starter("h1", "Comet", "bay", makeRng(1), T0))
		local errors = {}
		local view = Profile.decoratedView(p, T0, GameConfig.energy, {
			function(_data, v) v.first = true end,
			function() error("decorator broke") end,
			function(_data, v) v.third = true end,
		}, function(i, err) table.insert(errors, { i, tostring(err) }) end)
		check(view ~= nil and view.horses and #view.horses == 1, "a throwing decorator still produces a view")
		check(view.first == true and view.third == true, "the other decorators still run")
		check(#errors == 1 and errors[1][1] == 2 and string.find(errors[1][2], "decorator broke") ~= nil, "the failing decorator is reported")
		local quiet = Profile.decoratedView(p, T0, GameConfig.energy, { function() error("x") end })
		check(quiet.horses ~= nil, "no error handler: still a view")
	end

	-- Ready / Napping (D-058): ready from 1 Energy; napping only at 0; Advice says napping only then.
	do
		local T0 = 20000 * 86400
		local E = GameConfig.energy
		check(E.restingLabelAt == 0, "energy.restingLabelAt = 0")
		local h = Horse.starter("h1", "Comet", "bay", makeRng(2), T0)
		local full = Horse.view(h, T0, E)
		check(full.ready and not full.resting, "full Energy: ready")
		Horse.spendEnergy(h, 1, T0, E)
		local four = Horse.view(h, T0, E)
		check(four.energy == E.maxPerRacer - 1 and four.ready and not four.resting, "after one cash race: still Ready, not napping")
		for _ = 1, E.maxPerRacer - 2 do Horse.spendEnergy(h, 1, T0, E) end
		local one = Horse.view(h, T0, E)
		check(one.energy == 1 and one.ready and not one.resting, "ready at 1 Energy")
		Horse.spendEnergy(h, 1, T0, E)
		local zero = Horse.view(h, T0, E)
		check(zero.energy == 0 and not zero.ready and zero.resting, "napping at 0 Energy")
		local tipOne = Advice.forHorse({ name = "Comet", fed = true, groomed = true, resting = one.resting, stats = {} }, { garden = {} }, T0)
		check(not string.find(tipOne.fact, "napping") and not string.find(tipOne.next, "Napping"), "Advice doesn't say napping at 1 Energy")
		local tipZero = Advice.forHorse({ name = "Comet", fed = true, groomed = true, resting = zero.resting, stats = {} }, { garden = {} }, T0)
		check(string.find(tipZero.fact, "napping") ~= nil, "Advice says napping at 0 Energy")
	end

	-- No retiring a horse in use (D-065).
	do
		check(Leagues.retireBlock("Comet", "h1", { ridingHorse = "h1" }) ~= nil, "can't retire the horse you're riding")
		check(string.find(Leagues.retireBlock("Comet", "h1", { ridingHorse = "h1" }) or "", "riding") ~= nil, "it says riding")
		check(Leagues.retireBlock("Comet", "h1", { inLine = true }) ~= nil, "can't retire while queued")
		check(Leagues.retireBlock("Comet", "h1", { racing = true }) ~= nil, "can't retire while racing")
		check(Leagues.retireBlock("Comet", "h1", { racingHorse = "h1" }) ~= nil, "can't retire the horse at the races")
		check(Leagues.retireBlock("Comet", "h1", { trainingRide = true, ridingHorse = "h1" }) ~= nil, "can't retire on a training ride")
		check(Leagues.retireBlock("Maple", "h2", { ridingHorse = "h1" }) == nil, "another horse can retire while you ride")
		check(Leagues.retireBlock("Maple", "h2", {}) == nil, "a horse at home can retire")
	end

	-- Dock floors (D-064): never under 56 px buttons or 14 px labels, at any width.
	do
		local U = GameConfig.ui
		check(U.minTouchPx >= 56 and U.minTextPx >= 14 and U.labelPx >= 16 and U.dockPhoneItems == 3, "ui floors in GameConfig")
		local ok = true
		for room = 50, 2000, 25 do
			for width = 300, 1400, 100 do
				local sc = DockLayout.scale(room, width, U)
				if sc * DockLayout.BUTTON_PX < U.minTouchPx - 1e-9 or sc * DockLayout.LEAVE_PX < U.minTouchPx - 1e-9
					or sc * DockLayout.LABEL_PX < U.minTextPx - 1e-9 or sc > 1 then ok = false end
			end
		end
		check(ok, "the dock never scales a button under 56 px or a label under 14 px")
		check(DockLayout.scale(5000, 500, U) == 1, "a roomy screen shows the dock at full size")
		check(DockLayout.isPhone(true, 812, 375, U) and not DockLayout.isPhone(false, 812, 375, U)
			and not DockLayout.isPhone(true, 1366, 1024, U), "phones: touch and a short side under 500 px")
		check(GameConfig.lobbyFillSeconds == 15, "lobbyFillSeconds = 15")
		check(GameConfig.queue.mode == "leagues", "per-league queues on")
	end
end
