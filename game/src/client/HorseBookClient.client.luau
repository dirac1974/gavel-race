--!nonstrict
-- HorseBookClient (D-063, stage 6): the Horse Book, a collection of everything you've found.
--   📖 Book in the dock (in ☰ More on a phone) opens it. Pages: Coats, Rosettes, Courses, Cups,
--   Passport, Tour (friends' barns, D-060), Bests (your best ride at each distance, private) and
--   Cloths (the monthly stamp cloths). Each thing is a grey "?" card until earned.
--   Phones first (D-064): tabs and buttons 56 px or more, text 14-16 px or more, icon + one short
--   word on every tab. No ranks, no timers, nothing to buy.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local C = Ui.colors
local player = Players.LocalPlayer

if (GameConfig.comeback or {}).horseBook == false then return end

local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local openEvent = HudEvents:FindFirstChild("OpenHorseBook")
if not openEvent then
	openEvent = Instance.new("BindableEvent")
	openEvent.Name = "OpenHorseBook"
	openEvent.Parent = HudEvents
end

local MIN_TOUCH = math.max(56, (GameConfig.ui and GameConfig.ui.minTouchPx) or 56)
local TEXT = math.max(16, (GameConfig.ui and GameConfig.ui.labelPx) or 16)
local SMALL = math.max(14, (GameConfig.ui and GameConfig.ui.minTextPx) or 14)

-- The 📖 Book button in the dock (Hud moves it into ☰ More on a phone).
do
	local dock = player:WaitForChild("PlayerGui"):WaitForChild("Hud"):WaitForChild("Dock")
	local slot = Instance.new("Frame")
	slot.Name = "BookSlot"
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.new(0, 90, 1, 0)
	slot.LayoutOrder = 4
	slot.Parent = dock
	local b = Ui.button(slot, "", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.cream, TEXT)
	Ui.text(b, "📖", 30, { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 4), TextScaled = false })
	Ui.text(b, "Book", TEXT, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -28), TextWrapped = false })
	b.Activated:Connect(function() openEvent:Fire() end)
end

-- The book ---------------------------------------------------------------------------
local gui = Ui.screen("HorseBook", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local W, H = 800, 560
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
local title = Ui.text(panel, "📖 Horse Book", 28, { Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -100, 0, 36),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
local closeBtn = Ui.button(panel, "✕", UDim2.fromOffset(MIN_TOUCH, MIN_TOUCH), UDim2.new(1, -MIN_TOUCH - 8, 0, 6), C.white, 24)

local tabs = Instance.new("ScrollingFrame")
tabs.BackgroundTransparency = 1
tabs.Size = UDim2.new(1, -24, 0, MIN_TOUCH + 8)
tabs.Position = UDim2.new(0, 12, 0, 54 + 12)
tabs.ScrollingDirection = Enum.ScrollingDirection.X
tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
tabs.CanvasSize = UDim2.new()
tabs.ScrollBarThickness = 4
tabs.Parent = panel
local tl = Instance.new("UIListLayout")
tl.FillDirection = Enum.FillDirection.Horizontal
tl.Padding = UDim.new(0, 6)
tl.SortOrder = Enum.SortOrder.LayoutOrder
tl.Parent = tabs

local TOP = 54 + 12 + MIN_TOUCH + 14
local body = Instance.new("ScrollingFrame")
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, -24, 1, -TOP - 12)
body.Position = UDim2.new(0, 12, 0, TOP)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.CanvasSize = UDim2.new()
body.ScrollBarThickness = 6
body.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(150, 120)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = body

local scale = Instance.new("UIScale")
scale.Parent = panel
local narrow = false
local render
local function layout()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local v = cam.ViewportSize
	-- Phones: fill the screen at full size (never shrink text or targets under the floors).
	narrow = v.X < 820 or v.Y < 600
	if narrow then
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

local TABS = {
	{ id = "coats", icon = "🐴", word = "Coats" },
	{ id = "rosettes", icon = "🏵️", word = "Rosettes" },
	{ id = "courses", icon = "🗺️", word = "Courses" },
	{ id = "cups", icon = "🏆", word = "Cups" },
	{ id = "passport", icon = "🩺", word = "Passport" },
	{ id = "tour", icon = "👫", word = "Friends" },
	{ id = "bests", icon = "★", word = "Bests" },
	{ id = "cloths", icon = "🎀", word = "Cloths" },
}
local page = "coats"

local function clear()
	for _, ch in body:GetChildren() do
		if not ch:IsA("UIGridLayout") then ch:Destroy() end
	end
end

-- One thing in the book: earned = bright card; not yet = grey card with a "?".
local function entryCard(e, order: number, coatColor: Color3?, extra: string?)
	local card = Ui.card(body, UDim2.new(), UDim2.new(), if e.earned then C.cream else C.shade)
	card.LayoutOrder = order
	if coatColor then
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(56, 56)
		dot.Position = UDim2.new(0.5, -28, 0, 10)
		dot.BackgroundColor3 = if e.earned then coatColor else C.ink
		dot.BackgroundTransparency = if e.earned then 0 else 0.55
		Ui.corner(dot, 28)
		Ui.stroke(dot, 3)
		dot.Parent = card
		Ui.text(dot, if e.earned then "🐴" else "?", 28, { Size = UDim2.fromScale(1, 1), TextScaled = true }).TextColor3 = C.white
	else
		local icon = Ui.text(card, if e.earned then e.emoji else "?", 40, { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0, 8) })
		if not e.earned then icon.TextColor3 = C.plum end
	end
	local label = Ui.text(card, e.label, TEXT, { Size = UDim2.new(1, -12, 0, 40), Position = UDim2.new(0, 6, 0, 70) })
	label.TextColor3 = if e.earned then C.ink else C.plum
	if extra then
		local x = Ui.text(card, extra, SMALL, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 1, -26) })
		x.TextColor3 = C.cash
	end
	return card
