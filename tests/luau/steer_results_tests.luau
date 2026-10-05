--!strict
-- Steering stage S4 (D-054): replays and results. The trip-star thresholds, the results lines
-- (never a lost place, never zero stars or a strange number, the trip line only for riders who had
-- the buttons and only while steering counts), the RideReport arguments both ways, what the replay
-- draws from a recording (lanes, your line, saved turns, tucked-in spans; older recordings are
-- safe), and the half-lane step at the finish: it keeps two horses from finishing through each
-- other, jerks nobody backwards, and changes no finish. Run from run_all.luau.
local fs = require("@lune/fs")

local GameConfig = require("../../game/src/shared/GameConfig")
local TrackLayout = require("../../game/src/shared/TrackLayout")
local Trip = require("../../game/src/shared/Trip")
local ReplayTrip = require("../../game/src/shared/ReplayTrip")
local ResultsText = require("../../game/src/shared/ResultsText")
local simulateRace = require("./race_overlap")

local STEER = GameConfig.steering
local NAN, INF = 0 / 0, math.huge

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Trip stars ----------------------------------------------------------------------------------
	check(STEER.stars[1] == 0.015 and STEER.stars[2] == -0.005, "trip stars: three at +0.015 or more, two at -0.005 or more")
	check(Trip.stars(0.015, STEER) == 3 and Trip.stars(0.04, STEER) == 3, "three stars from +0.015")
	check(Trip.stars(0.0149, STEER) == 2 and Trip.stars(0, STEER) == 2 and Trip.stars(-0.005, STEER) == 2, "two stars from -0.005")
	check(Trip.stars(-0.0051, STEER) == 1 and Trip.stars(-0.02, STEER) == 1 and Trip.stars(-1, STEER) == 1, "one star below that, never zero")

	-- The results lines ---------------------------------------------------------------------------
	check(ResultsText.rideLine(2) == "You rode ★★☆" and ResultsText.rideLine(0) == "You rode ☆☆☆"
		and ResultsText.rideLine(NAN) == "You rode ☆☆☆", "You rode, in stars (a strange value shows none)")
	check(ResultsText.tripLine(3) == "Good trip ★★★" and ResultsText.tripLine(2) == "Good trip ★★☆"
		and ResultsText.tripLine(1) == "Good trip ★☆☆", "Good trip, in one to three stars")
	local noTrip = true
	for _, v in { nil, 0, 4, 2.5, -1, NAN, INF, -INF } do
		if ResultsText.tripLine(v) ~= nil then noTrip = false end
	end
	check(noTrip, "no trip line for nil, 0, 4, 2.5, a negative, NaN or infinity (never \"Good trip\" with no stars)")
	check(ResultsText.tripLine(3, 0) == nil and ResultsText.tripLine(3, 1) == "Good trip ★★★",
		"no trip line while steering is cosmetic (scale 0)")
	check(ResultsText.gainLine("trip", 1) == "Your trip gained you 1 place!" and ResultsText.gainLine("trip", 2) == "Your trip gained you 2 places!"
		and ResultsText.gainLine("riding", 3) == "Your riding gained you 3 places!", "gains, in words")
	local onlyGains = true
	for _, g in { nil, 0, 0.5, -1, -3, NAN, INF, -INF } do
		for _, what in { "trip", "riding" } do
			if ResultsText.gainLine(what, g) ~= "" then onlyGains = false end
		end
	end
	for g = -8, 8 do
		local line = ResultsText.gainLine("trip", g)
		if (g < 1) ~= (line == "") or string.find(line, "-", 1, true) or string.find(string.lower(line), "lost", 1, true) then
			onlyGains = false
		end
	end
	check(onlyGains, "a gain line only for a gain of a place or more: nothing for nil, 0, a loss, NaN or infinity, never a lost place")

	-- RideReport's arguments, built by the server and read by the card ------------------------------
	local plainArgs = ResultsText.reportArgs(2, 1, 3, "dirt")
	local tripArgs = ResultsText.reportArgs(2, 0, 5, "turf", 3, -1)
	check(#plainArgs == 4 and plainArgs[4] == "dirt" and #tripArgs == 6 and tripArgs[6] == "turf", "RideReport: four arguments, or six with a trip; the course last")
	local plain = ResultsText.rideReport(table.unpack(plainArgs))
	local steered = ResultsText.rideReport(table.unpack(tripArgs))
	check(plain.stars == 2 and plain.gain == 1 and plain.place == 3 and plain.tripStars == nil and ResultsText.tripLine(plain.tripStars) == nil,
		"without a trip the card shows no trip line")
	check(steered.tripStars == 3 and steered.tripGain == -1 and ResultsText.tripLine(steered.tripStars, STEER.scale) == "Good trip ★★★"
		and ResultsText.gainLine("trip", steered.tripGain) == "", "with a trip: the stars show, a trip that cost a place says nothing")
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	check(string.find(rs, "local tripStars = if trip and steers[p] then Trip.stars(session.tau[i], GameConfig.steering) else nil", 1, true) ~= nil
		and string.find(rs, "ResultsText.reportArgs(stars, session:ridingGain(i), placeOf[i], c.id, tripStars, tripGain)", 1, true) ~= nil,
		"the server builds RideReport with ResultsText, trip fields only for riders who had the buttons")

	-- What the replay draws ---------------------------------------------------------------------
	local frame1 = { t = 10, [1] = 0.10, [2] = 0.11, x = { 2, 4 } }
	local frame2 = { t = 10.1, [1] = 0.11, [2] = 0.12, x = { 1.5, 4 } }
	local rec = { frames = { frame1, frame2 }, lane = { 2, 4 }, events = {}, myLane = 1, steer = true }
	check(math.abs(ReplayTrip.laneAt(rec, frame1, frame2, 0.5, 1) - 1.75) < 1e-12, "replay lanes come from the recorded lanes, interpolated")
	local old = { frames = { { t = 1, [1] = 0.1 }, { t = 1.1, [1] = 0.2 } }, lane = { 6 } }
	local older = { frames = { { t = 1, [1] = 0.1 }, { t = 1.1, [1] = 0.2 } } }
	check(ReplayTrip.laneAt(old, old.frames[1], old.frames[2], 0.5, 1) == 6 and ReplayTrip.laneAt(older, older.frames[1], older.frames[2], 0.5, 1) == 1,
		"recordings without lanes: the post, else the lane number")
	check(ReplayTrip.ribbon(old, 1) == nil and ReplayTrip.ribbon(older, 1) == nil and not ReplayTrip.tuckedAt(older, 1)
		and #ReplayTrip.events(older, "saved") == 0, "an old recording draws no line, no wind lines, no chevrons, and nothing errors")
	-- A rider's race recorded with the same builders the race uses: 40 frames from t = 0, a turn from
	-- 25 to 50 ft at 25 ft/s (1 to 2 s) left having saved ground, tucked in from 2.1 to 2.6 s, the lock at 3 s.
	local frames = {}
	for k = 0, 39 do
		frames[k + 1] = { t = k * 0.1, [1] = 0.01 * k, [2] = 0.01 * k + 0.001, x = { 3 - math.min(2, k * 0.05), 4 } }
	end
	local saved = ReplayTrip.saved(2, 0, 25, 50, 25)
	local tuck = ReplayTrip.tuck(2.1, 2.6)
	check(saved.kind == "saved" and saved.t0 == 1 and saved.t1 == 2 and tuck.kind == "tuck" and tuck.t == 2.6,
		"the race records a saved turn by its time span, a tucked-in span by its ends")
	local race = { frames = frames, lane = { 3, 4 }, myLane = 1, steer = true, lockAt = 3,
		events = { { t = 0.5, kind = "steer", dir = -1 }, saved, tuck } }
	local ribbon = ReplayTrip.ribbon(race, 2) :: { any }
	local lastT, savedOk, stepOk = -1, true, true
	for k, pnt in ribbon do
		lastT = pnt.t
		if pnt.saved ~= (pnt.t >= 1 - 1e-9 and pnt.t <= 2 + 1e-9) then savedOk = false end
		if k > 1 and math.abs(pnt.t - ribbon[k - 1].t - 0.2) > 1e-9 then stepOk = false end
	end
	check(ribbon ~= nil and lastT <= 3 and lastT > 2.7 and stepOk, "your line runs from the gate to the lock, every `step` frames")
	check(savedOk, "...green through the turns where you saved ground")
	check(ReplayTrip.tuckedAt(race, 2.3) and not ReplayTrip.tuckedAt(race, 2.7) and not ReplayTrip.tuckedAt(race, 1),
		"wind lines exactly while you were tucked in")
	race.steer = nil
	check(ReplayTrip.ribbon(race, 2) == nil, "no line for a race ridden without the buttons (or watched)")
	-- The client wiring (Roblox scripts, so read, not run).
	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	local rv = fs.readFile("game/src/client/RaceView.client.luau")
	local replay = fs.readFile("game/src/client/Replay.client.luau")
	check(string.find(rv, "local frame = { t = t, x = table.clone(race.lane) }", 1, true) ~= nil
		and string.find(rv, "then rec.lockAt = lockAt end", 1, true) ~= nil
		and string.find(rc, "ReplayTrip.saved(t, s.start, turn[1], turn[2], SPEED)", 1, true) ~= nil
		and string.find(rc, "ReplayTrip.tuck(s.tuckFrom, t)", 1, true) ~= nil
		and string.find(rc, "RaceState.recording.steer = true", 1, true) ~= nil
		and string.find(rc, "ResultsText.tripLine(rideReport.tripStars, STEER.scale)", 1, true) ~= nil,
		"the race records lanes, the lock, saved turns, tucked spans and the buttons; the card asks ResultsText")
	check(string.find(replay, "ReplayTrip.laneAt(rec, a, b, f, i)", 1, true) ~= nil and string.find(replay, "lanes[subject] or subject", 1, true) ~= nil
		and string.find(replay, "RaceState.finishFollowed()", 1, true) ~= nil and string.find(replay, "RaceState.restHorses(rec.course, rec.lanes)", 1, true) ~= nil,
		"Replay places by recorded lanes, frames the camera on the lane now, keeps the D-055 handover and the legs' rest")
	for _, src in { replay, rc, fs.readFile("game/src/shared/ResultsText.luau") } do
		check(string.find(string.lower(src), "lost a place", 1, true) == nil and string.find(string.lower(src), "lost places", 1, true) == nil,
			"no lost places anywhere on the results or the replay")
	end

	-- The half-lane step at the finish -------------------------------------------------------------
	local track = TrackLayout.courses.dirt
	local plan = TrackLayout.plan(track, TrackLayout.distances.Sprint)
	local geo = TrackLayout.phaseA(track, plan)
	local function boxed(lanes: number, posts: { number }, view: { number }): any
		local params = Trip.raceParams(GameConfig)
		params.lanes = lanes
		local n = #posts
		local st = Trip.new(posts, table.create(n, 1 / n), table.create(2 * n, 0.5), geo, STEER, table.create(n, "manual"), params)
		Trip.lock(st)
		st.view, st.shown, st.shownTgt = table.clone(view), table.clone(posts), table.clone(posts)
		return st
	end
	local finish = geo.length / Trip.raceParams(GameConfig).speed
	-- Two lanes: B held behind A in lane 1, C alongside in lane 2; nobody can move over.
	local targets = { 0, -4, 2 } -- B finishes 4 ft behind A: closer than a horse's length
	local early = boxed(2, { 1, 1, 2 }, { 0, -10, 2 })
	local lanesEarly = { 1, 1, 2 }
	for k = 1, 10 do lanesEarly = Trip.cosmetic(early, targets, 0.1, 10 + k * 0.1) end
	check(lanesEarly[2] == 1, "far from the line a boxed-in horse stays held in its lane")
	local late = boxed(2, { 1, 1, 2 }, { 0, -10, 2 })
	local lanesLate, prevView, backMax = { 1, 1, 2 }, table.clone(late.view), 0
	for k = 1, 6 do
		lanesLate = Trip.cosmetic(late, targets, 0.1, finish - 1.5 + k * 0.1)
		for i = 1, 3 do backMax = math.max(backMax, (prevView[i] - late.view[i]) / 0.1) end
		prevView = table.clone(late.view)
	end
	check(lanesLate[2] == 1.5 and lanesLate[1] == 1 and lanesLate[3] == 2,
		"in the last moments it edges half a lane over, so the two finish staggered, not through each other")
	check(backMax <= 20, string.format("...and nobody is drawn jerking back while it steps (fastest %.1f ft/s)", backMax))
	-- The outside lane: B steps in, from lane 8 to 7.5, with every other lane taken alongside.
	local posts8 = { 8, 8, 7, 6, 5, 4, 3, 2, 1 }
	local view8 = { 0, -10, 2, 2, 2, 2, 2, 2, 2 }
	local targets8 = { 0, -4, 2, 2, 2, 2, 2, 2, 2 }
	local outside = boxed(8, posts8, view8)
	local lanes8 = table.clone(posts8)
	for k = 1, 6 do lanes8 = Trip.cosmetic(outside, targets8, 0.1, finish - 1.5 + k * 0.1) end
	local othersStay = true
	for i = 3, 9 do
		if lanes8[i] ~= posts8[i] then othersStay = false end
	end
	check(lanes8[2] == 7.5 and lanes8[1] == 8 and othersStay, "from the outside lane the step goes in: lane 8 to 7.5")
	-- On and off, to the line: the others' offsets are the same, the stepping horse's differ only
	-- because its hold lets go a moment early (once it is half a lane over), by under a foot on the
	-- way and a fraction of one at the line; the order is the same. Only its lane differs.
	local function toLine(on: boolean): ({ { number } }, { number })
		Trip.halfSteps = on
		local st = boxed(2, { 1, 1, 2 }, { 0, -10, 2 })
		local lanes, views = { 1, 1, 2 }, {}
		for k = 1, 15 do -- the last tick is at the line
			lanes = Trip.cosmetic(st, targets, 0.1, finish - 1.5 + k * 0.1)
			views[k] = table.clone(st.view)
		end
		Trip.halfSteps = true
		return views, lanes
	end
	local viewsOn, lanesOn = toLine(true)
	local viewsOff, lanesOff = toLine(false)
	local othersSame, wayMax = true, 0
	for k = 1, 15 do
		if viewsOn[k][1] ~= viewsOff[k][1] or viewsOn[k][3] ~= viewsOff[k][3] then othersSame = false end
		wayMax = math.max(wayMax, math.abs(viewsOn[k][2] - viewsOff[k][2]))
	end
	local atLine = math.abs(viewsOn[15][2] - viewsOff[15][2])
	local orderOn, orderOff = viewsOn[15][1] > viewsOn[15][2], viewsOff[15][1] > viewsOff[15][2]
	check(othersSame and wayMax < 1 and atLine < 0.25 and orderOn and orderOff,
		string.format("step on or off: the others' offsets the same; the stepping horse's within %.2f ft on the way, %.2f ft at the line; the same order", wayMax, atLine))
	check(lanesOn[2] == 1.5 and lanesOff[2] == 1 and lanesOn[1] == lanesOff[1] and lanesOn[3] == lanesOff[3],
		"...and only the stepping horse's lane differs")

	-- Make-room never moves a horse in front of one that's catching it (the hold would pull one back
	-- when they meet, a jerk). B, held behind A in lane 1, may move to lane 2 only if C there isn't
	-- closing on it.
	local function makeRoom(cTarget: number): number
		local st = boxed(2, { 1, 1, 2 }, { 0, -10, -25 })
		local lanes = { 1, 1, 2 }
		for k = 1, 4 do lanes = Trip.cosmetic(st, { 0, -4, cTarget }, 0.1, 10 + k * 0.1) end
		return lanes[2]
	end
	check(makeRoom(0) == 1 and makeRoom(-40) > 1,
		"a horse waits rather than move in front of one catching it; with the lane behind it clear, it moves")

	-- Whole races: the two that jerked before the fix, and a mix, with the step on and off --------
	local reproBots = simulateRace("dirt", "Sprint", 4212911)
	local reproRiders = simulateRace("turf", "Marathon", 1963915, nil, { riders = 2 })
	check(reproBots.jerks + reproBots.jerksBefore + reproRiders.jerks + reproRiders.jerksBefore == 0
		and math.max(reproBots.backAfter, reproRiders.backAfter, reproBots.backBefore, reproRiders.backBefore) <= 20
		and reproBots.before + reproBots.after + reproRiders.before + reproRiders.after == 0,
		string.format("the review's two races: no jerks (fastest fall back %.1f and %.1f ft/s after the lock, %.1f and %.1f before), no overlaps",
			reproBots.backAfter, reproRiders.backAfter, reproBots.backBefore, reproRiders.backBefore))
	local races, jerks, overlaps, sameOrder, rightOrder = 0, 0, 0, true, true
	for ci, course in { "dirt", "turf" } do
		for di, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
			local seed = 5100 + 100 * ci + 10 * di
			local opts = if di % 2 == 0 then { riders = 2 } else nil
			Trip.halfSteps = false
			local off = simulateRace(course, distance, seed, nil, opts)
			Trip.halfSteps = true
			local on = simulateRace(course, distance, seed, nil, opts)
			races += 1
			jerks += on.jerks + on.jerksBefore
			overlaps += on.before + on.after
			if not on.orderOk then rightOrder = false end
			for p, lane in on.lineOrder do
				if off.lineOrder[p] ~= lane then sameOrder = false end
			end
		end
	end
	check(jerks == 0 and overlaps == 0 and rightOrder, `{races} races: no jerks, no overlaps, the order across the line the result`)
	check(sameOrder, "...and the same order across the line with the half-lane step on or off")
end
