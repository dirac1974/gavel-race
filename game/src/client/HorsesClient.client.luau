--!nonstrict
-- HorsesClient (D-037): your horses and the Market Corral.
--   My Horses (tap the horse card in the dock): every horse with its stats (and Potential
--   once the vet reveals it), Energy, bond and record, in a stall or the pasture. Ride this
--   one (make it active), move between stall and pasture, rename with word chips, and build
--   a new stall with Green Cash.
--   Market Corral: walk up to a horse in the corral to see its card (stats, ★ bloodline,
--   price) and bring it home. Never for Robux; buying never takes it from anyone else.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NameGen = require(Shared:WaitForChild("NameGen"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors
local STAT_LABEL = { speed = "Speed", accel = "Accel", stamina = "Stamina", grit = "Grit" }
local STYLE_LABEL = { FrontRunner = "Front-runner", Stalker = "Stalker", Closer = "Closer" }

local gui = Ui.screen("MyHorses", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local W, H = 760, 500
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
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
local title = Ui.text(panel, "🐴 My Horses", 30, { Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 36) })
local closeBtn = Ui.button(panel, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 10), C.white, 22)
local stallBtn = Ui.button(panel, "", UDim2.fromOffset(220, 40), UDim2.new(0, 16, 0, 14), C.sky, 17)
local hallBtn = Ui.button(panel, "🏅 Hall of Fame", UDim2.fromOffset(170, 40), UDim2.new(1, -236, 0, 14), C.cream, 16)
local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.Size = UDim2.new(1, -32, 1, -76)
list.Position = UDim2.new(0, 16, 0, 62)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 6
list.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -8, 0, 210)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = list

local moving: string? = nil -- a pasture horse picked to swap into a stall
local retiring: string? = nil -- asked once; a second tap retires
local renameState = nil       -- { id, first, second, picked } kept while renaming
local mode = "horses"       -- or "rename:<id>"

