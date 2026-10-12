--!nonstrict
-- BarnDecor (D-070, provisional): builds what a stable built at Barn Builder into its plot, each at
-- the fixed spot BarnCatalog gives it, so everyone in the server (visiting friends too) sees it.
-- Things every yard already has for free are swapped for their variant at the same spot (a
-- painted trough, a flower-box wheelbarrow, a red horseshoe...), never added twice. Gold and
-- Champion pieces are painted wood, rope and bunting colours, never chrome. The weathervane is
-- built here from parts (a cupola, a pole, a compass cross and a wedge arrow under a horse
-- silhouette: the horse_silhouette image on both sides once it loads, parts until then); each
-- client turns its VaneSpin slowly (BarnBuilder client; held still with Reduced Motion).
-- Every piece is a Model named Build_<id> with BuildId, so the owner's client can drop it in when
-- they walk home to see it; barn paint parts carry Paint ("walls", "roof", "trim", "doors",
-- "plates") for the paint sweep.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("Style"))
local WorldArt = require(Shared:WaitForChild("WorldArt"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local WorldScene = require(script.Parent:WaitForChild("WorldScene"))

local part, wedge = WorldScene.part, WorldScene.wedge
local C = WorldScene.colors

local BarnDecor = {}

-- The free yard props a Barn Builder variant replaces (StableService skips the free one).
BarnDecor.SWAPS = { swapTrough = "trough", swapBarrow = "barrow", swapBucket = "bucket", swapHay = "hay", swapShoe = "horseshoe", swapPhoto = "photo" }

local FAIR = { Color3.fromHex("E5484D"), Color3.fromHex("FFD23F"), Color3.fromHex("17A398"), Color3.fromHex("56B4E9"), Color3.fromHex("FF9F1C") }
local IRON = Color3.fromHex("2B2B30") -- painted black iron, matte

-- The newest build still under greenCash.newBuildHours old, or nil (the plot's FreshBuildId).
function BarnDecor.freshId(data, now: number): string?
	local hours = (GameConfig.greenCash or {}).newBuildHours or 48
	return Style.freshBuildId(data, now, hours)
end

-- Is the free prop at `anchor` swapped for a placed variant?
function BarnDecor.swapped(data, anchor: string): boolean
	for _, it in Style.yard(data) do
		if it.build and BarnDecor.SWAPS[it.build] == anchor then return true end
	end
	return false
end

local function quiet(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanQuery, d.CanTouch = true, false, false end
	end
end

-- Repaint an uploaded model in one colour (matte painted wood or plastic; never metal).
local function tint(m: Instance, color: Color3, material: Enum.Material?)
	for _, d in m:GetDescendants() do
		if d:IsA("SurfaceAppearance") or d:IsA("Texture") then
			d:Destroy()
		elseif d:IsA("MeshPart") then
			pcall(function() (d :: any).TextureID = "" end)
			d.Color = color
			d.Material = material or Enum.Material.SmoothPlastic
		elseif d:IsA("BasePart") then
			d.Color = color
			d.Material = material or Enum.Material.SmoothPlastic
		end
	end
end

local function holder(parent: Instance, it): Model
	local m = Instance.new("Model")
	m.Name = "Build_" .. it.id
	m:SetAttribute("BuildId", it.id)
	m.Parent = parent
	return m
end

local function flowers(m: Instance, cf: CFrame, w: number, d: number, n: number)
	part({ Name = "Planter", Size = Vector3.new(w, 0.9, d), Color = C.wood, Material = Enum.Material.WoodPlanks,
		CanCollide = false, CFrame = cf * CFrame.new(0, 0.45, 0) }, m)
	part({ Name = "Soil", Size = Vector3.new(w - 0.3, 0.2, d - 0.3), Color = Color3.fromHex("6B4A2E"), Material = Enum.Material.Ground,
		CanCollide = false, CFrame = cf * CFrame.new(0, 0.95, 0) }, m)
	for k = 1, n do
		local x = (k - (n + 1) / 2) * (w - 0.6) / math.max(1, n - 1)
		local z = if k % 2 == 0 then d * 0.18 else -d * 0.18
		part({ Name = "Stem", Size = Vector3.new(0.15, 0.9, 0.15), Color = Color3.fromHex("4CAF50"), CanCollide = false,
			CFrame = cf * CFrame.new(x, 1.4, z) }, m)
		part({ Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = FAIR[(k - 1) % #FAIR + 1],
			Material = Enum.Material.SmoothPlastic, CanCollide = false, CFrame = cf * CFrame.new(x, 1.95, z) }, m)
	end
end

-- Bunting: one Beam per run, textured with the uploaded bunting_strip (WorldArt), sagging in the
-- middle. Plain fair colours until the image loads. No parts per pennant (the code review's part count).
local function pennantLine(m: Instance, a: Vector3, b: Vector3, sag: number, size: number)
	local anchor = part({ Name = "BuntingAnchor", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CanCollide = false,
		CanQuery = false, CanTouch = false, CFrame = CFrame.new((a + b) / 2) }, m)
	local function att(at: Vector3): Attachment
		local x = Instance.new("Attachment")
		x.Parent = anchor
		x.WorldPosition = at
		x.Axis, x.SecondaryAxis = Vector3.new(0, -1, 0), Vector3.new(1, 0, 0) -- curves bend down
		return x
	end
	local beam = Instance.new("Beam")
	beam.Name = "Bunting"
	beam.Attachment0, beam.Attachment1 = att(a), att(b)
	beam.Width0, beam.Width1 = size * 1.6, size * 1.6
	beam.CurveSize0, beam.CurveSize1 = sag / 0.75, -sag / 0.75 -- a Bezier sags about 3/4 of its handles
	beam.FaceCamera = true
	beam.Segments = 10
	beam.LightInfluence = 1
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 10 * size / 1.1 -- the track's tile (trackDressing.buntingTileStuds) at this width
	local keys = {}
	for k, c in FAIR do table.insert(keys, ColorSequenceKeypoint.new((k - 1) / (#FAIR - 1), c)) end
	beam.Color = ColorSequence.new(keys)
	beam.Parent = anchor
	WorldArt.whenReady("bunting_strip", function(image: string)
		if not beam.Parent then return end
		beam.Texture = image
		beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	end)
end

-- Pieces ----------------------------------------------------------------------------------------

local function tree(m: Model, cf: CFrame)
	if WorldScene.placeModel(m, "apple_tree_small", cf) then return end
	part({ Name = "Trunk", Size = Vector3.new(1.2, 6, 1.2), Color = C.trunk, Material = Enum.Material.Wood, CFrame = cf * CFrame.new(0, 3, 0) }, m)
	for k, off in { Vector3.new(0, 7.5, 0), Vector3.new(1.8, 6.6, 0.6), Vector3.new(-1.6, 6.8, -0.8) } do
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(5 - k * 0.6, 5 - k * 0.6, 5 - k * 0.6), Color = C.leaf,
			Material = Enum.Material.Grass, CanCollide = false, CFrame = cf * CFrame.new(off) }, m)
	end
	for k = 1, 6 do
		local a = k * math.pi / 3
		part({ Name = "Apple", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = Color3.fromHex("E5484D"),
			CanCollide = false, CFrame = cf * CFrame.new(math.cos(a) * 2.2, 6.2 + (k % 2) * 1.2, math.sin(a) * 2.2) }, m)
	end
end

local function logJump(m: Model, cf: CFrame)
	local turned = cf * CFrame.Angles(0, math.pi / 2, 0) -- the log lies across the way you ride
	if WorldScene.placeModel(m, "log_jump", turned) then return end
	part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 1.4, 1.4), Color = Color3.fromHex("8A5A36"),
		Material = Enum.Material.Wood, CanCollide = false, CFrame = turned * CFrame.new(0, 1.6, 0) }, m)
	for _, sd in { -1, 1 } do
		for _, lean in { -0.5, 0.5 } do
			part({ Name = "Stand", Size = Vector3.new(0.35, 2.4, 0.35), Color = C.woodLight, Material = Enum.Material.Wood, CanCollide = false,
				CFrame = turned * CFrame.new(sd * 3.4, 1.1, 0) * CFrame.Angles(lean, 0, 0) }, m)
		end
	end
end

local function trough(m: Model, cf: CFrame, color: Color3)
	local t = WorldScene.placeModel(m, "water_trough", cf)
	if t then
		tint(t, color, Enum.Material.Wood)
		local box, size = t:GetBoundingBox()
		part({ Name = "Water", Size = Vector3.new(size.X * 0.8, 0.2, size.Z * 0.6), Color = C.water, Material = Enum.Material.Glass,
			Transparency = 0.25, CanCollide = false, CFrame = box * CFrame.new(0, size.Y * 0.32, 0) }, m)
		part({ Name = "Stripe", Size = Vector3.new(size.X * 1.01, size.Y * 0.14, size.Z * 1.01), Color = Color3.fromHex("FBFBF5"),
			Material = Enum.Material.Wood, CanCollide = false, CFrame = box * CFrame.new(0, size.Y * 0.05, 0) }, m)
		return
	end
	part({ Name = "Trough", Size = Vector3.new(6, 2, 2.6), Color = color, Material = Enum.Material.Wood, CFrame = cf * CFrame.new(0, 1, 0) }, m)
	part({ Name = "Stripe", Size = Vector3.new(6.05, 0.3, 2.65), Color = Color3.fromHex("FBFBF5"), Material = Enum.Material.Wood,
		CanCollide = false, CFrame = cf * CFrame.new(0, 1.1, 0) }, m)
	part({ Name = "Water", Size = Vector3.new(5.4, 0.2, 2), Color = C.water, Material = Enum.Material.Glass, Transparency = 0.25,
		CanCollide = false, CFrame = cf * CFrame.new(0, 1.9, 0) }, m)
end

local function barrow(m: Model, cf: CFrame, color: Color3)
	local w = WorldScene.placeModel(m, "wheelbarrow", cf)
	local top = 2.6
	if w then
		tint(w, color, Enum.Material.Wood)
		local box, size = w:GetBoundingBox()
		top = box.Position.Y + size.Y / 2 - cf.Position.Y
	else
		part({ Name = "Tub", Size = Vector3.new(2.6, 1.4, 3.6), Color = color, Material = Enum.Material.Wood, CFrame = cf * CFrame.new(0, 1.6, 0) }, m)
		part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.4, 1.4), Color = C.wood,
			CFrame = cf * CFrame.new(0, 0.7, -2) }, m)
	end
	flowers(m, cf * CFrame.new(0, top - 0.6, 0), 2.2, 2.8, 5)
end

local function bucket(m: Model, cf: CFrame, color: Color3)
	local b = WorldScene.placeModel(m, "feed_bucket", cf)
	if b then
		tint(b, color, Enum.Material.SmoothPlastic)
		local box, size = b:GetBoundingBox()
		part({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.Y * 0.18, size.X * 1.02, size.Z * 1.02),
			Color = Color3.fromHex("FBFBF5"), CanCollide = false, CFrame = box * CFrame.Angles(0, 0, math.pi / 2) }, m)
		return
	end
	part({ Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 1.5, 1.5), Color = color,
		CFrame = cf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2) }, m)
	part({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.55, 1.55), Color = Color3.fromHex("FBFBF5"),
		CanCollide = false, CFrame = cf * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2) }, m)
