--!strict
-- Steering in replays (D-054 S4): what Replay draws from a recording, kept pure so it runs under
-- Lune. A recording (RaceState.recording) is { frames = { { t, [i] = progress, x = { lane per
-- horse }? } }, lane = { posts }?, events = { { t, kind, ... } }, myLane?, steer? (you had the ◀ ▶
-- buttons), lockAt? (server time of the far-turn lock) }. Recordings from before steering have no
-- x, no lane list or no events: every function here copes.
-- Trip events (RaceController records them, built here): "saved" { t, t0, t1 } (a turn from t0 to
-- t1 you left having saved ground), "tuck" { t, t0, t1 } (tucked in from t0 to t1), "steer" { t,
-- dir } (your presses). The lock time is rec.lockAt (RaceView, from TripInfo).

local ReplayTrip = {}

-- "Saved ground!" at t on leaving a turn that runs from turnStart to turnEnd feet along the rail
-- (pace feet, as Trip counts turns), in a race that started at server time `start`.
function ReplayTrip.saved(t: number, start: number, turnStart: number, turnEnd: number, speed: number): any
	return { t = t, kind = "saved", t0 = start + turnStart / speed, t1 = start + turnEnd / speed }
end

-- Tucked in from t0 to t1 (server time).
function ReplayTrip.tuck(t0: number, t1: number): any
	return { t = t1, kind = "tuck", t0 = t0, t1 = t1 }
end

-- Horse i's lane position between frames a and b (fraction f): the recorded lanes, else its post
-- (the recording's lane list), else its lane number.
function ReplayTrip.laneAt(rec: any, a: any, b: any, f: number, i: number): number
	local post = (rec.lane and rec.lane[i]) or i
	local xa = (a.x and a.x[i]) or post
	local xb = (b.x and b.x[i]) or xa
	return xa + (xb - xa) * f
end

-- Horse i's lane position between frames k - 1 and k (fraction f) on a smooth curve through the
-- recorded lanes (D-057 N3): a monotone cubic using the frames either side (k - 2 and k + 1), so a
-- replayed lane change keeps the S-curve it had live (no corner at each 10 Hz frame, even in slow
-- motion) and never swings past a lane. Frames without lanes (older recordings) use the post.
function ReplayTrip.laneCurve(rec: any, k: number, f: number, i: number): number
	local frames = rec.frames
	local n = #frames
	local post = (rec.lane and rec.lane[i]) or i
	local function at(j: number): (number, number)
		local fr = frames[math.clamp(j, 1, n)]
		return (fr.x and fr.x[i]) or post, fr.t
	end
	local x1, t1 = at(k - 1)
	local x2, t2 = at(k)
	local h = t2 - t1
	if k <= 1 or h <= 0 then return x2 end
	local x0, t0 = at(k - 2)
	local x3, t3 = at(k + 1)
	local d1 = (x2 - x1) / h
	local d0 = if t1 > t0 then (x1 - x0) / (t1 - t0) else d1
	local d2 = if t3 > t2 then (x3 - x2) / (t3 - t2) else d1
	-- Tangents: the harmonic mean of the slopes either side, 0 where the curve turns (Fritsch and
	-- Butland), which keeps every piece monotone.
	local function tangent(a: number, b: number): number
		if a * b <= 0 then return 0 end
		return 2 / (1 / a + 1 / b)
	end
	local m1, m2 = tangent(d0, d1), tangent(d1, d2)
	local f2, f3 = f * f, f * f * f
	return (2 * f3 - 3 * f2 + 1) * x1 + (f3 - 2 * f2 + f) * h * m1 + (-2 * f3 + 3 * f2) * x2 + (f3 - f2) * h * m2
end

-- Events of one kind, in recorded order (none for an old recording).
function ReplayTrip.events(rec: any, kind: string): { any }
	local out = {}
	for _, e in rec.events or {} do
		if e.kind == kind then table.insert(out, e) end
	end
	return out
end

-- Your line up to the lock: { t, p (progress), x, saved } every `step` frames, saved = inside a
-- turn you left having saved ground. nil when there's nothing to draw: no rider, no buttons in that
-- race, or no recorded lanes.
function ReplayTrip.ribbon(rec: any, step: number): { any }?
	local me = rec.myLane
	if not me or not rec.steer then return nil end
	local saved = ReplayTrip.events(rec, "saved")
	local out = {}
	local frames = rec.frames or {}
	for k = 1, #frames, math.max(1, step) do
		local f = frames[k]
		if rec.lockAt and f.t > rec.lockAt then break end
		if f.x and f.x[me] and f[me] then
			local inSaved = false
			for _, e in saved do
				if f.t >= e.t0 and f.t <= e.t1 then inSaved = true end
			end
			table.insert(out, { t = f.t, p = f[me], x = f.x[me], saved = inSaved })
		end
	end
	return if #out >= 2 then out else nil
end

-- Tucked in at time t (inside a recorded span).
function ReplayTrip.tuckedAt(rec: any, t: number): boolean
	for _, e in rec.events or {} do
		if e.kind == "tuck" and t >= e.t0 and t <= e.t1 then return true end
	end
	return false
end

return ReplayTrip
