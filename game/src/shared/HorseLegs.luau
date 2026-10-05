--!nonstrict
-- Running legs (D-051). Horses from tools/meshy/split_legs.py have a Body and four legs
-- (LegFL, LegFR, LegBL, LegBR); each leg swings about its hip, in a gait picked by speed:
--   stand: legs ease back to rest      walk: four-beat, gentle
--   trot: diagonal pairs together       gallop: four-beat with big reach
-- The phase follows distance travelled (one stride per stride length), so feet keep pace with
-- the ground at any speed; a change of gait cross-fades so no leg jumps. Gait maths is pure
-- (tested under Lune); `apply` poses a model: anchored legs are placed directly (race and wild
-- horses), welded rigs use one Motor6D per leg whose Transform this client sets (ride horses),
-- so it works for any horse on screen. Each leg's resting place is stored on it as the LegRest
-- attribute when the model is loaded (AssetService), so a pose never drifts.

local HorseLegs = {}

HorseLegs.LEGS = { "LegFL", "LegFR", "LegBL", "LegBR" }

-- offset: where each leg is in the cycle (0..1); amp: swing in degrees; stride: studs per cycle.
HorseLegs.GAITS = {
	walk = { stride = 9, amp = 18, offset = { LegBL = 0, LegFL = 0.25, LegBR = 0.5, LegFR = 0.75 } },
	trot = { stride = 12, amp = 26, offset = { LegFL = 0, LegBR = 0, LegFR = 0.5, LegBL = 0.5 } },
	gallop = { stride = 22, amp = 36, offset = { LegBL = 0, LegBR = 0.1, LegFL = 0.45, LegFR = 0.55 } },
}

HorseLegs.MIX_RATE = 4 -- gait cross-fade per second (a quarter second)

-- Gait for a speed in studs per second (riding walks at 16 and gallops at 46; races run at 40+).
function HorseLegs.gaitFor(speed: number): string
	if speed < 1 then return "stand" end
	if speed < 20 then return "walk" end
	if speed < 36 then return "trot" end
	return "gallop"
end

-- Swing angle (degrees, + = foot forward) for a leg at stride phase p (0..1). Legs reach
-- forward quickly and push back slowly (a little asymmetry reads as weight on the ground);
-- front legs reach a bit further than hind legs.
function HorseLegs.angle(gait: string, leg: string, p: number): number
	local g = HorseLegs.GAITS[gait]
	if not g then return 0 end
	local theta = 2 * math.pi * ((p + (g.offset[leg] or 0)) % 1)
	local wave = math.sin(theta) + 0.22 * math.sin(2 * theta)
	local front = if string.sub(leg, 4, 4) == "F" then 1.1 else 0.9
	return g.amp * front * wave / 1.17 -- 1.17 ≈ the wave's peak, so amp is the real maximum
end

-- Phase advance for travelling `dist` studs in this gait.
function HorseLegs.advance(phase: number, gait: string, dist: number): number
	local g = HorseLegs.GAITS[gait]
	if not g then return phase end
	return (phase + dist / g.stride) % 1
end

-- One step of the pose state (pure): s = { phase, gait, prev, mix, blend }. `speed` picks the
-- gait; a new gait fades in from the old one over 1 / MIX_RATE seconds, and the next change
-- waits until that fade is done (a fast speed-up crosses walk, trot and gallop in a few frames).
function HorseLegs.step(s, dist: number, dt: number, speed: number)
	local gait = HorseLegs.gaitFor(speed)
	if gait ~= "stand" then
		if gait ~= s.gait and (s.mix >= 1 or s.blend <= 0) then
			s.prev, s.mix, s.gait = if s.blend > 0 then s.gait else gait, 0, gait
		end
		s.phase = HorseLegs.advance(s.phase, s.gait, dist)
		s.blend = math.min(1, s.blend + dt * 4)
	else
		s.blend = math.max(0, s.blend - dt * 3) -- ease back to standing
	end
	s.mix = math.min(1, s.mix + dt * HorseLegs.MIX_RATE)
end

-- Swing of one leg in a pose state (degrees).
function HorseLegs.poseAngle(s, leg: string): number
	local cur = HorseLegs.angle(s.gait, leg, s.phase)
	local old = if s.prev and s.mix < 1 then HorseLegs.angle(s.prev, leg, s.phase) else cur
	return (old + (cur - old) * s.mix) * s.blend
end

function HorseLegs.newState()
	return { phase = 0, gait = "walk", prev = nil, mix = 1, blend = 0 }
end

-- Roblox side ------------------------------------------------------------------------------
-- state per model: pose state + { model, body, legs = { [name] = { part, toHip, hipToLeg, motor? } } }
local states = {}
local calls = 0

local function find(model: Instance, name: string): BasePart?
	local p = model:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

