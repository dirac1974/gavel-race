--!nonstrict
-- RaceController: prototype race UI (D-026).
-- Riders see the race in a close chase view behind their horse (scroll or pinch in for
-- first person from the saddle). The pace slider runs the whole race with no pauses: tap when the marker
-- crosses the glowing target, one tap per pass; distance from the target sets the score
-- and the speed meter fills from your last few passes. The target moves every 2-3 passes.
-- In the homestretch comes the Final Burst: one tap on a big, colourful meter that counts
-- double. Tap anywhere (counted as the finger goes down), Space or Enter, or gamepad A or R2
-- (GameConfig.tapKeys, D-055); a finger bounce within 0.15 s is ignored. "3, 2, 1" counts down
-- over the gate. Steering (D-054): ◀ In / Out ▶ buttons, A/D or the arrows, the D-pad or a
-- left-stick flick change lanes from the gate to the far-turn lock; none of them taps. Drawn from the shared server clock; all scoring happens on the server (this
-- screen only predicts it for feedback).
-- Race feel (D-066, GameConfig.raceFx): every counted tap ticks (pitched by its score) and its word
-- pops; a Perfect surges your horse (RaceView) and widens the view a little. RaceCamera owns the
-- camera kicks: one budget (raceFx.fovMaxDeg), none under Reduced Motion. The Final Burst arms
-- burstArmSeconds after it opens: its bar stays grey and taps are ignored until then. The bar
-- under the slider is "RIDING" (it never was speed), and on a phone with the ◀ ▶ pad the slider
-- sits right of the pad; the tap words step below the burst bar while it's up.
-- AAA Phase 2 (D-067): the finish moment as your horse crosses (FinishMoment: the orbit to the
-- replay's side view, confetti for 1st, the ribbon stamp for 1st to 4th; skippable, the card up
-- within finish.cardWithinSeconds of the line), the results card (ResultsCard, at the floors, with
-- 🏁 Race again and "Best ride in the race!" for the top 3 only), first-race coaching (the rule, the
-- ghost thumb over the green, "NOW!") and every tap's word at the marker. The status line uses the
-- picker's words ("🐇 Short", never "Sprint").
-- AAA Phase 4 (D-069): the HUD in the art direction's colours (RaceHudStyle: Paper panels, Ink outlines, a
-- Gold glow on Slate) and a smaller, lower YOU marker in your chase view; the gate line-up camera pass in
-- the countdown (GateIntro, riders only); the music bed (MusicBed); the card's stars count in (ResultsCard).
-- Placeholder shapes show until the uploaded atlas art arrives (UiArt).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BurstMeter = require(Shared:WaitForChild("BurstMeter"))
local PaceMeter = require(Shared:WaitForChild("PaceMeter"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ThemePack = require(Shared:WaitForChild("ThemePack"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local RaceInput = require(Shared:WaitForChild("RaceInput"))
local ResultsText = require(Shared:WaitForChild("ResultsText"))
local ReplayTrip = require(Shared:WaitForChild("ReplayTrip"))
local SteerHud = require(Shared:WaitForChild("SteerHud"))
local SteerChips = require(Shared:WaitForChild("SteerChips"))
local RaceFx = require(Shared:WaitForChild("RaceFx"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))
local PickerText = require(Shared:WaitForChild("PickerText"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Sound = (function()
	local ok, module = pcall(require, script.Parent:WaitForChild("Sound", 5))
	return if ok then module else nil
end)()

local player = game:GetService("Players").LocalPlayer
local myId = tostring(player.UserId)
local HUD = GameConfig.hud
local BOUNCE = GameConfig.pace.bounceSeconds or 0
local STEER, SHUD = GameConfig.steering, GameConfig.steerHud
local FX = GameConfig.raceFx
local ARM = GameConfig.burstArmSeconds or 0
local BURST_HINT = "One big tap in the glow. It counts double!"

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Race sounds (Sound.luau) on the shared clock. Each race the HUD follows gets a new cueRace,
-- and a newer or stopped race cancels pending cues. Riders always hear their own race;
-- spectators hear it at half volume, and only near that race's course. Only riders hear
-- their own hoofbeats, and only while they're in the saddle.
local cueRace = 0
local cueTo = { volume = 1, rider = false, course = "dirt" } -- who hears this race's cues
local nearCourse = RaceState.nearCourse -- within GameConfig.spectate.rangeStuds (D-052, D-055)
local function cue(at: number, ...)
	if not Sound then return end
	local id, names, volume, rider, course = cueRace, { ... }, cueTo.volume, cueTo.rider, cueTo.course
	task.delay(math.max(0, at - serverNow()), function()
		if id ~= cueRace then return end
		if not rider and not nearCourse(course) then return end
		for _, name in names do Sound.play(name, volume) end
	end)
end
local stopGallop = nil
local gallopDucked = false
-- (D-066) Hoofbeats at the legs' cadence (race speed over the gallop stride, against the loop's own
-- rate), ducked under the tap tick while the slider runs (raceFx.gallopDuck; the loop restarts at
-- the new level, only as the slider starts or pauses).
local function gallop(on: boolean, ducked: boolean?)
	if stopGallop then stopGallop() end
	local rate = GameConfig.raceSpeedStudsPerSecond / HorseLegs.GAITS.gallop.stride / (FX.gallopLoopStridesPerSecond or 2)
	gallopDucked = ducked == true
	local volume = if gallopDucked and FX.enabled then FX.gallopDuck else nil
	stopGallop = if on and Sound then Sound.loop("gallop_loop", volume, rate) else nil
end
local function seated(): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end
player.CharacterAdded:Connect(function() gallop(false) end) -- a new character isn't in the saddle

-- Reduced Motion, read once and then on change (it's checked every frame).
local still = false
local function readStill()
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	still = ok and on == true
end
readStill()
pcall(function() GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(readStill) end)
local function reducedMotion(): boolean
	return still
end

-- While riding, a jump would throw you out of the saddle, and Space is also a tap key. The move
-- controls are off too (D-054): A/D and the arrows steer the race horse instead of walking, and
-- the touch thumbstick and jump button leave the screen to the ◀ ▶ buttons.
local moveControls = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and module then moveControls = module:GetControls() end
end)
local function setJumping(enabled: boolean)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled) end
	if moveControls then
		pcall(function()
			if enabled then moveControls:Enable() else moveControls:Disable() end
		end)
	end
end

-- The riding camera and the camera kicks (D-026, D-066): RaceCamera owns both (one budget,
-- raceFx.fovMaxDeg; none under Reduced Motion).
local Cam = require(script.Parent:WaitForChild("RaceCamera"))

-- Off the race horse for any reason (Done, the timeout, the next race on the course rebuilding
-- its horses): the normal camera and jumping come back straight away.
local function watchSeat(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local function restore()
		if humanoid.SeatPart == nil and Cam.on then
			Cam.ride(false)
			setJumping(true)
		end
	end
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		if humanoid.SeatPart ~= nil or not Cam.on then return end
		local replay = player.PlayerGui:FindFirstChild("ReplayUI")
		if replay and replay.Enabled then
			RaceState.ReplayClosed.Event:Once(restore) -- the replay owns the camera until it closes
		else
			restore()
		end
	end)
end
if player.Character then task.spawn(watchSeat, player.Character) end
player.CharacterAdded:Connect(function(character)
	if Cam.on then Cam.ride(false) end -- a new character starts on foot
	setJumping(true) -- ...never in a race saddle: the move controls come back (Disable outlives a respawn)
	task.spawn(watchSeat, character)
end)

-- UI construction -----------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RaceUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, size, pos, text, textSize)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize or 18
	l.Text = text or ""
	l.ZIndex = 5
	l.Parent = parent
	return l
end

local function round(frame, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0.5, 0)
	c.Parent = frame
	return c
end

-- Tap anywhere: a transparent full-screen button under the rest of the UI.
local tapArea = Instance.new("TextButton")
tapArea.Size = UDim2.fromScale(1, 1)
tapArea.BackgroundTransparency = 1
tapArea.Text = ""
tapArea.AutoButtonColor = false
tapArea.ZIndex = 1
tapArea.Visible = false
tapArea.Parent = gui

local status = label(gui, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 40), "", 24)

local board = Instance.new("Frame")
board.Size = UDim2.new(0, 300, 0, 8 * 26 + 10)
board.Position = UDim2.new(0, 12, 0, 90)
board.BackgroundColor3 = Color3.fromHex("FFF7E6") -- Paper (RaceHudStyle)
board.BackgroundTransparency = 0
board.ZIndex = 4
board.Visible = false
board.Parent = gui
local boardScale = Instance.new("UIScale")
boardScale.Parent = board
local rows, rowBadges = {}, {}
for i = 1, 8 do
	local row = label(board, UDim2.new(1, -40, 0, 24), UDim2.new(0, 34, 0, 5 + (i - 1) * 26), "", 16)
	row.TextXAlignment = Enum.TextXAlignment.Left
	rows[i] = row
	local b = Instance.new("ImageLabel")
	b.Size = UDim2.fromOffset(24, 24)
	b.Position = UDim2.new(0, 6, 0, 5 + (i - 1) * 26)
	b.BackgroundTransparency = 1
	b.ZIndex = 5
	b.Visible = false
	b.Parent = board
	rowBadges[i] = b
end

local feedback = label(gui, UDim2.new(1, 0, 0, 46), UDim2.new(0, 0, 0.62, 0), "", 32)
local hint = label(gui, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0.68, 0), "", 20)
-- The tap word pops in (D-066): from labelPopScale back to 1, with its shape above it. Under
-- Reduced Motion the word just shows.
local feedbackScale = Instance.new("UIScale")
feedbackScale.Parent = feedback
local popTween: Tween? = nil
local function popFeedback()
	if popTween then popTween:Cancel() end
	feedbackScale.Scale = 1
	if not (FX.enabled and FX.labelPop) or reducedMotion() then return end
	feedbackScale.Scale = FX.labelPopScale
	popTween = TweenService:Create(feedbackScale, TweenInfo.new(FX.labelPopSeconds, Enum.EasingStyle.Back), { Scale = 1 })
	popTween:Play()
end

-- A slider (bar, glowing target, marker). The pace meter and the Final Burst share the build;
-- the burst is bigger and rainbow-coloured to show it matters most.
local function makeMeter(widthScale: number, height: number, y: number, rainbow: boolean)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Size = UDim2.new(widthScale, 0, 0, height)
	bar.Position = UDim2.new(0.5, 0, y, 0)
	bar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bar.ZIndex = 3
	bar.Visible = false
	bar.Parent = gui
	round(bar, UDim.new(0, height / 2))
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if rainbow then 6 else 3
	stroke.Color = if rainbow then Color3.fromHex("FFD34D") else Color3.fromHex("1F2430")
	stroke.Parent = bar
	local g = nil
	if rainbow then
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("FF5A5F")), ColorSequenceKeypoint.new(0.25, Color3.fromHex("FFB347")),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFF06A")), ColorSequenceKeypoint.new(0.75, Color3.fromHex("6BD66B")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("5AA9FF")),
		})
		g.Parent = bar
	else
		UiArt.attach(bar, "burst_bar", 3, function() bar.BackgroundTransparency = 1 end)
	end
	local zone = Instance.new("Frame")
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Size = UDim2.new(0.2, 0, 1, 0)
	zone.BackgroundColor3 = if rainbow then Color3.new(1, 1, 1) else Color3.fromHex("FFD23F") -- the Gold glow
	zone.BackgroundTransparency = if rainbow then 0.25 else 0
	zone.BorderSizePixel = 0
	zone.ZIndex = 4
	zone.Parent = bar
	if not rainbow then UiArt.attach(zone, "burst_glow", 4, function() zone.BackgroundTransparency = 1 end) end
	local zone2 = zone:Clone()
	zone2.Visible = false
	zone2.Parent = bar
	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Size = UDim2.new(0, if rainbow then 14 else 8, 1.6, 0)
	marker.Position = UDim2.new(0, 0, 0.5, 0)
	marker.BackgroundColor3 = Color3.new(1, 1, 1)
	marker.ZIndex = 6
	marker.Parent = bar
	local mStroke = Instance.new("UIStroke")
	mStroke.Thickness = 2
	mStroke.Color = Color3.fromHex("1F2430")
	mStroke.Parent = marker
	return { bar = bar, zone = zone, zone2 = zone2, marker = marker, stroke = stroke, gradient = g }
