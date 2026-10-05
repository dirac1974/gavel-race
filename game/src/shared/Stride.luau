--!strict
-- Giddy-up stride scoring (D-022), shared by riders and Clap Along fans (D-020).
-- Pure: no Roblox services. Mirrors src/stride.py exactly (parity tests in tests/luau).
--
-- schedule:  beat times for one stretch; tempo picked per stretch in the league's
--            range, drifts each stride, Champion adds one half-beat lead change.
-- score:     each beat takes its closest tap within +-half, scoring 1 - |err|/half;
--            every other tap counts -1; 100 * total / beats, floored at 0.
-- gapErrors: (tap gap - beat gap) for consecutive matched beats; Integrity checks
--            their spread (people 30-50 ms, beat-tracking bots ~5 ms).

export type Rng = { NextNumber: (self: any) -> number }

export type Spec = {
	beats: number,
	intervalLo: number,
	intervalHi: number,
	drift: number,
	leadChange: boolean,
	half: number, -- scoring window, seconds either side of a beat
}

local Stride = {}

-- Consumes 1 uniform for the tempo, then 1 per beat after the first.
function Stride.schedule(rng: Rng, start: number, spec: Spec): { number }
	local interval = spec.intervalLo + (spec.intervalHi - spec.intervalLo) * rng:NextNumber()
	local leadAt = if spec.leadChange then spec.beats // 2 + 1 else -1
	local t = start
	local out = table.create(spec.beats)
	for k = 1, spec.beats do
		if k > 1 then
			interval *= 1 + spec.drift * (2 * rng:NextNumber() - 1)
			t += interval
			if k == leadAt then t += interval / 2 end
		end
		out[k] = t
	end
	return out
end

-- Per beat, the closest unused tap within +-half (false if none), and the count of
-- taps no beat claimed. Beats are always more than 2 * half apart.
function Stride.match(beats: { number }, taps: { number }, half: number): ({ number | false }, number)
	local matched: { number | false } = table.create(#beats, false :: number | false)
	local used = table.create(#taps, false)
	for k, b in beats do
		local best, bestErr = -1, 0
		for j, t in taps do
			local e = math.abs(t - b)
			if not used[j] and e <= half and (best == -1 or e < bestErr) then
				best, bestErr = j, e
			end
		end
		if best >= 0 then
			used[best] = true
			matched[k] = taps[best]
		end
	end
	local extras = 0
	for j = 1, #taps do
		if not used[j] then extras += 1 end
	end
	return matched, extras
end

function Stride.score(beats: { number }, taps: { number }, half: number): number
	if #beats == 0 then return 0 end
	local matched, extras = Stride.match(beats, taps, half)
	local total = 0
	for k, b in beats do
		local t = matched[k]
		if t then total += 1 - math.abs(t - b) / half end
	end
	return math.max(0, 100 * (total - extras) / #beats)
end

function Stride.gapErrors(beats: { number }, taps: { number }, half: number): { number }
	local matched = Stride.match(beats, taps, half)
	local out = {}
	for k = 2, #beats do
		local a, b = matched[k - 1], matched[k]
		if a and b then table.insert(out, (b - a) - (beats[k] - beats[k - 1])) end
	end
	return out
end

-- Label for one tap, from its distance to the nearest beat (client feedback).
-- Thresholds are fractions of the window so an average kid mostly sees Good or better.
function Stride.tapLabel(err: number, half: number, labels: { { min: number, label: string } }): string
	if math.abs(err) > half then return "Off beat" end
	local closeness = 1 - math.abs(err) / half
	for _, row in labels do
		if closeness >= row.min then return row.label end
	end
	return "Okay"
end

-- Index of the beat nearest to time t, and the signed error.
function Stride.nearest(beats: { number }, t: number): (number, number)
	local best, bestErr = 1, math.huge
	for k, b in beats do
		local e = t - b
		if math.abs(e) < math.abs(bestErr) then best, bestErr = k, e end
	end
	return best, bestErr
end

return Stride
