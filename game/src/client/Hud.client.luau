--!nonstrict
-- Hud: the dock at the bottom of the screen (D-035, D-037): Green Cash, your active horse
-- with its Energy, and the big RACE! button that puts you in line for the next race.
-- Hidden while you ride; toasts for friendly server notices.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local C = Ui.colors
local gui = Ui.screen("Hud", 4)

local HudEvents = ReplicatedStorage:FindFirstChild("HudEvents") -- local signals between client scripts
if not HudEvents then
	HudEvents = Instance.new("Folder")
	HudEvents.Name = "HudEvents"
	HudEvents.Parent = ReplicatedStorage
end
local function localEvent(name: string): BindableEvent
	local e = HudEvents:FindFirstChild(name)
	if not e then
		e = Instance.new("BindableEvent")
		e.Name = name
		e.Parent = HudEvents
	end
	return e
end
local OpenStarter = localEvent("OpenStarter")
local OpenMap = localEvent("OpenMap")
local OpenBoard = localEvent("OpenBoard")

-- Dock --------------------------------------------------------------------------
local dock = Instance.new("Frame")
dock.Name = "Dock"
dock.AnchorPoint = Vector2.new(0.5, 1)
dock.Position = UDim2.new(0.5, 0, 1, -14)
dock.Size = UDim2.new(0, 0, 0, 78)
dock.AutomaticSize = Enum.AutomaticSize.X
dock.BackgroundTransparency = 1
dock.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = dock

local function slot(width: number, order: number): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(0, width, 1, 0)
	holder.LayoutOrder = order
	holder.Parent = dock
	return holder
end

-- Green Cash
local cashSlot = slot(150, 1)
local cashCard = Ui.card(cashSlot, UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 1, -60), C.paper)
Ui.icon(cashCard, "cash", "💵", UDim2.fromOffset(40, 40), UDim2.new(0, 8, 0.5, -20))
local cashText = Ui.text(cashCard, "0", 28, { Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 52, 0, 0) })
cashText.TextXAlignment = Enum.TextXAlignment.Left
cashText.TextColor3 = C.cash

-- Active horse
local horseSlot = slot(230, 2)
local horseCard = Ui.card(horseSlot, UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.paper)
local coatDot = Instance.new("Frame")
coatDot.Size = UDim2.fromOffset(48, 48)
coatDot.Position = UDim2.new(0, 10, 0.5, -24)
coatDot.BackgroundColor3 = Ui.coatColors.bay
Ui.corner(coatDot, 24)
Ui.stroke(coatDot, 3)
coatDot.Parent = horseCard
Ui.text(coatDot, "🐴", 26, { Size = UDim2.fromScale(1, 1), TextScaled = true })
local horseName = Ui.text(horseCard, "No horse yet", 22, { Size = UDim2.new(1, -74, 0, 26), Position = UDim2.new(0, 66, 0, 8) })
horseName.TextXAlignment = Enum.TextXAlignment.Left
horseName.TextTruncate = Enum.TextTruncate.AtEnd
local hoofRow = Instance.new("Frame")
hoofRow.BackgroundTransparency = 1
hoofRow.Size = UDim2.new(1, -74, 0, 24)
hoofRow.Position = UDim2.new(0, 66, 0, 38)
hoofRow.Parent = horseCard
local hoofLayout = Instance.new("UIListLayout")
hoofLayout.FillDirection = Enum.FillDirection.Horizontal
hoofLayout.Padding = UDim.new(0, 3)
hoofLayout.VerticalAlignment = Enum.VerticalAlignment.Center
hoofLayout.Parent = hoofRow
local hoofs = {}
for k = 1, GameConfig.energy.maxPerRacer do
	local full = Ui.icon(hoofRow, "energy_hoof", "⚡", UDim2.fromOffset(22, 22))
	full.LayoutOrder = k
	hoofs[k] = full
end
local restLabel = Ui.text(hoofRow, "", 16, { Size = UDim2.new(0, 70, 1, 0), LayoutOrder = 99, TextXAlignment = Enum.TextXAlignment.Left })
restLabel.TextColor3 = C.plum

