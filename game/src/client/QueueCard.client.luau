--!nonstrict
-- QueueCard (D-061 stage 2): while you're in line, a card at the top of the screen shows the
-- wait so kids can see it: a countdown ring with the seconds in big numbers, the gate's 8 slots
-- filling with each rider's horse name and coat dot (yours in gold), and "🤖 Bots join at 0".
-- You can groom, ride or visit while it's up. When the gate fills, "Race time!" with hoofprints
-- stepping to GO, and the server brings you to the gate. ✕ leaves the line; "More" opens the
-- race picker (pick a horse, Practice, Cup). What it shows comes from QueueView (Lune-tested).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local QueueView = require(Shared:WaitForChild("QueueView"))
local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local CFG = GameConfig.queueCard or {}
if CFG.enabled == false then return end

local player = Players.LocalPlayer
local C = Ui.colors
local state = QueueView.new(GameConfig.lanes, GameConfig.lobbyFillSeconds)

local function reducedMotion(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

-- Layout (unscaled px). Never scaled below minTextPx / 14 so the smallest text (14 px) stays 14.
local W, H = 660, 156
local RING, DOTS = 104, 20
local SLOT_W, SLOT_H, GAP = 110, 38, 6
local MIN_SCALE = GameConfig.ui.minTextPx / 16 -- the smallest text on the card is 16 px

local gui = Ui.screen("QueueCard", 12) -- above the care card and the picker (11): visible while grooming
gui.Enabled = false
local inset = GuiService:GetGuiInset()
local card = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.new(0.5, 0, 0, inset.Y + 8), C.paper)
card.AnchorPoint = Vector2.new(0.5, 0)
local scale = Instance.new("UIScale")
scale.Parent = card
local function rescale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.clamp((cam.ViewportSize.X - 24) / W, MIN_SCALE, 1) end
end
rescale()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)

-- The countdown ring: DOTS dots round a circle; lit dots are the time left.
local ring = Instance.new("Frame")
ring.BackgroundTransparency = 1
ring.Size = UDim2.fromOffset(RING, RING)
ring.Position = UDim2.fromOffset(10, (H - RING) / 2 - 2)
ring.Parent = card
local dots = {}
for k = 1, DOTS do
	local a = (k - 1) / DOTS * 2 * math.pi -- clockwise from 12 o'clock
	local d = Instance.new("Frame")
	d.Size = UDim2.fromOffset(14, 14)
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.new(0.5, math.sin(a) * (RING / 2 - 9), 0.5, -math.cos(a) * (RING / 2 - 9))
	d.BorderSizePixel = 0
	Ui.corner(d, 7)
	d.Parent = ring
	dots[k] = d
end
local bigNum = Ui.text(ring, "", 44, { Size = UDim2.fromOffset(RING - 30, 52), Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5), TextScaled = false, TextWrapped = false })

