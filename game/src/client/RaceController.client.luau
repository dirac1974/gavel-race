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
-- Placeholder shapes show until the uploaded atlas art arrives (UiArt).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
local UiArt = require(script.Parent:WaitForChild("UiArt"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

local player = Players.LocalPlayer
local myId = tostring(player.UserId)
local DEFAULT_MAX_ZOOM = 128
local HUD = GameConfig.hud
local BOUNCE = GameConfig.pace.bounceSeconds or 0
local STEER, SHUD = GameConfig.steering, GameConfig.steerHud

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Race sounds (Sound.luau) on the shared clock. Each race the HUD follows gets a new cueRace,
-- and a newer or stopped race cancels pending cues. Riders always hear their own race;
-- spectators hear it at half volume, and only near that race's course. Only riders hear
-- their own hoofbeats, and only while they're in the saddle.
local cueRace, cueVolume, cueRider, cueCourse = 0, 1, false, "dirt"
local nearCourse = RaceState.nearCourse -- within GameConfig.spectate.rangeStuds (D-052, D-055)
local function cue(at: number, ...)
	if not Sound then return end
	local id, names, volume, rider, course = cueRace, { ... }, cueVolume, cueRider, cueCourse
	task.delay(math.max(0, at - serverNow()), function()
		if id ~= cueRace then return end
		if not rider and not nearCourse(course) then return end
		for _, name in names do Sound.play(name, volume) end
	end)
end
local stopGallop = nil
local function gallop(on: boolean)
	if stopGallop then stopGallop() end
	stopGallop = if on and Sound then Sound.loop("gallop_loop") else nil
end
local function seated(): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end
player.CharacterAdded:Connect(function() gallop(false) end) -- a new character isn't in the saddle

local function reducedMotion(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
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

-- Riding camera (D-026, amended): a close chase view from just behind and above the rider,
-- a little wider than normal so nearby horses are in view, turning with the horse round
-- the bends (Follow camera). Scroll or pinch in for first person, or out for more.
local RIDE_ZOOM, RIDE_FOV, NORMAL_FOV = 14, 80, 70
local rideCamOn = false
local function rideCamera(on: boolean)
	local camera = workspace.CurrentCamera
	rideCamOn = on
	if on then
		if camera then
			camera.CameraType = Enum.CameraType.Follow
			camera.FieldOfView = RIDE_FOV
		end
		player.CameraMinZoomDistance = RIDE_ZOOM
		player.CameraMaxZoomDistance = RIDE_ZOOM -- snaps the camera to the chase distance
		task.delay(0.2, function()
			player.CameraMinZoomDistance = 0.5 -- then allow zooming in to first person
			player.CameraMaxZoomDistance = 40
		end)
	else
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = NORMAL_FOV
		end
		player.CameraMaxZoomDistance = DEFAULT_MAX_ZOOM
		player.CameraMinZoomDistance = 0.5
	end
end

-- Off the race horse for any reason (Done, the timeout, the next race on the course rebuilding
-- its horses): the normal camera and jumping come back straight away.
local function watchSeat(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	local function restore()
		if humanoid.SeatPart == nil and rideCamOn then
			rideCamera(false)
			setJumping(true)
		end
	end
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		if humanoid.SeatPart ~= nil or not rideCamOn then return end
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
	if rideCamOn then rideCamera(false) end -- a new character starts on foot
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
board.BackgroundColor3 = Color3.fromRGB(20, 30, 25)
board.BackgroundTransparency = 0.3
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
	if rainbow then
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
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
	zone.BackgroundColor3 = if rainbow then Color3.new(1, 1, 1) else Color3.fromRGB(60, 200, 90)
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
	return { bar = bar, zone = zone, zone2 = zone2, marker = marker, stroke = stroke }
end

local pace = makeMeter(0.7, 34, 0.80, false)
local burst = makeMeter(0.9, 72, 0.44, true)
-- "3, 2, 1, GO!" over the gate (D-055): big for riders, smaller for spectators.
local countLabel = label(gui, UDim2.new(1, 0, 0, 160), UDim2.new(0, 0, 0.26, 0), "", 140)
countLabel.Font = Enum.Font.GothamBlack
countLabel.TextColor3 = Color3.fromHex("FFD34D")
countLabel.TextStrokeTransparency = 0.2
countLabel.ZIndex = 9
countLabel.Visible = false
-- On keyboard devices the slider shows which key taps.
local keyCap = label(pace.bar, UDim2.fromOffset(70, 24), UDim2.new(1, 10, 0.5, -12), "SPACE", 14)
keyCap.BackgroundTransparency = 0.1
keyCap.BackgroundColor3 = Color3.fromHex("F4EFE6")
keyCap.TextColor3 = Color3.fromHex("1F2430")
keyCap.TextStrokeTransparency = 1
keyCap.ZIndex = 6
round(keyCap, UDim.new(0, 6))
keyCap.Visible = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local burstTitle = label(gui, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0.34, 0), "FINAL BURST  ×2", 52)
burstTitle.Font = Enum.Font.GothamBlack
burstTitle.TextColor3 = Color3.fromHex("FFD34D")
burstTitle.Visible = false

-- Speed meter: fills from your last few passes.
local speed = Instance.new("Frame")
speed.AnchorPoint = Vector2.new(0.5, 0)
speed.Size = UDim2.new(0.4, 0, 0, 16)
speed.Position = UDim2.new(0.5, 0, 0.75, 0)
speed.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
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
local speedGradient = Instance.new("UIGradient")
speedGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF5A5F")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFD34D")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("46C46A")),
})
speedGradient.Parent = speedFill
local speedLabel = label(speed, UDim2.new(0, 70, 1, 0), UDim2.new(0, -78, 0, 0), "SPEED", 16)
speedLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Your place in the race (D-030): big, top right under the minimap.
local placeBadge = Instance.new("Frame")
placeBadge.AnchorPoint = Vector2.new(1, 0)
placeBadge.Position = UDim2.new(1, -16, 0, 268) -- under the race map
placeBadge.Size = UDim2.fromOffset(150, 70)
placeBadge.BackgroundColor3 = Color3.fromRGB(20, 30, 25)
placeBadge.BackgroundTransparency = 0.2
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
local burstBanner = label(gui, UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.30, 0), "", 64)
burstBanner.Font = Enum.Font.GothamBlack
burstBanner.TextColor3 = Color3.fromRGB(255, 225, 90)
burstBanner.Visible = false
local rays = Instance.new("ImageLabel")
rays.AnchorPoint = Vector2.new(0.5, 0.5)
rays.Position = UDim2.new(0.5, 0, 0.30, 40)
rays.Size = UDim2.fromOffset(340, 340)
rays.BackgroundTransparency = 1
rays.ZIndex = 4
rays.Visible = false
rays.Parent = gui

