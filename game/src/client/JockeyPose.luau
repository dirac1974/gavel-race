--!strict
-- JockeyPose (AAA Phase 4, D-069): every jockey on this screen's courses (bots and riders) crouches
-- like a race rider and pumps once a stride, instead of Roblox's plain sit. Drawn only.
--   The crouch is written to the R15 joints' Motor6D.Transform in RunService.PreSimulation, which runs
--   after the Animator, so the sit track keeps playing underneath and is simply overridden.
--   The pump follows the horse's own stride (HorseLegs.bodyBob, the same phase as the body bob and the
--   hoof dust): the waist and shoulders reach forward as the lead forefoot lands and the rider rises a
--   little between landings. The replay poses the same way, since it strides the horses through
--   RaceState.placeHorse. Under Reduced Motion the crouch stays and the pump stops.
--   Arms reach forward along the horse's neck (hands on the reins), the same on both sides: never a
--   raised arm, a whip or a crop.
--   R6 rigs keep the sit (no R15 joints to pose).
-- Angles: GameConfig.jockeyPose in the plan's convention; SIGN turns each into a rotation about the
-- joint's X axis (Roblox: + tips a part that hangs down forward, and a part that stands up backward).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local JockeyPose = {}

export type Pose = { pelvis: number, waist: number, neck: number, hip: number, knee: number, shoulder: number,
	elbow: number, rise: number }

JockeyPose.SIGN = { pelvis = -1, waist = -1, neck = -1, hip = -1, knee = -1, shoulder = 1, elbow = 1 }

-- Each posed joint: the part holding the Motor6D, its name and the pose field it takes. Left and right
-- always take the same field (no one-arm pose is possible).
JockeyPose.JOINTS = {
	{ part = "LowerTorso", motor = "Root", field = "pelvis" },
	{ part = "UpperTorso", motor = "Waist", field = "waist" },
	{ part = "Head", motor = "Neck", field = "neck" },
	{ part = "LeftUpperLeg", motor = "LeftHip", field = "hip" },
	{ part = "RightUpperLeg", motor = "RightHip", field = "hip" },
	{ part = "LeftLowerLeg", motor = "LeftKnee", field = "knee" },
	{ part = "RightLowerLeg", motor = "RightKnee", field = "knee" },
	{ part = "LeftUpperArm", motor = "LeftShoulder", field = "shoulder" },
	{ part = "RightUpperArm", motor = "RightShoulder", field = "shoulder" },
	{ part = "LeftLowerArm", motor = "LeftElbow", field = "elbow" },
	{ part = "RightLowerArm", motor = "RightElbow", field = "elbow" },
}

function JockeyPose.newPose(): Pose
	return { pelvis = 0, waist = 0, neck = 0, hip = 0, knee = 0, shoulder = 0, elbow = 0, rise = 0 }
end

-- The pose for one frame (degrees about each joint's X axis, and the rise in studs), written into
-- `out`. lift (0 at the lead forefoot's landing .. 1 between) and nose (-1 at the landing .. 1
-- between) come from HorseLegs.bodyBob, already scaled by how much the horse is moving.
function JockeyPose.solve(cfg, lift: number, nose: number, out: Pose): Pose
	local S = JockeyPose.SIGN
	local pump = -nose -- +1 as the lead forefoot lands
	out.pelvis = S.pelvis * cfg.pelvisDeg
	out.waist = S.waist * (cfg.waistDeg + cfg.pumpDeg * pump)
	out.neck = S.neck * cfg.neckDeg
	out.hip = S.hip * cfg.hipDeg
	out.knee = S.knee * cfg.kneeDeg
	out.shoulder = S.shoulder * (cfg.shoulderDeg + cfg.shoulderPumpDeg * pump)
	out.elbow = S.elbow * cfg.elbowDeg
	out.rise = cfg.riseStuds * math.clamp(lift, 0, 1) - (cfg.seatDropStuds or 0)
	return out
end

-- The rider's back, in degrees above horizontal (90 = sitting up straight).
function JockeyPose.backDeg(p: Pose): number
	return 90 + p.pelvis + p.waist
end

-- The arm in the world, in degrees forward of straight down: the upper arm and the forearm. The
-- torso's lean carries the shoulder back, so the arm's own angle is less the lean.
function JockeyPose.armDeg(p: Pose): (number, number)
	local lean = -(p.pelvis + p.waist)
	local upper = p.shoulder - lean
	return upper, upper + p.elbow
end

-- Roblox side ----------------------------------------------------------------------------------
type Rider = { horse: Instance, rider: Instance, motors: { Motor6D }, fields: { string } }

-- The rider's posable joints, and whether that answer is final (an R6 rig, or every joint found; a
-- character still streaming in is asked again on the next refresh).
local function motorsOf(rider: Instance): (Rider?, boolean)
	local humanoid = rider:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil, false end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return nil, true end -- R6 keeps the sit
	local motors, fields = {}, {}
	for _, j in JockeyPose.JOINTS do
		local part = rider:FindFirstChild(j.part)
		local m = part and part:FindFirstChild(j.motor)
		if m and m:IsA("Motor6D") then
			table.insert(motors, m)
			table.insert(fields, j.field)
		end
	end
	if #motors == 0 then return nil, false end
	return { horse = rider, rider = rider, motors = motors, fields = fields }, #motors == #JockeyPose.JOINTS
