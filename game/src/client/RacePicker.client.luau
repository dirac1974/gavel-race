--!nonstrict
-- RacePicker (D-036): RACE! opens the next race on each course as a big card (league badge,
-- distance, surface, weather, riders in line, starts in…) and your stalled horses with their
-- Energy and how well each suits today's race (shown as Rating, never win chance, because
-- chance depends on the field). Pick a card and a horse, then Join. Tired horses nap on
-- their card ("Resting"), with no countdown and no buy button.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceRating = require(Shared:WaitForChild("RaceRating"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors

local DIST_ICON = { Sprint = "dist_short", Mile = "dist_short", Classic = "dist_long", Marathon = "dist_long" }
local DIST_EMOJI = { Sprint = "⚡", Mile = "🏇", Classic = "🏆", Marathon = "🛤️" }
local DIST_TEXT = { Sprint = "Sprint · short", Mile = "Mile", Classic = "Classic · long", Marathon = "Marathon · longest" }
local SURF_EMOJI = { Dirt = "🟫", Turf = "🟩" }
local WEATHER_EMOJI = { Sunny = "☀️", Rain = "🌧️", Wind = "🌬️" }

local cards = {}
local pickedCourse: string? = nil
local pickedHorse: string? = nil
local pickedKind = "race" -- "race" | "cup" | "practice" (D-046)

local gui = Ui.screen("RacePicker", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local W, H = 720, 470
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = Instance.new("UIScale")
scale.Parent = panel
local function rescale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.min(1, (cam.ViewportSize.X - 20) / W, (cam.ViewportSize.Y - 20) / H) end
end
rescale()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
Ui.text(panel, "🏁 Pick a race", 32, { Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 38) })
local closeBtn = Ui.button(panel, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 10), C.white, 22)

local cardRow = Instance.new("Frame")
cardRow.BackgroundTransparency = 1
cardRow.Size = UDim2.new(1, -32, 0, 170)
cardRow.Position = UDim2.new(0, 16, 0, 58)
cardRow.Parent = panel
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
cl.Padding = UDim.new(0, 14)
cl.Parent = cardRow

Ui.text(panel, "Your horse", 20, { Position = UDim2.new(0, 18, 0, 236), Size = UDim2.new(0, 200, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
local horseRow = Instance.new("ScrollingFrame")
horseRow.BackgroundTransparency = 1
horseRow.Size = UDim2.new(1, -32, 0, 104)
horseRow.Position = UDim2.new(0, 16, 0, 262)
horseRow.ScrollingDirection = Enum.ScrollingDirection.X
horseRow.AutomaticCanvasSize = Enum.AutomaticSize.X
horseRow.CanvasSize = UDim2.new()
horseRow.ScrollBarThickness = 4
horseRow.Parent = panel
local hl = Instance.new("UIListLayout")
hl.FillDirection = Enum.FillDirection.Horizontal
hl.Padding = UDim.new(0, 10)
hl.Parent = horseRow

local renderCards, renderHorses, renderKinds -- defined below; the buttons call them
local joinBtn = Ui.button(panel, "Join!", UDim2.fromOffset(260, 62), UDim2.new(1, -276, 1, -78), C.orange, 30)

-- Race kind for an open card: a regular race, the Cup (when the horse has the points, or
-- is too strong for its league), or Practice (free, no prizes, open to tired horses too).
local kindRow = Instance.new("Frame")
kindRow.BackgroundTransparency = 1
kindRow.Size = UDim2.new(0, 420, 0, 50)
kindRow.Position = UDim2.new(0, 16, 1, -72)
kindRow.Parent = panel
local kl = Instance.new("UIListLayout")
kl.FillDirection = Enum.FillDirection.Horizontal
kl.Padding = UDim.new(0, 8)
kl.Parent = kindRow
local kindButtons = {}
local kindAllowed: { [string]: boolean } = { race = true, cup = false, practice = true }
for _, k in { { "race", "🏁 Race" }, { "cup", "🏆 Cup" }, { "practice", "🎈 Practice" } } do
	local b = Ui.button(kindRow, k[2], UDim2.fromOffset(130, 46), UDim2.new(), C.white, 18)
	kindButtons[k[1]] = b
	b.Activated:Connect(function()
		if not kindAllowed[k[1]] then return end
		pickedKind = k[1]
		renderKinds()
		renderHorses()
	end)
end

-- How well a horse suits these conditions: today's Rating minus its average Rating over
-- every distance, surface and weather (D-014). Positive = a good day for it.
local avgCache: { [string]: number } = {}
local function suits(h, card): number?
	if not card or not card.distance then return nil end
	local care, bond = h.care or 0, (h.bond or 0) / 100
	local cond = { distance = card.distance, surface = card.surface, weather = card.weather }
	local today = RaceRating.rating(h.stats, cond, care, 0, h.style, bond)
	local key = h.id .. ":" .. table.concat({ h.stats.speed, h.stats.accel, h.stats.stamina, h.stats.grit, care, bond }, ",")
	local avg = avgCache[key]
	if not avg then
		local total, n = 0, 0
		for d in RaceRating.DISTANCE_WEIGHTS do
			for s in RaceRating.SURFACE_SHIFT do
				for w in RaceRating.WEATHER_SHIFT do
					total += RaceRating.rating(h.stats, { distance = d, surface = s, weather = w }, care, 0, h.style, bond)
					n += 1
				end
			end
		end
		avg = total / n
		avgCache[key] = avg
	end
	return today - avg
end

local function cardFor(course: string)
	for _, c in cards do
		if c.course == course then return c end
	end
	return nil
end

renderKinds = function()
	local card = pickedCourse and cardFor(pickedCourse)
	local h = pickedHorse and PlayerState.horse(pickedHorse)
	local open = card == nil or card.open
	for kind, b in kindButtons do
		local allowed = true
		if not open then
			allowed = (kind == "cup" and card.cup) or (kind == "practice" and card.practice) or (kind == "race" and not card.cup and not card.practice)
		elseif h then
			if kind == "cup" then allowed = h.cupOpen == true end
			if kind == "race" then allowed = not h.overCeiling end
		end
		if not open and allowed then pickedKind = kind end
		if open and not allowed and pickedKind == kind then pickedKind = "practice" end
		b.BackgroundColor3 = if pickedKind == kind and allowed then C.gold elseif allowed then C.white else C.shade
		kindAllowed[kind] = allowed
	end
	if h and h.pointsToCup and h.pointsToCup > 0 then
		kindButtons.cup.Text = string.format("🏆 %d pts", h.pointsToCup)
	else
		kindButtons.cup.Text = "🏆 Cup"
	end
end

local function raceCard(c)
	local selected = c.course == pickedCourse
	local full = c.riders >= c.lanes
	local card = Ui.card(cardRow, UDim2.fromOffset(330, 166), UDim2.new(), if selected then C.gold elseif full then C.shade else C.cream)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if selected then
		stroke.Thickness = 6
		stroke.Color = C.orangeDark
	end
	Ui.icon(card, "league_" .. string.lower(c.league or "rookie"), "🎀", UDim2.fromOffset(44, 44), UDim2.new(0, 10, 0, 10))
	local kindText = if c.open then "Open · your horse's league" elseif c.cup then "🏆 " .. (c.league or "") .. " Cup"
		elseif c.practice then "🎈 Practice" else (c.league or "")
	Ui.text(card, string.format("%s %s", kindText, if c.course == "dirt" then "· Dirt" else "· Turf"), 20,
		{ Position = UDim2.new(0, 60, 0, 8), Size = UDim2.new(1, -66, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	Ui.text(card, string.format("%s %s   %s %s   %s", DIST_EMOJI[c.distance] or "🏇", DIST_TEXT[c.distance] or (c.distance or ""),
		SURF_EMOJI[c.surface] or "", c.surface or "", WEATHER_EMOJI[c.weather] or ""), 18,
		{ Position = UDim2.new(0, 60, 0, 34), Size = UDim2.new(1, -66, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	-- Eight lane dots: filled = a rider is in line.
	local dots = Instance.new("Frame")
	dots.BackgroundTransparency = 1
	dots.Size = UDim2.new(1, -20, 0, 26)
	dots.Position = UDim2.new(0, 10, 0, 70)
	dots.Parent = card
	local dl = Instance.new("UIListLayout")
	dl.FillDirection = Enum.FillDirection.Horizontal
	dl.Padding = UDim.new(0, 6)
	dl.Parent = dots
	for k = 1, c.lanes do
		local d = Instance.new("Frame")
		d.Size = UDim2.fromOffset(24, 24)
		d.BackgroundColor3 = if k <= c.riders then C.orange else C.white
		Ui.corner(d, 12)
		Ui.stroke(d, 2)
		d.Parent = dots
	end
	local status = if c.racing then "🏇 Racing now · next race after"
		elseif c.seconds then string.format("⏱ Starts in %ds", c.seconds)
		elseif c.riders > 0 then "Filling up…"
		else "Open · be the first!"
	Ui.text(card, status, 18, { Position = UDim2.new(0, 10, 0, 104), Size = UDim2.new(1, -20, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	Ui.text(card, if c.cup then "🏆 Win to move up a league!" elseif c.practice then "🎈 Just for fun: no Energy, no prizes"
		else "🎀 Ribbons and Green Cash", 14,
		{ Position = UDim2.new(0, 10, 0, 130), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 5
	hit.Parent = card
	hit.Activated:Connect(function()
		pickedCourse = c.course
		renderCards()
		renderHorses()
	end)
end

local function horseCard(h, card)
	local selected = h.id == pickedHorse
	local practice = pickedKind == "practice" or (card ~= nil and card.practice)
	local tired = not practice and h.resting and h.energy < GameConfig.energy.costPerCashRace
		and not GameConfig.energy.freeLeagues[(card and card.league) or h.league or "Rookie"]
	local b = Ui.button(horseRow, "", UDim2.fromOffset(200, 96), UDim2.new(), if selected then C.gold elseif tired then C.shade else C.white, 18)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(40, 40)
	dot.Position = UDim2.new(0, 8, 0, 8)
	dot.BackgroundColor3 = Ui.coatColors[h.coat] or Ui.coatColors.bay
	Ui.corner(dot, 20)
	Ui.stroke(dot, 2)
	dot.Parent = b
	local name = Ui.text(b, h.name, 18, { Position = UDim2.new(0, 54, 0, 6), Size = UDim2.new(1, -60, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	name.TextTruncate = Enum.TextTruncate.AtEnd
	Ui.text(b, string.rep("⚡", h.energy) .. string.rep("·", GameConfig.energy.maxPerRacer - h.energy), 16,
		{ Position = UDim2.new(0, 54, 0, 30), Size = UDim2.new(1, -60, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
	local diff = suits(h, card)
	local line
	if tired then
		line = "😴 Resting"
	elseif diff then
		local d = math.floor(diff + 0.5)
		line = if d > 0 then string.format("Loves today's race (+%d)", d) elseif d < 0 then string.format("Not its best today (%d)", d) else "A normal day"
	else
		line = ""
	end
	local l = Ui.text(b, line, 15, { Position = UDim2.new(0, 8, 0, 60), Size = UDim2.new(1, -16, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
	l.TextColor3 = if diff and diff > 0.5 then C.green elseif diff and diff < -0.5 then C.orangeDark else C.plum
	b.Activated:Connect(function()
		if tired then
			Ui.toast(h.name .. " is resting. Try another horse!", "zzz_resting", "😴")
			return
		end
		pickedHorse = h.id
		renderHorses()
	end)
end

-- Cards refresh every second (riders, countdown); horses only when something changes, so a
-- tap on a horse is never interrupted by a redraw.
local lastCardsKey = ""
renderCards = function(force: boolean?)
	if not gui.Enabled then return end
	local parts = { tostring(pickedCourse) }
	for _, c in cards do
		table.insert(parts, table.concat({ c.course, c.distance or "", c.weather or "", c.riders, tostring(c.seconds), tostring(c.racing) }, ":"))
	end
	local key = table.concat(parts, "|")
	if key == lastCardsKey and not force then return end
	lastCardsKey = key
	for _, ch in cardRow:GetChildren() do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	for _, c in cards do raceCard(c) end
	renderKinds()
	joinBtn.Text = if pickedCourse then "Join!" else "Pick a race"
	joinBtn.BackgroundColor3 = if pickedCourse then C.orange else C.shade
end
renderHorses = function()
	if not gui.Enabled then return end
	for _, ch in horseRow:GetChildren() do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	local card = pickedCourse and cardFor(pickedCourse)
	for _, h in (PlayerState.data and PlayerState.data.horses) or {} do
		if h.stalled then horseCard(h, card) end
	end
	renderKinds()
end

local function open()
	local d = PlayerState.data
	if not d then
		Ui.toast("Your stable is loading…", "hay", "🐴")
		return
	end
	if #d.horses == 0 then
		HudEvents:WaitForChild("OpenStarter"):Fire()
		return
	end
	pickedHorse = pickedHorse or d.activeHorse
	-- Preselect the course with riders waiting, else the one that isn't racing.
	if not pickedCourse or not cardFor(pickedCourse) then
		local best, score = nil, -math.huge
		for _, c in cards do
			local s = c.riders * 10 + (if c.racing then -50 else 0)
			if c.riders < c.lanes and s > score then best, score = c.course, s end
		end
		pickedCourse = best
	end
	gui.Enabled = true
	panel.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	renderCards(true)
	renderHorses()
end
local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
joinBtn.Activated:Connect(function()
	if not pickedCourse then return end
	local card = cardFor(pickedCourse)
	local kind = if card and not card.open then (if card.cup then "cup" elseif card.practice then "practice" else "race") else pickedKind
	raceRemotes:WaitForChild("JoinRace"):FireServer(true, pickedCourse, pickedHorse, kind)
	close()
end)

raceRemotes:WaitForChild("RaceCards").OnClientEvent:Connect(function(view)
	cards = view
	renderCards()
end)
PlayerState.Changed.Event:Connect(function() renderHorses() end)

local openEvent = HudEvents:FindFirstChild("OpenRacePicker")
if not openEvent then
	openEvent = Instance.new("BindableEvent")
	openEvent.Name = "OpenRacePicker"
	openEvent.Parent = HudEvents
end
openEvent.Event:Connect(function() if gui.Enabled then close() else open() end end)

-- Your queued race starting closes the picker.
game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("Racing"):Connect(function()
	if game:GetService("Players").LocalPlayer:GetAttribute("Racing") and gui.Enabled then close() end
end)
