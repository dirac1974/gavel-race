--!nonstrict
-- HorsesClient (D-037): your horses and the Market Corral.
--   My Horses (tap the horse card in the dock): every horse with its stats (and Potential
--   once the vet reveals it), Energy, bond and record, in a stall or the pasture. Ride this
--   one (make it active), move between stall and pasture, rename with word chips, and build
--   a new stall with Green Cash.
--   Market Corral: walk up to a horse in the corral to see its card (stats, 🌱 family line,
--   price) and bring it home. Never for Robux; buying never takes it from anyone else.
-- Clarity pass (D-064, stage 3): 🏇 marks the horse you ride (★ is only how you rode), text is
-- never under ui.panelMinText, buttons never under ui.panelButtonPx, and on a short screen the
-- panel gets shorter and its list scrolls instead of shrinking.
-- Careers (D-059, stage 7): each card has its career row (🎖️ badges, 🏆 Cups, Veteran / 👑
-- Legend); a Veteran's "👑 Legend" button (two taps) retires it to the Hall of Fame paddock; a
-- Legend's "🐴 Ride" brings it for a ride. Stalls are stored per horse: cards go stall order,
-- pasture, then Legends, and a pasture horse moves straight into a free stall. The Hall of Fame
-- page lists the plaques and the horses at Sunny Meadow Riding School with "↩️ Undo".
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NameGen = require(Shared:WaitForChild("NameGen"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Market = require(Shared:WaitForChild("Market"))
local PickerText = require(Shared:WaitForChild("PickerText")) -- class badges (D-062)
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors
local TEXT = GameConfig.ui.panelMinText -- the smallest text on these panels (16)
local TAP = GameConfig.ui.panelButtonPx  -- the smallest button on these panels (64)
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
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.new(), C.paper)
local slideIn = Ui.fitPanel(panel, W, H, 300) -- shorter on a short screen; the list scrolls (D-064)
local title = Ui.text(panel, "🐴 My Horses", 28, { Position = UDim2.new(0, 250, 0, 20), Size = UDim2.new(1, -500, 0, 36) })
local closeBtn = Ui.button(panel, "✕", UDim2.fromOffset(TAP, TAP), UDim2.new(1, -TAP - 10, 0, 6), C.white, 26)
local stallBtn = Ui.button(panel, "", UDim2.fromOffset(230, TAP), UDim2.new(0, 12, 0, 6), C.sky, 18)
local hallBtn = Ui.button(panel, "🏅 Hall of Fame", UDim2.fromOffset(170, TAP), UDim2.new(1, -TAP - 186, 0, 6), C.cream, 18)
local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.Size = UDim2.new(1, -32, 1, -TAP - 22)
list.Position = UDim2.new(0, 16, 0, TAP + 14)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 6
list.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -8, 0, 290)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = list

local moving: string? = nil -- a pasture horse picked to swap into a stall
local retiring: string? = nil -- asked once; a second tap retires
local renameState = nil       -- { id, first, second, picked } kept while renaming
local mode = "horses"       -- or "rename:<id>"

