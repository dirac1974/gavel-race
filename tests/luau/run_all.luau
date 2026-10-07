--!strict
-- Luau parity and property tests for src/RaceMath.luau. Run with:
--   python tests/fixtures/make_fixtures.py --d057 && lune run tests/luau/run_all
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local RaceMath = require("../../src/RaceMath")

local failures = 0
local checks = 0

local function check(ok: boolean, msg: string)
	checks += 1
	if not ok then
		failures += 1
		if failures <= 20 then print("FAIL: " .. msg) end
	end
end

local function close(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

local function listRng(values: {number})
	local i = 0
	return {
		NextNumber = function(_self)
			i += 1
			return values[i]
		end,
	}
end

-- Parity with the Python reference ------------------------------------------
local data = serde.decode("json", fs.readFile("tests/fixtures/race_math.json"))

for c, case in data.cases do
	local cfg = case.cfg
	local q = RaceMath.baseChances(case.ratings, cfg)
	local purses = RaceMath.lockPurses(q, cfg)
	local R = RaceMath.skills(case.scores, cfg)
	local p = RaceMath.liveChances(q, R, cfg)
	local finish = RaceMath.drawFinish(p, listRng(case.uniforms))
	for i = 1, #case.q do
		check(close(q[i], case.q[i], 1e-9), `case {c} q[{i}] {q[i]} vs {case.q[i]}`)
		check(purses[i] == case.purses[i], `case {c} purse[{i}] {purses[i]} vs {case.purses[i]}`)
		check(close(R[i], case.R[i], 1e-9), `case {c} R[{i}]`)
		check(close(p[i], case.p[i], 1e-9), `case {c} p[{i}]`)
		check(finish[i] == case.finish[i], `case {c} finish[{i}] {finish[i]} vs {case.finish[i]}`)
	end
end

local RaceRating = require("../../game/src/shared/RaceRating")
for c, rc in data.ratings do
	local strategy = if rc.strategy == "" then nil else rc.strategy
	local r = RaceRating.rating(rc.stats, rc.cond, rc.care, rc.pilot, strategy, rc.bond)
	check(close(r, rc.rating, 1e-9), `rating case {c}: {r} vs {rc.rating}`)
end

local Stride = require("../../game/src/shared/Stride")
for c, sc in data.stride do
	local beats = Stride.schedule(listRng(sc.uniforms), sc.start, sc.spec)
	check(#beats == #sc.beats, `stride case {c}: beat count`)
	for k = 1, #sc.beats do
		check(close(beats[k], sc.beats[k], 1e-9), `stride case {c}: beat {k} {beats[k]} vs {sc.beats[k]}`)
	end
	local s = Stride.score(sc.beats, sc.taps, sc.spec.half)
	check(close(s, sc.score, 1e-9), `stride case {c}: score {s} vs {sc.score}`)
	local g = Stride.gapErrors(sc.beats, sc.taps, sc.spec.half)
	check(#g == #sc.gaps, `stride case {c}: gap count {#g} vs {#sc.gaps}`)
	for k = 1, math.min(#g, #sc.gaps) do
		check(close(g[k], sc.gaps[k], 1e-9), `stride case {c}: gap {k}`)
	end
end

local PaceMeter = require("../../game/src/shared/PaceMeter")
for c, pc in data.pace do
	local passes = PaceMeter.schedule(listRng(pc.uniforms), pc.start, pc.duration, pc.spec)
	check(#passes == #pc.passes, `pace case {c}: pass count {#passes} vs {#pc.passes}`)
	for k = 1, math.min(#passes, #pc.passes) do
		local a, b = passes[k], pc.passes[k]
		check(close(a.t0, b.t0, 1e-9) and close(a.t1, b.t1, 1e-9) and a.dir == b.dir and close(a.center, b.center, 1e-12),
			`pace case {c}: pass {k}`)
	end
	local s, errs, single = PaceMeter.score(pc.passes, pc.taps)
	check(close(s, pc.score, 1e-9), `pace case {c}: score {s} vs {pc.score}`)
	check(single == pc.single and #errs == #pc.errors, `pace case {c}: one-tap passes`)
	for k = 1, math.min(#errs, #pc.errors) do
		check(close(errs[k], pc.errors[k], 1e-9), `pace case {c}: error {k}`)
	end
	-- Finger bounces ignored (D-055)
	local bs, berrs, bsingle = PaceMeter.score(pc.passes, pc.bounceTaps, 0.15)
	check(close(bs, pc.bounceScore, 1e-9), `pace case {c}: bounce score {bs} vs {pc.bounceScore}`)
	check(bsingle == pc.bounceSingle and #berrs == #pc.bounceErrors, `pace case {c}: bounce one-tap passes`)
	for k = 1, math.min(#berrs, #pc.bounceErrors) do
		check(close(berrs[k], pc.bounceErrors[k], 1e-9), `pace case {c}: bounce error {k}`)
	end
end

for _, w in data.windows do
	check(close(RaceMath.windowScore(w.d), w.s, 1e-9), `windowScore({w.d})`)
end

-- Properties in Luau itself ---------------------------------------------------
local cfg: RaceMath.Config = { T = 14.4, qFloor = 0.025, kappa = 1.0, rFloor = -0.5, B = 100 }
-- Lune has no Roblox Random; a small deterministic LCG stands in.
local seed = 7
local function nextUnit(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local rng = {
	NextNumber = function(_self, lo: number, hi: number): number
		return lo + (hi - lo) * nextUnit()
	end,
	NextInteger = function(_self, lo: number, hi: number): number
		return lo + math.floor((hi - lo + 1) * nextUnit())
	end,
}

for _ = 1, 500 do
	local ratings, scores = {}, {}
	for i = 1, 8 do
		ratings[i] = rng:NextNumber(30, 90)
		scores[i] = rng:NextNumber(0, 100)
	end
	local q = RaceMath.baseChances(ratings, cfg)
	local p = RaceMath.liveChances(q, RaceMath.skills(scores, cfg), cfg)
	local sum = 0
	for _, v in p do
		sum += v
		check(v > 0, "positive chance")
	end
	check(close(sum, 1, 1e-12), "sums to one")

	local i = rng:NextInteger(1, 8)
	local better = table.clone(scores)
	better[i] = math.min(100, better[i] + rng:NextNumber(1, 40))
	local after = RaceMath.liveChances(q, RaceMath.skills(better, cfg), cfg)
	check(after[i] >= p[i] - 1e-12, "own skill never lowers own chance")
end

do
	local q = RaceMath.baseChances({ 70, 67, 64, 62, 60, 58, 56, 52 }, cfg)
	local p = RaceMath.liveChances(q, RaceMath.skills({ 50, 50, 50, 50, 50, 50, 50, 50 }, cfg), cfg)
	for i = 1, 8 do check(close(p[i], q[i], 1e-12), "equal scores return base chances") end
end

-- Steering geometry (D-054): src/trip.py's gate and phase A match TrackLayout -------------
do
	local TrackLayout = require("../../game/src/shared/TrackLayout")
	local tripData = serde.decode("json", fs.readFile("tests/fixtures/trip.json"))
	for course, cfg in TrackLayout.courses do
		for name, distance in TrackLayout.distances do
			local g = tripData.geometry[course][name]
			local plan = TrackLayout.plan(cfg, distance)
			local r1 = TrackLayout.laneRadius(cfg, 1)
			check(close(tripData.distances[name], distance, 0), `trip geometry {course} {name}: distance`)
			check(plan.gateStraight == g.gate.straight and plan.laps == g.gate.laps, `trip geometry {course} {name}: gate straight`)
			check(close(plan.gateOffset, g.gate.offset, 1e-9), `trip geometry {course} {name}: gate offset`)
			check(close(plan.lengths[1], g.length, 1e-9), `trip geometry {course} {name}: length {plan.lengths[1]} vs {g.length}`)
			check(r1 == g.r1 and close(math.pi * r1, g.turnLength, 1e-9), `trip geometry {course} {name}: lane-1 radius`)
			check(close(plan.lengths[1] - cfg.finishFromTop - math.pi * r1, g.lockS, 1e-9), `trip geometry {course} {name}: lock`)
			check(cfg.finishFromTop == tripData.finishFromTop[course], `trip geometry {course}: finish`)
			local s = 0
			for _, seg in g.segments do
				check(close(seg.start, s, 1e-6), `trip geometry {course} {name}: segment start`)
				s += seg.length
			end
			check(close(s, g.lockS, 1e-6), `trip geometry {course} {name}: segments reach the lock`)
			-- TrackLayout.phaseA (S1) gives src/trip.py's phase A: the same segments and lock.
			local pa = TrackLayout.phaseA(cfg, plan)
			check(#pa.segments == #g.segments, `phaseA {course} {name}: segment count {#pa.segments} vs {#g.segments}`)
			for k = 1, math.min(#pa.segments, #g.segments) do
				local a, b = pa.segments[k], g.segments[k]
				check(a.kind == b.kind and close(a.start, b.start, 1e-9) and close(a.length, b.length, 1e-9),
					`phaseA {course} {name}: segment {k}`)
			end
			check(close(pa.lockS, g.lockS, 1e-9) and close(pa.turnLength, g.turnLength, 1e-9) and close(pa.length, g.length, 1e-9),
				`phaseA {course} {name}: lock {pa.lockS} vs {g.lockS}`)
		end
	end
end

-- Game modules ---------------------------------------------------------------
require("./game_tests")(check, close)
require("./world_tests")(check, close)
require("./steering_tests")(check, close)
require("./trip_tests")(check, close)
require("./trip_d057_tests")(check, close)
require("./steer_controls_tests")(check, close)
require("./steer_results_tests")(check, close)
require("./steer_pose_tests")(check, close)
require("./steer_hud_tests")(check, close)
require("./steer_brush_tests")(check, close)
require("./queue_tests")(check, close)
require("./race_button_tests")(check, close)
require("./visit_tests")(check, close)

print(`{checks - failures}/{checks} checks passed`)
if failures > 0 then process.exit(1) end
