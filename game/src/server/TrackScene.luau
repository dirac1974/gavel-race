--!nonstrict
-- TrackScene: the racecourse, modelled on Churchill Downs (D-027), built from parts.
--   Main track: one-mile dirt oval, 80 ft wide, white inner and outer rails, run
--   counter-clockwise; red-and-white furlong poles on the inside rail; the finish pole on
--   the inside rail with a checkered strip across the track (for kids; Churchill has a wire).
--   Turf course inside the dirt. Grandstand along the homestretch with the Twin Spires on
--   its roof, the clubhouse at the first turn, the infield Big Board, a rose garden by the
--   finish, and the barns on the backside. The starting gate goes wherever the race's
--   distance puts it (TrackLayout.plan) and clears when the race starts.
-- One horse per lane (uploaded models from ReplicatedStorage.RaceModels, or block
-- placeholders until they load). The server only places horses at the gate; every client
-- animates them from the race timeline (client/RaceView). Racing players ride their
-- lane's horse as the jockey (D-024): each horse carries an invisible saddle Seat.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local UiAtlas = require(Shared:WaitForChild("UiAtlas"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))

local TrackScene = {}

local CFG = TrackLayout.churchill
local LANES = CFG.lanes
local TURN_SEGMENTS = 40
local COATS = { "bay", "chestnut", "grey", "black", "palomino", "bay", "chestnut", "grey" }
-- Lane colours from docs/art/ART_DIRECTION.md (colour-blind-safe set, with numbers).
local LANE_COLOURS = {
	Color3.fromHex("D55E00"), Color3.fromHex("56B4E9"), Color3.fromHex("F0E442"), Color3.fromHex("009E73"),
	Color3.fromHex("CC79A7"), Color3.fromHex("E69F00"), Color3.fromHex("0072B2"), Color3.fromHex("3A3F4B"),
}
local LIGHT_LANES = { [2] = true, [3] = true, [6] = true } -- dark numbers read better on these
local DIRT = Color3.fromHex("C68A52")
local TURF = Color3.fromHex("4AA23C")
local RAIL = Color3.fromHex("FBFBF5")
local STAND = Color3.fromHex("E8E4DA")
local STAND_DARK = Color3.fromHex("9C978C")
local ROOF = Color3.fromHex("2F5D3A")
local SPIRE = Color3.fromHex("F4F1EA")
local SPIRE_CAP = Color3.fromHex("3B4A5A")
local BRICK = Color3.fromHex("8C4A32")

local venue: Folder? = nil   -- static buildings, built once
-- Saddle position on a model, as fractions of its bounding box (gallop pose; tune in Studio).
local SADDLE_HEIGHT = 0.6     -- of the model's height, measured from the hooves
local SADDLE_BACK = 0.06      -- of its length, toward the tail (+Z; horses face -Z)

