--!strict
-- Final Burst meter (D-022; scoring from D-010). Pure: no Roblox services, so it
-- runs on server, client, and under Lune tests. Score = 100 * (1 - d) in every
-- league; difficulty comes from speed and targets only.
--
-- The marker starts at a uniformly random point shared by every lane (`phase`), so a
-- fixed-delay macro scores the same as tapping at random (~50) at every delay. Any
-- rule about where it may start (e.g. "not in the glow") makes the first pass
-- predictable and lifts a tuned macro to ~60, so there is none. The window has
-- several passes, so an early pass is never a player's only chance.

export type Spec = {
	sweepSeconds: number,   -- full sweep there and back
	targetDrift: number,    -- 0 = fixed center
	twoTargets: boolean,    -- two half-size targets at -0.5 and +0.5
	driftSeconds: number?,  -- drift period, default 3.7 s (not a multiple of the sweep)
	phase: number?,         -- start offset as a fraction of a sweep, 0..1 (0 = left edge)
}

export type Rng = { NextNumber: (self: any) -> number }

local BurstMeter = {}

-- Marker position in [-1, 1] at t seconds after the window opens.
-- Triangle wave; phase 0 starts at -1, so a random tap is uniform over the bar.
function BurstMeter.position(t: number, sweepSeconds: number, phase: number?): number
	local p = (t / sweepSeconds + (phase or 0)) % 1
	if p < 0.5 then
		return -1 + 4 * p
	end
	return 3 - 4 * p
end

-- Center of the (single) target at time t.
function BurstMeter.targetCenter(t: number, spec: Spec): number
	if spec.targetDrift <= 0 then return 0 end
	local period = spec.driftSeconds or 3.7
	return spec.targetDrift * math.sin(2 * math.pi * t / period)
end

-- Distance used for scoring, in half-widths (0 = dead center).
function BurstMeter.distance(t: number, spec: Spec): number
	local pos = BurstMeter.position(t, spec.sweepSeconds, spec.phase)
	if spec.twoTargets then
		-- Each target is half as wide, so distance counts double.
		return 2 * math.min(math.abs(pos - 0.5), math.abs(pos + 0.5))
	end
	return math.abs(pos - BurstMeter.targetCenter(t, spec))
end

-- Score 0..100 for a tap t seconds after the window opened.
function BurstMeter.score(t: number, spec: Spec): number
	return 100 * (1 - math.clamp(BurstMeter.distance(t, spec), 0, 1))
end

-- Random start shared by every lane (uniform; see the header for why).
function BurstMeter.randomPhase(rng: Rng): number
	return rng:NextNumber()
end

return BurstMeter
