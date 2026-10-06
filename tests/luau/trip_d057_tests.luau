--!strict
-- Natural steering stage N2 (D-057): Trip.luau with D-057 switched on against the Python reference
-- (tests/fixtures/trip_d057.json from `python tests/fixtures/make_fixtures.py --d057`, 1e-9): every
-- answer, snapshot (lanes, sideways speeds, offsets, targets, waiting presses, steadying, charges,
-- tucking, tuck-back, every clock, each side's state, boxed in), brush event, trip, charge, tau with the
-- brush term and stars, for the scripted runs and the hand-built edge runs. Also: GameConfig.steering
-- holds every D-057 key with its D-054 value (the game stays on D-054 until N3). Run from
-- run_all.luau.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local GameConfig = require("../../game/src/shared/GameConfig")
local TrackLayout = require("../../game/src/shared/TrackLayout")
local Trip = require("../../game/src/shared/Trip")

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

-- A config from its exact-decimal form (make_fixtures._exact): numbers come as strings, which
-- Luau's tonumber reads exactly (Lune's JSON reader can land a number one ulp off); strings that
-- aren't numbers ("eased", "wait", ...) and booleans stay as they are.
local function fromExact(value: any): any
	if type(value) == "string" then return tonumber(value) or value end
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in value do out[k] = fromExact(v) end
	return out
end

