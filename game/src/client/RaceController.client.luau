--!nonstrict
-- RaceController: prototype race UI (D-022, art review 2026-10-04).
-- Giddy-up stretches: each beat sends a ring that closes on the hoof in the same
-- fixed time, so tempo changes show as ring spacing. Tap anywhere, any key, or any
-- gamepad button; the pulsing pad at the bottom is only a reminder, not a target.
-- The on-screen beat is what counts; audio, when added, stays decoration.
-- Final Burst: one tap on the sweeping meter, which starts at a random point. The
-- celebration plays on your own screen after it's scored; others see a sparkle.
-- Drawn from the shared server clock; all scoring happens on the server.
-- Placeholder shapes until the playtest art is imported.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HapticService = game:GetService("HapticService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BurstMeter = require(Shared:WaitForChild("BurstMeter"))
local Stride = require(Shared:WaitForChild("Stride"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ThemePack = require(Shared:WaitForChild("ThemePack"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local player = Players.LocalPlayer
local myId = tostring(player.UserId)
local RING_LEAD = GameConfig.stride.ringLeadSeconds

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function reducedMotion(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

-- UI construction -----------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RaceUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, size, pos, text, textSize)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize or 18
	l.Text = text or ""
	l.ZIndex = 5
	l.Parent = parent
	return l
end

local function round(frame, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0.5, 0)
	c.Parent = frame
	return c
end

-- Tap anywhere: a transparent full-screen button under the rest of the UI.
local tapArea = Instance.new("TextButton")
tapArea.Size = UDim2.fromScale(1, 1)
tapArea.BackgroundTransparency = 1
tapArea.Text = ""
tapArea.AutoButtonColor = false
tapArea.ZIndex = 1
tapArea.Visible = false
tapArea.Parent = gui

local status = label(gui, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 40), "", 24)

local board = Instance.new("Frame")
board.Size = UDim2.new(0, 300, 0, 8 * 26 + 10)
board.Position = UDim2.new(0, 12, 0, 90)
board.BackgroundColor3 = Color3.fromRGB(20, 30, 25)
board.BackgroundTransparency = 0.3
board.ZIndex = 4
board.Parent = gui
local rows = {}
for i = 1, 8 do
	local row = label(board, UDim2.new(1, -12, 0, 24), UDim2.new(0, 6, 0, 5 + (i - 1) * 26), "", 16)
	row.TextXAlignment = Enum.TextXAlignment.Left
	rows[i] = row
end

local segmentName = label(gui, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.30, 0), "", 24)
local feedback = label(gui, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0.66, 0), "", 34)
local hint = label(gui, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.73, 0), "", 20)

-- Giddy-up: hoof target and a pool of closing rings (several can be on screen).
local HOOF = 110
local hoof = Instance.new("Frame")
hoof.AnchorPoint = Vector2.new(0.5, 0.5)
hoof.Position = UDim2.fromScale(0.5, 0.5)
hoof.Size = UDim2.fromOffset(HOOF, HOOF)
hoof.BackgroundColor3 = Color3.fromRGB(60, 40, 30) -- dark, high contrast: the beat lands here
hoof.ZIndex = 3
hoof.Visible = false
hoof.Parent = gui
round(hoof)

local rings = {}
for i = 1, 4 do
	local r = Instance.new("Frame")
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.fromScale(0.5, 0.5)
	r.BackgroundTransparency = 1
	r.ZIndex = 4
	r.Visible = false
	r.Parent = gui
	round(r)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.fromRGB(255, 225, 90)
	stroke.Parent = r
	rings[i] = { frame = r, stroke = stroke }
end

-- The pulsing pad: kids look for a button, but any tap anywhere counts.
local pad = Instance.new("Frame")
pad.AnchorPoint = Vector2.new(0.5, 1)
pad.Position = UDim2.new(0.5, 0, 1, -24)
pad.Size = UDim2.new(0.7, 0, 0, 90)
pad.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
pad.BackgroundTransparency = 0.35
pad.ZIndex = 2
pad.Visible = false
pad.Parent = gui
round(pad, UDim.new(0, 24))
local padText = label(pad, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), ThemePack.words.giddyUp, 40)
padText.Font = Enum.Font.GothamBlack

-- Final Burst meter.
local meter = Instance.new("Frame")
meter.Size = UDim2.new(0.8, 0, 0, 36)
meter.Position = UDim2.new(0.1, 0, 0.45, 0)
meter.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
meter.ZIndex = 3
meter.Visible = false
meter.Parent = gui

local function zone()
	local z = Instance.new("Frame")
	z.AnchorPoint = Vector2.new(0.5, 0)
	z.Size = UDim2.new(0.2, 0, 1, 0)
	z.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
	z.BorderSizePixel = 0
	z.ZIndex = 3
	z.Parent = meter
	return z
end
local zoneA, zoneB = zone(), zone()

local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Size = UDim2.new(0, 8, 1.6, 0)
marker.Position = UDim2.new(0, 0, 0.5, 0)
marker.BackgroundColor3 = Color3.new(1, 1, 1)
marker.ZIndex = 4
marker.Parent = meter

