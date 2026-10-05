--!nonstrict
-- Hud: the dock at the bottom of the screen (D-035, D-037): Green Cash, your active horse
-- with its Energy, and the big RACE! button that puts you in line for the next race.
-- Hidden while you ride; toasts for friendly server notices.
-- Touch screens (D-056): the dock keeps clear of the bottom-right column (Hop, Gallop) and of
-- the thumbstick zone (the cash and horse cards there are display-only; My Horses opens from a
-- 🐴 button), and 💎 is a quiet pill at the top right. Both shop doors stay shut around races.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DiamondProducts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DiamondProducts"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local C = Ui.colors
local gui = Ui.screen("Hud", 4)
local UserInputService = game:GetService("UserInputService")
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local LAYOUT = GameConfig.touchLayout
local gemOnPill = TOUCH and LAYOUT.gemPlacement == "topRight"

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
local OpenRacePicker = localEvent("OpenRacePicker")
local OpenHorses = localEvent("OpenHorses")
local OpenStyleShop = localEvent("OpenStyleShop")

-- Dock --------------------------------------------------------------------------
local dock = Instance.new("Frame")
dock.Name = "Dock"
dock.AnchorPoint = if TOUCH then Vector2.new(0, 1) else Vector2.new(0.5, 1)
dock.Position = if TOUCH then UDim2.new(0, 12, 1, -14) else UDim2.new(0.5, 0, 1, -14)
dock.Size = UDim2.new(0, 0, 0, 78)
dock.AutomaticSize = Enum.AutomaticSize.X
dock.BackgroundTransparency = 1
dock.Parent = gui
local dockScale = Instance.new("UIScale")
dockScale.Parent = dock
local function fitDock()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local width = math.max(1, dock.AbsoluteSize.X / dockScale.Scale)
	local room = cam.ViewportSize.X - 24 - (if TOUCH then LAYOUT.movementColumn else 0)
	dockScale.Scale = math.clamp(room / width, 0.55, 1)
end
dock:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitDock)
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitDock)
	fitDock()
end)
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
local cashSlot = slot(230, 1)
local cashCard = Ui.card(cashSlot, UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 1, -60), C.paper)
Ui.icon(cashCard, "cash", "💵", UDim2.fromOffset(36, 36), UDim2.new(0, 8, 0.5, -18))
local cashText = Ui.text(cashCard, "0", 26, { Size = UDim2.new(0.5, -50, 1, 0), Position = UDim2.new(0, 48, 0, 0) })
cashText.TextXAlignment = Enum.TextXAlignment.Left
cashText.TextColor3 = C.cash
-- Diamonds: tap to open the Tack & Paint shop (never opens by itself, D-050). On touch it's a
-- 48 px pill at the top right, below the Roblox top bar: no glow, pulse, badge or sound (D-056).
local gemBtn
if gemOnPill then
	cashText.Size = UDim2.new(1, -56, 1, 0)
	local inset = game:GetService("GuiService"):GetGuiInset()
	gemBtn = Ui.button(gui, "💎 0", UDim2.fromOffset(110, 48), UDim2.new(1, -12, 0, inset.Y + 8), C.sky, 20)
	gemBtn.AnchorPoint = Vector2.new(1, 0)
	gemBtn:SetAttribute("NoPop", true)
else
	gemBtn = Ui.button(cashCard, "💎 0", UDim2.new(0.5, -10, 1, -12), UDim2.new(0.5, 4, 0, 6), C.sky, 20)
end
gemBtn.Activated:Connect(function() OpenStyleShop:Fire() end)

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
-- Tap the horse card for My Horses (D-037). On touch the card sits in the thumbstick zone, so
-- it is display-only and a 🐴 button in the button group opens My Horses instead (D-056).
local function openHorses()
	if PlayerState.activeHorse() then OpenHorses:Fire() else OpenStarter:Fire() end
end
if not TOUCH then
	local horseHit = Instance.new("TextButton")
	horseHit.BackgroundTransparency = 1
	horseHit.Text = ""
	horseHit.Size = UDim2.fromScale(1, 1)
	horseHit.ZIndex = 5
	horseHit.Parent = horseCard
	horseHit.Activated:Connect(openHorses)
