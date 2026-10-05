--!nonstrict
-- StableService (D-035, D-037, D-042): gives each player a plot on Barn Lane, builds their
-- barn with one stall per stall slot and their stalled horses standing in them, spawns them
-- at their gate, and handles Map fast-travel. Plots stay fenced; the owner's visit setting
-- (default Friends) is published on the plot so each client can close the gate locally for
-- players who aren't allowed in (WorldClient). Visitors never change anything.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Profile = require(Shared:WaitForChild("Profile"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local WorldScene = require(script.Parent:WaitForChild("WorldScene"))
local Rides = require(script.Parent:WaitForChild("Rides"))
local Care = require(Shared:WaitForChild("Care"))
local Style = require(Shared:WaitForChild("Style"))

local Travel = Profiles.remote("Travel")            -- client -> server: map destination key
local GROUND_Y = WorldScene.GROUND_Y
local C = WorldScene.colors
local part, wedge = WorldScene.part, WorldScene.wedge

local STALL_MAX_W = 14
local BARN_D = 24
local BARN_H = 15
local GATE_W = 14

local world = WorldScene.build()
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = world

local owners: { [number]: Player } = {}      -- plot index -> owner
local plotOf: { [Player]: number } = {}
local plotModels: { [number]: Model } = {}
local signatures: { [number]: string } = {}

local function plotCF(i: number, inward: number, across: number, y: number?): CFrame
	-- A frame inside plot i: `inward` studs from the lane, `across` to the right looking in,
	-- facing out toward the lane.
	local x, z = WorldLayout.plotPoint(i, inward, across)
	local ox, oz = WorldLayout.plotPoint(i, inward - 10, across)
	local pos = Vector3.new(x, y or 0, z)
	return CFrame.lookAt(pos, Vector3.new(ox, y or 0, oz))
end

-- The fenced shell every plot has, owned or not.
local function buildShell(i: number): Model
	local m = Instance.new("Model")
	m.Name = "Plot" .. i
	m:SetAttribute("PlotIndex", i)
	local F, D = WorldLayout.PLOT_FRONT, WorldLayout.PLOT_DEPTH
	local centre = plotCF(i, D / 2, 0)
	part({ Name = "Lawn", Size = Vector3.new(F - 1, 0.2, D - 1), Color = C.plotGrass, Material = Enum.Material.Grass,
		CFrame = centre * CFrame.new(0, GROUND_Y + 0.04, 0) }, m)
	-- Fence: front with a gate gap, two sides, back. Points are (inward, across).
	local h = F / 2
	local function fenceIA(a0: number, c0: number, a1: number, c1: number)
		local x0, z0 = WorldLayout.plotPoint(i, a0, c0)
		local x1, z1 = WorldLayout.plotPoint(i, a1, c1)
		WorldScene.fence(m, x0, z0, x1, z1)
	end
	-- Neighbouring plots share a side: only the lower-numbered plot builds the shared fence.
	local function neighbourOn(across: number): number?
		local x, z = WorldLayout.plotPoint(i, D / 2, across * 1.05)
		for j = 1, WorldLayout.PLOT_COUNT do
			local r = WorldLayout.plotRect(j)
			if j ~= i and x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then return j end
		end
		return nil
	end
	fenceIA(1, -h, 1, -GATE_W / 2)
	fenceIA(1, GATE_W / 2, 1, h)
	local right, left = neighbourOn(h), neighbourOn(-h)
	if not right or right > i then fenceIA(1, h, D, h) end
	fenceIA(D, h, D, -h)
	if not left or left > i then fenceIA(D, -h, 1, -h) end
	-- Privacy walls (D-042): invisible and passable on the server; each client turns them
	-- solid for itself when the owner's setting doesn't let it in.
	local walls = Instance.new("Folder")
	walls.Name = "PrivacyWalls"
	walls.Parent = m
	local function wall(a: number, c: number, len: number, alongAcross: boolean)
		local cf = plotCF(i, a, c, GROUND_Y + 8)
		local size = if alongAcross then Vector3.new(len, 16, 1) else Vector3.new(1, 16, len)
		part({ Name = "Wall", Size = size, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = cf }, walls)
	end
	wall(0.5, 0, F, true)          -- front, across the gate too
	wall(D, 0, F, true)            -- back
	wall(D / 2, -h, D, false)      -- left
	wall(D / 2, h, D, false)       -- right
	-- Name sign by the gate.
	local signPos = (plotCF(i, -1, GATE_W / 2 + 6, GROUND_Y + 6)).Position
	local x, z = WorldLayout.plot(i).fx, WorldLayout.plot(i).fz
	local _, label = WorldScene.sign(m, signPos, Vector3.new(x, 0, z), "Free stable", "🏡", 14, 3.5, C.woodLight)
	label.Name = "OwnerLabel"
	m.Parent = plotsFolder
	return m