local function part(props, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do p[k] = v end
	if parent then p.Parent = parent end
	return p
end

local function wedge(props, parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	for k, v in props do w[k] = v end
	w.Parent = parent
	return w
end

local function modelFor(slot: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("RaceModels")
	local m = folder and folder:FindFirstChild(slot)
	return if m then m:Clone() else nil
end

-- Bands round the oval (dirt, turf, rails): two straights and two segmented semicircles.
local function band(parent: Instance, name: string, rIn: number, rOut: number, height: number, y: number,
	color: Color3, material: Enum.Material?, collide: boolean?)
	local L, cx, cz = CFG.straight, CFG.centerX, CFG.centerZ
	local w, rMid = rOut - rIn, (rIn + rOut) / 2
	for _, side in { 1, -1 } do
		part({ Name = name, Size = Vector3.new(w, height, L), Color = color, Material = material or Enum.Material.SmoothPlastic,
			CanCollide = collide == true, CFrame = CFrame.new(cx + side * rMid, y, cz) }, parent)
	end
	local seg = math.pi / TURN_SEGMENTS
	local length = rOut * seg * 1.04 -- a little overlap so the outer edge has no gaps
	for _, turn in { { z = cz - L / 2, s = -1 }, { z = cz + L / 2, s = 1 } } do
		for j = 0, TURN_SEGMENTS - 1 do
			local a = (j + 0.5) * seg
			local pos = Vector3.new(cx + rMid * math.cos(a), y, turn.z + turn.s * rMid * math.sin(a))
			local tangent = Vector3.new(-math.sin(a), 0, turn.s * math.cos(a))
			part({ Name = name, Size = Vector3.new(w, height, length), Color = color, Material = material or Enum.Material.SmoothPlastic,
				CanCollide = collide == true, CFrame = CFrame.lookAt(pos, pos + tangent) }, parent)
		end
	end
end

-- An invisible wall from the ground to the rail, so players can't walk through under it.
-- Horses aren't affected: they're anchored and moved by CFrame.
local function railBlocker(parent: Instance, r: number)
	local folder = Instance.new("Folder")
	folder.Name = "RailBlocker"
	band(folder, "Blocker", r - 0.3, r + 0.3, 3.2, 1.6, Color3.new(1, 1, 1), nil, true)
	for _, b in folder:GetChildren() do
		b.Transparency = 1
		b.CastShadow = false
	end
	folder.Parent = parent
end

-- A four-sided spire roof from wedges, apex up, base centred on `base` (top of a tower).
local function pyramid(parent: Instance, base: Vector3, size: number, height: number, color: Color3)
	for k = 0, 3 do
		local yaw = k * math.pi / 2
		-- A WedgePart's upright face is at its back (+Z); turn it to face the centre so the slope faces out.
		local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, height / 2, size / 4) * CFrame.Angles(0, math.pi, 0)
		wedge({ Size = Vector3.new(size, height, size / 2), Color = color, CFrame = cf }, parent)
	end
end

local function spire(parent: Instance, x: number, z: number, roofY: number)
	local tower = 14
	part({ Name = "Spire", Size = Vector3.new(tower, 34, tower), Color = SPIRE, CFrame = CFrame.new(x, roofY + 17, z) }, parent)
	for k = 0, 3 do -- arched windows, one per face
		local yaw = k * math.pi / 2
		part({ Name = "Window", Size = Vector3.new(5, 12, 0.6), Color = SPIRE_CAP, CFrame = CFrame.new(x, roofY + 20, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, tower / 2) }, parent)
	end
	part({ Name = "Collar", Size = Vector3.new(tower + 2, 2, tower + 2), Color = SPIRE, CFrame = CFrame.new(x, roofY + 35, z) }, parent)
	pyramid(parent, Vector3.new(x, roofY + 36, z), tower + 1, 30, SPIRE_CAP)
	part({ Name = "Finial", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Color = Color3.fromHex("D4AF37"), CFrame = CFrame.new(x, roofY + 67, z) }, parent)
end

local function tree(parent: Instance, x: number, z: number, h: number)
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.5, 2.5, 2.5), Color = Color3.fromHex("6B4A2E"),
		CFrame = CFrame.new(x, h * 0.25, z) * CFrame.Angles(0, 0, math.pi / 2) }, parent)
	part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.6, h * 0.6, h * 0.6), Color = Color3.fromHex("3E8E3A"),
		Material = Enum.Material.Grass, CFrame = CFrame.new(x, h * 0.65, z) }, parent)
end

