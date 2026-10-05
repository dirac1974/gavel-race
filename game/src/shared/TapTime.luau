--!strict
-- Which server time a tap is scored at (D-010, D-021). Pure; used by Giddy-up
-- stretches and the Final Burst alike.

local TapTime = {}

-- How far before arrival a claimed tap time may be: the player's measured one-way
-- latency plus a jitter margin, capped. A flat allowance let a modified client wait
-- until the marker passed the center and claim that moment; tying it to measured
-- latency leaves only a narrow band to pick from.
function TapTime.rewindAllowance(roundTripSeconds: number, margin: number, cap: number): number
	return math.clamp(math.max(roundTripSeconds, 0) / 2 + margin, 0, cap)
end

-- The client's claimed server time if it lies within `allowance` before arrival,
-- otherwise the arrival time. Returns nil if that falls outside [windowStart, windowEnd].
function TapTime.resolve(
	claimed: number,
	arrival: number,
	windowStart: number,
	windowEnd: number,
	allowance: number
): number?
	local t = arrival
	if claimed <= arrival and arrival - claimed <= allowance then
		t = claimed
	end
	if t < windowStart or t > windowEnd then
		return nil
	end
	return t
end

return TapTime