end

local function hayWithBow(m: Model, cf: CFrame, color: Color3)
	local h = WorldScene.placeModel(m, "hay_bale", cf)
	local box, size
	if h then
		box, size = h:GetBoundingBox()
	else
		local bale = part({ Name = "HayBale", Size = Vector3.new(4, 3, 3), Color = Color3.fromHex("E8C76A"), Material = Enum.Material.Fabric,
			CFrame = cf * CFrame.new(0, 1.5, 0) }, m)
		box, size = bale.CFrame, bale.Size
	end
	part({ Name = "Ribbon", Size = Vector3.new(0.4, size.Y + 0.08, size.Z + 0.08), Color = color, Material = Enum.Material.Fabric,
		CanCollide = false, CFrame = box }, m)
	part({ Name = "Ribbon", Size = Vector3.new(size.X + 0.08, size.Y + 0.08, 0.4), Color = color, Material = Enum.Material.Fabric,
		CanCollide = false, CFrame = box }, m)
	local knot = box * CFrame.new(0, size.Y / 2 + 0.2, 0)
	part({ Name = "Knot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = color, Material = Enum.Material.Fabric,
		CanCollide = false, CFrame = knot }, m)
	for _, sd in { -1, 1 } do
		part({ Name = "Loop", Size = Vector3.new(0.9, 0.6, 0.15), Color = color, Material = Enum.Material.Fabric, CanCollide = false,
			CFrame = knot * CFrame.new(sd * 0.55, 0.1, 0) * CFrame.Angles(0, 0, sd * 0.35) }, m)
		part({ Name = "Tail", Size = Vector3.new(0.25, 0.9, 0.08), Color = color, Material = Enum.Material.Fabric, CanCollide = false,
			CFrame = knot * CFrame.new(sd * 0.3, -0.5, -0.1) * CFrame.Angles(0, 0, sd * 0.4) }, m)
	end