local function exactList(list: { string }): { number }
	local out = table.create(#list)
	for i, s in list do out[i] = tonumber(s) :: number end
	return out
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local path = "tests/fixtures/trip_d057.json"
	if not fs.isFile(path) then
		check(false, "tests/fixtures/trip_d057.json is missing: run python tests/fixtures/make_fixtures.py --d057")
		return
	end
	local data = serde.decode("json", fs.readFile(path))
	local base = fromExact(data.cfgExact)
	local defaults = fromExact(data.defaultsExact)

	-- GameConfig.steering holds every key of trip.CONFIG (the game-only switches and the scale
	-- aside), D-057's included: since N3, D-057's motion and press rules on, brushes off.
	local steering = table.clone(GameConfig.steering)
	steering.drawPosts = nil
	steering.requestsPerSecond = nil
	steering.scale = nil
	local pyDefaults = table.clone(defaults)
	pyDefaults.scale = nil
	check(deepEqual(steering, pyDefaults, 0), "GameConfig.steering mirrors trip.CONFIG with every D-057 key")
	local motionOn = true
	for key, value in Trip.D057 do
		if key ~= "brush" and GameConfig.steering[key] ~= value then motionOn = false end
	end
	check(motionOn and GameConfig.steering.brush == "off",
		"N3: D-057's motion and press switches are on in GameConfig.steering; brushes stay off until N5")
	local back = Trip.d054Config(GameConfig.steering)
	local backOk = true
	for key, value in Trip.D057_OFF do
		if back[key] ~= value then backOk = false end
	end
	check(backOk and back.smart ~= GameConfig.steering.smart and GameConfig.steering.glide == "eased",
		"Trip.d054Config switches every D-057 key back to D-054, on a copy")
	check(base.glide == "eased" and base.brush == "repeat" and base.weaveWindowSeconds == 7, "the fixture runs D-057 on")

	local race = Trip.raceParams(GameConfig)
	local dt = 1 / GameConfig.steering.tickHz
	local failed: { [string]: number } = {}
	local function fail(what: string, where: string)
		if failed[what] == nil then
			failed[what] = 0
			print(`trip_d057 {where}: {what}`)
		end
		failed[what] += 1
	end
	local function nums(a: { number }, b: { number }, tol: number): boolean
		if #a ~= #b then return false end
		for i = 1, #a do
			if math.abs(a[i] - b[i]) > tol then return false end
		end
		return true
	end
	local function same(a: { any }, b: { any }): boolean
		if #a ~= #b then return false end
		for i = 1, #a do
			if a[i] ~= b[i] then return false end
		end
		return true
	end

	local function replay(run: any, label: string): boolean
		local cfg = if run.cfgExact then fromExact(run.cfgExact) else base
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
		local ok = true
		local answers, events = {}, {}
		local snapIndex = 1
		for tick = 0, run.ticks - 1 do
			local live = if tick < run.switchTick then q else p1
			local before = #st.events
			for _, a in Trip.step(st, live, byTick[tick] or {}, tick * dt, dt) do table.insert(answers, a) end
			for e = before + 1, #st.events do
				local ev = st.events[e]
				table.insert(events, { tick, ev[3], ev[4], ev[5] })
			end
			if tick % run.snapEvery == 0 or tick == run.ticks - 1 then
				local snap = run.snapshots[snapIndex]
				snapIndex += 1
				local where = `{label} tick {tick}`
				if not snap or snap.tick ~= tick then
					fail("snapshot ticks", where)
					ok = false
				else
					local n = st.n
					local sides, boxed, noTuck, boxedNoTuck = {}, {}, {}, {}
					for i = 1, n do
						sides[i] = { Trip.sideState(st, i, -1), Trip.sideState(st, i, 1) }
						boxed[i] = Trip.boxedIn(st, i)
						noTuck[i] = Trip.noTuckInside(st, i)
						boxedNoTuck[i] = Trip.boxedNoTuck(st, i)
					end
					local checks = {
						{ "x", nums(st.x, snap.x, 1e-9) }, { "v", nums(st.v, snap.v, 1e-9) }, { "off", nums(st.off, snap.off, 1e-9) },
						{ "tgt", same(st.tgt, snap.tgt) }, { "want", same(st.want, snap.want) }, { "queued", same(st.queued, snap.queued) },
						{ "check", nums(st.check, snap.check, 1e-9) }, { "charged", same(st.charged, snap.charged) },
						{ "tucking", same(st.tucking, snap.tucking) },
						{ "alongSince", deepEqual(st.alongSince, snap.alongSince, 1e-9) },
						{ "steadyUntil", nums(st.steadyUntil, snap.steadyUntil, 1e-9) },
						{ "firstPressAt", nums(st.firstPressAt, snap.firstPressAt, 1e-9) },
						{ "lastRevAt", nums(st.lastRevAt, snap.lastRevAt, 1e-9) },
						{ "arrivedAt", nums(st.arrivedAt, snap.arrivedAt, 1e-9) },
						{ "manualAt", nums(st.manualAt, snap.manualAt, 1e-9) },
						{ "smartBlockAt", nums(st.smartBlockAt, snap.smartBlockAt, 1e-9) },
						{ "lastPressAt", nums(st.lastPressAt, snap.lastPressAt, 1e-9) },
						{ "lastPressDir", same(st.lastPressDir, snap.lastPressDir) },
						{ "wantAt", nums(st.wantAt, snap.wantAt, 1e-9) },
						{ "lastChange", nums(st.lastChange, snap.lastChange, 1e-9) },
						{ "lastDir", same(st.lastDir, snap.lastDir) }, { "tuck", nums(st.tuck, snap.tuck, 1e-9) },
						{ "sides", deepEqual(sides, snap.sides, 0) }, { "boxed", same(boxed, snap.boxed) },
						{ "noTuckInside", same(noTuck, snap.noTuckInside) }, { "boxedNoTuck", same(boxedNoTuck, snap.boxedNoTuck) },
					}
					for _, c in checks do
						if not c[2] then
							fail("snapshot " .. c[1], where)
							ok = false
						end
					end
				end
			end
		end
		if not same(answers, run.answers) then
			fail("answers", label)
			ok = false
		end
		if not nums(st.x, run.lockX, 1e-9) then
			fail("lanes at the lock", label)
			ok = false
		end
		Trip.lock(st)
		local frozen = { x = table.clone(st.x), charged = table.clone(st.charged), events = #st.events }
		local late = {}
		for _, li in run.afterLock do table.insert(late, { li[1], li[2] }) end
		local lateAnswers = Trip.step(st, p1, late, run.ticks * dt, dt)
		local allLocked = #lateAnswers == #run.afterLockAnswers
		for k2, a in lateAnswers do
			if a ~= "locked" or a ~= run.afterLockAnswers[k2] then allLocked = false end
		end
		if not (allLocked and same(frozen.x, st.x) and same(frozen.charged, st.charged) and frozen.events == #st.events) then
			fail("after the lock", label)
			ok = false
		end
		local tr = Trip.tripValues(st)
		local charges = Trip.brushCharges(st)
		local tau = Trip.tau(tr, run.posts, data.baseline[run.course][run.distance], cfg, charges)
		local stars = {}
		for i = 1, st.n do stars[i] = Trip.stars(tau[i], cfg) end
		local results = {
			{ "ground", nums(st.ground, run.ground, 1e-9) }, { "draft", nums(st.draft, run.draft, 1e-9) },
			{ "trip", nums(tr, run.trip, 1e-9) }, { "brushes", same(st.brushes, run.brushes) },
			{ "charged", same(st.charged, run.charged) }, { "charges", nums(charges, run.charges, 1e-9) },
			{ "events", deepEqual(events, run.events, 0) }, { "tau", nums(tau, run.tau, 1e-9) }, { "stars", same(stars, run.stars) },
		}
		for _, c in results do
			if not c[2] then
				fail(c[1], label)
				ok = false
			end
		end
		return ok
	end

	local runsOk, edgesOk = 0, 0
	for r, run in data.runs do
		if replay(run, `run {r}`) then runsOk += 1 end
	end
	local names = {}
	for _, edge in data.edges do
		if replay(edge, `edge {edge.name}`) then edgesOk += 1 end
		table.insert(names, edge.name)
	end
	local brushes = 0
	for _, run in data.runs do brushes += #run.events end
	check(#data.runs >= 50 and runsOk == #data.runs,
		`all {#data.runs} trip_d057.json runs replay to 1e-9 ({runsOk} matched; {brushes} brush events)`)
	check(#data.edges >= 12 and edgesOk == #data.edges, `all {#data.edges} edge runs replay to 1e-9 ({table.concat(names, ", ")})`)
	for what, count in failed do check(false, `trip_d057: {what} differs in {count} places`) end

	-- The config the tests and the overlap report build (Trip.d057Config) is the fixture's D-057
	-- config: trip.d057_config() in Python.
	local built = Trip.d057Config(GameConfig.steering)
	built.drawPosts, built.requestsPerSecond, built.scale = nil, nil, nil
	local pyOn = table.clone(base)
	pyOn.scale = nil
	check(deepEqual(built, pyOn, 0), "Trip.d057Config(GameConfig.steering) is trip.d057_config()")

	-- Whole races with D-057 on (tests/luau/overlap_report.luau d057 runs the same at any size): a
	-- masher, a ditherer and a casual rider pressing through Trip.submit, lanes drawn from the 10 Hz
	-- samples interpolated (N3's RaceView), half of the races with rider 1 pressing from its own
	-- screen over a 0.1 s link. No horse within half a lane and 6 ft of another on any screen, none
	-- drawn falling back faster than 20 ft/s, the order across the line the result, no rider
	-- reversing within 3 s of its last reversal, no horse reversing after the lock within 3.5 s of
	-- its last reversal, no full-lane move in the last 2 s (the report allows 100 per 960 races),
	-- and the drawn sideways acceleration within 31.7 ft/s^2 (Trip's landing tick reaches 30.4,
	-- the 0.001-lane rounding of the sent lanes adds up to 1.2).
	local simulateRace = require("./race_overlap")
	local races, overlaps, own, jerks, wrongOrder, predicted, minGap, accel, brushes = 0, 0, 0, 0, 0, 0, math.huge, 0, 0
	local afterMoves, lateMoves, afterGap = 0, 0, math.huge
	local cell = 0
	for _, course in { "dirt", "turf" } do
		for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
			cell += 1
			for k = 1, 2 do
				local res = simulateRace(course, distance, 5700 + 100 * cell + k, nil, { d057 = true, predict = k == 2 })
				races += 1
				overlaps += res.before + res.after
				jerks += res.jerks + res.jerksBefore
				if not res.orderOk then wrongOrder += 1 end
				if res.own then
					own += res.own.overlapsBefore + res.own.overlapsAfter
					predicted += res.own.predicted
				end
				for _, r in res.reversals do minGap = math.min(minGap, r.minGap) end
				accel = math.max(accel, res.accelBefore, res.accelAfter)
				brushes += res.brushes
				afterMoves += res.afterMoves
				lateMoves += res.lateMoves
				afterGap = math.min(afterGap, res.afterMinGap)
			end
		end
	end
	check(races == 16 and overlaps == 0 and own == 0, `D-057 on: no overlapping horses on any screen in {races} races ({overlaps} shared, {own} own frames)`)
	check(jerks == 0 and wrongOrder == 0, `D-057 on: no backward jerks ({jerks} frames) and the order across the line right ({wrongOrder} wrong)`)
	check(minGap >= 3 - 1e-9, `D-057 on: no rider reverses within 3 s of its last reversal (shortest {minGap} s)`)
	check(accel <= 31.7, `D-057 on: drawn sideways acceleration within 31.7 ft/s^2 ({accel})`)
	check(predicted == 0, "D-057 on: SteerPredict draws nothing ahead of the server (the slide starts with the server's lane)")
	check(brushes > 0, `D-057 on: brushes happen ({brushes} in {races} races)`)
	check(afterMoves > 0 and afterGap >= 3.5 - 1e-6,
		`D-057 on: after the lock no horse reverses within 3.5 s of its last reversal ({afterMoves} moves, shortest gap {afterGap} s)`)
	check(lateMoves == 0, `D-057 on: no full-lane move in the last 2 s ({lateMoves})`)

	-- Repro races from the PR #49 review: without a plan, seed 174221 (the report's race 22) overlapped
	-- on dirt and turf Marathon with a rider pressing from its own screen (15-20 frames at 0.1 and
	-- 0.25 s), and only a late full-lane dodge saved it; a half-step-only dodge overlapped on dirt
	-- Marathon, seed 277168. With the plan they run clean with no late full-lane moves.
	local repro = {}
	for _, case in { { "dirt", 174221 }, { "turf", 174221 }, { "dirt", 277168 } } do
		for _, latency in { 0.1, 0.25 } do
			local res = simulateRace(case[1], "Marathon", case[2], nil, { d057 = true, predict = true, latency = latency })
			local frames = res.before + res.after + res.own.overlapsBefore + res.own.overlapsAfter
			if frames > 0 or res.lateMoves > 0 or not res.orderOk or res.afterMinGap < 3.5 - 1e-6 then
				table.insert(repro, `{case[1]} {case[2]} at {latency} s: {frames} overlapping frames, {res.lateMoves} late moves`)
			end
		end
	end
	check(#repro == 0, "D-057 repro races (174221 dirt/turf Marathon, 277168 dirt Marathon, predict at 0.1 and 0.25 s) run clean"
		.. (if #repro > 0 then ": " .. table.concat(repro, "; ") else ""))
end
