--!nonstrict
-- RacePicker (D-036): RACE! opens the next race on each course as a big card (league badge,
-- distance, surface, weather, riders in line, starts in…) and your stalled horses with their
-- Energy and how well each suits today's race (shown as Rating, never win chance, because
-- chance depends on the field). Pick a card and a horse, then Join. Tired horses nap on
-- their card ("Napping", only at 0 Energy, D-058), with no countdown and no buy button.
-- Per-league queues (D-061 core, stage 1): only a card your horse can join is ever preselected or
-- joinable; another league's card shows its badge and "Watch" (hoofprints to the grandstand).
-- With no joinable card, Join puts you in your league's line for the next free course.
-- One race button (D-061 stage 2): RACE! joins at once with the active horse, so this picker is
-- "More choices" (another horse, Practice, the Cup, a course), opened from the queue card.
-- Clarity pass (D-064, stage 3): each race card is its league's colour and badge with one short
-- line (PickerText.cardLine) and a status chip; a horse card says how today's race suits it in
-- words, never a number; every button is at least ui.panelButtonPx tall.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceRating = require(Shared:WaitForChild("RaceRating"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local PickerText = require(Shared:WaitForChild("PickerText"))
local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors

local TEXT = GameConfig.ui.panelMinText -- the smallest text on this panel (16)
local TAP = GameConfig.ui.panelButtonPx  -- the smallest button on this panel (64)

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
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.new(), C.paper)
local slideIn = Ui.fitPanel(panel, W, H) -- never shrinks text under 14 px: scrolls instead (D-064)
local QCARD = GameConfig.queueCard or {}
local moreChoices = QCARD.enabled ~= false and QCARD.oneTapRace ~= false
Ui.text(panel, if moreChoices then "🔀 More choices" else "🏁 Pick a race", 32, { Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 38) })
local closeBtn = Ui.button(panel, "✕", UDim2.fromOffset(TAP, TAP), UDim2.new(1, -TAP - 10, 0, 6), C.white, 26)

local cardRow = Instance.new("Frame")
cardRow.BackgroundTransparency = 1
cardRow.Size = UDim2.new(1, -32, 0, 150)
cardRow.Position = UDim2.new(0, 16, 0, 74)
cardRow.Parent = panel
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
cl.Padding = UDim.new(0, 14)
cl.Parent = cardRow

