--!nonstrict
-- Rides (D-035): ride your own horse around the world. "Ride" brings your active horse to
-- you and puts you in the saddle; "Get off" sends it home to its stall.
-- The horse is a small Humanoid rig (invisible root + Humanoid, HipHeight) carrying the
-- uploaded standing and galloping models (both welded on; each client shows one by speed,
-- RideClient). The rider's client owns the rig's physics and steers it, like a character.
-- Free roaming wins nothing, so the server only checks requests, not movement.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Profile = require(Shared:WaitForChild("Profile"))
local Style = require(Shared:WaitForChild("Style"))

local PATTERN_TEXT = { stars = "⭐ ⭐ ⭐", checks = "🏁", lightning = "⚡", goldtrim = "", plain = "", dots = "• • •", star = "⭐" }

-- A saddle cloth in your shop colours. It's the horse model's own Cloth piece, cut to fit its
-- back by tools/meshy/split_legs.py and tinted here; a horse without one shows no cloth (a
-- plain box stuck out of the horse's sides).
local function addCloth(rig: Model, item)
	if not item then return end
	local cloth
	for _, d in rig:GetDescendants() do
		if d.Name == "Cloth" and d:IsA("MeshPart") then
			cloth = d
			break
		end
	end
	if not cloth then return end
	cloth.TextureID = ""
	cloth.Material = Enum.Material.Fabric
	cloth.Color = Color3.fromHex(item.color or "FBFBF5")
	cloth.Transparency = 0
	local text = PATTERN_TEXT[item.pattern or "plain"] or ""
	if text == "" and item.pattern ~= "goldtrim" then return end
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(200, 120)
		sg.LightInfluence = 1
		sg.Parent = cloth
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.4)
		l.Size = UDim2.fromScale(0.6, 0.4)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Parent = sg
		if item.pattern == "goldtrim" then
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = Color3.fromHex("E3B341")
			stroke.Thickness = 6
			stroke.Parent = l
		end
	end
end

