--!strict
-- D-057 N5: brushes on. The pose of a brush (SteerPose.brush), who brushes and who pays in whole
-- races, the race's tau with the charges, nothing after the lock, the remote's shape, the mover's
-- chip, and a cleared wait that doesn't wobble.
local fs = require("@lune/fs")
local RaceMath = require("../../src/RaceMath")
local GameConfig = require("../../game/src/shared/GameConfig")
local ThemePack = require("../../game/src/shared/ThemePack")
local BurstMeter = require("../../game/src/shared/BurstMeter")
local PaceMeter = require("../../game/src/shared/PaceMeter")
local RaceShape = require("../../game/src/shared/RaceShape")
local RaceSession = require("../../game/src/shared/RaceSession")
local TrackLayout = require("../../game/src/shared/TrackLayout")
local Trip = require("../../game/src/shared/Trip")
local TripBaseline = require("../../game/src/shared/TripBaseline")
local SteerPose = require("../../game/src/shared/SteerPose")
local SteerHud = require("../../game/src/shared/SteerHud")
local SteerChips = require("../../game/src/shared/SteerChips")
local SteerPredict = require("../../game/src/shared/SteerPredict")
local simulateRace = require("./race_overlap")

local STEER, SHUD, POSE = GameConfig.steering, GameConfig.steerHud, GameConfig.steerView