end

local function horseshoe(m: Model, cf: CFrame, color: Color3)
	local h = WorldScene.placeModel(m, "horseshoe_decor", cf)
	if h then
		tint(h, color, Enum.Material.SmoothPlastic)
		return
	end
	part({ Name = "ShoeBottom", Size = Vector3.new(2, 0.4, 0.3), Color = color, CanCollide = false, CFrame = cf * CFrame.new(0, 0.3, 0) }, m)
	for _, sd in { -1, 1 } do
		part({ Name = "ShoeSide", Size = Vector3.new(0.4, 2, 0.3), Color = color, CanCollide = false, CFrame = cf * CFrame.new(sd * 0.8, 1.2, 0) }, m)
	end
end

local function photo(m: Model, cf: CFrame, color: Color3)
	if not WorldScene.placeModel(m, "photo_frame_stand", cf) then
		part({ Name = "PhotoFrame", Size = Vector3.new(8, 6, 0.6), Color = Color3.fromHex("BFD7FF"), CFrame = cf * CFrame.new(0, 4.5, 0) }, m)
	end
	for _, sd in { -1, 1 } do flowers(m, cf * CFrame.new(sd * 3.2, 0, -1.2), 2.4, 1.2, 3) end
	pennantLine(m, (cf * CFrame.new(-4, 8.2, -0.5)).Position, (cf * CFrame.new(4, 8.2, -0.5)).Position, 0.6, 0.8)
	part({ Name = "PinkTop", Size = Vector3.new(8.4, 0.4, 0.8), Color = color, Material = Enum.Material.Wood, CanCollide = false,
		CFrame = cf * CFrame.new(0, 8, 0) }, m)
