--!nonstrict
-- WorldScene: builds the world around the racecourse from parts (D-035, WorldLayout):
-- Fair Street with its fountain, lamps and bunting; the Race Board, Feed & Seed, Vet,
-- Training Paddock and Market Corral; Barn Lane with 20 fenced stable plots; the Trail loop
-- with the meadow; the Training Ground with its oval and the paddock gymkhana's layouts (D-053;
-- clients put this week's in the arena); trees. Uploaded models (ReplicatedStorage.RaceModels) replace the
-- part-built buildings and props when they've loaded; otherwise the parts stay.
-- Barns and horses inside each plot are built by StableService.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TrainingCourses = require(Shared:WaitForChild("TrainingCourses"))
local CollisionGroups = require(script.Parent:WaitForChild("CollisionGroups"))

local WorldScene = {}

local GROUND_Y = -0.5 -- top of the ground parts
local C = {
	street = Color3.fromHex("CDB48C"),
	cobble = Color3.fromHex("BFAE95"),
	lane = Color3.fromHex("B99B6B"),
	trail = Color3.fromHex("A98756"),
	grass = Color3.fromHex("5DBB4A"),
	plotGrass = Color3.fromHex("6CC456"),
	meadow = Color3.fromHex("8ED36B"),
	white = Color3.fromHex("FBFBF5"),
	wood = Color3.fromHex("8A5A36"),
	woodLight = Color3.fromHex("C48A55"),
	red = Color3.fromHex("C0392B"),
	mint = Color3.fromHex("8FD9C4"),
	roof = Color3.fromHex("2F5D3A"),
	roofRed = Color3.fromHex("7B2D26"),
	glass = Color3.fromHex("BFE3F2"),
	ink = Color3.fromHex("1D2433"),
	gold = Color3.fromHex("FFD23F"),
	orange = Color3.fromHex("FF9F1C"),
	leaf = Color3.fromHex("3E8E3A"),
	trunk = Color3.fromHex("6B4A2E"),
	water = Color3.fromHex("5BC0EB"),
	stone = Color3.fromHex("C9C3B6"),
}
local BUNTING = { Color3.fromHex("E5484D"), Color3.fromHex("FFD23F"), Color3.fromHex("17A398"), Color3.fromHex("56B4E9"), Color3.fromHex("FF9F1C") }

WorldScene.colors = C

local function part(props, parent: Instance?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end
WorldScene.part = part

local function wedge(props, parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	w.Material = Enum.Material.SmoothPlastic
	for k, v in props do w[k] = v end
	w.Parent = parent
	return w
end
WorldScene.wedge = wedge

local function model(slot: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("RaceModels")
	local m = folder and folder:FindFirstChild(slot)
	return if m then m:Clone() else nil
end
WorldScene.model = model

-- A flat strip between two points on the ground.
local function strip(parent: Instance, x0: number, z0: number, x1: number, z1: number, width: number, color: Color3, material: Enum.Material?, lift: number?)
	local dx, dz = x1 - x0, z1 - z0
	local len = math.sqrt(dx * dx + dz * dz)
	local mid = Vector3.new((x0 + x1) / 2, GROUND_Y + (lift or 0.05), (z0 + z1) / 2)
	return part({ Name = "Path", Size = Vector3.new(width, 0.2, len + width * 0.5), Color = color, Material = material or Enum.Material.Ground,
		CanCollide = true, CFrame = CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz)) }, parent)
end

-- A sign board with big friendly text (and an emoji), facing `look`.
function WorldScene.sign(parent: Instance, pos: Vector3, look: Vector3, text: string, emoji: string?, w: number?, h: number?, color: Color3?)
	local width, height = w or 16, h or 5
	local board = part({ Name = "Sign", Size = Vector3.new(width, height, 0.6), Color = color or C.white,
		CFrame = CFrame.lookAt(pos, pos + look) }, parent)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(width * 40, height * 40)
	sg.LightInfluence = 0.2
	sg.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = C.ink
	label.Text = if emoji then emoji .. " " .. text else text
	label.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
	pad.Parent = label
	local stroke = Instance.new("SelectionBox") -- an ink outline like the UI cards
	stroke.Adornee = board
	stroke.LineThickness = 0.08
	stroke.Color3 = C.ink
	stroke.SurfaceTransparency = 1
	stroke.Parent = board
	return board, label
end

-- White rail fence from (x0,z0) to (x1,z1).
function WorldScene.fence(parent: Instance, x0: number, z0: number, x1: number, z1: number, color: Color3?)
	local dx, dz = x1 - x0, z1 - z0
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.5 then return end
	local dir = Vector3.new(dx, 0, dz).Unit
	local col = color or C.white
	local posts = math.max(1, math.floor(len / 10))
	for k = 0, posts do
		local p = Vector3.new(x0, 0, z0) + dir * (len * k / posts)
		part({ Name = "Post", Size = Vector3.new(0.8, 5, 0.8), Color = col, CFrame = CFrame.new(p.X, GROUND_Y + 2.5, p.Z) }, parent)
	end
	local mid = Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
	for _, y in { 2, 4 } do
		part({ Name = "Rail", Size = Vector3.new(0.4, 0.6, len), Color = col,
			CFrame = CFrame.lookAt(Vector3.new(mid.X, GROUND_Y + y, mid.Z), Vector3.new(mid.X, GROUND_Y + y, mid.Z) + dir) }, parent)
	end
end

function WorldScene.tree(parent: Instance, x: number, z: number, h: number, rng: Random?)
	local r = rng or Random.new(math.floor(x * 7 + z * 13))
	local trunkH = h * 0.45
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(trunkH, h * 0.09, h * 0.09), Color = C.trunk,
		Material = Enum.Material.Wood, CFrame = CFrame.new(x, GROUND_Y + trunkH / 2, z) * CFrame.Angles(0, 0, math.pi / 2) }, parent)
	local tint = C.leaf:Lerp(Color3.fromHex("6CBF3F"), r:NextNumber() * 0.6)
	for k = 1, 3 do
		local s = h * (0.55 - k * 0.08)
		local off = Vector3.new(r:NextNumber(-1, 1) * h * 0.08, trunkH + k * h * 0.13, r:NextNumber(-1, 1) * h * 0.08)
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Color = tint, Material = Enum.Material.Grass,
			CanCollide = false, CFrame = CFrame.new(x, GROUND_Y, z) + off }, parent)
	end
end