-- Is this a horse with separate legs?
function HorseLegs.has(model: Instance?): boolean
	if model == nil then return false end
	if states[model] then return true end
	return find(model, "LegFL") ~= nil and find(model, "Body") ~= nil
end

-- Hip of a leg at rest: the top-centre of its box, a little down.
local function hipOf(rest: CFrame, size: Vector3): CFrame
	return rest * CFrame.new(0, size.Y / 2 - math.min(0.25, size.Y * 0.06), 0)
end

-- Facing of the horse (the model pivot faces -Z after AssetService), for the swing axis.
local function facing(model: Instance, fallback: CFrame): CFrame
	if model:IsA("Model") then return model:GetPivot().Rotation end
	return fallback.Rotation
end

-- Record each leg's resting place relative to the body (AssetService calls this once).
function HorseLegs.markRest(model: Instance)
	local body = find(model, "Body")
	if not body then return end
	for _, name in HorseLegs.LEGS do
		local leg = find(model, name)
		if leg then leg:SetAttribute("LegRest", body.CFrame:ToObjectSpace(leg.CFrame)) end
	end
end

local function restOf(body: BasePart, leg: BasePart): CFrame
	local rest = leg:GetAttribute("LegRest")
	return if typeof(rest) == "CFrame" then body.CFrame * rest else leg.CFrame
end

local function setup(model: Instance)
	local body = find(model, "Body")
	if not body then return nil end
	local s = HorseLegs.newState()
	s.model, s.body, s.legs = model, body, {}
	local turn = facing(model, body.CFrame)
	for _, name in HorseLegs.LEGS do
		local leg = find(model, name)
		if leg then
			local rest = restOf(body, leg)
			-- hip frame: at the hip, with the horse's facing (swings turn about its sideways axis)
			local hipWorld = CFrame.new(hipOf(rest, leg.Size).Position) * turn
			local entry = { part = leg, toHip = body.CFrame:ToObjectSpace(hipWorld), hipToLeg = hipWorld:ToObjectSpace(rest) }
			local motor = leg:FindFirstChild("LegMotor")
			if motor and motor:IsA("Motor6D") then entry.motor = motor end
			s.legs[name] = entry
		end
	end
	states[model] = s
	return s
end

-- Forget horses that have left the game (every few hundred calls).
local function sweep()
	calls += 1
	if calls % 300 ~= 0 then return end
	for model, s in states do
		if not model.Parent or not s.body.Parent then states[model] = nil end
	end
end

-- Welded rigs: replace a leg's weld with a Motor6D at the hip so clients can swing it (call
-- once on the server after the rig is built, with legs already welded to `anchor`).
function HorseLegs.rig(model: Instance, anchor: BasePart)
	local body = find(model, "Body")
	local turn = facing(model, anchor.CFrame)
	for _, name in HorseLegs.LEGS do
		local leg = find(model, name)
		if leg then
			for _, w in leg:GetChildren() do
				if w:IsA("WeldConstraint") then w:Destroy() end
			end
			local rest = if body then restOf(body, leg) else leg.CFrame
			local hip = CFrame.new(hipOf(rest, leg.Size).Position) * turn
			local m = Instance.new("Motor6D")
			m.Name = "LegMotor"
			m.Part0, m.Part1 = anchor, leg
			m.C0 = anchor.CFrame:ToObjectSpace(hip)
			m.C1 = rest:ToObjectSpace(hip)
			m.Parent = leg
		end
	end
end

local parts, frames = {}, {}

local function pose(s)
	local bodyCF = s.body.CFrame
	table.clear(parts)
	table.clear(frames)
	for name, e in s.legs do
		local swing = CFrame.Angles(math.rad(HorseLegs.poseAngle(s, name)), 0, 0)
		if e.motor then
			e.motor.Transform = swing
		elseif e.part.Anchored then
			table.insert(parts, e.part)
			table.insert(frames, bodyCF * e.toHip * swing * e.hipToLeg)
		end
	end
	if #parts > 0 then workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
end

-- Pose a horse for this frame: `dist` studs travelled since the last call, over `dt` seconds.
-- `timeScale` (replays in slow motion) is how fast the clock runs, so the gait matches the
-- race's real speed.
function HorseLegs.apply(model: Instance, dist: number, dt: number, timeScale: number?)
	sweep()
	local s = states[model] or setup(model)
	if not s then return end
	if not s.body.Parent then
		states[model] = nil
		return
	end
	local clock = dt * (timeScale or 1)
	HorseLegs.step(s, dist, dt, if clock > 0 then dist / clock else 0)
	pose(s)
end

-- Legs straight down at once (a race or replay that has ended).
function HorseLegs.rest(model: Instance?)
	if not model then return end
	local s = states[model] or (HorseLegs.has(model) and setup(model))
	if not s or not s.body.Parent then return end
	s.blend, s.mix, s.prev = 0, 1, nil
	pose(s)
end

return HorseLegs