local function buildVenue(): Folder
	local f = Instance.new("Folder")
	f.Name = "Venue"
	local L, cx, cz = CFG.straight, CFG.centerX, CFG.centerZ
	local rIn, rOut = CFG.railRadius, TrackLayout.outerRadius(CFG)

	-- Main dirt track and its rails.
	band(f, "Dirt", rIn, rOut, 1, -0.45, DIRT, Enum.Material.Ground)
	band(f, "InnerRail", rIn - 0.3, rIn + 0.3, 0.6, 3.2, RAIL, nil, true)
	band(f, "OuterRail", rOut - 0.3, rOut + 0.3, 0.6, 3.2, RAIL, nil, true)
	railBlocker(f, rIn)
	railBlocker(f, rOut)
	-- Turf course inside, with its own rails.
	local tOut = rIn - CFG.turfGap
	local tIn = tOut - CFG.turfWidth
	band(f, "Turf", tIn, tOut, 1, -0.47, TURF, Enum.Material.Grass)
	band(f, "TurfRail", tOut - 0.25, tOut + 0.25, 0.5, 3, RAIL, nil, true)
	band(f, "TurfRail", tIn - 0.25, tIn + 0.25, 0.5, 3, RAIL, nil, true)
	railBlocker(f, tOut)
	railBlocker(f, tIn)

	-- Furlong poles on the inside rail (every 660 ft back from the finish), red and white.
	local r1 = TrackLayout.laneRadius(CFG, 1)
	for k = 1, 7 do
		local x, z = TrackLayout.atDistance(CFG, rIn - 1.5, CFG.finishFromTop - k * 660 * (rIn / r1))
		part({ Name = "FurlongPole", Size = Vector3.new(0.8, 9, 0.8), Color = Color3.fromHex("C8102E"), CFrame = CFrame.new(x, 4.5, z) }, f)
		part({ Name = "FurlongBand", Size = Vector3.new(0.9, 1.5, 0.9), Color = Color3.new(1, 1, 1), CFrame = CFrame.new(x, 6.5, z) }, f)
	end

	-- Finish: the pole on the inside rail, a checkered strip across the dirt, and the post model.
	local x0, x1, lineZ = TrackLayout.finishLine(CFG)
	for k = 0, math.floor((x1 - x0) / 2) - 1 do
		for row = 0, 1 do
			part({ Name = "Finish", Size = Vector3.new(2, 0.05, 2), CanCollide = false,
				Color = if (k + row) % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(28, 31, 38),
				CFrame = CFrame.new(x0 + 1 + k * 2, 0.08, lineZ - 1 + row * 2) }, f)
		end
	end
	local turfCfg = TrackLayout.churchillTurf
	local tx0, tx1 = turfCfg.centerX + turfCfg.railRadius, turfCfg.centerX + TrackLayout.outerRadius(turfCfg)
	for k = 0, math.floor((tx1 - tx0) / 2) - 1 do -- the turf course finishes on the same line
		for row = 0, 1 do
			part({ Name = "TurfFinish", Size = Vector3.new(2, 0.05, 2), CanCollide = false,
				Color = if (k + row) % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(28, 31, 38),
				CFrame = CFrame.new(tx0 + 1 + k * 2, 0.06, lineZ - 1 + row * 2) }, f)
		end
	end
	part({ Name = "FinishPole", Size = Vector3.new(1, 16, 1), Color = Color3.fromHex("C8102E"), CFrame = CFrame.new(x0 - 1.5, 8, lineZ) }, f)
	part({ Name = "FinishDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), Color = Color3.new(1, 1, 1),
		CFrame = CFrame.new(x0 - 1.5, 15, lineZ) * CFrame.Angles(0, math.pi / 2, 0) }, f)
	local post = modelFor("finish_post")
	if post then
		post:PivotTo(CFrame.new(x1 + 4, 0, lineZ) * CFrame.Angles(0, math.pi / 2, 0))
		post.Parent = f
	end

	-- Grandstand along the homestretch, facing the track (-X), centred on the finish line.
	local standZ0, standZ1 = lineZ - 300, lineZ + 600
	local standLen, standMid = standZ1 - standZ0, (standZ0 + standZ1) / 2
	local apron = rOut + 18
	part({ Name = "Apron", Size = Vector3.new(18, 0.6, standLen + 60), Color = Color3.fromHex("BDB6A8"),
		Material = Enum.Material.Concrete, CFrame = CFrame.new(rOut + 9, -0.2, standMid) }, f)
	local tiers = 7
	-- Gate 1: a tunnel through the stand to Fair Street (D-035), so the stand is built in two
	-- spans either side of it.
	local gateZ0 = WorldLayout.STREET_Z - WorldLayout.TUNNEL_WIDTH / 2
	local gateZ1 = WorldLayout.STREET_Z + WorldLayout.TUNNEL_WIDTH / 2
	local spans = { { standZ0, gateZ0 }, { gateZ1, standZ1 } }
	local backX = apron + 14 * tiers
	local roofY = 6 + tiers * 6 + 24
	for _, span in spans do
		local len, mid = span[2] - span[1], (span[1] + span[2]) / 2
		for k = 0, tiers - 1 do
			local depth = 14
			local height = 6 + k * 6
			part({ Name = "StandTier", Size = Vector3.new(depth, height, len), Color = if k % 2 == 0 then STAND else STAND_DARK,
				Material = Enum.Material.Concrete, CFrame = CFrame.new(apron + depth * (k + 0.5), height / 2, mid) }, f)
		end
		part({ Name = "StandBack", Size = Vector3.new(16, roofY, len), Color = BRICK, Material = Enum.Material.Brick,
			CFrame = CFrame.new(backX + 8, roofY / 2, mid) }, f)
	end
	for z = standZ0 + 40, standZ1 - 40, 80 do -- roof columns
		if z < gateZ0 - 2 or z > gateZ1 + 2 then
			part({ Name = "Column", Size = Vector3.new(2, roofY - 8, 2), Color = STAND, CFrame = CFrame.new(apron + 30, 6 + (roofY - 8) / 2 + 2, z) }, f)
		end
	end
	-- The tunnel: a paved floor, a low ceiling under the stand, and a sign over each end.
	local tunnelLen = backX + 16 - apron
	part({ Name = "TunnelFloor", Size = Vector3.new(tunnelLen + 4, 0.4, WorldLayout.TUNNEL_WIDTH), Color = Color3.fromHex("BFAE95"),
		Material = Enum.Material.Cobblestone, CFrame = CFrame.new(apron + tunnelLen / 2, -0.3, WorldLayout.STREET_Z) }, f)
	part({ Name = "TunnelCeiling", Size = Vector3.new(tunnelLen, 2, WorldLayout.TUNNEL_WIDTH + 2), Color = STAND_DARK,
		Material = Enum.Material.Concrete, CFrame = CFrame.new(apron + tunnelLen / 2, 17, WorldLayout.STREET_Z) }, f)
	for _, side in { { x = apron - 0.4, face = Enum.NormalId.Left, text = "🎪 Fair Street · Stables" }, { x = backX + 16.4, face = Enum.NormalId.Right, text = "🏁 Racetrack" } } do
		local sign = part({ Name = "GateSign", Size = Vector3.new(0.6, 6, WorldLayout.TUNNEL_WIDTH - 4), Color = Color3.fromHex("2F5D3A"),
			CFrame = CFrame.new(side.x, 21, WorldLayout.STREET_Z) }, f)
		local sg = Instance.new("SurfaceGui")
		sg.Face = side.face
		sg.CanvasSize = Vector2.new(1040, 240)
		sg.Parent = sign
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = side.text
		t.Parent = sg
	end
	part({ Name = "Roof", Size = Vector3.new(backX + 16 - (apron + 24), 3, standLen + 10), Color = ROOF,
		CFrame = CFrame.new((apron + 24 + backX + 16) / 2, roofY, standMid) }, f)
	-- The Twin Spires, on the roof near the finish line.
	spire(f, backX - 18, lineZ - 32, roofY + 1.5)
	spire(f, backX - 18, lineZ + 32, roofY + 1.5)

	-- Clubhouse beyond the finish, toward the first turn.
	part({ Name = "Clubhouse", Size = Vector3.new(90, 46, 160), Color = BRICK, Material = Enum.Material.Brick,
		CFrame = CFrame.new(rOut + 75, 23, standZ0 - 110) }, f)
	part({ Name = "ClubhouseRoof", Size = Vector3.new(96, 3, 166), Color = ROOF, CFrame = CFrame.new(rOut + 75, 47.5, standZ0 - 110) }, f)

	-- Infield: the Big Board facing the grandstand, and a rose garden by the finish.
	local boardX, boardZ = cx - 120, lineZ + 120
	for _, dz in { -55, 55 } do
		part({ Name = "BoardLeg", Size = Vector3.new(4, 40, 4), Color = Color3.fromHex("3A3F4B"), CFrame = CFrame.new(boardX, 20, boardZ + dz) }, f)
	end
	local board = part({ Name = "BigBoard", Size = Vector3.new(4, 60, 170), Color = Color3.fromHex("1C1F26"), CFrame = CFrame.new(boardX, 70, boardZ) }, f)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Right -- +X, toward the grandstand
	sg.CanvasSize = Vector2.new(850, 300)
	sg.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.7)
	title.BackgroundTransparency = 1
	title.Text = "GIDDY-UP!"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromHex("FFD34D")
	title.Parent = sg
	local tagline = Instance.new("TextLabel")
	tagline.Size = UDim2.fromScale(0.9, 0.25)
	tagline.Position = UDim2.fromScale(0.05, 0.72)
	tagline.BackgroundTransparency = 1
	tagline.Text = "Tap it. Shout it. Win it." -- D-029
	tagline.Font = Enum.Font.GothamBold
	tagline.TextScaled = true
	tagline.TextColor3 = Color3.new(1, 1, 1)
	tagline.Parent = sg
	for k = 0, 23 do -- rose garden in the grass between the turf course and the dirt
		local x = tOut + 4 + (k % 6) * 4
		local z = lineZ - 30 + math.floor(k / 6) * 5
		part({ Name = "Rose", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Color = Color3.fromHex("B3122E"), CFrame = CFrame.new(x, 1.5, z) }, f)
	end

	-- The backside: barns outside the backstretch.
	for k = 0, 5 do
		local z = cz - L / 2 + 120 + k * 200
		part({ Name = "Barn", Size = Vector3.new(36, 14, 150), Color = Color3.fromHex("F2EFE6"), CFrame = CFrame.new(cx - rOut - 50, 7, z) }, f)
		part({ Name = "BarnRoof", Size = Vector3.new(40, 2, 154), Color = ROOF, CFrame = CFrame.new(cx - rOut - 50, 15, z) }, f)
	end
	for k = 0, 9 do -- trees round the outside of the turns
		local a = (k + 0.5) / 10 * math.pi
		tree(f, cx + (rOut + 70) * math.cos(a), cz - L / 2 - (rOut + 70) * math.sin(a), 30)
		tree(f, cx - (rOut + 70) * math.cos(a), cz + L / 2 + (rOut + 70) * math.sin(a), 30)
	end

	f.Parent = workspace
	return f