end

local function note(text: string, order: number)
	local card = Ui.card(body, UDim2.new(), UDim2.new(), C.white)
	card.LayoutOrder = order
	Ui.text(card, text, TEXT, { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8) })
	return card
end

local thumbs: { [number]: string } = {}
local names: { [number]: string } = {}
local function friendCard(userId: number, order: number)
	local card = Ui.card(body, UDim2.new(), UDim2.new(), C.cream)
	card.LayoutOrder = order
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromOffset(64, 64)
	img.Position = UDim2.new(0.5, -32, 0, 8)
	img.BackgroundColor3 = C.white
	img.Image = thumbs[userId] or ""
	Ui.corner(img, 32)
	Ui.stroke(img, 3)
	img.Parent = card
	local label = Ui.text(card, names[userId] or "Friend", TEXT, { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.new(0, 6, 0, 76),
		TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
	Ui.text(card, "🐾 Stamp", SMALL, { Size = UDim2.new(1, -12, 0, 18), Position = UDim2.new(0, 6, 1, -24) }).TextColor3 = C.cash
	if not thumbs[userId] or not names[userId] then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and typeof(url) == "string" then
				thumbs[userId] = url
				if img.Parent then img.Image = url end
			end
			local okN, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
			if okN and typeof(name) == "string" then
				names[userId] = name
				if label.Parent then label.Text = name end
			end
		end)
	end
end

local function pageOf(book, id: string)
	for _, p in book.pages or {} do
		if p.id == id then return p end
	end
	return nil
end

render = function()
	if not gui.Enabled then return end
	local d = PlayerState.data
	local book = d and d.book
	clear()
	for _, ch in tabs:GetChildren() do
		if ch:IsA("TextButton") then ch:Destroy() end
	end
	if not book then
		note("Your Horse Book is opening…", 1)
		return
	end
	title.Text = string.format("📖 Horse Book  %d / %d", book.got or 0, book.total or 0)
	for k, t in TABS do
		local b = Ui.button(tabs, t.icon .. " " .. t.word, UDim2.fromOffset(if narrow then 128 else 132, MIN_TOUCH), UDim2.new(),
			if page == t.id then C.gold else C.white, TEXT)
		b.LayoutOrder = k
		b.Activated:Connect(function()
			page = t.id
			render()
		end)
	end
	grid.CellSize = if narrow then UDim2.new(0.5, -6, 0, 120) else UDim2.fromOffset(176, 124)
	if page == "tour" then
		local tour = book.tour or { count = 0, friends = {} }
		if (tour.count or 0) == 0 then
			note("No Tour stamps yet. Visit a friend's barn and pat every horse!", 1)
			return
		end
		note(string.format("👫 %d barn%s toured!", tour.count, if tour.count == 1 then "" else "s"), 0)
		for k, uid in tour.friends or {} do friendCard(uid, k) end
		return
	end
	if page == "bests" then
		note("Your best ride at each distance. Only you see these.", 0)
		for k, b in book.bests or {} do
			local stars = if b.stars then string.rep("★", b.stars) .. string.rep("☆", 3 - b.stars) else nil
			entryCard({ earned = b.score ~= nil, emoji = b.emoji, label = b.distance }, k, nil,
				if b.score then string.format("%s  %d", stars, b.score) else "Race one!")
		end
		return
	end
	local p = pageOf(book, page)
	if not p then return end
	local jobs = d.jobs
	for k, e in p.entries do
		local extra = nil
		if page == "cloths" and not e.earned and jobs and jobs.monthCloth == e.id then
			extra = string.format("🎀 %d / %d", math.min(jobs.monthStamps or 0, jobs.stampsNeeded or 8), jobs.stampsNeeded or 8)
		end
		entryCard(e, k, if page == "coats" then Ui.coatColors[e.id] else nil, extra)
	end
end

local function open()
	if not PlayerState.data then return end
	gui.Enabled = true
	panel.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	render()
end
local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
openEvent.Event:Connect(function()
	if gui.Enabled then close() else open() end
end)
PlayerState.Changed.Event:Connect(function() render() end)
-- Your race starting closes the book.
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if player:GetAttribute("Racing") and gui.Enabled then close() end
end)