local function lamp(parent: Instance, x: number, z: number)
	local folder = ReplicatedStorage:FindFirstChild("RaceModels")
	local lantern = folder and folder:FindFirstChild("lantern_post")
	if lantern then
		local m = lantern:Clone()
		m:PivotTo(CFrame.new(x, GROUND_Y, z))
		m.Parent = parent
		return
	end
	part({ Name = "LampPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 0.8, 0.8), Color = C.ink,
		CFrame = CFrame.new(x, GROUND_Y + 6, z) * CFrame.Angles(0, 0, math.pi / 2) }, parent)
	local bulb = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Color = Color3.fromHex("FFF1B8"),
		Material = Enum.Material.Neon, CanCollide = false, CFrame = CFrame.new(x, GROUND_Y + 12.6, z) }, parent)
end

-- A string of little pennant flags between two points, sagging a bit.
local function bunting(parent: Instance, a: Vector3, b: Vector3)
	local n = math.max(4, math.floor((b - a).Magnitude / 6))
	for k = 0, n do
		local t = k / n
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2.5, 0)
		wedge({ Name = "Pennant", Size = Vector3.new(0.1, 1.6, 1.2), Color = BUNTING[(k % #BUNTING) + 1], CanCollide = false,
			CFrame = CFrame.lookAt(p, p + (b - a).Unit) * CFrame.Angles(math.pi, 0, 0) }, parent) -- flat side to the street
	end
end

-- A simple shop: walls, gable roof, door, windows, striped awning, sign. `cf` is the
-- front-centre on the ground, looking out of the shop (toward the street).
function WorldScene.shop(parent: Instance, cf: CFrame, w: number, d: number, h: number, wall: Color3, roof: Color3, awning: { Color3 }, label: string, emoji: string)
	local f = Instance.new("Model")
	f.Name = label
	local back = cf * CFrame.new(0, 0, d / 2) -- centre of the footprint
	part({ Name = "Walls", Size = Vector3.new(w, h, d), Color = wall, Material = Enum.Material.WoodPlanks, CFrame = back * CFrame.new(0, GROUND_Y + h / 2, 0) }, f)
	local roofH = h * 0.45
	for _, s in { -1, 1 } do
		wedge({ Name = "Roof", Size = Vector3.new(w + 3, roofH, d / 2 + 1.5), Color = roof,
			CFrame = back * CFrame.new(0, GROUND_Y + h + roofH / 2, s * (d / 4 + 0.75)) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0) }, f)
	end
	part({ Name = "Trim", Size = Vector3.new(w + 0.6, 0.8, d + 0.6), Color = C.white, CFrame = back * CFrame.new(0, GROUND_Y + h, 0) }, f)
	part({ Name = "Door", Size = Vector3.new(7, 10, 0.4), Color = C.wood, CFrame = cf * CFrame.new(0, GROUND_Y + 5, -0.1) }, f)
	for _, x in { -w / 2 + 8, w / 2 - 8 } do
		part({ Name = "Window", Size = Vector3.new(8, 6, 0.4), Color = C.glass, Material = Enum.Material.Glass, Transparency = 0.2,
			CFrame = cf * CFrame.new(x, GROUND_Y + h * 0.5, -0.1) }, f)
		part({ Name = "WindowFrame", Size = Vector3.new(9, 7, 0.2), Color = C.white, CFrame = cf * CFrame.new(x, GROUND_Y + h * 0.5, 0.05) }, f)
	end
	-- Striped awning over the front.
	local stripes = math.floor(w / 3)
	for k = 0, stripes - 1 do
		local x = -w / 2 + (k + 0.5) * (w / stripes)
		wedge({ Name = "Awning", Size = Vector3.new(w / stripes, 2, 5), Color = awning[(k % #awning) + 1], CanCollide = false,
			CFrame = cf * CFrame.new(x, GROUND_Y + h * 0.78, -2.5) }, f)
	end
	WorldScene.sign(f, (cf * CFrame.new(0, GROUND_Y + h + 1.5, -0.8)).Position, cf.LookVector, label, emoji, math.min(w - 6, 30), 6, C.white)
	f.Parent = parent
	return f
end

-- Put a loaded model at `cf` (bottom-centre), or return nil.
local function placeModel(parent: Instance, slot: string, cf: CFrame): Model?
	local m = model(slot)
	if not m then return nil end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end
WorldScene.placeModel = placeModel

local function placeCF(key: string): CFrame
	local p = WorldLayout.places[key]
	local pos = Vector3.new(p.x, 0, p.z)
	return CFrame.lookAt(pos, pos + Vector3.new(p.fx, 0, p.fz))
end
WorldScene.placeCF = placeCF

-- Fair Street ----------------------------------------------------------------------
local function buildFairStreet(root: Instance)
	local f = Instance.new("Folder")
	f.Name = "FairStreet"
	local Z, W = WorldLayout.STREET_Z, WorldLayout.STREET_WIDTH
	strip(f, WorldLayout.STREET_X0 - 10, Z, WorldLayout.STREET_X1, Z, W, C.street, Enum.Material.Ground)
	-- Plaza by the grandstand tunnel, with a fountain.
	part({ Name = "Plaza", Size = Vector3.new(120, 0.2, 110), Color = C.cobble, Material = Enum.Material.Cobblestone,
		CFrame = CFrame.new(WorldLayout.STREET_X0 + 58, GROUND_Y + 0.1, Z) }, f)
	local fx, fz = WorldLayout.STREET_X0 + 75, Z
	part({ Name = "FountainRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 22, 22), Color = C.stone, Material = Enum.Material.Slate,
		CFrame = CFrame.new(fx, GROUND_Y + 1.2, fz) * CFrame.Angles(0, 0, math.pi / 2) }, f)
	part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 19, 19), Color = C.water, Material = Enum.Material.Glass,
		Transparency = 0.3, CanCollide = false, CFrame = CFrame.new(fx, GROUND_Y + 2.2, fz) * CFrame.Angles(0, 0, math.pi / 2) }, f)
	part({ Name = "FountainColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 3, 3), Color = C.stone,
		CFrame = CFrame.new(fx, GROUND_Y + 4, fz) * CFrame.Angles(0, 0, math.pi / 2) }, f)
	local spray = part({ Name = "FountainSpray", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false,
		CFrame = CFrame.new(fx, GROUND_Y + 8.5, fz) }, f)
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 40
	pe.Lifetime = NumberRange.new(1, 1.6)
	pe.Speed = NumberRange.new(10, 14)
	pe.SpreadAngle = Vector2.new(18, 18)
	pe.Acceleration = Vector3.new(0, -30, 0)
	pe.Size = NumberSequence.new(0.5, 0.1)
	pe.Color = ColorSequence.new(Color3.fromHex("D8F3FF"))
	pe.Transparency = NumberSequence.new(0.2, 1)
	pe.Parent = spray
	-- Lamps and bunting along both sides of the street.
	local x = WorldLayout.STREET_X0 + 30
	local prev = nil
	while x <= WorldLayout.STREET_X1 - 20 do
		for _, s in { -1, 1 } do lamp(f, x, Z + s * (W / 2 + 2)) end
		if prev then
			for _, s in { -1, 1 } do bunting(f, Vector3.new(prev, GROUND_Y + 12, Z + s * (W / 2 + 2)), Vector3.new(x, GROUND_Y + 12, Z + s * (W / 2 + 2))) end
		end
		prev = x
		x += 60
	end
	-- Benches round the fountain, facing it; picnic tables and a hay cart by Feed & Seed.
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local pos = Vector3.new(fx + math.cos(a) * 22, GROUND_Y, fz + math.sin(a) * 22)
		WorldScene.placeModel(f, "bench", CFrame.lookAt(pos, Vector3.new(fx, GROUND_Y, fz)))
	end
	local store = WorldLayout.places.feedStore
	for k = 0, 1 do
		local pos = Vector3.new(store.x + store.w / 2 + 14 + k * 16, GROUND_Y, Z - W / 2 - 14)
		WorldScene.placeModel(f, "picnic_table", CFrame.new(pos))
	end
	WorldScene.placeModel(f, "hay_cart", CFrame.lookAt(Vector3.new(store.x - store.w / 2 - 10, GROUND_Y, Z - W / 2 - 8),
		Vector3.new(store.x - store.w / 2 - 10, GROUND_Y, Z)))
	f.Parent = root
	return f