end

local pace = makeMeter(0.7, 34, 0.80, false)
local burst = makeMeter(0.9, 72, 0.44, true)
-- The tap's word at the marker and first-race coaching (D-067): RaceCoach draws both on this slider.
local Coach = require(script.Parent:WaitForChild("RaceCoach"))
Coach.attach(pace)
-- "3, 2, 1, GO!" over the gate (D-055): big for riders, smaller for spectators.
local countLabel = label(gui, UDim2.new(1, 0, 0, 160), UDim2.new(0, 0, 0.26, 0), "", 140)
countLabel.Font = Enum.Font.GothamBlack
countLabel.TextColor3 = Color3.fromHex("FFD34D")
countLabel.TextStrokeTransparency = 0.2
countLabel.ZIndex = 9
countLabel.Visible = false
-- On keyboard devices the slider shows which key taps.
do
	local keyCap = label(pace.bar, UDim2.fromOffset(70, 24), UDim2.new(1, 10, 0.5, -12), "SPACE", 14)
	keyCap.BackgroundTransparency = 0.1
	keyCap.BackgroundColor3 = Color3.fromHex("F4EFE6")
	keyCap.TextColor3 = Color3.fromHex("1F2430")
	keyCap.TextStrokeTransparency = 1
	keyCap.ZIndex = 6
	round(keyCap, UDim.new(0, 6))
	keyCap.Visible = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
end
-- "FINAL BURST ×2" and, after your tap, your result banner sit just above the burst bar (their
-- bottoms 10 px over it), smaller on short screens (layout), so neither covers the bar.
local burstTitle = label(gui, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0.44, -10), "FINAL BURST  ×2", 52)
burstTitle.AnchorPoint = Vector2.new(0, 1)
burstTitle.Font = Enum.Font.GothamBlack
burstTitle.TextColor3 = Color3.fromHex("FFD34D")
burstTitle.Visible = false

-- Riding meter (D-066: was "SPEED", which it never changed): fills from your last few passes, gold
-- over slate (ART_DIRECTION: no red-to-green).
local speed = Instance.new("Frame")
speed.AnchorPoint = Vector2.new(0.5, 0)
speed.Size = UDim2.new(0.4, 0, 0, 16)
speed.Position = UDim2.new(0.5, 0, 0.75, -10)
speed.BackgroundColor3 = Color3.fromHex("3A4250") -- slate
speed.BackgroundTransparency = 0.2
speed.ZIndex = 3
speed.Visible = false
speed.Parent = gui
round(speed, UDim.new(0, 8))
local speedFill = Instance.new("Frame")
speedFill.Size = UDim2.fromScale(0, 1)
speedFill.BackgroundColor3 = Color3.new(1, 1, 1)
speedFill.ZIndex = 4
speedFill.Parent = speed
round(speedFill, UDim.new(0, 8))
do
	local speedGradient = Instance.new("UIGradient")
	speedGradient.Color = ColorSequence.new(Color3.fromHex("F2B630"), Color3.fromHex("FFD34D")) -- gold
	speedGradient.Parent = speedFill
	local speedLabel = label(speed, UDim2.new(0, 70, 1, 0), UDim2.new(0, -78, 0, 0), HUD.rideMeterLabel or "RIDING", 16)
	speedLabel.TextXAlignment = Enum.TextXAlignment.Right
end

-- Your place in the race (D-030): big, top right under the minimap.
local placeBadge = Instance.new("Frame")
placeBadge.AnchorPoint = Vector2.new(1, 0)
placeBadge.Position = UDim2.new(1, -16, 0, 268) -- under the race map
placeBadge.Size = UDim2.fromOffset(150, 70)
placeBadge.BackgroundColor3 = Color3.fromHex("FFF7E6") -- Paper (RaceHudStyle)
placeBadge.BackgroundTransparency = 0
placeBadge.ZIndex = 6
placeBadge.Visible = false
placeBadge.Parent = gui
round(placeBadge, UDim.new(0, 14))
local badgeScale = Instance.new("UIScale")
badgeScale.Parent = placeBadge
local placeText = label(placeBadge, UDim2.new(1, 0, 0.72, 0), UDim2.fromScale(0, 0), "", 46)
placeText.Font = Enum.Font.GothamBlack
placeText.TextColor3 = Color3.fromHex("FFD34D")
placeText.ZIndex = 7
local placeOf = label(placeBadge, UDim2.new(1, 0, 0.3, 0), UDim2.fromScale(0, 0.68), "", 16)
placeOf.ZIndex = 7
local chanceArrow = Instance.new("ImageLabel")
chanceArrow.AnchorPoint = Vector2.new(1, 0.5)
chanceArrow.Position = UDim2.new(0, -6, 0.5, 0)
chanceArrow.Size = UDim2.fromOffset(40, 40)
chanceArrow.BackgroundTransparency = 1
chanceArrow.ZIndex = 7
chanceArrow.Visible = false
chanceArrow.Parent = placeBadge
local arrowUntil = 0

-- Tap-result shapes above the feedback text (Perfect is a star, a miss is a flat dash).
local feedbackIcon = Instance.new("ImageLabel")
feedbackIcon.AnchorPoint = Vector2.new(0.5, 1)
feedbackIcon.Position = UDim2.new(0.5, 0, 0.62, -2)
feedbackIcon.Size = UDim2.fromOffset(52, 52)
feedbackIcon.BackgroundTransparency = 1
feedbackIcon.ZIndex = 5
feedbackIcon.Visible = false
feedbackIcon.Parent = gui
local RESULT_ART = {
	Perfect = "label_perfect", Great = "label_great", Good = "label_good", Okay = "label_okay",
	Miss = "label_miss", ["Too fast"] = "label_steady",
}
local function showResultIcon(labelText: string?)
	local name = labelText and RESULT_ART[labelText]
	if name then UiArt.set(feedbackIcon, name) else feedbackIcon.Visible = false end
end

-- Burst celebration (own screen only, after scoring).
local burstBanner = label(gui, UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.44, -10), "", 64)
burstBanner.AnchorPoint = Vector2.new(0, 1)
local bannerTextPx = 64 -- (layout: scaled on short screens)
burstBanner.Font = Enum.Font.GothamBlack
burstBanner.TextColor3 = Color3.fromRGB(255, 225, 90)
burstBanner.Visible = false
local rays = Instance.new("ImageLabel")
rays.AnchorPoint = Vector2.new(0.5, 0.5)
rays.Position = UDim2.new(0.5, 0, 0.44, -50) -- behind the banner
rays.Size = UDim2.fromOffset(340, 340)
rays.BackgroundTransparency = 1
rays.ZIndex = 4
rays.Visible = false
rays.Parent = gui

-- The results card (D-067): ResultsCard builds and fits it; this script fills it and shows it.
local Card = require(script.Parent:WaitForChild("ResultsCard"))
local results = Card.results -- (the card's column: showing it shows the card)
local TRIP_ROW = (GameConfig.results or {}).tripRow == true

-- Small (phone) screens: the board and place badge shrink with the screen and the badge sits under
-- the race map (scaled the same way, D-055); the results card fits itself (fitCard). The steering
-- buttons size and place themselves too (steerLayout, below).
local steerLayout: (() -> ())? = nil
local function layout()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	local k = RaceState.hudScale()
	boardScale.Scale, badgeScale.Scale = k, k
	board.Position = UDim2.new(0, 12, 0, math.floor(90 * k))
	placeBadge.Position = UDim2.new(1, -16, 0, math.floor(RaceState.MAP_TOP + (RaceState.MAP_HEIGHT + 10) * k))
	if results.Visible then Card.layout() end -- (one or two columns: the screen may have turned)
	-- Short screens: the burst title and banner shrink with the HUD (28 px at least).
	local textK = if height < 500 then k else 1
	burstTitle.TextSize = math.max(28, math.floor(52 * textK))
	burstTitle.Size = UDim2.new(1, 0, 0, burstTitle.TextSize + 8)
	bannerTextPx = math.max(28, math.floor(64 * textK))
	burstBanner.Size = UDim2.new(1, 0, 0, bannerTextPx + 16)
	if steerLayout then steerLayout() end
end
local function watchViewport()
	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()
end
watchViewport()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)


-- (AAA Phase 4, D-069) The HUD in the art direction's colours, and the music bed.
require(script.Parent:WaitForChild("RaceHudStyle")).apply({ board = board, rows = rows, placeBadge = placeBadge, placeText = placeText,
	placeOf = placeOf, pace = pace, speed = speed, countLabel = countLabel, status = status, feedback = feedback, hint = hint,
	burstTitle = burstTitle, burstBanner = burstBanner })
require(script.Parent:WaitForChild("MusicBed")).start()

-- State ---------------------------------------------------------------------
local lanes = {}
local chances = {}
local sparkleUntil = {}
local riding = false
local myLaneIndex = nil
local youMarkerPlace: TextLabel? = nil
local lastAt = { hud = 0, watch = 0, arrow = -math.huge } -- when the HUD, the watch check and the chance arrow last ran
-- pace = { passes, tapsByPass = {}, done = 0, recent = {} } for the race
local paceState = nil
-- active burst = { seg, open, close, spec, tapped }
local burstState = nil
-- AAA Phase 2 (D-067): the finish moment and first-race coaching (both below).
local finishSeq = nil
local coach = nil -- { race, hintPasses, passes, burstHinted } in a coached race
local clearFinishFx: () -> () = function() end
local endOrbit: () -> () = function() end

