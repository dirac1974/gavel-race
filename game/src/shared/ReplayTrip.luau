--!strict
-- Steering in replays (D-054 S4): what Replay draws from a recording, kept pure so it runs under
-- Lune. A recording (RaceState.recording) is { frames = { { t, [i] = progress, x = { lane per
-- horse }? } }, lane = { posts }?, events = { { t, kind, ... } }, myLane?, steer? (you had the ◀ ▶
-- buttons), lockAt? (server time of the far-turn lock) }. Recordings from before steering have no
-- x, no lane list or no events: every function here copes.
-- Trip events (RaceController and RaceView record them): "lock" { t }, "saved" { t, t0, t1 }
-- (a turn from t0 to t1 you left having saved ground), "tuck" { t, t0, t1 } (tucked in from t0 to
-- t1), "steer" { t, dir } (your presses).

local ReplayTrip = {}

-- Horse i's lane position between frames a and b (fraction f): the recorded lanes, else its post
-- (the recording's lane list), else its lane number.
function ReplayTrip.laneAt(rec: any, a: any, b: any, f: number, i: number): number
	local post = (rec.lane and rec.lane[i]) or i
	local xa = (a.x and a.x[i]) or post
	local xb = (b.x and b.x[i]) or xa
	return xa + (xb - xa) * f
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