end

local function buildPlaces(root: Instance)
	local f = Instance.new("Folder")
	f.Name = "Places"
	-- Race Board: a big wooden notice board with a roof. Stage 4 shows race cards on it.
	do
		local cf = placeCF("raceBoard")
		local m = Instance.new("Model")
		m.Name = "RaceBoard"
		local frame = placeModel(m, "race_board_frame", cf * CFrame.Angles(0, math.pi, 0))
		if not frame then
			for _, x in { -18, 18 } do
				part({ Name = "Post", Size = Vector3.new(2, 22, 2), Color = C.wood, Material = Enum.Material.Wood, CFrame = cf * CFrame.new(x, GROUND_Y + 11, 3) }, m)
			end
			part({ Name = "RoofBoard", Size = Vector3.new(42, 1.5, 7), Color = C.roofRed, CFrame = cf * CFrame.new(0, GROUND_Y + 22.5, 3) }, m)
		end
		-- The uploaded frame is 24.4 studs wide: the board fits inside it (same shape, so the cards
		-- keep their layout); the 34-stud board is for the fallback posts.
		local board = part({ Name = "Board", Size = if frame then Vector3.new(20, 8.8, 1) else Vector3.new(34, 15, 1),
			Color = Color3.fromHex("2B3A2F"), CFrame = cf * CFrame.new(0, GROUND_Y + 12, 3) }, m)
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Cards"
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(1020, 450)
		sg.Parent = board
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.fromScale(1, 0.3)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = C.gold
		title.Text = "🏁 RACE BOARD"
		title.Parent = sg
		local info = Instance.new("TextLabel")
		info.Name = "Info"
		info.Size = UDim2.fromScale(0.9, 0.55)
		info.Position = UDim2.fromScale(0.05, 0.36)
		info.BackgroundTransparency = 1
		info.Font = Enum.Font.FredokaOne
		info.TextScaled = true
		info.TextColor3 = C.white
		info.Text = "Next race: Rookie\nTap RACE! to join"
		info.Parent = sg
		local pedestal = part({ Name = "Pedestal", Size = Vector3.new(5, 4, 5), Color = C.white, Material = Enum.Material.Marble,
			CFrame = cf * CFrame.new(26, GROUND_Y + 2, 2) }, m)
		WorldScene.placeModel(m, "trophy_cup", pedestal.CFrame * CFrame.new(0, 2, 0))
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RacePrompt"
		prompt.ActionText = "Join the next race"
		prompt.ObjectText = "Race Board"
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = board
		m.Parent = f
	end
	-- Feed & Seed and the Vet (wellness clinic, D-039).
	do
		local p = WorldLayout.places.feedStore
		local cf = placeCF("feedStore")
		if placeModel(f, "feed_store", cf * CFrame.new(0, GROUND_Y, p.d / 2)) then
			WorldScene.sign(f, (cf * CFrame.new(0, GROUND_Y + 22, -2)).Position, cf.LookVector, "Feed & Seed", "🥕", 24, 5)
		else
			WorldScene.shop(f, cf, p.w, p.d, 18, C.red, C.roofRed, { C.white, Color3.fromHex("2E9E5B") }, "Feed & Seed", "🥕")
		end
		for k = 0, 2 do -- hay bales out front
			local hb = placeModel(f, "hay_bale", cf * CFrame.new(-p.w / 2 + 4 + k * 4.5, GROUND_Y, -4))
			if not hb then
				part({ Name = "HayBale", Size = Vector3.new(4, 3, 3), Color = Color3.fromHex("E8C76A"), Material = Enum.Material.Fabric,
					CFrame = cf * CFrame.new(-p.w / 2 + 4 + k * 4.5, GROUND_Y + 1.5, -4) }, f)
			end
		end
	end
	do
		local p = WorldLayout.places.vet
		local cf = placeCF("vet")
		if placeModel(f, "vet_clinic", cf * CFrame.new(0, GROUND_Y, p.d / 2)) then
			WorldScene.sign(f, (cf * CFrame.new(0, GROUND_Y + 20, -2)).Position, cf.LookVector, "Vet", "💚", 16, 5)
		else
			WorldScene.shop(f, cf, p.w, p.d, 16, C.white, Color3.fromHex("3E8E7E"), { C.white, C.mint }, "Vet", "💚")
		end
	end
	-- Tack & Paint (D-050): the Diamond shop for looks; opens only when you walk in and tap.
	do
		local p = WorldLayout.places.tackShop
		local cf = placeCF("tackShop")
		WorldScene.shop(f, cf, p.w, p.d, 16, Color3.fromHex("F3E3C3"), Color3.fromHex("7D6B91"), { Color3.fromHex("7D6B91"), C.white }, "Tack & Paint", "🎨")
	end
	-- Training Paddock (Stage 6): fenced arena with cones and little jumps.
	do
		local p = WorldLayout.places.paddock
		local x0, x1 = p.x - p.w / 2, p.x + p.w / 2
		local z0, z1 = p.z, p.z + p.d
		local gate = 20
		WorldScene.fence(f, x0, z0, p.x - gate / 2, z0)
		WorldScene.fence(f, p.x + gate / 2, z0, x1, z0)
		WorldScene.fence(f, x1, z0, x1, z1)
		-- the south fence has a gate to the Training Ground (D-053)
		local south = WorldLayout.PADDOCK_SOUTH_GATE
		WorldScene.fence(f, x1, z1, south.x + south.width / 2, z1)
		WorldScene.fence(f, south.x - south.width / 2, z1, x0, z1)
		for _, s in { -1, 1 } do
			part({ Name = "GatePost", Size = Vector3.new(1.4, 7, 1.4), Color = C.woodLight, Material = Enum.Material.Wood,
				CFrame = CFrame.new(south.x + s * south.width / 2, GROUND_Y + 3.5, z1) }, f)
		end
		WorldScene.fence(f, x0, z1, x0, z0)
		part({ Name = "Arena", Size = Vector3.new(p.w - 2, 0.2, p.d - 2), Color = Color3.fromHex("D9B98A"), Material = Enum.Material.Sand,
			CFrame = CFrame.new(p.x, GROUND_Y + 0.06, (z0 + z1) / 2) }, f)
		-- The arena holds the Mud Splash gymkhana (built with the Training Ground).
		WorldScene.sign(f, Vector3.new(p.x + gate / 2 + 8, GROUND_Y + 7, z0 - 0.8), Vector3.new(0, 0, -1), "Training Paddock", "⭐", 18, 4)
	end
	-- Market Corral (Stage 8).
	do
		local p = WorldLayout.places.market
		local x0, x1 = p.x - p.w / 2, p.x + p.w / 2
		local z0, z1 = p.z, p.z + p.d
		local gate = 16
		WorldScene.fence(f, x0, z0, p.x - gate / 2, z0, C.woodLight)
		WorldScene.fence(f, p.x + gate / 2, z0, x1, z0, C.woodLight)
		WorldScene.fence(f, x1, z0, x1, z1, C.woodLight)
		WorldScene.fence(f, x1, z1, x0, z1, C.woodLight)
		WorldScene.fence(f, x0, z1, x0, z0, C.woodLight)
		local booth = CFrame.lookAt(Vector3.new(x0 + 16, 0, z0 + 14), Vector3.new(x0 + 16, 0, z0 - 10))
		if not placeModel(f, "market_corral_booth", booth) then
			WorldScene.shop(f, booth, 22, 14, 12, C.woodLight, C.roofRed, { C.gold, C.white }, "Market", "🐴")
		end
		WorldScene.sign(f, Vector3.new(p.x + gate / 2 + 8, GROUND_Y + 7, z0 - 0.8), Vector3.new(0, 0, -1), "Market Corral", "🐴", 18, 4)
	end
	-- Trail Gate: a log arch at the end of the street.
	do
		local cf = placeCF("trailGate")
		if not placeModel(f, "trail_gate_arch", cf) then
			for _, x in { -14, 14 } do
				part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(18, 2.4, 2.4), Color = C.wood, Material = Enum.Material.Wood,
					CFrame = cf * CFrame.new(x, GROUND_Y + 9, 0) * CFrame.Angles(0, 0, math.pi / 2) }, f)
			end
			part({ Name = "Beam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(32, 2.2, 2.2), Color = C.wood, Material = Enum.Material.Wood,
				CFrame = cf * CFrame.new(0, GROUND_Y + 17, 0) }, f)
		end
		WorldScene.sign(f, (cf * CFrame.new(0, GROUND_Y + 14, -0.5)).Position, cf.LookVector, "Trail", "🌲", 14, 4, C.woodLight)
	end
	f.Parent = root
	return f
