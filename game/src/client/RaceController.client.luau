--!nonstrict
-- RaceController: prototype race UI (D-022).
-- Giddy-up stretches: a ring closes on the hoof for each beat; tap anywhere (or
-- Space / gamepad A) on the beat. The on-screen beat is what counts; there is no
-- audio cue yet, and when there is it stays decoration (Bluetooth lag).
-- Final Burst: one tap on the sweeping meter, which starts at a random point.
-- Drawn from the shared server clock; all scoring happens on the server.
-- Placeholder shapes until the playtest art lands.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local HapticService = game:GetService("HapticService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BurstMeter = require(Shared:WaitForChild("BurstMeter"))
local Stride = require(Shared:WaitForChild("Stride"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ThemePack = require(Shared:WaitForChild("ThemePack"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local player = Players.LocalPlayer
local myId = tostring(player.UserId)

local function serverNow(): number
	return workspace:GetServerTimeNow()
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
local feedback = label(gui, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0.72, 0), "", 34)
local hint = label(gui, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.80, 0), "", 20)

-- Giddy-up: hoof target and the closing ring.
local HOOF = 110
local hoof = Instance.new("Frame")
hoof.AnchorPoint = Vector2.new(0.5, 0.5)
hoof.Position = UDim2.fromScale(0.5, 0.5)
hoof.Size = UDim2.fromOffset(HOOF, HOOF)
hoof.BackgroundColor3 = Color3.fromRGB(150, 95, 55)
hoof.ZIndex = 3
hoof.Visible = false
hoof.Parent = gui
round(hoof)
local hoofText = label(hoof, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), ThemePack.words.giddyUp, 18)

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromOffset(HOOF, HOOF)
ring.BackgroundTransparency = 1
ring.ZIndex = 3
ring.Visible = false
ring.Parent = gui
round(ring)
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 6
ringStroke.Color = Color3.fromRGB(255, 225, 90)
ringStroke.Parent = ring

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

-- State ---------------------------------------------------------------------
local lanes = {}
local chances = {}
-- active = { kind = "stride", seg, beats, half, lastTapBeat, tapsThisBeat }
--        | { kind = "burst", seg, open, close, spec, tapped }
local active = nil

local function renderBoard()
	for i, row in rows do
		local lane = lanes[i]
		if lane then
			local you = lane.id == myId and "  (you)" or ""
			row.Text = string.format("%s%s  %d%%  %s %d", lane.name, you, math.round((chances[i] or 0) * 100), ThemePack.words.purse, lane.purse)
			row.TextColor3 = lane.id == myId and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1)
		else
			row.Text = ""
		end
	end
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
	hoof.Visible, ring.Visible, meter.Visible, tapArea.Visible = false, false, false, false
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
		tapArea.Visible = false
	end
end

tapArea.Activated:Connect(tap)
ContextActionService:BindAction("RaceTap", function(_, state)
	if state == Enum.UserInputState.Begin then tap() end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

local lastBeatBuzzed = 0
RunService.RenderStepped:Connect(function()
	if not active then return end
	local t = serverNow()
	if active.kind == "stride" then
		local beats = active.beats
		-- The ring closes over the interval before the next beat and meets the hoof on it.
		local nextK = nil
		for k, b in beats do
			if b >= t - 0.05 then nextK = k break end
		end
		if nextK then
			local b = beats[nextK]
			local prev = if nextK > 1 then beats[nextK - 1] else b - (beats[2] - beats[1])
			local progress = math.clamp((b - t) / (b - prev), 0, 1)
			local size = HOOF * (1 + 1.6 * progress)
			ring.Size = UDim2.fromOffset(size, size)
			local onBeat = math.abs(t - b) < 0.06
			hoof.BackgroundColor3 = if onBeat then Color3.fromRGB(255, 225, 90) else Color3.fromRGB(150, 95, 55)
			if onBeat and lastBeatBuzzed ~= nextK then
				lastBeatBuzzed = nextK
				buzz()
			end
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
	for i, lane in laneList do chances[i] = lane.chance end
	local conditions = cond and string.format("%s · %s · %s", cond.distance, cond.surface, cond.weather) or ""
	status.Text = string.format("%s race: %s", league, conditions)
	feedback.Text, hint.Text = "", ""
	renderBoard()
end)

remotes.StretchOpened.OnClientEvent:Connect(function(seg, beats, name, half)
	active = { kind = "stride", seg = seg, beats = beats, half = half, lastTapBeat = 0, tapsThisBeat = 0 }
	segmentName.Text = string.format("%s: %s", name, ThemePack.words.giddyUp)
	feedback.Text, hint.Text = "", "Tap when the ring meets the hoof"
	hoof.Visible, ring.Visible, meter.Visible, tapArea.Visible = true, true, false, true
end)

remotes.StretchResult.OnClientEvent:Connect(function(_seg, score, labelText)
	feedback.Text = string.format("%s! %d", labelText, math.round(score))
	hint.Text = ""
end)

remotes.BurstOpened.OnClientEvent:Connect(function(seg, open, close, spec, name)
	active = { kind = "burst", seg = seg, open = open, close = close, spec = spec, tapped = false }
	segmentName.Text = name or ThemePack.words.burst
	feedback.Text, hint.Text = "", "One big tap in the glow. It counts double!"
	hoof.Visible, ring.Visible, meter.Visible, tapArea.Visible = false, false, true, true
end)

remotes.TapResult.OnClientEvent:Connect(function(_seg, score, labelText)
	feedback.Text = string.format("%s! %d", labelText, math.round(score))
	hint.Text = ""
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
