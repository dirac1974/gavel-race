--!nonstrict
-- RaceHudStyle (AAA Phase 4 Dev B, D-069, GameConfig.raceHud): the race HUD in the art direction's
-- colours (docs/art/ART_DIRECTION.md), applied once to the pieces RaceController builds, so its own code
-- stays as it is (it is near Luau's limit for top-level locals). Paper panels with a 3 px Ink outline,
-- Ink text on them (your own row in the darker orange that passes 4.5:1 on Paper), Fredoka One for
-- words, Builder Sans Bold for numbers, the Gold "3, 2, 1" with an Ink outline, the slider on Slate with
-- a Gold glow, the Riding bar on Slate.
-- The YOU marker (youMarker): in your own chase view it is small and low (riderStuds, riderPx), so it
-- keeps off the middle of the screen; it hides in first person and while the finish orbit plays
-- (FinishMoment marks it OrbitHidden); replays and every other view keep the big one.
-- Drawn only. STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RacePresent = require(Shared:WaitForChild("RacePresent"))
local Cam = require(script.Parent:WaitForChild("RaceCamera"))

local CFG = GameConfig.raceHud or { enabled = true }
local player = Players.LocalPlayer

local Style = {
	INK = Color3.fromHex("1D2433"),
	PAPER = Color3.fromHex("FFF7E6"),
	GOLD = Color3.fromHex("FFD23F"),
	SLATE = Color3.fromHex("2A3247"),
	YOU_TEXT = Color3.fromHex("8F4700"), -- (Ui.colors.textWarn: 4.5:1 or better on Paper)
	WHITE = Color3.new(1, 1, 1),
}

local function numberFont(): Font?
	local ok, f = pcall(function() return Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold) end)
	return if ok then f else nil
end
local NUMBERS = numberFont()

-- A 2-3 px Ink outline round a label's text that fades with the text (the countdown and banners tween
-- TextTransparency).
local function inkText(l: TextLabel?, px: number?)
	if not l then return end
	l.TextStrokeTransparency = 1
	local s = l:FindFirstChild("InkStroke") :: UIStroke?
	if not s then
		s = Instance.new("UIStroke")
		s.Name = "InkStroke"
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = l
		l:GetPropertyChangedSignal("TextTransparency"):Connect(function()
			(s :: UIStroke).Transparency = l.TextTransparency
		end)
	end
	s.Color = Style.INK
	s.Thickness = px or 2
	s.Transparency = l.TextTransparency
end

local function words(l: TextLabel?)
	if l then l.Font = Enum.Font.FredokaOne end
end
local function numbers(l: TextLabel?)
	if l and NUMBERS then
		pcall(function() l.FontFace = NUMBERS :: Font end)
	end
end

local function panel(f: Frame?)
	if not f then return end
	f.BackgroundColor3 = Style.PAPER
	f.BackgroundTransparency = 0
	local s = f:FindFirstChild("InkOutline") :: UIStroke?
	if not s then
		s = Instance.new("UIStroke")
		s.Name = "InkOutline"
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
	end
	s.Color, s.Thickness = Style.INK, 3
	if not f:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = f
	end
end

-- Text on a Paper panel: Ink, no outline (it's dark on light already).
local function onPaper(l: TextLabel?)
	if not l then return end
	l.TextColor3 = Style.INK
	l.TextStrokeTransparency = 1
end

-- The board row's colour: Ink, your own row in the dark orange.
function Style.rowColour(you: boolean): Color3
	return if you then Style.YOU_TEXT else Style.INK
end

-- parts: { board, rows, placeBadge, placeText, placeOf, pace, speed, countLabel, status, feedback, hint,
-- burstTitle, burstBanner } (any may be missing).
-- The panels are Paper even with raceHud.enabled = false (RaceController builds them Paper), so their
-- text is always Ink; enabled = false skips the fonts, outlines and slider colours.
function Style.apply(parts)
	panel(parts.board)
	for _, row in parts.rows or {} do onPaper(row) end
	panel(parts.placeBadge)
	onPaper(parts.placeText)
	onPaper(parts.placeOf)
	if CFG.enabled == false then return end
	for _, row in parts.rows or {} do words(row) end
	numbers(parts.placeText)
	words(parts.placeOf)
	-- The slider: Slate track, Ink rim, Gold glow (the placeholder until the art shows), white marker.
	local pace = parts.pace
	if pace then
		pace.bar.BackgroundColor3 = Style.SLATE
		if pace.stroke then pace.stroke.Color, pace.stroke.Thickness = Style.INK, 3 end
		pace.zone.BackgroundColor3 = Style.GOLD
		pace.zone2.BackgroundColor3 = Style.GOLD
	end
	local speed = parts.speed
	if speed then
		speed.BackgroundColor3 = Style.SLATE
		local riding = speed:FindFirstChildOfClass("TextLabel")
		words(riding)
		inkText(riding, 2)
	end
	-- Over the world: white (or Gold) words with an Ink outline.
	for _, l in { parts.status, parts.feedback, parts.hint } do
		words(l)
		inkText(l, 2)
	end
	local count = parts.countLabel
	if count then
		count.TextColor3 = Style.GOLD
		numbers(count)
		inkText(count, 3)
	end
	for _, l in { parts.burstTitle, parts.burstBanner } do
		if l then
			l.TextColor3 = Style.GOLD
			words(l)
			inkText(l, 3)
		end
	end
end

-- The YOU marker over your own horse (RaceController builds it each race) -----------------------------
local marker: BillboardGui? = nil
local function chaseView(camera: Camera): boolean
	if not Cam.on or camera.CameraType ~= Enum.CameraType.Follow then return false end
	local replay = player.PlayerGui:FindFirstChild("ReplayUI")
	return not (replay and replay:IsA("ScreenGui") and replay.Enabled)
end
function Style.youMarker(bb: BillboardGui)
	marker = bb
	if CFG.enabled == false then return end
	for _, d in bb:GetDescendants() do
		if d:IsA("TextLabel") then
			d.TextColor3 = Style.GOLD
			d.TextStrokeColor3 = Style.INK
			d.TextStrokeTransparency = 0
			numbers(d)
		end
	end
end
RunService.RenderStepped:Connect(function()
	local bb = marker
	if not bb then return end
	if not bb.Parent then
		marker = nil
		return
	end
	if CFG.enabled == false or bb:GetAttribute("OrbitHidden") then return end -- (FinishMoment brings it back)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local zoom = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	local shown, studs, w, h = RacePresent.youMarker(CFG.youMarker, chaseView(camera), zoom, false)
	if bb.Enabled ~= shown then bb.Enabled = shown end
	if bb.StudsOffsetWorldSpace.Y ~= studs then bb.StudsOffsetWorldSpace = Vector3.new(0, studs, 0) end
	if bb.Size.X.Offset ~= w or bb.Size.Y.Offset ~= h then bb.Size = UDim2.fromOffset(w, h) end
end)

return Style