-- Results panel with ribbons for 1st-4th (D-016 ribbons: Blue, Red, Yellow, White).
local RIBBONS = { "ribbon_blue", "ribbon_red", "ribbon_yellow", "ribbon_white" }
local results = Instance.new("Frame")
results.AnchorPoint = Vector2.new(0.5, 0)
results.Position = UDim2.new(0.5, 0, 0.32, 0)
results.Size = UDim2.fromOffset(360, 5 * 40 + 12)
results.BackgroundColor3 = Color3.fromRGB(20, 30, 25)
results.BackgroundTransparency = 0.25
results.ZIndex = 6
results.Visible = false
results.Parent = gui
round(results, UDim.new(0, 16))
local resultsScale = Instance.new("UIScale")
resultsScale.Parent = results

-- Small (phone) screens: the board, place badge and results card shrink with the screen, the
-- badge sits under the race map (scaled the same way), and the card moves up (D-055). The
-- steering buttons size and place themselves too (steerLayout, below).
local steerLayout: (() -> ())? = nil
local function layout()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	local k = RaceState.hudScale()
	boardScale.Scale, badgeScale.Scale, resultsScale.Scale = k, k, k
	board.Position = UDim2.new(0, 12, 0, math.floor(90 * k))
	placeBadge.Position = UDim2.new(1, -16, 0, math.floor(RaceState.MAP_TOP + (RaceState.MAP_HEIGHT + 10) * k))
	results.Position = UDim2.new(0.5, 0, if height < 500 then 0.24 else 0.32, 0)
	if steerLayout then steerLayout() end
