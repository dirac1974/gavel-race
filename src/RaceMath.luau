--!strict
-- RaceMath v2: base chances, locked purses, gavel tilt, finish draw.
-- Server-only. Mirrors src/gavel_race_v2.py. See docs/V2_PROPOSAL.md.
local RaceMath = {}

-- Anything with a NextNumber method: Roblox's Random, or a test stub.
export type Rng = { NextNumber: (self: any) -> number }

export type Config = {
	T: number,      -- stat temperature (22 Rookie ... 12 Champion)
	qFloor: number, -- smallest win chance (0.025)
	kappa: number,  -- gavel strength (1.0)
	rFloor: number, -- worst skill value (-0.5)
	B: number,      -- league base purse
}

local function normalize(w: {number}): {number}
	local total = 0
	for _, v in w do total += v end
	local out = table.create(#w)
	for i, v in w do out[i] = v / total end
	return out
end

-- Step 1: base win chances from Race Ratings
function RaceMath.baseChances(ratings: {number}, cfg: Config): {number}
	local maxR = -math.huge
	for _, r in ratings do maxR = math.max(maxR, r) end
	local w = table.create(#ratings)
	for i, r in ratings do w[i] = math.exp((r - maxR) / cfg.T) end
	local q = normalize(w)
	for i, v in q do q[i] = math.max(v, cfg.qFloor) end
	return normalize(q)
end

-- Step 2: locked win purses, rounded to whole cash (D-017)
function RaceMath.lockPurses(q: {number}, cfg: Config): {number}
	local purses = table.create(#q)
	-- floor(x + 0.5) to match the Python reference exactly (see gavel_race_v2.py)
	for i, qi in q do purses[i] = math.floor(cfg.B / qi + 0.5) end
	return purses
end

-- Step 3: one gavel window; d = |offset from center| / half-width
function RaceMath.windowScore(d: number): number
	return 100 * (1 - math.clamp(d, 0, 1))
end

-- Step 4: skill vs. this race's average score
-- scores = each lane's average over the windows played so far
function RaceMath.skills(scores: {number}, cfg: Config): {number}
	local mean = 0
	for _, s in scores do mean += s end
	mean /= #scores
	local R = table.create(#scores)
	for i, s in scores do R[i] = math.clamp((s - mean) / 50, cfg.rFloor, 1) end
	return R
end

-- Step 5: live win chances
function RaceMath.liveChances(q: {number}, R: {number}, cfg: Config): {number}
	local w = table.create(#q)
	for i, qi in q do w[i] = qi * math.exp(cfg.kappa * R[i]) end
	return normalize(w)
end

-- Step 6: finish order (Harville); returns lane indices, 1st to last.
-- Lanes are scanned in index order so results match the Python reference.
function RaceMath.drawFinish(p: {number}, rng: Rng): {number}
	local n = #p
	local taken = table.create(n, false)
	local order = table.create(n)
	for _ = 1, n do
		local total = 0
		for i = 1, n do
			if not taken[i] then total += p[i] end
		end
		local x = rng:NextNumber() * total
		local pick = -1
		for i = 1, n do
			if not taken[i] then
				pick = i
				x -= p[i]
				if x <= 0 then break end
			end
		end
		table.insert(order, pick)
		taken[pick] = true
	end
	return order
end

return RaceMath