-- Map (D-035)
local mapSlot = slot(70, 4)
local mapBtn = Ui.button(mapSlot, "", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.sky, 20)
Ui.icon(mapBtn, "map", "🗺️", UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0.5, -22))
mapBtn.Activated:Connect(function() OpenMap:Fire() end)

-- Stable Board (D-043): no badge, no bell.
local boardSlot = slot(70, 3)
local boardBtn = Ui.button(boardSlot, "", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.cream, 20)
Ui.icon(boardBtn, "clipboard", "📋", UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0.5, -22))
boardBtn.Activated:Connect(function() OpenBoard:Fire() end)

-- Race button
local raceSlot = slot(170, 5)
local raceBtn = Ui.button(raceSlot, "🏁 RACE!", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.orange, 30)
local leaveBtn = Ui.button(raceSlot, "✕", UDim2.fromOffset(34, 34), UDim2.new(1, -20, 1, -88), C.white, 18)
leaveBtn.Visible = false
leaveBtn.ZIndex = 3

local inLine = false
local function setRaceButton(state: string, detail: string?)
	if state == "nohorse" then
		raceBtn.Text, raceBtn.BackgroundColor3 = "🐴 Pick a horse", C.gold
		leaveBtn.Visible = false
	elseif state == "line" then
		raceBtn.Text, raceBtn.BackgroundColor3 = "In line! " .. (detail or ""), C.teal
		leaveBtn.Visible = true
	else
		raceBtn.Text, raceBtn.BackgroundColor3 = "🏁 RACE!", C.orange
		leaveBtn.Visible = false
	end
end

local function render(data)
	if not data then return end
	cashText.Text = tostring(data.cash)
	local h = PlayerState.activeHorse()
	if h then
		horseName.Text = h.name
		coatDot.BackgroundColor3 = Ui.coatColors[h.coat] or Ui.coatColors.bay
		for k, icon in hoofs do
			local on = k <= h.energy
			for _, d in icon:GetDescendants() do
				if d:IsA("ImageLabel") then d.ImageTransparency = if on then 0 else 0.75 end
				if d:IsA("TextLabel") then d.TextTransparency = if on then 0 else 0.75 end
			end
		end
		local care = math.floor((h.care or 0) * 2 + 0.5)
		restLabel.Text = (if h.resting then "Resting " else "") .. string.rep("⭐", care)
		if not inLine then setRaceButton("idle") end
	else
		horseName.Text = "No horse yet"
		restLabel.Text = ""
		setRaceButton("nohorse")
	end
end

PlayerState.watch(function(data, before)
	render(data)
	if before and data.cash > before.cash then
		Ui.pop(cashCard)
	end
end)

raceBtn.Activated:Connect(function()
	if not PlayerState.data then
		Ui.toast("Your stable is loading…", "hay", "🐴")
		return
	end
	if not PlayerState.activeHorse() then
		OpenStarter:Fire()
		return
	end
	if inLine then return end
	raceRemotes:WaitForChild("JoinRace"):FireServer(true)
end)
leaveBtn.Activated:Connect(function()
	raceRemotes:WaitForChild("JoinRace"):FireServer(false)
end)

raceRemotes:WaitForChild("QueueStatus").OnClientEvent:Connect(function(isIn, count, seconds)
	inLine = isIn
	if isIn then
		local detail = if seconds then string.format("%ds", seconds) else ""
		if count and count > 1 then detail = string.format("%s · %d riders", detail, count) end
		setRaceButton("line", detail)
	else
		render(PlayerState.data)
	end
end)

gameRemotes:WaitForChild("Notice").OnClientEvent:Connect(function(text, icon)
	Ui.toast(text, icon)
end)

-- Hide the dock while you ride (RaceState knows your lane) and during the replay.
RunService.Heartbeat:Connect(function()
	local riding = RaceState.active and RaceState.myLane ~= nil
	local replay = Players.LocalPlayer.PlayerGui:FindFirstChild("ReplayUI")
	local hide = riding or (replay and replay.Enabled)
	if dock.Visible == hide then dock.Visible = not hide end
end)
