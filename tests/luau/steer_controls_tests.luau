--!strict
-- Steering stage S3 (D-054): the rider controls. RaceInput's key table and stick flick (none of
-- them a tap), Trip.submit (in this race, before the lock, dir, seq, spam) and Trip.acceptIntent
-- (the request gap, the queue, the track's edges), requests applied on the next tick and dropped
-- at the lock, Smart Steer resuming after presses without ever moving a rider outward, Smart Steer
-- off (lanes change only on a press), disconnects, the smartSteer setting, whole races with
-- riders pressing (no overlaps on screen), and the copy. Run from run_all.luau.
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
local RaceInput = require("../../game/src/shared/RaceInput")
local Profile = require("../../game/src/shared/Profile")
local simulateRace = require("./race_overlap")

local EPS = 1e-9
local STEER = GameConfig.steering
local SHUD = GameConfig.steerHud
local COURSES = { "dirt", "turf" }
local DISTANCES = { "Sprint", "Mile", "Classic", "Marathon" }

local function makeRng(seed0: number)
	local seed = seed0
	return {
		NextNumber = function(_self): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Keys and buttons ------------------------------------------------------------------------
	local expect = { A = -1, Left = -1, DPadLeft = -1, D = 1, Right = 1, DPadRight = 1 }
	local tableOk = true
	for name, dir in expect do
		if RaceInput.steerDir(name) ~= dir or not RaceInput.isSteerInput(name) then tableOk = false end
	end
	for name in RaceInput.STEER do
		if expect[name] == nil then tableOk = false end
	end
	check(tableOk, "RaceInput: A, Left and DPadLeft steer in; D, Right and DPadRight steer out; nothing else")
	check(RaceInput.isSteerInput("Thumbstick1") and RaceInput.steerDir("Thumbstick1") == nil,
		"the left stick steers by flicks, never as a press")
	local others = true
	for _, name in { "Space", "Return", "KeypadEnter", "ButtonA", "ButtonR2", "W", "S", "Up", "Down", "E", "C", "X",
		"ButtonB", "ButtonX", "ButtonY", "ButtonL1", "ButtonR1", "DPadUp", "DPadDown", "Thumbstick2" } do
		if RaceInput.isSteerInput(name) then others = false end
	end
	check(others, "taps, forward and back, prompts and the other buttons don't steer")
	local shared = false
	for _, name in GameConfig.tapKeys do
		if RaceInput.isSteerInput(name) then shared = true end
	end
	check(not shared, "no steering key or button is a tap key (D-055): a steering press never scores as a tap")
	local d1, a1 = RaceInput.flick(true, 0.6)
	local d2, a2 = RaceInput.flick(true, 0.61)
	local d3, a3 = RaceInput.flick(a2, 0.95)
	local d4, a4 = RaceInput.flick(a3, 0.3)
	local d5, a5 = RaceInput.flick(a4, 0.29)
	local d6, a6 = RaceInput.flick(a5, -0.7)
	check(d1 == nil and a1 and d2 == 1 and not a2 and d3 == nil and not a3, "a stick flick fires past 0.6, once")
	check(d4 == nil and not a4 and d5 == nil and a5 and d6 == -1 and not a6, "the stick re-arms under 0.3; a flick left steers in")

	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	local steerAt = string.find(rc, "local dir = RaceInput.steerDir(input.KeyCode.Name)", 1, true)
	local tapAt = string.find(rc, "elseif TAP_KEYS[input.KeyCode] then", 1, true)
	check(steerAt ~= nil and tapAt ~= nil and steerAt < tapAt, "RaceController takes steering keys out before the tap keys")
	check(string.find(string.lower(rc), "lost a place", 1, true) == nil, "the race screen never says \"lost a place\"")
	check(SHUD.minButtonPx >= 88 and SHUD.buttonPx >= SHUD.minButtonPx, "the ◀ ▶ buttons are at least 88 px")

	-- Trip.acceptIntent: the request gap, the queue, the edges, the lock ----------------------
	local track = TrackLayout.courses.dirt
	local plan = TrackLayout.plan(track, TrackLayout.distances.Mile)
	local geo = TrackLayout.phaseA(track, plan)
	local race = Trip.raceParams(GameConfig)
	local function fresh(posts: { number }): any
		local u = table.create(2 * #posts, 0.5)
		return Trip.new(posts, table.create(#posts, 1 / #posts), u, geo, STEER, table.create(#posts, "manual"), race)
	end
	local st = fresh({ 4, 7 })
	check(Trip.acceptIntent(st, 1, -1, 1) == "accepted", "an idle rider's press is accepted")
	check(Trip.acceptIntent(st, 1, -1, 1.1) == "queued", "a press during a lane change waits (one queued)")
	check(Trip.acceptIntent(st, 1, -1, 1.2) == "rate", "a third press is refused: the request gap and the queue")
	check(Trip.acceptIntent(st, 1, 1, 1.3) == "cancelled", "the opposite press cancels the one waiting")
	check(Trip.acceptIntent(st, 1, 0, 1.4) == "invalid" and Trip.acceptIntent(st, 1, 2, 1.4) == "invalid", "dir is -1 or 1")
	local gap = fresh({ 4, 7 })
	Trip.step(gap, { 0.5, 0.5 }, { { 1, -1 } }, 0, 0.1)
	local glidingAnswer = Trip.acceptIntent(gap, 1, 1, 0.3)
	check(gap.tgt[1] == 3 and glidingAnswer == "queued", "a press while gliding waits for the request gap")
	local edge = fresh({ 1, 8 })
	check(Trip.acceptIntent(edge, 1, -1, 1) == "bounds" and Trip.acceptIntent(edge, 2, 1, 1) == "bounds",
		"no press past the rail or the outside lane")
	Trip.lock(edge)
	check(Trip.acceptIntent(edge, 1, 1, 50) == "locked", "after the lock every press is refused")

	-- Trip.submit and the next tick -------------------------------------------------------------
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local humans = {
		{ id = "1", name = "Ava", rating = 60, isBot = false },
		{ id = "2", name = "Ben", rating = 55, isBot = false },
	}
	local field = RaceSession.fillWithBots(humans, 8, GameConfig, ThemePack, makeRng(1))
	local function session(seed: number): any
		local s = RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Bronze", lanes = field, rng = makeRng(seed) })
		s:assignPosts(RaceSession.postOrder(GameConfig, 8, makeRng(seed + 17)))
		return s
	end
	local s = session(3)
	local trip = Trip.start(GameConfig, s, track, plan, TripBaseline.dirt.Mile, makeRng(4), TrackLayout, { ["2"] = true })
	local i1, i2 = s:laneIndex("1") :: number, s:laneIndex("2") :: number
	check(trip.smart[i1] and not trip.smart[i2], "a rider who turned Smart Steer off steers alone; the rest have it")
	local botId = nil
	for _, lane in s.lanes do
		if lane.isBot then botId = lane.id end
	end
	check(Trip.submit(trip, s, "999", -1, 1, 0.51) == "notRacing", "a player not in this race is refused")
	check(Trip.submit(trip, s, botId, -1, 1, 0.51) == "notRacing", "nobody steers a bot")
	check(Trip.submit(trip, s, "1", 0, 1, 0.51) == "invalid" and Trip.submit(trip, s, "1", "1", 1, 0.51) == "invalid"
		and Trip.submit(trip, s, "1", nil, 1, 0.51) == "invalid", "dir must be -1 or 1")
	check(Trip.submit(trip, s, "1", -1, "x", 0.51) == "invalid" and Trip.submit(trip, s, "1", -1, 0 / 0, 0.51) == "invalid",
		"seq must be a number")
	-- Rider 1 presses the way with room for two lanes, eight times and more in under 0.1 s.
	local d = if trip.x[i1] <= GameConfig.lanes - 2 then 1 else -1
	check(Trip.submit(trip, s, "1", d, 1, 0.51) == "sent", "a rider's press waits for the next tick")
	check(Trip.submit(trip, s, "1", d, 1, 0.52) == "invalid", "a repeated seq is dropped")
	local sent = 1
	for k = 2, 12 do
		if Trip.submit(trip, s, "1", d, k, 0.51 + k * 0.004) == "sent" then sent += 1 end
	end
	check(sent == STEER.requestsPerSecond, `spam: past {STEER.requestsPerSecond} presses in a second the rest are dropped`)
	Trip.advance(trip, s.live, 0.55)
	local answered = 0
	for _, count in trip.answers do answered += count end
	check(answered == 0 and #trip.pending == sent, "nothing applies before the next tick")
	Trip.advance(trip, s.live, 0.6)
	check((trip.answers.accepted or 0) == 1 and (trip.answers.queued or 0) == 1 and (trip.answers.rate or 0) == sent - 2
		and #trip.pending == 0, "the next tick applies them in arrival order: one accepted, one queued, the rest refused")
	check(Trip.submit(trip, s, "1", d, 30, 1.6) == "sent", "a second later the rider may press again")
	Trip.submit(trip, s, "2", -1, 1, trip.lockT - 0.05)
	Trip.advance(trip, s.live, trip.lockT)
	check(trip.locked and #trip.pending == 0, "requests still waiting at the lock are dropped")
	check(Trip.submit(trip, s, "1", d, 31, trip.lockT + 1) == "locked", "requests after the lock are ignored")

	-- Smart Steer: presses pause it; it resumes and never moves a rider outward ----------------
	local outward, inward, checkedTicks = 0, 0, 0
	local stayed, manualMoves, manualAnswers, disconnectMoved = true, 0, 0, false
	for ci, course in COURSES do
		for di, distance in DISTANCES do
			for k = 1, 3 do
				local seed = 1000 * ci + 100 * di + k
				local trk = TrackLayout.courses[course]
				local pl = TrackLayout.plan(trk, TrackLayout.distances[distance])
				-- Rider 1 (Smart Steer on) presses three times early, in or out, then leaves it alone.
				local ss = session(seed)
				local tr = Trip.start(GameConfig, ss, trk, pl, TripBaseline[course][distance], makeRng(seed + 1), TrackLayout)
				local i = ss:laneIndex("1") :: number
				local dir = if k % 2 == 0 then 1 else -1
				for n, at in { 0.21, 0.91, 1.61 } do Trip.submit(tr, ss, "1", dir, n, at) end
				local resumeAt = 1.7 + STEER.smart.resumeSeconds
				local last, t = tr.x[i], 0
				while not tr.locked do
					Trip.advance(tr, ss.live, t)
					if t > resumeAt + EPS then
						checkedTicks += 1
						if tr.x[i] > last + EPS then outward += 1 end
						if tr.x[i] < last - EPS then inward += 1 end
					end
					last = tr.x[i]
					t += tr.dt
				end
				-- Rider 2 with Smart Steer off: never presses here, so never moves; then, pressing,
				-- moves only as far as its presses were taken; a disconnect hands it to Smart Steer.
				local sm = session(seed + 50)
				local tm = Trip.start(GameConfig, sm, trk, pl, TripBaseline[course][distance], makeRng(seed + 2), TrackLayout, { ["2"] = true })
				local j = sm:laneIndex("2") :: number
				local post, tt = tm.x[j], 0
				while not tm.locked do
					Trip.advance(tm, sm.live, tt)
					if tm.x[j] ~= post then stayed = false end
					tt += tm.dt
				end
				local sp = session(seed + 60)
				local tp = Trip.start(GameConfig, sp, trk, pl, TripBaseline[course][distance], makeRng(seed + 3), TrackLayout, { ["2"] = true })
				local jp = sp:laneIndex("2") :: number
				local seq, lastTgt, tq = 0, tp.tgt[jp], 0
				local pressRng = makeRng(seed + 4)
				while not tp.locked do
					if pressRng:NextNumber() < 0.08 then
						seq += 1
						Trip.submit(tp, sp, "2", if pressRng:NextNumber() < 0.6 then -1 else 1, seq, tq)
					end
					Trip.advance(tp, sp.live, tq)
					if tp.tgt[jp] ~= lastTgt then manualMoves += 1 end
					lastTgt = tp.tgt[jp]
					tq += tp.dt
				end
				manualAnswers += (tp.answers.accepted or 0) + (tp.answers.queued or 0)
				local sd = session(seed + 70)
				local td = Trip.start(GameConfig, sd, trk, pl, TripBaseline[course][distance], makeRng(seed + 5), TrackLayout, { ["2"] = true })
				local jd = sd:laneIndex("2") :: number
				local startX = td.x[jd]
				Trip.setSmart(td, jd, true) -- what RaceService does when the rider leaves
				local td2 = 0
				while not td.locked do
					Trip.advance(td, sd.live, td2)
					td2 += td.dt
				end
				if td.x[jd] < startX then disconnectMoved = true end
			end
		end
	end
	check(checkedTicks > 1000 and outward == 0, `Smart Steer resumes after a rider's presses and never moves them outward ({checkedTicks} ticks)`)
	check(inward > 0, "...and does head in again after the pause")
	check(stayed, "Smart Steer off: a rider who never presses keeps their lane to the lock")
	check(manualMoves > 0 and manualMoves <= manualAnswers, `Smart Steer off: lanes change only on presses ({manualMoves} changes from {manualAnswers} taken presses)`)
	check(disconnectMoved, "a rider who leaves goes to Smart Steer, which heads in")

	-- Whole races with riders pressing at random: nobody overlaps on screen --------------------
	local races, overlaps, wrongOrder = 0, 0, 0
	for ci, course in COURSES do
		for di, distance in DISTANCES do
			for k = 1, 2 do
				local res = simulateRace(course, distance, 7000 + 100 * ci + 10 * di + k, nil, { riders = 2, manual = k == 2 })
				races += 1
				overlaps += res.before + res.after
				if not res.orderOk then wrongOrder += 1 end
			end
		end
	end
	check(overlaps == 0, `riders pressing ◀ ▶ at random: no overlapping horses in {races} races ({overlaps} frames)`)
	check(wrongOrder == 0, "...and the order across the line is still the result")

	-- Settings and copy -------------------------------------------------------------------------
	local now = 20000 * 86400
	check(Profile.new(now).settings.smartSteer == true, "Smart Steer is on by default")
	local junk = Profile.migrate({ settings = { visits = "Friends", smartSteer = "no" } }, now)
	local off = Profile.migrate({ settings = { visits = "Friends", smartSteer = false } }, now)
	local old = Profile.migrate({ settings = { visits = "Friends" } }, now)
	check(junk.settings.smartSteer == true and off.settings.smartSteer == false and old.settings.smartSteer == true,
		"Smart Steer repaired on load: always a boolean, on unless turned off")
	check(Profile.view(off, now, GameConfig.energy).settings.smartSteer == false, "the owner sees their Smart Steer setting")
	local svc = fs.readFile("game/src/server/SettingsService.server.luau")
	check(string.find(svc, "key == \"smartSteer\" and typeof(value) == \"boolean\"", 1, true) ~= nil,
		"SettingsService takes Smart Steer as a boolean only")
	local grownUps = fs.readFile("game/src/client/GrownUps.client.luau")
	check(string.find(grownUps, "Riders can steer a little: the best trip is worth about 2 points of a 100-point ride, and nothing buys it.", 1, true) ~= nil
		and string.find(grownUps, "FireServer(\"smartSteer\", v)", 1, true) ~= nil,
		"For grown-ups explains steering; Settings has the Smart Steer toggle")
	check(math.abs(STEER.ceiling / 0.02 - 2) < 1e-12, "the best trip is 2 points of S (ceiling 0.04, 1 point = 0.02)")
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	check(string.find(rs, "Trip.submit(cur.trip, cur.session, tostring(player.UserId), dir, seq, now() - cur.tStart)", 1, true) ~= nil
		and string.find(rs, "not cur.steers[player]", 1, true) ~= nil,
		"SteerRequest goes through Trip.submit, only for riders who have the buttons")
	check(string.find(rs, "Trip.setSmart(trip, i, true)", 1, true) ~= nil, "RaceService hands a rider who leaves to Smart Steer")
end
