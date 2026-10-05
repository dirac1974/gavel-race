--!nonstrict
-- RideClient (D-035): riding your own horse around the world.
--   Ride / Get off button in the dock; Gallop toggle (or hold Shift) while riding.
--   Steering: the normal move controls (thumbstick, WASD) steer the horse's Humanoid, which
--   this client owns; Space or the jump button makes the horse hop.
--   Every ride horse (yours and other players') shows its standing model when slow and its
--   galloping model when fast, with a little bob in step, computed on each screen.
--   Course mode (training rides, D-053; TrainingState): held still for the 3-2-1, then the
--   horse rides at the course's own speed by itself (a gallop on the oval, an arena lope in the
--   gymkhana, a canter through the poles) and is pulled gently toward the next hoop within
--   magnetStuds of its edge. Gamepad R2 gallops too (L3 kept; ButtonX stays the prompt key).
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
local TrainingCourses = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrainingCourses"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local TrainingState = require(script.Parent:WaitForChild("TrainingState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

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
-- Hop (D-056): riding switches the character's jumping off (a jump would throw you out of the
-- saddle), which hides Roblox's own jump button on phones. This takes its place and size,
-- under Gallop, and hops the horse. Training rides show their own Jump instead.
local hopBtn = Ui.button(gui, "⬆️ Hop", UDim2.fromOffset(70, 70), UDim2.new(1, -95, 1, -90), C.sky, 20)
hopBtn.Visible = false
hopBtn:SetAttribute("NoPop", true)
local function placeHop()
	local cam = workspace.CurrentCamera
	local small = not cam or math.min(cam.ViewportSize.X, cam.ViewportSize.Y) <= 500
	local size = if small then 70 else 120
	hopBtn.Size = UDim2.fromOffset(size, size)
	hopBtn.Position = UDim2.new(1, -(size * 1.5 - 10), 1, if small then -90 else -210)
end
placeHop()

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

local lastGiddyUp = -math.huge
local function setGallop(on: boolean)
	if on and not galloping and Sound and os.clock() - lastGiddyUp > 20 then -- "Giddy-up!", not on every Shift
		lastGiddyUp = os.clock()
		Sound.stop("ui_pop") -- the Gallop button's pop would land on top of the line
		Sound.play("vo_giddyup", 0.8)
	end
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

-- Shift = gallop while held (PC). Bound above Shift Lock's own binding, so while you ride
-- Shift gallops instead of locking the mouse (D-056); on foot it passes through as usual.
ContextActionService:BindActionAtPriority("GiddyUpGallop", function(_, state)
	if not riding then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then setGallop(true) elseif state == Enum.UserInputState.End then setGallop(false) end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3, Enum.KeyCode.ButtonR2)

local function hop()
	if not riding or TrainingState.phase == "countdown" then return end
	local hh = riding:FindFirstChildOfClass("Humanoid")
	if hh and hh.FloorMaterial ~= Enum.Material.Air then hh.Jump = true end
end
UserInputService.JumpRequest:Connect(hop)
hopBtn.MouseButton1Down:Connect(hop)

local function setCharacterJump(enabled: boolean)
	local h = myHumanoid()
	if h then h:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled) end
end

-- Steering ----------------------------------------------------------------------------
-- The move vector as a world direction (what Humanoid:Move(v, true) does with the camera).
local function worldMove(move: Vector3): Vector3
	local cam = workspace.CurrentCamera
	if not cam or move.Magnitude < 1e-3 then return Vector3.zero end
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	if look.Magnitude < 1e-3 then look = Vector3.new(cam.CFrame.UpVector.X, 0, cam.CFrame.UpVector.Z) end
	if look.Magnitude < 1e-3 then return Vector3.zero end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	return right * move.X - look * move.Z
end