end

-- The hay loft: a little dormer on the front slope of the roof with two hay doors, a pulley beam
-- with a bale on a rope, and a "Hay Loft" sign. `mid` is the barn's middle (local +Z inward).
local function hayloft(m: Model, mid: CFrame, ground: number, barnH: number, barnD: number, color: Color3, roofC: Color3)
	local base = mid * CFrame.new(0, ground + barnH + 1.5, -barnD / 2 + 5) -- front face at -barnD/2 + 2
	part({ Name = "LoftBox", Size = Vector3.new(8, 5.5, 6), Color = Color3.fromHex("FBFBF5"), Material = Enum.Material.WoodPlanks,
		CFrame = base * CFrame.new(0, 2.75, 0) }, m)
	for _, sd in { -1, 1 } do
		wedge({ Name = "LoftRoof", Size = Vector3.new(7, 2.2, 4.6), Color = roofC,
			CFrame = base * CFrame.new(sd * 2.3, 5.5 + 1.1, 0) * CFrame.Angles(0, -sd * math.pi / 2, 0) }, m)
	end
	local face = base * CFrame.new(0, 0, -3.05)
	for _, sd in { -1, 1 } do
		local door = part({ Name = "HayDoor", Size = Vector3.new(1.7, 3.2, 0.2), Color = color, Material = Enum.Material.WoodPlanks,
			CanCollide = false, CFrame = face * CFrame.new(sd * 0.9, 2.2, 0) }, m)
		part({ Name = "DoorBrace", Size = Vector3.new(0.25, 3.4, 0.1), Color = Color3.fromHex("FBFBF5"), CanCollide = false,
			CFrame = door.CFrame * CFrame.new(0, 0, -0.12) * CFrame.Angles(0, 0, sd * 0.5) }, m)
	end
	part({ Name = "LoftHay", Size = Vector3.new(3.2, 0.5, 0.6), Color = Color3.fromHex("E8C76A"), Material = Enum.Material.Fabric,
		CanCollide = false, CFrame = face * CFrame.new(0, 0.55, -0.2) }, m)
	local beam = face * CFrame.new(0, 4.4, -1)
	part({ Name = "PulleyBeam", Size = Vector3.new(0.5, 0.5, 2.4), Color = C.wood, Material = Enum.Material.Wood, CanCollide = false, CFrame = beam }, m)
	part({ Name = "Rope", Size = Vector3.new(0.1, 2.6, 0.1), Color = Color3.fromHex("E8D9B5"), Material = Enum.Material.Fabric,
		CanCollide = false, CFrame = beam * CFrame.new(0, -1.3, -1) }, m)
	part({ Name = "HangingBale", Size = Vector3.new(1.4, 1, 1), Color = Color3.fromHex("E8C76A"), Material = Enum.Material.Fabric,
		CanCollide = false, CFrame = beam * CFrame.new(0, -3, -1) }, m)
	local sign = WorldScene.sign(m, (face * CFrame.new(0, 4.6, -0.4)).Position, face.LookVector, "Hay Loft", "🌾", 4.6, 1.1, Color3.fromHex("FFF4C7"))
	sign.CanCollide = false
