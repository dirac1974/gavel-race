--!nonstrict
-- GrownUps (D-045, D-049): the ⚙️ button (top right) opens settings and a page for parents;
-- plus the first-ten-minutes tour card and the optional break reminder.
--   Settings: who can visit your stable (Friends or Nobody), break reminder on or off, sound on or off.
--   For grown-ups: how races work (no gambling, nothing buys speed), what's saved, chat and
--   safety, this week's play time, and where Roblox's parental controls live.
--   Tour: one friendly step at a time with a GO button (golden hoofprints) and Skip.
--   Break reminder: off by default; when on, a gentle note after each hour of play.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tour = require(Shared:WaitForChild("Tour"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors
local player = Players.LocalPlayer

local gui = Ui.screen("GrownUps", 12)

-- ⚙️ button --------------------------------------------------------------------------
local gear = Ui.button(gui, "⚙️", UDim2.fromOffset(52, 52), UDim2.new(1, -68, 0, 64), C.white, 26)

-- Panel ------------------------------------------------------------------------------
local panelGui = Ui.screen("GrownUpsPanel", 13)
panelGui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = panelGui
local W, H = 640, 470
local panel = Ui.card(panelGui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = Instance.new("UIScale")
scale.Parent = panel
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	local function rescale()
		local v = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (v.X - 20) / W, (v.Y - 20) / H)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
local closeBtn = Ui.button(panel, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 10), C.white, 22)
local tabs = Instance.new("Frame")
tabs.BackgroundTransparency = 1
tabs.Size = UDim2.new(1, -120, 0, 44)
tabs.Position = UDim2.new(0, 16, 0, 12)
tabs.Parent = panel
local tl = Instance.new("UIListLayout")
tl.FillDirection = Enum.FillDirection.Horizontal
tl.Padding = UDim.new(0, 8)
tl.Parent = tabs
local body = Instance.new("ScrollingFrame")
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, -32, 1, -76)
body.Position = UDim2.new(0, 16, 0, 64)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.CanvasSize = UDim2.new()
body.ScrollBarThickness = 6
body.Parent = panel
local bl = Instance.new("UIListLayout")
bl.Padding = UDim.new(0, 10)
bl.SortOrder = Enum.SortOrder.LayoutOrder
bl.Parent = body

local tab = "settings"
local render

local function para(text: string, size: number?, order: number)
	local l = Ui.text(body, text, size or 18, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order })
	return l
end

