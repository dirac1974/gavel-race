--!strict
-- Giddy-up pace meter (D-026): the continuous slider riders tap through the whole race.
-- Pure: no Roblox services. Mirrors src/pace_meter.py exactly (parity tests in tests/luau).
--
-- schedule: the marker's passes across the bar, back and forth with no pauses. Each pass
--           takes half a sweep, nudged by up to +-speedDrift; the glowing target moves to a
--           new spot every shiftMin..shiftMax passes (David's anti-macro idea), so a
--           fixed-interval clicker can't follow it.
-- score:    one tap per pass, 100 * (1 - distance from the target) in half-bar units; a pass
--           with no tap, or two or more taps, scores 0.
-- errors:   tap time minus the moment the marker crossed the target (one-tap passes only);
--           Integrity looks at their spread.

export type Rng = { NextNumber: (self: any) -> number }

export type Pass = { t0: number, t1: number, dir: number, center: number }

export type Spec = {
	sweepSeconds: number,  -- full sweep there and back
	speedDrift: number,
	shiftMin: number,
	shiftMax: number,
	centerRange: number,
}

local PaceMeter = {}

-- Per new target: 2 uniforms (centre, run length); per pass: 1 uniform (speed).
function PaceMeter.schedule(rng: Rng, start: number, duration: number, spec: Spec): { Pass }
	local out: { Pass } = {}
	local t, dir, left, center = start, 1, 0, 0
	while t < start + duration - 1e-9 do
		if left == 0 then
			center = (2 * rng:NextNumber() - 1) * spec.centerRange
			left = spec.shiftMin + math.floor(rng:NextNumber() * (spec.shiftMax - spec.shiftMin + 1))
		end
		local half = spec.sweepSeconds / 2 * (1 + spec.speedDrift * (2 * rng:NextNumber() - 1))
		table.insert(out, { t0 = t, t1 = t + half, dir = dir, center = center })
		t += half
		dir = -dir
		left -= 1
	end
	return out
end

function PaceMeter.position(p: Pass, t: number): number
	local f = (t - p.t0) / (p.t1 - p.t0)
	return if p.dir > 0 then -1 + 2 * f else 1 - 2 * f
end

function PaceMeter.idealTime(p: Pass): number
	local f = if p.dir > 0 then (p.center + 1) / 2 else (1 - p.center) / 2
	return p.t0 + f * (p.t1 - p.t0)
end

function PaceMeter.tapScore(p: Pass, t: number): number
	return 100 * (1 - math.min(math.abs(PaceMeter.position(p, t) - p.center), 1))
end

function PaceMeter.passIndex(passes: { Pass }, t: number): number?
	for k, p in passes do
		if p.t0 <= t and t < p.t1 then return k end
	end
	return nil
end

-- Mean pass score (missed or doubled passes count 0), timing errors, passes hit once.
function PaceMeter.score(passes: { Pass }, taps: { number }): (number, { number }, number)
	if #passes == 0 then return 0, {}, 0 end
	local byPass: { { number } } = {}
	for k = 1, #passes do byPass[k] = {} end
	for _, t in taps do
		local k = PaceMeter.passIndex(passes, t)
		if k then table.insert(byPass[k], t) end
	end
	local total, errors, single = 0, {}, 0
	for k, p in passes do
		local ts = byPass[k]
		if #ts == 1 then
			total += PaceMeter.tapScore(p, ts[1])
			table.insert(errors, ts[1] - PaceMeter.idealTime(p))
			single += 1
		end
	end
	return total / #passes, errors, single
end

-- How many passes got exactly one tap scoring at least `min` (80 = Great or Perfect), the
-- same rule as score(): a doubled pass counts for nothing.
function PaceMeter.countAtLeast(passes: { Pass }, taps: { number }, min: number): number
	local byPass: { [number]: { number } } = {}
	for _, t in taps do
		local k = PaceMeter.passIndex(passes, t)
		if k then
			byPass[k] = byPass[k] or {}
			table.insert(byPass[k], t)
		end
	end
	local n = 0
	for k, ts in byPass do
		if #ts == 1 and PaceMeter.tapScore(passes[k], ts[1]) >= min then n += 1 end
	end
	return n
end

return PaceMeter