end

-- The weathervane: on the ridge, a cupola, a pole, a fixed N/E/S/W cross and the spinning part
-- (VaneSpin: a wedge arrow, a tail and the horse silhouette above it).
local function silhouetteParts(spin: Model, at: CFrame)
	local function p(name: string, size: Vector3, cf: CFrame)
		part({ Name = name, Size = size, Color = IRON, CanCollide = false, CFrame = at * cf }, spin)
	end
	p("HorseBody", Vector3.new(2.6, 0.9, 0.12), CFrame.new(0, 0, 0))
	p("HorseNeck", Vector3.new(0.6, 1.2, 0.12), CFrame.new(1.3, 0.55, 0) * CFrame.Angles(0, 0, -0.5))
	p("HorseHead", Vector3.new(0.9, 0.45, 0.12), CFrame.new(1.85, 1.05, 0) * CFrame.Angles(0, 0, -0.25))
	p("HorseTail", Vector3.new(0.25, 1, 0.12), CFrame.new(-1.45, -0.1, 0) * CFrame.Angles(0, 0, 0.6))
	for k, x in { -1, -0.75, 0.75, 1.05 } do
		p("HorseLeg", Vector3.new(0.2, 1.1, 0.12), CFrame.new(x, -0.9, 0) * CFrame.Angles(0, 0, if k % 2 == 0 then 0.35 else -0.35))
	end
end