local function choice(label: string, options: { { string } }, current: any, onPick, order: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 52)
	row.LayoutOrder = order
	row.Parent = body
	Ui.text(row, label, 18, { Size = UDim2.new(0, 220, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -230, 1, 0)
	holder.Position = UDim2.new(0, 230, 0, 0)
	holder.Parent = row
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 8)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = holder
	for _, opt in options do
		local b = Ui.button(holder, opt[2], UDim2.fromOffset(150, 44), UDim2.new(), if opt[1] == current then C.gold else C.white, 17)
		b.Activated:Connect(function() onPick(opt[1]) end)
	end
end

local function settingsTab()
	local d = PlayerState.data
	if not d then return end
	choice("Who can visit my stable?", { { "Friends", "👫 Friends" }, { "Nobody", "🔒 Nobody" } }, d.settings.visits,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("visits", v) end, 1)
	choice("Break reminder (each hour)", { { true, "On" }, { false, "Off" } }, d.settings.breakReminder == true,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("breakReminder", v) end, 2)
	choice("Sound", { { true, "🔊 On" }, { false, "🔇 Off" } }, d.settings.sound ~= false,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("sound", v) end, 3)
	local tourBtn = Ui.button(body, "🧭 Show me around again", UDim2.fromOffset(260, 46), UDim2.new(), C.sky, 18)
	tourBtn.LayoutOrder = 4
	tourBtn.Activated:Connect(function()
		Ui.toast("Follow the steps at the top of the screen!", "map", "🧭")
		panelGui.Enabled = false
		gameRemotes:WaitForChild("SetSetting"):FireServer("tour", "restart")
	end)
	para("Visitors who aren't allowed in see a closed gate. Nobody can take, move or buy anything in your stable.", 15, 5).TextColor3 = C.plum
end

local function grownUpsTab()
	local d = PlayerState.data
	local mins = math.floor(((d and d.playtimeWeek) or 0) / 60)
	para("👋 Hello, grown-ups!", 24, 1)
	para(string.format("Play time this week: %d h %d min", mins // 60, mins % 60), 18, 2)
	para("🏁 How races work: each horse's chance comes from its care and training; riding well (tapping in time) moves it up; a little luck shows near the finish. There is no gambling of any kind: entry is free, prizes are fixed before the race, and nothing can be bought to win.", 16, 3)
	local shop = d and d.shop
	para("💎 Diamonds cost real money through Robux, 1 Diamond = 1 Robux in every pack (no bigger-pack bonus). They buy looks only: saddle cloths and helmets for riding around, barn paint, name plates and yard decor.", 16, 4)
	para("Never for sale: horses, coats, stats, speed, Green Cash, food, Energy, race entries, fan gear, trophies, rosettes or anything random.", 16, 41)
	para(string.format("Our own limits: the game won't offer more than %d Robux of Diamonds in 24 hours or %d in 30 days. Diamonds bought in the last 30 days: %d Robux. No buying in line, during a race, on the results screen or for two minutes after. Any look can be returned within a day for all its Diamonds; Robux refunds go through Roblox Support.",
		shop and shop.caps and shop.caps.dayRobux or 250, shop and shop.caps and shop.caps.monthRobux or 1000, shop and shop.monthRobux or 0), 16, 42)
	para("🐴 Horses never get sick, run away or come to harm if your child takes a break. There are no streaks to lose and no countdowns.", 16, 5)
	para("💬 Chat uses Roblox's own filtered chat and age settings. Horse names are built from a word list, so nothing can be typed.", 16, 6)
	para("🔒 Spending limits, chat and play-time controls live in Roblox's Parental Controls (Settings → Parental Controls on roblox.com).", 16, 7)
end

render = function()
	for _, ch in tabs:GetChildren() do if ch:IsA("TextButton") then ch:Destroy() end end
	for _, ch in body:GetChildren() do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	for _, t in { { "settings", "⚙️ Settings" }, { "grownups", "👪 For grown-ups" } } do
		local b = Ui.button(tabs, t[2], UDim2.fromOffset(190, 42), UDim2.new(), if tab == t[1] then C.gold else C.white, 17)
		b.Activated:Connect(function()
			tab = t[1]
			render()
		end)
	end
	if tab == "settings" then settingsTab() else grownUpsTab() end
end

local function open()
	panelGui.Enabled = true
	panel.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	render()
end
gear.Activated:Connect(function() if panelGui.Enabled then panelGui.Enabled = false else open() end end)
closeBtn.Activated:Connect(function() panelGui.Enabled = false end)
dim.Activated:Connect(function() panelGui.Enabled = false end)
PlayerState.Changed.Event:Connect(function() if panelGui.Enabled then render() end end)

-- Tour card -------------------------------------------------------------------------------
local tourCard = Ui.card(gui, UDim2.fromOffset(520, 70), UDim2.new(0.5, 0, 0, 96), C.cream)
tourCard.AnchorPoint = Vector2.new(0.5, 0)
tourCard.Visible = false
local tourScale = Instance.new("UIScale")
tourScale.Parent = tourCard
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	local v = workspace.CurrentCamera.ViewportSize
	tourScale.Scale = math.min(1, (v.X - 20) / 520)
end)
local tourText = Ui.text(tourCard, "", 18, { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -200, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
local tourGo = Ui.button(tourCard, "GO ▶", UDim2.fromOffset(84, 44), UDim2.new(1, -180, 0.5, -22), C.orange, 18)
local tourSkip = Ui.button(tourCard, "Skip", UDim2.fromOffset(80, 44), UDim2.new(1, -90, 0.5, -22), C.white, 16)
local currentStep = nil

local function goTo(go: string?)
	if go == "stable" then
		local i = player:GetAttribute("PlotIndex")
		if i then
			local x, z = WorldLayout.plotPoint(i, 40, 0)
			Guide.to(x, z)
		end
	elseif go == "raceBoard" then
		local p = WorldLayout.places.raceBoard
		Guide.to(p.x, p.z + 10)
		local picker = HudEvents:FindFirstChild("OpenRacePicker")
		if picker then picker:Fire() end
	end
end

local function renderTour()
	local d = PlayerState.data
	local step = nil
	if d and #d.horses > 0 then
		local flags = d.flags or {}
		local i = Tour.current(flags)
		step = i and Tour.STEPS[i]
	end
	currentStep = if step then table.find(Tour.STEPS, step) else nil
	tourCard.Visible = step ~= nil and not RaceState.active
	if step then
		local h = PlayerState.activeHorse()
		tourText.Text = "🧭 " .. Tour.text(step, h and h.name)
		tourGo.Visible = step.go ~= nil
	end
end
tourGo.Activated:Connect(function()
	local step = currentStep and Tour.STEPS[currentStep]
	if step then goTo(step.go) end
end)
tourSkip.Activated:Connect(function()
	gameRemotes:WaitForChild("TourSkip"):FireServer()
	tourCard.Visible = false
end)
PlayerState.watch(function() renderTour() end)
RunService.Heartbeat:Connect(function()
	-- While any race is on screen (riding or watching) the race map and board own the top.
	local busy = RaceState.active == true
	local showTour = currentStep ~= nil and not busy
	if tourCard.Visible ~= showTour then tourCard.Visible = showTour end
	if gear.Visible == busy then gear.Visible = not busy end
end)

-- Break reminder ---------------------------------------------------------------------
local sessionStart = os.clock()
local nextReminder = 60 * 60
RunService.Heartbeat:Connect(function()
	local d = PlayerState.data
	if not d or not d.settings or not d.settings.breakReminder then return end
	local elapsed = os.clock() - sessionStart
	if elapsed >= nextReminder then
		nextReminder = (math.floor(elapsed / 3600) + 1) * 3600 -- one note, even if it was just turned on
		Ui.toast("You've been riding for a while. Time for a stretch and a drink of water? 🌤️", "welcome_sun", "🌤️")
	end
end)
