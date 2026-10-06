--!nonstrict
-- RaceView: animates the horses round the racecourse on every client (D-025, D-027,
-- D-033, D-036), so they gallop smoothly. Everyone gets the same timeline from the server, so
-- all screens show the same races. Riders are welded to their horse's saddle and move with it.
-- Both courses (dirt and turf) can race at once; every race on screen is animated, and the
-- one this client follows (RaceState.focus) also feeds the places, the race map and the replay.
--   Pace: the race clock runs on lane 1 (the rail). Every lane's progress is lane-1 feet over
--   the lane-1 length, so the order on screen is the race order in every lane; outer horses
--   cover their longer path a little faster, which nobody sees (D-055). Horses ease out of
--   the gate to full gallop and still reach the line as the race ends.
--   Where: rail coordinates (D-054). A horse is drawn at s = progress * railLength feet along
--   the lane-1 path and lane position x (TrackLayout.railPoint), so horses at the same s are
--   abreast on turns too. x starts at the horse's post (lane number = post since posts are
--   drawn). With steering on (TripInfo) the server sends what to show, all race: gaps and lanes
--   from its Trip up to the far-turn lock (Smart Steer, tuck-ins, holds), then the race shape's
--   gaps as they ease, held so no horse runs through another, with make-room lanes. Each sample
--   carries the server time it stands for, and the screen draws the race a little behind the
--   newest sample, interpolating gaps and lanes between the samples by those times (Playback,
--   D-057 N3): a sample that arrives early or late changes nothing, so the S-curve lane changes
--   keep their shape on a jittery link. Steering's gaps already grow in from the gate, so the
--   30% ramp below is skipped for those races.
--   Body (D-057 N3, SteerPose): with the eased glide every horse in a steering race turns with its
--   true drift (at most 10 degrees) and leans up to 3 degrees into a lane change, smoothed so
--   nothing snaps (D-054's linear glide, the switch-back, has no pose, as before D-057). Your own
--   press turns your horse 3 degrees toward it at once (the look cue, your screen only); the
--   sideways move itself starts with the server's lane, so a refused press never snaps back. With
--   the D-054 linear glide (the switch-back) your own lane change starts on your screen the
--   moment you press (S3) and hands over to the server's lane once it gets there, and the screen
--   draws the samples as D-054 did: offsets interpolated from each sample's arrival over one send
--   interval, lanes gliding linearly at the race's lane speed.
--   Gaps: the server sends each horse's offset from the pace a few times a second. Up to
--   the far turn it comes from live chance (skill); from the far turn to the last tap it
--   blends toward the projected finish order (luck), so late chargers come through and the
--   order on screen at the line is the result. No reshuffle at the line. A gap changes at a
--   believable rate (no lurching at checkpoints), faster only when a horse must reach its
--   place before the line.
--   Your own horse also gets a small nudge on a Great or Perfect tap (same size for
--   everyone, never luck), so a rider sees their tap work straight away. It is drawn only:
--   places are ranked without it, so the place badge never flickers.
-- It also records the followed race (positions 10 times a second) for the replay.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))
local SteerPredict = require(Shared:WaitForChild("SteerPredict"))
local SteerPose = require(Shared:WaitForChild("SteerPose"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Playback = require(Shared:WaitForChild("Playback"))

local myId = tostring(Players.LocalPlayer.UserId)
local BOB_HZ, BOB_STUDS = 1.8, 0.3
local PAST_LINE = 0.012     -- past the line, horses ease to a stop within about this fraction
local RECORD_HZ = 10
local VIEW = GameConfig.raceView
local STEER = GameConfig.steering
local POSE = GameConfig.steerView
local PLAYBACK = Playback.config(GameConfig)
local EASED = STEER.glide == "eased"
local SAMPLE_SECONDS = 1 / STEER.sendHz -- (D-054) interpolate the server's offsets over one send

-- The tap nudge rises over nudgeRiseSeconds and fades over nudgeFallSeconds; scaled so its
-- peak is tapNudgeFeet.
local RISE, FALL = VIEW.nudgeRiseSeconds, VIEW.nudgeFallSeconds
local NUDGE_PEAK = FALL / (RISE + FALL) * (RISE / (RISE + FALL)) ^ (RISE / FALL)
local function nudgeFeet(age: number): number
	if age < 0 or age > 6 * FALL then return 0 end
	return GameConfig.tapNudgeFeet * (1 - math.exp(-age / RISE)) * math.exp(-age / FALL) / NUDGE_PEAK
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Feet covered on lane 1 after `s` seconds of a race lasting `T` seconds over `len1` feet:
-- a quick ease out of the gate (time constant tau), then a steady gallop, reaching len1 at T.
local function paceFeet(s: number, T: number, len1: number): number
	if s <= 0 then return 0 end
	local tau = VIEW.gateEaseSeconds
	local v = len1 / (T - tau * (1 - math.exp(-T / tau)))
	return v * (s - tau * (1 - math.exp(-s / tau)))
end

-- races[course] = { course, cfg, start, T, len1, plan, lanes, myLane, offset = {}, target = {},
--   lane = {} (x per lane as drawn, updated in place: RaceState.lane is the same table),
--   laneTarget = {} (the newest sample's lanes), drawn = {} (the samples' lanes at the playback
--   time), pb (Playback: the timestamped samples), pose = {} (SteerPose per horse), steering
--   (TripInfo), lockAt, locked (TripLocked), predict and own (your own lane: SteerPredict's state and
--   view), done, doneAt, settleAt }
local races: { [string]: any } = {}

local function horseModel(courseId: string?, i: number): Model?
	local track = RaceState.trackFolder(courseId)
	local horses = track and track:FindFirstChild("Horses")
	return horses and horses:FindFirstChild("Lane" .. i)
end

local lastPlaced = setmetatable({}, { __mode = "k" }) -- horse -> { pos, t } for the legs
local lastBase = setmetatable({}, { __mode = "k" })   -- horse -> its last placement without the pose
-- A placement further than this from the last one is a jump (a replay starting or seeking), not
-- a stride: even a 3x replay covers under 35 studs in the longest frame the legs count (0.2 s).
local JUMP_STUDS = 60

-- Lane i at progress p (lane-1 feet over railLength) and lane position `x` (default: its post,
-- which is its lane number). `timeScale`: how fast the race clock runs (replays in slow motion),
-- so the legs pick the gait for the race's real speed. yaw and roll (radians, toward higher lanes;
-- SteerPose) turn and lean the body through a lane change; leanFeet and nod are a brush's (D-057
-- N5: drawn only, never in the lanes that rank the race).
local function place(i: number, p: number, bob: number, plan, courseId: string?, timeScale: number?, x: number?,
	yaw: number?, roll: number?, leanFeet: number?, nod: number?)
	local horse = horseModel(courseId, i)
	if not horse then return end
	local cfg = TrackLayout.courses[courseId or "dirt"] or TrackLayout.churchill
	local railLength = TrackLayout.railLength(cfg, plan)
	local px, pz, dx, dz = TrackLayout.railPoint(cfg, plan, p * railLength, (x or i) + (leanFeet or 0) / cfg.laneWidth)
	local pos = Vector3.new(px, bob, pz)
	local cf = CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz))
	lastBase[horse] = cf
	if (yaw and yaw ~= 0) or (roll and roll ~= 0) or (nod and nod ~= 0) then
		local ry, rz = SteerPose.angles(yaw or 0, roll or 0)
		-- (CFrame.Angles(x, y, z) is Rx * Ry * Rz: the nod turns about the track's sideways axis, the
		-- unturned body's X, then the turn about the nodded up axis, then the lean about the body's length.
		-- The turn is a few degrees at most, so the nod is all but about the turned body.)
		cf = cf * CFrame.Angles(SteerPose.nodAngle(nod or 0), ry, rz)
	end
	horse:PivotTo(cf)
	-- Running legs (D-051): stride with the ground actually covered since the last frame (the
	-- horizontal move between placed positions), so outer horses on turns and sideways glides
	-- (steering, S2) stride as far as they travel.
	if HorseLegs.has(horse) then
		local now = os.clock()
		local prev = lastPlaced[horse]
		local flat = Vector3.new(px, 0, pz)
		local dist = 0
		if prev then
			dist = (flat - prev.pos).Magnitude
			if dist > JUMP_STUDS then dist = 0 end
		end
		local dt = if prev then math.clamp(now - prev.t, 0, 0.2) else 0
		if prev then
			prev.pos, prev.t = flat, now
		else
			lastPlaced[horse] = { pos = flat, t = now }
		end
		HorseLegs.apply(horse, dist, dt, timeScale)
	end