-- A soft pull toward the next hoop when the horse is heading for it and within magnetStuds of
-- its edge (D-053). It never steers on its own: no stick, no pull.
local MAGNET = GameConfig.training.magnetStuds
local COURSE_DEADZONE = 0.2
local function magnet(dir: Vector3, pos: Vector3): Vector3
	local t = TrainingState.target
	if not t or dir.Magnitude < 1e-3 then return dir end
	local toX, toZ = t.x - pos.X, t.z - pos.Z
	local ahead = toX * t.nx + toZ * t.nz
	if ahead < 2 or ahead > 30 then return dir end
	local sideX, sideZ = toX - t.nx * ahead, toZ - t.nz * ahead
	local side = math.sqrt(sideX * sideX + sideZ * sideZ)
	if side < 0.5 or side > t.half + MAGNET then return dir end
	if dir.X * t.nx + dir.Z * t.nz <= 0 then return dir end
	local pull = Vector3.new(toX, 0, toZ).Unit
	return (dir.Unit * 0.7 + pull * 0.3).Unit * dir.Magnitude
end

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
		if not ride then setGallop(false) end
	end
	-- Courses gallop by themselves, so the Gallop button steps aside (the training ride's own
	-- Jump button takes that corner).
	local touch = Ui.touchLayout() -- the same touch rule as the dock (D-056)
	local showGallop = riding ~= nil and touch and not TrainingState.active
	if gallopBtn.Visible ~= showGallop then gallopBtn.Visible = showGallop end
	local showHop = showGallop and GameConfig.riding.hopButton and not racing
	if hopBtn.Visible ~= showHop then
		hopBtn.Visible = showHop
		if showHop then placeHop() end
	end
	-- Hide the ride button while racing or with no horse yet.
	rideSlot.Visible = not racing and PlayerState.data ~= nil and #PlayerState.data.horses > 0
	if not riding then return end
	local hh = riding:FindFirstChildOfClass("Humanoid")
	if not hh then return end
	local move = if controls then controls:GetMoveVector() else Vector3.zero
	if TrainingState.active and TrainingState.phase == "countdown" then
		hh.WalkSpeed = 0
		hh:Move(Vector3.zero, false)
		return
	end
	local root = riding.PrimaryPart
	if TrainingState.active and TrainingState.phase == "ride" and root and TrainingState.course then
		-- Courses ride at their own speed: a part-pushed stick still rides at full course speed
		-- (only the direction counts), with a small deadzone so a resting thumb doesn't steer.
		local dir = if move.Magnitude > COURSE_DEADZONE then move.Unit else Vector3.zero
		hh.WalkSpeed = TrainingCourses.speedAt(TrainingState.course, root.Position.X, root.Position.Z)
		hh:Move(magnet(worldMove(dir), root.Position), false)
		return
	end
	hh.WalkSpeed = if galloping then GALLOP else WALK
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
			local legs = anim and HorseLegs.stateOf(anim)
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
			if legs then
				-- Running legs (D-056): the body bobs in step with the legs, and drops by the lowest
				-- hoof's lift so a hoof is always on the ground (no floating gallop).
				local ride = GameConfig.riding
				local y = ride.bobAmp * math.abs(math.sin(legs.phase * math.pi * 2)) * legs.blend
					- HorseLegs.lowestLift(legs, ride.legLength)
				motor.Transform = CFrame.new(0, y, 0)
			else
				-- Bob in step: quicker and higher at a gallop, a gentle nod at a walk, still when stopped.
				local hz = if fast then 2.2 else 1.6
				phase[rig] = ((phase[rig] or 0) + dt * hz * math.min(1, speed / 8)) % 1
				local amp = if fast then 0.45 else 0.12
				local y = amp * math.abs(math.sin(phase[rig] * math.pi * 2)) * math.min(1, speed / 8)
				motor.Transform = CFrame.new(0, y, 0) * CFrame.Angles(if fast then math.sin(phase[rig] * math.pi * 2) * 0.04 else 0, 0, 0)
			end
		end
	end
	for rig in phase do
		if not rig.Parent then phase[rig] = nil end
	end
end)
