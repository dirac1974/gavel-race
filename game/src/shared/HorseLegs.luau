--!nonstrict
-- Running legs (D-051). Horses from tools/meshy/split_legs.py have a Body and four legs
-- (LegFL, LegFR, LegBL, LegBR); each leg swings about its hip, in a gait picked by speed:
--   stand: legs ease back to rest      walk: four-beat, gentle
--   trot: diagonal pairs together       gallop: four-beat with big reach
-- The phase follows distance travelled (one stride per stride length), so feet keep pace with
-- the ground at any speed. Gait maths is pure (tested under Lune); `apply` poses a model:
-- anchored legs are placed directly (race and wild horses), welded rigs use one Motor6D per leg
-- whose Transform this client sets (ride horses), so it works for any horse on screen.

local HorseLegs = {}

HorseLegs.LEGS = { "LegFL", "LegFR", "LegBL", "LegBR" }

-- offset: where each leg is in the cycle (0..1); amp: swing in degrees; stride: studs per cycle.
HorseLegs.GAITS = {
	walk = { stride = 6, amp = 18, offset = { LegBL = 0, LegFL = 0.25, LegBR = 0.5, LegFR = 0.75 } },
	trot = { stride = 10, amp = 26, offset = { LegFL = 0, LegBR = 0, LegFR = 0.5, LegBL = 0.5 } },
	gallop = { stride = 22, amp = 36, offset = { LegBL = 0, LegBR = 0.1, LegFL = 0.45, LegFR = 0.55 } },
}

-- Gait for a speed in studs per second.
function HorseLegs.gaitFor(speed: number): string
	if speed < 1 then return "stand" end
	if speed < 13 then return "walk" end
	if speed < 30 then return "trot" end
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

-- Roblox side ------------------------------------------------------------------------------
-- state per model: { body, legs = { [name] = { part, toHip, hipToLeg, motor? } }, phase, gait, blend }
local states = setmetatable({}, { __mode = "k" })

local function find(model: Instance, name: string): BasePart?
	local p = model:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

-- Is this a horse with separate legs?
function HorseLegs.has(model: Instance?): boolean
	return model ~= nil and find(model, "LegFL") ~= nil and find(model, "Body") ~= nil
end

-- Hip of a leg: the top-centre of its box, a little down.
local function hipOf(leg: BasePart): CFrame
	return leg.CFrame * CFrame.new(0, leg.Size.Y / 2 - math.min(0.25, leg.Size.Y * 0.06), 0)
end

local function setup(model: Instance)
	local body = find(model, "Body")
	if not body then return nil end
	local s = { body = body, legs = {}, phase = 0, gait = "stand", blend = 0 }
	for _, name in HorseLegs.LEGS do
		local leg = find(model, name)
		if leg then
			-- hip frame: at the hip, with the body's axes (so swings turn about the body's sideways axis)
			local hipWorld = CFrame.new(hipOf(leg).Position) * (body.CFrame - body.CFrame.Position)
			local entry = { part = leg, toHip = body.CFrame:ToObjectSpace(hipWorld), hipToLeg = hipWorld:ToObjectSpace(leg.CFrame) }
			local motor = leg:FindFirstChild("LegMotor")
			if motor and motor:IsA("Motor6D") then entry.motor = motor end
			s.legs[name] = entry
		end
	end
	states[model] = s
	return s
end

-- Welded rigs: replace a leg's weld with a Motor6D at the hip so clients can swing it (call
-- once on the server after the rig is built, with legs already welded to `anchor`).
function HorseLegs.rig(model: Instance, anchor: BasePart)
	for _, name in HorseLegs.LEGS do
		local leg = find(model, name)
		if leg then
			for _, w in leg:GetChildren() do
				if w:IsA("WeldConstraint") then w:Destroy() end
			end
			local hip = CFrame.new(hipOf(leg).Position) * (anchor.CFrame - anchor.CFrame.Position)
			local m = Instance.new("Motor6D")
			m.Name = "LegMotor"
			m.Part0, m.Part1 = anchor, leg
			m.C0 = anchor.CFrame:ToObjectSpace(hip)
			m.C1 = leg.CFrame:ToObjectSpace(hip)
			m.Parent = leg
		end
	end
end

-- Pose a horse for this frame: `dist` studs travelled since the last call, over `dt` seconds.
function HorseLegs.apply(model: Instance, dist: number, dt: number)
	local s = states[model] or setup(model)
	if not s or not s.body.Parent then return end
	local speed = if dt > 0 then dist / dt else 0
	local gait = HorseLegs.gaitFor(speed)
	if gait ~= "stand" then
		s.gait = gait
		s.phase = HorseLegs.advance(s.phase, gait, dist)
		s.blend = math.min(1, s.blend + dt * 4)
	else
		s.blend = math.max(0, s.blend - dt * 3) -- ease back to standing
	end
	local bodyCF = s.body.CFrame
	for name, e in s.legs do
		local deg = HorseLegs.angle(s.gait, name, s.phase) * s.blend
		local swing = CFrame.Angles(math.rad(deg), 0, 0)
		if e.motor then
			e.motor.Transform = swing
		elseif e.part.Anchored then
			e.part.CFrame = bodyCF * e.toHip * swing * e.hipToLeg
		end
	end
end

return HorseLegs
