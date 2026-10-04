--!strict
-- Luau parity and property tests for src/RaceMath.luau. Run with:
--   python tests/fixtures/make_fixtures.py && lune run tests/luau/run_all
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

print(`{checks - failures}/{checks} checks passed`)
if failures > 0 then process.exit(1) end