end
local function watchViewport()
	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()
end
watchViewport()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
local rideLine = label(results, UDim2.new(1, -24, 0, 30), UDim2.new(0, 12, 0, -70), "", 26)
rideLine.ZIndex = 7
rideLine.Font = Enum.Font.GothamBlack
rideLine.TextColor3 = Color3.fromHex("FFD34D")
local gainLine = label(results, UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, -38), "", 20)
gainLine.ZIndex = 7

local function button(parent, text: string, size: UDim2, pos: UDim2, colour: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size, b.Position = size, pos
	b.BackgroundColor3 = colour
	b.Text = text
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.fromHex("1F2430")
	b.ZIndex = 8
	b.AutoButtonColor = true
	b.Parent = parent
	round(b, UDim.new(0, 12))
	return b
end
-- Replay (D-034): the same small buttons after every race; never auto-played.
local watchBtn = button(results, "↺ Watch the finish", UDim2.new(0.62, 0, 0, 40), UDim2.new(0, 10, 1, 8), Color3.fromHex("FFD34D"))
local fullBtn = button(results, "Whole race ×3", UDim2.new(0.34, 0, 0, 40), UDim2.new(0.64, 0, 1, 8), Color3.fromHex("BFD7FF"))
local doneBtn = button(results, "Done ✕", UDim2.new(0, 110, 0, 36), UDim2.new(1, -110, 0, -110), Color3.new(1, 1, 1))

local resultRows = {}
for i = 1, 5 do
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromOffset(28, 34)
	icon.Position = UDim2.new(0, 12, 0, 8 + (i - 1) * 40)
	icon.BackgroundTransparency = 1
	icon.ZIndex = 7
	icon.Visible = false
	icon.Parent = results
	local text = label(results, UDim2.new(1, -60, 0, 34), UDim2.new(0, 50, 0, 8 + (i - 1) * 40), "", 22)
	text.ZIndex = 7
	text.TextXAlignment = Enum.TextXAlignment.Left
	resultRows[i] = { icon = icon, text = text }
end

-- State ---------------------------------------------------------------------
local lanes = {}
local chances = {}
local sparkleUntil = {}
local riding = false
local myLaneIndex = nil
local youMarkerPlace: TextLabel? = nil
local lastHud = 0
local lastWatchCheck = 0
-- pace = { passes, tapsByPass = {}, done = 0, recent = {} } for the race
local paceState = nil
-- active burst = { seg, open, close, spec, tapped }
local burstState = nil

-- The running-order board (D-030, D-055). During a race the rows follow the running order;
-- before it they're in lane order. Rows show place, lane badge and name, with a ★ (and an up or
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
				star = " ★"
				if cheerArrow and cheerArrow.untilT > t then star ..= if cheerArrow.up then " ▲" else " ▼" end
			end
			local sparkle = (sparkleUntil[lane.id] or 0) > t and " ✦" or ""
			local lead = if racing then RaceState.ordinal(RaceState.place[i] or r) else tostring(i)
			local extra = if HUD.boardShowsChance
				then string.format("  %d%%  %s %d", math.round((chances[i] or 0) * 100), ThemePack.words.purse, lane.purse)
				else ""
			row.Text = string.format("%s  %s%s%s%s%s", lead, lane.name, star, sparkle, you, extra)
			row.TextColor3 = lane.id == myId and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1)
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
			zone.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
			for _, d in zone:GetDescendants() do
				if d:IsA("ImageLabel") then d.ImageColor3 = Color3.new(1, 1, 1) end
			end
		end
	end)
end

local function hideMeters()
	pace.bar.Visible, burst.bar.Visible, speed.Visible, burstTitle.Visible, tapArea.Visible = false, false, false, false, false
end