end

local function placeholderHorse(i: number): Model
	local m = Instance.new("Model")
	part({ Size = Vector3.new(1.8, 3.5, 7), Color = Color3.fromRGB(120, 72, 40), CanCollide = false, Name = "Body", CFrame = CFrame.new(0, 3.5, 0) }, m)
	part({ Size = Vector3.new(1.4, 1.6, 2.4), Color = Color3.fromRGB(110, 66, 36), CanCollide = false, Name = "Head", CFrame = CFrame.new(0, 5.6, -4) }, m)
	m.WorldPivot = CFrame.new(0, 0, 0)
	m:SetAttribute("SaddleY", 5.3) -- top of the block body
	m.Name = "Placeholder" .. i
	return m
end

-- Race-day saddle cloth (running-legs horses, D-051): the fitted Cloth piece in the lane's
-- colour with the lane number on both sides, like a real race number cloth.
local function laneCloth(horse: Model, i: number): BasePart?
	local cloth = horse:FindFirstChild("Cloth", true)
	if not cloth or not cloth:IsA("MeshPart") then return nil end
	cloth.TextureID = ""
	cloth.Material = Enum.Material.Fabric
	cloth.Color = LANE_COLOURS[i]
	cloth.Transparency = 0
	cloth.CastShadow = true
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(200, 120)
		sg.LightInfluence = 1
		sg.Parent = cloth
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.62)
		l.Size = UDim2.fromScale(0.5, 0.5)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.Text = tostring(i)
		l.TextColor3 = if LIGHT_LANES[i] then Color3.fromHex("1F2430") else Color3.new(1, 1, 1)
		l.Parent = sg
	end
	return cloth
