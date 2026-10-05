--!strict
-- Race shape (D-033): how skill and luck show on the track. Pure, so it runs under Lune.
--
-- Exponential race. At the gate each horse gets a secret luck number L ~ Exp(1). Its
-- projected finish time is T = L / p, where p is its live win chance. Sorting by T gives
-- exactly the Harville finish order the race model has always used (P(first) = p), so
-- fairness and the locked purses are unchanged. A rider's taps change only their own p,
-- so only their own T moves (the others keep their relative order).
--
-- On screen: up to the far turn a horse's offset from the shared pace comes from its live
-- chance alone (skill). From the far turn to the last tap the offsets blend toward the
-- projected finish order (luck), so lucky, well-ridden horses charge late. By the last tap
-- the order on screen is the result; margins are a fixed function of the T ratios, the
-- same for every horse (no near-miss shaping, no player input).

export type Config = {
	leadFeetPerShare: number, -- skill: feet ahead per unit of (p - fair share)
	leaderFeet: number,       -- luck: the projected leader's lead over the pace
	feetPerLog: number,       -- luck: margin per unit of log(T_next / T)
	minGap: number,
	maxGap: number,
	blendPower: number,       -- luck blend curve: weight = x ^ blendPower over far turn -> last tap
}

export type Rng = { NextNumber: (self: any) -> number }

local RaceShape = {}

RaceShape.default = {
	leadFeetPerShare = 320,
	leaderFeet = 20,
	feetPerLog = 24,
	minGap = 2,
	maxGap = 40,
	blendPower = 2,
} :: Config

-- One secret luck number per lane.
function RaceShape.drawLuck(rng: Rng, n: number): { number }
	local out = table.create(n)
	for i = 1, n do
		out[i] = -math.log(1 - rng:NextNumber())
	end
	return out
end

function RaceShape.finishTimes(luck: { number }, live: { number }): { number }
	local out = table.create(#luck)
	for i, l in luck do
		out[i] = l / math.max(live[i], 1e-12)
	end
	return out
end

-- Lanes in projected finish order (ties: lower lane first).
function RaceShape.order(luck: { number }, live: { number }): { number }
	local t = RaceShape.finishTimes(luck, live)
	local order = table.create(#luck)
	for i = 1, #luck do order[i] = i end
	table.sort(order, function(a, b)
		if t[a] ~= t[b] then return t[a] < t[b] end
		return a < b
	end)
	return order
end

-- Skill offsets (feet ahead of the pace) from live chances.
function RaceShape.skillOffsets(live: { number }, cfg: Config): { number }
	local fair = 1 / #live
	local out = table.create(#live)
	for i, p in live do out[i] = cfg.leadFeetPerShare * (p - fair) end
	return out
end

-- Luck offsets: the projected leader at +leaderFeet, each next horse behind by a margin
-- set only by its T ratio to the horse ahead.
function RaceShape.luckOffsets(luck: { number }, live: { number }, cfg: Config): { number }
	local t = RaceShape.finishTimes(luck, live)
	local order = RaceShape.order(luck, live)
	local out = table.create(#luck)
	local pos = cfg.leaderFeet
	for k, lane in order do
		if k > 1 then
			local ahead = order[k - 1]
			local gap = cfg.feetPerLog * math.log(t[lane] / t[ahead])
			pos -= math.clamp(gap, cfg.minGap, cfg.maxGap)
		end
		out[lane] = pos
	end
	return out
end

-- 0 before the far turn, rising to 1 at the last tap. Power 2 keeps luck mostly hidden
-- until the stretch: in simulation the leader at the eighth pole wins about 61% and about
-- 11% of winners come from 3rd or worse there (Kentucky Derby proxy: 74% and 12%).
function RaceShape.blendWeight(t: number, t0: number, t1: number, power: number?): number
	if t1 <= t0 then return if t >= t1 then 1 else 0 end
	local x = math.clamp((t - t0) / (t1 - t0), 0, 1)
	return x ^ (power or 2)
end

function RaceShape.offsets(live: { number }, luck: { number }, w: number, cfg: Config): { number }
	local skill = RaceShape.skillOffsets(live, cfg)
	local lucky = RaceShape.luckOffsets(luck, live, cfg)
	local out = table.create(#live)
	for i = 1, #live do out[i] = (1 - w) * skill[i] + w * lucky[i] end
	return out
end

-- Where lane `me` would have finished riding at the race average (R = 0), others unchanged.
-- `liveAtAverage` is the live-chance vector with me at R = 0 (RaceSession computes it).
function RaceShape.placeIn(luck: { number }, live: { number }, me: number): number
	local t = RaceShape.finishTimes(luck, live)
	local place = 1
	for j = 1, #luck do
		if j ~= me and (t[j] < t[me] or (t[j] == t[me] and j < me)) then place += 1 end
	end
	return place
end

return RaceShape
