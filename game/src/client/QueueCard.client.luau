--!nonstrict
-- QueueCard (D-061 stage 2): while you're in line, a card at the top of the screen shows the
-- wait so kids can see it: a countdown ring with the seconds in big numbers, the gate's 8 slots
-- filling with each rider's horse name and coat dot (yours in gold), and "🤖 Bots join at 0".
-- You can groom, ride or visit while it's up. When the gate fills, "Race time!" with hoofprints
-- stepping to GO, and the server brings you to the gate. ✕ leaves the line; "More" opens the
-- race picker (pick a horse, Practice, Cup). What it shows comes from QueueView (Lune-tested).
-- Phone screen budget (AAA Phase 2, D-067):
--   The card takes the top-centre spot through Ui.slot (the tour outranks it; its "Race time!"
--   outranks the tour), placed clear of the 💎 pill and the ⚙️.
--   On a phone (queueCard.compactPhone) it is one 64 px row: the seconds, "Race in 12 · 3 riders"
--   and ✕, so the world (and your horse) stays in view. Tap the row to see the gate and More.
--   For a player's first queueCard.warmUpRaces races the row has a "Warm up" button: a practice
--   slider in place of the gate. It counts nothing and sends nothing to the server.
--   Nothing here is ever scaled under the floors (14 px text, 56 px buttons).
-- Find it (D-075): the card names your line and why ("🟠 Bronze race line · Horses like Comet race
-- here"; QueueView.lineTitle / lineWhy from the server's LineKey and LineHorse), and the phone row
-- reads "🟠 Bronze line · 3 riders". A ❓ opens the "how racing works" strip (HowRacing), which also
-- shows by itself the first time you're in line.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local QueueView = require(Shared:WaitForChild("QueueView"))
local DockLayout = require(Shared:WaitForChild("DockLayout"))
local PanelFit = require(Shared:WaitForChild("PanelFit"))
local PaceMeter = require(Shared:WaitForChild("PaceMeter"))
local HowRacing = require(script.Parent:WaitForChild("HowRacing"))
local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local CFG = GameConfig.queueCard or {}
if CFG.enabled == false then return end
local SLOTP = GameConfig.topSlot or { queueCard = 20, raceTime = 40 }

local player = Players.LocalPlayer
local C = Ui.colors
local state = QueueView.new(GameConfig.lanes, GameConfig.lobbyFillSeconds)
local BTN = GameConfig.ui.minTouchPx

local function reducedMotion(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

-- Layout (unscaled px). The full card's smallest text is 16 px and its smallest button 64 px, so
-- its shrink floor (PanelFit.floor) keeps them at 14 and 56 rendered.
local W, H = 672, 178
local RING, DOTS = 104, 20
local SLOT_W, SLOT_H, GAP = 110, 38, 6
local MIN_SCALE = PanelFit.floor(16, 64, GameConfig.ui)
local ROW_H = CFG.compactHeight or 64 -- the compact phone row
local EXTRA_H = 2 * SLOT_H + GAP + 16  -- the compact card opened: the gate (or the warm-up) under the row

local gui = Ui.screen("QueueCard", 12) -- above the care card and the picker (11): visible while grooming
gui.Enabled = false
local card = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + 8), C.paper)
card.AnchorPoint = Vector2.new(0.5, 0)
local scale = Instance.new("UIScale")
scale.Parent = card
local wantTop = Ui.slot("queueCard", SLOTP.queueCard or 20, card)

-- Full card ---------------------------------------------------------------------------------
local full = Instance.new("Frame")
full.Name = "Full"
full.BackgroundTransparency = 1
full.Size = UDim2.fromScale(1, 1)
full.Parent = card