local function weathervane(m: Model, top: CFrame, roofC: Color3, trimC: Color3)
	-- the cupola on the ridge
	part({ Name = "Cupola", Size = Vector3.new(3, 2.6, 3), Color = trimC, Material = Enum.Material.WoodPlanks, CFrame = top * CFrame.new(0, 0.6, 0) }, m)
	for _, sd in { -1, 1 } do
		wedge({ Name = "CupolaRoof", Size = Vector3.new(3.6, 1.2, 1.8), Color = roofC,
			CFrame = top * CFrame.new(0, 2.5, sd * 0.9) * CFrame.Angles(0, if sd > 0 then math.pi else 0, 0) }, m)
	end
	local pole = top * CFrame.new(0, 3.1, 0)
	part({ Name = "VanePole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 0.25, 0.25), Color = IRON, CanCollide = false,
		CFrame = pole * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2) }, m)
	-- the compass cross, fixed to the world directions
	local cross = CFrame.new((pole * CFrame.new(0, 2.6, 0)).Position)
	for k, letter in { "N", "E", "S", "W" } do
		local dir = cross * CFrame.Angles(0, -(k - 1) * math.pi / 2, 0)
		part({ Name = "CompassArm", Size = Vector3.new(0.18, 0.18, 2.4), Color = IRON, CanCollide = false, CFrame = dir * CFrame.new(0, 0, -1.2) }, m)
		-- 1.2-stud plates (the feel consult): 0.7 couldn't be read from Barn Lane
		local plate = part({ Name = "CompassLetter", Size = Vector3.new(1.2, 1.2, 0.1), Color = IRON, CanCollide = false,
			CFrame = dir * CFrame.new(0, 0, -3) }, m)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local sg = Instance.new("SurfaceGui")
			sg.Face = face
			sg.CanvasSize = Vector2.new(60, 60)
			sg.LightInfluence = 0.5
			sg.Parent = plate
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = Color3.fromHex("FBFBF5")
			t.Text = letter
			t.Parent = sg
		end
	end
	-- the part that turns
	local spin = Instance.new("Model")
	spin.Name = "VaneSpin"
	local axis = CFrame.new((pole * CFrame.new(0, 4.4, 0)).Position)
	local pivot = part({ Name = "VanePivot", Size = Vector3.new(0.3, 0.3, 0.3), Color = IRON, CanCollide = false, CFrame = axis }, spin)
	spin.PrimaryPart = pivot
	part({ Name = "ArrowShaft", Size = Vector3.new(4.4, 0.18, 0.18), Color = IRON, CanCollide = false, CFrame = axis }, spin)
	for _, sd in { 1, -1 } do -- two halves of a triangle pointing +X (the way the arrow points)
		wedge({ Name = "ArrowHead", Size = Vector3.new(0.12, 0.45, 0.9), Color = IRON, CanCollide = false,
			CFrame = axis * CFrame.new(2.65, sd * 0.225, 0) * CFrame.Angles(0, -math.pi / 2, 0)
				* (if sd < 0 then CFrame.Angles(0, 0, math.pi) else CFrame.identity) }, spin)
	end
	part({ Name = "ArrowTail", Size = Vector3.new(1, 1.1, 0.12), Color = IRON, CanCollide = false, CFrame = axis * CFrame.new(-2, 0.1, 0) }, spin)
	local horseAt = axis * CFrame.new(0, 1.35, 0)
	local panel = part({ Name = "HorsePanel", Size = Vector3.new(4.2, 2.4, 0.05), Transparency = 1, CanCollide = false, CFrame = horseAt }, spin)
	local fallback = Instance.new("Model")
	fallback.Name = "HorseParts"
	silhouetteParts(fallback, horseAt)
	fallback.Parent = spin
	-- The drawn silhouette (tools/ui/make_ui_svgs.py horse_silhouette), the same on both faces.
	WorldArt.whenReady("horse_silhouette", function(image: string)
		if not panel.Parent then return end
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local d = Instance.new("Decal") -- world-lit like the parts, so the vane reads dark against the sky
			d.Name = "Silhouette"
			d.Texture = image
			d.Face = face
			d.Parent = panel
		end
		fallback:Destroy()
	end)
	spin.Parent = m
	CollectionService:AddTag(spin, "Weathervane")
