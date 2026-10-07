--!nonstrict
-- StyleShop (D-050): the Tack & Paint shop. Opens only when you tap: the 💎 button in the dock
-- or the shop's counter on Fair Street. Never pops up by itself, no timers, no "limited", no
-- "best value". Tapping a card never buys: Buy asks first ("Use 75 Diamonds? You'll have 25
-- left."), and a look bought by mistake can be returned within a day for every Diamond.
-- Diamond packs: 1 Diamond = 1 Robux; Roblox's own window confirms any Robux, and the server
-- only shows it at a calm moment (not around your races) and within the spending caps.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("Style"))
local DiamondProducts = require(Shared:WaitForChild("DiamondProducts"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors
local player = Players.LocalPlayer

local gui = Ui.screen("StyleShop", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local W, H = 780, 520
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = Instance.new("UIScale")
scale.Parent = panel
local compact = false
local render -- defined below; a screen-size change redraws
local function layout()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local v = cam.ViewportSize
	-- Phones: fill the screen at full size with one column (big, tappable), rather than
	-- shrinking the desktop layout.
	compact = v.Y < 600 or v.X < 820
	if compact then
		scale.Scale = 1
		panel.Size = UDim2.fromOffset(math.min(W, v.X - 16), v.Y - 16)
	else
		panel.Size = UDim2.fromOffset(W, H)
		scale.Scale = math.min(1, (v.X - 20) / W, (v.Y - 20) / H)
	end
end
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		layout()
		if render then render() end
	end)
end)
Ui.text(panel, "🎨 Tack & Paint", 30, { Position = UDim2.new(0, 0, 0, 10), Size = UDim2.new(1, 0, 0, 36) })
local balance = Ui.text(panel, "", 22, { Position = UDim2.new(0, 18, 0, 14), Size = UDim2.new(0, 200, 0, 28), TextXAlignment = Enum.TextXAlignment.Left })
balance.TextColor3 = Color3.fromHex("2E5AAC")
local closeBtn = Ui.button(panel, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 8), C.white, 22)
local tabs = Instance.new("ScrollingFrame")
tabs.BackgroundTransparency = 1
tabs.Size = UDim2.new(1, -32, 0, 46)
tabs.Position = UDim2.new(0, 16, 0, 54)
tabs.ScrollingDirection = Enum.ScrollingDirection.X
tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
tabs.CanvasSize = UDim2.new()
tabs.ScrollBarThickness = 4
tabs.Parent = panel
local tl = Instance.new("UIListLayout")
tl.FillDirection = Enum.FillDirection.Horizontal
tl.Padding = UDim.new(0, 6)
tl.Parent = tabs
local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.Size = UDim2.new(1, -32, 1, -112)
list.Position = UDim2.new(0, 16, 0, 102)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 6
list.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -8, 0, 132)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = list

local tab = "tack"
local confirming: string? = nil

local function diamonds(): number
	return (PlayerState.data and PlayerState.data.diamonds) or 0
end

local function worn(id: string, slot: string): boolean
	local eq = PlayerState.data and PlayerState.data.style and PlayerState.data.style.equipped or {}
	if slot == "yard" then return eq["yard:" .. id] == true end
	local cur = eq[slot]
	if cur then return cur == id end
	local it = Style.item(id)
	return it ~= nil and Style.isStarter(it)
end

local function owns(id: string): boolean
	local d = PlayerState.data
	if not d then return false end
	return Style.owns({ style = d.style, diamonds = d.diamonds, fan = { xp = (d.fanXp or 0) } }, id)
end

-- Monthly stamp cloths (D-063): the ones you earned, and this month's as a goal. Other months
-- stay out of the shop until earned (each comes back in its own month next year).
local function shown(it): boolean
	if not it.month then return true end
	if owns(it.id) then return true end
	local jobs = PlayerState.data and PlayerState.data.jobs
	return jobs ~= nil and jobs.monthCloth == it.id
end