-- Your helmet while you ride (taken off when you get off or race: races use lane colours).
local function putOnHelmet(character: Model?, item)
	local head = character and character:FindFirstChild("Head")
	if not head or not item or head:FindFirstChild("RideHelmet") then return end
	local helmet = Instance.new("Part")
	helmet.Name = "RideHelmet"
	helmet.Shape = Enum.PartType.Ball
	helmet.Size = Vector3.new(1.35, 1.35, 1.35)
	helmet.Color = Color3.fromHex(item.color or "E5484D")
	helmet.CanCollide, helmet.CanTouch, helmet.CanQuery, helmet.Massless = false, false, false, true
	helmet.CFrame = head.CFrame * CFrame.new(0, 0.25, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = head, helmet
	w.Parent = helmet
	helmet.Parent = head
	local text = PATTERN_TEXT[item.pattern or "plain"] or ""
	if text ~= "" then
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(100, 100)
		sg.Parent = helmet
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Text = text
		l.Parent = sg
	end
end

local function takeOffHelmet(character: Model?)
	local head = character and character:FindFirstChild("Head")
	local helmet = head and head:FindFirstChild("RideHelmet")
	if helmet then helmet:Destroy() end
end
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local Rides = {}

local ROOT_SIZE = Vector3.new(2.6, 3, 6.5)
local HIP = 2.6                 -- root bottom above the ground
local ROOT_Y = HIP + ROOT_SIZE.Y / 2
Rides.WALK, Rides.GALLOP = 16, 46

local folder = workspace:FindFirstChild("RideHorses") or Instance.new("Folder")
folder.Name = "RideHorses"
folder.Parent = workspace

local active: { [Player]: Model } = {}
local lastCall: { [Player]: number } = {}

local CallHorse = Profiles.remote("CallHorse")   -- client -> server: bring my horse and ride
local GetOff = Profiles.remote("GetOff")         -- client -> server: off my horse

local function modelFor(slot: string): Model?
	local f = ReplicatedStorage:FindFirstChild("RaceModels")
	local m = f and f:FindFirstChild(slot)
	return if m then m:Clone() else nil
end

local function placeholder(coat: string): Model
	local colour = ({ bay = "8B4A2B", chestnut = "B5562B", grey = "B9BCC2", black = "2B2B30", palomino = "E3C16F" })[coat] or "8B4A2B"
	local m = Instance.new("Model")
	local function p(size: Vector3, cf: CFrame)
		local part = Instance.new("Part")
		part.Size, part.CFrame, part.Color = size, cf, Color3.fromHex(colour)
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Parent = m
	end
	p(Vector3.new(2, 3.2, 6.5), CFrame.new(0, 3.6, 0))
	p(Vector3.new(1.4, 1.6, 2.4), CFrame.new(0, 5.8, -3.8))
	for _, xz in { { -0.6, -2.4 }, { 0.6, -2.4 }, { -0.6, 2.4 }, { 0.6, 2.4 } } do
		p(Vector3.new(0.6, 2.2, 0.6), CFrame.new(xz[1], 1.1, xz[2]))
	end
	m.WorldPivot = CFrame.new()
	return m
end

-- Weld every part of `visual` to `anchor`, unanchored, massless, no collisions.
local function attach(visual: Model, anchor: BasePart, name: string)
	visual.Name = name
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = anchor, d
			w.Parent = d
		end
	end
end

local function build(player: Player, h, at: CFrame): Model
	local rig = Instance.new("Model")
	rig.Name = "Ride_" .. player.UserId
	rig:SetAttribute("Owner", player.UserId)
	rig:SetAttribute("HorseName", h.name)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = at * CFrame.new(0, ROOT_Y, 0)
	root.RootPriority = 127 -- stays the assembly root with a rider welded on
	root.Parent = rig
	rig.PrimaryPart = root

	-- The visuals hang from VisualRoot through a Motor6D, so clients can bob it locally.
	local visualRoot = Instance.new("Part")
	visualRoot.Name = "VisualRoot"
	visualRoot.Size = Vector3.new(0.2, 0.2, 0.2)
	visualRoot.Transparency = 1
	visualRoot.CanCollide, visualRoot.CanTouch, visualRoot.CanQuery = false, false, false
	visualRoot.Massless = true
	visualRoot.CFrame = at
	visualRoot.Parent = rig
	local motor = Instance.new("Motor6D")
	motor.Name = "Bob"
	motor.Part0, motor.Part1 = root, visualRoot
	motor.C0 = CFrame.new(0, -ROOT_Y, 0)
	motor.Parent = root

	-- Running legs when the split model is there (D-051); otherwise standing and galloping poses.
	local anim = modelFor("horse_anim_" .. h.coat)
	local stand = if anim then nil else modelFor("horse_stand_" .. h.coat)
	local gallop = if anim then nil else (modelFor("horse_gallop_" .. h.coat) or modelFor("horse_" .. h.coat)) -- new coats use horse_gallop_<coat>
	if not anim and not stand and not gallop then stand = placeholder(h.coat) end
	local height = 4
	for name, m in { Stand = stand, Gallop = gallop, Anim = anim } do
		if m then
			m:PivotTo(at)
			local _, size = m:GetBoundingBox()
			height = math.max(height, size.Y)
			attach(m, visualRoot, name)
			m.Parent = rig
		end
	end
	rig:SetAttribute("HasGallop", gallop ~= nil)
	rig:SetAttribute("HasStand", stand ~= nil)
	if anim then HorseLegs.rig(anim, visualRoot) end

	-- Saddle seat (TrackScene uses the same proportions).
	local seat = Instance.new("Seat")
	seat.Name = "Saddle"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.Transparency = 1
	seat.CanCollide, seat.CanTouch, seat.CanQuery = false, false, false -- only Sit() seats anyone
	seat.Massless = true
	seat.CFrame = at * CFrame.new(0, height * 0.6, 0.5)
	seat.Parent = rig
	local sw = Instance.new("WeldConstraint")
	sw.Part0, sw.Part1 = root, seat
	sw.Parent = seat

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP
	humanoid.WalkSpeed = Rides.WALK
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 42
	humanoid.AutoRotate = true
	humanoid.MaxSlopeAngle = 60
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = rig
	for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Dead } do
		humanoid:SetStateEnabled(state, false)
	end

	-- Name over the horse.
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(180, 34)
	tag.StudsOffsetWorldSpace = Vector3.new(0, height + 2.5, 0)
	tag.MaxDistance = 90
	tag.AlwaysOnTop = false
	tag.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = h.name
	label.Parent = tag

	rig.Parent = folder
	pcall(function() root:SetNetworkOwner(player) end)
	return rig
