--!strict
-- Gavel meter motion and scoring (D-010). Pure: no Roblox services, so it runs
-- on server, client, and under Lune tests. Score formula is the same in every
-- league (s = 100 * (1 - d)); difficulty comes from speed and targets only.

export type Spec = {
	sweepSeconds: number,   -- full sweep there and back
	targetDrift: number,    -- 0 = fixed center
	twoTargets: boolean,    -- two half-size targets at -0.5 and +0.5
	driftSeconds: number?,  -- drift period, default 3.7 s (not a multiple of the sweep)
}

local GavelMeter = {}

-- Marker position in [-1, 1] at t seconds after the window opens.
-- Triangle wave starting at -1, so a random tap is uniform over the bar.
function GavelMeter.position(t: number, sweepSeconds: number): number
	local phase = (t / sweepSeconds) % 1
	if phase < 0.5 then
		return -1 + 4 * phase
	end
	return 3 - 4 * phase
end

-- Center of the (single) target at time t.
function GavelMeter.targetCenter(t: number, spec: Spec): number
	if spec.targetDrift <= 0 then return 0 end
	local period = spec.driftSeconds or 3.7
	return spec.targetDrift * math.sin(2 * math.pi * t / period)
end

-- Score 0..100 for a tap t seconds after the window opened.
function GavelMeter.score(t: number, spec: Spec): number
	local pos = GavelMeter.position(t, spec.sweepSeconds)
	local d: number
	if spec.twoTargets then
		-- Each target is half as wide, so distance counts double.
		d = 2 * math.min(math.abs(pos - 0.5), math.abs(pos + 0.5))
	else
		d = math.abs(pos - GavelMeter.targetCenter(t, spec))
	end
	return 100 * (1 - math.clamp(d, 0, 1))
end

-- Decide which time a tap is scored at (D-010): the client's claimed server
-- time if it is plausible, otherwise the arrival time. Returns nil if the tap
-- falls outside the window.
function GavelMeter.resolveTapTime(
	claimed: number,
	arrival: number,
	windowStart: number,
	windowEnd: number,
	maxRewind: number
): number?
	local t = arrival
	if claimed <= arrival and arrival - claimed <= maxRewind then
		t = claimed
	end
	if t < windowStart or t > windowEnd then
		return nil
	end
	return t
end

return GavelMeter