end

-- Barn Lane and the empty plot shells (StableService fills owned plots).
local function buildLane(root: Instance)
	local f = Instance.new("Folder")
	f.Name = "BarnLane"
	strip(f, WorldLayout.LANE_X, WorldLayout.LANE_Z0, WorldLayout.LANE_X, WorldLayout.LANE_Z1, WorldLayout.LANE_WIDTH, C.lane, Enum.Material.Ground)
	WorldScene.sign(f, Vector3.new(WorldLayout.LANE_X - WorldLayout.LANE_WIDTH / 2 - 6, GROUND_Y + 10, WorldLayout.STREET_Z - WorldLayout.STREET_WIDTH / 2 - 3),
		Vector3.new(-1, 0, 0), "Barn Lane", "🐎", 16, 4, C.woodLight)
	-- Lamps on the lane's edges at the plot boundaries (never in a gateway or the crossing).
	local seen = {}
	for i = 1, WorldLayout.PLOT_COUNT do
		local p = WorldLayout.plot(i)
		for _, dz in { -WorldLayout.PLOT_FRONT / 2, WorldLayout.PLOT_FRONT / 2 } do
			local z = p.z + dz
			local key = tostring(p.side) .. ":" .. tostring(z)
			local nearStreet = math.abs(z - WorldLayout.STREET_Z) < WorldLayout.STREET_WIDTH / 2 + 4
			if not seen[key] and not nearStreet then
				seen[key] = true
				lamp(f, WorldLayout.LANE_X + p.side * (WorldLayout.LANE_WIDTH / 2 - 1.5), z)
			end
		end
	end
	f.Parent = root
	return f
end

-- The Trail: a dirt path through the trees to the meadow and back.
local function buildTrail(root: Instance)
	local f = Instance.new("Folder")
	f.Name = "Trail"
	local pts = WorldLayout.trail
	for k = 1, #pts - 1 do
		strip(f, pts[k].x, pts[k].z, pts[k + 1].x, pts[k + 1].z, 14, C.trail, Enum.Material.Ground, 0.03)
	end
	do
		local a, b = pts[3], pts[4]
		local mid = Vector3.new((a.x + b.x) / 2, GROUND_Y, (a.z + b.z) / 2)
		-- The deck sits 3.4 studs up on flat ground: sunk to ground level, so you ride over it, not through it (D-056).
		WorldScene.placeModel(f, "wooden_bridge", CFrame.lookAt(mid, mid + Vector3.new(b.x - a.x, 0, b.z - a.z)) * CFrame.new(0, -3.1, 0))
	end
	local m = WorldLayout.meadow
	for k = 0, 2 do
		local ang = k * 2.1
		local pos = Vector3.new(m.x + math.cos(ang) * (m.radius - 8), GROUND_Y, m.z + math.sin(ang) * (m.radius - 8))
		WorldScene.placeModel(f, "bench", CFrame.lookAt(pos, Vector3.new(m.x, GROUND_Y, m.z)))
	end
	WorldScene.placeModel(f, "picnic_table", CFrame.new(m.x + 20, GROUND_Y, m.z - 12))
	part({ Name = "Meadow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, m.radius * 2, m.radius * 2), Color = C.meadow,
		Material = Enum.Material.Grass, CFrame = CFrame.new(m.x, GROUND_Y + 0.02, m.z) * CFrame.Angles(0, 0, math.pi / 2) }, f)
	local rng = Random.new(42)
	local flowers = { Color3.fromHex("FFD23F"), Color3.fromHex("FF8FB1"), Color3.fromHex("FFFFFF"), Color3.fromHex("B497FF") }
	for _ = 1, 90 do
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * (m.radius - 6)
		part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Color = flowers[rng:NextInteger(1, #flowers)],
			CanCollide = false, CFrame = CFrame.new(m.x + math.cos(a) * r, GROUND_Y + 0.6, m.z + math.sin(a) * r) }, f)
	end
	f.Parent = root
	return f
