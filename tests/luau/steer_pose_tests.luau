--!strict
-- D-057 N3: the body through lane changes (SteerPose) and the screen's playback of the server's
-- timestamped samples (Playback). Both pure; RaceView, Replay and the overlap report use them.
local GameConfig = require("../../game/src/shared/GameConfig")
local SteerPose = require("../../game/src/shared/SteerPose")
local Playback = require("../../game/src/shared/Playback")
local Trip = require("../../game/src/shared/Trip")

local POSE = GameConfig.steerView
local W = 6       -- feet per lane
local FWD = 56    -- race speed, ft/s
local FRAME = 1 / 60

-- Rotate vector v about the axis (0, 1, 0) or (0, 0, 1) by angle a, right-handed (Roblox's
-- convention: a positive turn about +Y takes +Z toward +X).
local function aboutY(v: { number }, a: number): { number }
	local c, s = math.cos(a), math.sin(a)
	return { c * v[1] + s * v[3], v[2], -s * v[1] + c * v[3] }
end
local function aboutZ(v: { number }, a: number): { number }
	local c, s = math.cos(a), math.sin(a)
	return { c * v[1] - s * v[2], s * v[1] + c * v[2], v[3] }
end

-- A horse gliding sideways at `v` ft/s for `seconds`, stepped every frame.
local function glide(state: any, x0: number, v: number, seconds: number, look: number?): (number, number, number)
	local x, yaw, roll = x0, 0, 0
	for _ = 1, math.floor(seconds / FRAME + 0.5) do
		x += v / W * FRAME
		yaw, roll = SteerPose.step(state, POSE, x, FRAME, FWD, W, look)
	end
	return x, yaw, roll
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	-- SteerPose ------------------------------------------------------------------------------
	check(POSE.yawMaxDeg == 10 and POSE.leanMaxDeg == 3 and POSE.lookDeg == 3 and POSE.yawSmoothSeconds == 0.15
		and POSE.leanDegPerFtps2 == 0.12 and POSE.lookRelaxSeconds == 0.3 and POSE.yawGain == 1,
		"GameConfig.steerView holds D-057's body values")
	local still = SteerPose.new()
	local _, yaw0, roll0 = glide(still, 3, 0, 2)
	check(yaw0 == 0 and roll0 == 0, "no sideways drift: no turn and no lean")
	local cruise = SteerPose.new()
	local _, yawC, rollC = glide(cruise, 3, 9, 2)
	check(close(yawC, math.atan(9 / FWD), 1e-6) and math.abs(rollC) < 1e-4,
		"a steady 9 ft/s drift turns the body by its true drift, atan(9 / 56) = 9.1 degrees, with no lean")
	local fast = SteerPose.new()
	local _, yawF = glide(fast, 3, 30, 1)
	check(close(yawF, math.rad(10), 1e-9), "never past 10 degrees")
	local left = SteerPose.new()
	local _, yawL = glide(left, 5, -9, 2)
	check(close(yawL, -math.atan(9 / FWD), 1e-6), "toward the rail turns the other way")
	-- Smoothed: one frame after a glide starts at full speed, the body has barely begun to turn.
	local start = SteerPose.new()
	SteerPose.step(start, POSE, 3, FRAME, FWD, W, 0)
	local y1 = SteerPose.step(start, POSE, 3 + 9 / W * FRAME, FRAME, FWD, W, 0)
	check(y1 > 0 and y1 < 0.15 * math.atan(9 / FWD), "smoothed: a sudden drift turns the body over yawSmoothSeconds, never at once")
	-- Lean: into the move as it speeds up (27 ft/s^2 would be 3.2 degrees: capped at 3), back as it settles.
	local lean = SteerPose.new()
	local x, v, maxRoll, minRoll, maxStep, lastYaw = 3, 0, 0, 0, 0, 0
	SteerPose.step(lean, POSE, x, FRAME, FWD, W, 0)
	for k = 1, 120 do
		local a = if k <= 20 then 27 elseif k <= 40 then -27 else 0
		v += a * FRAME
		x += v / W * FRAME
		local yaw, roll = SteerPose.step(lean, POSE, x, FRAME, FWD, W, 0)
		maxRoll, minRoll = math.max(maxRoll, roll), math.min(minRoll, roll)
		maxStep = math.max(maxStep, math.abs(yaw - lastYaw))
		lastYaw = yaw
	end
	check(maxRoll > math.rad(1.5) and maxRoll <= math.rad(3) + 1e-12 and minRoll < -math.rad(1) and minRoll >= -math.rad(3) - 1e-12,
		string.format("leans into the move as it starts (%.1f deg) and the other way as it settles (%.1f deg), at most 3", math.deg(maxRoll), math.deg(minRoll)))
	check(math.abs(lean.yaw) < math.rad(0.05) and math.abs(lean.roll) < math.rad(0.05), "...and stands straight once it has landed")
	check(maxStep < math.rad(0.5), string.format("no snap: the body turns at most %.2f degrees a frame through a glide", math.deg(maxStep)))
	-- The look cue: toward your press at once (within a few frames), relaxed over lookRelaxSeconds.
	local look = SteerPose.new()
	glide(look, 3, 0, 0.1, 0)
	local _, yawLook = glide(look, 3, 0, 0.1, -1)
	check(yawLook < -math.rad(2.5) and yawLook >= -math.rad(3), string.format("your press: the body looks toward it at once (%.1f deg in 0.1 s)", math.deg(yawLook)))
	local _, yawHeld = glide(look, 3, 0, 0.5, -1)
	check(close(yawHeld, -math.rad(3), 1e-3), "...3 degrees, held while the press is on its way")
	local _, yawRelax = glide(look, 3, 0, 0.15, 0)
	local _, yawGone = glide(look, 3, 0, 0.3, 0)
	check(yawRelax < 0 and yawRelax > yawHeld and yawGone == 0, "...and relaxed over lookRelaxSeconds when the press waits")
	local hand = SteerPose.new()
	glide(hand, 3, 0, 0.2, -1)
	local _, yawHand = glide(hand, 3, -9, 1, 0)
	check(close(yawHand, -math.atan(9 / FWD), 1e-3), "the look hands over to the drift as the slide starts (the larger counts)")
	-- At the line horses slow down; a drift there never turns past the cap.
	local stop = SteerPose.new()
	SteerPose.step(stop, POSE, 3, FRAME, 0, W, 0)
	local yawStop = 0
	for k = 1, 60 do yawStop = SteerPose.step(stop, POSE, 3 + k * 0.001, FRAME, 0, W, 0) end
	check(yawStop > 0 and yawStop <= math.rad(10), "a horse pulling up past the line never turns past the cap")
	local primed = SteerPose.new()
	local yP, rP = SteerPose.prime(primed, POSE, 3.4, 9, FWD)
	local yP2, rP2 = SteerPose.step(primed, POSE, 3.4 + 9 / W * FRAME, FRAME, FWD, W, 0)
	check(close(yP, math.atan(9 / FWD), 1e-12) and rP == 0 and close(yP2, yP, 1e-9) and math.abs(rP2) < 1e-9,
		"SteerPose.prime: a replay starting mid-glide turns at once with the glide, and doesn't flick into a lean")
	SteerPose.reset(stop)
	check(stop.x == nil and stop.yaw == 0 and select(1, SteerPose.step(stop, POSE, 7, FRAME, FWD, W, 0)) == 0,
		"after a reset (a replay starting) the first frame turns nothing")
	-- The sign convention: toward higher lanes is the horse's right.
	local ry, rz = SteerPose.angles(math.rad(5), math.rad(2))
	local lookV = aboutY({ 0, 0, -1 }, ry)
	local up = aboutY(aboutZ({ 0, 1, 0 }, rz), ry)
	check(lookV[1] > 0 and up[1] > 0, "SteerPose.angles: a turn and lean toward higher lanes swing the nose and the top to the horse's right (+X)")

	-- Playback -------------------------------------------------------------------------------
	local cfg = Playback.config(GameConfig)
	check(cfg.interval == 0.1 and cfg.slew <= 0.05, "Playback: one send interval of 0.1 s; the clock changes speed by at most 5%")
	-- The server's samples of a lane gliding at a steady rate (1 lane/s from t = 1), stamped by
	-- tick; the same race arriving with no jitter and with 0-30 ms of jitter.
	local function run(latency: number, jitter: number, seed: number): (number, number, number, number)
		local rng = seed
		local function u(): number
			rng = (rng * 1103515245 + 12345) % 2147483648
			return rng / 2147483648
		end
		local b = Playback.new(cfg)
		local inbox = {}
		for k = 0, 80 do
			local T = k * 0.1
			table.insert(inbox, { at = T + latency + jitter * u(), T = T, x = 3 + math.max(0, T - 1) })
		end
		local drawn, lastX, lastV, maxDv, back, holds, delay = {}, nil, nil, 0, 0, 0, 0
		local tc = 0
		while tc < 8.8 do
			tc += FRAME
			while #inbox > 0 and inbox[1].at <= tc do
				local m = table.remove(inbox, 1)
				Playback.push(b, m.T, tc, { x = { m.x } })
			end
			local play = Playback.advance(b, tc, FRAME)
			if play then
				local a, c, f = Playback.around(b, play)
				local x = Playback.lerp(drawn, a.data.x, c.data.x, f)[1]
				if lastX then
					local vNow = (x - lastX) / FRAME
					if lastV and tc > 3 and tc < 8 then maxDv = math.max(maxDv, math.abs(vNow - lastV)) end
					if x < lastX - 1e-12 then back += 1 end
					lastV = vNow
				end
				lastX = x
				if b.held and tc > 3 and tc < 8 then holds += 1 end
				if tc > 6 and delay == 0 then delay = b.delay :: number end
			end
		end
		return maxDv, back, holds, delay
	end
	local dv0, back0, holds0 = run(0.1, 0, 1)
	local dvJ, backJ, holdsJ, delayJ = run(0.1, 0.03, 7)
	local dvL, backL, holdsL, delayL = run(0.25, 0.03, 9)
	check(back0 + backJ + backL == 0, "Playback never draws a lane going back")
	check(holds0 + holdsJ + holdsL == 0, "...and never holds mid-glide: 0-30 ms of jitter at 0.1 s and 0.25 s links")
	check(dv0 < 0.02 and dvJ < 0.02 and dvL < 0.02,
		string.format("...so a steady glide is drawn at a steady speed (speed changes %.3f / %.3f / %.3f lanes/s a frame)", dv0, dvJ, dvL))
	check(delayJ > 0.1 + 0.1 and delayJ < 0.1 + 0.03 + 0.1 + cfg.margin + 0.02 and delayL > delayJ + 0.1,
		string.format("...a delay of the link's lag plus one interval plus a margin (%.3f s at 0.1 s, %.3f s at 0.25 s)", delayJ, delayL))
	-- A late sample: hold the newest, then carry on from it (never jump ahead or back).
	local hb = Playback.new(cfg)
	for k = 0, 10 do Playback.push(hb, k * 0.1, k * 0.1 + 0.05, { x = { k } }) end
	local p1 = Playback.advance(hb, 1.3, FRAME) :: number
	local p2 = Playback.advance(hb, 1.6, 0.3) :: number
	check(p2 <= 1.0 + 1e-12 and hb.held and p2 >= p1, "a late sample: the screen holds the newest sample, never guessing ahead")
	Playback.push(hb, 1.1, 1.62, { x = { 11 } })
	local p3 = Playback.advance(hb, 1.62 + FRAME, FRAME) :: number
	check(p3 >= p2 and p3 < 1.1 and not hb.held, "...and carries on from it when the sample arrives")
	check(not Playback.push(hb, 1.05, 1.7, { x = { 0 } }) and not Playback.push(hb, 1.1, 1.7, { x = { 0 } }),
		"a sample older than the newest (or a repeat) is dropped")
	local empty = Playback.new(cfg)
	check(Playback.advance(empty, 5, FRAME) == nil, "before the first sample there is nothing to draw")
	-- Lanes ride only on the samples where they changed: the others carry the newest sample's on, and a
	-- packet overtaken by a later one (unreliable remotes) is dropped whole, so its lanes never come back.
	local lb = Playback.new(cfg)
	local posts = { 1, 2 }
	check(Playback.pushOffsets(lb, 1.0, 1.1, { 0, 0 }, nil, posts) and lb.samples[1].data.lanes[2] == 2,
		"pushOffsets: before any lanes, the posts")
	Playback.pushOffsets(lb, 1.2, 1.3, { 0, 0 }, { 1, 2.5 }, posts)
	check(not Playback.pushOffsets(lb, 1.1, 1.35, { 0, 0 }, { 1, 2.2 }, posts), "...an overtaken packet is dropped, lanes and all")
	Playback.pushOffsets(lb, 1.3, 1.4, { 0, 0 }, nil, posts)
	check(lb.samples[#lb.samples].data.lanes[2] == 2.5, "...and a sample without lanes carries the newest sample's on")
	-- A client freeze: every packet queued during it arrives at once. Only the newest says how late
	-- the link is, so the delay is back to normal within a few seconds, not half a race.
	local fz = Playback.new(cfg)
	local queued, tcF, delayAfter = {}, 0, 0
	for kk = 0, 400 do table.insert(queued, { T = kk * 0.1, at = kk * 0.1 + 0.1 }) end
	local normal = 0
	while tcF < 20 do
		local frozen = tcF >= 3 and tcF < 3.8
		if not frozen then
			tcF += FRAME
			while #queued > 0 and queued[1].at <= tcF do
				local m = table.remove(queued, 1)
				Playback.push(fz, m.T, tcF, { x = { 0 } })
			end
			Playback.advance(fz, tcF, FRAME)
			if tcF > 2.5 and tcF < 2.6 then normal = fz.delay :: number end
			if tcF > 7 and delayAfter == 0 then delayAfter = fz.delay :: number end
		else
			tcF = 3.8 -- (nothing runs while frozen)
		end
	end
	check(normal > 0 and delayAfter < normal + 0.1,
		string.format("a 0.8 s client freeze: the delay is back near normal 3 s later (%.2f s, normal %.2f s)", delayAfter, normal))
	local out = Playback.lerp({}, { 1, 2 }, { 3, 6 }, 1)
	check(out[1] == 3 and out[2] == 6 and Playback.lerp({}, { 1 }, { 3 }, 0.5)[1] == 2, "lerp: exactly the later sample at f = 1")

	-- Bots, Smart Steer and riders glide the same way: Trip's eased lanes played back give every
	-- horse the same body motion (a whole race, every horse, through the jittery link).
	local track = require("../../game/src/shared/TrackLayout")
	local plan = track.plan(track.courses.dirt, track.distances.Mile)
	local st = Trip.new({ 1, 2, 3, 4, 5, 6, 7, 8 }, table.create(8, 1 / 8), table.create(16, 0.5),
		track.phaseA(track.courses.dirt, plan), GameConfig.steering, { "bot", "smart", "manual", "bot", "smart", "manual", "bot", "smart" },
		Trip.raceParams(GameConfig))
	local b = Playback.new(cfg)
	local poses = {}
	for i = 1, 8 do poses[i] = SteerPose.new() end
	local maxYaw, maxRollAll, moved, drawn = 0, 0, 0, table.create(8, 0)
	local lockT = Trip.lockTime(st.geo, Trip.raceParams(GameConfig))
	local inbox, rng = {}, 3
	local tc, k = 0, 0
	while k * 0.1 < 40 do
		if k * 0.1 < lockT - 1e-9 then
			Trip.step(st, table.create(8, 1 / 8), if k == 30 then { { 3, 1 } } elseif k == 90 then { { 6, -1 } } else {}, k * 0.1, 0.1)
		end
		rng = (rng * 1103515245 + 12345) % 2147483648
		table.insert(inbox, { at = k * 0.1 + 0.1 + 0.03 * rng / 2147483648, T = k * 0.1, x = table.clone(st.x) })
		local stop = (k + 1) * 0.1
		while tc < stop - 1e-9 do
			tc += FRAME
			while #inbox > 0 and inbox[1].at <= tc do
				local m = table.remove(inbox, 1)
				Playback.push(b, m.T, tc, { x = m.x })
			end
			local play = Playback.advance(b, tc, FRAME)
			if play then
				local a, c, f = Playback.around(b, play)
				Playback.lerp(drawn, a.data.x, c.data.x, f)
				for i = 1, 8 do
					local yaw, roll = SteerPose.step(poses[i], POSE, drawn[i], FRAME, FWD, W, 0)
					maxYaw, maxRollAll = math.max(maxYaw, math.abs(yaw)), math.max(maxRollAll, math.abs(roll))
				end
			end
		end
		k += 1
	end
	for i = 1, 8 do
		if st.x[i] ~= i then moved += 1 end
	end
	check(moved >= 3 and maxYaw > math.rad(5) and maxYaw <= math.rad(10) + 1e-12 and maxRollAll <= math.rad(3) + 1e-12,
		string.format("bots, Smart Steer and riders turn the same way through their glides: %d horses moved, the most %.1f deg turn and %.1f deg lean",
			moved, math.deg(maxYaw), math.deg(maxRollAll)))
end