local function statBar(parent: Instance, y: number, key: string, value: number, cap: number?)
	Ui.text(parent, STAT_LABEL[key], TEXT, { Position = UDim2.new(0, 10, 0, y), Size = UDim2.new(0, 72, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -156, 0, 14)
	bar.Position = UDim2.new(0, 84, 0, y + 3)
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
	Ui.text(parent, if cap then string.format("%.0f/%d", value, cap) else string.format("%.0f", value), TEXT,
		{ Position = UDim2.new(1, -68, 0, y), Size = UDim2.new(0, 62, 0, 20), TextXAlignment = Enum.TextXAlignment.Right })
end

local render

local function horseCard(h, order: number)
	local d = PlayerState.data
	local active = h.id == d.activeHorse
	local card = Ui.card(list, UDim2.new(), UDim2.new(), if active then C.gold elseif h.legend then Color3.fromHex("FFF4C7")
		elseif h.stalled then C.cream else Color3.fromHex("E3F2D9"))
	card.LayoutOrder = order
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(40, 40)
	dot.Position = UDim2.new(0, 10, 0, 10)
	dot.BackgroundColor3 = Ui.coatColors[h.coat] or Ui.coatColors.bay
	Ui.corner(dot, 20)
	Ui.stroke(dot, 2)
	dot.Parent = card
	local name = Ui.text(card, (if active then "🏇 " else "") .. h.name, 20, { Position = UDim2.new(0, 58, 0, 6), Size = UDim2.new(1, -66, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	name.TextTruncate = Enum.TextTruncate.AtEnd
	-- the class badge (D-062): First Win, Rising Star, Open class, or the Cup when it's open
	local badge = if h.cupOpen then "🏆 Cup open!" else PickerText.classBadge(h.class)
	local leagueLine = (h.league or "Rookie") .. (if badge ~= "" then " · " .. badge else "")
	local place = if h.legend then "👑 Hall of Fame paddock" elseif h.stalled then "Stall " .. tostring(h.stall or "") else "Pasture"
	local sub = Ui.text(card, if h.legend then place else string.format("%s · %s", place, leagueLine), TEXT,
		{ Position = UDim2.new(0, 58, 0, 30), Size = UDim2.new(1, -66, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
	sub.TextColor3 = C.plum
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	for k, key in { "speed", "accel", "stamina", "grit" } do
		statBar(card, 56 + (k - 1) * 24, key, h.stats[key], h.potential and h.potential[key])
	end
	-- Energy as the one horseshoe row (D-064), then care (❤️ bond) and the record.
	local pips = Ui.energyPips(card, h.energy, GameConfig.energy.maxPerRacer, 18, UDim2.new(0, 10, 0, 155))
	Ui.text(card, string.format("❤️%d  🏁 %d · 🥇 %d", math.floor(h.bond), h.record.races, h.record.wins), TEXT,
		{ Position = UDim2.new(0, 16 + pips.Size.X.Offset, 0, 153), Size = UDim2.new(1, -26 - pips.Size.X.Offset, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	-- Career row (D-059): 🎖️ a badge every 25 races, 🏆 Cups, Veteran or 👑 Legend; races to the next badge.
	local career = h.career or {}
	local careerText = career.line or ""
	if not h.legend and career.toNextBadge then careerText ..= string.format(" · 🎖️ in %d races", career.toNextBadge) end
	local cl = Ui.text(card, careerText, TEXT, { Position = UDim2.new(0, 10, 0, 180), Size = UDim2.new(1, -20, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	cl.TextColor3 = C.plum
	cl.TextTruncate = Enum.TextTruncate.AtEnd
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -16, 0, TAP)
	row.Position = UDim2.new(0, 8, 1, -TAP - 10)
	row.Parent = card
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 6)
	rl.Parent = row
	local function btn(text: string, color: Color3, fn)
		local b = Ui.button(row, text, UDim2.fromOffset(80, TAP), UDim2.new(), color, TEXT)
		b.Activated:Connect(fn)
	end
	if h.legend then
		btn("🐴 Ride", C.orange, function()
			gameRemotes:WaitForChild("CallHorse"):FireServer(h.id) -- a Legend ride (D-059)
			gui.Enabled = false
		end)
	end
	if h.stalled and not active then
		btn("🏇 Ride", C.orange, function() gameRemotes:WaitForChild("SetActiveHorse"):FireServer(h.id) end)
	end
	local freeStall = false
	do
		local used = 0
		for _, x in d.horses do if x.stalled then used += 1 end end
		freeStall = used < d.stalls
	end
	if not h.stalled and not h.legend then
		btn(if moving == h.id then "Pick one ↓" else "🏠 Stall", C.sky, function()
			if freeStall then -- an empty stall: straight in (stalls stored per horse, D-059)
				gameRemotes:WaitForChild("SwapStall"):FireServer("", h.id)
				return
			end
			moving = if moving == h.id then nil else h.id
			render()
		end)
	elseif moving and h.stalled then
		btn("🔁 Swap", C.green, function()
			gameRemotes:WaitForChild("SwapStall"):FireServer(h.id, moving)
			moving = nil
		end)
	end
	btn("✏️ Name", C.white, function()
		mode = "rename:" .. h.id
		render()
	end)
	if career.canBeLegend and not h.legend then -- Legend Retirement (D-059): two taps, a Veteran only
		btn(if retiring == h.id then "Sure? 👑" else "👑 Legend", if retiring == h.id then C.red else C.gold, function()
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
	-- Horses at Sunny Meadow Riding School that can still come back (D-059): undo, no clock.
	for k, r in d.rehomed or {} do
		local c = Ui.card(list, UDim2.new(), UDim2.new(), C.sky)
		c.LayoutOrder = k
		local t = Ui.text(c, "🏫 " .. r.name .. " at Sunny Meadow", 20, { Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -24, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
		t.TextTruncate = Enum.TextTruncate.AtEnd
		Ui.text(c, string.format("%d %s to change your mind", r.daysLeft, if r.daysLeft == 1 then "day" else "days"), TEXT,
			{ Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 20), TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
		local undo = Ui.button(c, if r.cash > 0 then string.format("↩️ Undo · 💵 %d", r.cash) else "↩️ Undo", UDim2.fromOffset(200, TAP), UDim2.new(0, 12, 1, -TAP - 6), C.white, 18)
		undo.Activated:Connect(function() gameRemotes:WaitForChild("UndoRehome"):FireServer(r.id) end)
	end
	if (d.goodbyeRosettes or 0) > 0 then
		local c = Ui.card(list, UDim2.new(), UDim2.new(), C.cream)
		c.LayoutOrder = 50
		Ui.text(c, string.format("🏵️ %d goodbye %s", d.goodbyeRosettes, if d.goodbyeRosettes == 1 then "rosette" else "rosettes"), 22,
			{ Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(1, -24, 0, 28), TextXAlignment = Enum.TextXAlignment.Left })
		Ui.text(c, "From horses you shared with the riding school", TEXT,
			{ Position = UDim2.new(0, 12, 0, 48), Size = UDim2.new(1, -24, 0, 44), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }).TextColor3 = C.plum
	end
	if #plaques == 0 then
		local empty = Ui.card(list, UDim2.new(), UDim2.new(), C.cream)
		empty.LayoutOrder = 100
		Ui.text(empty, string.format("No Legends yet. A horse with %d races can become one!", GameConfig.career.veteranAt), 18,
			{ Position = UDim2.new(0, 12, 0, 20), Size = UDim2.new(1, -24, 0, 80), TextWrapped = true })
	end
	for k, pl in plaques do
		local c = Ui.card(list, UDim2.new(), UDim2.new(), C.cream)
		c.LayoutOrder = 100 + k
		Ui.text(c, (if pl.legend then "👑 " else "🏅 ") .. pl.name, 22, { Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(1, -24, 0, 28), TextXAlignment = Enum.TextXAlignment.Left })
		Ui.text(c, string.format("%s · %s", (pl.coat:gsub("_", " ")), pl.league), TEXT, { Position = UDim2.new(0, 12, 0, 44), Size = UDim2.new(1, -24, 0, 20), TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
		Ui.text(c, string.format("🏁 %d races · 🥇 %d wins · 🏅 %d top three · 💵 %d", pl.races, pl.wins, pl.places, pl.cash), TEXT,
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
	box.Size = UDim2.new(1, 0, 0, 52 + 3 * (TAP + 8))
	box.LayoutOrder = 1
	box.Parent = list
	local preview = Ui.text(box, NameGen.build(picked[1], picked[2]) or h.name, 36, { Size = UDim2.new(1, 0, 0, 44) })
	preview.TextColor3 = C.orangeDark
	for r, words in { first, second } do
		local rowF = Instance.new("Frame")
		rowF.BackgroundTransparency = 1
		rowF.Size = UDim2.new(1, 0, 0, TAP)
		rowF.Position = UDim2.new(0, 0, 0, 52 + (r - 1) * (TAP + 8))
		rowF.Parent = box
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		l.Padding = UDim.new(0, 6)
		l.Parent = rowF
		for _, w in words do
			local b = Ui.button(rowF, w, UDim2.fromOffset(104, TAP), UDim2.new(), C.white, 18)
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
	local save = Ui.button(box, "Save name", UDim2.fromOffset(200, TAP), UDim2.new(0.5, -210, 0, 52 + 2 * (TAP + 8)), C.green, 22)
	local back = Ui.button(box, "Back", UDim2.fromOffset(200, TAP), UDim2.new(0.5, 10, 0, 52 + 2 * (TAP + 8)), C.white, 22)
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
		grid.CellSize = UDim2.new(0.5, -8, 0, 140)
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
	grid.CellSize = UDim2.new(0.5, -8, 0, 290)
	title.Text = string.format("🐴 My Horses (%d)", #d.horses)
	local price = d.market and d.market.nextStallPrice
	stallBtn.Visible = true
	stallBtn.Text = if price then string.format("🔨 Build a stall · 💵 %d", price) else string.format("🏠 %d stalls (full barn)", d.stalls)
	-- stall order, then the pasture, then Legends (D-059)
	for i, h in d.horses do
		local order = if h.legend then 200 + i elseif h.stalled then (h.stall or 0) else 100 + i
		horseCard(h, order)
	end
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
	slideIn()
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

-- Legends in your Hall of Fame paddock (D-059): a Ride prompt on your own Legends.
local function attachLegend(m: Instance)
	if not m:IsA("Model") or not m:GetAttribute("LegendId") or m:GetAttribute("Owner") ~= Players.LocalPlayer.UserId then return end
	local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not anchor or anchor:FindFirstChild("LegendPrompt") then return end
	local p = Instance.new("ProximityPrompt")
	p.Name = "LegendPrompt"
	p.ActionText = "Ride"
	p.ObjectText = "👑 " .. tostring(m:GetAttribute("HorseName") or "Legend")
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Parent = anchor
	p.Triggered:Connect(function() gameRemotes:WaitForChild("CallHorse"):FireServer(m:GetAttribute("LegendId")) end)
end

-- Reduced Motion: no sparkle on Legends (the soft gold sheen stays).
local function calm(): boolean
	local ok, on = pcall(function() return game:GetService("GuiService").ReducedMotionEnabled end)
	return ok and on == true
end
local function onPaddockPart(d: Instance)
	if d:IsA("Model") then task.defer(attachLegend, d) end
	if d:IsA("ParticleEmitter") and d.Name == "LegendSparkle" and calm() then d.Enabled = false end
end
task.spawn(function()
	local plots = workspace:WaitForChild("World", 60)
	plots = plots and plots:WaitForChild("Plots", 60)
	if not plots then return end
	for _, d in plots:GetDescendants() do onPaddockPart(d) end
	plots.DescendantAdded:Connect(onPaddockPart)
end)

-- Market Corral --------------------------------------------------------------------------
local mgui = Ui.screen("MarketCard", 11)
mgui.Enabled = false
local mcard = Ui.card(mgui, UDim2.fromOffset(420, 350), UDim2.new(), C.paper)
local marketSlide = Ui.fitPanel(mcard, 420, 350)
local mbody = Instance.new("Frame")
mbody.BackgroundTransparency = 1
mbody.Size = UDim2.fromScale(1, 1)
mbody.Parent = mcard
local mclose = Ui.button(mcard, "✕", UDim2.fromOffset(TAP, TAP), UDim2.new(1, -TAP - 8, 0, 6), C.white, 26)
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
	-- 🌱 = a good family line (D-064; ★ is only how you rode).
	Ui.text(mbody, string.format("%s · %s", (l.coat:gsub("_", " ")), Market.familyLine(l.stars)), TEXT,
		{ Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(1, 0, 0, 22) }).TextColor3 = C.plum
	for k, key in { "speed", "accel", "stamina", "grit" } do statBar(mbody, 82 + (k - 1) * 24, key, l.stats[key], nil) end
	Ui.text(mbody, "More 🌱 = more room to grow", TEXT, { Position = UDim2.new(0, 0, 0, 182), Size = UDim2.new(1, 0, 0, 22) }).TextColor3 = C.plum
	local buy = Ui.button(mbody, if l.bought then "Lives with you ✓" else string.format("Bring home · 💵 %d", l.price), UDim2.fromOffset(280, TAP),
		UDim2.new(0.5, -140, 1, -TAP - 16), if l.bought then C.shade else C.orange, 22)
	buy.Activated:Connect(function()
		if l.bought then return end
		gameRemotes:WaitForChild("MarketBuy"):FireServer(l.id)
		mgui.Enabled = false
	end)
	if not mgui.Enabled then
		mgui.Enabled = true
		marketSlide()
	end
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