local function celebrate(score: number, labelText: string)
	burstBanner.Text = string.format("%s! %d", labelText, math.round(score))
	burstBanner.Visible = true
	burstBanner.TextTransparency = 0
	burstBanner.TextSize = 40
	TweenService:Create(burstBanner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = 64 }):Play()
	if score >= 80 and UiArt.set(rays, "burst_rays") then
		rays.ImageTransparency = 0.2
		TweenService:Create(rays, TweenInfo.new(1.8), { ImageTransparency = 1 }):Play()
	end
	if score >= 80 and not reducedMotion() then
		local camera = workspace.CurrentCamera
		if camera then
			local fov = camera.FieldOfView
			TweenService:Create(camera, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { FieldOfView = fov - 3 }):Play()
		end
	end
	task.delay(1.6, function()
		TweenService:Create(burstBanner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

local function tap()
	local t = serverNow()
	if burstState and not burstState.tapped and t >= burstState.open and t <= burstState.close then
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
		hint.Text = ""
		if labelText == "Perfect" or labelText == "Great" then
			if Sound then Sound.play("tap_good") end
			RaceState.nudgeAt = t -- instant, luck-free nudge on your own horse (D-033)
		end
		if RaceState.recording then table.insert(RaceState.recording.events, { t = t, kind = "tap", label = labelText }) end
	else
		feedback.Text = "One tap!"
		showResultIcon("Too fast")
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
local steerPad = Instance.new("Frame")
steerPad.Name = "SteerPad"
steerPad.AnchorPoint = Vector2.new(0, 1)
steerPad.BackgroundTransparency = 1
steerPad.ZIndex = 8
steerPad.Visible = false
steerPad.Parent = gui
local BUTTON_COLOUR, LOCKED_COLOUR = Color3.fromHex("F4EFE6"), Color3.fromRGB(170, 170, 170)
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
	return b
end
local inBtn, outBtn = steerButton("◀ In"), steerButton("Out ▶")

local steerChip = label(gui, UDim2.fromOffset(320, 44), UDim2.new(), "", 20)
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
local chipText = Instance.new("UITextSizeConstraint")
chipText.MaxTextSize, chipText.MinTextSize = 20, 12
chipText.Parent = steerChip
local chipPad = Instance.new("UIPadding")
chipPad.PaddingLeft, chipPad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
chipPad.Parent = steerChip
local chipScale = Instance.new("UIScale")
chipScale.Parent = steerChip

-- The ghost-thumb tip (first race with the buttons): a see-through thumb pressing ◀ In.
local thumb = label(gui, UDim2.fromOffset(64, 64), UDim2.new(), "👆", 52)
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
-- they're up, so nothing hides behind them.
steerLayout = function()
	local camera = workspace.CurrentCamera
	local w = if camera then camera.ViewportSize.X else 1280
	local size = if RaceState.phone() then SHUD.minButtonPx
		else math.max(SHUD.minButtonPx, math.floor(SHUD.buttonPx * RaceState.hudScale()))
	local gap, left = 12, 24
	steerPad.Size = UDim2.fromOffset(2 * size + gap, size)
	steerPad.Position = UDim2.new(0, left, 0.75, -8)
	inBtn.Size, outBtn.Size = UDim2.fromOffset(size, size), UDim2.fromOffset(size, size)
	inBtn.Position, outBtn.Position = UDim2.fromOffset(0, 0), UDim2.fromOffset(size + gap, 0)
	steerChip.Position = UDim2.new(0, left, 0.75, -8 - size - 10)
	steerChip.Size = UDim2.fromOffset(math.max(2 * size + gap, 320), 44)
	thumbX, thumbY = left + size / 2, -8 - size / 2
	local right = left + 2 * size + gap + 12
	if steerPad.Visible and w / 2 - 260 < right then
		feedback.Position, feedback.Size = UDim2.new(0, right, 0.62, 0), UDim2.new(1, -right - 12, 0, 46)
		hint.Position, hint.Size = UDim2.new(0, right, 0.68, 0), UDim2.new(1, -right - 12, 0, 28)
		feedbackIcon.Position = UDim2.new(0.5, (right - 12) / 2, 0.62, -2)
	else
		feedback.Position, feedback.Size = UDim2.new(0, 0, 0.62, 0), UDim2.new(1, 0, 0, 46)
		hint.Position, hint.Size = UDim2.new(0, 0, 0.68, 0), UDim2.new(1, 0, 0, 28)
		feedbackIcon.Position = UDim2.new(0.5, 0, 0.62, -2)
	end
end
layout()

-- steer = the race you ride: { race, course, start, geo (TrackLayout.phaseA), shown, smart, tipAt,
-- tipUntil, lockAt, locked, hideAt, seq, lastPress, armed (stick), turnAcc, tipped, tips,
-- tuckedFor, tuckChipAt, bellArmed }
local steer = nil

local chipToken = 0
local function showChip(text: string, seconds: number?)
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
	end
end

local function clearSteer()
	steer = nil
	chipToken += 1
	steerChip.Visible, thumb.Visible, wind.Visible = false, false, false
end

-- A press: one lane in (-1) or out (1). The server decides; your own glide starts at once.
local function steerPress(dir: number)
	local s = steer
	if not (s and s.shown and riding and not s.locked and s.race == cueRace) then return end
	local t = serverNow()
	if t < s.start or (s.lockAt and t >= s.lockAt) then return end
	s.seq += 1
	s.lastPress = os.clock()
	remotes:WaitForChild("SteerRequest"):FireServer(dir, s.seq)
	RaceState.predictSteer(dir)
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
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.Thumbstick1 or not steer then return end
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
	-- "Saved ground!" leaving a turn ridden on the rail, or well inside the field.
	for k, turn in s.geo.turns do
		local acc = s.turnAcc[k]
		if sPace >= turn[1] and sPace < turn[2] then
			acc.own += x[me] * dt
			acc.field += fieldX * dt
			acc.time += dt
		elseif sPace >= turn[2] and not acc.done then
			acc.done = true
			local own, field = acc.own / math.max(acc.time, 1e-6), acc.field / math.max(acc.time, 1e-6)
			if acc.time > 0.5 and (own < SHUD.railLane or own <= field - SHUD.belowField) then showChip("Saved ground!") end
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
	s.tuckedFor = if tucked then s.tuckedFor + dt else 0
	if s.tuckedFor >= SHUD.tuckedSeconds and os.clock() - s.tuckChipAt >= SHUD.tuckedAgainSeconds then
		s.tuckChipAt = os.clock()
		showChip("Tucked in!")
	end
	wind.Visible = s.tuckedFor >= 0.3
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
			steerPress(dir) -- steering keys and the D-pad steer and never tap (D-054, D-055)
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
	if os.clock() - lastWatchCheck > 0.25 then
		lastWatchCheck = os.clock()
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
	if RaceState.active and os.clock() - lastHud > 0.2 then
		lastHud = os.clock()
		renderBoard()
		local myPlace = myLaneIndex and RaceState.place[myLaneIndex]
		placeBadge.Visible = myPlace ~= nil and not burstUp
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
		speed.Visible = k ~= nil
		tapArea.Visible = k ~= nil or (burstState ~= nil and not burstState.tapped)
		if k then
			local p = passes[k]
			placeMarker(pace, PaceMeter.position(p, t), p.center, false)
		elseif waiting then
			placeMarker(pace, PaceMeter.position(passes[1], passes[1].t0), passes[1].center, false)
		end
		-- Finished passes feed the speed meter (missed or doubled count 0).
		while paceState.done < #passes and passes[paceState.done + 1].t1 <= t do
			paceState.done += 1
			local j = paceState.done
			local s = if paceState.tapsByPass[j] == 1 then PaceMeter.tapScore(passes[j], paceState.firstTap[j]) else 0
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
		end
	end
	if burstState then
		local rel = t - burstState.open
		if rel >= 0 and t <= burstState.close then
			local shown = riding or not RaceState.watchHidden -- not over the barn (D-055)
			burst.bar.Visible, burstTitle.Visible = shown, shown
			local spec = burstState.spec
			placeMarker(burst, BurstMeter.position(rel, spec.sweepSeconds, spec.phase),
				BurstMeter.targetCenter(rel, spec), spec.twoTargets)
			if not reducedMotion() then
				burst.stroke.Thickness = 6 + 2 * math.abs(math.sin(t * 6)) -- pulsing gold rim (3 Hz)
			end
		elseif t > burstState.close then
			if burstState.race == cueRace then cue(t, "vo_stretch") end -- "Down the stretch they come!"
			if riding and not burstState.tapped then feedback.Text = "Finish strong!" end -- riders only
			burst.bar.Visible, burstTitle.Visible = false, false
			burstState = nil
		end
	end
end)

-- Server events -------------------------------------------------------------
remotes.LobbyStatus.OnClientEvent:Connect(function(seconds)
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
		watchBtn.Visible, fullBtn.Visible = false, false
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
			tuckedFor = 0, tuckChipAt = -math.huge }
	end
	local conditions = cond and string.format("%s · %s · %s", cond.distance, cond.surface, cond.weather) or ""
	status.Text = string.format("%s race: %s%s", league, conditions, if riding then "" else "  (watching)")
	if COURSE_NAME[courseId] and not riding then status.Text = COURSE_NAME[courseId] .. " · " .. status.Text end
	feedback.Text, hint.Text = "", if riding then "Tap when the marker crosses the glow" else ""
	burstBanner.Visible = false
	results.Visible = false
	RaceState.resultsOpen, RaceState.holdFocus = false, false
	showResultIcon(nil)
	speedFill.Size = UDim2.fromScale(0, 1)
	renderBoard()
	-- Sound cues: the bell as the gate opens and "And they're off!" just after it (so they don't
	-- stack), "Into the far turn!" as the field enters the final far turn, your hoofbeats while you ride.
	cueVolume, cueRider, cueCourse = if riding then 1 else 0.5, riding, courseId or "dirt"
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
			if id == cueRace and seated() then rideCamera(true) end
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
	end)
