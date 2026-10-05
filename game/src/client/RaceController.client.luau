--!nonstrict
-- RaceController: prototype race UI (D-026).
-- Riders see the race in a close chase view behind their horse (scroll or pinch in for
-- first person from the saddle). The pace slider runs the whole race with no pauses: tap when the marker
-- crosses the glowing target, one tap per pass; distance from the target sets the score
-- and the speed meter fills from your last few passes. The target moves every 2-3 passes.
-- In the homestretch comes the Final Burst: one tap on a big, colourful meter that counts
-- double. Tap anywhere, any key, or any gamepad button. Drawn from the shared server
-- clock; all scoring happens on the server (this screen only predicts it for feedback).
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
local UiArt = require(script.Parent:WaitForChild("UiArt"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))

local player = Players.LocalPlayer
local myId = tostring(player.UserId)
local DEFAULT_MAX_ZOOM = 128

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function reducedMotion(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

-- While riding, a jump would throw you out of the saddle, and Space is also a tap key.
local function setJumping(enabled: boolean)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled) end
end

-- Riding camera (D-026, amended): a close chase view from just behind and above the rider,
-- a little wider than normal so nearby horses are in view, turning with the horse round
-- the bends (Follow camera). Scroll or pinch in for first person, or out for more.
local RIDE_ZOOM, RIDE_FOV, NORMAL_FOV = 14, 80, 70
local function rideCamera(on: boolean)
	local camera = workspace.CurrentCamera
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
board.Parent = gui
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
-- pace = { passes, tapsByPass = {}, done = 0, recent = {} } for the race
local paceState = nil
-- active burst = { seg, open, close, spec, tapped }
local burstState = nil

-- During a race the rows follow the running order (D-030): place, lane badge, name,
-- win chance and purse. Before the race they're in lane order.
local function renderBoard()
	local t = os.clock()
	local racing = RaceState.active and #RaceState.order > 0
	for r, row in rows do
		local i = if racing then RaceState.order[r] else r
		local lane = i and lanes[i]
		if lane then
			local you = lane.id == myId and "  ◀ YOU" or ""
			local sparkle = (sparkleUntil[lane.id] or 0) > t and " ✦" or ""
			local lead = if racing then RaceState.ordinal(r) else tostring(i)
			row.Text = string.format("%s  %s%s%s  %d%%  %s %d", lead, lane.name, sparkle, you,
				math.round((chances[i] or 0) * 100), ThemePack.words.purse, lane.purse)
			row.TextColor3 = lane.id == myId and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1)
			UiArt.set(rowBadges[r], if sparkle ~= "" then `lane_{i}_sparkle` else `lane_{i}`)
		else
			row.Text = ""
			rowBadges[r].Visible = false
		end
	end
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
	if not k then return end
	remotes.PaceTap:FireServer(t)
	local n = (paceState.tapsByPass[k] or 0) + 1
	paceState.tapsByPass[k] = n
	if n == 1 then
		paceState.firstTap[k] = t
		local labelText = GameConfig.labelFor(PaceMeter.tapScore(paceState.passes[k], t))
		feedback.Text = labelText
		showResultIcon(labelText)
		hint.Text = ""
		if labelText == "Perfect" or labelText == "Great" then
			RaceState.nudgeAt = t -- instant, luck-free nudge on your own horse (D-033)
		end
		if RaceState.recording then table.insert(RaceState.recording.events, { t = t, kind = "tap", label = labelText }) end
	else
		feedback.Text = "Too fast!"
		showResultIcon("Too fast")
		hint.Text = "One tap each time the marker crosses"
	end
end

tapArea.Activated:Connect(tap)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end -- typing in chat, menus, or a GUI button took it
	local kind = input.UserInputType
	if kind == Enum.UserInputType.Keyboard or kind == Enum.UserInputType.MouseButton1
		or kind == Enum.UserInputType.Touch or kind.Name:sub(1, 7) == "Gamepad" then
		tap()
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