local function makeRng(seed0: number)
	local seed = seed0
	return { NextNumber = function(_self): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end }
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	check(STEER.brush == "repeat" and STEER.brushPays == "mover" and STEER.brushCost == 0.002 and STEER.brushFree == 1
		and STEER.brushMaxCharged == 3 and POSE.brushLeanFeet == 1 and POSE.brushLeanSeconds == 0.4 and POSE.brushNodDeg == 2
		and POSE.brushVolume == 0.5, "brushes are on with D-057's values: the mover pays 0.002 after one free, at most 0.006")
	check(STEER.brushPresses == 3 and Trip.D057.brushPresses == nil and Trip.D057_OFF.brushPresses == 3,
		"N5 review: a brush needs a third press that way (a press again is the same try)")

	-- The pose ---------------------------------------------------------------------------------
	local span = POSE.brushLeanSeconds
	local l0, n0 = SteerPose.brush(-0.01, POSE, true, 1)
	local l1, n1 = SteerPose.brush(span, POSE, true, 1)
	check(l0 == 0 and n0 == 0 and l1 == 0 and n1 == 0, "a brush's lean and nod are nothing before it and after brushLeanSeconds")
	local lm, nm = SteerPose.brush(span / 2, POSE, true, -1)
	check(close(lm, -POSE.brushLeanFeet, 1e-12) and close(nm, math.rad(POSE.brushNodDeg), 1e-12),
		"the mover leans toward the other horse, at most brushLeanFeet, and nods at most brushNodDeg, halfway through")
	local lo, no = SteerPose.brush(span / 2, POSE, false, -1)
	check(lo == 0 and close(no, nm, 1e-12), "the other horse only nods: no lean, no drop, no stumble")
	-- At a real 60 fps (span * 60 frames): the first and last frames move at most 6% of the lean
	-- (sin^2 starts and ends at rest; a plain sine moved 13% on its first frame), and no frame more
	-- than the curve's own peak rate allows.
	local frames = math.floor(span * 60 + 0.5)
	local steps = {}
	local prevL = 0
	for k = 1, frames do
		local l = SteerPose.brush(k / 60, POSE, true, 1)
		steps[k] = math.abs(l - prevL) / POSE.brushLeanFeet
		prevL = l
	end
	local peak = 0
	for _, d in steps do peak = math.max(peak, d) end
	check(frames == 24 and steps[1] <= 0.06 and steps[frames] <= 0.06,
		"the lean starts and ends at rest: at most 6% of it on the first and last frames at 60 fps")
	check(peak <= math.pi / (span * 60) + 1e-9, "...and no frame jumps: at most the curve's own peak rate a frame")
	local nodA, nodB = select(2, SteerPose.brush(1 / 60, POSE, false, 1)), math.rad(POSE.brushNodDeg)
	check(nodA <= 0.06 * nodB, "the nod starts at rest too")
	-- The nod tips the nose down: about +X, Roblox's right-handed turn lifts the nose, so it flips.
	local a = SteerPose.nodAngle(math.rad(2))
	local noseY = math.sin(a) -- the look vector (0, 0, -1) turned about +X by a: y = sin(a)
	check(noseY < 0, "SteerPose.nodAngle: a nod dips the nose")
	-- A brush that reaches the screen late (SteerPose.brushStart): from the beginning, or not at all.
	check(SteerPose.brushStart(0, POSE) == "start" and SteerPose.brushStart(POSE.brushLateSeconds, POSE) == "start"
		and SteerPose.brushStart(0.05, POSE) == "restart" and SteerPose.brushStart(span - 0.01, POSE) == "restart"
		and SteerPose.brushStart(span, POSE) == "skip" and POSE.brushLateSeconds == 1 / 30,
		"a brush first drawn over 1/30 s late starts from the beginning then; one already past brushLeanSeconds is skipped")
	local jump = SteerPose.brush(0.05, POSE, true, 1) - SteerPose.brush(0, POSE, true, 1)
	check(jump > 0.06 * POSE.brushLeanFeet, `(without the restart a brush 0.05 s late would jump {string.format("%.2f", jump)} ft on its first frame)`)

	-- A wait the brush cleared doesn't wobble; the mover's chip ------------------------------------
	local h = SteerHud.new()
	local function lane(wait: number, waitAt: number, t: number): any
		return { tgt = 3, dest = 3, ack = 0, wait = wait, waitAt = waitAt, tucking = false, inSide = "free", outSide = "blocked", t = t }
	end
	SteerHud.message(h, lane(1, 20, 20), STEER, SHUD)
	local w = SteerHud.message(h, lane(0, 0, 21.6), STEER, SHUD, 1, 20, 21.5)
	check(w == 0, "an outward wait a brush cleared doesn't wobble (the N4 carry-over)")
	local h2 = SteerHud.new()
	SteerHud.message(h2, lane(1, 20, 20), STEER, SHUD)
	local w2 = SteerHud.message(h2, lane(0, 0, 21.6), STEER, SHUD, 1, 20, 12)
	check(w2 == 1, "...while one dropped at the end of its wait still does (an older brush doesn't count)")
	local ch = SteerChips.new()
	check(SteerChips.brushed(ch, 30, SHUD) and not SteerChips.brushed(ch, 35, SHUD) and SteerChips.brushed(ch, 40.1, SHUD),
		"the mover's \"No room yet\" after a brush: at most once per noRoomChipEvery")
	local ch2 = SteerChips.new()
	SteerChips.shown(ch2, 50)
	check(not SteerChips.brushed(ch2, 51, SHUD) and SteerChips.brushed(ch2, 52.1, SHUD), "...and never within chipMinGap of another chip")
	-- The one-time tip on a rider's first brush (it is free), then "No room yet" under its limits.
	local ch3 = SteerChips.new()
	SteerChips.shown(ch3, 60)
	check(SteerChips.bumped(ch3, 60.5, SHUD, true) == "tip" and SteerChips.bumped(ch3, 65, SHUD, false) == nil
		and SteerChips.bumped(ch3, 71, SHUD, false) == "noRoom",
		"the first brush ever brings the tip (always, like the turn tip), and it counts as that brush's chip for the limits")
	local function prof(races: number, bumpSeen: boolean?): any
		return { totals = { races = races }, settings = { smartSteer = true }, flags = { steerTip = true, bumpTip = bumpSeen } }
	end
	local offCfg = table.clone(STEER)
	offCfg.brush = "off"
	check(Trip.riderControls(prof(STEER.introRaces), STEER).bumpTip and not Trip.riderControls(prof(STEER.introRaces, true), STEER).bumpTip
		and not Trip.riderControls(prof(STEER.introRaces - 1), STEER).bumpTip and not Trip.riderControls(prof(STEER.introRaces), offCfg).bumpTip
		and not Trip.riderControls(nil, STEER).bumpTip,
		"the tip is due once per player (data.flags.bumpTip), only with the buttons and with brushes on")
	-- Your own brush steadies your horse: no look cue for presses the server answers "steady".
	local view = { me = 1, lanes = 8, x = { 3, 6 }, off = { 0, 0 }, srv = { tgt = 3, dest = 3, ack = 0 }, cfg = STEER, steadyUntil = 10 }
	check(not SteerPredict.look(SteerPredict.new(), view, -1, 1, 9.5), "no look cue while your horse steadies after a brush")
	check(SteerPredict.look(SteerPredict.new(), view, -1, 1, 10.1), "...and the cue is back once it has")

	-- Whole races: who brushes, who pays, tau, the lock --------------------------------------------
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local events, riderMovers, nonRiderMovers, strangers, charged, tauOk, after, races = 0, 0, 0, 0, 0, true, 0, 0
	local intoOk = true
	for ci, courseId in { "dirt", "turf" } do
		for di, distanceName in { "Sprint", "Mile", "Classic" } do
			local track = TrackLayout.courses[courseId]
			local plan = TrackLayout.plan(track, TrackLayout.distances[distanceName])
			local rng = makeRng(ci * 101 + di * 7)
			local humans, riders = {}, {}
			for r = 1, 3 do
				table.insert(humans, { id = "rider" .. r, name = "Rider " .. r, rating = 50, isBot = false })
				riders["rider" .. r] = if r == 3 then "manual" else "smart"
			end
			local lanes = RaceSession.fillWithBots(humans, GameConfig.lanes, GameConfig, ThemePack, rng)
			local session = RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Silver", lanes = lanes, rng = rng })
			session:assignPosts(RaceSession.postOrder(GameConfig, #session.lanes, rng))
			local trip = Trip.start(GameConfig, session, track, plan, TripBaseline[courseId][distanceName], rng, TrackLayout, riders)
			local press = makeRng(ci * 13 + di)
			local seq, k = 0, 0
			while not trip.locked do
				local t = k * trip.dt
				for _, hm in humans do -- mashing: second presses come quickly, so brushes happen
					if press:NextNumber() < 0.35 then
						seq += 1
						Trip.submit(trip, session, hm.id, if press:NextNumber() < 0.5 then -1 else 1, seq, t)
					end
				end
				Trip.advance(trip, session.live, t)
				k += 1
			end
			races += 1
			local moved = {}
			for i = 1, trip.n do
				local sum = 0
				for j, count in Trip.brushesInto(trip, i) do
					if j == i or count < 1 then intoOk = false end
					sum += count
				end
				if sum ~= trip.brushes[i] then intoOk = false end
			end
			for _, e in trip.events do
				events += 1
				moved[e[3]] = true
				if session.lanes[e[3]].isBot or trip.riderKind[e[3]] == nil then nonRiderMovers += 1 else riderMovers += 1 end
			end
			for i = 1, trip.n do
				if Trip.brushCharge(trip, i) > 0 then
					charged += 1
					if not moved[i] then strangers += 1 end
				end
			end
			local tau = Trip.raceTau(trip)
			local ref = Trip.tau(Trip.tripValues(trip), trip.posts, trip.baselineRow, trip.cfg, Trip.brushCharges(trip))
			local noBrush = Trip.tau(Trip.tripValues(trip), trip.posts, trip.baselineRow, trip.cfg)
			for i = 1, trip.n do
				if tau[i] ~= ref[i] then tauOk = false end
				-- (a charge lowers tau, unless the clamp absorbs it: at the floor, or still at the ceiling)
				if Trip.brushCharge(trip, i) > 0 and not (tau[i] < noBrush[i] or tau[i] == trip.cfg.floor
					or (tau[i] == trip.cfg.ceiling and noBrush[i] == trip.cfg.ceiling)) then tauOk = false end
			end
			session:setTrip(tau)
			for i = 1, trip.n do
				if session.tau[i] ~= tau[i] then tauOk = false end
			end
			local before = #trip.events
			for _, hm in humans do
				seq += 1
				if Trip.submit(trip, session, hm.id, 1, seq, trip.lockT + 1) ~= "locked" then after += 1 end
			end
			Trip.step(trip, session.live, { { 1, 1 }, { 2, -1 } }, trip.lockT + 2, trip.dt)
			after += #trip.events - before
		end
	end
	check(events > 0 and riderMovers == events and nonRiderMovers == 0,
		`only riders' own presses brush: {events} brushes in {races} mashing races, no bot or Smart Steer move among them`)
	check(charged > 0 and strangers == 0, `only the mover pays: {charged} horses charged, none for a brush it didn't make`)
	check(tauOk, "the race's tau is Trip.tau with each mover's brush charge (lower for a charged mover), and RaceSession takes it")
	check(after == 0, "after the lock nothing brushes (presses refused, no events)")
	check(intoOk, "Trip.brushesInto: each rider's brushes per other horse (the [Trip] log's \"same horse 3+ times\" count) add up")
	-- And in the overlap tool's races, with the casual rider's own share.
	local strangerTool, casualRiders, casualCharged = 0, 0, 0
	for ci, course in { "dirt", "turf" } do
		for di, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
			local res = simulateRace(course, distance, 6100 + 100 * ci + di, nil, nil)
			strangerTool += res.strangerCharged
			local c = res.brushStyles.casual
			if c then
				casualRiders += c.riders
				casualCharged += c.chargedRaces
			end
		end
	end
	check(strangerTool == 0 and casualRiders > 0 and casualCharged <= math.ceil(0.05 * casualRiders),
		`whole races as the game runs them: no stranger charged, casual riders charged in {casualCharged} of {casualRiders} races`)

	-- The wiring (Roblox scripts, so read) -------------------------------------------------------
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	local rv = fs.readFile("game/src/client/RaceView.client.luau")
	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	local replay = fs.readFile("game/src/client/Replay.client.luau")
	check(string.find(rs, "SteerBrush:FireAllClients(e[3], e[4], e[5], tStart + e[1] + trip.dt, c.id)", 1, true) ~= nil
		and string.find(rs, "sendBrushes()", 1, true) ~= nil,
		"RaceService sends each brush (mover, other, dir, server time, course id last) to the course's screens")
	check(string.find(rs, "SteerControls:FireClient(p, ctl.shown, ctl.smart, ctl.tip, ctl.bumpTip, c.id)", 1, true) ~= nil
		and string.find(rs, "data.flags.bumpTip = true", 1, true) ~= nil and string.find(rs, "Trip.brushesInto(trip, i)", 1, true) ~= nil,
		"RaceService: the first-brush tip goes with SteerControls and is marked seen at that brush; the log counts brushes per horse")
	check(string.find(rv, "OnClientEvent:Connect(function(mover, other, dir, at, courseId)", 1, true) ~= nil
		and string.find(rv, "Sound.play(\"count_tick\", POSE.brushVolume, part)", 1, true) ~= nil
		and string.find(rv, "kind = \"brush\"", 1, true) ~= nil
		and string.find(rv, "local how = SteerPose.brushStart(age, POSE)", 1, true) ~= nil
		and string.find(rv, "if how == \"restart\" then b.at, age = drawnAt, 0 end", 1, true) ~= nil
		and string.find(rv, "RaceState.BrushDrawn:Fire(courseId, b.mover, b.at)", 1, true) ~= nil
		and string.find(rv, "race.own.steadyUntil = ", 1, true) ~= nil,
		"RaceView draws the brush when the race on screen gets there (late: from the beginning; past: not at all), ticks softly, records it, and tells RaceController")
	check(string.find(rc, "OnClientEvent:Connect(function(mover, _other, _dir, at, courseId)", 1, true) ~= nil
		and string.find(rc, "mover ~= myLaneIndex then return end", 1, true) ~= nil
		and string.find(rc, "RaceState.BrushDrawn.Event:Connect(function(courseId, mover, _at)", 1, true) ~= nil
		and string.find(rc, "showChip(\"Bump! Press once, then wait for a gap\", SHUD.tipSeconds)", 1, true) ~= nil
		and string.find(rc, "showChip(\"No room yet\")", 1, true) ~= nil,
		"only the mover's rider gets a chip, as the brush is drawn, and only with the buttons: the one-time tip, then \"No room yet\"")
	check(string.find(replay, "SteerPose.brush(t - e.t, GameConfig.steerView, e.mover == i, e.dir)", 1, true) ~= nil,
		"replays play the recorded brush's lean and nod, no text")
	local grownUps = fs.readFile("game/src/client/GrownUps.client.luau")
	check(string.find(grownUps, "A brush costs the horse that bumped a tiny bit (a third of a point at most), never the horse that was bumped.", 1, true) ~= nil,
		"the grown-ups page: a brush costs the horse that bumped a tiny bit, never the bumped horse")
	for _, src in { rv, rc, replay } do
		local lower = string.lower(src)
		check(string.find(lower, "stumble(", 1, true) == nil and string.find(lower, "\"ouch", 1, true) == nil
			and string.find(lower, "injur", 1, true) == nil, "no stumble, no hurt horse anywhere a brush is drawn")
	end
end