end

local function badge(i: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LaneBadge"
	gui.Size = UDim2.fromOffset(44, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	local rect = UiAtlas["lane_" .. i]
	local imageId = rect and ReplicatedStorage:GetAttribute("UiSheet_" .. rect.sheet)
	if imageId then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = "rbxassetid://" .. imageId
		img.ImageRectOffset = Vector2.new(rect.x, rect.y)
		img.ImageRectSize = Vector2.new(rect.w, rect.h)
		img.Parent = gui
		return gui
	end
	local chip = Instance.new("TextLabel")
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = LANE_COLOURS[i]
	chip.Text = tostring(i)
	chip.Font = Enum.Font.GothamBlack
	chip.TextScaled = true
	chip.TextColor3 = if LIGHT_LANES[i] then Color3.fromHex("1F2430") else Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = chip
	chip.Parent = gui
	return gui
end

-- Courses (D-036): the dirt oval and the turf course inside it each run their own race,
-- so two races can be on at once. Each course keeps its own gate, horses and saddles in its
-- own folder ("RaceTrack" for dirt, "RaceTrack_turf" for turf); the buildings are shared.
local Course = {}
Course.__index = Course
local courses: { [string]: any } = {}

function TrackScene.course(id: string, cfg): any
	if courses[id] then return courses[id] end
	local c = setmetatable({
		id = id, cfg = cfg, root = nil, horses = {}, saddles = {}, stalls = {}, plan = nil,
		folderName = if id == "dirt" then "RaceTrack" else "RaceTrack_" .. id,
	}, Course)
	courses[id] = c
	return c
end

-- Lane i's CFrame at progress p of this course's race (s = p * railLength along the lane-1 path,
-- at lane position x, default its post: D-054), standing on the track, facing its way.
function Course:laneCFrame(i: number, p: number, x: number?): CFrame
	local s = p * TrackLayout.railLength(self.cfg, self.plan)
	local px, pz, dx, dz = TrackLayout.railPoint(self.cfg, self.plan, s, x or i)
	local pos = Vector3.new(px, 0, pz)
	return CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz))
