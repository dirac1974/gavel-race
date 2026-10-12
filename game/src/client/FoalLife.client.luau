--!nonstrict
-- FoalLife (D-080, the feel vote F7): for its first foalLook.tagAlongRaces counted races a bred foal
-- tags along behind its parent and frolics. Client only, nothing saved, never in a race, in line or on
-- a training ride.
--   Parent ridden around (Ride_<UserId>): the foal trots foalLook.followStuds behind and sideStuds
--   aside, never faster than the parent + catchUp studs/s.
--   Parent at home (its stall or the Hall of Fame paddock): the foal stands at its flank.
--   Every hopEvery seconds a little hop (hopStuds), with the young nicker on at most 1 in nickerEvery.
--   Reduced Motion: following kept, no hops.
-- The foal's own stall model is hidden on this screen while it tags along (one foal, never two).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local HorseLook = require(Shared:WaitForChild("HorseLook"))

local F = GameConfig.foalLook
if not F or F.enabled == false then return end
local player = Players.LocalPlayer

local function calm(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

local function away(): boolean
	return not GameConfig.breeding.enabled or player:GetAttribute("Racing") == true or player:GetAttribute("InLine") == true
		or player:GetAttribute("TrainingRide") ~= nil
end

-- The foal tagging along now: the youngest bred horse still in its first tagAlongRaces races.
local function current(): any
	local d = PlayerState.data
	if not d then return nil end
	for _, h in d.horses do
		if h.origin == "bred" and typeof(h.parents) == "table" and (h.record and h.record.races or 0) < F.tagAlongRaces and not h.lent then
			return h
		end
	end
	return nil
end

local function myPlot(): Instance?
	local i = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	return i and plots and plots:FindFirstChild("Plot" .. i)
end

local function findModel(prefixes: { string }, id: string): Model?
	local plot = myPlot()
	if not plot then return nil end
	for _, pre in prefixes do
		local m = plot:FindFirstChild(pre .. id, true)
		if m and m:IsA("Model") then return m end
	end
	return nil
end

local function hide(m: Model?, on: boolean)
	if not m then return end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = if on then 1 else 0 end
	end
end

local companion: Model? = nil
local companionFor: string? = nil
local companionKey = "" -- the foal's size step (HorseLook.foalKey): a growth step builds it again at the new size
local lift = 0 -- the companion's pivot height over its hooves

local function build(h): Model?
	local folder = ReplicatedStorage:FindFirstChild("RaceModels")
	local src = folder and (folder:FindFirstChild("horse_stand_" .. h.coat) or folder:FindFirstChild("horse_gallop_" .. h.coat))
	if not src then return nil end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
	end
	m.Name = "FoalCompanion"
	m:PivotTo(CFrame.new(0, -500, 0))
	m.Parent = workspace
	HorseLook.shapeFoal(m, HorseLook.foal(h) or { body = F.body, legY = F.legY })
	local cf, size = m:GetBoundingBox()
	lift = m:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	return m
end

local function drop()
	if companion then companion:Destroy() end
	companion, companionFor = nil, nil
end

local rigCache: Instance? = nil
local rigAt = 0
local function rideRig(): Model?
	if os.clock() - rigAt > 0.5 or (rigCache and not rigCache.Parent) then
		rigAt = os.clock()
		rigCache = workspace:FindFirstChild("Ride_" .. player.UserId, true)
	end
	return if rigCache and rigCache:IsA("Model") then rigCache else nil
end

local nextHop = os.clock() + 8
local hops = 0
local lastPos: Vector3? = nil
local speed = 0

RunService.Heartbeat:Connect(function(dt)
	local h = current()
	if not h or away() then
		if companionFor then hide(findModel({ "Horse_" }, companionFor), false) end
		drop()
		return
	end
	if companionFor ~= h.id or companionKey ~= HorseLook.foalKey(h) then
		drop()
		companion = build(h)
		companionFor = h.id
		companionKey = HorseLook.foalKey(h)
		if not companion then return end
		lastPos = nil
	end
	local m = companion
	if not m then return end
	local parentId = h.parents[1]
	-- where the parent is: riding (the ride rig) or at home (stall or Hall of Fame paddock)
	local riding = player:GetAttribute("RidingHorse")
	local target: CFrame? = nil
	local follow = false
	if riding == parentId or riding == h.parents[2] then
		local rig = rideRig()
		if rig then
			local cf = rig:GetPivot()
			local ground = cf.Position.Y - (rig:GetExtentsSize().Y / 2)
			target = CFrame.new(cf.Position.X, ground, cf.Position.Z) * cf.Rotation * CFrame.new(F.sideStuds, 0, F.followStuds)
			follow = true
			local p = cf.Position
			if lastPos then speed = (p - lastPos).Magnitude / math.max(dt, 1e-3) end
			lastPos = p
		end
	end
	if not target then
		local pm = findModel({ "Horse_", "Legend_" }, parentId) or findModel({ "Horse_", "Legend_" }, h.parents[2])
		if pm then
			local cf, size = pm:GetBoundingBox()
			target = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z) * cf.Rotation * CFrame.new(-size.X * 0.9, 0, size.Z * 0.2)
		end
	end
	local own = findModel({ "Horse_" }, h.id)
	if not target then
		hide(own, false)
		m:PivotTo(CFrame.new(0, -500, 0))
		return
	end
	hide(own, true)
	local here = m:GetPivot() - Vector3.new(0, lift, 0)
	if here.Position.Y < -100 then here = target end
	local step = (target.Position - here.Position)
	local maxMove = (if follow then speed + F.catchUp else 40) * dt
	local move = if step.Magnitude > maxMove and step.Magnitude < 60 then step.Unit * maxMove else step
	local pos = here.Position + move
	local face = target.Rotation
	local hopY = 0
	if not calm() and os.clock() >= nextHop then
		local t = os.clock() - nextHop
		if t < 0.3 then
			hopY = math.sin(t / 0.3 * math.pi) * F.hopStuds
		else
			hops += 1
			nextHop = os.clock() + F.hopEvery[1] + math.random() * (F.hopEvery[2] - F.hopEvery[1])
			if Sound and hops % F.nickerEvery == 1 then Sound.play("horse_nicker", 0.25, nil, F.nickerSpeed) end
		end
	end
	m:PivotTo(CFrame.new(pos.X, target.Position.Y + lift + hopY, pos.Z) * face)
end)

PlayerState.Changed.Event:Connect(function()
	if not current() then drop() end
end)