local function stampLine(): string
	local jobs = PlayerState.data and PlayerState.data.jobs
	local have = (jobs and jobs.monthStamps) or 0
	local need = (jobs and jobs.stampsNeeded) or 8
	return string.format("🎀 %d of %d stamps. Do monthly jobs!", math.min(have, need), need)
end

local function canReturn(id: string): boolean
	local d = PlayerState.data
	local at = d and d.shop and d.shop.boughtAt and d.shop.boughtAt[id]
	return at ~= nil and workspace:GetServerTimeNow() - at < Style.RETURN_SECONDS
end

local function itemCard(it, order: number)
	local own = owns(it.id)
	local on = own and worn(it.id, it.slot)
	local card = Ui.card(list, UDim2.new(), UDim2.new(), if on then C.gold elseif own then C.cream else C.white)
	card.LayoutOrder = order
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(64, 64)
	swatch.Position = UDim2.new(0, 12, 0, 12)
	swatch.BackgroundColor3 = if it.color then Color3.fromHex(it.color) else C.cream
	Ui.corner(swatch, 14)
	Ui.stroke(swatch, 2)
	swatch.Parent = card
	Ui.text(swatch, it.emoji, 30, { Size = UDim2.fromScale(1, 1), TextScaled = true })
	if it.color2 then -- paint shows walls, roof and trim
		local roof = Instance.new("Frame")
		roof.Size = UDim2.new(1, 0, 0.3, 0)
		roof.BackgroundColor3 = Color3.fromHex(it.color2)
		Ui.corner(roof, 14)
		roof.Parent = swatch
	end
	Ui.text(card, it.name, 19, { Position = UDim2.new(0, 86, 0, 10), Size = UDim2.new(1, -94, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	local sub = if it.fanLevel then string.format("Earned at Fan level %d (cheer in races!)", it.fanLevel)
		elseif it.month and own then "🎀 Earned!"
		elseif it.month then stampLine()
		elseif it.price == 0 then "Free"
		elseif own then "Yours"
		else string.format("💎 %d", it.price)
	local subL = Ui.text(card, sub, 16, { Position = UDim2.new(0, 86, 0, 36), Size = UDim2.new(1, -94, 0, 36), TextXAlignment = Enum.TextXAlignment.Left })
	subL.TextColor3 = if own then C.green else C.plum
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -20, 0, 40)
	row.Position = UDim2.new(0, 10, 1, -48)
	row.Parent = card
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 6)
	rl.Parent = row
	local function btn(text: string, color: Color3, fn)
		local b = Ui.button(row, text, UDim2.fromOffset(124, 44), UDim2.new(), color, 16)
		b.Activated:Connect(fn)
	end
	if own then
		if on then
			if it.price > 0 or it.slot == "yard" or it.month then
				btn(if it.slot == "yard" then "Put away" else "Take off", C.white, function()
					gameRemotes:WaitForChild("StyleWear"):FireServer(it.id, false)
				end)
			else
				btn("Wearing ✓", C.gold, function() end)
			end
		else
			btn(if it.slot == "yard" then "Place it" else "Wear", C.sky, function()
				gameRemotes:WaitForChild("StyleWear"):FireServer(it.id, true)
			end)
		end
		if canReturn(it.id) then
			btn("Return (+" .. it.price .. "💎)", C.cream, function()
				gameRemotes:WaitForChild("StyleReturn"):FireServer(it.id)
			end)
		end
	elseif Style.forSale(it) then
		if confirming == it.id then
			local left = diamonds() - it.price
			if left >= 0 then
				btn("Yes, buy", C.green, function()
					confirming = nil
					gameRemotes:WaitForChild("StyleBuy"):FireServer(it.id)
					render()
				end)
				btn("No", C.white, function()
					confirming = nil
					render()
				end)
				subL.Text = string.format("Use %d 💎? You'll have %d left.", it.price, left)
			else
				subL.Text = string.format("You need %d more 💎", -left)
				btn("OK", C.white, function()
					confirming = nil
					render()
				end)
			end
		else
			btn("Buy", C.orange, function()
				confirming = it.id
				render()
			end)
		end
	end
end

local function diamondsTab()
	local d = PlayerState.data
	local shop = d and d.shop
	local info = Ui.card(list, UDim2.new(), UDim2.new(), C.cream)
	info.LayoutOrder = 0
	Ui.text(info, "💎 Diamonds buy looks only. 1 Diamond = 1 Robux.", 17, { Position = UDim2.new(0, 12, 0, 10), Size = UDim2.new(1, -24, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	Ui.text(info, "They never buy speed, horses, Green Cash or wins. Free Diamonds come from moving up a league, finishing every monthly job and new Fan levels.", 14,
		{ Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 60), TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
	for k, pack in (shop and shop.packs) or {} do
		local card = Ui.card(list, UDim2.new(), UDim2.new(), C.white)
		card.LayoutOrder = k
		Ui.text(card, "💎 " .. pack.diamonds, 30, { Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 36) })
		local b = Ui.button(card, if pack.ready then string.format("R$ %d", pack.robux) else "Coming soon", UDim2.fromOffset(170, 44),
			UDim2.new(0.5, -85, 1, -56), if pack.ready then C.gold else C.shade, 18)
		b.Activated:Connect(function()
			if pack.ready then gameRemotes:WaitForChild("BuyDiamonds"):FireServer(pack.index) end
		end)
	end
end

render = function()
	if not gui.Enabled then return end
	balance.Text = "💎 " .. diamonds()
	for _, ch in tabs:GetChildren() do if ch:IsA("TextButton") then ch:Destroy() end end
	for _, ch in list:GetChildren() do if not ch:IsA("UIGridLayout") then ch:Destroy() end end
	grid.CellSize = if compact then UDim2.new(1, -8, 0, 132) else UDim2.new(0.5, -8, 0, 132)
	for _, cat in Style.CATEGORIES do
		local b = Ui.button(tabs, cat.label, UDim2.fromOffset(112, 44), UDim2.new(), if tab == cat.id then C.gold else C.white, 15)
		b.Activated:Connect(function()
			tab, confirming = cat.id, nil
			render()
		end)
	end
	local db = Ui.button(tabs, "💎 Diamonds", UDim2.fromOffset(112, 44), UDim2.new(), if tab == "diamonds" then C.gold else C.sky, 15)
	db.Activated:Connect(function()
		tab, confirming = "diamonds", nil
		render()
	end)
	if tab == "diamonds" then return diamondsTab() end
	local slots = {}
	for _, cat in Style.CATEGORIES do
		if cat.id == tab then for _, s in cat.slots do slots[s] = true end end
	end
	local order = 0
	for _, it in Style.ITEMS do
		if slots[it.slot] and shown(it) then
			order += 1
			itemCard(it, order)
		end
	end
end

local function open()
	if not PlayerState.data then return end
	gui.Enabled = true
	confirming = nil
	panel.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	render()
end
local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
PlayerState.Changed.Event:Connect(function() render() end)

local ev = HudEvents:FindFirstChild("OpenStyleShop")
if not ev then
	ev = Instance.new("BindableEvent")
	ev.Name = "OpenStyleShop"
	ev.Parent = HudEvents
end
ev.Event:Connect(function()
	if gui.Enabled then
		close()
	elseif not RaceState.shopClosed(DiamondProducts.afterRaceSeconds) then
		open()
	end
end)

-- Your race starting closes the shop.
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if player:GetAttribute("Racing") and gui.Enabled then close() end
end)

-- The counter in the Tack & Paint shop on Fair Street.
do
	local p = WorldLayout.places.tackShop
	local anchor = Instance.new("Part")
	anchor.Name = "TackCounter"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.new(4, 4, 4)
	anchor.CFrame = CFrame.new(p.x, 2, p.z - 6)
	anchor.Parent = workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Browse", "Tack & Paint"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(open)
	-- The counter's door shuts around races and training rides too (D-056).
	task.spawn(function()
		while true do
			local shut = RaceState.shopClosed(DiamondProducts.afterRaceSeconds)
			if prompt.Enabled == shut then prompt.Enabled = not shut end
			task.wait(0.5)
		end
	end)
end