-- Burst celebration (own screen only, after scoring).
local burstBanner = label(gui, UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.36, 0), "", 64)
burstBanner.Font = Enum.Font.GothamBlack
burstBanner.TextColor3 = Color3.fromRGB(255, 225, 90)
burstBanner.Visible = false

-- State ---------------------------------------------------------------------
local lanes = {}
local chances = {}
local sparkleUntil = {} -- lane id -> time a burst sparkle stops showing on the board
-- active = { kind = "stride", seg, beats, half, lastTapBeat, tapsThisBeat }
--        | { kind = "burst", seg, open, close, spec, tapped }
local active = nil

local function renderBoard()
	local t = os.clock()
	for i, row in rows do
		local lane = lanes[i]
		if lane then
			local you = lane.id == myId and "  ◀ YOU" or ""
			local sparkle = (sparkleUntil[lane.id] or 0) > t and " ✦" or ""
			row.Text = string.format("%d  %s%s%s  %d%%  %s %d", i, lane.name, sparkle, you,
				math.round((chances[i] or 0) * 100), ThemePack.words.purse, lane.purse)
			row.TextColor3 = lane.id == myId and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1)
		else
			row.Text = ""
		end
	end
end

-- During taps only the ring should stand out (art review).
local function setFocus(on: boolean)
	board.BackgroundTransparency = if on then 0.75 else 0.3
	for _, row in rows do row.TextTransparency = if on then 0.6 else 0 end
end

local function buzz()
	pcall(function()
		if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.4)
			task.delay(0.06, function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
			end)
		end
	end)
end

local function hideAll()
	hoof.Visible, meter.Visible, tapArea.Visible, pad.Visible = false, false, false, false
	for _, r in rings do r.frame.Visible = false end
	setFocus(false)
end

