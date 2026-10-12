--!strict
-- Race realism phase A (D-072): Trip.luau with D-072 on against the Python reference
-- (tests/fixtures/trip_d072.json from `python tests/fixtures/make_fixtures.py`, 1e-9): every answer,
-- snapshot (lanes, offsets, targets, drift, skill targets, the horse being passed, returning, shut
-- doors, the pass trigger's clock), pack event, style, press count, pass count, trip and tau (with
-- the per-style row and the learner floor) for the scripted runs (each block off on its own, the
-- levers, a fixed-lanes race and the whole switch-back) and the hand-built edges (pass, door,
-- door-learner, learner-floor, fixed, styles, rider-room). Also: GameConfig.steering mirrors
-- trip.CONFIG's D-072 blocks, the switch-backs turn them off, the feel limits (drift at most 3 ft/s
-- between two horses, every pass alongside at least 0.8 s, nothing moving after the lock) and the
-- staged onboarding (Trip.riderControls). Run from run_all.luau.
-- TRIP_D072_FIXTURE (an environment variable) points at another copy of the fixture.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

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

-- A run's config: the fixture's exact config with the values its record changes (a lever run).
-- Values the record leaves as the fixture's keep their exact form.
local function applyRecord(cfg: any, rec: any, ref: any)
	for key, value in rec do
		if type(value) == "table" and type(cfg[key]) == "table" and type(ref[key]) == "table" then
			applyRecord(cfg[key], value, ref[key])
		elseif value ~= ref[key] then
			cfg[key] = value
		end
	end
end

