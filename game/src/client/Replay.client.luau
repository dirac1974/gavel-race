--!nonstrict
-- Replay (D-034): watch the race again from the results card. Plays back only what was
-- recorded on this screen (RaceView, 10 frames a second) and ends on the official result:
-- no re-simulation, no ghost horses, nothing that wasn't shown live. Riders are still in
-- the saddle (they get off with Done), so you ride along in your own replay.
--   "Watch the finish": the final quarter at real speed.
--   "Whole race": the full race at 3x, slowing to real speed for the final quarter.
--   Camera: side-on, broadcast style, framed on your horse; "Behind" switches to the view
--   from behind your horse. With Reduced Motion on, a fixed camera at the finish line.
--   Slow motion over the last 2 s only when you won; after any other result the true
--   finish plays at normal speed, with a photo-finish still when it was close.
--   Overlays: REPLAY letterbox, your tap shapes as they happened, a pulse when your burst
--   landed, "+N" when you gained places. No tap pad, no race-again or shop prompts.
--   Steering (D-054 S4): horses run in the lanes recorded on this screen, on a smooth curve through
--   them (ReplayTrip.laneCurve; older recordings use the posts), turning and leaning through lane
--   changes as they did live with the eased glide (SteerPose, from the replayed lanes and progress,
--   D-057 N3; none with D-054's linear glide, the switch-back). A rider
--   who had the ◀ ▶ buttons sees their line up to the lock drawn
--   on the track behind their horse as a gold ribbon, green with chevrons through the turns where
--   they saved ground, wind lines while they were tucked in, and "Lanes locked!" as they pass the
--   lock marker (a bar across the track at the far-turn entry, shown in every steering race).
--   No ideal-line ghost: only what you did.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local TrackLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackLayout"))
local ReplayTrip = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ReplayTrip"))
local SteerPose = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SteerPose"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

local player = Players.LocalPlayer
local HORSE_LENGTH = 8
local POSED = GameConfig.steering.glide == "eased" -- bodies turn and lean (D-057); not with D-054's linear glide
local RESULT_ART = { Perfect = "label_perfect", Great = "label_great", Good = "label_good", Okay = "label_okay", Miss = "label_miss" }

local function reducedMotion(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

-- HUD -------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ReplayUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(y: number)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0.1, 0)
	f.Position = UDim2.fromScale(0, y)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Parent = gui
	return f
end
bar(0)
bar(0.9)
local tint = Instance.new("Frame") -- warm film tint so it's obviously not a live race
tint.Size = UDim2.fromScale(1, 1)
tint.BackgroundColor3 = Color3.fromHex("FFE2B0")
tint.BackgroundTransparency = 0.9
tint.BorderSizePixel = 0
tint.Parent = gui

local function text(size: UDim2, pos: UDim2, str: string, ts: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size, l.Position = size, pos
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextSize = ts
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.Text = str
	l.ZIndex = 3
	l.Parent = gui
	return l
end
local banner = text(UDim2.new(0, 220, 0.1, 0), UDim2.fromScale(0.02, 0), "● REPLAY", 30)
banner.TextColor3 = Color3.fromHex("FF6B6B")
banner.TextXAlignment = Enum.TextXAlignment.Left
local caption = text(UDim2.new(1, 0, 0, 60), UDim2.fromScale(0, 0.18), "", 44)
caption.TextColor3 = Color3.fromHex("FFD34D")
local gainTag = text(UDim2.new(0, 120, 0, 50), UDim2.fromScale(0.44, 0.75), "", 40)
gainTag.TextColor3 = Color3.fromHex("46C46A")
local tapIcon = Instance.new("ImageLabel")
tapIcon.AnchorPoint = Vector2.new(0.5, 0.5)
tapIcon.Position = UDim2.fromScale(0.5, 0.66)
tapIcon.Size = UDim2.fromOffset(64, 64)
tapIcon.BackgroundTransparency = 1
tapIcon.ZIndex = 3
tapIcon.Visible = false
tapIcon.Parent = gui

local function button(str: string, pos: UDim2, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size, b.Position = size, pos
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Text = str
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.fromHex("1F2430")
	b.ZIndex = 4
	b.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = b
	return b
end
-- Wind lines while you were tucked in behind a horse (as in the race).
local wind = Instance.new("Frame")
wind.Size = UDim2.fromScale(1, 1)
wind.BackgroundTransparency = 1
wind.ZIndex = 2
wind.Visible = false
wind.Parent = gui
local windLines = {}
for k = 1, 6 do
	local line = Instance.new("Frame")
	line.Size = UDim2.fromOffset(90, 3)
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BorderSizePixel = 0
	line.ZIndex = 2
	line.Parent = wind
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = line
	windLines[k] = line
end

-- Your line on the track (D-054 S4): flat strips just above the dirt, shown as your horse
-- passes them; green with chevrons where you saved ground; a bar across the track at the lock.
local GOLD, GREEN, BELL = Color3.fromHex("FFD34D"), Color3.fromHex("46C46A"), Color3.fromHex("F4EFE6")
local RIBBON_Y = 0.14
local tripFolder: Folder? = nil
local function strip(parent: Instance, a: Vector3, b: Vector3, width: number, colour: Color3): Part?
	local length = (b - a).Magnitude
	if length < 0.05 then return nil end
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = colour
	part.Size = Vector3.new(width, 0.06, length)
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
	part.Transparency = 1
	part.Parent = parent
	return part
end
local function clearTrip()
	if tripFolder then tripFolder:Destroy() end
	tripFolder = nil
end
-- Returns the ribbon's strips { t, parts } in time order (empty without a line to draw).
local function buildTrip(rec): { any }
	clearTrip()
	local cfg = TrackLayout.courses[rec.course or "dirt"] or TrackLayout.churchill
	local railLength = TrackLayout.railLength(cfg, rec.plan)
	local folder = Instance.new("Folder")
	folder.Name = "ReplayTrip"
	folder.Parent = workspace
	tripFolder = folder
	local function at(p: number, x: number): Vector3
		local px, pz = TrackLayout.railPoint(cfg, rec.plan, p * railLength, x)
		return Vector3.new(px, RIBBON_Y, pz)
	end
	local strips = {}
	local points = ReplayTrip.ribbon(rec, 3)
	if points then
		for k = 2, #points do
			local a, b = points[k - 1], points[k]
			local pa, pb = at(a.p, a.x), at(b.p, b.x)
			local parts = {}
			local main = strip(folder, pa, pb, 1.4, if b.saved then GREEN else GOLD)
			if main then table.insert(parts, main) end
			if b.saved and k % 4 == 0 and main then -- a chevron pointing the way you went
				local look = CFrame.lookAt(pb, pb + (pb - pa).Unit)
				local back = look.LookVector * -1.1
				for _, side in { -1, 1 } do
					local arm = strip(folder, pb + back + look.RightVector * 0.9 * side + Vector3.new(0, 0.02, 0),
						pb + Vector3.new(0, 0.02, 0), 0.35, GREEN)
					if arm then table.insert(parts, arm) end
				end
			end
			table.insert(strips, { t = b.t, parts = parts })
		end
	end
	if rec.lockAt then
		local lockP = TrackLayout.phaseA(cfg, rec.plan).lockS / railLength
		local bar = strip(folder, at(lockP, 0.5), at(lockP, cfg.lanes + 0.5), 1.2, BELL)
		if bar then
			bar.Transparency = 0.15
			local sign = Instance.new("BillboardGui")
			sign.Size = UDim2.fromOffset(150, 34)
			sign.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
			sign.MaxDistance = 400 -- not through the grandstand from across the course
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextStrokeTransparency = 0.3
			l.Text = "🔔 Lanes lock"
			l.Parent = sign
			sign.Adornee = bar
			sign.Parent = bar
		end
	end
	return strips
end

local doneBtn = button("Done ✕", UDim2.new(1, -150, 0.015, 0), UDim2.fromOffset(130, 44))
local camBtn = button("Behind", UDim2.new(1, -290, 0.015, 0), UDim2.fromOffset(130, 44))

-- Playback ---------------------------------------------------------------------------
local playing = nil -- { rec, mode, clock, quarterT, crossT, endT, slowFrom, eventIdx, lastPlace, view, frozenUntil }

-- The frames around t, the fraction between them, and the later one's index.
local function frameAt(rec, t: number)
	local frames = rec.frames
	if t <= frames[1].t then return frames[1], frames[1], 0, 1 end
	for k = 2, #frames do
		if frames[k].t >= t then
			local a, b = frames[k - 1], frames[k]
			return a, b, (t - a.t) / math.max(1e-6, b.t - a.t), k
		end
	end
	return frames[#frames], frames[#frames], 1, #frames -- (past the last frame: on it, f = 1)
end

local function stop()
	if not playing then return end
	local rec = playing.rec
	playing = nil
	clearTrip()
	wind.Visible = false
	if rec and RaceState.restHorses then RaceState.restHorses(rec.course, rec.lanes) end
	gui.Enabled = false
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if camera then
		-- Back to the riding camera if still in the saddle, otherwise the normal one.
		camera.CameraType = if humanoid and humanoid.SeatPart then Enum.CameraType.Follow else Enum.CameraType.Custom
	end
	RaceState.ReplayClosed:Fire()
end

local function start(mode: string)
	local rec = RaceState.recording
	-- The race is over (its results card is up): the replay takes its horses from RaceView, even
	-- while they're still pulling up past the line. Nothing to play: back to the card.
	if playing then return end
	local free = rec ~= nil and #rec.frames >= 10
		and (not RaceState.active or (RaceState.finishFollowed ~= nil and RaceState.finishFollowed()))
	if not free then
		RaceState.ReplayClosed:Fire()
		return
	end
	-- The final quarter starts when the leader passes 75% of the race; the finish is when
	-- the leader reaches the line.
	local lastT = rec.frames[#rec.frames].t
	local quarterT, crossT = rec.frames[1].t, lastT
	local quarterFound = false
	for _, f in rec.frames do
		local lead = 0
		for i = 1, rec.lanes do lead = math.max(lead, f[i] or 0) end
		if not quarterFound and lead >= 0.75 then
			quarterT, quarterFound = f.t, true
		end
		if lead >= 1 then
			crossT = f.t
			break
		end
	end
	local won, winner = false, nil
	for _, row in rec.summary or {} do
		if row.lane == rec.myLane and row.place == 1 then won = true end
		if row.place == 1 then winner = row.lane end
	end
	playing = {
		rec = rec, mode = mode, clock = if mode == "finish" then quarterT else rec.frames[1].t,
		quarterT = quarterT, crossT = crossT, endT = math.min(lastT, crossT + 1.5),
		slowFrom = if won then crossT - 2 else math.huge, -- slow motion only when you won
		eventIdx = 1, view = "side", frozenUntil = nil, lastPlace = nil, photoChecked = false,
		subject = rec.myLane or winner or 1, -- a spectator's replay follows the winner
		strips = buildTrip(rec), stripIdx = 1, lockShown = false,
		pose = {}, lastProgress = {}, -- SteerPose per horse, fresh: the first frame turns nobody
	}
	for i = 1, rec.lanes do playing.pose[i] = SteerPose.new() end
	-- "Watch the finish" starts after the lock: no "Lanes locked!" then.
	playing.lockShown = rec.lockAt ~= nil and playing.clock > rec.lockAt + 0.5
	-- skip events before the start point
	while playing.eventIdx <= #rec.events and rec.events[playing.eventIdx].t < playing.clock do
		playing.eventIdx += 1
	end
	caption.Text, gainTag.Text = "", ""
	tapIcon.Visible = false
	camBtn.Text = "Behind"
	camBtn.Visible = not reducedMotion()
	gui.Enabled = true
	local camera = workspace.CurrentCamera
	if camera then camera.CameraType = Enum.CameraType.Scriptable end
end

RaceState.ReplayRequested.Event:Connect(start)
doneBtn.Activated:Connect(stop)
camBtn.Activated:Connect(function()
	if not playing then return end
	playing.view = if playing.view == "side" then "behind" else "side"
	camBtn.Text = if playing.view == "side" then "Behind" else "Side"
end)
remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList, _start, _cond, _resultAt, _burstOpen, courseId)
	-- A new race of yours always wins, and so does a new race on the course you're replaying
	-- (its horses are about to move); a race on the other course doesn't stop it.
	if playing and (courseId or "dirt") == (playing.rec.course or "dirt") then
		stop()
		return
	end
	local myId = tostring(player.UserId)
	for _, lane in laneList do
		if lane.id == myId then
			stop()
			return
		end
	end
end)

-- Places every horse at time t (raceDt = race seconds since the last frame); returns their
-- progress and lane positions.
local function placeAll(rec, t: number, speed: number?, raceDt: number)
	local a, b, f, k = frameAt(rec, t)
	local progress, lanes = {}, {}
	local cfg = TrackLayout.courses[rec.course or "dirt"] or TrackLayout.churchill
	local railLength = TrackLayout.railLength(cfg, rec.plan)
	for i = 1, rec.lanes do
		local p = (a[i] or 0) + ((b[i] or 0) - (a[i] or 0)) * f
		progress[i] = p
		-- Recorded lane positions (D-054): per frame when steering moved them, else the posts.
		lanes[i] = ReplayTrip.laneCurve(rec, k, f, i)
		-- The body turns and leans as it did live (SteerPose): forward speed from the replayed
		-- progress, in race time, so a 3x or slow-motion replay turns the same way.
		local yaw, roll = 0, 0
		local last = playing.lastProgress[i]
		if POSED and last and raceDt > 0 then
			local forward = (p - last) * railLength / raceDt
			yaw, roll = SteerPose.step(playing.pose[i], GameConfig.steerView, lanes[i], raceDt, forward, cfg.laneWidth, 0)
		elseif POSED then -- the first frame: start at the sideways speed the recording has here (no flick mid-glide)
			local a0, b0, f0, k0 = frameAt(rec, t - 0.05)
			local before = ReplayTrip.laneCurve(rec, k0, f0, i)
			local p0 = (a0[i] or 0) + ((b0[i] or 0) - (a0[i] or 0)) * f0
			yaw, roll = SteerPose.prime(playing.pose[i], GameConfig.steerView, lanes[i], (lanes[i] - before) * cfg.laneWidth / 0.05,
				(p - p0) * railLength / 0.05)
		end
		playing.lastProgress[i] = p
		-- A brush recorded live (D-057 N5): the same lean and nod, no text.
		local leanFeet, nod = 0, 0
		for _, e in rec.events or {} do
			if e.kind == "brush" and (e.mover == i or e.other == i) and t >= e.t and t < e.t + GameConfig.steerView.brushLeanSeconds then
				local l, n = SteerPose.brush(t - e.t, GameConfig.steerView, e.mover == i, e.dir)
				leanFeet += l
				nod = math.max(nod, n)
			end
		end
		RaceState.placeHorse(i, p, 0, rec.plan, rec.course, speed, lanes[i], yaw, roll, leanFeet, nod)
	end
	return progress, lanes
end

local function myPlace(progress, me: number): number
	local place = 1
	for i, p in progress do
		if i ~= me and p > progress[me] then place += 1 end
	end
	return place
end

RunService.RenderStepped:Connect(function(dt)
	if not playing then return end
	local rec = playing.rec
	if playing.frozenUntil then
		if os.clock() >= playing.frozenUntil then stop() end
		return
	end
	local speed = if playing.mode == "full" and playing.clock < playing.quarterT then 3 else 1
	if playing.clock >= playing.slowFrom and playing.clock < playing.crossT then speed = 0.5 end
	playing.clock += dt * speed
	local t = playing.clock
	local progress, lanes = placeAll(rec, t, speed, dt * speed)
	local me = rec.myLane

	-- Camera.
	local camera = workspace.CurrentCamera
	local track = RaceState.trackFolder(rec.course)
	local subject = playing.subject
	local horse = track and track:FindFirstChild("Horses") and track.Horses:FindFirstChild("Lane" .. subject)
	if camera and reducedMotion() then
		if not RaceState.finishCam or RaceState.finishCamCourse ~= rec.course then
			RaceState.finishCamCourse = rec.course
			-- A fixed camera outside the finish line, looking across the track.
			local tl = require(ReplicatedStorage.Shared.TrackLayout)
			local x0, x1, lineZ = tl.finishLine(tl.courses[rec.course or "dirt"] or tl.churchill)
			RaceState.finishCam = CFrame.lookAt(Vector3.new(x1 + 30, 12, lineZ + 40), Vector3.new((x0 + x1) / 2, 3, lineZ))
		end
		camera.CFrame = RaceState.finishCam
	elseif camera and horse then
		local pivot = horse:GetPivot()
		local target = pivot.Position + Vector3.new(0, 4, 0)
		-- Side view from just outside the outer rail (broadcast angle), so no horse runs through it.
		-- The camera follows the track's heading at the horse, never its body turn or lean (D-057).
		local cfg = TrackLayout.courses[rec.course or "dirt"] or TrackLayout.churchill
		local outside = TrackLayout.outerRadius(cfg) - TrackLayout.laneRadius(cfg, lanes[subject] or subject) + 12 -- its lane now
		local _, _, dx, dz = TrackLayout.railPoint(cfg, rec.plan, (progress[subject] or 0) * TrackLayout.railLength(cfg, rec.plan),
			lanes[subject] or subject)
		local look, right = Vector3.new(dx, 0, dz), Vector3.new(-dz, 0, dx)
		local eye = if playing.view == "side"
			then target + right * outside + Vector3.new(0, 6, 0)
			else target - look * 18 + Vector3.new(0, 7, 0)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, target), math.min(1, dt * 4))
	end

	-- Your line on the track shows up to where your horse is now; wind lines while you were
	-- tucked in; "Lanes locked!" at the lock (riders who had the steering buttons).
	while playing.stripIdx <= #playing.strips and playing.strips[playing.stripIdx].t <= t do
		for _, part in playing.strips[playing.stripIdx].parts do part.Transparency = 0.3 end
		playing.stripIdx += 1
	end
	wind.Visible = rec.steer == true and ReplayTrip.tuckedAt(rec, t)
	if wind.Visible then
		local still = reducedMotion()
		for k, line in windLines do
			local phase = if still then 0.5 else (os.clock() * 1.2 + k * 0.37) % 1
			local y = 0.36 + 0.07 * ((k - 1) // 2)
			line.Position = if k % 2 == 1 then UDim2.new(0.3 - 0.25 * phase, -90, y, 0) else UDim2.new(0.7 + 0.25 * phase, 0, y, 0)
			line.BackgroundTransparency = 0.35 + 0.6 * phase
		end
	end
	if rec.steer and rec.lockAt and not playing.lockShown and t >= rec.lockAt then
		playing.lockShown = true
		caption.Text = "Lanes locked!"
		task.delay(1.5, function()
			if playing and caption.Text == "Lanes locked!" then caption.Text = "" end
		end)
	end

	-- Overlays: your taps, the burst, places gained.
	while playing.eventIdx <= #rec.events and rec.events[playing.eventIdx].t <= t do
		local e = rec.events[playing.eventIdx]
		playing.eventIdx += 1
		if (e.kind == "tap" or e.kind == "burst") and RESULT_ART[e.label] then
			if UiArt.set(tapIcon, RESULT_ART[e.label]) then
				tapIcon.Size = if e.kind == "burst" then UDim2.fromOffset(110, 110) else UDim2.fromOffset(64, 64)
				task.delay(if e.kind == "burst" then 1.2 else 0.4, function() tapIcon.Visible = false end)
			end
			if e.kind == "burst" then caption.Text = "FINAL BURST: " .. e.label .. "!" end
		elseif e.kind == "checkpoint" then
			caption.Text = string.rep("★", e.stars) .. string.rep("☆", 3 - e.stars)
		end
	end
	if me and progress[me] and t >= playing.quarterT then
		local place = myPlace(progress, me)
		if playing.lastPlace and place < playing.lastPlace then
			gainTag.Text = string.format("+%d", playing.lastPlace - place)
			task.delay(1.2, function() if playing then gainTag.Text = "" end end)
		end
		playing.lastPlace = place
	end

	-- At the line: a photo-finish still when 1st and 2nd were under a length apart.
	if not playing.photoChecked and t >= playing.crossT then
		playing.photoChecked = true
		local first, second
		for _, row in rec.summary or {} do
			if row.place == 1 then first = row.lane elseif row.place == 2 then second = row.lane end
		end
		if first and second and progress[first] and progress[second]
			and (progress[first] - progress[second]) * TrackLayout.railLength(TrackLayout.courses[rec.course or "dirt"] or TrackLayout.churchill, rec.plan)
				< HORSE_LENGTH then -- lane-1 feet (D-055)
			caption.Text = "PHOTO FINISH"
			if Sound then Sound.play("vo_photo") end
			playing.frozenUntil = os.clock() + 2.5
			return
		end
	end
	-- The end: the official result shows on the results card when the replay closes.
	if t >= playing.endT then
		playing.frozenUntil = os.clock() + 1.0
	end
end)