end

-- The grand gate arch: the arch model painted barn white with caps in the barn's trim colour, so it
-- reads as a painted show-gate (not the Trail's log arch). Nothing in it collides: the gate stays open.
local function gateArch(m: Model, cf: CFrame, trimC: Color3)
	local arch = WorldScene.placeModel(m, "trail_gate_arch", cf)
	if arch then
		tint(arch, Color3.fromHex("FBFBF5"), Enum.Material.Wood)
		local box, size = arch:GetBoundingBox()
		for _, sd in { -1, 1 } do
			part({ Name = "PostCap", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Color = trimC, CanCollide = false,
				CFrame = box * CFrame.new(sd * (size.X / 2 - 0.9), size.Y / 2 + 0.6, 0) }, m)
		end
	else
		for _, sd in { -1, 1 } do
			part({ Name = "ArchPost", Size = Vector3.new(1.2, 13, 1.2), Color = Color3.fromHex("FBFBF5"), Material = Enum.Material.Wood,
				CanCollide = false, CFrame = cf * CFrame.new(sd * 8, 6.5, 0) }, m)
			part({ Name = "PostCap", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Color = trimC,
				CanCollide = false, CFrame = cf * CFrame.new(sd * 8, 13.6, 0) }, m)
		end
		part({ Name = "ArchTop", Size = Vector3.new(17.6, 1.4, 1.2), Color = Color3.fromHex("FBFBF5"), Material = Enum.Material.Wood,
			CanCollide = false, CFrame = cf * CFrame.new(0, 12.4, 0) }, m)
	end
	local sign = WorldScene.sign(m, (cf * CFrame.new(0, 10.4, -0.8)).Position, cf.LookVector, "Welcome!", "🏡", 7, 1.8, Color3.fromHex("B9B9F0"))
	sign.CanCollide = false
	pennantLine(m, (cf * CFrame.new(-8, 11.4, -0.9)).Position, (cf * CFrame.new(8, 11.4, -0.9)).Position, 1.2, 1)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide = false end
	end
end

-- Barn looks (one each) ------------------------------------------------------------------------

-- The painted front fence (lane side, both sides of the gate): drawn just over the white one.
function BarnDecor.fence(parent: Instance, i: number, it, ground: number, gateW: number)
	local m = holder(parent, it)
	local col = Color3.fromHex(it.color or "7EC8E3")
	local h = WorldLayout.PLOT_FRONT / 2
	for _, seg in { { -h, -gateW / 2 }, { gateW / 2, h } } do
		local x0, z0 = WorldLayout.plotPoint(i, 1, seg[1])
		local x1, z1 = WorldLayout.plotPoint(i, 1, seg[2])
		local dir = Vector3.new(x1 - x0, 0, z1 - z0)
		local len = dir.Magnitude
		if len > 0.5 then
			dir = dir.Unit
			local posts = math.max(1, math.floor(len / 10))
			for k = 0, posts do
				local p = Vector3.new(x0, 0, z0) + dir * (len * k / posts)
				part({ Name = "PaintedPost", Size = Vector3.new(0.95, 5.1, 0.95), Color = col, Material = Enum.Material.Wood,
					CanCollide = false, CFrame = CFrame.new(p.X, ground + 2.5, p.Z) }, m)
			end
			local mid = Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
			for _, y in { 2, 4 } do
				part({ Name = "PaintedRail", Size = Vector3.new(0.5, 0.7, len + 0.1), Color = col, Material = Enum.Material.Wood, CanCollide = false,
					CFrame = CFrame.lookAt(Vector3.new(mid.X, ground + y, mid.Z), Vector3.new(mid.X, ground + y, mid.Z) + dir) }, m)
			end
		end
	end
	return m
end

-- A frame round the Rosette Wall's felt panel (panelCF, width, height from StableService).
function BarnDecor.frame(parent: Instance, it, panelCF: CFrame, width: number, height: number)
	local m = holder(parent, it)
	local col, col2 = Color3.fromHex(it.color or "D5DCE6"), Color3.fromHex(it.color2 or "8A93A6")
	local t = 0.45
	for _, sd in { -1, 1 } do
		part({ Name = "FrameSide", Size = Vector3.new(t, height + 2 * t, 0.3), Color = col, Material = Enum.Material.Wood, CanCollide = false,
			CanQuery = false, CFrame = panelCF * CFrame.new(sd * (width / 2 + t / 2), 0, -0.05) }, m)
		part({ Name = "FrameTop", Size = Vector3.new(width + 2 * t, t, 0.3), Color = col, Material = Enum.Material.Wood, CanCollide = false,
			CanQuery = false, CFrame = panelCF * CFrame.new(0, sd * (height / 2 + t / 2), -0.05) }, m)
		for _, sy in { -1, 1 } do
			part({ Name = "FrameCorner", Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 0.75, 0.75), Color = col2, CanCollide = false,
				CanQuery = false, CFrame = panelCF * CFrame.new(sd * (width / 2 + t / 2), sy * (height / 2 + t / 2), -0.2) }, m)
		end
	end
	if it.id == "bb_frame_bunting" or it.id == "bb_frame_champion" then
		pennantLine(m, (panelCF * CFrame.new(-width / 2, height / 2 + t, -0.3)).Position,
			(panelCF * CFrame.new(width / 2, height / 2 + t, -0.3)).Position, 0.5, 0.6)
	end
	return m
