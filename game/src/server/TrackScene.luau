--!nonstrict
-- TrackScene: the oval racecourse for the playtest (D-023 art, D-025 oval).
-- Builds an eight-lane oval from parts (straights plus segmented turns, inner and outer
-- rails), a checkered start/finish line with the finish post, starting stalls at the
-- line, and one horse per lane (uploaded models from ReplicatedStorage.RaceModels, or
-- block placeholders until they load). The server only places horses at the gate; every
-- client animates them round the lap from the race timeline (client/RaceView), so they
-- move smoothly. Racing players ride their lane's horse as the jockey (D-024): each horse
-- carries an invisible saddle Seat, and the default camera follows the rider.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OvalTrack = require(Shared:WaitForChild("OvalTrack"))
local UiAtlas = require(Shared:WaitForChild("UiAtlas"))

local TrackScene = {}

local CFG = OvalTrack.default
local LANES = CFG.lanes
local TURN_SEGMENTS = 24
local COATS = { "bay", "chestnut", "grey", "black", "palomino", "bay", "chestnut", "grey" }
-- Lane colours from docs/art/ART_DIRECTION.md (colour-blind-safe set, with numbers).
local LANE_COLOURS = {
	Color3.fromHex("D55E00"), Color3.fromHex("56B4E9"), Color3.fromHex("F0E442"), Color3.fromHex("009E73"),
	Color3.fromHex("CC79A7"), Color3.fromHex("E69F00"), Color3.fromHex("0072B2"), Color3.fromHex("3A3F4B"),
}
local LIGHT_LANES = { [2] = true, [3] = true, [6] = true } -- dark numbers read better on these
local DIRT = Color3.fromHex("C68A52")
local RAIL = Color3.fromHex("FBFBF5")

local root: Folder? = nil
local horses: { Model } = {}
local saddles: { Seat } = {}
local stalls: { Model } = {}
-- Saddle position on a model, as fractions of its bounding box (gallop pose; tune in Studio).
local SADDLE_HEIGHT = 0.6     -- of the model's height, measured from the hooves
local SADDLE_BACK = 0.06      -- of its length, toward the tail (+Z; horses face -Z)

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	return p
end

