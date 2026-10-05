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
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local TrackLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackLayout"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

local player = Players.LocalPlayer
local HORSE_LENGTH = 8
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
local doneBtn = button("Done ✕", UDim2.new(1, -150, 0.015, 0), UDim2.fromOffset(130, 44))
local camBtn = button("Behind", UDim2.new(1, -290, 0.015, 0), UDim2.fromOffset(130, 44))

-- Playback ---------------------------------------------------------------------------
local playing = nil -- { rec, mode, clock, quarterT, crossT, endT, slowFrom, eventIdx, lastPlace, view, frozenUntil }

local function frameAt(rec, t: number)
	local frames = rec.frames
	if t <= frames[1].t then return frames[1], frames[1], 0 end
	for k = 2, #frames do
		if frames[k].t >= t then
			local a, b = frames[k - 1], frames[k]
			return a, b, (t - a.t) / math.max(1e-6, b.t - a.t)
		end
	end
	return frames[#frames], frames[#frames], 0
end

local function stop()
	if not playing then return end
	local rec = playing.rec
	playing = nil
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
	}
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

local function placeAll(rec, t: number, speed: number?)
	local a, b, f = frameAt(rec, t)
	local progress = {}
	for i = 1, rec.lanes do
		local p = (a[i] or 0) + ((b[i] or 0) - (a[i] or 0)) * f
		progress[i] = p
		-- Recorded lane positions (D-054): per frame when steering moved them, else the posts.
		local xa = (a.x and a.x[i]) or (rec.lane and rec.lane[i])
		local xb = (b.x and b.x[i]) or xa
		local x = if xa and xb then xa + (xb - xa) * f else nil
		RaceState.placeHorse(i, p, 0, rec.plan, rec.course, speed, x)
	end
	return progress
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
	local progress = placeAll(rec, t, speed)
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
		local cfg = TrackLayout.courses[rec.course or "dirt"] or TrackLayout.churchill
		local outside = TrackLayout.outerRadius(cfg) - TrackLayout.laneRadius(cfg, (rec.lane and rec.lane[subject]) or subject) + 12
		local eye = if playing.view == "side"
			then target + pivot.RightVector * outside + Vector3.new(0, 6, 0)
			else target - pivot.LookVector * 18 + Vector3.new(0, 7, 0)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, target), math.min(1, dt * 4))
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