end
RaceState.placeHorse = place -- the replay uses the same placement

-- Legs straight down and the body straight (no turn or lean) for every horse on a course (a race
-- or replay has ended, or the race was aborted).
function RaceState.restHorses(courseId: string?, lanes: number)
	for i = 1, lanes do
		local horse = horseModel(courseId, i)
		if horse then
			lastPlaced[horse] = nil
			local base = lastBase[horse]
			if base then horse:PivotTo(base) end
			HorseLegs.rest(horse)
		end
	end
end

-- The race you follow is over and the replay wants its horses: stop animating it now.
function RaceState.finishFollowed(): boolean
	local id = RaceState.focus
	local race = id and races[id]
	if not race then return not RaceState.active end
	if not race.done then return false end
	RaceState.restHorses(id, race.lanes)
	races[id] = nil
	RaceState.active = false
	return true
end

-- Past the line, ease to a stop instead of running on.
local function easePastLine(p: number): number
	if p <= 1 then return p end
	return 1 + PAST_LINE * (1 - math.exp(-(p - 1) / PAST_LINE))
end

remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList, start, cond, _resultAt, _burstOpen, courseId)
	courseId = courseId or "dirt"
	local cfg = TrackLayout.courses[courseId] or TrackLayout.churchill
	local plan = TrackLayout.plan(cfg, TrackLayout.distances[cond and cond.distance or "Sprint"] or TrackLayout.distances.Sprint)
	local len1 = plan.lengths[1]
	local race = {
		course = courseId, cfg = cfg, start = start, plan = plan, lanes = #laneList, offset = {}, target = {},
		lane = {}, laneTarget = {}, drawn = {}, pose = {}, steering = false, locked = false, pb = Playback.new(PLAYBACK),
		brushes = {}, -- (D-057 N5) { at (server time), mover, other, dir, started } still to draw or drawing
		from = {}, to = {}, sampleAt = 0, -- (D-054's linear glide) the offsets' glide to the newest sample
		done = false, len1 = len1, T = len1 / GameConfig.raceSpeedStudsPerSecond, predict = SteerPredict.new(),
	}
	for i, lane in laneList do
		race.offset[i], race.target[i], race.from[i], race.to[i] = 0, 0, 0, 0
		race.lane[i] = i -- x starts at the post (lanes are numbered by post, D-054)
		race.laneTarget[i], race.drawn[i] = i, i
		race.pose[i] = SteerPose.new()
		if lane.id == myId then race.myLane = i end
	end
	-- Your own lane as SteerPredict sees it: the lanes (eased: as played back; D-054's linear glide:
	-- the newest sample's) and the drawn offsets (the same tables, updated in place), and your own
	-- lane from the server (SteerLane) once it arrives.
	race.own = { me = race.myLane, lanes = GameConfig.lanes, x = if EASED then race.drawn else race.laneTarget,
		off = race.offset, srv = nil, cfg = STEER }
	local focus = RaceState.consider(courseId, laneList, start) -- a stale focus ends its HUD there
	races[courseId] = race
	if focus then
		RaceState.active, RaceState.final, RaceState.plan, RaceState.lanes = true, false, plan, #laneList
		RaceState.progress, RaceState.place, RaceState.order = {}, {}, {}
		RaceState.lane = race.lane
		RaceState.offset = race.offset
		RaceState.myLane = race.myLane
		RaceState.myHome = false
		RaceState.course = courseId
		RaceState.recording = { start = start, plan = plan, lanes = #laneList, frames = {}, events = {}, course = courseId,
			myLane = race.myLane, lane = table.clone(race.lane) }
		RaceState.nudgeAt = -math.huge
	end
	-- The stalls clear on this screen as the bell rings (the server's removal arrives a ping later).
	task.delay(math.max(0, start - serverNow()), function()
		if races[courseId] ~= race then return end
		local track = RaceState.trackFolder(courseId)
		if not track then return end
		for _, child in track:GetChildren() do
			if child.Name == "gate_stall" then child:Destroy() end
		end
	end)
end)

-- Your press, on your screen (SteerPredict). With the eased glide (D-057): the look cue, your
-- horse's body turning 3 degrees toward a lane with room at once; the move waits for the server.
-- With D-054's linear glide (the switch-back): a press from a resting lane starts your horse over at
-- once if that lane has room by the server's lanes; the server's answer (SteerLane's ack) ends the
-- prediction, and your horse then follows the lane the server has taken.
function RaceState.predictSteer(dir: number, seq: number): boolean
	local race = RaceState.focus and races[RaceState.focus]
	if not race or not race.myLane or not race.steering or race.locked then return false end
	if EASED then return SteerPredict.look(race.predict, race.own, dir, seq, os.clock()) end
	return SteerPredict.press(race.predict, race.own, dir, seq, os.clock())
end

-- Your own lane from the server (riders with the buttons, on change, up to the lock). The boxed-in
-- fields (a waiting press, tuck-back, each side's room) are RaceController's (D-057 N4).
remotes:WaitForChild("SteerLane").OnClientEvent:Connect(function(tgt, dest, ack, _wait, _waitAt, _tucking, _inSide, _outSide, _t, courseId)
	local race = races[courseId or "dirt"]
	if race and race.own then race.own.srv = { tgt = tgt, dest = dest, ack = ack } end
end)

-- (offsets, courseId) without steering; with it (offsets, [lanes,] serverTime, courseId), lanes
-- only when they changed (and once a second). The course id is always last.
remotes.RaceOffsets.OnClientEvent:Connect(function(offsets, a, b, c)
	local lanes, stamp, courseId = nil, nil, a
	if typeof(a) == "table" then
		lanes, a, b = a, b, c
	end
	if typeof(a) == "number" then stamp, courseId = a, b else courseId = a end
	local race = races[courseId or "dirt"]
	if not race then return end
	if race.steering and EASED then
		-- What to show at that server time (no second easing, so held gaps stay as the server holds
		-- them): the screen plays the samples back by their stamps (Playback). A packet overtaken by
		-- a later one is dropped whole, its lanes too.
		if not Playback.pushOffsets(race.pb, stamp or serverNow(), serverNow(), offsets, lanes, race.laneTarget) then return end
	end
	if lanes then
		for i, x in lanes do race.laneTarget[i] = x end
	end
	if race.steering and not EASED then
		-- (D-054) glide from where the horse is to the new sample over one send interval
		for i, feet in offsets do
			race.from[i], race.to[i] = race.offset[i], feet
		end
		race.sampleAt = os.clock()
	else
		for i, feet in offsets do race.target[i] = feet end
	end
end)

-- A brush (D-057 N5), stamped with the server time it happened: drawn when the race on screen
-- gets there (the playback time), a soft tick at the mover's horse as it starts. Your own brush
-- also steadies your horse (steadySeconds): no look cue for presses the server answers "steady".
remotes:WaitForChild("SteerBrush").OnClientEvent:Connect(function(mover, other, dir, at, courseId)
	local race = races[courseId or "dirt"]
	if not race or not race.steering then return end
	local stamp = at or serverNow()
	table.insert(race.brushes, { at = stamp, mover = mover, other = other, dir = dir, started = false })
	if mover == race.myLane and race.own then
		race.own.steadyUntil = os.clock() + math.max(0, stamp + STEER.steadySeconds - serverNow())
	end
end)

-- Steering (D-054): this race's lanes move, and lock at the far turn (server time lockAt).
remotes:WaitForChild("TripInfo").OnClientEvent:Connect(function(enabled, lockAt, courseId)
	local race = races[courseId or "dirt"]
	if not race then return end
	race.steering = enabled == true
	race.lockAt = lockAt
	local rec = RaceState.recording
	if race.steering and rec and rec.course == (courseId or "dirt") then rec.lockAt = lockAt end -- the replay's lock marker
	if race.steering then
		for i = 1, race.lanes do race.from[i], race.to[i] = race.offset[i], race.offset[i] end
	end
end)

-- The far-turn bell (D-054): lanes are locked; from here they only make room on screen (the
-- bell and "Lanes locked!" are RaceController's, for riders with the steering buttons).
remotes:WaitForChild("TripLocked").OnClientEvent:Connect(function(courseId)
	local race = races[courseId or "dirt"]
	if race then race.locked = true end
end)

remotes:WaitForChild("RaceAborted").OnClientEvent:Connect(function(courseId)
	local race = races[courseId or "dirt"]
	races[courseId or "dirt"] = nil
	if race then RaceState.restHorses(courseId or "dirt", race.lanes) end
	if race and RaceState.focus == (courseId or "dirt") then
		RaceState.active = false
		RaceState.recording = nil
	end
	if race and race.myLane then RaceState.releaseMyRace() end
end)

remotes.RaceFinished.OnClientEvent:Connect(function(summary, courseId)
	local race = races[courseId or "dirt"]
	if not race then return end
	race.done = true
	race.doneAt = serverNow()
	if RaceState.focus == (courseId or "dirt") then
		if RaceState.recording then RaceState.recording.summary = summary end
		-- The result arrives about a second before the leader reaches the line. Until then the
		-- places follow the horses (the same order by the line); the official order then holds.
		task.delay(math.max(0, race.start + race.T - serverNow()), function()
			if races[courseId or "dirt"] == race and RaceState.focus == (courseId or "dirt") then
				RaceState.setFinal(summary)
			end
		end)
	end
end)

local lastRecord = 0
RunService:BindToRenderStep("RaceView", Enum.RenderPriority.Camera.Value - 1, function(dt)
	local t = serverNow()
	local k = math.min(1, dt * VIEW.easePerSecond)
	local glide = dt / STEER.laneSeconds -- (D-054) lanes glide at the race's lane speed, linearly
	local clock = os.clock()
	for courseId, race in races do
		local isFocus = RaceState.focus == courseId -- only the followed race writes the shared state
		local s = t - race.start
		local base = paceFeet(s, race.T, race.len1)
		local gateSpeed = if s > 0 then 1 - math.exp(-s / VIEW.gateEaseSeconds) else 0
		local nudge = if isFocus then nudgeFeet(t - (RaceState.nudgeAt or -math.huge)) else 0
		-- Gaps change at a believable rate, unless a horse must hurry to be in its place by the line.
		local toLine = race.start + race.T - t
		local allowed = VIEW.maxGapFeetPerSecond * dt
		local allStopped = true
		if race.steering and EASED then -- the samples at the playback time (Playback)
			local play = Playback.advance(race.pb, t, dt)
			if play then
				local a, b, f = Playback.around(race.pb, play)
				Playback.lerp(race.offset, a.data.off, b.data.off, f)
				Playback.lerp(race.drawn, a.data.lanes, b.data.lanes, f)
			end
		end
		local laneWidth = race.cfg.laneWidth
		-- Brushes (D-057 N5): each starts when the race on screen reaches it; the mover's horse ticks
		-- softly, the mover's chip shows (RaceState.BrushDrawn), and the replay records it then (what
		-- this screen showed). One that arrives late starts from the beginning now (its clock restarts
		-- at the drawn time, so the horse never snaps into the middle of a lean); one the screen is
		-- already past (brushLeanSeconds) isn't drawn, ticked or recorded at all.
		local drawnAt = if race.steering and EASED and race.pb.play then race.pb.play else t
		for k = #race.brushes, 1, -1 do
			local b = race.brushes[k]
			local age = drawnAt - b.at
			if not b.started and age >= 0 then
				local how = SteerPose.brushStart(age, POSE)
				if how == "skip" then
					table.remove(race.brushes, k)
					continue
				end
				if how == "restart" then b.at, age = drawnAt, 0 end
				b.started = true
				local horse = horseModel(courseId, b.mover)
				local part = horse and (horse.PrimaryPart or horse:FindFirstChildWhichIsA("BasePart", true))
				if Sound and part then Sound.play("count_tick", POSE.brushVolume, part) end
				local rec = RaceState.recording
				if isFocus and rec and rec.course == courseId then
					table.insert(rec.events, { t = t, kind = "brush", mover = b.mover, other = b.other, dir = b.dir })
				end
				RaceState.BrushDrawn:Fire(courseId, b.mover, b.at)
			end
			if age > POSE.brushLeanSeconds + 0.1 then table.remove(race.brushes, k) end
		end
		for i = 1, race.lanes do
			if race.steering and not EASED then
				local f = math.clamp((clock - race.sampleAt) / SAMPLE_SECONDS, 0, 1)
				race.offset[i] = race.from[i] + (race.to[i] - race.from[i]) * f
			elseif not race.steering then -- (eased steering: race.offset is the playback's, above)
				local gap = race.target[i] - race.offset[i]
				local limit = if toLine <= VIEW.catchUpMarginSeconds then math.huge
					else math.max(allowed, math.abs(gap) * dt / (toLine - VIEW.catchUpMarginSeconds))
				race.offset[i] += math.clamp(gap * k, -limit, limit)
			end
			-- In place: RaceState.lane is this table. Eased: the samples' lanes as played back. D-054's
			-- linear glide: lanes glide toward the newest sample, and your own lane follows SteerPredict
			-- (your press, then the lane the server has taken; after the lock, the lanes everyone sees).
			if race.steering and EASED then
				race.lane[i] = race.drawn[i]
			elseif race.steering then
				local laneTo = race.laneTarget[i]
				if i == race.myLane then laneTo = SteerPredict.laneTo(race.predict, race.own, clock, race.locked) end
				race.lane[i] += math.clamp(laneTo - race.lane[i], -glide, glide)
			end
			-- Gaps grow in over the first 30% so the field leaves the gate together (with steering,
			-- the server's gaps already grow in from the gate).
			local ramp = if race.steering then 1 else math.min(1, base / (0.3 * race.len1))
			local feet = base + race.offset[i] * ramp
			local raw = math.max(0, feet / race.len1)
			local p = easePastLine(raw)
			local moving = s > 0 and raw < 1 + 3 * PAST_LINE
			if moving then allStopped = false end
			local speed = if raw > 1 then math.exp(-(raw - 1) / PAST_LINE) else gateSpeed
			local bob = BOB_STUDS * speed * math.abs(math.sin((t * BOB_HZ + i * 0.37) * math.pi))
			local shown = p
			if i == race.myLane and nudge > 0 then shown = p + nudge / race.len1 end
			-- The body through lane changes (SteerPose): every horse in a steering race; your own
			-- press's look cue on your horse (eased glide).
			local yaw, roll, leanFeet, nod = 0, 0, 0, 0
			if race.steering and EASED then
				local look = if i == race.myLane then SteerPredict.lookDir(race.predict, race.own, clock, race.locked) else 0
				yaw, roll = SteerPose.step(race.pose[i], POSE, race.lane[i], dt, GameConfig.raceSpeedStudsPerSecond * speed,
					laneWidth, look)
			end
			for _, b in race.brushes do
				if b.mover == i or b.other == i then
					local l, n = SteerPose.brush(drawnAt - b.at, POSE, b.mover == i, b.dir)
					leanFeet += l
					nod = math.max(nod, n)
				end
			end
			place(i, shown, bob, race.plan, courseId, nil, race.lane[i], yaw, roll, leanFeet, nod)
			if isFocus then
				RaceState.progress[i] = p
				if i == race.myLane and raw >= 1 + 2 * PAST_LINE then RaceState.myHome = true end
			end
		end
		if isFocus then
			RaceState.rank()
			-- Record for the replay.
			local rec = RaceState.recording
			if rec and rec.course == courseId and t - lastRecord >= 1 / RECORD_HZ and t >= race.start then
				lastRecord = t
				local frame = { t = t, x = table.clone(race.lane) } -- lane positions too (D-054)
				for i = 1, race.lanes do frame[i] = RaceState.progress[i] end
				table.insert(rec.frames, frame)
			end
		end
		if race.done and (allStopped or t - race.doneAt > GameConfig.runInSeconds + 4) then
			-- Stopped: the legs ease to standing (they keep being placed, standing still), then rest.
			race.settleAt = race.settleAt or t
			if t - race.settleAt >= VIEW.settleSeconds then
				RaceState.restHorses(courseId, race.lanes)
				races[courseId] = nil -- the horses stay where they stopped until the next race (or the replay)
				if isFocus then RaceState.active = false end
			end
		end
	end
end)