end

-- Per race: the gate where this distance starts, and the horses in it.
function Course:build(plan, coats: { string? }?)
	if not venue or not venue.Parent then
		Lighting.ClockTime = 15
		venue = buildVenue()
	end
	self.plan = plan
	if self.root then self.root:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = self.folderName
	folder:SetAttribute("Distance", plan.distance)
	folder:SetAttribute("Course", self.id)

	self.stalls = {}
	for i = 1, LANES do
		local stall = modelFor("gate_stall")
		if stall then
			stall:PivotTo(self:laneCFrame(i, 0) * CFrame.new(0, 0, 1))
			stall.Parent = folder
			self.stalls[i] = stall
		end
	end

	local horseFolder = Instance.new("Folder")
	horseFolder.Name = "Horses"
	horseFolder.Parent = folder
	self.horses, self.saddles = {}, {}
	for i = 1, LANES do
		local coat = (coats and coats[i]) or COATS[i]
		-- Running legs first (horse_anim_<coat>, D-051); then the one-piece gallop poses (the first
		-- five coats are uploaded as horse_<coat>, the newer ones as horse_gallop_<coat>).
		local horse = modelFor("horse_anim_" .. coat)
		if horse and not HorseLegs.has(horse) then -- the legs didn't import as separate parts
			horse:Destroy()
			horse = nil
		end
		horse = horse or modelFor("horse_gallop_" .. coat) or modelFor("horse_" .. coat)
			or modelFor("horse_" .. COATS[i]) or placeholderHorse(i)
		horse.Name = "Lane" .. i
		horse:PivotTo(self:laneCFrame(i, 0))
		badge(i).Parent = horse
		-- The saddle is anchored inside the model, so pivoting the horse moves it, and a
		-- seated rider (welded to it by the Seat) moves with the horse.
		local _, size = horse:GetBoundingBox()
		-- On a running-legs horse the jockey sits on the race cloth, a little below its top
		-- (the same seat depth the gallop models were tuned to).
		local cloth = laneCloth(horse, i)
		local seatY, seatZ = horse:GetAttribute("SaddleY") or size.Y * SADDLE_HEIGHT, size.Z * SADDLE_BACK
		if cloth then
			local top = horse:GetPivot():PointToObjectSpace(cloth.Position + Vector3.new(0, cloth.Size.Y / 2, 0))
			seatY, seatZ = top.Y - 0.34, top.Z
		end
		local saddle = Instance.new("Seat")
		saddle.Name = "Saddle"
		saddle.Size = Vector3.new(2, 0.4, 2)
		saddle.Transparency = 1
		saddle.Anchored = true
		saddle.CanCollide = false
		saddle.CanTouch = false -- nobody sits by walking into it; the server seats riders
		saddle.CFrame = horse:GetPivot() * CFrame.new(0, seatY, seatZ)
		saddle.Parent = horse
		horse.Parent = horseFolder
		self.horses[i] = horse
		self.saddles[i] = saddle
	end
	folder.Parent = workspace
	self.root = folder
end

-- Roblox-style jockeys for the bot horses: a standard character in its lane's silks
-- (torso and arms), white breeches and a lane-coloured helmet, seated with Roblox's own
-- R15 sit animation. Built in the background; a horse simply has no jockey until it's ready.
local SKIN = { "FFCC99", "EAB892", "C69C6D", "A57143", "7C4A2D", "5A3825" }
local SIT_ANIMATION = "rbxassetid://2506281703" -- Roblox's default R15 sit (from the Animate script)

