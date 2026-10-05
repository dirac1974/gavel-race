--!nonstrict
-- RideClient (D-035): riding your own horse around the world.
--   Ride / Get off button in the dock; Gallop toggle (or hold Shift) while riding.
--   Steering: the normal move controls (thumbstick, WASD) steer the horse's Humanoid, which
--   this client owns; Space or the jump button makes the horse hop.
--   Every ride horse (yours and other players') shows its standing model when slow and its
--   galloping model when fast, with a little bob in step, computed on each screen.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local HorseLegs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HorseLegs"))

local player = Players.LocalPlayer
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local C = Ui.colors
local WALK, GALLOP = 16, 46

local controls = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and module then controls = module:GetControls() end
end)

-- Buttons ---------------------------------------------------------------------------
-- The Ride button lives in the dock (Hud); Gallop sits above the jump button on phones.
local dock = player:WaitForChild("PlayerGui"):WaitForChild("Hud"):WaitForChild("Dock")
local rideSlot = Instance.new("Frame")
rideSlot.Name = "RideSlot"
rideSlot.BackgroundTransparency = 1
rideSlot.Size = UDim2.new(0, 130, 1, 0)
rideSlot.LayoutOrder = 6
rideSlot.Parent = dock
local rideBtn = Ui.button(rideSlot, "🐴 Ride", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 1, -74), C.gold, 24)
local gui = Ui.screen("Ride", 4)
local gallopBtn = Ui.button(gui, "💨 Gallop", UDim2.fromOffset(130, 60), UDim2.new(1, -24, 1, -210), C.orange, 22)
gallopBtn.AnchorPoint = Vector2.new(1, 1)
gallopBtn.Visible = false

local riding: Model? = nil
local galloping = false

local function myHumanoid(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function currentRide(): Model?
	local h = myHumanoid()
	local seat = h and h.SeatPart
	if seat and seat.Name == "Saddle" and seat.Parent and seat.Parent.Parent and seat.Parent.Parent.Name == "RideHorses"
		and seat.Parent:GetAttribute("Owner") == player.UserId then
		return seat.Parent
	end
	return nil
end

local function setGallop(on: boolean)
	galloping = on
	gallopBtn.Text = if on then "🐢 Walk" else "💨 Gallop"
	gallopBtn.BackgroundColor3 = if on then C.sky else C.orange
end

rideBtn.Activated:Connect(function()
	if riding then
		gameRemotes:WaitForChild("GetOff"):FireServer()
	elseif not PlayerState.activeHorse() then
		Ui.toast("Pick your first horse to ride!", "heart", "🐴")
	else
		gameRemotes:WaitForChild("CallHorse"):FireServer()
	end
end)
gallopBtn.Activated:Connect(function() setGallop(not galloping) end)

-- Shift = gallop while held (PC).
ContextActionService:BindAction("GiddyUpGallop", function(_, state)
	if not riding then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then setGallop(true) elseif state == Enum.UserInputState.End then setGallop(false) end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

UserInputService.JumpRequest:Connect(function()
	if not riding then return end
	local hh = riding:FindFirstChildOfClass("Humanoid")
	if hh and hh.FloorMaterial ~= Enum.Material.Air then hh.Jump = true end
end)

local function setCharacterJump(enabled: boolean)
	local h = myHumanoid()
	if h then h:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled) end
end

-- Steering ----------------------------------------------------------------------------
local function steadyHorse(rig: Model)
	-- State changes only work on the machine that simulates the humanoid: this one.
	local hh = rig:FindFirstChildOfClass("Humanoid")
	if not hh then return end
	for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Seated } do
		hh:SetStateEnabled(state, false)
	end
end

RunService.RenderStepped:Connect(function()
	local ride = currentRide()
	local racing = RaceState.active and RaceState.myLane ~= nil
	if ride ~= riding then
		riding = ride
		if ride then steadyHorse(ride) end
		-- Space hops the horse instead of throwing you off; in a race RaceController owns jumping.
		if not racing then setCharacterJump(ride == nil) end
		rideBtn.Text = if ride then "👋 Get off" else "🐴 Ride"
		rideBtn.BackgroundColor3 = if ride then C.white else C.gold
		gallopBtn.Visible = ride ~= nil and UserInputService.TouchEnabled
		if not ride then setGallop(false) end
	end
	-- Hide the ride button while racing or with no horse yet.
	rideSlot.Visible = not racing and PlayerState.data ~= nil and #PlayerState.data.horses > 0
	if not riding then return end
	local hh = riding:FindFirstChildOfClass("Humanoid")
	if not hh then return end
	hh.WalkSpeed = if galloping then GALLOP else WALK
	local move = if controls then controls:GetMoveVector() else Vector3.zero
	hh:Move(move, true)
end)

-- Pose and bob for every ride horse on screen -------------------------------------------
local folder = workspace:WaitForChild("RideHorses", 30)
local phase: { [Model]: number } = {}
RunService.RenderStepped:Connect(function(dt)
	if not folder then return end
	for _, rig in folder:GetChildren() do
		local root = rig:FindFirstChild("HumanoidRootPart")
		local motor = root and root:FindFirstChild("Bob")
		if motor then
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local fast = speed > 22
			local anim = rig:FindFirstChild("Anim")
			if anim then HorseLegs.apply(anim, speed * dt, dt) end -- running legs (D-051)
			local stand, gallop = rig:FindFirstChild("Stand"), rig:FindFirstChild("Gallop")
			local showGallop = gallop ~= nil and (fast or stand == nil)
			for model, visible in { [stand or false] = not showGallop, [gallop or false] = showGallop } do
				if model then
					local want = if visible then 0 else 1
					if model:GetAttribute("Shown") ~= visible then
						model:SetAttribute("Shown", visible)
						for _, d in model:GetDescendants() do
							if d:IsA("BasePart") then d.LocalTransparencyModifier = want end
						end
					end
				end
			end
			-- Bob in step: quicker and higher at a gallop, a gentle nod at a walk, still when stopped.
			local hz = if fast then 2.2 else 1.6
			phase[rig] = ((phase[rig] or 0) + dt * hz * math.min(1, speed / 8)) % 1
			local amp = if fast then 0.45 else 0.12
			local y = amp * math.abs(math.sin(phase[rig] * math.pi * 2)) * math.min(1, speed / 8)
			motor.Transform = CFrame.new(0, y, 0) * CFrame.Angles(if fast then math.sin(phase[rig] * math.pi * 2) * 0.04 else 0, 0, 0)
		end
	end
	for rig in phase do
		if not rig.Parent then phase[rig] = nil end
	end
end)