local function celebrate(score: number, labelText: string)
	burstBanner.Text = string.format("%s! %d", labelText, math.round(score))
	burstBanner.Visible = true
	burstBanner.TextTransparency = 0
	burstBanner.TextSize = 40
	TweenService:Create(burstBanner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = 64 }):Play()
	if score >= 80 and not reducedMotion() then
		local camera = workspace.CurrentCamera
		if camera then
			local fov = camera.FieldOfView
			local punch = TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { FieldOfView = fov - 3 })
			punch:Play()
		end
	end
	task.delay(1.6, function()
		TweenService:Create(burstBanner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

local function tap()
	if not active then return end
	local t = serverNow()
	if active.kind == "stride" then
		remotes.StrideTap:FireServer(active.seg, t)
		local k, err = Stride.nearest(active.beats, t)
		-- More than one tap around the same beat breaks stride (it scores against you).
		if active.lastTapBeat == k then
			active.tapsThisBeat += 1
		else
			active.lastTapBeat, active.tapsThisBeat = k, 1
		end
		if active.tapsThisBeat > 1 then
			feedback.Text = "Broke stride!"
			hint.Text = ThemePack.words.tooFast
		else
			feedback.Text = Stride.tapLabel(err, active.half, GameConfig.strideLabels)
			hint.Text = ""
		end
	elseif active.kind == "burst" and not active.tapped then
		active.tapped = true
		remotes.BurstTap:FireServer(active.seg, t)
		tapArea.Visible, pad.Visible = false, false
	end
end

tapArea.Activated:Connect(tap)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- typing in chat, menus
	local kind = input.UserInputType
	if kind == Enum.UserInputType.Keyboard or kind.Name:sub(1, 7) == "Gamepad" then
		tap()
	end
end)

local lastBeatBuzzed = 0
RunService.RenderStepped:Connect(function()
	if not active then
		return
	end
	local t = serverNow()
	if active.kind == "stride" then
		local beats = active.beats
		-- Each ring appears RING_LEAD before its beat and closes at a constant rate.
		local used = 0
		for k, b in beats do
			local ahead = b - t
			if ahead <= RING_LEAD and ahead >= -0.06 and used < #rings then
				used += 1
				local r = rings[used]
				local size = HOOF * (1 + 1.6 * math.max(ahead, 0) / RING_LEAD)
				r.frame.Size = UDim2.fromOffset(size, size)
				r.stroke.Transparency = if ahead > RING_LEAD * 0.8 then (ahead - RING_LEAD * 0.8) / (RING_LEAD * 0.2) else 0
				r.frame.Visible = true
			end
			if math.abs(ahead) < 0.06 and lastBeatBuzzed ~= k then
				lastBeatBuzzed = k
				buzz()
			end
		end
		for i = used + 1, #rings do rings[i].frame.Visible = false end
		local onBeat = false
		for _, b in beats do
			if math.abs(t - b) < 0.06 then onBeat = true break end
		end
		hoof.BackgroundColor3 = if onBeat then Color3.fromRGB(255, 225, 90) else Color3.fromRGB(60, 40, 30)
		-- Pulse only before the first ring; hold steady while rings are on screen so the
		-- pad never competes with the beat (art review).
		if t < beats[1] - RING_LEAD then
			pad.BackgroundTransparency = 0.35 + 0.2 * math.abs(math.sin(t * math.pi * 2))
		else
			pad.BackgroundTransparency = 0.35
		end
		if t > beats[#beats] + active.half + 0.1 then
			hideAll()
			active = nil
		end
	else
		local rel = t - active.open
		if rel < 0 then return end
		local spec = active.spec
		local pos = BurstMeter.position(rel, spec.sweepSeconds, spec.phase)
		marker.Position = UDim2.new(0.5 + 0.5 * pos, 0, 0.5, 0)
		if spec.twoTargets then
			zoneA.Size = UDim2.new(0.1, 0, 1, 0)
			zoneB.Size = UDim2.new(0.1, 0, 1, 0)
			zoneA.Position = UDim2.new(0.25, 0, 0, 0)
			zoneB.Position = UDim2.new(0.75, 0, 0, 0)
			zoneB.Visible = true
		else
			local c = BurstMeter.targetCenter(rel, spec)
			zoneA.Size = UDim2.new(0.2, 0, 1, 0)
			zoneA.Position = UDim2.new(0.5 + 0.5 * c, 0, 0, 0)
			zoneB.Visible = false
		end
		if t > active.close then
			if not active.tapped then feedback.Text = "Missed! Tap when the marker is in the glow." end
			hideAll()
			active = nil
		end
	end
end)

-- Server events -------------------------------------------------------------
remotes.LobbyStatus.OnClientEvent:Connect(function(seconds)
	status.Text = string.format("Next race in %d", seconds)
end)

remotes.RaceStarted.OnClientEvent:Connect(function(league, laneList, _start, cond)
	lanes = laneList
	chances = {}
	sparkleUntil = {}
	for i, lane in laneList do chances[i] = lane.chance end
	local conditions = cond and string.format("%s · %s · %s", cond.distance, cond.surface, cond.weather) or ""
	status.Text = string.format("%s race: %s", league, conditions)
	feedback.Text, hint.Text = "", ""
	burstBanner.Visible = false
	renderBoard()
end)

remotes.StretchOpened.OnClientEvent:Connect(function(seg, beats, name, half)
	active = { kind = "stride", seg = seg, beats = beats, half = half, lastTapBeat = 0, tapsThisBeat = 0 }
	segmentName.Text = name
	feedback.Text, hint.Text = "", "Tap when the ring meets the hoof"
	hoof.Visible, meter.Visible, tapArea.Visible, pad.Visible = true, false, true, true
	setFocus(true)
end)

remotes.StretchResult.OnClientEvent:Connect(function(_seg, score, labelText)
	feedback.Text = string.format("%s! %d", labelText, math.round(score))
	hint.Text = ""
end)

remotes.BurstOpened.OnClientEvent:Connect(function(seg, open, close, spec, name)
	active = { kind = "burst", seg = seg, open = open, close = close, spec = spec, tapped = false }
	segmentName.Text = name or ThemePack.words.burst
	feedback.Text, hint.Text = "", "One big tap in the glow. It counts double!"
	hoof.Visible, meter.Visible, tapArea.Visible, pad.Visible = false, true, true, true
	for _, r in rings do r.frame.Visible = false end
	setFocus(true)
end)

remotes.TapResult.OnClientEvent:Connect(function(_seg, score, labelText)
	feedback.Text = ""
	hint.Text = ""
	celebrate(score, labelText) -- the burst is scored on arrival; the window may still be open for others
end)

remotes.BurstSparkle.OnClientEvent:Connect(function(laneIds)
	local untilT = os.clock() + 4
	for _, id in laneIds do
		if id ~= myId then sparkleUntil[id] = untilT end
	end
	renderBoard()
	task.delay(4.1, renderBoard)
end)

remotes.LiveChances.OnClientEvent:Connect(function(_seg, live)
	local before = {}
	for i, v in chances do before[i] = v end
	chances = live
	renderBoard()
	for i, lane in lanes do
		if lane.id == myId then
			local delta = math.round((live[i] - (before[i] or 0)) * 100)
			local sign = delta >= 0 and "+" or ""
			status.Text = string.format("%s: %d%% (%s%d)", ThemePack.words.winChance, math.round(live[i] * 100), sign, delta)
		end
	end
end)

remotes.IntegrityNote.OnClientEvent:Connect(function(text)
	hint.Text = text -- private; the "Ask for a check" button needs review tooling (not built)
end)

remotes.RaceFinished.OnClientEvent:Connect(function(summary)
	local lines = {}
	for _, row in summary do
		if row.place <= 4 or row.id == myId then
			local cash = row.cash > 0 and string.format("  +%d", row.cash) or ""
			table.insert(lines, string.format("%d. %s%s", row.place, row.name, cash))
		end
	end
	status.Text = "Results"
	feedback.Text = table.concat(lines, "   ")
	segmentName.Text, hint.Text = "", ""
	hideAll()
	active = nil
end)