end

-- Training Ground (D-053) -------------------------------------------------------------------
-- The training oval south of the paddock (rails, dirt, the hill on the south straight, Sprint
-- Lane hoops, the practice gate in the infield), the path from the paddock's south gate, the
-- Mud Splash gymkhana in the paddock arena and the picture signs. Geometry: TrainingCourses.
-- Hoops, poles, logs and finish posts are CourseProps: they never collide with a horse, so
-- nobody snags on them. Each rider's client lights the next one for itself.
local DIRT = Color3.fromHex("C69C6D")
local MUD = Color3.fromHex("6B4A2E")
local HOOP_COLOURS = { Color3.fromHex("E5484D"), Color3.fromHex("FF9F1C"), Color3.fromHex("17A398"),
	Color3.fromHex("56B4E9"), Color3.fromHex("B497FF"), Color3.fromHex("46C46A") }

local function ghostPart(props, parent: Instance): BasePart
	props.CanCollide, props.CanQuery, props.CanTouch = false, false, false
	return part(props, parent)
end

-- A course prop (CourseProps group, never collides).
local function prop(props, parent: Instance): BasePart
	props.CollisionGroup = CollisionGroups.PROPS
	return ghostPart(props, parent)
end

-- A picture sign on two posts: a big emoji, the course name and a short line, both sides.
local function pictureSign(parent: Instance, x: number, z: number, look: Vector3, emoji: string, title: string, line: string, color: Color3)
	local size = TrainingCourses.SIGN_SIZE
	local m = Instance.new("Model")
	m.Name = "Sign_" .. title
	local pos = Vector3.new(x, GROUND_Y, z)
	local across = Vector3.new(-look.Z, 0, look.X)
	local boardH = size.h - 2.5
	for _, s in { -1, 1 } do
		part({ Name = "Post", Size = Vector3.new(0.8, size.h, 0.8), Color = C.wood, Material = Enum.Material.Wood,
			CFrame = CFrame.new(pos + across * s * (size.w / 2 - 0.8) + Vector3.new(0, size.h / 2, 0)) }, m)
	end
	local centre = pos + Vector3.new(0, 2.5 + boardH / 2, 0)
	local board = part({ Name = "Board", Size = Vector3.new(size.w, boardH, 0.6), Color = color,
		CFrame = CFrame.lookAt(centre, centre + look) }, m)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(size.w * 40, boardH * 40)
		sg.LightInfluence = 0.2
		sg.Parent = board
		local rows = { { emoji, 0, 0.5 }, { title, 0.5, 0.28 }, { line, 0.78, 0.2 } }
		for _, row in rows do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0.04, row[2])
			l.Size = UDim2.fromScale(0.92, row[3])
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.TextColor3 = C.ink
			l.Text = row[1]
			l.Parent = sg
		end
	end
	local outline = Instance.new("SelectionBox")
	outline.Adornee = board
	outline.LineThickness = 0.08
	outline.Color3 = C.ink
	outline.SurfaceTransparency = 1
	outline.Parent = board
	m.Parent = parent
	return m
end

-- One rail segment that may climb (the hill): a post at the start, two rails along the slope.
local function railSegment(parent: Instance, a: Vector3, b: Vector3, endPost: boolean)
	local len = (b - a).Magnitude
	if len < 0.5 then return end
	part({ Name = "Post", Size = Vector3.new(0.8, 5, 0.8), Color = C.white, CFrame = CFrame.new(a + Vector3.new(0, 2.5, 0)) }, parent)
	if endPost then
		part({ Name = "Post", Size = Vector3.new(0.8, 5, 0.8), Color = C.white, CFrame = CFrame.new(b + Vector3.new(0, 2.5, 0)) }, parent)
	end
	for _, y in { 2, 4 } do
		local p0, p1 = a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)
		part({ Name = "Rail", Size = Vector3.new(0.4, 0.6, len), Color = C.white, CFrame = CFrame.lookAt((p0 + p1) / 2, p1) }, parent)
	end
end

