--!strict
-- Steering stage S2 (D-054): Trip.luau against the Python reference (tests/fixtures/trip.json,
-- 1e-9), GameConfig.steering and TripBaseline against their Python sources, RaceMath.liveChances
-- with an extra exponent, RaceSession's trip (tau, setTrip, tripGain), the assignPosts
-- completeness guard, and the race helpers RaceService uses. Run from run_all.luau after
-- tests/fixtures/make_fixtures.py.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

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
local simulateRace = require("./race_overlap")

local function makeRng(seed0: number)
	local seed = seed0
	local rng = { calls = 0 }
	function rng.NextNumber(self): number
		self.calls += 1
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	return rng
end

local function deepEqual(a: any, b: any, tol: number): boolean
	if type(a) ~= type(b) then return false end
	if type(a) == "number" then return math.abs(a - b) <= tol end
	if type(a) ~= "table" then return a == b end
	for k, v in a do
		if not deepEqual(v, b[k], tol) then return false end
	end
	for k in b do
		if a[k] == nil then return false end
	end
	return true
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local data = serde.decode("json", fs.readFile("tests/fixtures/trip.json"))
	local baselineJson = serde.decode("json", fs.readFile("tests/fixtures/trip_baseline.json"))

	-- GameConfig mirrors the Python CONFIG and RACE; TripBaseline is the generated table.
	-- GameConfig.steering mirrors CONFIG, except two game-only switches (S1's post draw and S3's
	-- spam limit on steering requests) and the scale, a documented switch (0 = cosmetic; S3 ships
	-- the model's 1). Parity runs at the fixture's scale. Since N3 the config has D-057's motion
	-- and press rules on, so trip.json records every key (trip.config_record).
	local D057_KEYS = {}
	for key in Trip.D057_OFF do table.insert(D057_KEYS, key) end
	local steering = table.clone(GameConfig.steering)
	steering.drawPosts = nil
	steering.requestsPerSecond = nil
	steering.scale = nil
	local pyCfg = table.clone(data.cfg)
	pyCfg.scale = nil
	check(deepEqual(steering, pyCfg, 0), "GameConfig.steering mirrors CONFIG in src/trip.py (the scale switch aside)")
	check(GameConfig.steering.scale >= 0 and GameConfig.steering.scale <= 1, "the steering scale is between 0 (cosmetic) and 1")
	local race = Trip.raceParams(GameConfig)
	check(deepEqual(race, data.race, 0), "Trip.raceParams(GameConfig) mirrors RACE in src/trip.py")
	check(deepEqual(TripBaseline, baselineJson.baseline, 1e-15), "TripBaseline.luau is trip_baseline.json's baseline")

	-- Parity with src/trip.py: every scripted run, tick by tick. Lune's JSON reader can land a
	-- number one ulp off, which an exact boundary (two horses exactly holdGap apart) turns into a
	-- different race; so the inputs come from the exact strings (Luau's tonumber is exact), and
	-- the config and race numbers from GameConfig's literals (checked equal to the fixture above).
	local function exactList(list: { string }): { number }
		local out = table.create(#list)
		for i, s in list do out[i] = tonumber(s) :: number end
		return out
	end
	local function runConfig(run: any): any
		local cfg = table.clone(GameConfig.steering)
		cfg.drawPosts = nil
		cfg.requestsPerSecond = nil
		cfg.scale = data.cfg.scale -- the fixture's scale, whatever the game ships
		cfg.smart = table.clone(cfg.smart)
		if run.cfg then -- a run with other settings: copy the ones that differ (simple values)
			for key, value in run.cfg do
				if type(value) ~= "table" and value ~= data.cfg[key] then cfg[key] = value end
			end
			for key, value in run.cfg.smart do
				if value ~= data.cfg.smart[key] then cfg.smart[key] = value end
			end
		end
		return cfg
	end
	local dt = 1 / GameConfig.steering.tickHz
	local full = runConfig({}) -- GameConfig.steering at the fixture's scale, every key
	local runsOk, answersOk, snapsOk, lockOk, tripOk = 0, true, true, true, true
	for r, run in data.runs do
		local cfg = runConfig(run)
		local q, p1, uniforms = exactList(run.exact.q), exactList(run.exact.p1), exactList(run.exact.uniforms)
		local track = TrackLayout.courses[run.course]
		local plan = TrackLayout.plan(track, TrackLayout.distances[run.distance])
		local geo = TrackLayout.phaseA(track, plan)
		local byTick: { [number]: { { number } } } = {}
		for _, intent in run.intents do
			local tick = intent[1]
			byTick[tick] = byTick[tick] or {}
			table.insert(byTick[tick], { intent[2], intent[3] })
		end
		local st = Trip.new(run.posts, q, uniforms, geo, cfg, run.kinds, race)
		local answers = {}
		local snapIndex = 1
		for tick = 0, run.ticks - 1 do
			local live = if tick < run.switchTick then q else p1
			for _, a in Trip.step(st, live, byTick[tick] or {}, tick * dt, dt) do table.insert(answers, a) end
			if tick % 10 == 0 or tick == run.ticks - 1 then
				local snap = run.snapshots[snapIndex]
				snapIndex += 1
				if not snap or snap.tick ~= tick then
					snapsOk = false
				else
					for i = 1, st.n do
						if not (close(st.x[i], snap.x[i], 1e-9) and close(st.off[i], snap.off[i], 1e-9) and st.tgt[i] == snap.tgt[i]) then
							if snapsOk then print(`trip run {r} tick {tick} lane {i}: x {st.x[i]} vs {snap.x[i]}, off {st.off[i]} vs {snap.off[i]}`) end
							snapsOk = false
						end
					end
				end
			end
		end
		if #answers ~= #run.answers then answersOk = false end
		for k = 1, math.min(#answers, #run.answers) do
			if answers[k] ~= run.answers[k] then answersOk = false end
		end
		for i = 1, st.n do
			if not close(st.x[i], run.lockX[i], 1e-9) then lockOk = false end
		end
		Trip.lock(st)
		local before = { x = table.clone(st.x), ground = table.clone(st.ground), draft = table.clone(st.draft) }
		local lateIntents = {}
		for _, li in run.afterLock do table.insert(lateIntents, { li[1], li[2] }) end
		local late = Trip.step(st, p1, lateIntents, run.ticks * dt, dt)
		if #late ~= #run.afterLockAnswers then lockOk = false end
		for k, a in late do
			if a ~= "locked" or a ~= run.afterLockAnswers[k] then lockOk = false end
		end
		if not (deepEqual(before.x, st.x, 0) and deepEqual(before.ground, st.ground, 0) and deepEqual(before.draft, st.draft, 0)) then
			lockOk = false
		end
		local tr = Trip.tripValues(st)
		local tau = Trip.tau(tr, run.posts, data.baseline[run.course][run.distance], cfg)
		for i = 1, st.n do
			if not (close(tr[i], run.trip[i], 1e-9) and close(tau[i], run.tau[i], 1e-9)
				and close(st.ground[i], run.ground[i], 1e-9) and close(st.draft[i], run.draft[i], 1e-9)
				and Trip.stars(tau[i], cfg) == run.stars[i]) then
				tripOk = false
			end
		end
		runsOk += 1
	end
	check(runsOk == #data.runs and #data.runs == 200, "all 200 trip.json runs replayed")
	check(answersOk, "Trip answers every press as src/trip.py does")
	check(snapsOk, "lanes, offsets and targets match src/trip.py every 10 ticks (1e-9)")
	check(lockOk, "lanes at the lock match; presses after the lock are refused and change nothing")
	check(tripOk, "ground, draft, trip, tau and stars match src/trip.py (1e-9)")

	-- Guards: a bad lane index errors (Python raises).
	do
		local track = TrackLayout.courses.dirt
		local plan = TrackLayout.plan(track, TrackLayout.distances.Classic)
		local st = Trip.new({ 3, 4 }, { 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }, TrackLayout.phaseA(track, plan), full, { "manual", "manual" }, data.race)
		check(not pcall(Trip.acceptIntent, st, 0, -1, 0), "lane 0 is refused")
		check(not pcall(Trip.acceptIntent, st, 3, -1, 0), "a lane past the field is refused")
		check(not pcall(Trip.step, st, { 0.5, 0.5 }, { { 2.5, -1 } }, 0, dt), "a fractional lane index is refused")
		check(not pcall(Trip.new, { 0, 4 }, { 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }, st.geo, full, nil, data.race), "post 0 is refused")
		check(not pcall(Trip.tau, { 0, 0 }, { 1, 9 }, table.create(8, 0), full), "post 9 is refused by tau")
		local old = table.clone(full)
		for _, key in D057_KEYS do old[key] = nil end
		check(not pcall(Trip.new, { 3, 4 }, { 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }, st.geo, old, nil, data.race),
			"a config without the D-057 keys is refused (Python raises too)")
		local bad = table.clone(full)
		bad.glide = "curvy"
		check(not pcall(Trip.new, { 3, 4 }, { 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }, st.geo, bad, nil, data.race), "an unknown glide is refused")
	end

	-- RaceMath.liveChances with an extra exponent (crowd boost + trip).
	local rm = serde.decode("json", fs.readFile("tests/fixtures/race_math.json"))
	local extraOk, zeroSame = true, true
	for k, case in rm.extraCases do
		local q = RaceMath.baseChances(case.ratings, case.cfg)
		local R = RaceMath.skills(case.scores, case.cfg)
		local p = RaceMath.liveChances(q, R, case.cfg, case.extra)
		local p0 = RaceMath.liveChances(q, R, case.cfg)
		local finish = RaceMath.drawFinish(p, (function()
			local j = 0
			return { NextNumber = function(_self) j += 1; return case.uniforms[j] end }
		end)())
		for i = 1, #q do
			if not (close(p[i], case.p[i], 1e-9) and close(p0[i], case.p0[i], 1e-9) and finish[i] == case.finish[i]) then extraOk = false end
		end
		if (k - 1) % 10 == 0 then -- all-zero extras
			for i = 1, #q do
				if p[i] ~= p0[i] then zeroSame = false end
			end
		end
	end
	check(#rm.extraCases == 100 and extraOk, "liveChances(q, R, cfg, extra) matches Python (1e-9)")
	check(zeroSame, "zero extras give exactly the plain chances")

	-- RaceSession: the trip.
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
	local humans = {
		{ id = "1", name = "Ava", rating = 60, isBot = false },
		{ id = "2", name = "Ben", rating = 55, isBot = false },
	}
	local field = RaceSession.fillWithBots(humans, 8, GameConfig, ThemePack, makeRng(1))
	local function build(seed: number)
		local s = RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Bronze", lanes = field, rng = makeRng(seed) })
		s:paceSchedule({ { 10, 36 } }, { { 10, 22 }, { 22, 34 }, { 34, 46 } })
		return s
	end
	local function play(s, withTrip: { number }?, lockAfter: number)
		for seg, kind in GameConfig.segments do
			if kind == "pace" then
				local taps = {}
				for _, p in s:pacePasses(seg) do table.insert(taps, PaceMeter.idealTime(p) + 0.04) end
				s:scorePace("1", seg, taps)
			end
			s:closeSegment(seg)
			if seg == lockAfter and withTrip then s:setTrip(withTrip) end
		end
		return s:finish()
	end
	local zeros = table.create(8, 0)
	local plain, zeroed = build(11), build(11)
	local ra = play(plain, nil, 1)
	local rb = play(zeroed, zeros, 1)
	local sameLive, sameFinish = true, true
	for i = 1, 8 do
		if plain.live[i] ~= zeroed.live[i] then sameLive = false end
		if ra.order[i] ~= rb.order[i] then sameFinish = false end
	end
	check(sameLive and sameFinish, "zero tau: live chances and the finish exactly as before")
	check(plain:ridingGain(1) == zeroed:ridingGain(1) and zeroed:tripGain(1) == 0, "zero tau: riding gain unchanged, trip gain 0")

	local a, b = build(12), build(12)
	a:closeSegment(1)
	b:closeSegment(1)
	local beforeLock = table.clone(b.live)
	check(deepEqual(a.live, b.live, 0) and deepEqual(b.tau, zeros, 0), "before the lock tau is 0 and changes nothing")
	local tau = { 0.04, -0.02, 0, 0, 0, 0, 0.5, -0.5 }
	b:setTrip(tau)
	check(b.tau[7] == GameConfig.steering.ceiling and b.tau[8] == GameConfig.steering.floor, "setTrip clamps tau")
	check(b.live[1] > beforeLock[1] and b.live[2] < beforeLock[2], "tau applies at setTrip: a good trip raises the chance")
	local w1 = RaceMath.liveChances(b.q, RaceMath.skills(b:scoresSoFar(), b.mathCfg), b.mathCfg, b.tau)
	local tilted = true
	for i = 1, 8 do
		if not close(b.live[i], w1[i], 1e-12) then tilted = false end
	end
	check(tilted, "the exponent equals step 5 (kappa * R + tau, crowd 0) within 1e-12; the game folds tau/kappa into R")
	a:closeSegment(2)
	b:closeSegment(2)
	check(b.live[1] / a.live[1] > 1, "tau stays in at the next checkpoint")
	local gainOk = true
	for i = 1, 8 do
		if b.tau[i] == 0 and b:tripGain(i) ~= 0 then gainOk = false end
	end
	check(gainOk, "tripGain is 0 for a zero trip")

	-- assignPosts completeness: every table the session holds is classified, so a new per-lane
	-- table can't be left behind by the post draw; and every per-lane table moves.
	do
		local s = build(13)
		s:setCrowd(2, 0.02)
		s:setTrip({ 0.01, 0.02, 0.03, 0.04, -0.01, -0.02, 0.005, 0 })
		s:burstSpec()
		local known = {}
		for _, list in { RaceSession.PER_LANE, RaceSession.PER_SEGMENT_LANE, RaceSession.NOT_PER_LANE } do
			for _, key in list do known[key] = true end
		end
		local unclassified = {}
		for key, value in s :: any do
			if type(value) == "table" and not known[key] then table.insert(unclassified, tostring(key)) end
		end
		check(#unclassified == 0, "every session table is classified for assignPosts: " .. table.concat(unclassified, ", "))
		-- (assignPosts refuses after a checkpoint, so build a fresh one at the gate)
		local g = build(13)
		g:setCrowd(2, 0.02)
		g.tau = { 0.01, 0.02, 0.03, 0.04, -0.01, -0.02, 0.005, 0 } -- as if set; assignPosts only moves it
		local snapshot = {}
		for _, key in RaceSession.PER_LANE do snapshot[key] = table.clone((g :: any)[key]) end
		local order = { 3, 1, 4, 8, 6, 2, 7, 5 }
		g:assignPosts(order)
		local moved = true
		for _, key in RaceSession.PER_LANE do
			for post, old in order do
				if (g :: any)[key][post] ~= snapshot[key][old] then moved = false end
			end
		end
		check(moved, "assignPosts moves every PER_LANE table, tau included")
	end

	-- Race helpers: steering off is today's path; on, fixed ticks to the lock, then tau.
	do
		local s = build(14)
		local track = TrackLayout.courses.turf
		local plan = TrackLayout.plan(track, TrackLayout.distances.Mile)
		local offCfg = table.clone(GameConfig)
		offCfg.steering = table.clone(GameConfig.steering)
		offCfg.steering.enabled = false
		local rng = makeRng(5)
		check(Trip.start(offCfg, s, track, plan, TripBaseline.turf.Mile, rng, TrackLayout) == nil and rng.calls == 0,
			"enabled = false: no trip, no draws")
		local offsets, lanes = Trip.frame(nil, s, s.live, 0.3, GameConfig.raceShape, 0.1)
		check(deepEqual(offsets, s:displayOffsets(s.live, 0.3, GameConfig.raceShape), 0) and lanes == nil,
			"enabled = false: RaceOffsets carries today's offsets and no lanes")

		local onRng = makeRng(5)
		local st = Trip.start(GameConfig, s, track, plan, TripBaseline.turf.Mile, onRng, TrackLayout)
		check(st ~= nil and onRng.calls == 16, "steering on: two uniforms per lane, nothing else drawn")
		local everyoneSmart = true
		for i, lane in s.lanes do
			if not st.smart[i] then everyoneSmart = false end
			if not lane.isBot and (st.home[i] ~= GameConfig.steering.smart.homeLane or st.turnLead[i] ~= GameConfig.steering.smart.turnLeadSeconds) then
				everyoneSmart = false
			end
		end
		check(everyoneSmart, "everyone steers with Smart Steer; riders with its plain settings (nobody turned it off)")
		-- A late, jumpy server reaches exactly the same state as one stepping on time.
		local ref = Trip.start(GameConfig, s, track, plan, TripBaseline.turf.Mile, makeRng(5), TrackLayout)
		local t, locked = 0, false
		while not locked do
			locked = Trip.advance(st, s.live, t)
			t += 0.37
		end
		local k = 0
		while k * ref.dt < ref.lockT - Trip.EPS do
			Trip.step(ref, s.live, {}, k * ref.dt, ref.dt)
			k += 1
		end
		Trip.lock(ref)
		check(st.locked and deepEqual(st.x, ref.x, 0) and deepEqual(st.ground, ref.ground, 0) and deepEqual(st.draft, ref.draft, 0),
			"Trip.advance steps the same fixed ticks however late the calls")
		local tauRace = Trip.raceTau(st)
		local inRange = true
		for _, v in tauRace do
			if v < GameConfig.steering.floor or v > GameConfig.steering.ceiling then inRange = false end
		end
		check(inRange, "race tau stays within the floor and ceiling")
		check(not Trip.advance(st, s.live, t + 10), "nothing steps after the lock")
		-- After the lock: race-shape offsets and cosmetic lanes that make room.
		local liveNow = table.clone(s.live)
		local viewBefore = table.clone(st.view)
		local o1, l1 = Trip.frame(st, s, liveNow, 0, GameConfig.raceShape, 0.25, st.lockT + 0.25)
		local eased = true
		local targets = s:displayOffsets(liveNow, 0, GameConfig.raceShape)
		for i = 1, #o1 do
			if o1[i] ~= st.view[i] then eased = false end
			-- each moves toward its race-shape target, no faster than the cap (or is held back)
			if math.abs(o1[i] - viewBefore[i]) > GameConfig.raceView.maxGapFeetPerSecond * 0.25 + 1e-9 + GameConfig.steering.holdGap then
				eased = false
			end
		end
		check(eased and l1 ~= nil, "after the lock: the offsets the screen shows (eased toward the race shape, held), plus lanes")
		check(targets ~= nil, "race-shape targets exist")
		local inside = true
		for _, x in l1 :: { number } do
			if x < 1 or x > GameConfig.lanes then inside = false end
		end
		check(inside, "cosmetic lanes stay on the track")
	end
	-- Overlaps on screen (B1 of the S2 review): whole races as RaceService runs them and RaceView
	-- draws them, steering at scale 1 (as shipped from S3) and 0 (cosmetic). No horse may come within
	-- half a lane and 6 ft of another anywhere, and the order across the line must be the result.
	-- (tests/luau/overlap_report.luau runs the same at any size: 960 races, 0 overlaps.)
	do
		local s1 = table.clone(GameConfig)
		s1.steering = table.clone(GameConfig.steering)
		s1.steering.scale = 0
		local races, overlaps, wrongOrder, cell, jerks = 0, 0, 0, 0, 0
		for _, course in { "dirt", "turf" } do
			for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
				cell += 1
				for k = 1, 8 do
					local s = simulateRace(course, distance, cell * 7907 + k * 104729, if k % 2 == 0 then s1 else nil)
					races += 1
					overlaps += s.before + s.after
					jerks += s.jerks + s.jerksBefore
					if not s.orderOk then wrongOrder += 1 end
				end
			end
		end
		check(races == 64 and overlaps == 0, `no overlapping horses on screen in {races} races ({overlaps} frames)`)
		check(wrongOrder == 0, "the order across the line is the result in every race")
		check(jerks == 0, `no horse drawn jerking back (over 20 ft/s), before or after the lock, in {races} races ({jerks} frames)`)
	end
	do -- make room: a horse closing on another in its lane moves out
		local track = TrackLayout.courses.dirt
		local plan = TrackLayout.plan(track, TrackLayout.distances.Sprint)
		local st = Trip.new({ 2, 2 }, { 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }, TrackLayout.phaseA(track, plan), full, { "manual", "manual" }, race)
		Trip.lock(st)
		st.view = { 10, -10 } -- the second horse 20 ft behind the first in lane 2, but its place is ahead
		local lanes = Trip.cosmetic(st, { 10, 30 }, 0.1, 10)
		for _ = 1, 10 do lanes = Trip.cosmetic(st, { 10, 30 }, 0.1, 10) end
		check(lanes[1] == 2 and lanes[2] == 3, "a horse about to pass another in its lane moves out first")
		check(st.view[2] > 0, "...and goes on toward its place")
		lanes = Trip.cosmetic(st, { 10, 30 }, 0.1, 11)
		check(lanes[2] == 3, "make-room lanes don't jump back")
		local held = Trip.new({ 1, 1 }, { 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }, TrackLayout.phaseA(track, plan), full, { "manual", "manual" }, race)
		Trip.lock(held)
		held.view = { 0, -10 }
		held.shown, held.shownTgt = { 1, 1 }, { 1, 1 }
		Trip.viewStep(held, { 0, 20 }, 0.5, 30) -- wants to pass at once, no time to move out
		check(held.view[1] - held.view[2] >= GameConfig.steering.holdGap - 1e-9, "a horse is held rather than run through another")
	end
end