end
local restLabel = Ui.text(hoofRow, "", 16, { Size = UDim2.new(0, 70, 1, 0), LayoutOrder = 99, TextXAlignment = Enum.TextXAlignment.Left })
restLabel.TextColor3 = C.plum

if TOUCH then
	local horsesSlot = slot(70, 3)
	local horsesBtn = Ui.button(horsesSlot, "", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.gold, 20)
	Ui.icon(horsesBtn, "horse", "🐴", UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0.5, -22))
	horsesBtn.Activated:Connect(openHorses)
end

-- Map (D-035)
local mapSlot = slot(70, 5)
local mapBtn = Ui.button(mapSlot, "", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.sky, 20)
Ui.icon(mapBtn, "map", "🗺️", UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0.5, -22))
mapBtn.Activated:Connect(function() OpenMap:Fire() end)

-- Stable Board (D-043): no badge, no bell.
local boardSlot = slot(70, 4)
local boardBtn = Ui.button(boardSlot, "", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.cream, 20)
Ui.icon(boardBtn, "clipboard", "📋", UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0.5, -22))
boardBtn.Activated:Connect(function() OpenBoard:Fire() end)

-- Race button
local raceSlot = slot(170, 6)
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
	gemBtn.Text = "💎 " .. tostring(data.diamonds or 0)
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

-- The coin chime waits while you ride and until your results card is up: the prize is paid
-- about a second before the leader reaches the line, so an early chime would give the result
-- away (the dock, and so the cash card's pop, is hidden while you ride; see the Heartbeat below).
local coinOwed = false
local function playCoin()
	if not Sound or Sound.recent("job_done", 2) then return end -- a job claim already chimed
	Sound.play("coin")
end
PlayerState.watch(function(data, before)
	render(data)
	if before and data.cash > before.cash then
		Ui.pop(cashCard)
		if (RaceState.active and RaceState.myLane ~= nil) or RaceState.resultsPending then
			coinOwed = true
		else
			playCoin()
		end
	end
end)
RaceState.ResultsShown.Event:Connect(function(shown: boolean)
	if coinOwed and shown then playCoin() end
	coinOwed = false
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
	OpenRacePicker:Fire() -- pick a course and a horse (D-036)
end)
leaveBtn.Activated:Connect(function()
	raceRemotes:WaitForChild("JoinRace"):FireServer(false)
end)

local COURSE_SHORT = { dirt = "Dirt", turf = "Turf" }
raceRemotes:WaitForChild("QueueStatus").OnClientEvent:Connect(function(isIn, count, seconds, courseId)
	inLine = isIn
	if isIn then
		local detail = if seconds then string.format("%ds", seconds) else ""
		if COURSE_SHORT[courseId] then detail = string.format("%s %s", COURSE_SHORT[courseId], detail) end
		if count and count > 1 then detail = string.format("%s · %d riders", detail, count) end
		setRaceButton("line", detail)
	else
		render(PlayerState.data)
	end
end)

gameRemotes:WaitForChild("Notice").OnClientEvent:Connect(function(text, icon)
	Ui.toast(text, icon)
end)

-- Hide the dock while you ride (RaceState knows your lane), while a results card is up (it
-- would cover the replay buttons on a phone) and during the replay.
RunService.Heartbeat:Connect(function()
	local riding = RaceState.active and RaceState.myLane ~= nil
	local replay = Players.LocalPlayer.PlayerGui:FindFirstChild("ReplayUI")
	local hide = riding or RaceState.resultsOpen or (replay and replay.Enabled)
	if dock.Visible == hide then dock.Visible = not hide end
	-- The 💎 door: shut around races (D-050, D-056); the pill also steps aside for the race map.
	local gemShown = not RaceState.shopClosed(DiamondProducts.afterRaceSeconds)
	if gemOnPill then gemShown = gemShown and not (RaceState.active and not RaceState.watchHidden) and not hide end
	if gemBtn.Visible ~= gemShown then gemBtn.Visible = gemShown end
end)
