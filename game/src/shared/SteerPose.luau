--!strict
-- SteerPose (D-057 N3): how a race horse's body turns and leans while it changes lanes. Pure, so
-- Lune tests it; RaceView applies it to every horse in a steering race (bots, Smart Steer and
-- riders alike: they all glide by the same server rules) and Replay to the recorded lanes.
-- * Yaw: the horse turns with its true drift, atan(sideways speed / forward speed) x yawGain
--   (a 9 ft/s glide at 56 ft/s is 9 degrees), capped at yawMaxDeg.
-- * Lean: sideways acceleration x leanDegPerFtps2, capped at leanMaxDeg: into a move as it starts,
--   the other way as it settles.
-- * Look (your own horse, on your screen only): lookDeg toward your press at once (most of it
--   within 0.1 s), held while
--   the press is on its way (SteerPredict.lookDir); it hands over to the drift as the slide starts
--   (the larger of the two counts) and relaxes over lookRelaxSeconds if the press waits.
-- * Smooth: sideways speed and acceleration are smoothed over yawSmoothSeconds, so the 10 Hz
--   samples' corners, the lock, a landing, the finish and a replay's first frame never snap the
--   body round. A placement that jumps (a replay starting or seeking) resets the state.
-- Angles are radians, positive toward higher lane numbers (outward), which is the horse's right
-- on every course (TrackLayout.railPoint: x grows outward from the rail on its left).

export type State = { x: number?, v: number, a: number, look: number, yaw: number, roll: number }
export type Config = { yawGain: number, yawMaxDeg: number, yawSmoothSeconds: number, leanDegPerFtps2: number,
	leanMaxDeg: number, lookDeg: number, lookRelaxSeconds: number }

local SteerPose = {}

SteerPose.MIN_FORWARD = 20 -- ft/s: a horse slowing past the line never turns past the cap
SteerPose.LOOK_RISE_SECONDS = 0.05 -- the look cue rises this fast: at once, but never a one-frame snap

function SteerPose.new(): State
	return { x = nil, v = 0, a = 0, look = 0, yaw = 0, roll = 0 }
end

-- Forget the last lane (the next step only records it): after a jump, or with no steering.
function SteerPose.reset(s: State)
	s.x, s.v, s.a, s.look, s.yaw, s.roll = nil, 0, 0, 0, 0, 0
end

-- One frame: x = lane position now, dt = race seconds since the last frame, forward = forward
-- speed (ft/s), laneWidth = feet per lane, look = -1 / 0 / 1 (your press's direction while the look
-- cue holds). Returns yaw, roll (radians).
function SteerPose.step(s: State, cfg: Config, x: number, dt: number, forward: number, laneWidth: number, look: number?): (number, number)
	if dt <= 0 then return s.yaw, s.roll end
	if s.x == nil then
		s.x = x
		return s.yaw, s.roll
	end
	local k = 1 - math.exp(-dt / math.max(cfg.yawSmoothSeconds, 1e-6))
	local raw = (x - (s.x :: number)) * laneWidth / dt
	s.x = x
	local v = s.v + (raw - s.v) * k
	local a = (v - s.v) / dt
	s.v = v
	s.a += (a - s.a) * k
	-- The look cue: up at once (LOOK_RISE_SECONDS), down over lookRelaxSeconds.
	local lookTo = look or 0
	if lookTo ~= 0 then
		s.look += (lookTo - s.look) * (1 - math.exp(-dt / SteerPose.LOOK_RISE_SECONDS))
	else
		local fall = dt / math.max(cfg.lookRelaxSeconds, 1e-6)
		s.look = if s.look > 0 then math.max(0, s.look - fall) else math.min(0, s.look + fall)
	end
	local maxYaw = math.rad(cfg.yawMaxDeg)
	local drift = math.atan2(v, math.max(forward, SteerPose.MIN_FORWARD)) * cfg.yawGain
	local cue = s.look * math.rad(cfg.lookDeg)
	local yaw
	if cue == 0 then
		yaw = drift
	elseif drift * cue >= 0 then -- the same way: the larger counts (the look hands over to the drift)
		yaw = if math.abs(drift) >= math.abs(cue) then drift else cue
	else
		yaw = drift + cue
	end
	s.yaw = math.clamp(yaw, -maxYaw, maxYaw)
	local maxRoll = math.rad(cfg.leanMaxDeg)
	s.roll = math.clamp(math.rad(s.a * cfg.leanDegPerFtps2), -maxRoll, maxRoll)
	return s.yaw, s.roll
end

-- The CFrame.Angles arguments for a pose, applied as
-- CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, ry, 0) * CFrame.Angles(0, 0, rz).
-- Roblox rotations are right-handed: a positive turn about +Y swings the look vector (-Z) toward
-- -X, the horse's left, and a positive turn about +Z (backwards) lifts the right side, a lean to
-- the left. Toward higher lanes is the horse's right, so both flip sign.
function SteerPose.angles(yaw: number, roll: number): (number, number)
	return -yaw, -roll
end

return SteerPose