end

-- deps: HorseLegs, RaceState, TrackLayout (shared modules), config (GameConfig.jockeyPose),
-- reducedMotion (() -> boolean).
function JockeyPose.start(deps)
	local cfg = deps.config
	if not cfg or not cfg.enabled then return end
	local HorseLegs, RaceState, TrackLayout = deps.HorseLegs, deps.RaceState, deps.TrackLayout
	local RunService = game:GetService("RunService")
	local rad = math.rad
	-- The joints that never pump, worked out once.
	local fixed: { [string]: CFrame } = {}
	local base = JockeyPose.solve(cfg, 0, 0, JockeyPose.newPose())
	for _, field in { "neck", "hip", "knee", "elbow" } do
		fixed[field] = CFrame.Angles(rad((base :: any)[field]), 0, 0)
	end

	local riders: { Rider } = {}
	local known: { [Instance]: Rider | false } = setmetatable({}, { __mode = "k" }) :: any
	local pose = JockeyPose.newPose()

	local function release(r: Rider)
		for _, m in r.motors do
			if m.Parent then m.Transform = CFrame.identity end
		end
	end

	local function riderOn(horse: Instance): Instance?
		local jockey = horse:FindFirstChild("Jockey")
		if jockey then return jockey end
		local saddle = horse:FindFirstChild("Saddle")
		local occupant = if saddle and saddle:IsA("Seat") then saddle.Occupant else nil
		return if occupant then occupant.Parent else nil
	end

	-- Who is riding what, a few times a second (the per-frame loop only walks this list).
	local function refresh()
		local list: { Rider } = {}
		for id in TrackLayout.courses do
			local folder = RaceState.trackFolder(id)
			local horses = folder and folder:FindFirstChild("Horses")
			if not horses then continue end
			for _, horse in horses:GetChildren() do
				local rider = riderOn(horse)
				if not rider then continue end
				local r = known[rider]
				if r == nil then
					local found, final = motorsOf(rider)
					r = found or false
					if final then known[rider] = r end
				end
				if r then
					r.horse = horse
					table.insert(list, r)
				end
			end
		end
		for _, old in riders do
			if not table.find(list, old) then release(old) end
		end
		riders = list
	end

	local since = math.huge
	local every = 1 / math.max(1, cfg.refreshHz or 4)
	RunService.PreSimulation:Connect(function(dt: number)
		since += dt
		if since >= every then
			since = 0
			refresh()
		end
		if #riders == 0 then return end
		local still = deps.reducedMotion()
		for _, r in riders do
			local lift, nose = 0, 0
			if not still then
				local s = HorseLegs.stateOf(r.horse)
				if s then lift, nose = HorseLegs.bodyBob(s) end
			end
			JockeyPose.solve(cfg, lift, nose, pose)
			local pelvisCf = CFrame.new(0, pose.rise, 0) * CFrame.Angles(rad(pose.pelvis), 0, 0)
			local waistCf = CFrame.Angles(rad(pose.waist), 0, 0)
			local shoulderCf = CFrame.Angles(rad(pose.shoulder), 0, 0)
			for i, m in r.motors do
				local f = r.fields[i]
				m.Transform = if f == "pelvis" then pelvisCf elseif f == "waist" then waistCf
					elseif f == "shoulder" then shoulderCf else fixed[f]
			end
		end
	end)
end

return JockeyPose