end

function Rides.horseOf(player: Player): Model?
	return active[player]
end

-- Off the horse and send it home. Safe to call any time.
function Rides.dismount(player: Player)
	local rig = active[player]
	active[player] = nil
	takeOffHelmet(player.Character)
	if not rig then return end
	local seat = rig:FindFirstChild("Saddle")
	local occupant = seat and seat.Occupant
	if occupant then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then weld:Destroy() end
		occupant.Sit = false
		local hrp = occupant.Parent and occupant.Parent:FindFirstChild("HumanoidRootPart")
		if hrp then occupant.Parent:PivotTo(hrp.CFrame * CFrame.new(3.5, 1, 0)) end
	end
	rig:Destroy()
end

-- Move a rider and their horse together (Map travel).
function Rides.travel(player: Player, cf: CFrame): boolean
	local rig = active[player]
	if not rig or not rig.PrimaryPart then return false end
	rig:PivotTo(cf * CFrame.new(0, ROOT_Y, 0))
	return true
end

function Rides.call(player: Player): (boolean, string?)
	if player:GetAttribute("Racing") then return false, "You're in a race!" end
	if active[player] then return false, nil end
	local data = Profiles.get(player)
	local h = data and Profile.activeHorse(data)
	if not h then return false, "Pick your first horse to ride" end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or humanoid.Health <= 0 then return false, nil end
	if humanoid.SeatPart then return false, nil end
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
	local base = Vector3.new(hrp.Position.X, hrp.Position.Y - humanoid.HipHeight - hrp.Size.Y / 2, hrp.Position.Z)
	local at = CFrame.lookAt(base, base + look.Unit)
	local rig = build(player, h, at)
	active[player] = rig
	local data2 = Profiles.get(player)
	if data2 then
		addCloth(rig, Style.worn(data2, "cloth"))
		putOnHelmet(character, Style.worn(data2, "helmet"))
	end
	task.defer(function()
		local seat = rig:FindFirstChild("Saddle")
		if seat and humanoid.Parent then seat:Sit(humanoid) end
	end)
	-- When the rider leaves the saddle any other way (reset, jump-off), send the horse home.
	task.spawn(function()
		local seat = rig:WaitForChild("Saddle")
		task.wait(1)
		if seat.Occupant ~= humanoid and active[player] == rig then
			Rides.dismount(player) -- the sit didn't take; don't leave a riderless horse blocking the next call
			return
		end
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seat.Occupant ~= humanoid and active[player] == rig then Rides.dismount(player) end
		end)
	end)
	return true, nil
end

function Rides.start()
	CallHorse.OnServerEvent:Connect(function(player: Player)
		if os.clock() - (lastCall[player] or 0) < 1.5 then return end
		lastCall[player] = os.clock()
		local ok, why = Rides.call(player)
		if ok then
			Progress.record(player, "ride", 1)
		elseif why then
			Profiles.notify(player, why, "heart")
		end
	end)
	GetOff.OnServerEvent:Connect(function(player: Player)
		if active[player] then
			Rides.dismount(player)
			return
		end
		-- Sitting on someone else's horse somehow: just get off it.
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if seat and seat.Name == "Saddle" and seat:IsDescendantOf(folder) then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then weld:Destroy() end
			humanoid.Sit = false
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		Rides.dismount(player)
		lastCall[player] = nil
	end)
	-- A change of active horse (or losing it) sends the current ride home.
	Profiles.Changed.Event:Connect(function(player: Player)
		local rig = active[player]
		local data = Profiles.get(player)
		local h = data and Profile.activeHorse(data)
		if rig and (not h or h.name ~= rig:GetAttribute("HorseName")) then Rides.dismount(player) end
	end)
end

return Rides