-- GameConfig.steering minus the game-only keys (S1's post draw, S3's spam limit, the scale switch).
local function steeringRecord(steering: any): any
	local out = Trip.deepCopy(steering)
	out.drawPosts, out.requestsPerSecond, out.scale = nil, nil, nil
	return out
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local path = process.env.TRIP_D072_FIXTURE or "tests/fixtures/trip_d072.json"
	if not fs.isFile(path) then
		check(false, "tests/fixtures/trip_d072.json is missing: run python tests/fixtures/make_fixtures.py")
		return
	end
	local data = serde.decode("json", fs.readFile(path))
	local base = fromExact(data.cfgExact)

	-- The config: GameConfig.steering is trip.CONFIG (D-072 on), and the switch-backs turn it off.
	local pyCfg = steeringRecord(base)
	check(deepEqual(steeringRecord(GameConfig.steering), pyCfg, 0), "GameConfig.steering mirrors trip.CONFIG with every D-072 block")
	check(Trip.d072On(GameConfig.steering) and Trip.d072On(base), "D-072 is on in the game and the fixture")
	local off = Trip.d072Off(GameConfig.steering)
	local offOk = not Trip.d072On(off) and GameConfig.steering.file.enabled == true
	for key, value in Trip.D072_OFF do
		if not deepEqual(off[key], value, 0) then offOk = false end
	end
	for key, value in Trip.D072_RETUNED do
		if off[key] ~= value then offOk = false end
	end
	check(offOk and off.pack ~= Trip.D072_OFF.pack, "Trip.d072Off switches every D-072 block off and the retuned keys back, on a copy")
	check(not Trip.d072On(Trip.d057Config(GameConfig.steering)) and not Trip.d072On(Trip.d054Config(GameConfig.steering)),
		"Trip.d057Config and Trip.d054Config are the game before D-072 (every block off)")
	check(Trip.d072On(Trip.d072Config(GameConfig.steering)) and Trip.d072Config(GameConfig.steering).glide == "eased",
		"Trip.d072Config is D-057 in full with the D-072 blocks")

	local race = Trip.raceParams(GameConfig)
	local dt = 1 / GameConfig.steering.tickHz
	local failed: { [string]: number } = {}
	local function fail(what: string, where: string)
		if failed[what] == nil then
			failed[what] = 0
			print(`trip_d072 {where}: {what}`)
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
	local function geometry(course: string, distance: string): any
		local track = TrackLayout.courses[course]
		return TrackLayout.phaseA(track, TrackLayout.plan(track, TrackLayout.distances[distance]))
	end
	local function styleRow(course: string, distance: string): { number }
		local row = data.styles and data.styles[course] and data.styles[course][distance]
		return row or table.create(#Trip.STYLES, 0)
	end

	-- One race on cfg: steps every tick, snapshots where `snapAt(tick)` says, compares with `run`.
	local function play(run: any, label: string, cfg: any, st: any, live: (number) -> { number }, byTick: any,
		snapAt: (number) -> boolean): boolean
		local ok = true
		local d072 = Trip.d072On(cfg)
		local answers, events = {}, {}
		local snapIndex = 1
		for tick = 0, run.ticks - 1 do
			local before = #st.packEvents
			for _, a in Trip.step(st, live(tick), byTick[tick] or {}, tick * dt, dt) do table.insert(answers, a) end
			for e = before + 1, #st.packEvents do
				local ev = st.packEvents[e]
				table.insert(events, { tick, ev[2], ev[3], ev[4], ev[5] })
			end
			if snapAt(tick) then
				local snap = run.snapshots[snapIndex]
				snapIndex += 1
				local where = `{label} tick {tick}`
				if not snap or snap.tick ~= tick then
					fail("snapshot ticks", where)
					ok = false
				else
					local checks = {
						{ "x", nums(st.x, snap.x, 1e-9) }, { "off", nums(st.off, snap.off, 1e-9) }, { "tgt", same(st.tgt, snap.tgt) },
					}
					if snap.drift then table.insert(checks, { "drift", nums(st.drift, snap.drift, 1e-9) }) end
					if snap.skill then table.insert(checks, { "skill", nums(st.skill, snap.skill, 1e-9) }) end
					if snap.passFrom then table.insert(checks, { "passFrom", same(st.passFrom, snap.passFrom) }) end
					if snap.returning then table.insert(checks, { "returning", same(st.returning, snap.returning) }) end
					if snap.doorUntil then table.insert(checks, { "doorUntil", nums(st.doorUntil, snap.doorUntil, 1e-9) }) end
					if snap.doorLane then table.insert(checks, { "doorLane", same(st.doorLane, snap.doorLane) }) end
					if snap.blockSince then table.insert(checks, { "blockSince", nums(st.blockSince, snap.blockSince, 1e-9) }) end
					for _, c in checks do
						if not c[2] then
							if not failed["snapshot " .. c[1]] then
								print(`  {c[1]} luau {serde.encode("json", (st :: any)[c[1]])}`)
								print(`  {c[1]} py   {serde.encode("json", (snap :: any)[c[1]])}`)
							end
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
		if d072 and not deepEqual(events, run.packEvents or {}, 0) then
			fail("pack events", label)
			ok = false
		end
		if run.lockX and not nums(st.x, run.lockX, 1e-9) then
			fail("lanes at the lock", label)
			ok = false
		end
		Trip.lock(st)
		if run.afterLock then
			local frozen = table.clone(st.x)
			local late = {}
			for _, li in run.afterLock do table.insert(late, { li[1], li[2] }) end
			local lateAnswers = Trip.step(st, live(run.ticks), late, run.ticks * dt, dt)
			if not (same(lateAnswers, run.afterLockAnswers) and same(frozen, st.x)) then
				fail("after the lock", label)
				ok = false
			end
		end
		local tr = Trip.tripValues(st)
		local row = data.baseline[run.course][run.distance]
		local tau
		if d072 then
			local srow = styleRow(run.course, run.distance)
			local floors = Trip.learnerFloors(st, row, srow)
			tau = Trip.tau(tr, run.posts, row, cfg, Trip.brushCharges(st), Trip.styleBaseline(st, srow), floors, run.fixedLanes == true)
			if run.learnerFloors then -- (JSON null = no floor: a hole on both sides)
				local floorsOk = true
				for i = 1, st.n do
					local a, b = floors[i], run.learnerFloors[i]
					if (a == nil) ~= (b == nil) or (a ~= nil and math.abs(a - b) > 1e-9) then floorsOk = false end
				end
				if not floorsOk then
					fail("learner floors", label)
					ok = false
				end
			end
		else
			tau = Trip.tau(tr, run.posts, row, cfg, Trip.brushCharges(st))
		end
		local results = { { "trip", nums(tr, run.trip, 1e-9) }, { "tau", nums(tau, run.tau, 1e-9) } }
		if run.ground then table.insert(results, { "ground", nums(st.ground, run.ground, 1e-9) }) end
		if run.draft then table.insert(results, { "draft", nums(st.draft, run.draft, 1e-9) }) end
		if run.stars then
			local stars = {}
			for i = 1, st.n do stars[i] = Trip.stars(tau[i], cfg) end
			table.insert(results, { "stars", same(stars, run.stars) })
		end
		if run.styles then table.insert(results, { "styles", same(st.style, run.styles) }) end
		if run.presses then table.insert(results, { "presses", same(st.presses, run.presses) }) end
		if run.passes then table.insert(results, { "passes", same(st.passes, run.passes) }) end
		for _, c in results do
			if not c[2] then
				fail(c[1], label)
				ok = false
			end
		end
		return ok
	end

	local runsOk, events, shuts, passes, fixedRuns = 0, 0, 0, 0, 0
	for r, run in data.runs do
		local cfg = Trip.deepCopy(base)
		if run.cfg then
			applyRecord(cfg, run.cfg, data.cfg)
			-- (trip.config_from_record: a record without the D-072 keys has every block off)
			for key, value in Trip.D072_OFF do
				if run.cfg[key] == nil then cfg[key] = Trip.deepCopy(value) end
			end
		end
		local q, p1, uniforms = exactList(run.exact.q), exactList(run.exact.p1), exactList(run.exact.uniforms)
		local byTick: { [number]: { { number } } } = {}
		for _, intent in run.intents do
			byTick[intent[1]] = byTick[intent[1]] or {}
			table.insert(byTick[intent[1]], { intent[2], intent[3] })
		end
		local st = Trip.new(run.posts, q, uniforms, geometry(run.course, run.distance), cfg, run.kinds, race, run.learners,
			run.fixedLanes == true)
		local ok = play(run, `run {r}`, cfg, st, function(tick: number): { number }
			return if tick < run.switchTick then q else p1
		end, byTick, function(tick: number): boolean
			return tick % 10 == 0 or tick == run.ticks - 1
		end)
		if ok then runsOk += 1 end
		if run.fixedLanes then fixedRuns += 1 end
		for _, e in run.packEvents or {} do
			events += 1
			if e[2] == "shut" then shuts += 1 elseif e[2] == "pass" then passes += 1 end
		end
	end
	check(#data.runs >= 40 and runsOk == #data.runs,
		`all {#data.runs} trip_d072.json runs replay to 1e-9 ({runsOk} matched; {events} pack events, {passes} passes, {shuts} shut doors)`)
	check(fixedRuns > 0 and passes > 0 and shuts > 0, "the runs cover fixed lanes, passes and shut doors")

	local edgesOk, names = 0, {}
	for _, edge in data.edges do
		local live, uniforms, offs = exactList(edge.exact.live), exactList(edge.exact.uniforms), exactList(edge.exact.offs)
		local byTick: { [number]: { { number } } } = {}
		for _, intent in edge.intents do
			byTick[intent[1]] = byTick[intent[1]] or {}
			table.insert(byTick[intent[1]], { intent[2], intent[3] })
		end
		local st = Trip.new(edge.posts, live, uniforms, geometry(edge.course, edge.distance), base, edge.kinds, race,
			edge.learners, edge.fixedLanes == true)
		st.off = offs
		if play(edge, `edge {edge.name}`, base, st, function(): { number } return live end, byTick, function(): boolean
			return true
		end) then
			edgesOk += 1
		end
		table.insert(names, edge.name)
	end
	check(#data.edges >= 7 and edgesOk == #data.edges, `all {#data.edges} edge runs replay to 1e-9 ({table.concat(names, ", ")})`)
	for what, count in failed do check(false, `trip_d072: {what} differs in {count} places`) end

	-- Feel (votes-feel.md R1, R2): whole bot fields on the game's config, Trip only. Drift alone never
	-- moves two horses apart faster than 3 ft/s; every completed pass keeps the two horses alongside
	-- (within brushAlongFeet lengthwise) for at least 0.8 s; Trip's offsets never move more than
	-- maxGapFeetPerSecond (no pop at 10 Hz).
	do
		local cfg = Trip.deepCopy(GameConfig.steering)
		local driftMax, alongMin, passCount, jump = 0, math.huge, 0, 0
		local alongs = {}
		local seed = 72
		local function rnd(): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		for _, course in { "dirt", "turf" } do
			for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
				local geo = geometry(course, distance)
				local n = 8
				local posts, q, uniforms = table.create(n), table.create(n), {}
				for i = 1, n do
					posts[i] = i
					q[i] = (0.8 + 0.4 * rnd()) / n
				end
				for _ = 1, 9 * n do table.insert(uniforms, rnd()) end
				local st = Trip.new(posts, q, uniforms, geo, cfg, nil, race)
				local ticks = 0
				while ticks * dt < Trip.lockTime(geo, race) - 1e-9 do ticks += 1 end
				local alongAt: { [string]: number } = {}
				local prevDrift = table.clone(st.drift)
				local prevOff = table.clone(st.off)
				for tick = 0, ticks - 1 do
					local before = #st.packEvents
					Trip.step(st, q, {}, tick * dt, dt)
					for i = 1, n do
						jump = math.max(jump, math.abs(st.off[i] - prevOff[i]) / dt)
						for j = i + 1, n do
							local rel = math.abs((st.drift[i] - prevDrift[i]) - (st.drift[j] - prevDrift[j])) / dt
							driftMax = math.max(driftMax, rel)
						end
					end
					prevDrift, prevOff = table.clone(st.drift), table.clone(st.off)
					for e = before + 1, #st.packEvents do -- (a pass starts its clock on its first tick)
						local ev = st.packEvents[e]
						if ev[2] == "out" then alongAt[`{ev[3]}:{ev[4]}`] = 0 end
					end
					-- alongside clocks for every horse being passed
					for i = 1, n do
						local j = st.passFrom[i]
						if j >= 1 then
							local key = `{i}:{j}`
							if math.abs(st.off[i] - st.off[j]) < cfg.brushAlongFeet then
								alongAt[key] = (alongAt[key] or 0) + dt
							end
						end
					end
					for e = before + 1, #st.packEvents do
						local ev = st.packEvents[e]
						if ev[2] == "pass" then
							local key = `{ev[3]}:{ev[4]}`
							passCount += 1
							alongMin = math.min(alongMin, alongAt[key] or 0)
							table.insert(alongs, alongAt[key] or 0)
							alongAt[key] = nil
						end
					end
				end
			end
		end
		check(driftMax <= 3 + 1e-9, `drift moves two horses apart at most 3 ft/s ({string.format("%.3f", driftMax)})`)
		-- (binding: every pass at least 0.8 s, from pass.closingFeetPerSecond; the vote's report row
		-- also asks a median of 0.8-1.5 s)
		table.sort(alongs)
		local median = if #alongs > 0 then alongs[math.ceil(#alongs / 2)] else 0
		check(passCount > 0 and alongMin >= 0.8 - 1e-9,
			`every pass shows the two horses alongside at least 0.8 s (shortest {string.format("%.2f", alongMin)} s, median {string.format("%.2f", median)} s; {passCount} passes)`)
		check(jump <= race.maxGapFeetPerSecond + 1e-6 + GameConfig.steering.holdPullPerSecond,
			`Trip's offsets never jump at 10 Hz (fastest {string.format("%.2f", jump)} ft/s)`)
	end

	-- Fixed lanes (Hurdles), a whole race as RaceService runs it: Trip.start, Trip.submit (refused:
	-- "fixed"), Trip.advance to the lock, Trip.raceTau (all 0) and Trip.frame after the lock to the
	-- line (lanes never leave the posts).
	do
		local n = 8
		local lanes, q = {}, table.create(n, 1 / n)
		for i = 1, n do lanes[i] = { id = tostring(i), isBot = i > 2 } end
		local session = {
			lanes = lanes, q = q,
			laneIndex = function(_self: any, id: string): number? return tonumber(id) end,
			displayOffsets = function(_self: any, _live: any, _w: any, _cfg: any): { number }
				local out = table.create(n, 0)
				for i = 1, n do out[i] = (i - 4.5) * 9 end -- horses passing each other on screen
				return out
			end,
		}
		local seed = 9
		local rng = { NextNumber = function(_self: any): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end }
		local track = TrackLayout.courses.dirt
		local plan = TrackLayout.plan(track, TrackLayout.distances.Mile)
		local st = Trip.start(GameConfig, session, track, plan, table.create(n, 0), rng, TrackLayout, { ["1"] = "manual" },
			{ learners = { ["2"] = true }, fixedLanes = true })
		local refused = Trip.submit(st, session, "1", -1, 1, 1)
		local t = 0
		while not st.locked do
			Trip.advance(st, q, t)
			t += st.dt
		end
		local tau = Trip.raceTau(st)
		local zero, still = true, true
		for i = 1, n do
			if tau[i] ~= 0 then zero = false end
		end
		local toLine = st.geo.length / st.speed
		while t < toLine do
			local _, shown = Trip.frame(st, session, q, 1, GameConfig.raceShape, 0.1, t)
			for i = 1, n do
				if (shown :: { number })[i] ~= i then still = false end
			end
			t += 0.1
		end
		check(refused == "fixed" and zero and still and #st.packEvents == 0,
			"fixed lanes, a whole race: presses refused (\"fixed\"), tau 0 (Trip.raceTau), every horse in its post lane to the line")
	end
	do
		local geo = geometry("dirt", "Mile")
		local st = Trip.new({ 1, 2, 3 }, { 1 / 3, 1 / 3, 1 / 3 }, table.create(27, 0.2), geo, GameConfig.steering,
			{ "manual", "bot", "bot" }, race, nil, true)
		local answers = Trip.step(st, { 0.5, 0.25, 0.25 }, { { 1, 1 } }, 0, dt)
		for tick = 1, 300 do Trip.step(st, { 0.5, 0.25, 0.25 }, {}, tick * dt, dt) end
		check(answers[1] == "fixed" and same(st.x, { 1, 2, 3 }) and #st.packEvents == 0,
			"fixed lanes: a press answers \"fixed\" and every horse keeps its post lane")
	end

	-- Doors on (D-072 consult, feel): whole races as RaceService runs them and RaceView draws them, with
	-- every bot ready to shut a door from 30 ft (doors.shutChance 1): no horse overlaps another on any
	-- screen, none jerks back, and the order across the line is the result. (A light check: 4 races;
	-- tests/luau/overlap_report.luau runs the full set.)
	do
		local simulateRace = require("./race_overlap")
		local cfgGame = table.clone(GameConfig)
		cfgGame.steering = Trip.deepCopy(GameConfig.steering)
		cfgGame.steering.doors.shutChance, cfgGame.steering.doors.reachFeet = 1, 30
		local overlaps, jerks, wrong, shutsSeen = 0, 0, 0, 0
		for k, case in { { "dirt", "Mile" }, { "turf", "Sprint" }, { "dirt", "Classic" }, { "turf", "Marathon" } } do
			local res = simulateRace(case[1], case[2], 7200 + k, cfgGame, { manual = k % 2 == 0 }) :: any
			overlaps += res.before + res.after
			jerks += res.jerks + res.jerksBefore
			if not res.orderOk then wrong += 1 end
			shutsSeen += res.shuts or 0
		end
		check(shutsSeen > 0 and overlaps == 0 and jerks == 0 and wrong == 0,
			`doors on: no overlapping or jerking horses and the right order in 4 races ({shutsSeen} doors shut, {overlaps} overlapping frames, {jerks} jerks)`)
	end

	-- Learner shadows' cost (D-072 consult, systems): 8 learners pressing all race take at most 2 ms a
	-- Trip tick on average (each forks its passive race on its first press that changes something).
	do
		local geo = geometry("dirt", "Marathon")
		local n = 8
		local posts, q = table.create(n), table.create(n, 1 / n)
		for i = 1, n do posts[i] = i end
		local st = Trip.new(posts, q, table.create(9 * n, 0.4), geo, GameConfig.steering, table.create(n, "manual"), race,
			table.create(n, true))
		local ticks, worst, total = 0, 0, 0
		while ticks * dt < Trip.lockTime(geo, race) - 1e-9 do
			local intents = {}
			if ticks % 7 == 0 then
				for i = 1, n do table.insert(intents, { i, if (ticks // 7 + i) % 2 == 0 then -1 else 1 }) end
			end
			local t0 = os.clock()
			Trip.step(st, q, intents, ticks * dt, dt)
			local spent = os.clock() - t0
			total += spent
			worst = math.max(worst, spent)
			ticks += 1
		end
		local shadows = 0
		for _ in st.shadows do shadows += 1 end
		local mean = total / ticks
		check(shadows == n and mean <= 0.002,
			string.format("8 pressing learners: %d shadows, %.3f ms a Trip tick on average (at most 2), worst %.2f ms", shadows, 1000 * mean, 1000 * worst))
	end

	-- Staged onboarding (UI/UX vote): race 1 the buttons only, race 2 the ghost-thumb tip, race 3 the
	-- move pips (a hook); a learner for the first learner.races races. introRaces 0 goes with the
	-- learner floor.
	do
		local STEER, HUD = GameConfig.steering, GameConfig.steerHud
		local function prof(races: number, seen: boolean?): any
			return { totals = { races = races }, settings = { smartSteer = true }, flags = { steerTip = seen == true } }
		end
		local r1, r2, r2seen, r3, r4 = Trip.riderControls(prof(0), STEER, HUD), Trip.riderControls(prof(1), STEER, HUD),
			Trip.riderControls(prof(1, true), STEER, HUD), Trip.riderControls(prof(2), STEER, HUD), Trip.riderControls(prof(3), STEER, HUD)
		check(STEER.introRaces == 0 and STEER.learner.races >= 3 and STEER.learner.tauFloor >= 0,
			"buttons from race 1, with the learner floor (introRaces 0 only together with learner)")
		check(r1.shown and not r1.tip and not r1.pips and r1.learner, "race 1: the ◀ ▶ buttons only, a learner")
		check(r2.shown and r2.tip and not r2.pips and not r2seen.tip, "race 2: the ghost-thumb tip, once")
		check(r3.pips and r3.learner and not r4.learner, "race 3: the move pips (hook); a learner through race 3")
	end
end