local function buildOval(f: Instance)
	local TC = TrainingCourses
	local O = GameConfig.training.oval
	local S, R, W = O.straight, O.radius, O.width
	local TURN = math.pi * R
	local outerR, innerR = R + W / 2, R - W / 2
	-- Dirt in a stadium shape with the infield grass on top (flat layers never collide; the
	-- horse runs on the ground under them).
	for _, sx in { -1, 1 } do
		ghostPart({ Name = "Dirt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, outerR * 2, outerR * 2), Color = DIRT,
			Material = Enum.Material.Ground, CFrame = CFrame.new(O.cx + sx * S / 2, GROUND_Y + 0.04, O.cz) * CFrame.Angles(0, 0, math.pi / 2) }, f)
		ghostPart({ Name = "Infield", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, innerR * 2, innerR * 2), Color = C.plotGrass,
			Material = Enum.Material.Grass, CFrame = CFrame.new(O.cx + sx * S / 2, GROUND_Y + 0.08, O.cz) * CFrame.Angles(0, 0, math.pi / 2) }, f)
	end
	ghostPart({ Name = "Dirt", Size = Vector3.new(S, 0.2, outerR * 2), Color = DIRT, Material = Enum.Material.Ground,
		CFrame = CFrame.new(O.cx, GROUND_Y + 0.04, O.cz) }, f)
	ghostPart({ Name = "Infield", Size = Vector3.new(S, 0.2, innerR * 2), Color = C.plotGrass, Material = Enum.Material.Grass,
		CFrame = CFrame.new(O.cx, GROUND_Y + 0.08, O.cz) }, f)

	-- The hill (berm) on the south straight: ramp up, flat top, ramp down. It's real ground.
	local H = TC.HILL
	local zc = O.cz + R
	local xa = O.cx - S / 2 + H.u0
	local width = H.halfWidth * 2
	local function solid(props)
		props.Color, props.Material = DIRT, Enum.Material.Ground
		return props
	end
	local yMid = GROUND_Y + H.height / 2
	local upC = Vector3.new(xa + H.ramp / 2, yMid, zc)
	wedge(solid({ Name = "HillUp", Size = Vector3.new(width, H.height, H.ramp), CFrame = CFrame.lookAt(upC, upC - Vector3.new(1, 0, 0)) }), f)
	part(solid({ Name = "HillTop", Size = Vector3.new(H.top, H.height, width), CFrame = CFrame.new(xa + H.ramp + H.top / 2, yMid, zc) }), f)
	local downC = Vector3.new(xa + H.ramp + H.top + H.ramp / 2, yMid, zc)
	wedge(solid({ Name = "HillDown", Size = Vector3.new(width, H.height, H.ramp), CFrame = CFrame.lookAt(downC, downC + Vector3.new(1, 0, 0)) }), f)

	-- Rails just outside the dirt, following the hill; a gap in both on the north straight
	-- where the path comes in (and leads on into the infield).
	local rails = Instance.new("Folder")
	rails.Name = "Rails"
	rails.Parent = f
	local gapD0, gapD1 = O.cx + S / 2 - TC.ENTRY.x1, O.cx + S / 2 - TC.ENTRY.x0
	for _, lat in { TC.RAIL_LATERAL, -TC.RAIL_LATERAL } do
		local function at(d: number): Vector3
			local x, z = TC.ovalPoint(d, lat)
			return Vector3.new(x, GROUND_Y + TC.surfaceHeight(d), z)
		end
		local runs = { { 0, gapD0, 6 }, { gapD1, S, 2 }, { S, S + TURN, 12 }, { S + TURN, 2 * S + TURN, 8 }, { 2 * S + TURN, TC.LAP, 12 } }
		for i, run in runs do
			local d0, d1, n = run[1], run[2], run[3]
			for k = 0, n - 1 do
				local a, b = d0 + (d1 - d0) * k / n, d0 + (d1 - d0) * (k + 1) / n
				railSegment(rails, at(a), at(b), i == 1 and k == n - 1)
			end
		end
	end

	-- Sprint Lane hoops: an arch three horses wide.
	local hoops = Instance.new("Folder")
	hoops.Name = "Hoops"
	hoops.Parent = f
	for _, p in TC.courses.speed.posts do
		local m = Instance.new("Model")
		m.Name = "Hoop" .. p.index
		local base = Vector3.new(p.x, GROUND_Y + p.y, p.z)
		local n = Vector3.new(p.nx, 0, p.nz)
		local half, postH = p.width / 2, 7
		local colour = HOOP_COLOURS[((p.index - 1) % #HOOP_COLOURS) + 1]
		for _, s in { -1, 1 } do
			prop({ Name = "Post", Size = Vector3.new(0.7, postH, 0.7), Color = C.white, CFrame = CFrame.new(base + n * s * half + Vector3.new(0, postH / 2, 0)) }, m)
		end
		local prev = base + n * half + Vector3.new(0, postH, 0)
		for k = 1, 8 do
			local a = math.pi * k / 8
			local pt = base + n * (half * math.cos(a)) + Vector3.new(0, postH + half * math.sin(a), 0)
			prop({ Name = "Ring", Size = Vector3.new(0.7, 0.7, (pt - prev).Magnitude + 0.3), Color = if k % 2 == 0 then C.white else colour,
				CFrame = CFrame.lookAt((prev + pt) / 2, pt) }, m)
			prev = pt
		end
		m.Parent = hoops
	end
	-- Start / finish line for the oval courses.
	do
		local c = TC.courses.speed
		local x, z, tx, tz = TC.ovalPoint(c.startD, 0)
		local mid = Vector3.new(x, GROUND_Y + 0.12, z)
		ghostPart({ Name = "StartLine", Size = Vector3.new(W, 0.2, 0.8), Color = C.white,
			CFrame = CFrame.lookAt(mid, mid + Vector3.new(tx, 0, tz)) }, f)
	end

	-- Gate Break: the practice gate in the infield, its lane, the flag and the loop back.
	do
		local c = TC.courses.accel
		local gz = c.start.z
		local flag = c.flag
		local flagX = flag.ax
		strip(f, c.stall[1] - 6, gz, flagX + 10, gz, 10, DIRT, Enum.Material.Ground, 0.1)
		local pos = Vector3.new(c.start.x, GROUND_Y, gz)
		local gate = WorldScene.placeModel(f, "gate_stall", CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0)) * CFrame.new(0, 0, 1))
		if not gate then
			gate = Instance.new("Model")
			for _, s in { -1, 1 } do
				part({ Name = "StallSide", Size = Vector3.new(8, 6, 0.6), Color = C.white, CFrame = CFrame.new(c.start.x, GROUND_Y + 3, gz + s * 3) }, gate)
			end
			part({ Name = "StallTop", Size = Vector3.new(8, 0.8, 6.6), Color = C.red, CFrame = CFrame.new(c.start.x, GROUND_Y + 6.4, gz) }, gate)
			gate.Parent = f
		end
		-- The practice gate never stops a horse (D-053): no collisions, CourseProps. (Race gates
		-- are a different model and race horses aren't ride rigs.)
		gate.Name = "PracticeGate"
		for _, d in gate:GetDescendants() do
			if d:IsA("BasePart") then d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end
		end
		CollisionGroups.set(gate, CollisionGroups.PROPS)
		ghostPart({ Name = "FlagLine", Size = Vector3.new(0.8, 0.2, flag.bz - flag.az), Color = C.white,
			CFrame = CFrame.new(flagX, GROUND_Y + 0.14, gz) }, f)
		prop({ Name = "FlagPole", Size = Vector3.new(0.5, 9, 0.5), Color = C.white, CFrame = CFrame.new(flagX, GROUND_Y + 4.5, flag.az - 1.5) }, f)
		wedge({ Name = "Flag", Size = Vector3.new(0.1, 2.4, 3.4), Color = C.gold, CanCollide = false,
			CFrame = CFrame.new(flagX + 1.7, GROUND_Y + 7.6, flag.az - 1.5) * CFrame.Angles(0, math.pi / 2, 0) }, f)
	end
end

-- One Mud Splash layout's props (G = TrainingCourses.courses[key]) into the folder `gy`.
local function buildGymkhana(gy: Instance, G)
	local TC = TrainingCourses
	local logH = GameConfig.training.grit.logHeight
	for _, e in G.elements do
		local m = Instance.new("Model")
		m.Name = e.name
		if e.kind == "mud" then
			local r = e.rect
			local w, d = r[3] - r[1], r[4] - r[2]
			prop({ Name = "Mud", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, d, d), Color = MUD, Material = Enum.Material.Mud,
				CFrame = CFrame.new(e.x - (w - d) / 2, GROUND_Y + 0.14, e.z) * CFrame.Angles(0, 0, math.pi / 2) }, m)
			prop({ Name = "Mud", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, d, d), Color = MUD, Material = Enum.Material.Mud,
				CFrame = CFrame.new(e.x + (w - d) / 2, GROUND_Y + 0.15, e.z) * CFrame.Angles(0, 0, math.pi / 2) }, m)
			prop({ Name = "Puddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, d * 0.6, d * 0.6), Color = C.water,
				Material = Enum.Material.Glass, Transparency = 0.35, CFrame = CFrame.new(e.x, GROUND_Y + 0.17, e.z) * CFrame.Angles(0, 0, math.pi / 2) }, m)
		elseif e.kind == "log" then
			local base = Vector3.new(e.x, GROUND_Y, e.z)
			local cf = CFrame.lookAt(base, base + Vector3.new(e.dir, 0, 0)) -- the model's long side lies across the lane
			local lm = WorldScene.model("log_jump")
			if lm then
				-- Fit the model inside the scoring gate: 12 studs across the lane, at most 2 high.
				local _, size = lm:GetBoundingBox()
				local width = math.max(size.X, size.Z)
				local k = math.min(if size.Y > 0.1 then logH / size.Y else 1, if width > 0.1 then TC.LOG_HALF * 2 / width else 1)
				lm:ScaleTo(lm:GetScale() * k)
				if size.Z > size.X then cf *= CFrame.Angles(0, math.pi / 2, 0) end -- long side across the lane
				lm:PivotTo(cf)
				for _, d in lm:GetDescendants() do
					if d:IsA("BasePart") then d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end
				end
				CollisionGroups.set(lm, CollisionGroups.PROPS)
				lm.Parent = m
			else
				local dia = 1.4
				prop({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(TC.LOG_HALF * 2, dia, dia), Color = C.trunk,
					Material = Enum.Material.Wood, CFrame = CFrame.new(e.x, GROUND_Y + logH - dia / 2, e.z) * CFrame.Angles(0, math.pi / 2, 0) }, m)
				for _, s in { -1, 1 } do
					prop({ Name = "Stump", Size = Vector3.new(1, logH - dia / 2, 1), Color = C.wood, Material = Enum.Material.Wood,
						CFrame = CFrame.new(e.x, GROUND_Y + (logH - dia / 2) / 2, e.z + s * (TC.LOG_HALF - 1)) }, m)
				end
			end
			-- Jump wings mark the ends of the scoring gate (the log counts anywhere between them).
			for _, sd in { -1, 1 } do
				prop({ Name = "Wing", Size = Vector3.new(0.6, 4, 0.6), Color = C.white,
					CFrame = CFrame.new(e.x, GROUND_Y + 2, e.z + sd * (TC.LOG_HALF + 0.5)) }, m)
				prop({ Name = "WingFlag", Size = Vector3.new(0.1, 1.2, 1.6), Color = if sd > 0 then C.red else C.white,
					CFrame = CFrame.new(e.x, GROUND_Y + 3.5, e.z + sd * (TC.LOG_HALF + 1.3)) }, m)
			end
		else
			local stripes = { C.red, C.white, C.red }
			for k, colour in stripes do
				prop({ Name = "Pole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 0.6, 0.6), Color = colour,
					CFrame = CFrame.new(e.x, GROUND_Y + 1 + (k - 1) * 2, e.z) * CFrame.Angles(0, 0, math.pi / 2) }, m)
			end
			prop({ Name = "PoleBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.2, 2.2), Color = C.white,
				CFrame = CFrame.new(e.x, GROUND_Y + 0.2, e.z) * CFrame.Angles(0, 0, math.pi / 2) }, m)
		end
		m.Parent = gy
	end
	-- The canter zone: a darker lane with turtle signs at both ends.
	local zone = G.slowZone
	ghostPart({ Name = "CanterZone", Size = Vector3.new(zone[3] - zone[1], 0.2, zone[4] - zone[2] - 2), Color = Color3.fromHex("C9A877"),
		Material = Enum.Material.Sand, CFrame = CFrame.new((zone[1] + zone[3]) / 2, GROUND_Y + 0.1, (zone[2] + zone[4]) / 2) }, gy)
	-- Start line and the finish arch.
	local startX, z1 = G.laneX[1], G.laneZ(1)
	ghostPart({ Name = "StartLine", Size = Vector3.new(0.8, 0.2, G.laneGap - 4), Color = C.white, CFrame = CFrame.new(startX, GROUND_Y + 0.14, z1) }, gy)
	local fin = G.finish
	local fx, fz = fin.ax, (fin.az + fin.bz) / 2
	local halfW = (fin.bz - fin.az) / 2 - 2
	local arch = Instance.new("Model")
	arch.Name = "Finish" -- one model, so a rider's client can light it up as the last target
	arch.Parent = gy
	for _, s in { -1, 1 } do
		prop({ Name = "FinishPost", Size = Vector3.new(0.8, 11, 0.8), Color = C.white, CFrame = CFrame.new(fx, GROUND_Y + 5.5, fz + s * halfW) }, arch)
	end
	local banner = prop({ Name = "FinishBanner", Size = Vector3.new(0.4, 2.4, halfW * 2), Color = C.white, CFrame = CFrame.new(fx, GROUND_Y + 10, fz) }, arch)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(halfW * 80, 96)
		sg.Parent = banner
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = C.ink
		l.Text = "🏁 Finish 🏁"
		l.Parent = sg
	end