-- The countdown ring: DOTS dots round a circle; lit dots are the time left.
local ring = Instance.new("Frame")
ring.BackgroundTransparency = 1
ring.Size = UDim2.fromOffset(RING, RING)
ring.Position = UDim2.fromOffset(10, (H - RING) / 2 - 2)
ring.Parent = full
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
local right = 10 + 64 + 10 -- the button column
local HELP = 64 -- the ❓ beside the ✕ (the card's 64 px button floor: it shrinks to 0.875 at most)
local title = Ui.text(full, "", 26, { Position = UDim2.fromOffset(left, 6), Size = UDim2.new(1, -(left + right + HELP + 8), 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
-- Which line, and why (D-075): "🟠 Bronze race line", then "Horses like Comet race here".
local lineName = Ui.text(full, "", 18, { Position = UDim2.fromOffset(left, 36), Size = UDim2.new(1, -(left + right + HELP + 8), 0, 22),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
local subtitle = Ui.text(full, "", 16, { Position = UDim2.fromOffset(left, 60), Size = UDim2.new(1, -(left + right + HELP + 8), 0, 20),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
subtitle.TextColor3 = C.plum

-- "Race time!" hoofprints: they step across the subtitle line to GO.
local hoofRow = Instance.new("Frame")
hoofRow.BackgroundTransparency = 1
hoofRow.Size = UDim2.new(1, -(left + right), 0, 24)
hoofRow.Position = UDim2.fromOffset(left, 58)
hoofRow.Visible = false
hoofRow.Parent = full
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
goLabel.TextColor3 = C.textWarn

-- The gate: two rows of four slots (lane order), each a coat dot and the horse's name.
local gate = Instance.new("Frame")
gate.BackgroundTransparency = 1
gate.Position = UDim2.fromOffset(left, 84)
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
local leaveBtn = Ui.closeButton(card, UDim2.new(1, -74, 0, 8), 64)
local moreBtn = Ui.button(card, "", UDim2.fromOffset(64, 72), UDim2.new(1, -74, 0, 78), C.sky, 16)
Ui.text(moreBtn, "🔀", 24, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 6) })
Ui.text(moreBtn, "More", 16, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -28) })
leaveBtn.Activated:Connect(function()
	raceRemotes:WaitForChild("JoinRace"):FireServer(false)
end)
moreBtn.Activated:Connect(function()
	local events = ReplicatedStorage:FindFirstChild("HudEvents")
	local open = events and events:FindFirstChild("OpenRacePicker")
	if open then open:Fire() end
end)
-- ❓ how racing works (D-075): three pictures, any time.
local helpBtn = Ui.button(card, "❓", UDim2.fromOffset(HELP, HELP), UDim2.new(1, -74 - HELP - 8, 0, 12), C.white, 26)
helpBtn.ZIndex = 3
helpBtn.Activated:Connect(function() HowRacing.open() end)

-- Compact phone row ----------------------------------------------------------------------------
local row = Instance.new("Frame")
row.Name = "CompactRow"
row.BackgroundTransparency = 1
row.Size = UDim2.new(1, 0, 0, ROW_H)
row.Visible = false
row.Parent = card
local secs = Instance.new("Frame")
secs.Size = UDim2.fromOffset(ROW_H - 12, ROW_H - 12)
secs.Position = UDim2.fromOffset(8, 6)
secs.BackgroundColor3 = C.cream
secs.BorderSizePixel = 0
Ui.corner(secs, (ROW_H - 12) // 2)
local secsStroke = Ui.stroke(secs, 3, C.orange)
secs.Parent = row
local secsText = Ui.text(secs, "", 24, { Size = UDim2.fromScale(1, 1), TextWrapped = false })
local line = Ui.text(row, "", 20, { Position = UDim2.fromOffset(ROW_H + 2, 0), Size = UDim2.new(1, -(ROW_H + 2) - 72 - 70, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
-- Tap the row to open or close the gate (the ✕ and Warm up sit on top of it).
local rowHit = Instance.new("TextButton")
rowHit.Name = "OpenGate"
rowHit.BackgroundTransparency = 1
rowHit.Text = ""
rowHit.Size = UDim2.new(1, -72 - 70, 1, 0)
rowHit.ZIndex = 2
rowHit.Parent = row
local warmBtn = Ui.button(row, "🎯 Warm up", UDim2.fromOffset(132, BTN), UDim2.new(1, -72 - 70 - 140, 0.5, -BTN / 2), C.gold, 18)
warmBtn.ZIndex = 3
warmBtn.Visible = false

-- Warm-up slider (in place of the gate): the race's own marker and glow, for practice only. -------
local warm = Instance.new("Frame")
warm.Name = "WarmUp"
warm.BackgroundTransparency = 1
warm.Visible = false
warm.Parent = card
local warmBar = Instance.new("TextButton") -- tap the bar itself (a big target)
warmBar.Name = "WarmBar"
warmBar.Text = ""
warmBar.AutoButtonColor = false
warmBar.BackgroundColor3 = C.cream
warmBar.Size = UDim2.new(1, -132, 0, 64)
warmBar.Position = UDim2.fromOffset(0, 0)
Ui.corner(warmBar, 14)
Ui.stroke(warmBar, 3)
warmBar.Parent = warm
local glow = Instance.new("Frame")
glow.AnchorPoint = Vector2.new(0.5, 0)
glow.Size = UDim2.new(0.16, 0, 1, -10)
glow.Position = UDim2.new(0.5, 0, 0, 5)
glow.BackgroundColor3 = C.gold -- a fill, like the race's Gold glow (D-069)
glow.BackgroundTransparency = 0.25
glow.BorderSizePixel = 0
Ui.corner(glow, 10)
glow.Parent = warmBar
local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0)
marker.Size = UDim2.new(0, 8, 1, 4)
marker.Position = UDim2.new(0, 0, 0, -2)
marker.BackgroundColor3 = C.ink
marker.BorderSizePixel = 0
Ui.corner(marker, 4)
marker.Parent = warmBar
local warmWord = Ui.text(warm, "Tap on the glow!", 18, { Position = UDim2.new(1, -124, 0, 0), Size = UDim2.new(0, 124, 0, 40) })
local warmNote = Ui.text(warm, "Just practice", 16, { Position = UDim2.new(1, -124, 0, 40), Size = UDim2.new(0, 124, 0, 24) })
warmNote.TextColor3 = C.plum

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

-- Modes -------------------------------------------------------------------------------------
local compact = false    -- the phone row
local opened = false     -- the phone row tapped open (the gate or the warm-up shows under it)
local warming = false    -- the warm-up slider is up
local function phone(): boolean
	local cam = workspace.CurrentCamera
	if not cam or CFG.compactPhone == false then return false end
	return DockLayout.isPhone(Ui.touchLayout(), cam.ViewportSize.X, cam.ViewportSize.Y, GameConfig.ui)
end
local function warmUpOffered(): boolean
	if CFG.warmUp == false then return false end
	local d = PlayerState.data
	local races = (d and d.totals and tonumber(d.totals.races)) or 0
	return races < (CFG.warmUpRaces or 3)
end

-- Places the gate (or the warm-up) and sizes the card for the mode and width.
local function arrange(width: number)
	full.Visible = not compact
	row.Visible = compact
	if compact then
		local inner = width - 16
		local cell = math.floor((inner - 72 - 3 * GAP) / 4)
		grid.CellSize = UDim2.fromOffset(math.max(80, cell), SLOT_H)
		gate.Position = UDim2.fromOffset(8, ROW_H + 4)
		gate.Size = UDim2.fromOffset(inner - 72, 2 * SLOT_H + GAP)
		moreBtn.Position = UDim2.new(1, -72, 0, ROW_H + 4)
		leaveBtn.Size = UDim2.fromOffset(BTN, BTN)
		leaveBtn.Position = UDim2.new(1, -BTN - 8, 0, (ROW_H - BTN) // 2)
		helpBtn.Position = UDim2.new(1, -BTN - 8 - HELP - 6, 0, (ROW_H - HELP) // 2)
		warm.Position = UDim2.fromOffset(8, ROW_H + 4)
		warm.Size = UDim2.new(1, -16, 0, 64)
		gate.Visible = opened and not warming
		warm.Visible = opened and warming
		moreBtn.Visible = opened and not warming and moreBtn.Visible
		card.Size = UDim2.fromOffset(width, ROW_H + (if opened then EXTRA_H else 0))
	else
		grid.CellSize = UDim2.fromOffset(SLOT_W, SLOT_H)
		gate.Position = UDim2.fromOffset(left, 84)
		gate.Size = UDim2.fromOffset(4 * SLOT_W + 3 * GAP, 2 * SLOT_H + GAP)
		moreBtn.Position = UDim2.new(1, -74, 0, 78)
		leaveBtn.Size = UDim2.fromOffset(64, 64)
		leaveBtn.Position = UDim2.new(1, -74, 0, 8)
		helpBtn.Position = UDim2.new(1, -74 - HELP - 8, 0, 12)
		-- the warm-up (desktop and tablet): in place of the gate, under the title
		warm.Position = UDim2.fromOffset(left, 92)
		warm.Size = UDim2.new(1, -(left + right), 0, 64)
		gate.Visible = not warming
		warm.Visible = warming
		card.Size = UDim2.fromOffset(W, H)
	end
end

rowHit.Activated:Connect(function()
	opened = not opened
	if not opened then warming = false end
end)
warmBtn.Activated:Connect(function()
	if warming then
		warming, opened = false, false
	else
		warming, opened = true, true
	end
end)

-- The practice slider: the race's own pass schedule (PaceMeter) on a local, throwaway random.
local warmPasses, warmT0 = nil, 0
local function warmSpec()
	local h = PlayerState.activeHorse()
	local league = GameConfig.leagues[(h and h.league) or "Rookie"] or GameConfig.leagues.Rookie
	local p = GameConfig.pace
	return { sweepSeconds = league.sweepSeconds, speedDrift = p.speedDrift, shiftMin = p.shiftMin, shiftMax = p.shiftMax,
		centerRange = p.centerRange }
end
local function warmPass(now: number)
	if not warmPasses or now - warmT0 > 290 then
		warmT0 = now
		warmPasses = PaceMeter.schedule(Random.new(), now, 300, warmSpec())
	end
	local k = PaceMeter.passIndex(warmPasses, now)
	return k and warmPasses[k]
end
local lastWarmTap = 0
warmBar.MouseButton1Down:Connect(function()
	local now = os.clock()
	if now - lastWarmTap < (GameConfig.pace.bounceSeconds or 0.15) then return end -- a finger bounce
	lastWarmTap = now
	local p = warmPass(now)
	if not p then return end
	local score = PaceMeter.tapScore(p, now)
	-- Nothing here is sent anywhere: it is practice on your own screen.
	warmWord.Text = QueueView.warmWord(score, now < PaceMeter.idealTime(p))
	warmWord.TextColor3 = if score >= 80 then C.textGood else C.ink
	if not reducedMotion() then Ui.pop(warmWord) end
	-- (D-069, the UI/UX consult) The race's own tap tick, pitched by the word, so practice sounds like the race.
	local FX = GameConfig.raceFx
	if Sound then Sound.play("tap_ok", FX.tickVolume, nil, (FX.tickSpeeds or {})[GameConfig.labelFor(score)] or 1) end
end)

-- Drawing ---------------------------------------------------------------------------
local lastPhase = ""
local lastBeep = -1
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local riding = (RaceState.active and RaceState.myLane ~= nil) or player:GetAttribute("Racing") == true
	local picker = player.PlayerGui:FindFirstChild("RacePicker")
	local v = QueueView.view(state, player.UserId, now)
	local racetime = v.phase == "racetime"
	local wants = v.phase ~= "hidden" and not riding and not RaceState.resultsOpen and not (picker and picker.Enabled)
	-- The top-centre spot (Ui.slot): "Race time!" outranks the tour; otherwise the tour goes first.
	local show = wantTop(wants, if racetime then (SLOTP.raceTime or 40) else (SLOTP.queueCard or 20))
	if gui.Enabled ~= show then gui.Enabled = show end
	Ui.queueLeaveShown = show and v.showLeave -- (D-069) the dock hides its own leave ✕ while this one shows
	if not show then
		lastPhase = v.phase
		if v.phase == "hidden" then opened, warming = false, false end
		return
	end
	-- Mode and place.
	compact = phone()
	local cx, width, top = Ui.topSlotPlace(if compact then 560 else W)
	if racetime and warming then warming = false end
	local offerWarm = warmUpOffered() and not racetime
	if not offerWarm then warming = false end
	warmBtn.Visible = compact and offerWarm
	if warmBtn.Visible then warmBtn.Text = if warming then "🎯 Done" else "🎯 Warm up" end
	line.Size = UDim2.new(1, -(ROW_H + 2) - 72 - 70 - (if warmBtn.Visible then 140 else 0), 1, 0)
	if compact then
		scale.Scale = 1 -- the row is built at the floors: never shrunk
	else
		scale.Scale = math.clamp(width / W, MIN_SCALE, 1)
	end
	card.Position = UDim2.fromOffset(cx, top)
	if v.phase ~= lastPhase then
		lastPhase = v.phase
		card.BackgroundColor3 = if racetime then C.gold else C.paper
		hoofRow.Visible = racetime
		subtitle.Visible = not racetime
		leaveBtn.Visible, moreBtn.Visible = v.showLeave, v.showChoices
		if v.phase == "countdown" or racetime then Ui.pop(card) end
	end
	moreBtn.Visible = v.showChoices
	arrange(if compact then width else W)
	title.Text = v.title
	title.TextSize = if racetime then 30 else 26
	-- (D-075) row 2 names the line, row 3 says why; the open gate slots say "🤖 at 0" in its place.
	local key = player:GetAttribute("LineKey")
	local why = QueueView.lineWhy(key, player:GetAttribute("LineHorse"), (GameConfig.queue or {}).practiceEqualHorses == true)
	lineName.Text = QueueView.lineTitle(key)
	lineName.Visible = not racetime
	subtitle.Text = if warming and not compact then "Practice taps: they don't count" elseif why ~= "" then why else v.subtitle
	local short = QueueView.lineShort(key)
	line.Text = if short ~= "" then QueueView.compactLine(v, short) else QueueView.compactLine(v)
	helpBtn.Visible = not racetime
	if v.showLeave then HowRacing.maybeAuto() end -- the first time in line, once
	secsText.Text = if racetime then "GO" elseif v.seconds then tostring(v.seconds) else "🏇"
	secsStroke.Color = if v.seconds and v.seconds <= 5 then C.orangeDark else C.orange
	secsText.TextColor3 = if v.seconds and v.seconds <= 5 then C.textWarn else C.ink
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
	bigNum.TextColor3 = if racetime then C.textWarn elseif v.seconds and v.seconds <= 5 then C.textWarn else C.ink
	if v.seconds and v.seconds <= 3 and v.seconds ~= lastBeep and v.phase == "countdown" then
		lastBeep = v.seconds
		if Sound then Sound.play("ui_pop") end -- a soft tick on 3, 2, 1
		Ui.pop(if compact then secs else ring)
	end
	-- Hoofprints step in one by one, then GO! (all at once under Reduced Motion).
	if racetime then
		local step = if reducedMotion() then #hoofs + 1 else math.floor((now - raceTimeAt) / 0.15) % (#hoofs + 4)
		for k, h in hoofs do h.TextTransparency = if k <= step then 0 else 0.85 end
		goLabel.TextTransparency = if step > #hoofs then 0 else 0.85
	end
	-- The warm-up marker and glow.
	if warming then
		local p = warmPass(now)
		if p then
			marker.Position = UDim2.new((PaceMeter.position(p, now) + 1) / 2, 0, 0, -2)
			glow.Position = UDim2.new((p.center + 1) / 2, 0, 0, 5)
		end
	end
	-- Gate slots.
	for k, s in v.slots do
		local ui = slotUi[k]
		if not ui then continue end
		if s.filled then
			ui.frame.BackgroundColor3 = if s.you then C.gold else C.white
			ui.dot.Visible = true
			ui.dot.BackgroundColor3 = Ui.coatColors[s.coat or "bay"] or Ui.coatColors.bay
			ui.name.Text = if s.you then "▶ " .. (s.name or "") else (s.name or "")
			ui.name.TextTransparency = 0
			ui.stroke.Transparency = 0
		else
			ui.frame.BackgroundColor3 = C.cream
			ui.dot.Visible = false
			ui.name.Text = if racetime then "🤖 bot" elseif v.phase == "countdown" then "🤖 at 0" else "open"
			ui.name.TextTransparency = 0.45
			ui.stroke.Transparency = 0.6
		end
	end
end)

-- Your race has started: the card goes, and the gate's own "3, 2, 1, GO!" takes over.
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if player:GetAttribute("Racing") then
		QueueView.clear(state)
		opened, warming = false, false
	end
end)