end

-- Yard pieces ---------------------------------------------------------------------------------
-- at = { i, cf = plotCF(inward, across, y), ground, front, width, barnH, barnD, roofH, mid, propA, propB, roofC, trimC }
function BarnDecor.yard(parent: Instance, it, at)
	local m = holder(parent, it)
	local col = Color3.fromHex(it.color or "E5484D")
	local b = it.build
	if b == "tree" then
		tree(m, at.cf(it.spot[1], it.spot[2], at.ground))
	elseif b == "logJump" then
		logJump(m, at.cf(it.spot[1], it.spot[2], at.ground))
	elseif b == "swapTrough" then
		trough(m, at.cf(at.front - 6, at.propB, at.ground), col)
	elseif b == "swapBarrow" then
		barrow(m, at.cf(at.front - 14, at.propA - 6, at.ground), col)
	elseif b == "swapBucket" then
		bucket(m, at.cf(at.front - 3, -at.width / 2 + 6, at.ground), col)
	elseif b == "swapHay" then
		hayWithBow(m, at.cf(at.front - 6, at.propA, at.ground), col)
	elseif b == "swapShoe" then
		horseshoe(m, at.cf(at.front - 0.8, 0, at.ground + at.barnH + 1.5), col)
	elseif b == "swapPhoto" then
		photo(m, at.cf(54, -4, at.ground), col)
	elseif b == "hayloft" then
		hayloft(m, at.mid, at.ground, at.barnH, at.barnD, col, at.roofC)
	elseif b == "bunting" then
		local y = at.ground + at.barnH - 0.6
		local l, r, c = at.cf(at.front - 0.9, -at.width / 2, y), at.cf(at.front - 0.9, at.width / 2, y), at.cf(at.front - 0.9, 0, y + 1.2)
		pennantLine(m, l.Position, c.Position, 1.2, 1.1)
		pennantLine(m, c.Position, r.Position, 1.2, 1.1)
	elseif b == "weathervane" then
		weathervane(m, at.mid * CFrame.new(0, at.ground + at.barnH + at.roofH, 0), at.roofC, at.trimC)
	elseif b == "gateArch" then
		gateArch(m, at.cf(1, 0, at.ground), at.trimC)
	end
	quiet(m)
	-- where the piece stands, for the owner's build moment (BarnBuilder client)
	local box = m:GetBoundingBox()
	m:SetAttribute("BuildAt", box.Position)
	return m
end

return BarnDecor