end

-- Mud Splash's four layouts (T5, "This week's course"): the props for each are kept in
-- ReplicatedStorage.Gymkhanas, a folder per course key (grit_w1..grit_w4). Each client copies
-- this week's layout into the arena (GymkhanaView, from the WeeklyCourse attribute that
-- TrainingService sets from the server's clock) and keeps the one it's riding until the ride
-- ends. The server scores from TrainingCourses' geometry, so it needs no props in the arena.
-- A rebuild (uploaded models arriving) swaps each folder for a new one; clients follow.
local function buildGymkhanas()
	local root = ReplicatedStorage:FindFirstChild("Gymkhanas")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Gymkhanas"
		root.Parent = ReplicatedStorage
	end
	for _, key in TrainingCourses.LAYOUTS do
		local gy = Instance.new("Folder")
		gy.Name = key
		buildGymkhana(gy, TrainingCourses.courses[key])
		local old = root:FindFirstChild(key)
		if old then old:Destroy() end
		gy.Parent = root
	end
end

local function buildTrainingGround(root: Instance)
	CollisionGroups.ensure()
	local f = Instance.new("Folder")
	f.Name = "TrainingGround"
	local TC = TrainingCourses
	local O = GameConfig.training.oval
	-- The path from the paddock's south gate to the gap in the oval's rails.
	local gateX = WorldLayout.PADDOCK_SOUTH_GATE.x
	local link = WorldLayout.trainingLink
	strip(f, gateX, link[2] + 4, gateX, O.cz - O.radius - O.width / 2 - 2, WorldLayout.TRAINING_PATH_WIDTH, C.lane, Enum.Material.Ground)
	-- A name board over the path where it reaches the ground.
	do
		local z = link[4] - 2
		local half = WorldLayout.TRAINING_PATH_WIDTH / 2 + 2
		for _, s in { -1, 1 } do
			part({ Name = "ArchPost", Size = Vector3.new(1.2, 14, 1.2), Color = C.woodLight, Material = Enum.Material.Wood,
				CFrame = CFrame.new(gateX + s * half, GROUND_Y + 7, z) }, f)
		end
		WorldScene.sign(f, Vector3.new(gateX, GROUND_Y + 12.5, z), Vector3.new(0, 0, -1), "Training Ground", "⭐", half * 2 + 2, 3.5, C.woodLight)
	end
	buildOval(f)
	buildGymkhanas()
	-- Picture signs (the open courses get a "Ride" prompt from the client).
	local signs = Instance.new("Folder")
	signs.Name = "Signs"
	signs.Parent = f
	for _, s in TC.signs do
		local c = TC.info(s.course)
		local open = GameConfig.training.courses[s.course] == true
		local line = if s.pointer then "In the paddock ⬆" elseif open then "Ride!" else "Coming soon"
		local colour = if open then C.white else Color3.fromHex("EDE4D3")
		pictureSign(signs, s.x, s.z, Vector3.new(s.lookX, 0, s.lookZ), c.emoji, c.name, line, colour)
	end
	f.Parent = root
	return f