-- The running-order board (D-030, D-055). During a race the rows follow the running order;
-- before it they're in lane order. Rows show place, lane badge and name, with a 📣 (and an up or
-- down arrow after cheers lock) on the rider you cheered. No win % or purse unless
-- GameConfig.hud.boardShowsChance. Spectators on a phone get the top 3 plus their rider.
local cheerArrow = nil -- { up, untilT } for the rider you cheered
local function boardLanes(racing: boolean): { number }
	local list = {}
	for r = 1, math.min(RaceState.lanes, #rows) do
		local i = if racing then RaceState.order[r] else r
		if i then table.insert(list, i) end
	end
	if myLaneIndex or not RaceState.phone() or #list <= HUD.spectatorBoardRowsPhone then return list end
	local mine = RaceState.myCheer()
	local short, hasMine = {}, false
	for r = 1, HUD.spectatorBoardRowsPhone - 1 do
		table.insert(short, list[r])
		if list[r] == mine then hasMine = true end
	end
	table.insert(short, if mine and not hasMine then mine else list[HUD.spectatorBoardRowsPhone])
	return short
end
local function renderBoard()
	local t = os.clock()
	local racing = RaceState.active and #RaceState.order > 0
	local list = boardLanes(racing)
	for r, row in rows do
		local i = list[r]
		local lane = i and lanes[i]
		if lane then
			local you = lane.id == myId and "  ◀ YOU" or ""
			local star = ""
			if i == RaceState.myCheer() then
				star = " 📣" -- the horse you cheer for (📣 = fans, D-064; ★ is how you rode)
				if cheerArrow and cheerArrow.untilT > t then star ..= if cheerArrow.up then " ▲" else " ▼" end
			end
			local sparkle = (sparkleUntil[lane.id] or 0) > t and " ✦" or ""
			local lead = if racing then RaceState.ordinal(RaceState.place[i] or r) else tostring(i)
			local extra = if HUD.boardShowsChance
				then string.format("  %d%%  %s %d", math.round((chances[i] or 0) * 100), ThemePack.words.purse, lane.purse)
				else ""
			row.Text = string.format("%s  %s%s%s%s%s", lead, lane.name, star, sparkle, you, extra)
			row.TextColor3 = if lane.id == myId then Color3.fromHex("8F4700") else Color3.fromHex("1D2433") -- Ink on Paper; yours dark orange
			UiArt.set(rowBadges[r], if sparkle ~= "" then `lane_{i}_sparkle` else `lane_{i}`)
		else
			row.Text = ""
			rowBadges[r].Visible = false
		end
	end
	board.Size = UDim2.new(0, if HUD.boardShowsChance then 300 else 240, 0, math.max(1, #list) * 26 + 10)
end

-- A pass with no tap: the glow greys for a moment instead of a failure word (D-055).
local greyToken = 0
local function greyGlow()
	greyToken += 1
	local token = greyToken
	local zone = pace.zone
	local function paint(c: Color3)
		zone.BackgroundColor3 = c
		for _, d in zone:GetDescendants() do
			if d:IsA("ImageLabel") then d.ImageColor3 = c end
		end
	end
	paint(Color3.fromRGB(150, 150, 150))
	task.delay(0.3, function()
		if token == greyToken then
			zone.BackgroundColor3 = Color3.fromHex("FFD23F") -- the Gold glow
			for _, d in zone:GetDescendants() do
				if d:IsA("ImageLabel") then d.ImageColor3 = Color3.new(1, 1, 1) end
			end
		end
	end)
end

local function hideMeters()
	pace.bar.Visible, burst.bar.Visible, speed.Visible, burstTitle.Visible, tapArea.Visible = false, false, false, false, false
	if steerLayout then steerLayout() end -- the tap words leave the burst bar's place
end

local function celebrate(score: number, labelText: string)
	burstBanner.Text = string.format("%s! %d", labelText, math.round(score))
	burstBanner.Visible = true
	burstBanner.TextTransparency = 0
	burstBanner.TextSize = math.floor(bannerTextPx * 0.625)
	TweenService:Create(burstBanner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = bannerTextPx }):Play()
	if score >= 80 and UiArt.set(rays, "burst_rays") then
		rays.ImageTransparency = 0.2
		TweenService:Create(rays, TweenInfo.new(1.8), { ImageTransparency = 1 }):Play()
	end
	if score >= 80 then Cam.kick(FX.burstFovDeg, 2 * FX.fovFallSeconds) end -- the big kick (D-066; none under Reduced Motion)
	task.delay(1.6, function()
		TweenService:Create(burstBanner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

-- A tap while the Final Burst is still grey (D-066): the bar gives a small shake (none under
-- Reduced Motion), with the early hint.
local shakeToken = 0
local function shakeBurst()
	local px = HUD.burstEarlyShakePx or 0
	if px <= 0 or reducedMotion() then return end
	shakeToken += 1
	local token = shakeToken
	task.spawn(function()
		for _, dx in { px, -px, 0.6 * px, -0.6 * px, 0 } do
			if token ~= shakeToken then return end
			burst.bar.Position = UDim2.new(0.5, dx, 0.44, 0)
			task.wait(0.04)
		end
	end)
end

local function tap()
	local t = serverNow()
	if burstState and not burstState.tapped and t >= burstState.open and t <= burstState.close then
		-- Not armed yet (D-066): ignored, not used up; the server ignores it too.
		if not BurstMeter.armed(t - burstState.open, ARM) then
			if HUD.burstEarlyHint and HUD.burstEarlyHint ~= "" then hint.Text = HUD.burstEarlyHint end -- kind, no sound
			shakeBurst()
			return
		end
		burstState.tapped = true
		remotes.BurstTap:FireServer(burstState.seg, t)
		tapArea.Visible = false
		return
	end
	if not paceState or not riding then return end
	local k = PaceMeter.passIndex(paceState.passes, t)
	if not k then return end -- before the bell (no false starts) or between passes
	remotes.PaceTap:FireServer(t) -- the server applies the same bounce rule
	-- A finger bounce (another tap within BOUNCE of the last counted tap) is ignored (D-055).
	if paceState.lastCounted and t - paceState.lastCounted < BOUNCE then return end
	paceState.lastCounted = t
	local n = (paceState.tapsByPass[k] or 0) + 1
	paceState.tapsByPass[k] = n
	if n == 1 then
		paceState.firstTap[k] = t
		local pass = paceState.passes[k]
		local score = PaceMeter.tapScore(pass, t)
		local labelText = GameConfig.labelFor(score)
		if score < HUD.earlyLateBelow then
			labelText = if t < PaceMeter.idealTime(pass) then "Early" else "Late" -- says what to fix
		end
		feedback.Text = labelText
		showResultIcon(labelText)
		popFeedback()
		Coach.judge(labelText, PaceMeter.position(pass, t)) -- (D-067) the word at the marker too
		if not (coach and coach.race == cueRace and k <= (FX.coachHintPasses or 0)) then hint.Text = "" end -- (a coached race holds the rule)
		-- The tap tick (D-066): every counted tap, pitched by its score (Sound.play's 4th argument is
		-- the PlaybackSpeed). With the tick off, Great and Perfect chime as before.
		local ticked = FX.enabled and FX.tapTick and Sound ~= nil
		if ticked then
			pcall(Sound.play, "tap_ok", FX.tickVolume, nil, RaceFx.tickSpeed(GameConfig.labelFor(score), FX))
		end
		-- Great-or-better taps in a row: every surgeOnGreatStreak-th surges too (no camera kick).
		paceState.streak = if labelText == "Perfect" or labelText == "Great" then (paceState.streak or 0) + 1 else 0
		if labelText == "Great" and FX.enabled and RaceFx.streakSurges(paceState.streak, FX) then RaceState.surgeAt = t end
		if labelText == "Perfect" or labelText == "Great" then
			if Sound and not ticked then Sound.play("tap_good") end
			-- A Perfect has its own sound on top of the tick (Great just ticks).
			if Sound and ticked and labelText == "Perfect" then pcall(Sound.play, "tap_good", FX.perfectChimeVolume) end
			RaceState.nudgeAt = t -- instant, luck-free nudge on your own horse (D-033)
		end
		if labelText == "Perfect" and FX.enabled then
			RaceState.surgeAt = t -- the surge on your own horse (RaceView, D-066)
			Cam.kickPerfect() -- (rate-limited: RaceFx.canKickPerfect)
		end
		if RaceState.recording then table.insert(RaceState.recording.events, { t = t, kind = "tap", label = labelText }) end
	else
		feedback.Text = "One tap!"
		showResultIcon("Too fast")
		paceState.streak = 0
		hint.Text = "One tap each time the marker crosses"
	end
end

-- Steering (D-054 S3) ---------------------------------------------------------------
-- ◀ In / Out ▶ sit bottom-left, above the default thumbstick zone and over the tap area, so a
-- press on them never taps. Riders get them from their introRaces + 1-th race (the server says,
-- SteerControls), from the gate to the far-turn lock: three soft bell ticks, "Lanes locked!", the
-- buttons grey, then fade before the Final Burst. Keys: A/← in, D/→ out; gamepad: the D-pad or a
-- left-stick flick (RaceInput). None of them is a tap (D-055). Chips above the buttons say what
-- steering did ("Saved ground!", "Tucked in!" with wind lines) and give a gentle tip when you're
-- wide into a turn; never a lost place, never a countdown.
-- Boxed in (D-057 N4, from the server's SteerLane: SteerHud, SteerChips): Out ▶ greys, with a small
-- horse icon, while a horse leaves no room outside; ◀ In greys only when tuck-back can't help.
-- Grey arrows still take presses (no buzz, no red). A press waiting for room shows a thin ring on
-- its arrow (lit inward, filling outward); an outward press that drops after its wait makes its
-- arrow wobble gently (none under Reduced Motion). "No room yet" after a second of waiting (at most
-- once per 10 s), "Gap!" when a wait ends in the move. The buttons show for every input, so keys
-- and the gamepad get the same arrows, ring, wobble and chips.
-- The buttons, chips and tip live in their own screen inside the device's safe area (clear of a
-- notch), drawn over RaceUI so a press on them never reaches the tap area.
local steerGui = Instance.new("ScreenGui")
steerGui.Name = "RaceSteer"
steerGui.ResetOnSpawn = false
steerGui.DisplayOrder = gui.DisplayOrder + 1
pcall(function() steerGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
steerGui.Parent = player:WaitForChild("PlayerGui")
local steerPad = Instance.new("Frame")
steerPad.Name = "SteerPad"
steerPad.AnchorPoint = Vector2.new(0, 1)
steerPad.BackgroundTransparency = 1
steerPad.ZIndex = 8
steerPad.Visible = false
steerPad.Parent = steerGui
local BUTTON_COLOUR, LOCKED_COLOUR = Color3.fromHex("F4EFE6"), Color3.fromRGB(170, 170, 170)
local GREY_COLOUR = Color3.fromRGB(SHUD.greyRgb[1], SHUD.greyRgb[2], SHUD.greyRgb[3]) -- a boxed-in arrow (D-057 N4): soft, never red
-- Per button: the small horse icon (grey: a horse is there), the wait ring and its fill gradient,
-- and what was last painted (repainted only on a change).
local arrowUi: { [TextButton]: any } = {}
local function steerButton(text: string): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = BUTTON_COLOUR
	b.BackgroundTransparency = 0.1
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.fromHex("1F2430")
	b.ZIndex = 8
	b.AutoButtonColor = true
	b.Parent = steerPad
	round(b, UDim.new(0, 18))
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 30
	size.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 3
	stroke.Color = Color3.fromHex("1F2430")
	stroke.Parent = b
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Text = "🐎"
	icon.TextScaled = true
	icon.Size = UDim2.fromScale(0.3, 0.3)
	icon.AnchorPoint = Vector2.new(0.5, 0.5) -- on the top edge, clear of the arrow and its text
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.ZIndex = 9
	icon.Visible = false
	icon.Parent = b
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, 10, 1, 10)
	ring.Position = UDim2.fromOffset(-5, -5)
	ring.ZIndex = 7
	ring.Visible = false
	ring.Parent = b
	round(ring, UDim.new(0, 22))
	local ringStroke = Instance.new("UIStroke")
	ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ringStroke.Thickness = 3
	ringStroke.Color = BUTTON_COLOUR
	ringStroke.Parent = ring
	local ringGrad = Instance.new("UIGradient")
	ringGrad.Parent = ringStroke
	arrowUi[b] = { icon = icon, ring = ring, stroke = ringStroke, grad = ringGrad, grey = false, fill = -1 }
	return b
end
local inBtn, outBtn = steerButton("◀ In"), steerButton("Out ▶")

local steerChip = label(steerGui, UDim2.fromOffset(320, 44), UDim2.new(), "", 20)
steerChip.AnchorPoint = Vector2.new(0, 1)
steerChip.BackgroundColor3 = BUTTON_COLOUR
steerChip.BackgroundTransparency = 0.1
steerChip.TextColor3 = Color3.fromHex("1F2430")
steerChip.TextStrokeTransparency = 1
steerChip.TextScaled = true
steerChip.TextWrapped = true
steerChip.ZIndex = 9
steerChip.Visible = false
round(steerChip, UDim.new(0, 12))
do
	local chipText = Instance.new("UITextSizeConstraint")
	chipText.MaxTextSize, chipText.MinTextSize = 20, 12
	chipText.Parent = steerChip
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft, chipPad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	chipPad.Parent = steerChip
end
local chipScale = Instance.new("UIScale")
chipScale.Parent = steerChip

-- The ghost-thumb tip (first race with the buttons): a see-through thumb pressing ◀ In.
local thumb = label(steerGui, UDim2.fromOffset(64, 64), UDim2.new(), "👆", 52)
thumb.AnchorPoint = Vector2.new(0.5, 0)
thumb.TextTransparency = 0.35
thumb.TextStrokeTransparency = 1
thumb.ZIndex = 10
thumb.Visible = false
local thumbX, thumbY = 0, 0

-- Wind lines while tucked in behind a horse: thin streaks either side of your horse.
local wind = Instance.new("Frame")
wind.Size = UDim2.fromScale(1, 1)
wind.BackgroundTransparency = 1
wind.ZIndex = 2
wind.Visible = false
wind.Parent = gui
local windLines = {}
for k = 1, 6 do
	local line = Instance.new("Frame")
	line.Size = UDim2.fromOffset(90, 3)
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BorderSizePixel = 0
	line.ZIndex = 2
	line.Parent = wind
	round(line, UDim.new(1, 0))
	windLines[k] = line
end

-- Buttons at least minButtonPx (88 px), bigger on big screens; bottom-left, above the speed
-- meter. On a narrow screen the tap words (feedback, hint) move right of the buttons while
-- they're up, so nothing hides behind them. On a phone, in a race where you have the buttons
-- (hud.sliderClearOfPad, D-066), the slider and the riding meter sit right of the pad for the
-- whole race (they don't jump when the pad fades), so a thumb on Out ▶ never covers the glow.
-- While the Final Burst bar is up the tap words step below it (on a phone they'd sit on it).
local padRace = false -- this race shows you the ◀ ▶ pad (SteerControls)
local burstLaidOut = false
steerLayout = function()
	local camera = workspace.CurrentCamera
	local w = if camera then camera.ViewportSize.X else 1280
	local size = if RaceState.phone() then SHUD.minButtonPx
		else math.max(SHUD.minButtonPx, math.floor(SHUD.buttonPx * RaceState.hudScale()))
	local gap, left = 12, 12 -- from the safe area's left edge (a notch is already outside it)
	steerPad.Size = UDim2.fromOffset(2 * size + gap, size)
	steerPad.Position = UDim2.new(0, left, 0.75, -8)
	inBtn.Size, outBtn.Size = UDim2.fromOffset(size, size), UDim2.fromOffset(size, size)
	inBtn.Position, outBtn.Position = UDim2.fromOffset(0, 0), UDim2.fromOffset(size + gap, 0)
	steerChip.Position = UDim2.new(0, left, 0.75, -8 - size - 10)
	steerChip.Size = UDim2.fromOffset(math.max(2 * size + gap, 320), 44)
	thumbX, thumbY = left + size / 2, -8 - size / 2
	local right = (steerGui.AbsolutePosition.X - gui.AbsolutePosition.X) + left + 2 * size + gap + 12
	-- The slider and the riding meter (its label sits 78 px left of the meter). Moved right of the
	-- pad on any screen where the pad's right edge reaches the slider or the meter's label (phones,
	-- and tablets at 1024x768 or 1280x720) and at least 200 px are left for the slider. The meter
	-- sits 10 px higher than it used to, clear of the marker's top (the marker is 1.6x the bar).
	local overlaps = right > 0.15 * w or right > 0.3 * w - 78
	if padRace and HUD.sliderClearOfPad ~= false and overlaps and w - 12 - right >= 200 then
		local barW = w - 12 - right
		pace.bar.Size, pace.bar.Position = UDim2.new(0, barW, 0, 34), UDim2.new(0, right + barW / 2, 0.80, 0)
		local meterW = math.min(barW - 78, math.floor(0.4 * w))
		speed.Size, speed.Position = UDim2.new(0, meterW, 0, 16), UDim2.new(0, right + 78 + meterW / 2, 0.75, -10)
	else
		pace.bar.Size, pace.bar.Position = UDim2.new(0.7, 0, 0, 34), UDim2.new(0.5, 0, 0.80, 0)
		speed.Size, speed.Position = UDim2.new(0.4, 0, 0, 16), UDim2.new(0.5, 0, 0.75, -10)
	end
	-- The tap words: under the burst bar while it's up (the icon on top, then the word, then the hint)...
	burstLaidOut = burst.bar.Visible
	if burstLaidOut then
		local below = burst.bar.AbsolutePosition.Y - gui.AbsolutePosition.Y + burst.bar.AbsoluteSize.Y + 6
		feedbackIcon.Position = UDim2.new(0.5, 0, 0, below + 52)
		feedback.Position, feedback.Size = UDim2.new(0, 0, 0, below + 54), UDim2.new(1, 0, 0, 46)
		local h = if camera then camera.ViewportSize.Y else 720
		hint.Position, hint.Size = UDim2.new(0, 0, 0, math.min(below + 100, h - 32)), UDim2.new(1, 0, 0, 28) -- (off the bottom edge)
	-- ...else right of the buttons on a narrow screen while they're up...
	elseif steerPad.Visible and w / 2 - 260 < right then
		feedback.Position, feedback.Size = UDim2.new(0, right, 0.62, 0), UDim2.new(1, -right - 12, 0, 46)
		hint.Position, hint.Size = UDim2.new(0, right, 0.68, 0), UDim2.new(1, -right - 12, 0, 28)
		feedbackIcon.Position = UDim2.new(0.5, (right - 12) / 2, 0.62, -2)
	else -- ...else centred
		feedback.Position, feedback.Size = UDim2.new(0, 0, 0.62, 0), UDim2.new(1, 0, 0, 46)
		hint.Position, hint.Size = UDim2.new(0, 0, 0.68, 0), UDim2.new(1, 0, 0, 28)
		feedbackIcon.Position = UDim2.new(0.5, 0, 0.62, -2)
	end
end
layout()

-- steer = the race you ride: { race, course, start, geo (TrackLayout.phaseA), shown, smart, tipAt,
-- tipUntil, lockAt, locked, hideAt, seq, lastPress, pressed, armed (stick), turnAcc, tipped, tips,
-- tuckedFor, tuckedTotal, tuckChips, tuckChipAt, bellArmed }
local steer = nil

-- While you have the buttons, the steering keys (A/D, the arrows, the D-pad) are bound above the
-- camera's own keys and sunk, so the arrows steer instead of turning the camera, and never tap.
local STEER_ACTION = "GiddyUpSteer"
local STEER_KEYS = {}
for name in RaceInput.STEER do
	local ok, code = pcall(function() return (Enum.KeyCode :: any)[name] end)
	if ok and code then table.insert(STEER_KEYS, code) end
end
local steerBound = false
local steerPress: (number) -> () = function(_dir: number) end -- set below
local function bindSteer(on: boolean)
	if on == steerBound then return end
	steerBound = on
	if on then
		ContextActionService:BindActionAtPriority(STEER_ACTION, function(_, state, input)
			if state == Enum.UserInputState.Begin then
				local dir = RaceInput.steerDir(input.KeyCode.Name)
				if dir then steerPress(dir) end
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 1, table.unpack(STEER_KEYS))
	else
		ContextActionService:UnbindAction(STEER_ACTION)
	end
end

local chipToken = 0
local function showChip(text: string, seconds: number?)
	if steer and steer.chips then SteerChips.shown(steer.chips, serverNow() - steer.start) end
	chipToken += 1
	local token = chipToken
	steerChip.Text = text
	steerChip.TextTransparency, steerChip.BackgroundTransparency = 0, 0.1
	steerChip.Visible = true
	if reducedMotion() then
		chipScale.Scale = 1
	else
		chipScale.Scale = 0.8
		TweenService:Create(chipScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	task.delay(seconds or SHUD.chipSeconds, function()
		if token ~= chipToken then return end
		TweenService:Create(steerChip, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.delay(0.3, function()
			if token == chipToken then steerChip.Visible = false end
		end)
	end)
end

local function paintButtons(locked: boolean)
	for _, b in { inBtn, outBtn } do
		b.BackgroundColor3 = if locked then LOCKED_COLOUR else BUTTON_COLOUR
		b.TextTransparency = if locked then 0.5 else 0
		b.AutoButtonColor = not locked
		b.Rotation = 0
		local ui = arrowUi[b]
		ui.icon.Visible, ui.ring.Visible, ui.grey, ui.fill = false, false, false, -1
	end
end

-- One arrow's boxed-in look (SteerHud): grey with the horse icon, and the wait ring (fill 0..1, -1
-- none). Repainted only when something changed; the lit ring breathes gently unless Reduced Motion.
local function fillSequence(f: number): NumberSequence
	if f >= 0.99 then return NumberSequence.new(0) end
	if f <= 0.01 then return NumberSequence.new(1) end
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(f, 0),
		NumberSequenceKeypoint.new(math.min(f + 0.01, 1), 1), NumberSequenceKeypoint.new(1, 1) })
end
local function paintArrow(b: TextButton, arrow: any)
	local ui = arrowUi[b]
	if arrow.grey ~= ui.grey then
		ui.grey = arrow.grey
		b.BackgroundColor3 = if arrow.grey then GREY_COLOUR else BUTTON_COLOUR
		b.TextTransparency = if arrow.grey then 0.35 else 0
		ui.icon.Visible = arrow.grey
	end
	local fill = if arrow.ring < 0 then -1 else math.floor(arrow.ring * 20 + 0.5) / 20
	if fill ~= ui.fill then
		ui.fill = fill
		ui.ring.Visible = fill >= 0
		if fill >= 0 then ui.grad.Transparency = fillSequence(fill) end
	end
	if fill >= 1 then
		ui.stroke.Transparency = if reducedMotion() then 0.1 else 0.1 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 3))
	elseif fill >= 0 then
		ui.stroke.Transparency = 0.1
	end
end

-- A dropped press: its arrow wobbles gently (no sound), none under Reduced Motion.
local function wobbleArrow(dir: number)
	if reducedMotion() then return end
	local b = if dir < 0 then inBtn else outBtn
	local step = SHUD.wobbleSeconds / 4
	local seq = { SHUD.wobbleDeg, -SHUD.wobbleDeg, SHUD.wobbleDeg / 2, 0 }
	for k, angle in seq do
		task.delay(step * (k - 1), function()
			TweenService:Create(b, TweenInfo.new(step, Enum.EasingStyle.Sine), { Rotation = angle }):Play()
		end)
	end
end

local function clearSteer()
	steer = nil
	bindSteer(false)
	chipToken += 1
	steerChip.Visible, thumb.Visible, wind.Visible = false, false, false
	if padRace then
		padRace = false
		steerLayout()
	end
end

-- A press: one lane in (-1) or out (1). The server decides; your own glide starts at once.
steerPress = function(dir: number)
	local s = steer
	if not (s and s.shown and riding and not s.locked and s.race == cueRace) then return end
	local t = serverNow()
	if t < s.start or (s.lockAt and t >= s.lockAt) then return end
	s.seq += 1
	s.lastPress = os.clock()
	s.pressDir, s.pressAt = dir, t - s.start -- (a wait you cancel by pressing the other way never wobbles)
	s.pressed = true
	remotes:WaitForChild("SteerRequest"):FireServer(dir, s.seq)
	RaceState.predictSteer(dir, s.seq)
	if RaceState.recording then table.insert(RaceState.recording.events, { t = t, kind = "steer", dir = dir }) end
end
for _, pair in { { inBtn, -1 }, { outBtn, 1 } } do
	pair[1].InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if input.UserInputState == Enum.UserInputState.Begin
			and (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) then
			steerPress(pair[2]) -- on the finger going down, like a tap
		end
	end)
end
-- The left stick steers by flicks: past 0.6 fires once, back under 0.3 re-arms.
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed or input.KeyCode ~= Enum.KeyCode.Thumbstick1 or not steer then return end
	local dir, armed = RaceInput.flick(steer.armed, input.Position.X)
	steer.armed = armed
	if dir then steerPress(dir) end
end)

-- Three soft bell ticks before the lock (lockBellSeconds), riders with the buttons only.
local function armBell(s)
	if s.bellArmed or not s.shown or not s.lockAt then return end
	s.bellArmed = true
	for k = 0, 2 do
		local at = s.lockAt - STEER.lockBellSeconds + k * STEER.lockBellSeconds / 3
		if at > serverNow() then cue(at, "lock_tick") end
	end
end

-- A tucked-in span ends: the replay draws its wind lines (S4).
local function endTuck(s, t: number)
	if s.tuckFrom and RaceState.recording then
		table.insert(RaceState.recording.events, ReplayTrip.tuck(s.tuckFrom, t))
	end
	s.tuckFrom = nil
end

-- Each frame while you ride with the buttons: show or hide them, the tip, the chips, the wind.
local SPEED = GameConfig.raceSpeedStudsPerSecond
local function updateSteer(t: number, dt: number)
	local s = steer
	local on = s ~= nil and s.shown and riding and s.race == cueRace and t >= s.start
		and (s.hideAt == nil or os.clock() < s.hideAt)
	if steerPad.Visible ~= on then
		steerPad.Visible = on
		if steerLayout then steerLayout() end
	end
	if not on or s.locked then
		wind.Visible, thumb.Visible = false, false
		return
	end
	-- Boxed in (D-057 N4): the arrows from the server's word on your own lane, and "No room yet".
	local raceNow = t - s.start
	local inArrow, outArrow = SteerHud.arrows(s.hud, s.lane, raceNow, STEER, SHUD, s.shown)
	paintArrow(inBtn, inArrow)
	paintArrow(outBtn, outArrow)
	if SteerChips.noRoom(s.chips, s.lane, raceNow, SHUD) then showChip("No room yet") end
	-- The ghost-thumb tip, once, just after the gate.
	if s.tipAt and t >= s.tipAt then
		s.tipAt = nil
		s.tipUntil = os.clock() + SHUD.tipSeconds
		local keys = if UserInputService.TouchEnabled then ""
			elseif UserInputService.GamepadEnabled then " (D-pad)" else " (A or ←)"
		showChip("Steer to the rail before the turn ◀" .. keys, SHUD.tipSeconds)
	end
	if s.tipUntil and os.clock() < s.tipUntil then
		local press = if reducedMotion() then 0 else -10 * math.abs(math.sin(os.clock() * math.pi))
		thumb.Text, thumb.AnchorPoint = "👆", Vector2.new(0.5, 0) -- (first-race coaching points it down at the slider)
		thumb.Position = UDim2.new(0, thumbX, 0.75, thumbY + press)
		thumb.Visible = true
	else
		thumb.Visible = false
	end
	local me = myLaneIndex
	local x, off = RaceState.lane, RaceState.offset
	if not (me and x[me] and off[me]) then return end
	local sPace = SPEED * (t - s.start) -- feet along the rail, as Trip counts turns
	local n, sum = 0, 0
	for j = 1, RaceState.lanes do
		if j ~= me and x[j] then
			n += 1
			sum += x[j]
		end
	end
	local fieldX = if n > 0 then sum / n else x[me]
	-- "Saved ground!" leaving a turn ridden on the rail, or well inside the field, once you have
	-- steered this race (Smart Steer's own moves don't earn it).
	for k, turn in s.geo.turns do
		local acc = s.turnAcc[k]
		if sPace >= turn[1] and sPace < turn[2] then
			acc.own += x[me] * dt
			acc.field += fieldX * dt
			acc.time += dt
		elseif sPace >= turn[2] and not acc.done then
			acc.done = true
			local own, field = acc.own / math.max(acc.time, 1e-6), acc.field / math.max(acc.time, 1e-6)
			if s.pressed and acc.time > 0.5 and (own < SHUD.railLane or own <= field - SHUD.belowField) then
				showChip("Saved ground!")
				if RaceState.recording then -- the replay's green chevrons through this turn (S4)
					table.insert(RaceState.recording.events, ReplayTrip.saved(t, s.start, turn[1], turn[2], SPEED))
				end
			end
		end
	end
	-- A gentle tip when you steer yourself and are wide going into a turn (the far turn included).
	local manualNow = not s.smart or os.clock() - s.lastPress < STEER.smart.resumeSeconds
	if s.tips < SHUD.tipsPerRace and manualNow and x[me] >= STEER.smart.homeLane + SHUD.wideLanes - 0.05 then
		local starts = { s.geo.lockS }
		for _, turn in s.geo.turns do table.insert(starts, turn[1]) end
		for _, a in starts do
			if not s.tipped[a] and sPace < a and a - sPace <= STEER.smart.turnLeadSeconds * SPEED then
				s.tipped[a] = true
				s.tips += 1
				showChip("The rail is shorter on turns ◀")
				break
			end
		end
	end
	-- "Tucked in!" behind a horse in your lane (0.5 to 3 lengths), with wind lines.
	local tucked = false
	for j = 1, RaceState.lanes do
		if j ~= me and x[j] and off[j] and math.abs(x[j] - x[me]) < STEER.laneBand then
			local ahead = off[j] - off[me]
			if ahead >= STEER.draftNear and ahead <= STEER.draftFar then
				tucked = true
				break
			end
		end
	end
	-- The tucked-in credit stops at draftCap (draftCap / draftPerSecond seconds tucked in), and so
	-- do the chip and the wind lines; at most tuckedPerRace chips.
	s.tuckedFor = if tucked then s.tuckedFor + dt else 0
	if tucked then s.tuckedTotal += dt end
	if s.tuckedTotal * STEER.draftPerSecond >= STEER.draftCap then s.tuckedFor = 0 end
	if s.tuckedFor >= SHUD.tuckedSeconds and os.clock() - s.tuckChipAt >= SHUD.tuckedAgainSeconds
		and s.tuckChips < SHUD.tuckedPerRace then
		s.tuckChipAt = os.clock()
		s.tuckChips += 1
		showChip("Tucked in!")
	end
	wind.Visible = s.tuckedFor >= 0.3
	if wind.Visible and not s.tuckFrom then
		s.tuckFrom = t - s.tuckedFor
	elseif not wind.Visible and s.tuckFrom then
		endTuck(s, t)
	end
	if wind.Visible then
		local still = reducedMotion()
		for k, line in windLines do
			local phase = if still then 0.5 else (os.clock() * 1.2 + k * 0.37) % 1
			local y = 0.36 + 0.07 * ((k - 1) // 2)
			if k % 2 == 1 then
				line.Position = UDim2.new(0.3 - 0.25 * phase, -90, y, 0)
			else
				line.Position = UDim2.new(0.7 + 0.25 * phase, 0, y, 0)
			end
			line.BackgroundTransparency = 0.35 + 0.6 * phase
		end
	end
end

-- Taps count as the finger (or mouse button) goes down, like a key press, not on release.
tapArea.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if input.UserInputState == Enum.UserInputState.Begin
		and (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) then
		tap()
	end
end)
-- Only GameConfig.tapKeys tap (D-055): a kid pressing W to "go" or O to zoom out never wastes
-- a pass or the Final Burst. The first other key pressed during a pass shows which keys tap,
-- once a race; keys kids press on purpose for something else (moving, steering, the camera,
-- clapping, prompts, menus) don't.
local function keyCodes(names: { string }): { [Enum.KeyCode]: boolean }
	local set = {}
	for _, name in names do
		local ok, code = pcall(function() return (Enum.KeyCode :: any)[name] end)
		if ok and code then set[code] = true end
	end
	return set
end
local TAP_KEYS = keyCodes(GameConfig.tapKeys)
local QUIET_KEYS = keyCodes({
	"W", "A", "S", "D", "Up", "Down", "Left", "Right", "I", "O", "C", "E", "X", "Slash", "Tab", "Escape",
	"Backquote", "LeftShift", "RightShift", "LeftControl", "RightControl", "LeftAlt", "RightAlt", "LeftSuper",
	"RightSuper", "DPadUp", "DPadDown", "DPadLeft", "DPadRight", "Thumbstick1", "Thumbstick2", "ButtonL3",
	"ButtonR3", "ButtonSelect", "ButtonStart", "ButtonX", "ButtonY", "ButtonB",
})
local keyHintShown = false -- once a race
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- typing in chat, menus, or a GUI button took it
	local kind = input.UserInputType
	local pad = kind.Name:sub(1, 7) == "Gamepad"
	if kind == Enum.UserInputType.Keyboard or pad then
		local dir = RaceInput.steerDir(input.KeyCode.Name)
		if dir then
			return -- steering keys never tap (D-054, D-055); with the buttons they steer through bindSteer
		elseif TAP_KEYS[input.KeyCode] then
			tap()
		elseif not keyHintShown and not QUIET_KEYS[input.KeyCode] and riding and paceState
			and PaceMeter.passIndex(paceState.passes, serverNow()) then
			keyHintShown = true
			hint.Text = if pad then "Tap: A or R2" else "Tap: SPACE or click"
		end
	elseif (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) and not tapArea.Visible then
		tap() -- the tap pad isn't up yet; tap() ignores it unless a pass or the burst is open
	end
end)