end

-- The barn and everything that depends on the owner's profile, rebuilt when it changes.
local function horseModel(coat: string): Model
	local m = WorldScene.model("horse_stand_" .. coat) or WorldScene.model("horse_gallop_" .. coat) or WorldScene.model("horse_" .. coat)
	if m then return m end
	m = Instance.new("Model")
	local colour = ({ bay = "8B4A2B", chestnut = "B5562B", grey = "B9BCC2", black = "2B2B30", palomino = "E3C16F" })[coat] or "8B4A2B"
	part({ Name = "Body", Size = Vector3.new(2, 3.2, 6.5), Color = Color3.fromHex(colour), CFrame = CFrame.new(0, 3.6, 0) }, m)
	part({ Name = "Head", Size = Vector3.new(1.4, 1.6, 2.4), Color = Color3.fromHex(colour), CFrame = CFrame.new(0, 5.8, -3.8) }, m)
	for _, xz in { { -0.6, -2.4 }, { 0.6, -2.4 }, { -0.6, 2.4 }, { 0.6, 2.4 } } do
		part({ Name = "Leg", Size = Vector3.new(0.6, 2.2, 0.6), Color = Color3.fromHex(colour), CFrame = CFrame.new(xz[1], 1.1, xz[2]) }, m)
	end
	m.WorldPivot = CFrame.new()
	return m
end

-- Fixed spots in the front yard for decor from the Tack & Paint shop (D-050), in plot space
-- (inward from the lane, across to the right looking in), each facing out to the lane.
local YARD_SPOTS = {
	yard_bench = { 22, 18 }, yard_lanterns = { 2, 20 }, yard_saddlerack = { 16, 32 },
	yard_picnic = { 36, -16 }, yard_haycart = { 70, -14 }, yard_bridge = { 12, -28 },
}

