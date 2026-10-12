--!nonstrict
-- FinishMoment (AAA Phase 2, D-067, GameConfig.finish): what the finish moment draws on the rider's
-- own screen. RaceController decides when (as your horse crosses the line, skippable, the card up
-- within finish.cardWithinSeconds of the leader's crossing); this module draws:
--   the ribbon stamp for 1st to 4th (the ribbon art, or a disc in its colour until the art loads),
--   stamping in from big (Reduced Motion: it just shows);
--   for 1st, a gold outline on your horse and confetti bursting over it (no confetti under Reduced
--   Motion);
--   the orbit: the camera arcs from where the chase camera was, relative to the track's heading at
--   your horse, to the replay's side view (RaceState.sideRig, RaceFx.orbit) over orbitSeconds, then
--   holds it while the field gallops out behind the card.
-- AAA Phase 4 (D-069): paper confetti (the confetti_square image, published by AssetService as the
-- ReplicatedStorage attribute UiSheet_confetti_square; the built-in sparkle until it's there) in the
-- art direction's colours, and the ribbon placeholders in the D-016 ribbon colours.
-- Drawn only: nothing here reads or changes a score, the order or the result.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RaceFx = require(Shared:WaitForChild("RaceFx"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

local FIN = GameConfig.finish or {}
local RIBBONS = { "ribbon_blue", "ribbon_red", "ribbon_yellow", "ribbon_white" }
-- ART_DIRECTION ribbons (D-016): Blue, Red, Yellow, White.
local RIBBON_RGB = { Color3.fromHex("2F6FDE"), Color3.fromHex("E0474C"), Color3.fromHex("FFD23F"), Color3.fromHex("FFFFFF") }
local INK = Color3.fromHex("1D2433")
-- Paper in the art direction's colours: Giddy-up orange, Gold, Sky, Teal, ribbon Blue and ribbon Red.
local CONFETTI = { Color3.fromHex("FF9F1C"), Color3.fromHex("FFD23F"), Color3.fromHex("8ED6FF"), Color3.fromHex("17A398"),
	Color3.fromHex("2F6FDE"), Color3.fromHex("E0474C") }
-- The confetti_square image once AssetService has published it; the built-in sparkle until then.
local function confettiTexture(): string
	local id = ReplicatedStorage:GetAttribute("UiSheet_confetti_square")
	if type(id) == "number" and id ~= 0 then return "rbxassetid://" .. id end
	return FIN.confettiFallback or "rbxasset://textures/particles/sparkles_main.dds"
end

local Finish = {}

-- The stamp, on its own screen just over the race HUD (under the results card).
local gui = Instance.new("ScreenGui")
gui.Name = "RaceFinish"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local stamp = Instance.new("Frame")
stamp.AnchorPoint = Vector2.new(0.5, 0.5)
stamp.Size = UDim2.fromOffset(150, 188)
local AT = FIN.stampAt or { 0.22, 0.30 }
stamp.Position = UDim2.new(AT[1], 0, AT[2], 0) -- the upper-left third: the orbit frames your horse in the middle
stamp.BackgroundTransparency = 1
stamp.Visible = false
stamp.Parent = gui
local art = Instance.new("ImageLabel")
art.Size = UDim2.fromScale(1, 1)
art.BackgroundTransparency = 1
art.ScaleType = Enum.ScaleType.Fit
art.ZIndex = 2
art.Parent = stamp
local disc = Instance.new("Frame")
disc.AnchorPoint = Vector2.new(0.5, 0.5)
disc.Position = UDim2.fromScale(0.5, 0.4)
disc.Size = UDim2.fromOffset(130, 130)
disc.ZIndex = 2
disc.Visible = false
disc.Parent = stamp
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = disc
local discStroke = Instance.new("UIStroke")
discStroke.Thickness = 5
discStroke.Color = INK
discStroke.Parent = disc
local word = Instance.new("TextLabel")
word.Size = UDim2.new(1, 0, 0, 56)
word.Position = UDim2.new(0, 0, 0.4, -28)
word.BackgroundTransparency = 1
word.Font = Enum.Font.GothamBlack
word.TextSize = 48
word.TextStrokeTransparency = 0
word.ZIndex = 3
word.Parent = stamp
local stampScale = Instance.new("UIScale")
stampScale.Parent = stamp

function Finish.stamp(place: number, still: boolean)
	if not RIBBONS[place] then return end
	stamp.Visible = true
	stamp.Rotation = -8
	disc.Visible = not UiArt.set(art, RIBBONS[place])
	disc.BackgroundColor3 = RIBBON_RGB[place]
	word.Text = RaceState.ordinal(place)
	-- Ink on the light ribbons (yellow, white), white on blue and red (N6: contrast).
	word.TextColor3 = if place >= 3 then INK else Color3.new(1, 1, 1)
	word.TextStrokeColor3 = if place >= 3 then Color3.new(1, 1, 1) else INK
	local k = RaceState.hudScale() -- smaller on a phone, like the rest of the race HUD
	if still then
		stampScale.Scale = k
	else
		stampScale.Scale = 1.8 * k
		TweenService:Create(stampScale, TweenInfo.new(FIN.stampSeconds or 0.35, Enum.EasingStyle.Back), { Scale = k }):Play()
	end
	-- Its own sound (the consult: not the button click): the job-done chime, and for 1st a second
	-- cheer from the crowd as you cross.
	if Sound then
		Sound.play("job_done", 1.2)
		if place == 1 then Sound.play("crowd_cheer", 0.8) end
	end
end

function Finish.hideStamp()
	stamp.Visible = false
end

-- 1st: a gold outline on your horse (until the card closes) and confetti bursting over it.
local glow: Highlight? = nil
function Finish.win(horse: Model, still: boolean)
	if glow then glow:Destroy() end
	local g = Instance.new("Highlight")
	g.FillTransparency = 1
	g.OutlineColor = Color3.fromHex("FFD23F") -- Gold
	g.OutlineTransparency = 0
	g.DepthMode = Enum.HighlightDepthMode.Occluded
	g.Adornee = horse
	g.Parent = horse
	glow = g
	if still or FIN.confetti == false then return end
	local part = horse.PrimaryPart or horse:FindFirstChildWhichIsA("BasePart", true)
	if not part then return end
	local at = Instance.new("Attachment")
	at.Parent = part -- (parented first: an unparented attachment's position is its local one)
	at.Position = Vector3.new(0, 8, 0)
	local each = math.max(1, math.floor((FIN.confettiCount or 70) / #CONFETTI))
	local texture = confettiTexture()
	local paper = string.sub(texture, 1, 13) == "rbxassetid://"
	for _, colour in CONFETTI do
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture
		e.Color = ColorSequence.new(colour)
		-- Paper doesn't glow and flutters down slower than sparkles (the square is white, tinted per colour).
		e.LightEmission = if paper then 0 else 0.3
		e.LightInfluence = if paper then 0.4 else 1
		e.Size = if paper then NumberSequence.new(0.45)
			else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.4) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(2, 3)
		e.Speed = NumberRange.new(18, 30)
		e.SpreadAngle = Vector2.new(55, 55)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, if paper then -16 else -24, 0)
		e.Drag = if paper then 1.8 else 1.2
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-220, 220)
		e.Rate = 0
		e.Parent = at
		e:Emit(each)
	end
	Debris:AddItem(at, 4)
end

-- The YOU marker over your horse (always on top) hides during the orbit, so the side view is clean.
local hiddenYou: BillboardGui? = nil
function Finish.hideYou(horse: Model)
	local you = horse:FindFirstChild("YouMarker")
	if you and you:IsA("BillboardGui") then
		you:SetAttribute("OrbitHidden", true) -- (RaceHudStyle leaves it hidden while this is set)
		you.Enabled = false
		hiddenYou = you
	end
end

-- The stamp and the gold outline go and the YOU marker comes back (the card closed, a replay, a
-- new race).
function Finish.clear()
	stamp.Visible = false
	if glow then
		glow:Destroy()
		glow = nil
	end
	if hiddenYou then
		if hiddenYou.Parent then
			hiddenYou:SetAttribute("OrbitHidden", nil)
			hiddenYou.Enabled = true
		end
		hiddenYou = nil
	end
end

function Finish.horse(courseId: string?, lane: number?): Model?
	local track = RaceState.trackFolder(courseId)
	local horses = track and track:FindFirstChild("Horses")
	return if horses and lane then horses:FindFirstChild("Lane" .. lane) :: Model? else nil
end

-- One frame of the orbit for `seq` ({ course, lane, orbitFrom, from }) at time t (the clock
-- orbitFrom is on). The camera must be Scriptable: if anything else took it (off the horse, a
-- replay), the orbit stops (seq.orbiting = false).
function Finish.orbitFrame(seq, t: number)
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Scriptable then
		seq.orbiting = false
		return
	end
	local horse = Finish.horse(seq.course, seq.lane)
	if not (horse and RaceState.plan) then return end
	local target = horse:GetPivot().Position + Vector3.new(0, 4, 0)
	local look, right, outside = RaceState.sideRig(seq.course, RaceState.plan, RaceState.progress[seq.lane] or 1,
		RaceState.lane[seq.lane] or seq.lane)
	local heading = math.atan2(look.Z, look.X)
	if not seq.from then
		local rel = camera.CFrame.Position - target
		seq.from = { a = math.atan2(rel.Z, rel.X) - heading, r = math.max(4, Vector2.new(rel.X, rel.Z).Magnitude), h = rel.Y }
	end
	local f = (t - seq.orbitFrom) / math.max(0.1, math.min(FIN.orbitSeconds or 2.5, 2.5))
	local a, r, h = RaceFx.orbit(seq.from.a, seq.from.r, seq.from.h, math.atan2(right.Z, right.X) - heading, outside, 6, f)
	local eye = target + Vector3.new(math.cos(a + heading) * r, h, math.sin(a + heading) * r)
	camera.CFrame = CFrame.lookAt(eye, target)
end

return Finish
