--!strict
-- Steering stage S4 (D-054): replays and results. The trip-star thresholds, the results lines
-- (never a lost place, never zero stars, the trip line only for riders who had the buttons), the
-- RideReport fields, what the replay draws from a recording (lanes, your line, saved turns,
-- tucked-in spans, the lock; older recordings without them are safe), what the race records for it,
-- and the half-lane step that keeps two horses from finishing through each other. Run from
-- run_all.luau.
local fs = require("@lune/fs")

local GameConfig = require("../../game/src/shared/GameConfig")
local TrackLayout = require("../../game/src/shared/TrackLayout")
local Trip = require("../../game/src/shared/Trip")
local ReplayTrip = require("../../game/src/shared/ReplayTrip")
local ResultsText = require("../../game/src/shared/ResultsText")

local STEER = GameConfig.steering

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Trip stars ----------------------------------------------------------------------------------
	check(STEER.stars[1] == 0.015 and STEER.stars[2] == -0.005, "trip stars: three at +0.015 or more, two at -0.005 or more")
	check(Trip.stars(0.015, STEER) == 3 and Trip.stars(0.04, STEER) == 3, "three stars from +0.015")
	check(Trip.stars(0.0149, STEER) == 2 and Trip.stars(0, STEER) == 2 and Trip.stars(-0.005, STEER) == 2, "two stars from -0.005")
	check(Trip.stars(-0.0051, STEER) == 1 and Trip.stars(-0.02, STEER) == 1 and Trip.stars(-1, STEER) == 1, "one star below that, never zero")

	-- The results lines ---------------------------------------------------------------------------
	check(ResultsText.rideLine(2) == "You rode ★★☆" and ResultsText.rideLine(0) == "You rode ☆☆☆", "You rode, in stars")
	check(ResultsText.tripLine(3) == "Good trip ★★★" and ResultsText.tripLine(2) == "Good trip ★★☆"
		and ResultsText.tripLine(1) == "Good trip ★☆☆", "Good trip, in stars")
	check(ResultsText.tripLine(0) == "Good trip ★☆☆" and ResultsText.tripLine(9) == "Good trip ★★★", "the trip line never has zero stars")
	check(ResultsText.tripLine(nil) == "", "no trip line without one (steering off, or no buttons yet)")
	check(ResultsText.gainLine("trip", 1) == "Your trip gained you 1 place!" and ResultsText.gainLine("trip", 2) == "Your trip gained you 2 places!"
		and ResultsText.gainLine("riding", 3) == "Your riding gained you 3 places!", "gains, in words")
	local neverNegative = true
	for g = -8, 8 do
		for _, what in { "trip", "riding" } do
			local line = ResultsText.gainLine(what, g)
			if (g < 1 and line ~= "") or string.find(line, "-", 1, true) or string.find(string.lower(line), "lost", 1, true) then
				neverNegative = false
			end
		end
	end
	check(neverNegative and ResultsText.gainLine("trip", nil) == "", "a trip (or riding) line only for a gain: never a negative number, never a lost place")
	local plain = ResultsText.rideReport(2, 1, 3, "dirt")
	local steered = ResultsText.rideReport(2, 0, 5, 3, -1, "turf")
	check(plain.stars == 2 and plain.gain == 1 and plain.place == 3 and plain.tripStars == nil and plain.tripGain == nil,
		"RideReport (stars, gain, place, course): no trip fields")
	check(steered.tripStars == 3 and steered.tripGain == -1 and ResultsText.gainLine("trip", steered.tripGain) == ""
		and ResultsText.tripLine(steered.tripStars) == "Good trip ★★★", "RideReport with a trip: the stars show, a trip that cost a place says nothing")
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	check(string.find(rs, "if trip and steers[p] then", 1, true) ~= nil
		and string.find(rs, "Trip.stars(session.tau[i], GameConfig.steering), session:tripGain(i), c.id)", 1, true) ~= nil,
		"the server sends trip stars and trip gain only to riders who had the buttons (intro riders: no trip line)")
	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	check(string.find(rc, "ResultsText.tripLine(rideReport.tripStars)", 1, true) ~= nil
		and string.find(rc, "ResultsText.gainLine(\"trip\", rideReport.tripGain)", 1, true) ~= nil
		and string.find(rc, "ResultsText.rideReport(starCount, gain, finishPlace, a, b)", 1, true) ~= nil,
		"the results card takes its lines from ResultsText")

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
	-- A rider's race: 40 frames from t = 0, one saved turn (1 to 2 s), a tucked-in span, the lock at 3 s.
	local frames = {}
	for k = 0, 39 do
		frames[k + 1] = { t = k * 0.1, [1] = 0.01 * k, [2] = 0.01 * k + 0.001, x = { 3 - math.min(2, k * 0.05), 4 } }
	end
	local race = { frames = frames, lane = { 3, 4 }, myLane = 1, steer = true, lockAt = 3,
		events = { { t = 2, kind = "saved", t0 = 1, t1 = 2 }, { t = 2.6, kind = "tuck", t0 = 2.1, t1 = 2.6 }, { t = 3, kind = "lock" },
			{ t = 0.5, kind = "steer", dir = -1 } } }
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

	-- What the race records ------------------------------------------------------------------------
	local rv = fs.readFile("game/src/client/RaceView.client.luau")
	check(string.find(rv, "local frame = { t = t, x = table.clone(race.lane) }", 1, true) ~= nil,
		"replay frames carry every horse's lane")
	check(string.find(rv, "then rec.lockAt = lockAt end", 1, true) ~= nil
		and string.find(rv, "table.insert(rec.events, { t = serverNow(), kind = \"lock\" })", 1, true) ~= nil,
		"the recording keeps the lock time and a lock event")
	check(string.find(rc, "kind = \"saved\",", 1, true) ~= nil and string.find(rc, "t0 = s.start + turn[1] / SPEED, t1 = s.start + turn[2] / SPEED", 1, true) ~= nil
		and string.find(rc, "kind = \"tuck\", t0 = s.tuckFrom, t1 = t", 1, true) ~= nil
		and string.find(rc, "kind = \"steer\", dir = dir", 1, true) ~= nil
		and string.find(rc, "RaceState.recording.steer = true", 1, true) ~= nil,
		"the recording keeps saved turns, tucked-in spans, your presses, and whether you had the buttons")
	local replay = fs.readFile("game/src/client/Replay.client.luau")
	check(string.find(replay, "ReplayTrip.laneAt(rec, a, b, f, i)", 1, true) ~= nil and string.find(replay, "ReplayTrip.ribbon(rec, 3)", 1, true) ~= nil
		and string.find(replay, "ReplayTrip.tuckedAt(rec, t)", 1, true) ~= nil and string.find(replay, "RaceState.finishFollowed()", 1, true) ~= nil
		and string.find(replay, "RaceState.restHorses(rec.course, rec.lanes)", 1, true) ~= nil,
		"Replay draws lanes, your line and wind lines, and keeps the D-055 handover and the legs' rest")
	for _, src in { replay, rc, fs.readFile("game/src/shared/ResultsText.luau") } do
		check(string.find(string.lower(src), "lost a place", 1, true) == nil and string.find(string.lower(src), "lost places", 1, true) == nil,
			"no lost places anywhere on the results or the replay")
	end

	-- The half-lane step at the finish -------------------------------------------------------------
	-- Two lanes only: B is held behind A in lane 1 with C alongside in lane 2, so nobody can move over.
	local track = TrackLayout.courses.dirt
	local plan = TrackLayout.plan(track, TrackLayout.distances.Sprint)
	local raceParams = Trip.raceParams(GameConfig)
	raceParams.lanes = 2
	local function boxed(): any
		local st = Trip.new({ 1, 1, 2 }, { 1 / 3, 1 / 3, 1 / 3 }, table.create(6, 0.5), TrackLayout.phaseA(track, plan), STEER,
			{ "manual", "manual", "manual" }, raceParams)
		Trip.lock(st)
		st.view, st.shown, st.shownTgt = { 0, -10, 2 }, { 1, 1, 2 }, { 1, 1, 2 }
		return st
	end
	local targets = { 0, -4, 2 } -- B finishes 4 ft behind A: closer than a horse's length
	local finish = TrackLayout.phaseA(track, plan).length / raceParams.speed
	local early = boxed()
	local lanesEarly = { 1, 1, 2 }
	for k = 1, 10 do lanesEarly = Trip.cosmetic(early, targets, 0.1, 10 + k * 0.1) end
	check(lanesEarly[2] == 1, "far from the line a boxed-in horse stays held in its lane")
	local late = boxed()
	local lanesLate = { 1, 1, 2 }
	for k = 1, 6 do lanesLate = Trip.cosmetic(late, targets, 0.1, finish - 1.5 + k * 0.1) end
	check(lanesLate[2] == 1.5 and lanesLate[1] == 1 and lanesLate[3] == 2,
		"in the last moments it edges half a lane over, so the two finish staggered, not through each other")
end