local function modelFor(slot: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("RaceModels")
	local m = folder and folder:FindFirstChild(slot)
	return if m then m:Clone() else nil
end

local function placeholderHorse(i: number): Model
	local m = Instance.new("Model")
	local body = part({ Size = Vector3.new(1.8, 3.5, 7), Color = Color3.fromRGB(120, 72, 40), CanCollide = false, Name = "Body" })
	body.CFrame = CFrame.new(0, 3.5, 0)
	body.Parent = m
	local head = part({ Size = Vector3.new(1.4, 1.6, 2.4), Color = Color3.fromRGB(110, 66, 36), CanCollide = false, Name = "Head" })
	head.CFrame = CFrame.new(0, 5.6, -4)
	head.Parent = m
	m.WorldPivot = CFrame.new(0, 0, 0)
	m:SetAttribute("SaddleY", 5.3) -- top of the block body
	m.Name = "Placeholder" .. i
	return m
end

local function badge(i: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LaneBadge"
	gui.Size = UDim2.fromOffset(44, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
	gui.AlwaysOnTop = true
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

-- Lane i's CFrame at progress p, standing on the dirt, facing the way it runs.
function TrackScene.laneCFrame(i: number, p: number): CFrame
	local x, z, dx, dz = OvalTrack.lanePoint(CFG, i, p)
	local pos = Vector3.new(x, 0, z)
	return CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz))
end

-- Straights and segmented turns for one band of the oval (the dirt, or a rail).
local function buildBand(folder: Instance, name: string, rIn: number, rOut: number, height: number, y: number,
	color: Color3, material: Enum.Material?)
	local L, cx, cz = CFG.straight, CFG.centerX, CFG.centerZ
	local w, rMid = rOut - rIn, (rIn + rOut) / 2
	local collide = name ~= "Dirt"
	for _, side in { 1, -1 } do
		part({ Name = name, Size = Vector3.new(w, height, L), Color = color, Material = material or Enum.Material.SmoothPlastic,
			CanCollide = collide, CFrame = CFrame.new(cx + side * rMid, y, cz) }).Parent = folder
	end
	local seg = math.pi / TURN_SEGMENTS
	local length = rOut * seg * 1.06 -- a little overlap so the outer edge has no gaps
	-- Far turn bulges toward -Z (s = -1), near turn toward +Z (s = 1); same geometry as OvalTrack.
	for _, turn in { { z = cz - L / 2, s = -1 }, { z = cz + L / 2, s = 1 } } do
		for j = 0, TURN_SEGMENTS - 1 do
			local a = (j + 0.5) * seg
			local pos = Vector3.new(cx + rMid * math.cos(a), y, turn.z + turn.s * rMid * math.sin(a))
			local tangent = Vector3.new(-math.sin(a), 0, turn.s * math.cos(a))
			part({ Name = name, Size = Vector3.new(w, height, length), Color = color, Material = material or Enum.Material.SmoothPlastic,
				CanCollide = collide, CFrame = CFrame.lookAt(pos, pos + tangent) }).Parent = folder
		end
	end
end

function TrackScene.build()
	if root then root:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "RaceTrack"
	local rIn, rOut = CFG.innerRadius, OvalTrack.outerRadius(CFG)
	buildBand(folder, "Dirt", rIn, rOut, 1, -0.45, DIRT, Enum.Material.Ground)
	buildBand(folder, "InnerRail", rIn - 0.3, rIn + 0.3, 0.6, 3, RAIL)
	buildBand(folder, "OuterRail", rOut - 0.3, rOut + 0.3, 0.6, 3, RAIL)

	-- Checkered start/finish line across the home straight, and the finish post outside it.
	local x0, x1, lineZ = OvalTrack.startLine(CFG)
	for k = 0, math.floor((x1 - x0) / 2) - 1 do
		for row = 0, 1 do
			part({ Name = "Finish", Size = Vector3.new(2, 0.05, 2), CanCollide = false,
				Color = if (k + row) % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(28, 31, 38),
				CFrame = CFrame.new(x0 + 1 + k * 2, 0.08, lineZ - 1 + row * 2) }).Parent = folder
		end
	end
	local post = modelFor("finish_post")
	if post then
		post:PivotTo(CFrame.new(x1 + 3, 0, lineZ) * CFrame.Angles(0, math.pi / 2, 0))
		post.Parent = folder
	end

	stalls = {}
	for i = 1, LANES do
		local stall = modelFor("gate_stall")
		if stall then
			stall:PivotTo(TrackScene.laneCFrame(i, 0) * CFrame.new(0, 0, 1))
			stall.Parent = folder
			stalls[i] = stall
		end
	end

	local horseFolder = Instance.new("Folder")
	horseFolder.Name = "Horses"
	horseFolder.Parent = folder
	horses, saddles = {}, {}
	for i = 1, LANES do
		local horse = modelFor("horse_" .. COATS[i]) or placeholderHorse(i)
		horse.Name = "Lane" .. i
		horse:PivotTo(TrackScene.laneCFrame(i, 0))
		badge(i).Parent = horse
		-- The saddle is anchored inside the model, so pivoting the horse moves it, and a
		-- seated rider (welded to it by the Seat) moves with the horse.
		local _, size = horse:GetBoundingBox()
		local saddle = Instance.new("Seat")
		saddle.Name = "Saddle"
		saddle.Size = Vector3.new(2, 0.4, 2)
		saddle.Transparency = 1
		saddle.Anchored = true
		saddle.CanCollide = false
		saddle.CanTouch = false -- nobody sits by walking into it; the server seats riders
		saddle.CFrame = horse:GetPivot() * CFrame.new(0, horse:GetAttribute("SaddleY") or size.Y * SADDLE_HEIGHT, size.Z * SADDLE_BACK)
		saddle.Parent = horse
		horse.Parent = horseFolder
		horses[i] = horse
		saddles[i] = saddle
	end
	folder.Parent = workspace
	root = folder
end

-- The gate opens: stalls clear away when the race starts.
function TrackScene.openGate()
	for _, stall in stalls do
		if stall.Parent then stall:Destroy() end
	end
	stalls = {}
end

-- Put a racing player's character in the saddle of lane `i`.
function TrackScene.seatRider(i: number, character: Model?): boolean
	local saddle = saddles[i]
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not saddle or not humanoid or humanoid.Health <= 0 then return false end
	character:PivotTo(saddle.CFrame + Vector3.new(0, 3, 0))
	saddle:Sit(humanoid)
	return true
end

-- After a race: everyone off, standing at the spawn beside the finish line.
function TrackScene.dismountAll()
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	local base = if spawn then spawn.CFrame else CFrame.new(115, 0, -24)
	for i, saddle in saddles do
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

return TrackScene