RunService.RenderStepped:Connect(function()
	local t = serverNow()
	if chanceArrow.Visible and os.clock() > arrowUntil then chanceArrow.Visible = false end
	if RaceState.active and os.clock() - lastHud > 0.2 then
		lastHud = os.clock()
		renderBoard()
		local myPlace = myLaneIndex and RaceState.place[myLaneIndex]
		placeBadge.Visible = myPlace ~= nil
		if myPlace then
			placeText.Text = RaceState.ordinal(myPlace)
			placeOf.Text = string.format("of %d", RaceState.lanes)
			if youMarkerPlace then youMarkerPlace.Text = RaceState.ordinal(myPlace) end
		end
	end
	if paceState and riding then
		local passes = paceState.passes
		local k = PaceMeter.passIndex(passes, t)
		pace.bar.Visible = k ~= nil
		speed.Visible = k ~= nil
		tapArea.Visible = k ~= nil or (burstState ~= nil and not burstState.tapped)
		if k then
			local p = passes[k]
			placeMarker(pace, PaceMeter.position(p, t), p.center, false)
		end
		-- Finished passes feed the speed meter (missed or doubled count 0).
		while paceState.done < #passes and passes[paceState.done + 1].t1 <= t do
			paceState.done += 1
			local j = paceState.done
			local s = if paceState.tapsByPass[j] == 1 then PaceMeter.tapScore(passes[j], paceState.firstTap[j]) else 0
			if not paceState.tapsByPass[j] and j > 1 then
				feedback.Text = "Miss"
				showResultIcon("Miss")
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
			burst.bar.Visible, burstTitle.Visible = true, true
			local spec = burstState.spec
			placeMarker(burst, BurstMeter.position(rel, spec.sweepSeconds, spec.phase),
				BurstMeter.targetCenter(rel, spec), spec.twoTargets)
			if not reducedMotion() then
				burst.stroke.Thickness = 6 + 2 * math.abs(math.sin(t * 6)) -- pulsing gold rim (3 Hz)
			end
		elseif t > burstState.close then
			if not burstState.tapped then feedback.Text = "Missed the Final Burst!" end
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
remotes.RaceStarted.OnClientEvent:Connect(function(league, laneList, start, cond, _resultAt, burstOpen)
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
	local conditions = cond and string.format("%s · %s · %s", cond.distance, cond.surface, cond.weather) or ""
	status.Text = string.format("%s race: %s", league, conditions)
	feedback.Text, hint.Text = "", if riding then "Tap when the marker crosses the glow" else ""
	burstBanner.Visible = false
	results.Visible = false
	showResultIcon(nil)
	speedFill.Size = UDim2.fromScale(0, 1)
	renderBoard()
	if riding then
		setJumping(false)
		task.delay(math.max(0, start - serverNow() - 1), rideCamera, true)
	end
	task.spawn(function()
		-- YOU marker over your own horse (TrackScene builds it just before this event).
		local myLane = nil
		for i, lane in laneList do
			if lane.id == myId then myLane = i end
		end
		local track = workspace:WaitForChild("RaceTrack", 5)
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

remotes.PaceSchedule.OnClientEvent:Connect(function(passes)
	paceState = { passes = passes, tapsByPass = {}, firstTap = {}, done = 0, recent = {}, burstOpen = pendingBurstOpen }
end)

local function stars(score: number): number
	return if score >= 85 then 3 elseif score >= 65 then 2 elseif score >= 40 then 1 else 0
end

remotes.PaceResult.OnClientEvent:Connect(function(seg, score, labelText)
	if RaceState.recording then
		table.insert(RaceState.recording.events, { t = serverNow(), kind = "checkpoint", stars = stars(score) })
	end
	hint.Text = string.format("Checkpoint %d: %s %d", seg, labelText, math.round(score))
end)

remotes.BurstOpened.OnClientEvent:Connect(function(seg, open, close, spec)
	pace.bar.Visible = false
	burstState = { seg = seg, open = open, close = close, spec = spec, tapped = false }
	feedback.Text, hint.Text = "", if riding then "One big tap in the glow. It counts double!" else ""
	showResultIcon(nil)
	tapArea.Visible = riding
end)

remotes.TapResult.OnClientEvent:Connect(function(_seg, score, labelText)
	if RaceState.recording then
		table.insert(RaceState.recording.events, { t = serverNow(), kind = "burst", label = labelText, score = score })
	end
	feedback.Text = ""
	hint.Text = "Stretch drive! Keep tapping to the line"
	showResultIcon(labelText)
	celebrate(score, labelText) -- the burst is scored on arrival; the window may still be open for others
end)

remotes.BurstSparkle.OnClientEvent:Connect(function(laneIds)
	local untilT = os.clock() + 4
	for _, id in laneIds do
		if id ~= myId then sparkleUntil[id] = untilT end
	end
	renderBoard()
	task.delay(4.1, renderBoard)
end)

remotes.LiveChances.OnClientEvent:Connect(function(_seg, live)
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
		if lane.id == myId then
			local delta = math.round((live[i] - (before[i] or 0)) * 100)
			local sign = delta >= 0 and "+" or ""
			status.Text = string.format("%s: %d%% (%s%d)", ThemePack.words.winChance, math.round(live[i] * 100), sign, delta)
		end
	end
end)

remotes.IntegrityNote.OnClientEvent:Connect(function(text)
	hint.Text = text -- private; the "Ask for a check" button needs review tooling (not built)
end)

local rideReport = nil -- { stars, gain, place }
local function closeResults()
	results.Visible = false
	remotes.Dismount:FireServer()
	rideCamera(false)
	setJumping(true)
end
doneBtn.Activated:Connect(closeResults)
watchBtn.Activated:Connect(function()
	results.Visible = false
	RaceState.ReplayRequested:Fire("finish")
end)
fullBtn.Activated:Connect(function()
	results.Visible = false
	RaceState.ReplayRequested:Fire("full")
end)
RaceState.ReplayClosed.Event:Connect(function()
	results.Visible = true -- back to the results card, not the lobby
end)

remotes.RideReport.OnClientEvent:Connect(function(starCount, gain, finishPlace)
	rideReport = { stars = starCount, gain = gain, place = finishPlace }
	if RaceState.recording then RaceState.recording.ride = rideReport end
end)

local function showResults(summary)
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
	placeBadge.Visible = false
	status.Text = "Results"
	feedback.Text, hint.Text = "", ""
	showResultIcon(nil)
end

remotes.RaceFinished.OnClientEvent:Connect(function(summary)
	-- The horses run home first (RaceView), then the results; riders are dismounted 3 s later.
	hideMeters()
	paceState, burstState = nil, nil
	feedback.Text, hint.Text = "", ""
	showResultIcon(nil)
	status.Text = "And they're home!"
	task.delay(GameConfig.runInSeconds, showResults, summary)
	rideReport = nil
	if riding then
		-- Riders stay on their horse for the results and replay; Done gets them off. The
		-- server also dismounts everyone after a timeout, so restore the camera then too.
		task.delay(GameConfig.dismountTimeoutSeconds + 0.5, function()
			if not RaceState.active then
				rideCamera(false)
				setJumping(true)
			end
		end)
	end
	riding = false
end)