local function placeMarker(meter, pos: number, center: number, twoTargets: boolean)
	meter.marker.Position = UDim2.new(0.5 + 0.5 * pos, 0, 0.5, 0)
	if twoTargets then
		meter.zone.Size, meter.zone2.Size = UDim2.new(0.1, 0, 1, 0), UDim2.new(0.1, 0, 1, 0)
		meter.zone.Position, meter.zone2.Position = UDim2.new(0.25, 0, 0, 0), UDim2.new(0.75, 0, 0, 0)
		meter.zone2.Visible = true
	else
		meter.zone.Size = UDim2.new(0.2, 0, 1, 0)
		meter.zone.Position = UDim2.new(0.5 + 0.5 * center, 0, 0, 0)
		meter.zone2.Visible = false
	end
end

RunService.RenderStepped:Connect(function(dt)
	local t = serverNow()
	updateSteer(t, dt)
	if stopGallop and not (RaceState.active and RaceState.myLane and seated() and not RaceState.myHome) then gallop(false) end
	-- Meter state belongs to one race; a race the HUD followed before never runs on into this one.
	if paceState and paceState.race ~= cueRace then paceState = nil end
	if burstState and burstState.race ~= cueRace then burstState = nil end
	if chanceArrow.Visible and os.clock() > arrowUntil then chanceArrow.Visible = false end
	-- While the Final Burst is up it has the screen to itself: the board, race map and place
	-- badge step aside (on a phone they would cover most of the burst bar).
	local burstUp = burst.bar.Visible
	RaceState.burstShowing = burstUp
	-- Watching (D-055): the HUD hides while you're busy or have walked out of range.
	if os.clock() - lastAt.watch > 0.25 then
		lastAt.watch = os.clock()
		RaceState.watchHidden = myLaneIndex == nil and RaceState.focus ~= nil
			and (RaceState.busy() or not RaceState.nearCourse(RaceState.focus, GameConfig.spectate.keepStuds))
	end
	local showBoard = RaceState.active and not burstUp and not RaceState.watchHidden
	if myLaneIndex then
		showBoard = showBoard and HUD.riderBoardInRace -- riders: the race strip and badge show position
	elseif RaceState.phone() and RaceState.cheerOpen then
		showBoard = false -- spectators on a phone: after the cheer strip closes
	end
	board.Visible = showBoard
	status.Visible = not RaceState.watchHidden or player:GetAttribute("InLine") == true
	if not RaceState.active then placeBadge.Visible = false end
	if RaceState.active and os.clock() - lastAt.hud > 0.2 then
		lastAt.hud = os.clock()
		renderBoard()
		local myPlace = myLaneIndex and RaceState.place[myLaneIndex]
		placeBadge.Visible = myPlace ~= nil and not burstUp and not finishSeq -- (gone for the finish moment, D-067)
		if myPlace then
			placeText.Text = RaceState.ordinal(myPlace)
			placeOf.Text = string.format("of %d", RaceState.lanes)
			if youMarkerPlace then youMarkerPlace.Text = RaceState.ordinal(myPlace) end
		end
	end
	if paceState and riding then
		local passes = paceState.passes
		local k = PaceMeter.passIndex(passes, t)
		-- During the countdown the slider shows still, with the first glow lit.
		local waiting = k == nil and passes[1] ~= nil and t < passes[1].t0
		pace.bar.Visible = k ~= nil or waiting
		-- The hoofbeats duck while the slider runs (D-066), switching once it has held for 0.3 s.
		local live = k ~= nil
		if live ~= paceState.duckWant then paceState.duckWant, paceState.duckSince = live, os.clock() end
		if stopGallop and live ~= gallopDucked and os.clock() - (paceState.duckSince or 0) >= 0.3 then gallop(true, live) end
		speed.Visible = k ~= nil
		tapArea.Visible = k ~= nil or (burstState ~= nil and not burstState.tapped)
		if k then
			local p = passes[k]
			placeMarker(pace, PaceMeter.position(p, t), p.center, false)
		elseif waiting then
			placeMarker(pace, PaceMeter.position(passes[1], passes[1].t0), passes[1].center, false)
		end
		-- First-race coaching (D-067): for the first coachPasses passes (and the countdown before
		-- them) the ghost thumb points at the green and presses as the marker crosses it, with "NOW!"
		-- on the green; the rule stays up for coachHintPasses passes.
		local coached = coach ~= nil and coach.race == cueRace
		Coach.frame(coached, pace, passes, k or (if waiting then 1 else nil), k ~= nil, t, thumb, steerGui,
			steer ~= nil and steer.tipUntil ~= nil and os.clock() < steer.tipUntil)
		if coached and k and k > (FX.coachHintPasses or 0) and hint.Text == FX.coachHint then hint.Text = "" end
		-- Finished passes feed the speed meter (missed or doubled count 0).
		while paceState.done < #passes and passes[paceState.done + 1].t1 <= t do
			paceState.done += 1
			local j = paceState.done
			local s = if paceState.tapsByPass[j] == 1 then PaceMeter.tapScore(passes[j], paceState.firstTap[j]) else 0
			if not paceState.tapsByPass[j] then paceState.streak = 0 end -- (a missed pass ends a Great streak)
			if not paceState.tapsByPass[j] and j > 1 then
				feedback.Text = HUD.missedPassLabel
				showResultIcon(if HUD.missedPassLabel ~= "" then HUD.missedPassLabel else nil)
				if HUD.missedPassLabel == "" then greyGlow() end
			end
			table.insert(paceState.recent, s)
			if #paceState.recent > GameConfig.pace.speedFillPasses then table.remove(paceState.recent, 1) end
			local sum = 0
			for _, v in paceState.recent do sum += v end
			TweenService:Create(speedFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(sum / #paceState.recent / 100, 1) }):Play()
		end
		if paceState.burstOpen and not burstState and t < paceState.burstOpen
			and t >= paceState.burstOpen - GameConfig.burstLeadSeconds then
			burstTitle.Visible = true -- "FINAL BURST" shows as the field turns into the homestretch
			if coach and coach.race == cueRace and not coach.burstHinted then -- (D-067) a coached race gets a heads-up
				coach.burstHinted = true
				hint.Text = FX.coachBurstHint
			end
		end
	end
	if burstState then
		local rel = t - burstState.open
		if rel >= 0 and t <= burstState.close then
			local shown = riding or not RaceState.watchHidden -- not over the barn (D-055)
			burst.bar.Visible = shown
			burstTitle.Visible = shown and not burstState.tapped -- your result banner takes its place
			if burstLaidOut ~= burst.bar.Visible then steerLayout() end
			local spec = burstState.spec
			placeMarker(burst, BurstMeter.position(rel, spec.sweepSeconds, spec.phase),
				BurstMeter.targetCenter(rel, spec), spec.twoTargets)
			-- Grey until armed (D-066), then the rainbow and the pulsing gold rim. The marker runs throughout.
			local armed = BurstMeter.armed(rel, ARM)
			if burstState.armedShown ~= armed then
				burstState.armedShown = armed
				if burst.gradient then burst.gradient.Enabled = armed end
				burst.bar.BackgroundColor3 = if armed then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
				burst.stroke.Color = if armed then Color3.fromHex("FFD34D") else Color3.fromRGB(110, 110, 110)
				burst.zone.BackgroundTransparency = if armed then 0.25 else 0.6
				burst.zone2.BackgroundTransparency = burst.zone.BackgroundTransparency -- (Champion's second glow)
				burst.stroke.Thickness = 6
				-- An early tap's "wait" hint gives way to the real one as the colours come on.
				if armed and riding and not burstState.tapped and hint.Text == HUD.burstEarlyHint then hint.Text = BURST_HINT end
			end
			if armed and not reducedMotion() then
				burst.stroke.Thickness = 6 + 2 * math.abs(math.sin(t * 6)) -- pulsing gold rim (3 Hz)
			end
		elseif t > burstState.close then
			if burstState.race == cueRace then cue(t, "vo_stretch") end -- "Down the stretch they come!"
			if riding and not burstState.tapped then feedback.Text = "Finish strong!" end -- riders only
			burst.bar.Visible, burstTitle.Visible = false, false
			burstState = nil
			steerLayout() -- the tap words go back
		end
	end
end)

-- Server events -------------------------------------------------------------
remotes.LobbyStatus.OnClientEvent:Connect(function(seconds)
	if GameConfig.queueCard and GameConfig.queueCard.enabled ~= false then return end -- the queue card shows the wait (D-061)
	status.Text = string.format("%s  Next race in %d", ThemePack.gameTitle, seconds)
	hint.Text = ThemePack.tagline
end)

local pendingBurstOpen = nil
local finishAt = 0 -- when the field reaches the line (same sums as RaceService)
local COURSE_NAME = { dirt = "Dirt course", turf = "Turf course" }
remotes.RaceStarted.OnClientEvent:Connect(function(league, laneList, start, cond, _resultAt, burstOpen, courseId)
	-- The next race on the course of your results card rebuilds its horses: the card stays
	-- (RaceState.consider keeps the focus on it), but there's nothing left to replay.
	if RaceState.resultsOpen and RaceState.holdFocus and (courseId or "dirt") == RaceState.myCourse then
		Card.watchBtn.Visible, Card.fullBtn.Visible = false, false
		Card.layout()
	end
	-- Two races can run at once (D-036): follow yours, or the newest when watching.
	if not RaceState.consider(courseId or "dirt", laneList, start) then return end
	-- The HUD follows this race now: drop the meters and pending cues of the one it followed before.
	cueRace += 1
	paceState, burstState = nil, nil
	hideMeters()
	pendingBurstOpen = burstOpen
	lanes = laneList
	chances = {}
	lastAt.from, lastAt.arrow = nil, -math.huge
	sparkleUntil = {}
	riding = false
	myLaneIndex = nil
	youMarkerPlace = nil
	for i, lane in laneList do
		chances[i] = lane.chance
		if lane.id == myId then
			riding = true
			myLaneIndex = i
		end
	end
	-- Steering (D-054 S3): this race's turns for the chips; the buttons wait for SteerControls.
	clearSteer()
	paintButtons(false)
	if riding then
		local track = TrackLayout.courses[courseId or "dirt"] or TrackLayout.churchill
		local distance = TrackLayout.distances[cond and cond.distance or "Sprint"] or TrackLayout.distances.Sprint
		local geo = TrackLayout.phaseA(track, TrackLayout.plan(track, distance))
		local acc = {}
		for k = 1, #geo.turns do acc[k] = { own = 0, field = 0, time = 0, done = false } end
		steer = { race = cueRace, course = courseId or "dirt", start = start, geo = geo, shown = false, smart = true,
			locked = false, seq = 0, lastPress = -math.huge, armed = true, turnAcc = acc, tipped = {}, tips = 0,
			tuckedFor = 0, tuckedTotal = 0, tuckChips = 0, tuckChipAt = -math.huge, pressed = false,
			hud = SteerHud.new(), chips = SteerChips.new(), lane = nil, pressDir = 0, pressAt = -math.huge, brushAt = -math.huge }
	end
	-- The picker's words for the race (D-064, AAA Phase 2 wording pass): "Bronze · 🐇 Short · Dirt ☀️",
	-- never "Sprint" on one screen and "🐇 Short" on another.
	local line = if cond then PickerText.cardLine({ league = league, distance = cond.distance, surface = cond.surface,
		weather = cond.weather, course = courseId }) else league
	status.Text = line .. (if riding then "" else "  (watching)")
	if COURSE_NAME[courseId] and not riding then status.Text = COURSE_NAME[courseId] .. " · " .. status.Text end
	-- First-race coaching (D-067): the rule, the ghost thumb over the green and "NOW!".
	local racesBefore = PlayerState.data and PlayerState.data.totals and PlayerState.data.totals.races
	coach = if riding and FX.enabled and PlayerState.data and RaceFx.coached(racesBefore, FX) then { race = cueRace } else nil
	feedback.Text = ""
	hint.Text = if coach then FX.coachHint elseif riding then "Tap when the marker crosses the glow" else ""
	burstBanner.Visible = false
	results.Visible = false
	clearFinishFx()
	RaceState.resultsOpen, RaceState.holdFocus = false, false
	showResultIcon(nil)
	speedFill.Size = UDim2.fromScale(0, 1)
	renderBoard()
	-- Sound cues: the bell as the gate opens and "And they're off!" just after it (so they don't
	-- stack), "Into the far turn!" as the field enters the final far turn, your hoofbeats while you ride.
	cueTo.volume, cueTo.rider, cueTo.course = if riding then 1 else 0.5, riding, courseId or "dirt"
	gallop(false)
	keyHintShown = false
	cheerArrow = nil
	countLabel.Visible = false
	-- "3, 2, 1" over the gate with a soft drum tick each, then "GO!" with the bell (D-055).
	local countFrom = GameConfig.gateCountdownSeconds
	local countRace = cueRace
	local function showCount(text: string)
		if countRace ~= cueRace or not (riding or not RaceState.watchHidden) then return end
		countLabel.Text = text
		countLabel.Visible = true
		local size = if riding then 140 else 80
		if reducedMotion() then
			countLabel.TextSize = size
			countLabel.TextTransparency = 0.7
			TweenService:Create(countLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
		else
			countLabel.TextTransparency = 0
			countLabel.TextSize = size * 0.6
			TweenService:Create(countLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = size }):Play()
		end
		task.delay(0.75, function()
			if countLabel.Text == text then
				TweenService:Create(countLabel, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
			end
		end)
	end
	for k = countFrom, 1, -1 do
		local at = start - k
		if at > serverNow() - 0.9 then -- a late start event still shows "3" (a moment late)
			task.delay(math.max(0, at - serverNow()), showCount, tostring(k))
			cue(at, "count_tick")
		end
	end
	task.delay(math.max(0, start - serverNow()), showCount, "GO!")
	cue(start, "gate_bell")
	cue(start + 0.25, "vo_off")
	if riding and Sound then
		local id = cueRace
		task.delay(math.max(0, start - serverNow()), function()
			if id == cueRace and seated() then gallop(true) end
		end)
	end
	if burstOpen then
		local tTop = burstOpen - GameConfig.burstAfterTurnSeconds
		local cfg = TrackLayout.courses[courseId or "dirt"] or TrackLayout.churchill
		local tFar = tTop - math.pi * TrackLayout.laneRadius(cfg, 1) / GameConfig.raceSpeedStudsPerSecond
		finishAt = tTop + cfg.finishFromTop / GameConfig.raceSpeedStudsPerSecond
		if tFar > start + 4 then cue(tFar, "vo_far_turn") end
	end
	if riding then
		setJumping(false)
		-- The camera moves into the saddle at "3", once the server has seated you.
		local id = cueRace
		task.spawn(function()
			task.wait(math.max(0, start - countFrom - serverNow()))
			while id == cueRace and not seated() and serverNow() < start + 1 do task.wait(0.05) end
			if id == cueRace and seated() then
				Cam.ride(true)
				setJumping(false) -- again: leaving the other course's horse may have brought the controls back
				-- (AAA Phase 4, D-069) The gate line-up pass, then the chase view before GO (riders only; never
				-- under Reduced Motion; a late seat skips it).
				if myLaneIndex then
					require(script.Parent:WaitForChild("GateIntro")).run(start, courseId, myLaneIndex, function()
						return id == cueRace and seated()
					end)
				end
			end
		end)
	end
	task.spawn(function()
		-- YOU marker over your own horse (TrackScene builds it just before this event).
		local myLane = nil
		for i, lane in laneList do
			if lane.id == myId then myLane = i end
		end
		local track = nil
		for _ = 1, 50 do
			track = RaceState.trackFolder(courseId)
			if track then break end
			task.wait(0.1)
		end
		local horseFolder = track and track:WaitForChild("Horses", 5)
		local horse = myLane and horseFolder and horseFolder:WaitForChild("Lane" .. myLane, 5)
		if not horse or horse:FindFirstChild("YouMarker") then return end
		local bb = Instance.new("BillboardGui")
		bb.Name = "YouMarker"
		bb.Size = UDim2.fromOffset(90, 120)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
		bb.AlwaysOnTop = true
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 0.75)
		img.BackgroundTransparency = 1
		img.Parent = bb
		local youPlace = Instance.new("TextLabel")
		youPlace.Name = "Place"
		youPlace.Size = UDim2.fromScale(1, 0.28)
		youPlace.Position = UDim2.fromScale(0, 0.72)
		youPlace.BackgroundTransparency = 1
		youPlace.Font = Enum.Font.GothamBlack
		youPlace.TextScaled = true
		youPlace.TextColor3 = Color3.fromHex("FFD34D")
		youPlace.TextStrokeTransparency = 0
		youPlace.Text = ""
		youPlace.Parent = bb
		youMarkerPlace = youPlace
		if not UiArt.set(img, "you_marker") then
			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.fromScale(1, 0.5)
			txt.BackgroundTransparency = 1
			txt.Text = "YOU"
			txt.Font = Enum.Font.GothamBlack
			txt.TextScaled = true
			txt.TextColor3 = Color3.fromRGB(255, 220, 80)
			txt.TextStrokeTransparency = 0
			txt.Parent = bb
		end
		bb.Parent = horse
		require(script.Parent:WaitForChild("RaceHudStyle")).youMarker(bb) -- (D-069) small and low in your chase view
	end)
end)

-- Steering (D-054 S3): your buttons and Smart Steer for this race (sent to you only), the lock
-- time, and the lock itself.
remotes:WaitForChild("SteerControls").OnClientEvent:Connect(function(shown, smart, tip, bumpTip, courseId)
	local s = steer
	if not s or s.course ~= (courseId or "dirt") or s.race ~= cueRace then return end
	s.shown, s.smart = shown == true, smart ~= false
	s.bumpTip = s.shown and bumpTip == true -- (D-057 N5) the one-time tip on your first brush
	if s.shown and tip then s.tipAt = s.start + 1.5 end
	if s.shown and RaceState.recording then RaceState.recording.steer = true end -- the replay draws your line
	bindSteer(s.shown)
	if padRace ~= s.shown then
		padRace = s.shown
		steerLayout() -- (D-066) the slider moves clear of the pad before the gate
	end
	armBell(s)
end)
-- Your own lane from the server (D-057 N4): only riders with the buttons hear it, so spectators
-- and a rider's first races show none of this. A dropped wait wobbles its arrow; a wait that ends
-- in the move says "Gap!".
remotes:WaitForChild("SteerLane").OnClientEvent:Connect(function(tgt, dest, ack, wait, waitAt, tucking, inSide, outSide, stateT, courseId)
	local s = steer
	if not s or s.course ~= (courseId or "dirt") or s.race ~= cueRace or not s.shown or s.locked then return end
	local lane = s.lane or {}
	lane.tgt, lane.dest, lane.ack, lane.wait, lane.waitAt = tgt, dest, ack, wait or 0, waitAt or 0
	lane.tucking, lane.inSide, lane.outSide, lane.t = tucking == true, inSide or "free", outSide or "free", stateT or 0
	s.lane = lane
	local wobble, gap = SteerHud.message(s.hud, lane, STEER, SHUD, s.pressDir, s.pressAt, s.brushAt)
	if wobble ~= 0 then wobbleArrow(wobble) end
	if gap then
		showChip("Gap!")
		if Sound then Sound.play("tap_good") end
	end
end)
-- A brush (D-057 N5): when you were the horse that pressed into another, the wait it cleared won't
-- wobble (from its arrival: the SteerLane that clears the wait comes right after it), and as your
-- screen draws it (RaceState.BrushDrawn, with the lean) a chip: the first brush you ever have (it
-- is free) the one-time tip, "Bump! Press once, then wait for a gap"; after that "No room yet"
-- under the chips' limits. The other rider hears nothing. No cost or blame words anywhere; the
-- results card shows nothing about it.
remotes:WaitForChild("SteerBrush").OnClientEvent:Connect(function(mover, _other, _dir, at, courseId)
	local s = steer
	if not s or s.course ~= (courseId or "dirt") or s.race ~= cueRace or not s.shown or s.locked or mover ~= myLaneIndex then return end
	s.brushAt = (at or serverNow()) - s.start
end)
RaceState.BrushDrawn.Event:Connect(function(courseId, mover, _at)
	local s = steer
	if not s or s.course ~= courseId or s.race ~= cueRace or not s.shown or s.locked or mover ~= myLaneIndex then return end
	local chip = SteerChips.bumped(s.chips, serverNow() - s.start, SHUD, s.bumpTip == true)
	if chip == "tip" then
		s.bumpTip = false
		showChip("Bump! Press once, then wait for a gap", SHUD.tipSeconds)
	elseif chip == "noRoom" then
		showChip("No room yet")
	end
end)
remotes:WaitForChild("TripInfo").OnClientEvent:Connect(function(enabled, lockAt, courseId)
	local s = steer
	if not s or s.course ~= (courseId or "dirt") or s.race ~= cueRace then return end
	s.lockAt = if enabled then lockAt else nil
	armBell(s)
end)
remotes:WaitForChild("TripLocked").OnClientEvent:Connect(function(courseId)
	local s = steer
	if not s or s.course ~= (courseId or "dirt") or s.race ~= cueRace or s.locked then return end
	s.locked = true
	if not s.shown then return end
	endTuck(s, serverNow()) -- tucked-in credit stops at the lock
	showChip("Lanes locked!")
	paintButtons(true)
	s.hideAt = os.clock() + SHUD.hideAfterLockSeconds
end)

remotes.PaceSchedule.OnClientEvent:Connect(function(passes, courseId)
	if not RaceState.isFocus(courseId) then return end
	paceState = { passes = passes, tapsByPass = {}, firstTap = {}, done = 0, recent = {}, burstOpen = pendingBurstOpen, race = cueRace }
end)

local function stars(score: number): number
	return if score >= 85 then 3 elseif score >= 65 then 2 elseif score >= 40 then 1 else 0
end

remotes.PaceResult.OnClientEvent:Connect(function(seg, score, labelText, courseId)
	if not RaceState.isFocus(courseId) then return end
	if RaceState.recording then
		table.insert(RaceState.recording.events, { t = serverNow(), kind = "checkpoint", stars = stars(score) })
	end
	hint.Text = string.format("Checkpoint %d: %s %d", seg, labelText, math.round(score))
end)

remotes.BurstOpened.OnClientEvent:Connect(function(seg, open, close, spec, _name, courseId)
	if not RaceState.isFocus(courseId) then return end
	pace.bar.Visible = false
	burstState = { seg = seg, open = open, close = close, spec = spec, tapped = false, race = cueRace }
	cue(open, "vo_burst")
	cue(open + ARM, "burst_whoosh") -- the whoosh says it's armed (D-066)
	feedback.Text, hint.Text = "", if riding then BURST_HINT else ""
	showResultIcon(nil)
	tapArea.Visible = riding
end)

remotes.TapResult.OnClientEvent:Connect(function(_seg, score, labelText, courseId)
	if not RaceState.isFocus(courseId) then return end
	if RaceState.recording then
		table.insert(RaceState.recording.events, { t = serverNow(), kind = "burst", label = labelText, score = score })
	end
	feedback.Text = ""
	hint.Text = "Stretch drive! Keep tapping to the line"
	showResultIcon(labelText)
	if Sound and score >= 80 then Sound.play("tap_good", 1.4) end
	celebrate(score, labelText) -- the burst is scored on arrival; the window may still be open for others
end)

remotes.BurstSparkle.OnClientEvent:Connect(function(laneIds, courseId)
	if not RaceState.isFocus(courseId) then return end
	local untilT = os.clock() + 4
	for _, id in laneIds do
		if id ~= myId then sparkleUntil[id] = untilT end
	end
	renderBoard()
	task.delay(4.1, renderBoard)
end)

-- (D-067) A preview (the stretch drive, or after the far-turn lock: the trailing `preview`) moves
-- the horses but, with hud.arrowOnPreview off, never the up or down arrows: those compare checkpoint
-- closes only (RaceFx.arrowShows), so the arrow doesn't flicker once a second.
remotes.LiveChances.OnClientEvent:Connect(function(_seg, live, courseId, preview)
	if not RaceState.isFocus(courseId) then return end
	local before = {}
	for i, v in chances do before[i] = v end
	chances = live
	renderBoard()
	local from = lastAt.from or before
	local since = os.clock() - lastAt.arrow
	for i, lane in lanes do
		if lane.id == myId and from[i] and RaceFx.arrowShows(live[i] - from[i], preview == true, since, HUD) then
			if UiArt.set(chanceArrow, if live[i] > from[i] then "chance_up" else "chance_down") then
				arrowUntil = os.clock() + 2
				lastAt.arrow = os.clock()
			end
		end
		if lane.id == myId and HUD.boardShowsChance then -- off by default: the badge arrow says it (D-055)
			local delta = math.round((live[i] - (before[i] or 0)) * 100)
			local sign = delta >= 0 and "+" or ""
			status.Text = string.format("%s: %d%% (%s%d)", ThemePack.words.winChance, math.round(live[i] * 100), sign, delta)
		end
	end
	-- Watching: the rider you cheered gets an up or down arrow on the board (the same rule).
	local cheered = RaceState.myCheer()
	if not riding and cheered and from[cheered] and live[cheered]
		and RaceFx.arrowShows(live[cheered] - from[cheered], preview == true, since, HUD) then
		cheerArrow = { up = live[cheered] > from[cheered], untilT = os.clock() + 3 }
		lastAt.arrow = os.clock()
		renderBoard()
	end
	-- The next arrow compares against this checkpoint (or, with arrows on previews, this one too).
	if preview ~= true or HUD.arrowOnPreview == true then lastAt.from = table.clone(live) end
end)

remotes:WaitForChild("RaceAborted").OnClientEvent:Connect(function(courseId)
	if not RaceState.isFocus(courseId) then return end
	-- The server hit an error mid-race: clear the race screens and give control back.
	cueRace += 1
	clearSteer()
	gallop(false)
	paceState, burstState, coach = nil, nil, nil
	finishSeq = nil
	endOrbit()
	clearFinishFx()
	hideMeters()
	burstBanner.Visible, results.Visible, placeBadge.Visible = false, false, false
	RaceState.resultsOpen, RaceState.holdFocus = false, false
	if riding then
		Cam.ride(false)
		setJumping(true)
		RaceState.resultsPending = false
		RaceState.ResultsShown:Fire(false) -- no results card is coming
	end
	riding = false
	status.Text = "That race stopped early. Sorry! Tap RACE! to try again."
end)

remotes.IntegrityNote.OnClientEvent:Connect(function(text)
	hint.Text = text -- private; the "Ask for a check" button needs review tooling (not built)
end)

local rideReport = nil -- { stars, gain, place }
local rideRank = nil   -- your ride score's rank, sent only for the top 3 (RideRank, D-067)
local shownSummary, shownRace = nil, nil -- what the card shows (refreshed if your report comes late)

-- The finish moment (AAA Phase 2, D-067, GameConfig.finish) ---------------------------------------
-- On the rider's own screen only. As your horse crosses the line: confetti and a gold outline for
-- 1st, the ribbon stamping onto the screen for 1st to 4th, and the camera arcing from behind your
-- horse to the replay's side view (RaceState.sideRig) over orbitSeconds while the field gallops out.
-- Any tap skips to the card; the card is up at the latest cardWithinSeconds after the leader's
-- crossing (RaceFx.cardAt), and the camera holds the side view on your horse behind it. Reduced
-- Motion: no orbit and no confetti, the world dims and the card fades in. Drawn only: nothing here
-- reads or changes a score, the order or the result (the summary is already the result).
local FIN = GameConfig.finish or { enabled = false }
local Finish = require(script.Parent:WaitForChild("FinishMoment")) -- the stamp, the win glow and confetti, the orbit
-- finishSeq = { race, summary, place, lane, course, leaderAt, phase ("wait" | "play" | "card"), crossAt, cardAt,
--   orbiting, orbitFrom, from, skip }

-- The camera leaves the orbit: back behind your horse if you're still in the saddle.
endOrbit = function()
	local seq = finishSeq
	if seq then seq.orbiting = false end
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Scriptable then
		local replay = player.PlayerGui:FindFirstChild("ReplayUI")
		if not (replay and replay.Enabled) then -- (the replay owns the camera while it plays)
			camera.CameraType = if seated() and Cam.on then Enum.CameraType.Follow else Enum.CameraType.Custom
			camera.FieldOfView = if Cam.on then Cam.RIDE_FOV else Cam.NORMAL_FOV
		end
	end
end

-- (N4) The finish's pieces go, and a Reduced Motion dim left up with no card on screen goes too.
clearFinishFx = function()
	Finish.clear()
	if not results.Visible then Card.dim.Visible = false end
end

-- Your horse is over the line (or the wait ran out): the moment starts.
local function startFinish(seq, t: number)
	seq.phase, seq.crossAt = "play", t
	local still = reducedMotion()
	seq.cardAt = RaceFx.cardAt(t, seq.leaderAt, FIN, still)
	placeBadge.Visible = false
	Cam.clearKicks()
	local horse = Finish.horse(seq.course, seq.lane)
	if seq.place == 1 and horse then Finish.win(horse, still) end
	if seq.place and seq.place <= 4 and FIN.stamp ~= false then Finish.stamp(seq.place, still) end
	local camera = workspace.CurrentCamera
	if FIN.orbit ~= false and not still and camera and Cam.on and seated() and horse then
		camera.FieldOfView = Cam.RIDE_FOV
		camera.CameraType = Enum.CameraType.Scriptable
		seq.orbiting, seq.orbitFrom, seq.from = true, t, nil
		Finish.hideYou(horse) -- (the YOU marker would clutter the side view)
	end
	if still then -- a simple fade: the world dims over fadeSeconds, then the card shows
		Card.dimIn()
	end
end

-- The results card's contents for this summary (your report and ride rank too, if they've come).
local function fillCard(summary)
	local mine = nil
	for _, row in summary do
		if row.id == myId then mine = row end
	end
	local horse = if mine then mine.name else ""
	-- The headline: the place under its ribbon, and a kind line for every place (D-067).
	local place = if rideReport and rideReport.place then rideReport.place elseif mine then mine.place else nil
	if GameConfig.results.headline ~= false and place then
		Card.headText.Text = ResultsText.headline(place, if rideReport then rideReport.stars else nil)
		local ribbon = Card.RIBBONS[place]
		Card.headRibbon.Visible = ribbon ~= nil and UiArt.set(Card.headRibbon, ribbon)
		Card.cheerText.Text = ResultsText.cheer(place, if rideReport then rideReport.stars else nil, horse)
	else
		Card.headText.Text, Card.cheerText.Text = if place then "" else "Results", ""
		Card.headRibbon.Visible = false
	end
	-- "Best ride" for the top 3 only, and only with a ride of rankMinStars or more (never beside ★☆☆).
	local rankOk = GameConfig.results.riderRank ~= false and rideReport ~= nil
		and (rideReport.stars or 0) >= (GameConfig.results.rankMinStars or 0)
	Card.rankText.Text = if rankOk then ResultsText.rankLine(rideRank) else ""
	-- Top four with ribbons, plus your own place if you finished lower.
	local shown = {}
	for _, row in summary do
		if row.place <= 4 then table.insert(shown, row) end
	end
	for _, row in summary do
		if row.id == myId and row.place > 4 then table.insert(shown, row) end
	end
	table.sort(shown, function(a, b) return a.place < b.place end)
	for i, r in Card.rows do
		local row = shown[i]
		if row then
			local cash = row.cash > 0 and string.format("  +%d", row.cash) or ""
			local you = row.id == myId and "  ◀ YOU" or ""
			r.text.Text = string.format("%d. %s%s%s", row.place, row.name, cash, you)
			r.text.TextColor3 = if row.id == myId then Card.WARM else Card.INK
			if not (Card.RIBBONS[row.place] and UiArt.set(r.icon, Card.RIBBONS[row.place])) then r.icon.Visible = false end
		else
			r.text.Text = ""
			r.icon.Visible = false
		end
	end
	-- One row (D-064): your ride in stars (the trip folded in for riders with the steering
	-- buttons), then "Your taps gained Comet N places!" only if it's a gain.
	if rideReport then
		-- (AAA Phase 4, D-069) the stars count in as the card shows: ResultsCard writes "You rode ★★☆"
		Card.setRide(ResultsText.rowStars(rideReport.stars, rideReport.tripStars, STEER.scale, TRIP_ROW))
		Card.gainLine.Text = ResultsText.gainedLine(horse, rideReport.gain, rideReport.tripGain, STEER.scale)
		Card.tripRowLine.Text = if TRIP_ROW then ResultsText.tripLine(rideReport.tripStars, STEER.scale) or "" else ""
	else
		Card.setRide(nil)
		Card.gainLine.Text, Card.tripRowLine.Text = "", ""
	end
	-- 🏁 Race again (your own card only): what RACE! would join now, and it says Practice when it is.
	Card.againBtn.Visible = GameConfig.results.raceAgain ~= false and rideReport ~= nil
	if Card.againBtn.Visible then
		local h = PlayerState.activeHorse()
		Card.againKind = ResultsText.nextKind(h, GameConfig.energy, PlayerState.data and PlayerState.data.horses,
			GameConfig.results.feedWhenNapping == true)
		Card.againBtn.Text = ResultsText.raceAgainLabel(Card.againKind, h and h.name)
	end
	local hasRecording = RaceState.recording ~= nil and #RaceState.recording.frames > 10
	Card.watchBtn.Visible, Card.fullBtn.Visible = hasRecording, hasRecording
	Card.doneBtn.Visible = true
	Card.layout()
end

local function closeResults()
	results.Visible = false
	RaceState.resultsOpen, RaceState.holdFocus = false, false
	finishSeq = nil
	clearFinishFx()
	remotes.Dismount:FireServer()
	Cam.ride(false)
	setJumping(true)
	RaceState.releaseMyRace()
end
Card.doneBtn.Activated:Connect(function()
	if Card.ready() then closeResults() end
end)
-- 🏁 Race again (D-067): off the race horse, then what RACE! does (Hud: the same league's line, the
-- Cup past the ceiling, Practice while napping). Not a purchase prompt (D-050 unaffected).
Card.againBtn.Activated:Connect(function()
	if not Card.ready() then return end
	closeResults()
	if Card.againKind == "feed" then -- (napping, nothing else ready) to the stall to feed it
		Card.goStable()
		return
	end
	local events = ReplicatedStorage:FindFirstChild("HudEvents")
	local press = events and events:FindFirstChild("PressRace")
	if press and press:IsA("BindableEvent") then press:Fire() end
end)
-- The card hides while a replay plays; if the replay can't start, ReplayClosed brings it back. The
-- replay takes the camera from the finish moment's side view.
local function replay(mode: string)
	if not Card.ready() then return end
	if finishSeq then finishSeq.orbiting = false end
	clearFinishFx()
	results.Visible = false
	RaceState.ReplayRequested:Fire(mode)
end
Card.watchBtn.Activated:Connect(function() replay("finish") end)
Card.fullBtn.Activated:Connect(function() replay("full") end)
RaceState.ReplayClosed.Event:Connect(function()
	if RaceState.resultsOpen then
		endOrbit()
		results.Visible = true -- back to the results card, not the lobby
		Card.shownAt = os.clock()
		Card.dimIn()
	end
end)

-- (stars, gain, place, course), or for a rider with the steering buttons (D-054) (stars, gain,
-- place, trip stars, places the trip gained, course): ResultsText.rideReport.
remotes.RideReport.OnClientEvent:Connect(function(starCount, gain, finishPlace, a, b)
	rideReport = ResultsText.rideReport(starCount, gain, finishPlace, a, b)
	if RaceState.recording then RaceState.recording.ride = rideReport end
	if results.Visible and shownSummary and shownRace == cueRace then fillCard(shownSummary) end -- (it came late)
end)
-- "Best ride in the race!" (D-067): sent only when your ride score is 1st to 3rd in the race.
remotes:WaitForChild("RideRank").OnClientEvent:Connect(function(rank, courseId)
	if courseId ~= nil and RaceState.myCourse ~= nil and courseId ~= RaceState.myCourse then return end
	rideRank = if type(rank) == "number" and rank >= 1 and rank <= 3 then rank else nil
	if results.Visible and shownSummary and shownRace == cueRace then fillCard(shownSummary) end
end)

local function showResults(summary, raceId: number)
	if not rideReport and RaceState.watchHidden then return end -- a spectator who didn't see the finish
	if raceId ~= cueRace then -- the HUD has moved on to another race
		if RaceState.resultsPending then
			RaceState.resultsPending = false
			RaceState.ResultsShown:Fire(false)
		end
		return
	end
	Finish.hideStamp() -- the card's headline carries the ribbon now
	shownSummary, shownRace = summary, raceId
	fillCard(summary)
	Card.show(reducedMotion()) -- the world dims and the card rises in (Reduced Motion: it just shows)
	RaceState.resultsOpen = true
	RaceState.holdFocus = rideReport ~= nil -- your own card keeps the HUD until Done
	if raceId == cueRace then cue(0, "vo_finish") end -- "What a finish!", only if the HUD still follows this race
	if RaceState.resultsPending then -- your own card: the Hud's coin chime plays now, with it
		RaceState.resultsPending = false
		RaceState.ResultsShown:Fire(true)
	end
	placeBadge.Visible = false
	status.Text = "Results"
	feedback.Text, hint.Text = "", ""
	showResultIcon(nil)
end

-- Each frame of the finish moment: wait for your horse to cross, run the orbit, show the card on
-- time (or at once on a skip), then hold the side view behind the card until it closes.
local function stepFinish(t: number)
	local seq = finishSeq
	if not seq then return end
	if seq.race ~= cueRace then -- the HUD moved on (a new race): no moment, no card for this one
		finishSeq = nil
		endOrbit()
		clearFinishFx()
		if RaceState.resultsPending then -- the Hud's held coin chime: no card is coming
			RaceState.resultsPending = false
			RaceState.ResultsShown:Fire(false)
		end
		return
	end
	if seq.phase == "wait" then
		if (RaceState.progress[seq.lane] or 0) >= 1 or t >= seq.leaderAt + (FIN.crossWaitSeconds or 1.5) then
			startFinish(seq, t)
		end
	elseif seq.phase == "play" and (seq.skip or t >= seq.cardAt) then
		seq.phase = "card"
		showResults(seq.summary, seq.race)
	end
	if seq.orbiting and finishSeq == seq then Finish.orbitFrame(seq, t) end
end
RunService.RenderStepped:Connect(function()
	stepFinish(serverNow())
end)
-- Any tap while the moment plays skips to the card (the orbit carries on behind it).
UserInputService.InputBegan:Connect(function(input)
	local seq = finishSeq
	if not seq or seq.phase ~= "play" then return end
	-- (the feel consult) Not in the first finish.skipAfterSeconds: a reflex tap from the stretch drive.
	if serverNow() - (seq.crossAt or 0) < (FIN.skipAfterSeconds or 0) then return end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 or TAP_KEYS[input.KeyCode] then
		seq.skip = true
	end
end)

remotes.RaceFinished.OnClientEvent:Connect(function(summary, courseId)
	if not RaceState.isFocus(courseId) then return end
	-- The horses run home first (RaceView), then the results; riders are dismounted 3 s later.
	hideMeters()
	clearSteer()
	paceState, burstState = nil, nil
	feedback.Text, hint.Text = "", ""
	showResultIcon(nil)
	coach = nil
	local id = cueRace
	task.delay(math.max(0, finishAt - serverNow()), function()
		if id == cueRace then status.Text = "And they're home!" end -- as the leader reaches the line
	end)
	cue(finishAt, "finish_fanfare", "crowd_cheer")
	rideReport, rideRank = nil, nil
	if riding and FIN.enabled ~= false and myLaneIndex then
		-- Your own race: the finish moment as your horse crosses, then the card (D-067).
		local place = nil
		for _, row in summary do
			if row.id == myId then place = row.place end
		end
		finishSeq = { race = cueRace, summary = summary, place = place, lane = myLaneIndex, course = courseId or "dirt",
			leaderAt = if finishAt > serverNow() - 5 then finishAt else serverNow() + 1, phase = "wait" }
	else
		task.delay(GameConfig.runInSeconds, showResults, summary, cueRace)
	end
	if riding then
		RaceState.resultsPending = true -- the Hud holds the coin chime for the results card
		-- Riders stay on their horse for the results and replay; Done gets them off. The
		-- server also dismounts everyone after a timeout, so restore the camera then too.
		task.delay(GameConfig.dismountTimeoutSeconds + 0.5, function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.SeatPart == nil and not (RaceState.active and RaceState.myLane) then
				finishSeq = nil
				endOrbit()
				clearFinishFx()
				Cam.ride(false)
				setJumping(true)
				results.Visible = false
				RaceState.resultsOpen, RaceState.holdFocus = false, false
				RaceState.releaseMyRace()
			end
		end)
	end
	riding = false
end)