local left = 10 + RING + 12
local right = 10 + 56 + 10 -- the button column
local title = Ui.text(card, "", 26, { Position = UDim2.fromOffset(left, 6), Size = UDim2.new(1, -(left + right), 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
local subtitle = Ui.text(card, "", 18, { Position = UDim2.fromOffset(left, 36), Size = UDim2.new(1, -(left + right), 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
subtitle.TextColor3 = C.plum

-- "Race time!" hoofprints: they step across the subtitle line to GO.
local hoofRow = Instance.new("Frame")
hoofRow.BackgroundTransparency = 1
hoofRow.Size = UDim2.new(1, -(left + right), 0, 24)
hoofRow.Position = UDim2.fromOffset(left, 35)
hoofRow.Visible = false
hoofRow.Parent = card
local hl = Instance.new("UIListLayout")
hl.FillDirection = Enum.FillDirection.Horizontal
hl.Padding = UDim.new(0, 6)
hl.VerticalAlignment = Enum.VerticalAlignment.Center
hl.Parent = hoofRow
local hoofs = {}
for k = 1, 6 do
	local h = Ui.text(hoofRow, "🐾", 20, { Size = UDim2.fromOffset(26, 24), LayoutOrder = k, Rotation = if k % 2 == 0 then 12 else -12 })
	hoofs[k] = h
end
local goLabel = Ui.text(hoofRow, "GO!", 22, { Size = UDim2.fromOffset(52, 24), LayoutOrder = 7, TextWrapped = false })
goLabel.TextColor3 = C.orangeDark

-- The gate: two rows of four slots (lane order), each a coat dot and the horse's name.
local gate = Instance.new("Frame")
gate.BackgroundTransparency = 1
gate.Position = UDim2.fromOffset(left, 62)
gate.Size = UDim2.fromOffset(4 * SLOT_W + 3 * GAP, 2 * SLOT_H + GAP)
gate.Parent = card
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(SLOT_W, SLOT_H)
grid.CellPadding = UDim2.fromOffset(GAP, GAP)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = gate
local slotUi = {}
for k = 1, GameConfig.lanes do
	local f = Instance.new("Frame")
	f.LayoutOrder = k
	f.BorderSizePixel = 0
	Ui.corner(f, 10)
	local stroke = Ui.stroke(f, 2)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(20, 20)
	dot.Position = UDim2.new(0, 6, 0.5, -10)
	dot.BorderSizePixel = 0
	Ui.corner(dot, 10)
	Ui.stroke(dot, 2)
	dot.Parent = f
	local name = Ui.text(f, "", 16, { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -33, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	f.Parent = gate
	slotUi[k] = { frame = f, dot = dot, name = name, stroke = stroke }
end

-- Buttons: ✕ leaves the line; "More" opens the picker (another horse, Practice, the Cup).
local leaveBtn = Ui.button(card, "✕", UDim2.fromOffset(56, 56), UDim2.new(1, -66, 0, 8), C.white, 26)
local moreBtn = Ui.button(card, "", UDim2.fromOffset(56, 64), UDim2.new(1, -66, 0, 76), C.sky, 14)
Ui.text(moreBtn, "🔀", 24, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4) })
Ui.text(moreBtn, "More", 16, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -24) })
leaveBtn.Activated:Connect(function()
	raceRemotes:WaitForChild("JoinRace"):FireServer(false)
end)
moreBtn.Activated:Connect(function()
	local events = ReplicatedStorage:FindFirstChild("HudEvents")
	local open = events and events:FindFirstChild("OpenRacePicker")
	if open then open:Fire() end
end)

-- Server events -------------------------------------------------------------------
raceRemotes:WaitForChild("QueueStatus").OnClientEvent:Connect(function(isIn, count, seconds, courseId)
	QueueView.status(state, isIn == true, count, seconds, courseId, os.clock())
end)
raceRemotes:WaitForChild("QueueGate").OnClientEvent:Connect(function(courseId, riders, lanes, seconds, racing)
	if typeof(riders) ~= "table" then riders = {} end
	QueueView.gate(state, courseId, riders, lanes, seconds, racing, os.clock())
end)
local raceTimeAt = 0
raceRemotes:WaitForChild("RaceTime").OnClientEvent:Connect(function(courseId, cancel)
	if cancel then -- you left the line
		QueueView.clear(state)
		return
	end
	QueueView.raceTime(state, courseId, CFG.raceTimeSeconds or 3, os.clock())
	raceTimeAt = os.clock()
	if Sound then Sound.play("horse_nicker") end
	Ui.pop(card)
end)

-- Drawing ---------------------------------------------------------------------------
local lastPhase = ""
local lastBeep = -1
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local riding = (RaceState.active and RaceState.myLane ~= nil) or player:GetAttribute("Racing") == true
	local picker = player.PlayerGui:FindFirstChild("RacePicker")
	local v = QueueView.view(state, player.UserId, now)
	local show = v.phase ~= "hidden" and not riding and not RaceState.resultsOpen and not (picker and picker.Enabled)
	if gui.Enabled ~= show then gui.Enabled = show end
	if not show then
		lastPhase = v.phase
		return
	end
	local racetime = v.phase == "racetime"
	if v.phase ~= lastPhase then
		lastPhase = v.phase
		card.BackgroundColor3 = if racetime then C.gold else C.paper
		hoofRow.Visible = racetime
		subtitle.Visible = not racetime
		leaveBtn.Visible, moreBtn.Visible = v.showLeave, v.showChoices
		if v.phase == "countdown" or racetime then Ui.pop(card) end
	end
	title.Text = v.title
	title.TextSize = if racetime then 30 else 26
	subtitle.Text = v.subtitle
	-- Ring and number.
	local lit = math.ceil(v.ring * DOTS - 1e-6)
	local wait = v.phase == "waiting" or v.phase == "next"
	local spin = if wait and not reducedMotion() then math.floor(now * 8) % DOTS + 1 else 0
	for k, d in dots do
		local on = if racetime then true elseif wait then true else k <= lit
		d.BackgroundColor3 = if racetime then C.orange elseif wait then (if k == spin then C.orange else C.sky)
			elseif on then C.orange else C.shade
		d.BackgroundTransparency = if on or wait then 0 else 0.4
	end
	bigNum.Text = if racetime then "GO!" elseif v.seconds then tostring(v.seconds) elseif v.phase == "next" then "🏇" else "…"
	bigNum.TextColor3 = if racetime then C.orangeDark elseif v.seconds and v.seconds <= 5 then C.orangeDark else C.ink
	if v.seconds and v.seconds <= 3 and v.seconds ~= lastBeep and v.phase == "countdown" then
		lastBeep = v.seconds
		if Sound then Sound.play("ui_pop") end -- a soft tick on 3, 2, 1
		Ui.pop(ring)
	end
	-- Hoofprints step in one by one, then GO! (all at once under Reduced Motion).
	if racetime then
		local step = if reducedMotion() then #hoofs + 1 else math.floor((now - raceTimeAt) / 0.15) % (#hoofs + 4)
		for k, h in hoofs do h.TextTransparency = if k <= step then 0 else 0.85 end
		goLabel.TextTransparency = if step > #hoofs then 0 else 0.85
	end
	-- Gate slots.
	for k, s in v.slots do
		local ui = slotUi[k]
		if not ui then continue end
		if s.filled then
			ui.frame.BackgroundColor3 = if s.you then C.gold else C.white
			ui.dot.Visible = true
			ui.dot.BackgroundColor3 = Ui.coatColors[s.coat or "bay"] or Ui.coatColors.bay
			ui.name.Text = if s.you then "★ " .. (s.name or "") else (s.name or "")
			ui.name.TextTransparency = 0
			ui.stroke.Transparency = 0
		else
			ui.frame.BackgroundColor3 = C.cream
			ui.dot.Visible = false
			ui.name.Text = if racetime then "🤖 bot" else "open"
			ui.name.TextTransparency = 0.45
			ui.stroke.Transparency = 0.6
		end
	end
end)

-- Your race has started: the card goes, and the gate's own "3, 2, 1, GO!" takes over.
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if player:GetAttribute("Racing") then QueueView.clear(state) end
end)
