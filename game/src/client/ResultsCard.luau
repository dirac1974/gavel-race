--!nonstrict
-- ResultsCard: the race's results card (D-034, D-064; rebuilt in AAA Phase 2, D-067). RaceController
-- fills it and decides when it shows; this module builds it and fits it to the screen.
-- Its own screen over the race HUD and the steering pad, built at the panel floors: 16 px text and
-- 64 px buttons unscaled, scaled down on a small screen no further than PanelFit's floor (so they
-- render at 14 px and 56 px at the least), and scrolled rather than shrunk past it. It sits under
-- the Roblox top bar (GuiService:GetGuiInset) and inside the device's safe area. Top to bottom: the
-- place headline under its ribbon (1st to 4th, D-016 ribbons: Blue, Red, Yellow, White), a kind line
-- for every place (ResultsText.cheer: the ribbon, or praise for the ride; never a near miss), "Best
-- ride in the race!" for the top 3 ride scores only (results.riderRank), "You rode ★★☆", "Your taps
-- gained Comet N places!" only on a gain, the top four and your own place, then 🏁 Race again
-- (results.raceAgain: what RACE! does) and the replay and Done buttons. No shop door, no prompts.
-- AAA Phase 4 (D-069): the stars count in one by one as the card shows (Card.setRide; RacePresent.starSteps),
-- each with a rising tick (finish.starTick); under Reduced Motion they show at once. Ribbon colours from
-- ART_DIRECTION.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PanelFit = require(Shared:WaitForChild("PanelFit"))
local ResultsText = require(Shared:WaitForChild("ResultsText"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local RacePresent = require(Shared:WaitForChild("RacePresent"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

local Card = {}

Card.RIBBONS = { "ribbon_blue", "ribbon_red", "ribbon_yellow", "ribbon_white" }
-- ART_DIRECTION ribbons (D-016): Blue, Red, Yellow, White.
Card.RIBBON_RGB = { Color3.fromHex("2F6FDE"), Color3.fromHex("E0474C"), Color3.fromHex("FFD23F"), Color3.fromHex("FFFFFF") }
Card.INK = Ui.colors.ink
Card.GOOD = Ui.colors.textGood or Ui.colors.teal -- (text colours that pass 4.5:1 on paper)
Card.WARM = Ui.colors.textWarn or Ui.colors.ink
local INK = Card.INK
local CARD_W, PAD, ROW_H = 400, 18, 32
Card.TEXT_PX, Card.BUTTON_PX = 16, 64 -- the card's smallest text and button, unscaled (PanelFit's floors)
local FIN = GameConfig.finish or {}

local gui = Instance.new("ScreenGui")
gui.Name = "RaceResults"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2 -- over the race HUD (0) and the steering pad (1)
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
Card.gui = gui

-- The world behind the card dims a little (finish.dim); under Reduced Motion it fades in instead of
-- the camera's orbit (D-067).
local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Ui.colors.ink -- a warm Ink tint, not black (the feel consult)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.ZIndex = 1
dim.Visible = false
dim.Parent = gui
Card.dim = dim

-- `results` is the scrolling column the card lives in: showing or hiding it shows or hides the card.
local results = Instance.new("ScrollingFrame")
results.Name = "ResultsColumn"
results.AnchorPoint = Vector2.new(0.5, 0)
results.BackgroundTransparency = 1
results.BorderSizePixel = 0
results.ScrollBarThickness = 8
results.ScrollingDirection = Enum.ScrollingDirection.Y
results.ZIndex = 2
results.Visible = false
results.Parent = gui
Card.results = results
local card = Ui.card(results, UDim2.fromOffset(CARD_W, 400), UDim2.new(0.5, 0, 0, 10))
card.AnchorPoint = Vector2.new(0.5, 0)
card.ZIndex = 2
Card.card = card
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
results:GetPropertyChangedSignal("Visible"):Connect(function()
	if not results.Visible then dim.Visible = false end
end)

local function cardText(size: number, colour: Color3?, align: Enum.TextXAlignment?): TextLabel
	return Ui.text(card, "", size, { TextColor3 = colour or INK, TextXAlignment = align or Enum.TextXAlignment.Center, ZIndex = 4 })
end
local headRibbon = Instance.new("ImageLabel")
headRibbon.Size = UDim2.fromOffset(56, 70)
headRibbon.BackgroundTransparency = 1
headRibbon.ScaleType = Enum.ScaleType.Fit
headRibbon.ZIndex = 4
headRibbon.Visible = false
headRibbon.Parent = card
Card.headRibbon = headRibbon
Card.headText = cardText(34, INK, Enum.TextXAlignment.Left)
Card.headText.Font = Enum.Font.GothamBlack
Card.cheerText = cardText(20)
Card.rankText = cardText(20, Card.GOOD)
Card.rankText.Font = Enum.Font.GothamBlack
Card.tripRowLine = cardText(20, Card.GOOD) -- the switch-back only: D-054's "Good trip" row
Card.rideLine = cardText(26, Card.WARM)
Card.rideLine.Font = Enum.Font.GothamBlack
Card.gainLine = cardText(18)
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -2 * PAD, 0, 2)
divider.BackgroundColor3 = INK
divider.BackgroundTransparency = 0.8
divider.BorderSizePixel = 0
divider.ZIndex = 4
divider.Parent = card
Card.rows = {}
for i = 1, 5 do
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromOffset(24, 30)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 4
	icon.Visible = false
	icon.Parent = card
	local text = cardText(18, INK, Enum.TextXAlignment.Left)
	text.TextWrapped = false
	text.TextTruncate = Enum.TextTruncate.AtEnd
	Card.rows[i] = { icon = icon, text = text }
end
-- 🏁 Race again (primary), then ↺ Finish, ↺ Whole race and Done, every one 64 px high.
Card.againBtn = Ui.button(card, ResultsText.raceAgainLabel("race"), UDim2.new(1, -36, 0, 64), UDim2.new(), Ui.colors.orange, 26)
local thirdW = math.floor((CARD_W - 2 * PAD - 2 * 8) / 3)
Card.watchBtn = Ui.button(card, "↺ Finish", UDim2.fromOffset(thirdW, 64), UDim2.new(), Ui.colors.gold, 20)
Card.fullBtn = Ui.button(card, "↺ Whole race", UDim2.fromOffset(thirdW, 64), UDim2.new(), Ui.colors.sky, 18)
Card.doneBtn = Ui.button(card, "Done", UDim2.fromOffset(thirdW, 64), UDim2.new(), Ui.colors.white, 22)
for _, b in { Card.againBtn, Card.watchBtn, Card.fullBtn, Card.doneBtn } do b.ZIndex = 5 end

-- A button ignores taps for a moment after the card shows, so the tap that skipped the finish
-- moment never presses one.
Card.shownAt = -math.huge
function Card.ready(): boolean
	return os.clock() - Card.shownAt >= 0.35
end

local function textHeight(l: TextLabel, width: number): number
	if l.Text == "" then return 0 end
	local ok, size = pcall(function()
		return TextService:GetTextSize(l.Text, l.TextSize, l.Font, Vector2.new(width, 1000))
	end)
	return if ok then math.max(l.TextSize + 6, math.ceil(size.Y) + 4) else l.TextSize + 6
end

local RESULTS = GameConfig.results or {}
local WIDE_W = RESULTS.cardWideW or 720
local height, width = 400, CARD_W

local function view(): (Vector2, number, number)
	local camera = workspace.CurrentCamera
	local v = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local wide = if gui.AbsoluteSize.X > 0 then gui.AbsoluteSize.X else v.X
	local top = GuiService:GetGuiInset().Y + 6 -- under the Roblox top bar
	return v, wide, top
end

-- Fit the card: as big as the screen under the top bar allows, never under the floors, scrolling
-- past them.
function Card.fit()
	local v, wide, top = view()
	local room = math.max(200, v.Y - top)
	local f = PanelFit.layout(wide, room, width, height, Card.TEXT_PX, Card.BUTTON_PX, GameConfig.ui)
	cardScale.Scale = f.scale
	card.Size = UDim2.fromOffset(width, height)
	local scaled = height * f.scale
	results.Position = UDim2.new(0.5, 0, 0, top)
	results.Size = UDim2.new(0, math.min(wide, math.ceil(width * f.scale) + 24), 1, -top)
	results.CanvasSize = UDim2.fromOffset(0, if f.scroll then math.ceil(scaled + PanelFit.MARGIN) else 0)
	results.ScrollingEnabled = f.scroll
	-- A little above the middle of the room under the top bar.
	local y = if f.scroll then PanelFit.MARGIN / 2 else math.floor(math.max(PanelFit.MARGIN / 2, (room - scaled) * 0.4))
	card.Position = UDim2.new(0.5, 0, 0, y)
end

-- Would the card scroll at this size on this screen?
local function scrolls(w: number, h: number): boolean
	local v, wide, top = view()
	return PanelFit.layout(wide, math.max(200, v.Y - top), w, h, Card.TEXT_PX, Card.BUTTON_PX, GameConfig.ui).scroll
end

-- One column of lines from y down, colW wide at x; returns the y under the last.
local function stackLines(x: number, y: number, colW: number): number
	local hasRibbon = headRibbon.Visible
	local head = Card.headText
	head.Visible = head.Text ~= ""
	if head.Visible then
		local hx = if hasRibbon then x + 66 else x
		headRibbon.Position = UDim2.fromOffset(x, y)
		head.TextXAlignment = if hasRibbon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		local h = textHeight(head, colW - (hx - x))
		local rowH = if hasRibbon then math.max(70, h) else h
		head.Size = UDim2.fromOffset(colW - (hx - x), rowH)
		head.Position = UDim2.fromOffset(hx, y)
		y += rowH + 6
	end
	for _, l in { Card.cheerText, Card.rankText, Card.tripRowLine, Card.rideLine, Card.gainLine } do
		local h = textHeight(l, colW)
		l.Visible = h > 0
		if h > 0 then
			l.Size = UDim2.fromOffset(colW, h)
			l.Position = UDim2.fromOffset(x, y)
			y += h + 2
		end
	end
	return y
end
local function stackRows(x: number, y: number, colW: number): number
	for _, r in Card.rows do
		local used = r.text.Text ~= ""
		r.text.Visible = used
		if used then
			r.icon.Position = UDim2.fromOffset(x, y + 1)
			r.text.Size = UDim2.fromOffset(colW - 34, ROW_H)
			r.text.Position = UDim2.fromOffset(x + 34, y)
			y += ROW_H
		else
			r.icon.Visible = false
		end
	end
	return y
end
local function buttonRow(x: number, y: number, colW: number)
	local shown = {}
	for _, b in { Card.watchBtn, Card.fullBtn, Card.doneBtn } do
		if b.Visible then table.insert(shown, b) end
	end
	local w = math.floor((colW - 8 * (#shown - 1)) / math.max(1, #shown))
	for k, b in shown do
		b.Size = UDim2.fromOffset(w, 64)
		b.Position = UDim2.fromOffset(x + (k - 1) * (w + 8), y)
	end
end

-- Place the card's parts top to bottom (only what has something to say takes room), then fit it.
-- One column; or, on a short landscape screen where one column would scroll (results.twoColumnBelowPx,
-- the UI/UX consult), two: the headline, the lines and Race again on the left, the places and the
-- replay and Done buttons on the right, all without scrolling.
function Card.layout()
	local inner = CARD_W - 2 * PAD
	local y = stackLines(PAD, PAD, inner) + 6
	divider.Visible = true
	divider.Size = UDim2.new(1, -2 * PAD, 0, 2)
	divider.Position = UDim2.fromOffset(PAD, y)
	y = stackRows(PAD, y + 10, inner) + 12
	if Card.againBtn.Visible then
		Card.againBtn.Size = UDim2.new(1, -36, 0, 64)
		Card.againBtn.Position = UDim2.fromOffset(PAD, y)
		y += 64 + 8
	end
	buttonRow(PAD, y, inner)
	height, width = y + 64 + PAD, CARD_W
	local v = select(1, view())
	if v.X > v.Y and v.Y < (RESULTS.twoColumnBelowPx or 0) and scrolls(width, height) then
		local colW = math.floor((WIDE_W - 3 * PAD) / 2)
		local left = stackLines(PAD, PAD, colW) + 8
		if Card.againBtn.Visible then
			Card.againBtn.Size = UDim2.fromOffset(colW, 64)
			Card.againBtn.Position = UDim2.fromOffset(PAD, left)
			left += 64
		end
		local rx = 2 * PAD + colW
		divider.Size = UDim2.fromOffset(2, 0)
		divider.Visible = false
		local right = stackRows(rx, PAD, colW) + 12
		buttonRow(rx, right, colW)
		right += 64
		height, width = math.max(left, right) + PAD, WIDE_W
		-- Race again and the buttons share one bottom line.
		local bottom = height - PAD - 64
		if Card.againBtn.Visible then Card.againBtn.Position = UDim2.fromOffset(PAD, bottom) end
		buttonRow(rx, bottom, colW)
	end
	Card.fit()
end

-- Your stars (AAA Phase 4, D-069): "You rode ☆☆☆" fills one star at a time as the card shows, each
-- with a tick a little higher (RacePresent.starSteps). setRide(n) sets the stars the line ends on (nil:
-- no line); a report that comes while the card is up starts the count then. A count that is cut off
-- (the card closed, a replay) lands on its last star at once and silently.
local ride = { stars = nil :: number?, done = true, token = 0, still = false }
local function countStars()
	ride.token += 1
	local token, n = ride.token, ride.stars
	if n == nil then
		Card.rideLine.Text, ride.done = "", true
		return
	end
	local final = ResultsText.rideLine(n)
	local steps = RacePresent.starSteps(FIN, n, ride.still)
	if #steps == 0 then
		Card.rideLine.Text, ride.done = final, true
		return
	end
	ride.done = false
	Card.rideLine.Text = ResultsText.rideLine(0)
	for k, step in steps do
		task.delay(step.at, function()
			if token ~= ride.token or ride.done then return end
			if not results.Visible then -- cut off: the last star at once, no ticks
				Card.rideLine.Text, ride.done = final, true
				return
			end
			Card.rideLine.Text = ResultsText.rideLine(step.stars)
			if Sound then Sound.play(FIN.starTick or "count_tick", FIN.starTickVolume or 0.8, nil, step.speed) end
			if k == #steps then ride.done = true end
		end)
	end
end
function Card.setRide(stars: number?)
	local changed = stars ~= ride.stars
	ride.stars = stars
	if stars == nil then
		ride.token += 1
		Card.rideLine.Text, ride.done = "", true
	elseif results.Visible then
		if changed then countStars() end -- the report came (or changed) while the card is up
	else
		Card.rideLine.Text = ResultsText.rideLine(stars) -- (its room in the layout; Card.show counts it in)
	end
end

-- Show it: the world dims (if it hasn't for the finish moment) and the card rises in (Reduced
-- Motion: it just shows). The stars count in.
function Card.show(still: boolean)
	results.Visible = true
	Card.shownAt = os.clock()
	ride.still = still
	countStars()
	if not still then
		local to = card.Position
		card.Position = to + UDim2.fromOffset(0, 30)
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = to }):Play()
	end
	Card.dimIn()
end

-- The dim behind the card fades in over finish.fadeSeconds (the Reduced Motion fade, D-067).
function Card.dimIn()
	if dim.Visible then return end
	dim.BackgroundTransparency = 1
	dim.Visible = true
	TweenService:Create(dim, TweenInfo.new(FIN.fadeSeconds or 0.4), { BackgroundTransparency = FIN.dim or 0.55 }):Play()
end

-- "🌾 Feed Comet" (results.feedWhenNapping): the guide to your stall, as the Next-thing pill's GO does.
Card.againKind = "race"
function Card.goStable()
	local i = Players.LocalPlayer:GetAttribute("PlotIndex")
	if i then
		local x, z = WorldLayout.plotPoint(i, 40, 0)
		Guide.to(x, z)
	end
end

return Card