local function jockeyFor(i: number): Model?
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromHex(SKIN[(i - 1) % #SKIN + 1])
	desc.HeadColor = skin
	desc.TorsoColor = LANE_COLOURS[i]
	desc.LeftArmColor, desc.RightArmColor = LANE_COLOURS[i], LANE_COLOURS[i]
	desc.LeftLegColor, desc.RightLegColor = Color3.new(1, 1, 1), Color3.new(1, 1, 1)
	desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 0.9, 0.85, 0.9, 1
	local ok, model = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[TrackScene] jockey not created: " .. tostring(model))
		return nil
	end
	model.Name = "Jockey"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	local head = model:FindFirstChild("Head")
	if head then
		local helmet = Instance.new("Part")
		helmet.Name = "Helmet"
		helmet.Shape = Enum.PartType.Ball
		helmet.Size = Vector3.new(1.35, 1.35, 1.35)
		helmet.Color = LANE_COLOURS[i]
		helmet.Material = Enum.Material.SmoothPlastic
		helmet.CanCollide, helmet.CanQuery, helmet.CanTouch, helmet.Massless = false, false, false, true
		helmet.CFrame = head.CFrame * CFrame.new(0, 0.25, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = head, helmet
		weld.Parent = helmet
		helmet.Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide, d.CanTouch = false, false end
	end
	return model
end

-- Seat a jockey on every bot lane (`isBot[i]` true). Call after build().
function Course:addJockeys(isBot: { boolean })
	for i, bot in isBot do
		local horse, saddle = self.horses[i], self.saddles[i]
		if bot and horse and saddle and not saddle.Occupant then
			task.spawn(function()
				local jockey = jockeyFor(i)
				if not jockey or not horse.Parent then
					if jockey then jockey:Destroy() end
					return
				end
				jockey:PivotTo(saddle.CFrame + Vector3.new(0, 3, 0))
				jockey.Parent = horse -- inside the horse model, so the horse's pivot carries it too
				local humanoid = jockey:FindFirstChildOfClass("Humanoid")
				if not humanoid then return end
				saddle:Sit(humanoid)
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
				local anim = Instance.new("Animation")
				anim.AnimationId = SIT_ANIMATION
				local okLoad, track = pcall(function() return animator:LoadAnimation(anim) end)
				if okLoad and track then
					track.Looped = true
					track:Play()
				end
			end)
		end
	end
end

-- The gate opens: stalls clear away when the race starts.
function Course:openGate()
	for _, stall in self.stalls do
		if stall.Parent then stall:Destroy() end
	end
	self.stalls = {}
end

-- Put a racing player's character in the saddle of lane `i`.
function Course:seatRider(i: number, character: Model?): boolean
	local saddle = self.saddles[i]
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not saddle or not humanoid or humanoid.Health <= 0 then return false end
	-- Still sitting somewhere (the other course's horse after its race): get off first.
	local old = humanoid.SeatPart
	if old then
		local weld = old:FindFirstChild("SeatWeld")
		if weld then weld:Destroy() end
		humanoid.Sit = false
	end
	character:PivotTo(saddle.CFrame + Vector3.new(0, 3, 0))
	saddle:Sit(humanoid)
	return true
end

local function apronBase(): CFrame
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	local _, _, lineZ = TrackLayout.finishLine(CFG)
	return if spawn then spawn.CFrame else CFrame.new(TrackLayout.outerRadius(CFG) + 12, 0, lineZ)
end

-- One rider off (they pressed Done), standing on the apron by the finish line.
function Course:dismount(character: Model?): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	for i, saddle in self.saddles do
		if saddle.Occupant == humanoid then
			local weld = saddle:FindFirstChild("SeatWeld")
			if weld then weld:Destroy() end
			humanoid.Sit = false
			character:PivotTo(apronBase() * CFrame.new((i - 4.5) * 3, 3.5, 0))
			return true
		end
	end
	return false
end

-- After a race: everyone off, standing on the apron by the finish line.
function Course:dismountAll()
	local base = apronBase()
	for i, saddle in self.saddles do
		local humanoid = saddle.Occupant
		if humanoid then
			local character = humanoid.Parent
			local weld = saddle:FindFirstChild("SeatWeld")
			if weld then weld:Destroy() end
			humanoid.Sit = false
			if character then
				character:PivotTo(base * CFrame.new((i - 4.5) * 3, 3.5, 0))
			end
		end
	end
end

-- Off whichever course's saddle this character is in.
function TrackScene.dismount(character: Model?)
	for _, c in courses do
		if c:dismount(character) then return end
	end
end

-- The dirt course, for callers that don't care about courses.
local dirt = TrackScene.course("dirt", CFG)
function TrackScene.build(plan, coats) dirt:build(plan, coats) end
function TrackScene.laneCFrame(i: number, p: number): CFrame return dirt:laneCFrame(i, p) end
function TrackScene.dismountAll() for _, c in courses do c:dismountAll() end end

return TrackScene
