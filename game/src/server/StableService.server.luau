--!nonstrict
-- StableService (D-035, D-037, D-042): gives each player a plot on Barn Lane, builds their
-- barn with one stall per stall slot and their stalled horses standing in them, spawns them
-- at their gate, and handles Map fast-travel. Plots stay fenced; the owner's visit setting
-- (default Friends) is published on the plot so each client can close the gate locally for
-- players who aren't allowed in (WorldClient). Visitors never change anything. Each stall shows
-- a gold rosette for every training course its horse has a gold ribbon on (D-053); Mud Splash
-- has one rosette for a gold on any of its four layouts (T5, Profile.rosettes).
-- Visiting friends' barns (D-060): the Map's Friends' barns list (FriendBarns), the trip to a
-- friend's gate (VisitFriend), the owner's one-tap gate (GateToggle, GateState to the owner
-- only) and the post box (PostBox). Once a second, anyone standing in a plot who isn't let in
-- (not a friend, "Nobody", or the gate closed) is walked out to Barn Lane.
-- Rest cues (D-058, stage 4): a stalled horse at energy.yawnAt (1) shows a "🥱 Yawn!" bubble; at
-- 0 it naps in a straw bed with "💤 Napping" (the horse_lie_<coat> model when it's uploaded, else
-- the standing horse sunk into the straw). Happy-tired only: never sore, hurt or ill.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Profile = require(Shared:WaitForChild("Profile"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local WorldScene = require(script.Parent:WaitForChild("WorldScene"))
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local Rides = require(script.Parent:WaitForChild("Rides"))
local Care = require(Shared:WaitForChild("Care"))
local Style = require(Shared:WaitForChild("Style"))
local Visits = require(Shared:WaitForChild("Visits"))
local VisitAccess = require(script.Parent:WaitForChild("VisitAccess"))
local Horse = require(Shared:WaitForChild("Horse"))
local Spa = require(Shared:WaitForChild("Spa"))

local Travel = Profiles.remote("Travel")            -- client -> server: map destination key
local FriendBarns = Profiles.remote("FriendBarns")  -- client -> server: ask; server -> client: { {userId, name, closed} }
local VisitFriend = Profiles.remote("VisitFriend")  -- client -> server: friend's userId
local GateToggle = Profiles.remote("GateToggle")    -- client -> server: owner opens or closes their gate
local GateState = Profiles.remote("GateState")      -- server -> owner only: visitorsIn, closed
local PostBox = Profiles.remote("PostBox")          -- client -> server: owner's userId (drop a carrot)
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

-- Rest cues (D-058): the pose for a stalled horse's Energy now ("nap", "yawn" or nil).
local function restPose(h, now: number): string?
	return Spa.restPose(Horse.syncEnergy(h, now, GameConfig.energy), GameConfig.energy)
end

local function bubble(hm: Model, text: string, name: string)
	local anchor = hm.PrimaryPart or hm:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then return end
	local box, size = hm:GetBoundingBox()
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = UDim2.fromOffset(150, 48)
	bb.StudsOffsetWorldSpace = box.Position + Vector3.new(0, size.Y / 2 + 1.5, 0) - anchor.Position
	bb.MaxDistance = 70
	bb.AlwaysOnTop = true -- over the half door and the stall walls
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromHex("FFF8E7")
	t.BackgroundTransparency = 0.05
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromHex("2D2A32")
	t.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = t
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = t
	t.Parent = bb
	bb.Parent = anchor
end

-- A napping horse: the lying model, or the standing one sunk into a straw bed (the bed hides its legs).
local function nappingHorse(coat: string, at: CFrame): Model
	local lying = WorldScene.model("horse_lie_" .. coat)
	if lying then
		lying:PivotTo(at)
		return lying
	end
	local hm = horseModel(coat)
	hm:PivotTo(at * CFrame.new(0, -GameConfig.spa.napLowerStuds, 0))
	part({ Name = "StrawBed", Size = Vector3.new(6, GameConfig.spa.napLowerStuds + 0.6, 10), Color = Color3.fromHex("E8C76A"),
		Material = Enum.Material.Fabric, CanCollide = false, CFrame = at * CFrame.new(0, (GameConfig.spa.napLowerStuds + 0.6) / 2, 0) }, hm)
	return hm
end

-- Fixed spots in the front yard for decor from the Tack & Paint shop (D-050), in plot space
-- (inward from the lane, across to the right looking in), each facing out to the lane.
local YARD_SPOTS = {
	yard_bench = { 22, 18 }, yard_lanterns = { 2, 20 }, yard_saddlerack = { 16, 32 },
	yard_picnic = { 36, -16 }, yard_haycart = { 70, -14 }, yard_bridge = { 12, -28 },
}

-- Training rides (D-053): a gold rosette on the stall for each course this horse has a gold
-- ribbon on, in a row under its name plate (the uploaded rosette_ribbon, or a part one). One
-- per stat: a gold on any Mud Splash layout makes the Mud Splash rosette (T5).
local GOLD = Color3.fromHex("FFD23F")
local function rosettes(barn: Instance, bay: CFrame, h)
	local golds = Profile.rosettes(h)
	for k, course in golds do
		local x = (k - (#golds + 1) / 2) * 1.9
		local cf = bay * CFrame.new(x, GROUND_Y + BARN_H - 4.6, 0.45)
		local m = WorldScene.model("rosette_ribbon")
		if m then
			m:PivotTo(cf * CFrame.new(0, -1.2, 0))
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
			end
			m.Name = "Rosette_" .. course
			m.Parent = barn
		else
			part({ Name = "Rosette_" .. course, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.4, 1.4), Color = GOLD,
				CanCollide = false, CFrame = cf * CFrame.Angles(0, math.pi / 2, 0) }, barn)
			for _, sd in { -1, 1 } do
				part({ Name = "RosetteTail", Size = Vector3.new(0.35, 1.1, 0.1), Color = GOLD, CanCollide = false,
					CFrame = cf * CFrame.new(sd * 0.25, -1, 0.05) * CFrame.Angles(0, 0, sd * 0.25) }, barn)
			end
		end
	end
end

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
		local door = barn:FindFirstChild("Stall" .. k)
		if door and h then door:SetAttribute("HorseId", h.id) door:SetAttribute("HorseName", h.name) end
		if h then
			local at = plotCF(i, front + BARN_D / 2 + 1, across, GROUND_Y)
			local pose = restPose(h, os.time())
			local hm = if pose == "nap" then nappingHorse(h.coat, at) else horseModel(h.coat)
			hm.Name = "Horse_" .. h.id
			if pose ~= "nap" then hm:PivotTo(at) end
			for _, d in hm:GetDescendants() do
				if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
			end
			hm:SetAttribute("Rest", pose or "")
			hm.Parent = barn
			if pose == "nap" then
				bubble(hm, Spa.NAP, "RestBubble")
			elseif pose == "yawn" then
				bubble(hm, Spa.YAWN, "RestBubble")
			end
			local _, nameLabel = WorldScene.sign(barn, (bay * CFrame.new(0, GROUND_Y + BARN_H - 2.5, 0.2)).Position,
				bay.LookVector, h.name, if h.id == data.activeHorse then "⭐" elseif starSet then "🌟" else nil, stallW - 3, 2.2, plateC)
			nameLabel.Name = "HorseName"
			rosettes(barn, bay, h)
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
	-- The post box shows carrots on the days friends dropped some (D-060), and a box part holds
	-- the visitors' "Drop a carrot" prompt (VisitClient) whether or not the art has loaded.
	local boxCF = plotCF(i, 3, GATE_W / 2 + 3, GROUND_Y)
	local carrots = data.postBox and data.postBox.day == os.time() // 86400 and data.postBox.today > 0
	if not (carrots and WorldScene.placeModel(barn, "post_box_carrots", boxCF)) then
		if not WorldScene.placeModel(barn, "post_box", boxCF) then
			part({ Name = "PostBoxPost", Size = Vector3.new(0.6, 3.4, 0.6), Color = C.wood, CFrame = boxCF * CFrame.new(0, 1.7, 0) }, barn)
			part({ Name = "PostBoxBox", Size = Vector3.new(1.8, 1.4, 2.4), Color = Color3.fromHex("7EC8E3"), CFrame = boxCF * CFrame.new(0, 3.9, 0) }, barn)
		end
	end
	if carrots then -- a little pile of carrots on the lid, so a kid sees the gift from the lane
		for k = -1, 1 do
			local c = part({ Name = "PostCarrot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.45, 0.45),
				Color = Color3.fromHex("FF8A1F"), CanCollide = false, CFrame = boxCF * CFrame.new(k * 0.45, 4.95, 0) * CFrame.Angles(0, math.pi / 2 + k * 0.3, 0) }, barn)
			part({ Name = "PostCarrotTop", Size = Vector3.new(0.3, 0.5, 0.3), Color = Color3.fromHex("4CAF50"), CanCollide = false,
				CFrame = c.CFrame * CFrame.new(0.8, 0, 0) * CFrame.Angles(0, 0, math.pi / 2) }, barn)
		end
	end
	local spot = part({ Name = "PostBox", Size = Vector3.new(3, 5, 3), Transparency = 1, CanCollide = false, CanQuery = false,
		CanTouch = false, CFrame = boxCF * CFrame.new(0, 2.5, 0) }, barn)
	spot:SetAttribute("Owner", owner.UserId)
	-- The visitor bell on the other gate post (rung when the owner opens or closes the gate).
	local bellCF = plotCF(i, 3, -(GATE_W / 2 + 3), GROUND_Y)
	if not WorldScene.placeModel(barn, "visitor_bell", bellCF) then
		part({ Name = "BellPost", Size = Vector3.new(0.8, 5, 0.8), Color = C.wood, CFrame = bellCF * CFrame.new(0, 2.5, 0) }, barn)
		part({ Name = "Bell", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Color = Color3.fromHex("D4A537"),
			Material = Enum.Material.Metal, CanCollide = false, CFrame = bellCF * CFrame.new(0, 4.6, -0.8) }, barn)
	end
	-- The Rosette Wall (D-060, D-062): what visitors see; stage 8 hangs the rosettes on it.
	WorldScene.placeModel(barn, "rosette_wall", plotCF(i, 52, 12, GROUND_Y))
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

-- A horse out riding or at the races isn't in its stall too (D-056): the stall is empty, with
-- a plaque on the door ("Comet is out riding" / "Comet is at the races"), and its Care prompt
-- is hidden (the door's Away attribute). Rides sets RidingHorse; RaceService sets RacingHorse.
local function awayKind(player: Player, id: string): string?
	if player:GetAttribute("RacingHorse") == id then return "races" end
	if player:GetAttribute("RidingHorse") == id then return "riding" end
	return nil
end

local function applyAway(i: number, player: Player, data)
	local barn = plotModels[i]:FindFirstChild("Barn")
	if not barn or not GameConfig.stable.awaySign then return end
	for k = 1, math.min(data.stalls, #data.horses) do
		local h = data.horses[k]
		local hm = barn:FindFirstChild("Horse_" .. h.id)
		local door = barn:FindFirstChild("Stall" .. k)
		local away = awayKind(player, h.id)
		if hm then
			for _, d in hm:GetDescendants() do
				if d:IsA("BasePart") then
					if d:GetAttribute("BaseT") == nil then d:SetAttribute("BaseT", d.Transparency) end
					d.Transparency = if away then 1 else d:GetAttribute("BaseT")
				elseif d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then -- (the rest bubble, D-058)
					if d:GetAttribute("BaseOn") == nil then d:SetAttribute("BaseOn", d.Enabled) end
					d.Enabled = not away and d:GetAttribute("BaseOn")
				end
			end
		end
		if door then
			door:SetAttribute("Away", away ~= nil)
			local old = barn:FindFirstChild("AwaySign" .. k)
			local text = if away == "races" then h.name .. " is at the races" elseif away then h.name .. " is out riding" else nil
			if old and old:GetAttribute("Text") ~= text then
				old:Destroy()
				old = nil
			end
			if text and not old then
				local look = door.CFrame.LookVector
				local plaque = WorldScene.sign(barn, (door.CFrame * CFrame.new(0, 1, -0.65)).Position, look, text,
					if away == "races" then "🏁" else "🐴", math.max(4, door.Size.X - 1), 1.6)
				plaque.Name = "AwaySign" .. k
				plaque:SetAttribute("Text", text)
				plaque.CanCollide = false
			end
		end
	end
end

local function signature(data, now: number): string
	local parts = { tostring(data.stalls), tostring(data.activeHorse), tostring(#data.horses) }
	-- the look from the shop
	for _, slot in { "paint", "plate" } do
		local it = Style.worn(data, slot)
		table.insert(parts, it and it.id or "")
	end
	table.insert(parts, tostring(Style.hasSet(data, "star")))
	table.insert(parts, tostring(data.postBox and data.postBox.day == os.time() // 86400 and data.postBox.today > 0)) -- D-060
	for _, it in Style.yard(data) do table.insert(parts, it.id) end
	for _, h in data.horses do
		local golds = table.concat(Profile.rosettes(h), ",")
		table.insert(parts, h.id .. ":" .. h.coat .. ":" .. h.name .. ":" .. golds) -- gold rosettes (D-053)
	end
	for k = 1, math.min(data.stalls, #data.horses) do -- rest cues (D-058): yawning or napping
		table.insert(parts, restPose(data.horses[k], now) or "")
	end
	return table.concat(parts, "|")
end

local function refresh(player: Player)
	local i = plotOf[player]
	local data = Profiles.get(player)
	if not i or not data then return end
	local shell = plotModels[i]
	shell:SetAttribute("OwnerId", player.UserId)
	shell:SetAttribute("Visits", data.settings.visits)
	shell:SetAttribute("GateClosed", VisitAccess.gateClosed(player))
	local label = shell:FindFirstChild("OwnerLabel", true)
	if label then label.Text = "🏡 " .. player.DisplayName .. "'s Stable" end
	local now = os.time()
	local sig = signature(data, now)
	if signatures[i] ~= sig then
		signatures[i] = sig
		buildBarn(i, player, data)
	end
	local gsig = gardenSignature(data, now)
	if gardenSigs[i] ~= gsig then
		gardenSigs[i] = gsig
		buildGarden(i, player, data, now)
	end
	applyCare(i, data, now)
	applyAway(i, player, data)
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
	shell:SetAttribute("GateClosed", nil)
	local bar = shell:FindFirstChild("GateBar")
	if bar then bar:Destroy() end
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

local function arriveAt(player: Player, x: number, z: number, lx: number, lz: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local ground = Vector3.new(x, GROUND_Y, z)
	local facing = CFrame.lookAt(ground, Vector3.new(lx, GROUND_Y, lz))
	if Rides.travel(player, facing) then return end -- riding: you and your horse travel together
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then return end -- sitting on something else (e.g. a race horse)
	character:PivotTo(facing + Vector3.new(0, 3.5, 0))
end

local function arrive(player: Player, dest: string)
	local x, z, lx, lz = WorldLayout.arrival(dest, plotOf[player])
	arriveAt(player, x, z, lx, lz)
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

-- The horse is back in its stall the moment you get off or its race ends.
local function watchAway(player: Player)
	for _, name in { "RidingHorse", "RacingHorse" } do
		player:GetAttributeChangedSignal(name):Connect(function() refresh(player) end)
	end
end
for _, player in Players:GetPlayers() do watchAway(player) end
Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function() onCharacter(player) end)
	watchAway(player)
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
local function canTravel(player: Player): boolean
	if player:GetAttribute("Racing") then return false end
	-- Still on a race horse after your race: its results card's Done gets you off (D-056).
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat.Name == "Saddle" and not seat:IsDescendantOf(workspace:FindFirstChild("RideHorses") or game) then
		Profiles.notify(player, "Tap Done first", "map_fair")
		return false
	end
	return true
end
Travel.OnServerEvent:Connect(function(player: Player, dest: any)
	if typeof(dest) ~= "string" or not table.find(WorldLayout.MAP, dest) then return end
	if (lastTravel[player] or 0) > os.clock() - 1.5 then return end
	lastTravel[player] = os.clock()
	if not canTravel(player) then return end
	arrive(player, dest)
end)

-- Visiting friends' barns (D-060) ------------------------------------------------------
local CFG = GameConfig.visit
local lastVisitAsk: { [Player]: number } = {}
local lastPost: { [Player]: number } = {}
local lastGate: { [Player]: number } = {}
local walkedAt: { [Player]: number } = {}

local function barnOwners(): { Visits.Owner }
	local out = {}
	for player in plotOf do
		local data = Profiles.get(player)
		if data then
			table.insert(out, { userId = player.UserId, name = player.DisplayName, visits = data.settings.visits,
				gateClosed = VisitAccess.gateClosed(player), hasBarn = #data.horses > 0 })
		end
	end
	return out
end

local function isFriend(a: number, b: number): boolean
	local pa, pb = Players:GetPlayerByUserId(a), Players:GetPlayerByUserId(b)
	return pa ~= nil and pb ~= nil and VisitAccess.friends(pa, pb)
end

FriendBarns.OnServerEvent:Connect(function(player: Player)
	if (lastVisitAsk[player] or 0) > os.clock() - 0.5 then return end
	lastVisitAsk[player] = os.clock()
	FriendBarns:FireClient(player, Visits.list(player.UserId, barnOwners(), isFriend, CFG))
end)

VisitFriend.OnServerEvent:Connect(function(player: Player, userId: any)
	if not CFG.mapList then return end
	local owner = VisitAccess.owner(userId)
	local ok, why = VisitAccess.check(player, owner)
	if not ok then
		if why == "closed" then Profiles.notify(player, "That gate is closed right now. Try again later!", "heart") end
		return
	end
	if (lastTravel[player] or 0) > os.clock() - CFG.travelGapSeconds then return end
	if not canTravel(player) then return end
	local odata = Profiles.get(owner)
	local i = plotOf[owner]
	if not i or not odata or #odata.horses == 0 then return end -- the same barns Visits.list shows
	lastTravel[player] = os.clock()
	local x, z, lx, lz = WorldLayout.gateArrival(i)
	arriveAt(player, x, z, lx, lz)
	Profiles.notify(player, "Welcome to " .. owner.DisplayName .. "'s barn! Pat each horse for a Tour stamp", "heart")
end)

PostBox.OnServerEvent:Connect(function(player: Player, userId: any)
	if (lastPost[player] or 0) > os.clock() - 0.5 then return end
	lastPost[player] = os.clock()
	local owner = VisitAccess.owner(userId)
	if not VisitAccess.check(player, owner) or not VisitAccess.near(player, owner) then return end
	local vdata, odata = Profiles.get(player), Profiles.get(owner)
	if not vdata or not odata then return end
	local ok, res = Visits.post(vdata, odata, owner.UserId, os.time(), CFG)
	if not ok then
		local msg = ({ used = "You dropped a carrot here today. Come back tomorrow!", full = "The post box is full today",
			none = "You need a carrot first. Grow some in your garden!" })[res.reason] or "Not now"
		Profiles.notify(player, msg, "carrot")
		return
	end
	Profiles.notify(player, "Carrot dropped in the post box!", "carrot")
	Profiles.notify(owner, "A friend left a carrot in your post box! (" .. res.today .. " today)", "carrot")
	Profiles.changed(player)
	Profiles.changed(owner)
end)

-- The gate (D-060): the owner's button shows while anyone is visiting or the gate is closed.
local gateSent: { [Player]: string } = {}
local function sendGate(owner: Player, visitorsIn: boolean)
	local closedNow = VisitAccess.gateClosed(owner)
	local k = tostring(visitorsIn) .. tostring(closedNow)
	if gateSent[owner] == k then return end
	gateSent[owner] = k
	GateState:FireClient(owner, visitorsIn, closedNow)
end

local function applyGate(owner: Player)
	local i = plotOf[owner]
	if not i then return end
	local shell = plotModels[i]
	local isClosed = VisitAccess.gateClosed(owner)
	shell:SetAttribute("GateClosed", isClosed)
	local bar = shell:FindFirstChild("GateBar")
	if isClosed and not bar then
		local x0, z0 = WorldLayout.plotPoint(i, 1, -GATE_W / 2)
		local x1, z1 = WorldLayout.plotPoint(i, 1, GATE_W / 2)
		local a, b = Vector3.new(x0, GROUND_Y + 2.6, z0), Vector3.new(x1, GROUND_Y + 2.6, z1)
		part({ Name = "GateBar", Size = Vector3.new(0.6, 0.6, (b - a).Magnitude), Color = C.woodLight or C.wood,
			CanCollide = false, CFrame = CFrame.lookAt((a + b) / 2, b) }, shell)
	elseif not isClosed and bar then
		bar:Destroy()
	end
end

-- Walk out (to Barn Lane, just outside the gate) everyone standing in a plot who isn't let in.
local function sweep()
	for owner, i in plotOf do
		local rect = WorldLayout.plotRect(i)
		local people = {}
		for _, p in Players:GetPlayers() do
			local pos = VisitAccess.position(p)
			if pos and p ~= owner then table.insert(people, { userId = p.UserId, x = pos.X, z = pos.Z }) end
		end
		local inside = Visits.toWalkOut(rect, owner.UserId, people)
		local visitorsIn = false
		for _, uid in inside do
			local visitor = Players:GetPlayerByUserId(uid)
			if visitor and not visitor:GetAttribute("Racing") then
				local ok, why = VisitAccess.check(visitor, owner)
				if ok then
					visitorsIn = true
				elseif why == "friends" or why == "private" or why == "closed" then
					-- ("off", visits switched off in GameConfig, leaves friends where they are, as before D-060)
					local x, z, lx, lz = WorldLayout.gateArrival(i)
					arriveAt(visitor, x, z, x + (x - lx), z + (z - lz)) -- facing the lane, back to the gate
					if why == "closed" and (walkedAt[visitor] or 0) < os.clock() - 10 then
						walkedAt[visitor] = os.clock()
						Profiles.notify(visitor, owner.DisplayName .. "'s gate is closing. Bye for now!", "heart")
					end
				end
			end
		end
		sendGate(owner, visitorsIn)
	end
end

GateToggle.OnServerEvent:Connect(function(player: Player)
	if not plotOf[player] then return end
	if (lastGate[player] or 0) > os.clock() - 0.5 then return end
	lastGate[player] = os.clock()
	VisitAccess.setGate(player, not VisitAccess.gateClosed(player))
	applyGate(player)
	Profiles.notify(player, if VisitAccess.gateClosed(player) then "Gate closed. Visitors head home." else "Gate open. Friends can visit.", "map_stable")
	gateSent[player] = nil
	sweep()
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastVisitAsk[player], lastPost[player], lastGate[player], walkedAt[player], gateSent[player] = nil, nil, nil, nil, nil
end)

task.spawn(function()
	while true do
		task.wait(1)
		local ok, err = pcall(sweep)
		if not ok then warn("[StableService] visit sweep: " .. tostring(err)) end
	end
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