Ui.text(panel, "Your horse", 20, { Position = UDim2.new(0, 18, 0, 228), Size = UDim2.new(0, 200, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
local horseRow = Instance.new("ScrollingFrame")
horseRow.BackgroundTransparency = 1
horseRow.Size = UDim2.new(1, -32, 0, 112)
horseRow.Position = UDim2.new(0, 16, 0, 254)
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
local joinBtn = Ui.button(panel, "Join!", UDim2.fromOffset(250, TAP), UDim2.new(1, -266, 1, -TAP - 16), C.orange, 28)

-- Race kind for an open card: a regular race, the Cup (when the horse has the points, or
-- is too strong for its league), or Practice (free, no prizes, open to tired horses too).
local kindRow = Instance.new("Frame")
kindRow.BackgroundTransparency = 1
kindRow.Size = UDim2.new(0, 430, 0, TAP)
kindRow.Position = UDim2.new(0, 16, 1, -TAP - 16)
kindRow.Parent = panel
local kl = Instance.new("UIListLayout")
kl.FillDirection = Enum.FillDirection.Horizontal
kl.Padding = UDim.new(0, 8)
kl.Parent = kindRow
local kindButtons = {}
local kindAllowed: { [string]: boolean } = { race = true, cup = false, practice = true }
for _, k in { { "race", "🏁 Race" }, { "cup", "🏆 Cup" }, { "practice", "🎈 Practice" } } do
	local b = Ui.button(kindRow, k[2], UDim2.fromOffset(136, TAP), UDim2.new(), C.white, 20)
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

local function leagueQueues(): boolean
	return GameConfig.queue == nil or GameConfig.queue.mode ~= "cards"
end

-- Can this horse join this card? An open card takes any league; a claimed one only its own.
local function joinable(c, h): boolean
	if not c or c.riders >= c.lanes then return false end
	if not leagueQueues() then return true end
	return c.open or (h ~= nil and c.league == (h.league or "Rookie"))
end

renderKinds = function()
	local card = pickedCourse and cardFor(pickedCourse)
	local h = pickedHorse and PlayerState.horse(pickedHorse)
	local open = card == nil or card.open
	for _, kind in { "race", "cup", "practice" } do
		local allowed = true
		if not open then
			allowed = (kind == "cup" and card.cup) or (kind == "practice" and card.practice) or (kind == "race" and not card.cup and not card.practice)
		elseif h then
			if kind == "cup" then allowed = h.cupOpen == true end
			if kind == "race" then allowed = not h.overCeiling end
		end
		kindAllowed[kind] = allowed == true
	end
	if not open then
		pickedKind = if card.cup then "cup" elseif card.practice then "practice" else "race"
	elseif not kindAllowed[pickedKind] then
		pickedKind = if kindAllowed.race then "race" else "practice"
	end
	for kind, b in kindButtons do
		b.BackgroundColor3 = if pickedKind == kind then C.gold elseif kindAllowed[kind] then C.white else C.shade
	end
	-- No "pts" (D-064): the Cup button is grey with a 🔒 until the Cup is open.
	kindButtons.cup.Text = if kindAllowed.cup then "🏆 Cup" else "🏆 Cup 🔒"
end

local function raceCard(c)
	local selected = c.course == pickedCourse
	local full = c.riders >= c.lanes
	local h = pickedHorse and PlayerState.horse(pickedHorse)
	local watch = leagueQueues() and not c.open and h ~= nil and c.league ~= (h.league or "Rookie")
	-- The league is the card's colour and badge; one short line; lane dots; a status chip.
	local league = c.league or (h and h.league) or "Rookie"
	local face = if selected then C.gold elseif full or watch then C.shade else (Ui.leagueColors[league] or C.cream)
	local card = Ui.card(cardRow, UDim2.fromOffset(330, 146), UDim2.new(), face)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if selected then
		stroke.Thickness = 6
		stroke.Color = C.orangeDark
	end
	Ui.icon(card, Ui.badge(league), "🏅", UDim2.fromOffset(48, 48), UDim2.new(0, 10, 0, 8))
	Ui.text(card, PickerText.cardLine(c), 20,
		{ Position = UDim2.new(0, 66, 0, 6), Size = UDim2.new(1, -74, 0, 52), TextXAlignment = Enum.TextXAlignment.Left })
	-- Eight lane dots: filled = a rider is in line.
	local dots = Instance.new("Frame")
	dots.BackgroundTransparency = 1
	dots.Size = UDim2.new(1, -20, 0, 24)
	dots.Position = UDim2.new(0, 10, 0, 64)
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
	Ui.text(card, PickerText.status(c, watch), 20, { Position = UDim2.new(0, 10, 0, 98), Size = UDim2.new(1, -20, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 5
	hit.Parent = card
	hit.Activated:Connect(function()
		if watch then -- another league's race: watch it from the grandstand
			local p = WorldLayout.places.raceBoard
			Guide.to(p.x, p.z + 10)
			Ui.toast("Follow the hoofprints to watch!", "flag_ready", "👀")
			return
		end
		pickedCourse = c.course
		renderCards()
		renderHorses()
	end)
end

local function horseCard(h, card)
	local selected = h.id == pickedHorse
	local practice = pickedKind == "practice" or (card ~= nil and card.practice)
	local tired = not practice and h.energy < GameConfig.energy.costPerCashRace
		and not GameConfig.energy.freeLeagues[(card and card.league) or h.league or "Rookie"]
	local b = Ui.button(horseRow, "", UDim2.fromOffset(210, 104), UDim2.new(), if selected then C.gold elseif tired then C.shade else C.white, 18)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(40, 40)
	dot.Position = UDim2.new(0, 8, 0, 8)
	dot.BackgroundColor3 = Ui.coatColors[h.coat] or Ui.coatColors.bay
	Ui.corner(dot, 20)
	Ui.stroke(dot, 2)
	dot.Parent = b
	local name = Ui.text(b, h.name, 20, { Position = UDim2.new(0, 54, 0, 6), Size = UDim2.new(1, -60, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	name.TextTruncate = Enum.TextTruncate.AtEnd
	Ui.energyPips(b, h.energy, GameConfig.energy.maxPerRacer, 18, UDim2.new(0, 54, 0, 31)) -- the one Energy icon (D-064)
	local diff = suits(h, card)
	local line = PickerText.suits(diff, tired) -- words, never a number (D-064)
	local l = Ui.text(b, line, TEXT, { Position = UDim2.new(0, 8, 0, 64), Size = UDim2.new(1, -16, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
	l.TextColor3 = if diff and diff > 0.5 then C.green elseif diff and diff < -0.5 then C.orangeDark else C.plum
	b.Activated:Connect(function()
		if tired then
			Ui.toast(h.name .. " is napping. Try another horse!", "zzz_resting", "😴")
			return
		end
		pickedHorse = h.id
		renderCards(true) -- (lets go of a picked card that's for another league)
		renderHorses()
	end)
end

-- Cards refresh every second (riders, countdown); horses only when something changes, so a
-- tap on a horse is never interrupted by a redraw.
local lastCardsKey = ""
renderCards = function(force: boolean?)
	if not gui.Enabled then return end
	-- A picked card that a league has since claimed for others is let go.
	local h = pickedHorse and PlayerState.horse(pickedHorse)
	if pickedCourse and not joinable(cardFor(pickedCourse), h) then pickedCourse = nil end
	-- The key has everything a card shows, league, kind and Cup included (D-065), so a card
	-- claimed by a league never keeps its "Open" look.
	local parts = { tostring(pickedCourse), tostring(pickedHorse) }
	for _, c in cards do
		table.insert(parts, table.concat({ c.course, c.distance or "", c.weather or "", c.riders, tostring(c.seconds), tostring(c.racing),
			tostring(c.league), tostring(c.open), tostring(c.cup), tostring(c.practice) }, ":"))
	end
	local key = table.concat(parts, "|")
	if key == lastCardsKey and not force then return end
	lastCardsKey = key
	for _, ch in cardRow:GetChildren() do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	for _, c in cards do raceCard(c) end
	renderKinds()
	local canWait = leagueQueues() and h ~= nil -- no card for us: wait in our league's line
	joinBtn.Text = if pickedCourse then "Join!" elseif canWait then "Join the line!" else "Pick a race"
	joinBtn.BackgroundColor3 = if pickedCourse or canWait then C.orange else C.shade
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
	-- Preselect only a card this horse can join (D-061): one with riders of its league waiting,
	-- else an open one that isn't racing. None: Join puts it in its league's line.
	local h = pickedHorse and PlayerState.horse(pickedHorse)
	if not pickedCourse or not joinable(cardFor(pickedCourse), h) then
		local best, score = nil, -math.huge
		for _, c in cards do
			local s = c.riders * 10 + (if c.racing then -50 else 0)
			if joinable(c, h) and s > score then best, score = c.course, s end
		end
		pickedCourse = best
	end
	gui.Enabled = true
	slideIn()
	renderCards(true)
	renderHorses()
end
local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
joinBtn.Activated:Connect(function()
	if not pickedCourse then
		if leagueQueues() and pickedHorse then -- wait in this league's line for the next free course
			raceRemotes:WaitForChild("JoinRace"):FireServer(true, nil, pickedHorse, pickedKind)
			close()
		end
		return
	end
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