end

-- Is (x, z) clear of streets, buildings, plots and the trail (for trees)?
local function clear(x: number, z: number, margin: number): boolean
	local r = { x - margin, z - margin, x + margin, z + margin }
	local Z, W = WorldLayout.STREET_Z, WorldLayout.STREET_WIDTH
	if WorldLayout.overlaps(r, { WorldLayout.STREET_X0 - 20, Z - W / 2 - 8, WorldLayout.STREET_X1 + 10, Z + W / 2 + 8 }) then return false end
	if WorldLayout.overlaps(r, { WorldLayout.LANE_X - 30, WorldLayout.LANE_Z0 - 10, WorldLayout.LANE_X + 30, WorldLayout.LANE_Z1 + 10 }) then return false end
	for i = 1, WorldLayout.PLOT_COUNT do
		if WorldLayout.overlaps(r, WorldLayout.plotRect(i)) then return false end
	end
	for key in WorldLayout.places do
		local pr = WorldLayout.placeRect(key)
		if pr and WorldLayout.overlaps(r, { pr[1] - 6, pr[2] - 6, pr[3] + 6, pr[4] + 6 }) then return false end
	end
	local pts = WorldLayout.trail
	for k = 1, #pts - 1 do
		local ax, az, bx, bz = pts[k].x, pts[k].z, pts[k + 1].x, pts[k + 1].z
		local dx, dz = bx - ax, bz - az
		local t = math.clamp(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
		local px, pz = ax + dx * t, az + dz * t
		if (x - px) ^ 2 + (z - pz) ^ 2 < (margin + 9) ^ 2 then return false end
	end
	local m = WorldLayout.meadow
	if (x - m.x) ^ 2 + (z - m.z) ^ 2 < (m.radius + margin) ^ 2 then return false end
	if WorldLayout.overlaps(r, WorldLayout.trainingLink) then return false end -- the path to the Training Ground
	return true
end

local function buildTrees(root: Instance)
	local f = Instance.new("Folder")
	f.Name = "Trees"
	local rng = Random.new(7)
	local placed = 0
	for _ = 1, 900 do
		if placed >= 170 then break end
		local x = rng:NextNumber(650, WorldLayout.BOUNDS.x1 - 12)
		local z = rng:NextNumber(WorldLayout.BOUNDS.z0 + 12, WorldLayout.BOUNDS.z1 - 12)
		-- denser woods round the Trail, scattered elsewhere
		local nearTrail = x > 1420
		if (nearTrail or rng:NextNumber() < 0.35) and clear(x, z, 8) then
			WorldScene.tree(f, x, z, rng:NextNumber(20, 36), rng)
			placed += 1
		end
	end
	f.Parent = root
	return f
end

-- Sunny afternoon at the fair: soft haze for depth, a little bloom and warmth.
local function ambience()
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 15
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 130)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	local function ensure(class: string, name: string): Instance
		local obj = Lighting:FindFirstChild(name)
		if not obj then
			obj = Instance.new(class)
			obj.Name = name
			obj.Parent = Lighting
		end
		return obj
	end
	local atmosphere = ensure("Atmosphere", "FairAtmosphere") :: Atmosphere
	atmosphere.Density, atmosphere.Offset, atmosphere.Haze, atmosphere.Glare = 0.28, 0.1, 1.2, 0.2
	atmosphere.Color, atmosphere.Decay = Color3.fromRGB(199, 214, 230), Color3.fromRGB(240, 210, 170)
	local bloom = ensure("BloomEffect", "FairBloom") :: BloomEffect
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 24, 1.6
	local cc = ensure("ColorCorrectionEffect", "FairColour") :: ColorCorrectionEffect
	cc.Saturation, cc.Contrast, cc.TintColor = 0.12, 0.05, Color3.fromRGB(255, 250, 240)
	local rays = ensure("SunRaysEffect", "FairSunRays") :: SunRaysEffect
	rays.Intensity, rays.Spread = 0.04, 0.6
end

local built: Folder? = nil
function WorldScene.build(): Folder
	if built and built.Parent then return built end
	ambience()
	local root = Instance.new("Folder")
	root.Name = "World"
	buildFairStreet(root)
	buildPlaces(root)
	buildLane(root)
	buildTrail(root)
	buildTrainingGround(root)
	buildTrees(root)
	root.Parent = workspace
	built = root
	return root
end

-- Rebuild Fair Street buildings once uploaded models load (they replace the part versions).
function WorldScene.rebuildPlaces()
	if not built then return end
	for _, name in { "FairStreet", "Places", "BarnLane", "Trail", "TrainingGround" } do
		local old = built:FindFirstChild(name)
		if old then old:Destroy() end
	end
	buildFairStreet(built)
	buildPlaces(built)
	buildLane(built)
	buildTrail(built)
	buildTrainingGround(built)
end

WorldScene.GROUND_Y = GROUND_Y
return WorldScene
