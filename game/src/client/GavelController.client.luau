--!nonstrict
-- GavelController: prototype race UI. Shows the field, the gavel meter, a big
-- tap button (also Space / gamepad A), live win chances, and results.
-- Draws the meter from the shared server clock; scoring happens on the server.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GavelMeter = require(Shared:WaitForChild("GavelMeter"))
local ThemePack = require(Shared:WaitForChild("ThemePack"))
local remotes = ReplicatedStorage:WaitForChild("GavelRemotes")

local player = Players.LocalPlayer
local myId = tostring(player.UserId)

-- UI construction -----------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "GavelUI"
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
	l.Parent = parent
	return l
end

local status = label(gui, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 40), "", 24)

local board = Instance.new("Frame")
board.Size = UDim2.new(0, 300, 0, 8 * 26 + 10)
board.Position = UDim2.new(0, 12, 0, 90)
board.BackgroundColor3 = Color3.fromRGB(20, 30, 25)
board.BackgroundTransparency = 0.3
board.Parent = gui
local rows = {}
for i = 1, 8 do
	local row = label(board, UDim2.new(1, -12, 0, 24), UDim2.new(0, 6, 0, 5 + (i - 1) * 26), "", 16)
	row.TextXAlignment = Enum.TextXAlignment.Left
	rows[i] = row
end

local meter = Instance.new("Frame")
meter.Size = UDim2.new(0.8, 0, 0, 36)
meter.Position = UDim2.new(0.1, 0, 0.42, 0)
meter.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
meter.Visible = false
meter.Parent = gui

local function zone()
	local z = Instance.new("Frame")
	z.AnchorPoint = Vector2.new(0.5, 0)
	z.Size = UDim2.new(0.2, 0, 1, 0)
	z.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
	z.BorderSizePixel = 0
	z.Parent = meter
	return z
end
local zoneA, zoneB = zone(), zone()

local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Size = UDim2.new(0, 8, 1.6, 0)
marker.Position = UDim2.new(0, 0, 0.5, 0)
marker.BackgroundColor3 = Color3.new(1, 1, 1)
marker.ZIndex = 3
marker.Parent = meter

local windowName = label(gui, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.42, -40), "", 22)
local feedback = label(gui, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0.42, 44), "", 34)

local tapButton = Instance.new("TextButton")
tapButton.Size = UDim2.new(1, 0, 0.35, 0)
tapButton.Position = UDim2.new(0, 0, 0.65, 0)
tapButton.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
tapButton.BackgroundTransparency = 0.25
tapButton.Font = Enum.Font.GothamBlack
tapButton.TextSize = 48
tapButton.Text = ThemePack.words.tap
tapButton.Visible = false
tapButton.Parent = gui

-- State ---------------------------------------------------------------------
local lanes = {}
local chances = {}
local active = nil -- { window, open, close, spec, tapped }

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

local function tap()
	if not active or active.tapped then return end
	active.tapped = true
	remotes.Tap:FireServer(active.window, workspace:GetServerTimeNow())
	tapButton.Visible = false
end

tapButton.Activated:Connect(tap)
ContextActionService:BindAction("GavelTap", function(_, state)
	if state == Enum.UserInputState.Begin then tap() end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

RunService.RenderStepped:Connect(function()
	if not active then return end
	local t = workspace:GetServerTimeNow() - active.open
	if t < 0 then return end
	local spec = active.spec
	local pos = GavelMeter.position(t, spec.sweepSeconds)
	marker.Position = UDim2.new(0.5 + 0.5 * pos, 0, 0.5, 0)
	if spec.twoTargets then
		zoneA.Size = UDim2.new(0.1, 0, 1, 0)
		zoneB.Size = UDim2.new(0.1, 0, 1, 0)
		zoneA.Position = UDim2.new(0.25, 0, 0, 0)
		zoneB.Position = UDim2.new(0.75, 0, 0, 0)
		zoneB.Visible = true
	else
		local c = GavelMeter.targetCenter(t, spec)
		zoneA.Size = UDim2.new(0.2, 0, 1, 0)
		zoneA.Position = UDim2.new(0.5 + 0.5 * c, 0, 0, 0)
		zoneB.Visible = false
	end
	if workspace:GetServerTimeNow() > active.close then
		meter.Visible = false
		tapButton.Visible = false
		if not active.tapped then feedback.Text = "Missed! Tap when the marker is in the green." end
		active = nil
	end
end)

-- Server events -------------------------------------------------------------
remotes.LobbyStatus.OnClientEvent:Connect(function(seconds)
	status.Text = string.format("Next race in %d", seconds)
end)

remotes.RaceStarted.OnClientEvent:Connect(function(league, laneList, start)
	lanes = laneList
	chances = {}
	for i, lane in laneList do chances[i] = lane.chance end
	status.Text = league .. " race starting!"
	feedback.Text = ""
	renderBoard()
end)

remotes.WindowOpened.OnClientEvent:Connect(function(window, open, close, spec, name)
	active = { window = window, open = open, close = close, spec = spec, tapped = false }
	windowName.Text = name or ""
	meter.Visible = true
	tapButton.Visible = true
	feedback.Text = ""
end)

remotes.TapResult.OnClientEvent:Connect(function(window, score, labelText)
	feedback.Text = string.format("%s! %d", labelText, math.round(score))
end)

remotes.LiveChances.OnClientEvent:Connect(function(window, live)
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
	windowName.Text = ""
end)