end)

-- Steering (D-054 S3): your buttons and Smart Steer for this race (sent to you only), the lock
-- time, and the lock itself.
remotes:WaitForChild("SteerControls").OnClientEvent:Connect(function(shown, smart, tip, courseId)
	local s = steer
	if not s or s.course ~= (courseId or "dirt") or s.race ~= cueRace then return end
	s.shown, s.smart = shown == true, smart ~= false
	if s.shown and tip then s.tipAt = s.start + 1.5 end
	armBell(s)
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
	cue(open, "burst_whoosh", "vo_burst")
	feedback.Text, hint.Text = "", if riding then "One big tap in the glow. It counts double!" else ""
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

remotes.LiveChances.OnClientEvent:Connect(function(_seg, live, courseId)
	if not RaceState.isFocus(courseId) then return end
	local before = {}
	for i, v in chances do before[i] = v end
	chances = live
	renderBoard()
	for i, lane in lanes do
		if lane.id == myId and before[i] and math.abs(live[i] - before[i]) > 0.003 then
			if UiArt.set(chanceArrow, if live[i] > before[i] then "chance_up" else "chance_down") then
				arrowUntil = os.clock() + 2
			end
		end
		if lane.id == myId and HUD.boardShowsChance then -- off by default: the badge arrow says it (D-055)
			local delta = math.round((live[i] - (before[i] or 0)) * 100)
			local sign = delta >= 0 and "+" or ""
			status.Text = string.format("%s: %d%% (%s%d)", ThemePack.words.winChance, math.round(live[i] * 100), sign, delta)
		end
	end
	-- Watching: the rider you cheered gets an up or down arrow on the board.
	local cheered = RaceState.myCheer()
	if not riding and cheered and before[cheered] and live[cheered] and math.abs(live[cheered] - before[cheered]) > 0.003 then
		cheerArrow = { up = live[cheered] > before[cheered], untilT = os.clock() + 3 }
		renderBoard()
	end
end)

remotes:WaitForChild("RaceAborted").OnClientEvent:Connect(function(courseId)
	if not RaceState.isFocus(courseId) then return end
	-- The server hit an error mid-race: clear the race screens and give control back.
	cueRace += 1
	clearSteer()
	gallop(false)
	paceState, burstState = nil, nil
	hideMeters()
	burstBanner.Visible, results.Visible, placeBadge.Visible = false, false, false
	RaceState.resultsOpen, RaceState.holdFocus = false, false
	if riding then
		rideCamera(false)
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
local function closeResults()
	results.Visible = false
	RaceState.resultsOpen, RaceState.holdFocus = false, false
	remotes.Dismount:FireServer()
	rideCamera(false)
	setJumping(true)
	RaceState.releaseMyRace()
end
doneBtn.Activated:Connect(closeResults)
-- The card hides while a replay plays; if the replay can't start, ReplayClosed brings it back.
watchBtn.Activated:Connect(function()
	results.Visible = false
	RaceState.ReplayRequested:Fire("finish")
end)
fullBtn.Activated:Connect(function()
	results.Visible = false
	RaceState.ReplayRequested:Fire("full")
end)
RaceState.ReplayClosed.Event:Connect(function()
	if RaceState.resultsOpen then results.Visible = true end -- back to the results card, not the lobby
end)

-- (stars, gain, place, course), or with steering (D-054) (stars, gain, place, trip stars, places
-- the trip gained, course). The trip line on the results card comes in S4; it's kept here.
remotes.RideReport.OnClientEvent:Connect(function(starCount, gain, finishPlace, a, b)
	rideReport = { stars = starCount, gain = gain, place = finishPlace }
	if typeof(a) == "number" then rideReport.tripStars, rideReport.tripGain = a, b end
	if RaceState.recording then RaceState.recording.ride = rideReport end
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
	-- Top four with ribbons, plus your own place if you finished lower.
	local shown = {}
	for _, row in summary do
		if row.place <= 4 then table.insert(shown, row) end
	end
	for _, row in summary do
		if row.id == myId and row.place > 4 then table.insert(shown, row) end
	end
	table.sort(shown, function(a, b) return a.place < b.place end)
	for i, r in resultRows do
		local row = shown[i]
		if row then
			local cash = row.cash > 0 and string.format("  +%d", row.cash) or ""
			local you = row.id == myId and "  ◀ YOU" or ""
			r.text.Text = string.format("%d. %s%s%s", row.place, row.name, cash, you)
			r.text.TextColor3 = row.id == myId and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1)
			if not (RIBBONS[row.place] and UiArt.set(r.icon, RIBBONS[row.place])) then r.icon.Visible = false end
		else
			r.text.Text = ""
			r.icon.Visible = false
		end
	end
	-- Your ride first (stars need no reading), then places your riding gained, only if it's a gain.
	if rideReport then
		rideLine.Text = "You rode " .. string.rep("★", rideReport.stars) .. string.rep("☆", 3 - rideReport.stars)
		gainLine.Text = if rideReport.gain > 0
			then string.format("Your riding gained you %d place%s!", rideReport.gain, if rideReport.gain == 1 then "" else "s")
			else ""
	else
		rideLine.Text, gainLine.Text = "", ""
	end
	local hasRecording = RaceState.recording ~= nil and #RaceState.recording.frames > 10
	watchBtn.Visible, fullBtn.Visible = hasRecording, hasRecording
	doneBtn.Visible = true
	results.Visible = true
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

remotes.RaceFinished.OnClientEvent:Connect(function(summary, courseId)
	if not RaceState.isFocus(courseId) then return end
	-- The horses run home first (RaceView), then the results; riders are dismounted 3 s later.
	hideMeters()
	clearSteer()
	paceState, burstState = nil, nil
	feedback.Text, hint.Text = "", ""
	showResultIcon(nil)
	local id = cueRace
	task.delay(math.max(0, finishAt - serverNow()), function()
		if id == cueRace then status.Text = "And they're home!" end -- as the leader reaches the line
	end)
	cue(finishAt, "finish_fanfare", "crowd_cheer")
	task.delay(GameConfig.runInSeconds, showResults, summary, cueRace)
	rideReport = nil
	if riding then
		RaceState.resultsPending = true -- the Hud holds the coin chime for the results card
		-- Riders stay on their horse for the results and replay; Done gets them off. The
		-- server also dismounts everyone after a timeout, so restore the camera then too.
		task.delay(GameConfig.dismountTimeoutSeconds + 0.5, function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.SeatPart == nil and not (RaceState.active and RaceState.myLane) then
				rideCamera(false)
				setJumping(true)
				results.Visible = false
				RaceState.resultsOpen, RaceState.holdFocus = false, false
				RaceState.releaseMyRace()
			end
		end)
	end
	riding = false
end)