local function statBar(parent: Instance, y: number, key: string, value: number, cap: number?)
	Ui.text(parent, STAT_LABEL[key], 14, { Position = UDim2.new(0, 10, 0, y), Size = UDim2.new(0, 64, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -140, 0, 12)
	bar.Position = UDim2.new(0, 76, 0, y + 2)
	bar.BackgroundColor3 = C.white
	Ui.corner(bar, 6)
	Ui.stroke(bar, 1.5)
	bar.Parent = parent
	if cap then
		local capFill = Instance.new("Frame")
		capFill.Size = UDim2.fromScale(math.clamp(cap / 100, 0, 1), 1)
		capFill.BackgroundColor3 = C.cream
		Ui.corner(capFill, 6)
		capFill.Parent = bar
	end
	local fillF = Instance.new("Frame")
	fillF.Size = UDim2.fromScale(math.clamp(value / 100, 0.02, 1), 1)
	fillF.BackgroundColor3 = C.teal
	Ui.corner(fillF, 6)
	fillF.Parent = bar
	Ui.text(parent, if cap then string.format("%.0f/%d", value, cap) else string.format("%.0f", value), 13,
		{ Position = UDim2.new(1, -60, 0, y), Size = UDim2.new(0, 54, 0, 16), TextXAlignment = Enum.TextXAlignment.Right })
end

local render

local function horseCard(h, order: number)
	local d = PlayerState.data
	local active = h.id == d.activeHorse
	local card = Ui.card(list, UDim2.new(), UDim2.new(), if active then C.gold elseif h.stalled then C.cream else Color3.fromHex("E3F2D9"))
	card.LayoutOrder = order
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(40, 40)
	dot.Position = UDim2.new(0, 10, 0, 10)
	dot.BackgroundColor3 = Ui.coatColors[h.coat] or Ui.coatColors.bay
	Ui.corner(dot, 20)
	Ui.stroke(dot, 2)
	dot.Parent = card
	local name = Ui.text(card, (if active then "⭐ " else "") .. h.name, 20, { Position = UDim2.new(0, 58, 0, 6), Size = UDim2.new(1, -66, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local leagueLine = (h.league or "Rookie") .. (if h.cupOpen then " · 🏆 Cup open!" elseif h.pointsToCup then string.format(" · %d pts to the Cup", h.pointsToCup) else "")
	Ui.text(card, string.format("%s · %s · %s", if h.stalled then "Stall" else "Pasture", STYLE_LABEL[h.style] or "", leagueLine), 13,
		{ Position = UDim2.new(0, 58, 0, 30), Size = UDim2.new(1, -66, 0, 16), TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
	for k, key in { "speed", "accel", "stamina", "grit" } do
		statBar(card, 54 + (k - 1) * 20, key, h.stats[key], h.potential and h.potential[key])
	end
	Ui.text(card, string.format("⚡%d  ❤️%d  🏁 %d races · %d wins", h.energy, math.floor(h.bond), h.record.races, h.record.wins), 14,
		{ Position = UDim2.new(0, 10, 0, 136), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -16, 0, 40)
	row.Position = UDim2.new(0, 8, 1, -48)
	row.Parent = card
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 6)
	rl.Parent = row
	local function btn(text: string, color: Color3, fn)
		local b = Ui.button(row, text, UDim2.fromOffset(82, 38), UDim2.new(), color, 13)
		b.Activated:Connect(fn)
	end
	if h.stalled and not active then
		btn("⭐ Ride this one", C.orange, function() gameRemotes:WaitForChild("SetActiveHorse"):FireServer(h.id) end)
	end
	if not h.stalled then
		btn(if moving == h.id then "Pick a stall ↓" else "Move to stall", C.sky, function()
			moving = if moving == h.id then nil else h.id
			render()
		end)
	elseif moving then
		btn("Swap here", C.green, function()
			gameRemotes:WaitForChild("SwapStall"):FireServer(h.id, moving)
			moving = nil
		end)
	end
	btn("✏️ Rename", C.white, function()
		mode = "rename:" .. h.id
		render()
	end)
	if #d.horses > 1 then
		btn(if retiring == h.id then "Sure? Retire" else "🏅 Retire", if retiring == h.id then C.red else C.cream, function()
			if retiring == h.id then
				gameRemotes:WaitForChild("RetireHorse"):FireServer(h.id)
				retiring = nil
			else
				retiring = h.id
				render()
			end
		end)
	end
end

local function hallView()
	local d = PlayerState.data
	title.Text = "🏅 Hall of Fame"
	local plaques = d.hallOfFame or {}
	if #plaques == 0 then
		local empty = Ui.card(list, UDim2.new(), UDim2.new(), C.cream)
		Ui.text(empty, "No legends yet. Retire a horse when you choose, and its record lives here.", 18,
			{ Position = UDim2.new(0, 12, 0, 40), Size = UDim2.new(1, -24, 0, 80) })
	end
	for k, pl in plaques do
		local c = Ui.card(list, UDim2.new(), UDim2.new(), C.cream)
		c.LayoutOrder = k
		Ui.text(c, "🏅 " .. pl.name, 22, { Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(1, -24, 0, 28), TextXAlignment = Enum.TextXAlignment.Left })
		Ui.text(c, string.format("%s · %s", pl.coat:gsub("_", " "), pl.league), 15, { Position = UDim2.new(0, 12, 0, 44), Size = UDim2.new(1, -24, 0, 20), TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
		Ui.text(c, string.format("🏁 %d races · 🥇 %d wins · 🎀 %d top three · 💵 %d", pl.races, pl.wins, pl.places, pl.cash), 16,
			{ Position = UDim2.new(0, 12, 0, 74), Size = UDim2.new(1, -24, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	end
end

local function renameView(id: string)
	local h = PlayerState.horse(id)
	if not h then
		mode = "horses"
		return render()
	end
	title.Text = "Rename " .. h.name
	if not renameState or renameState.id ~= id then
		local f, s2 = NameGen.offer(Random.new(), 6)
		renameState = { id = id, first = f, second = s2, picked = { nil, nil } }
	end
	local first, second, picked = renameState.first, renameState.second, renameState.picked
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.new(1, 0, 0, 300)
	box.LayoutOrder = 1
	box.Parent = list
	local preview = Ui.text(box, NameGen.build(picked[1], picked[2]) or h.name, 36, { Size = UDim2.new(1, 0, 0, 44) })
	preview.TextColor3 = C.orangeDark
	for r, words in { first, second } do
		local rowF = Instance.new("Frame")
		rowF.BackgroundTransparency = 1
		rowF.Size = UDim2.new(1, 0, 0, 50)
		rowF.Position = UDim2.new(0, 0, 0, 54 + (r - 1) * 58)
		rowF.Parent = box
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		l.Padding = UDim.new(0, 6)
		l.Parent = rowF
		for _, w in words do
			local b = Ui.button(rowF, w, UDim2.fromOffset(104, 44), UDim2.new(), C.white, 18)
			b.Activated:Connect(function()
				picked[r] = if picked[r] == w then nil else w
				for _, o in rowF:GetChildren() do
					if o:IsA("TextButton") then o.BackgroundColor3 = if o.Text == picked[r] then C.gold else C.white end
				end
				preview.Text = NameGen.build(picked[1], picked[2]) or h.name
			end)
			b.BackgroundColor3 = if picked[r] == w then C.gold else C.white
		end
	end
	local save = Ui.button(box, "Save name", UDim2.fromOffset(200, 50), UDim2.new(0.5, -210, 0, 186), C.green, 22)
	local back = Ui.button(box, "Back", UDim2.fromOffset(200, 50), UDim2.new(0.5, 10, 0, 186), C.white, 22)
	save.Activated:Connect(function()
		if NameGen.build(picked[1], picked[2]) then
			gameRemotes:WaitForChild("RenameHorse"):FireServer(id, picked[1], picked[2])
			mode, renameState = "horses", nil
		end
	end)
	back.Activated:Connect(function()
		mode, renameState = "horses", nil
		render()
	end)
end

render = function()
	if not gui.Enabled then return end
	for _, ch in list:GetChildren() do if not ch:IsA("UIGridLayout") then ch:Destroy() end end
	local d = PlayerState.data
	if not d then return end
	if mode == "hall" then
		grid.CellSize = UDim2.new(0.5, -8, 0, 120)
		stallBtn.Visible = false
		hallBtn.Text = "◀ My Horses"
		return hallView()
	end
	hallBtn.Text = "🏅 Hall of Fame"
	if string.sub(mode, 1, 7) == "rename:" then
		grid.CellSize = UDim2.new(1, 0, 0, 300)
		stallBtn.Visible = false
		return renameView(string.sub(mode, 8))
	end
	grid.CellSize = UDim2.new(0.5, -8, 0, 210)
	title.Text = string.format("🐴 My Horses (%d)", #d.horses)
	local price = d.market and d.market.nextStallPrice
	stallBtn.Visible = true
	stallBtn.Text = if price then string.format("🔨 Build a stall · 💵 %d", price) else string.format("🏠 %d stalls (full barn)", d.stalls)
	for i, h in d.horses do horseCard(h, i) end
end

hallBtn.Activated:Connect(function()
	mode = if mode == "hall" then "horses" else "hall"
	render()
end)

stallBtn.Activated:Connect(function()
	local d = PlayerState.data
	if d and d.market and d.market.nextStallPrice then gameRemotes:WaitForChild("BuyStall"):FireServer() end
end)

local function open()
	if not PlayerState.data or #PlayerState.data.horses == 0 then return end
	mode, moving, retiring, renameState = "horses", nil, nil, nil
	gui.Enabled = true
	panel.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	render()
end
local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
PlayerState.Changed.Event:Connect(function() render() end)

local ev = HudEvents:FindFirstChild("OpenHorses")
if not ev then
	ev = Instance.new("BindableEvent")
	ev.Name = "OpenHorses"
	ev.Parent = HudEvents
end
ev.Event:Connect(function() if gui.Enabled then close() else open() end end)

-- Market Corral --------------------------------------------------------------------------
local mgui = Ui.screen("MarketCard", 11)
mgui.Enabled = false
local mcard = Ui.card(mgui, UDim2.fromOffset(420, 330), UDim2.fromScale(0.5, 0.5), C.paper)
mcard.AnchorPoint = Vector2.new(0.5, 0.5)
local mscale = Instance.new("UIScale")
mscale.Parent = mcard
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	local v = workspace.CurrentCamera.ViewportSize
	mscale.Scale = math.min(1, (v.X - 20) / 420, (v.Y - 20) / 330)
end)
local mbody = Instance.new("Frame")
mbody.BackgroundTransparency = 1
mbody.Size = UDim2.fromScale(1, 1)
mbody.Parent = mcard
local mclose = Ui.button(mcard, "✕", UDim2.fromOffset(40, 40), UDim2.new(1, -50, 0, 10), C.white, 20)
mclose.Activated:Connect(function() mgui.Enabled = false end)

local function listingCard(id: string)
	local d = PlayerState.data
	local l = nil
	for _, x in (d and d.market and d.market.listings) or {} do
		if x.id == id then l = x end
	end
	if not l then return end
	mbody:ClearAllChildren()
	Ui.text(mbody, l.name, 28, { Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 32) })
	Ui.text(mbody, string.format("%s · %s · Bloodline %s", l.coat:gsub("_", " "), STYLE_LABEL[l.style] or "", string.rep("★", l.stars) .. string.rep("☆", 3 - l.stars)), 16,
		{ Position = UDim2.new(0, 0, 0, 48), Size = UDim2.new(1, 0, 0, 20) }).TextColor3 = C.plum
	for k, key in { "speed", "accel", "stamina", "grit" } do statBar(mbody, 80 + (k - 1) * 22, key, l.stats[key], nil) end
	Ui.text(mbody, "More ★ = more room to grow with training", 14, { Position = UDim2.new(0, 0, 0, 172), Size = UDim2.new(1, 0, 0, 18) }).TextColor3 = C.plum
	local buy = Ui.button(mbody, if l.bought then "Lives with you ✓" else string.format("Bring home · 💵 %d", l.price), UDim2.fromOffset(280, 58),
		UDim2.new(0.5, -140, 1, -78), if l.bought then C.shade else C.orange, 22)
	buy.Activated:Connect(function()
		if l.bought then return end
		gameRemotes:WaitForChild("MarketBuy"):FireServer(l.id)
		mgui.Enabled = false
	end)
	mgui.Enabled = true
end

local function attachListing(m: Instance)
	local id = m:GetAttribute("ListingId")
	if not id then return end
	local anchor = if m:IsA("BasePart") then m else (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true))
	if not anchor or anchor:FindFirstChild("ListingPrompt") then return end
	local p = Instance.new("ProximityPrompt")
	p.Name = "ListingPrompt"
	p.ActionText = "Look"
	p.ObjectText = "For sale"
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p.Parent = anchor
	p.Triggered:Connect(function() listingCard(id) end)
end

task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	if not world then return end
	local function watch(folder: Instance)
		for _, m in folder:GetChildren() do attachListing(m) end
		folder.ChildAdded:Connect(function(m) task.defer(attachListing, m) end)
	end
	local f = world:FindFirstChild("MarketHorses")
	if f then watch(f) end
	world.ChildAdded:Connect(function(ch)
		if ch.Name == "MarketHorses" then watch(ch) end
	end)
end)