local function buildBarn(i: number, owner: Player, data)
	-- Your look from the Tack & Paint shop (free classic red until you choose).
	local paint = Style.worn(data, "paint")
	local plate = Style.worn(data, "plate")
	local wallC = Color3.fromHex(paint and paint.color or "C0392B")
	local roofC = Color3.fromHex(paint and paint.color2 or "7B2D26")
	local trimC = Color3.fromHex(paint and paint.color3 or "FBFBF5")
	local plateC = Color3.fromHex(plate and plate.color or "FBFBF5")
	local starSet = Style.hasSet(data, "star")
	local shell = plotModels[i]
	local old = shell:FindFirstChild("Barn")
	if old then old:Destroy() end
	local barn = Instance.new("Model")
	barn.Name = "Barn"
	local stalls = data.stalls
	-- Bays narrow a little for big barns so the barn always fits the plot front.
	local stallW = math.min(STALL_MAX_W, (WorldLayout.PLOT_FRONT - 24) / stalls)
	local width = stalls * stallW + 8
	local back = WorldLayout.PLOT_DEPTH - 6
	local front = back - BARN_D
	local mid = plotCF(i, (front + back) / 2, 0)
	-- Back and side walls, roof; the front is open stall bays with half doors.
	part({ Name = "BackWall", Size = Vector3.new(width, BARN_H, 1.2), Color = wallC, Material = Enum.Material.WoodPlanks,
		CFrame = mid * CFrame.new(0, GROUND_Y + BARN_H / 2, BARN_D / 2) }, barn) -- local +Z is away from the lane
	for _, s in { -1, 1 } do
		part({ Name = "SideWall", Size = Vector3.new(1.2, BARN_H, BARN_D), Color = wallC, Material = Enum.Material.WoodPlanks,
			CFrame = mid * CFrame.new(s * width / 2, GROUND_Y + BARN_H / 2, 0) }, barn)
	end
	local roofH = 7
	for _, s in { -1, 1 } do
		wedge({ Name = "Roof", Size = Vector3.new(width + 3, roofH, BARN_D / 2 + 2), Color = roofC,
			CFrame = mid * CFrame.new(0, GROUND_Y + BARN_H + roofH / 2, s * (BARN_D / 4 + 1)) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0) }, barn)
	end
	part({ Name = "Trim", Size = Vector3.new(width + 0.8, 1, BARN_D + 0.8), Color = trimC, CFrame = mid * CFrame.new(0, GROUND_Y + BARN_H, 0) }, barn)
	part({ Name = "Floor", Size = Vector3.new(width, 0.3, BARN_D), Color = Color3.fromHex("E8C76A"), Material = Enum.Material.Fabric,
		CFrame = mid * CFrame.new(0, GROUND_Y + 0.15, 0) }, barn)
	-- Stall bays.
	for k = 1, stalls do
		local across = -width / 2 + 4 + (k - 0.5) * stallW
		local bay = plotCF(i, front + 0.6, across)
		if k > 1 then
			part({ Name = "Divider", Size = Vector3.new(0.8, BARN_H - 2, BARN_D - 1), Color = trimC,
				CFrame = plotCF(i, (front + back) / 2, across - stallW / 2, GROUND_Y + (BARN_H - 2) / 2) }, barn)
		end
		-- Dutch half door (lower half), crossed brace.
		part({ Name = "Stall" .. k, Size = Vector3.new(stallW - 2, 4.4, 0.6), Color = trimC, -- the chores prompt hangs here
			CFrame = bay * CFrame.new(0, GROUND_Y + 2.2, 0) }, barn)
		part({ Name = "Brace", Size = Vector3.new(0.5, 6, 0.3), Color = wallC,
			CFrame = bay * CFrame.new(0, GROUND_Y + 2.2, -0.4) * CFrame.Angles(0, 0, math.rad(55)) }, barn)
		local h = data.horses[k]
		if h then
			local hm = horseModel(h.coat)
			hm.Name = "Horse_" .. h.id
			hm:PivotTo(plotCF(i, front + BARN_D / 2 + 1, across, GROUND_Y))
			for _, d in hm:GetDescendants() do
				if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
			end
			hm.Parent = barn
			local _, nameLabel = WorldScene.sign(barn, (bay * CFrame.new(0, GROUND_Y + BARN_H - 2.5, 0.2)).Position,
				bay.LookVector, h.name, if h.id == data.activeHorse then "⭐" elseif starSet then "🌟" else nil, stallW - 3, 2.2, plateC)
			nameLabel.Name = "HorseName"
		end
	end
	-- Props: hay and a water trough in front of the barn, inside the plot whatever the barn's size.
	local propA, propB = WorldLayout.PLOT_FRONT / 2 - 10, -(WorldLayout.PLOT_FRONT / 2 - 10)
	local hay = WorldScene.placeModel(barn, "hay_bale", plotCF(i, front - 6, propA, GROUND_Y))
	if not hay then
		part({ Name = "HayBale", Size = Vector3.new(4, 3, 3), Color = Color3.fromHex("E8C76A"), Material = Enum.Material.Fabric,
			CFrame = plotCF(i, front - 6, propA, GROUND_Y + 1.5) }, barn)
	end
	local trough = WorldScene.placeModel(barn, "water_trough", plotCF(i, front - 6, propB, GROUND_Y))
	if trough then
		local cf, size = trough:GetBoundingBox()
		part({ Name = "Water", Size = Vector3.new(size.X * 0.8, 0.2, size.Z * 0.6), Color = C.water, Material = Enum.Material.Glass,
			Transparency = 0.25, CanCollide = false, CFrame = cf * CFrame.new(0, size.Y * 0.32, 0) }, barn)
	else
		part({ Name = "Trough", Size = Vector3.new(6, 2, 2.6), Color = C.wood, Material = Enum.Material.Wood,
			CFrame = plotCF(i, front - 6, propB, GROUND_Y + 1) }, barn)
		part({ Name = "Water", Size = Vector3.new(5.4, 0.2, 2), Color = C.water, Material = Enum.Material.Glass, Transparency = 0.25,
			CanCollide = false, CFrame = plotCF(i, front - 6, propB, GROUND_Y + 1.9) }, barn)
	end
	-- Pasture horses graze in the front yard (up to three shown).
	for k = stalls + 1, math.min(#data.horses, stalls + 3) do
		local h = data.horses[k]
		local slot = k - stalls
		local hm = horseModel(h.coat)
		hm.Name = "Pasture_" .. h.id
		hm:PivotTo(plotCF(i, 30 + slot * 12, WorldLayout.PLOT_FRONT / 2 - 18 - (slot % 2) * 6, GROUND_Y)
			* CFrame.Angles(0, math.rad(40 * slot), 0))
		for _, d in hm:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
		end
		hm.Parent = barn
	end
	-- Yard decor you've placed (Tack & Paint shop).
	for _, it in Style.yard(data) do
		local spot = YARD_SPOTS[it.id]
		if spot and it.model then
			local placed = WorldScene.placeModel(barn, it.model, plotCF(i, spot[1], spot[2], GROUND_Y))
			if placed and it.id == "yard_lanterns" then
				WorldScene.placeModel(barn, it.model, plotCF(i, spot[1], -spot[2], GROUND_Y)) -- the pair: both sides of the gate
			end
		end
	end
	-- Barnyard bits from the uploaded art (skipped until it loads): a horseshoe over the barn,
	-- a feed bucket and brush by the first stall, a wheelbarrow and pitchfork round the side,
	-- and the post box at the gate (friends' carrot gifts, D-042).
	WorldScene.placeModel(barn, "horseshoe_decor", plotCF(i, front - 0.8, 0, GROUND_Y + BARN_H + 1.5))
	WorldScene.placeModel(barn, "feed_bucket", plotCF(i, front - 3, -width / 2 + 6, GROUND_Y))
	WorldScene.placeModel(barn, "grooming_brush", plotCF(i, front - 3, -width / 2 + 9, GROUND_Y))
	WorldScene.placeModel(barn, "wheelbarrow", plotCF(i, front - 14, propA - 6, GROUND_Y))
	WorldScene.placeModel(barn, "pitchfork", plotCF(i, front - 14, propA - 11, GROUND_Y))
	WorldScene.placeModel(barn, "post_box", plotCF(i, 3, GATE_W / 2 + 3, GROUND_Y))
	-- The Stable Board noticeboard by the gate (D-043).
	local nbCF = plotCF(i, 9, -GATE_W / 2 - 9, GROUND_Y)
	local nb = WorldScene.placeModel(barn, "noticeboard", nbCF)
	if not nb then
		for _, dx in { -3.2, 3.2 } do
			part({ Name = "NoticePost", Size = Vector3.new(0.6, 7, 0.6), Color = C.wood, CFrame = nbCF * CFrame.new(dx, 3.5, 0) }, barn)
		end
		part({ Name = "NoticeRoof", Size = Vector3.new(8, 0.6, 2), Color = C.roofRed, CFrame = nbCF * CFrame.new(0, 7.2, 0) }, barn)
	end
	local board = part({ Name = "Noticeboard", Size = Vector3.new(6.4, 4, 0.4), Color = Color3.fromHex("C9A26B"),
		Material = Enum.Material.Wood, CFrame = nbCF * CFrame.new(0, 4.6, 0) }, barn)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(320, 200)
	sg.Parent = board
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = C.ink
	t.Text = "📋 Stable Board"
	t.Parent = sg
	barn:SetAttribute("Owner", owner.UserId)
	barn.Parent = shell
end

-- Garden beds and what's growing (D-038): crops grow from little sprouts to full size and
-- sparkle when they're ready to pick. Rebuilt only when a crop's stage changes.
local CROP_SLOT = { carrot = "carrot_crop", apple = "apple_tree_small", oats = "oat_crop" }
local CROP_COLOUR = { carrot = Color3.fromHex("FF8A1F"), apple = Color3.fromHex("E5484D"), oats = Color3.fromHex("E8C76A") }
local gardenSigs: { [number]: string } = {}

local function cropStage(b, now: number): number
	if b.seed == "" then return -1 end
	return math.floor(Care.cropProgress(b, now) * 4) -- 0..3 growing, 4 ready
end

local function buildGarden(i: number, owner: Player, data, now: number)
	local shell = plotModels[i]
	local old = shell:FindFirstChild("Garden")
	if old then old:Destroy() end
	local garden = Instance.new("Model")
	garden.Name = "Garden"
	for k = 1, Care.BEDS do
		local bedCF = plotCF(i, 26 + (k - 1) * 14, -WorldLayout.PLOT_FRONT / 2 + 10, GROUND_Y)
		local bed = Instance.new("Model")
		bed.Name = "Bed" .. k
		local box = WorldScene.placeModel(bed, "garden_bed", bedCF)
		if not box then
			part({ Name = "Box", Size = Vector3.new(10, 1.6, 8), Color = C.wood, Material = Enum.Material.WoodPlanks,
				CFrame = bedCF * CFrame.new(0, 0.8, 0) }, bed)
			part({ Name = "Soil", Size = Vector3.new(9, 0.3, 7), Color = Color3.fromHex("6B4A2E"), Material = Enum.Material.Ground,
				CFrame = bedCF * CFrame.new(0, 1.6, 0) }, bed)
		end
		local b = data.garden[k]
		local seed = b and Care.SEEDS[b.seed]
		if seed then
			local progress = Care.cropProgress(b, now)
			local size = 0.35 + 0.65 * progress
			local crop = WorldScene.model(CROP_SLOT[seed.crop])
			if crop then
				crop:ScaleTo(crop:GetScale() * size)
				crop:PivotTo(bedCF * CFrame.new(0, 1.7, 0))
				for _, d in crop:GetDescendants() do
					if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
				end
				crop.Parent = bed
			else
				for r = -1, 1 do
					for c = -1, 1, 2 do
						local leaf = part({ Name = "Sprout", Size = Vector3.new(0.6, 2.2 * size, 0.6), Color = Color3.fromHex("4CAF50"), CanCollide = false,
							CFrame = bedCF * CFrame.new(c * 2.2, 1.7 + 1.1 * size, r * 2.2) }, bed)
						if progress >= 1 then
							part({ Name = "Crop", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), Color = CROP_COLOUR[seed.crop],
								CanCollide = false, CFrame = leaf.CFrame * CFrame.new(0, -0.6 * size, 0) }, bed)
						end
					end
				end
			end
			if progress >= 1 then
				local glow = part({ Name = "ReadyGlow", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false,
					CFrame = bedCF * CFrame.new(0, 3, 0) }, bed)
				local pe = Instance.new("ParticleEmitter")
				pe.Rate = 6
				pe.Lifetime = NumberRange.new(1, 1.6)
				pe.Speed = NumberRange.new(1, 2)
				pe.SpreadAngle = Vector2.new(60, 60)
				pe.Size = NumberSequence.new(0.6, 0)
				pe.LightEmission = 1
				pe.Color = ColorSequence.new(Color3.fromHex("FFE066"))
				pe.Parent = glow
			end
		end
		bed:SetAttribute("Owner", owner.UserId)
		bed.Parent = garden
	end
	garden:SetAttribute("Owner", owner.UserId)
	garden.Parent = shell
end

local function gardenSignature(data, now: number): string
	local parts = {}
	for k = 1, Care.BEDS do
		local b = data.garden[k]
		table.insert(parts, (b and b.seed or "") .. ":" .. tostring(b and cropStage(b, now) or -1))
	end
	return table.concat(parts, "|")
end

-- Care shows on the horse: a sparkle when brushed today, a star on the name plate at full care.
local function applyCare(i: number, data, now: number)
	local barn = plotModels[i]:FindFirstChild("Barn")
	if not barn then return end
	local today = now // 86400
	for k = 1, math.min(data.stalls, #data.horses) do
		local h = data.horses[k]
		local hm = barn:FindFirstChild("Horse_" .. h.id)
		if hm then
			local shiny = h.care.day == today and h.care.groomed
			local fed = h.care.day == today and h.care.fed
			local anchor = hm.PrimaryPart or hm:FindFirstChildWhichIsA("BasePart", true)
			local sparkle = anchor and anchor:FindFirstChild("Shine")
			if anchor and shiny and not sparkle then
				sparkle = Instance.new("ParticleEmitter")
				sparkle.Name = "Shine"
				sparkle.Rate = 3
				sparkle.Lifetime = NumberRange.new(0.8, 1.2)
				sparkle.Speed = NumberRange.new(0.5, 1)
				sparkle.Size = NumberSequence.new(0.5, 0)
				sparkle.LightEmission = 1
				sparkle.Color = ColorSequence.new(Color3.new(1, 1, 1))
				sparkle.Parent = anchor
			elseif sparkle and not shiny then
				sparkle:Destroy()
			end
			hm:SetAttribute("Fed", fed)
			hm:SetAttribute("Groomed", shiny)
		end
	end
end

local function signature(data): string
	local parts = { tostring(data.stalls), tostring(data.activeHorse), tostring(#data.horses) }
	-- the look from the shop
	for _, slot in { "paint", "plate" } do
		local it = Style.worn(data, slot)
		table.insert(parts, it and it.id or "")
	end
	table.insert(parts, tostring(Style.hasSet(data, "star")))
	for _, it in Style.yard(data) do table.insert(parts, it.id) end
	for _, h in data.horses do table.insert(parts, h.id .. ":" .. h.coat .. ":" .. h.name) end
	return table.concat(parts, "|")
end

local function refresh(player: Player)
	local i = plotOf[player]
	local data = Profiles.get(player)
	if not i or not data then return end
	local shell = plotModels[i]
	shell:SetAttribute("OwnerId", player.UserId)
	shell:SetAttribute("Visits", data.settings.visits)
	local label = shell:FindFirstChild("OwnerLabel", true)
	if label then label.Text = "🏡 " .. player.DisplayName .. "'s Stable" end
	local sig = signature(data)
	if signatures[i] ~= sig then
		signatures[i] = sig
		buildBarn(i, player, data)
	end
	local now = os.time()
	local gsig = gardenSignature(data, now)
	if gardenSigs[i] ~= gsig then
		gardenSigs[i] = gsig
		buildGarden(i, player, data, now)
	end
	applyCare(i, data, now)
end

local function clearPlot(i: number)
	local shell = plotModels[i]
	local barn = shell:FindFirstChild("Barn")
	if barn then barn:Destroy() end
	local garden = shell:FindFirstChild("Garden")
	if garden then garden:Destroy() end
	gardenSigs[i] = nil
	shell:SetAttribute("OwnerId", nil)
	shell:SetAttribute("Visits", nil)
	local label = shell:FindFirstChild("OwnerLabel", true)
	if label then label.Text = "🏡 Free stable" end
	signatures[i] = nil
end

local function assign(player: Player): number?
	if plotOf[player] then return plotOf[player] end
	for i = 1, WorldLayout.PLOT_COUNT do
		if not owners[i] then
			owners[i] = player
			plotOf[player] = i
			player:SetAttribute("PlotIndex", i)
			return i
		end
	end
	return nil
end

local function arrive(player: Player, dest: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local x, z, lx, lz = WorldLayout.arrival(dest, plotOf[player])
	local ground = Vector3.new(x, GROUND_Y, z)
	local facing = CFrame.lookAt(ground, Vector3.new(lx, GROUND_Y, lz))
	if Rides.travel(player, facing) then return end -- riding: you and your horse travel together
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then return end -- sitting on something else (e.g. a race horse)
	character:PivotTo(facing + Vector3.new(0, 3.5, 0))
end

local function onCharacter(player: Player)
	-- Spawn at your own gate once your stable is ready; new players arrive on Fair Street.
	local data = Profiles.whenLoaded(player, 30)
	if not player.Parent then return end
	task.wait(0.1)
	if data and #data.horses > 0 and plotOf[player] then arrive(player, "stable") else arrive(player, "plaza") end
end

Profiles.Loaded.Event:Connect(function(player: Player)
	if assign(player) then refresh(player) end
end)
Profiles.Changed.Event:Connect(function(player: Player)
	refresh(player)
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function() onCharacter(player) end)
end)
Players.PlayerRemoving:Connect(function(player: Player)
	local i = plotOf[player]
	if i then
		owners[i] = nil
		plotOf[player] = nil
		clearPlot(i)
	end
end)

-- Map fast-travel (D-035): only between races, never while riding in one.
local lastTravel: { [Player]: number } = {}
Travel.OnServerEvent:Connect(function(player: Player, dest: any)
	if typeof(dest) ~= "string" or not table.find(WorldLayout.MAP, dest) then return end
	if (lastTravel[player] or 0) > os.clock() - 1.5 then return end
	lastTravel[player] = os.clock()
	if player:GetAttribute("Racing") then return end
	arrive(player, dest)
end)

for i = 1, WorldLayout.PLOT_COUNT do plotModels[i] = buildShell(i) end
Rides.start()

-- Crops grow and care resets at rollover while nobody touches anything: check every 20 s.
task.spawn(function()
	while true do
		task.wait(20)
		for player in plotOf do task.spawn(refresh, player) end
	end
end)
for _, p in Players:GetPlayers() do
	if Profiles.get(p) and assign(p) then refresh(p) end
	p.CharacterAdded:Connect(function() onCharacter(p) end)
	if p.Character then task.spawn(onCharacter, p) end
end

-- Uploaded models replace part-built buildings, props and horses once they load.
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("RaceModels", 60)
	if not folder then return end
	if not folder:GetAttribute("Loaded") then folder:GetAttributeChangedSignal("Loaded"):Wait() end
	WorldScene.rebuildPlaces()
	for player, i in plotOf do
		signatures[i] = nil
		refresh(player)
	end
end)
