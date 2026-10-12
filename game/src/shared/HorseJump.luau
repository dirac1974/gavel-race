--!nonstrict
-- HorseJump (D-074, race realism): the ride horse's hop in free riding and training rides goes
-- forward, never straight up. Used by RideClient (Space, the Hop button) and TrainingRideClient
-- (the big Jump button).
--   launch      pure: the horizontal launch velocity along the horse's flat facing
--   poseStep    pure: the airborne pose (leg fold, nose pitch, landing squash) for the pose loop;
--               says when the horse touches down (the thud and dust puff)
--   hop         Roblox: Humanoid.Jump plus the forward push, held through the flight (the
--               humanoid's own air control would pull a Move-less or WalkSpeed-0 horse back to a
--               stop), let go on landing
-- Numbers: GameConfig.riding.hop. Pure parts are tested under Lune (tests/luau/horse_jump_tests).

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")

local HorseJump = {}

HorseJump.GRAVITY = 196.2

local function cfgOf(cfg: any?): any
	return cfg or GameConfig.riding.hop
end

-- Peak height (studs) and airtime (s) of a hop at this jump power.
function HorseJump.peak(power: number, gravity: number?): number
	local g = gravity or HorseJump.GRAVITY
	return power * power / (2 * g)
end
function HorseJump.airtime(power: number, gravity: number?): number
	return 2 * power / (gravity or HorseJump.GRAVITY)
end
-- Seconds the hop spends at or above `height` (0 if it never gets there).
function HorseJump.timeAbove(power: number, height: number, gravity: number?): number
	local g = gravity or HorseJump.GRAVITY
	local disc = power * power - 2 * g * height
	if disc < 0 then return 0 end
	return 2 * math.sqrt(disc) / g
end

-- Launch speed along the facing for a horse moving `fwd` studs/s along it: at least forwardMin;
-- a moving horse gets forwardBoost on top; never over forwardCap nor `cap` (a course's pace).
function HorseJump.launchSpeed(fwd: number, cfg: any?, cap: number?): number
	local c = cfgOf(cfg)
	local f = math.max(0, fwd)
	local target = math.max(if f >= c.movingFrom then f + c.forwardBoost else f, c.forwardMin)
	target = math.min(target, c.forwardCap)
	if cap ~= nil then target = math.min(target, math.max(0, cap)) end
	return target
end

-- The horizontal launch velocity (vx, vz) and its speed for a horse moving (vx, vz) and facing
-- (lx, lz): straight along the flat facing (sideways drift dropped). A facing with no flat part
-- keeps the velocity as it is (speed 0: no push).
function HorseJump.launch(vx: number, vz: number, lx: number, lz: number, cfg: any?, cap: number?): (number, number, number)
	local m = math.sqrt(lx * lx + lz * lz)
	if m < 1e-3 then return vx, vz, 0 end
	local ux, uz = lx / m, lz / m
	local s = HorseJump.launchSpeed(vx * ux + vz * uz, cfg, cap)
	return ux * s, uz * s, s
end

-- Forward travel (studs) over one hop at this launch speed.
function HorseJump.reach(speed: number, power: number, gravity: number?): number
	return speed * HorseJump.airtime(power, gravity)
end

-- Airborne pose ------------------------------------------------------------------------------
-- p = { air (s airborne), tuck 0..1, pitch (rad, + nose up), dip (studs: the landing squash,
-- (1 - landSquash) × squashHeight), land (s left of the squash) }
function HorseJump.newPose()
	return { air = 0, tuck = 0, pitch = 0, dip = 0, land = 0 }
end

local function approach(x: number, to: number, step: number): number
	if x < to then return math.min(to, x + step) end
	return math.max(to, x - step)
end

-- One frame: `airborne` this frame, vertical speed `vy`, `still` = Reduced Motion (no pitch, no
-- squash). A flicker shorter than airDelaySeconds (a bump, a step down) never folds the legs.
-- Returns true on the frame a real flight touches down (Reduced Motion too: the thud still plays).
function HorseJump.poseStep(p, airborne: boolean, vy: number, dt: number, still: boolean?, cfg: any?): boolean
	local c = cfgOf(cfg)
	local wasUp = p.air >= c.airDelaySeconds
	p.air = if airborne then p.air + dt else 0
	local up = p.air >= c.airDelaySeconds
	local landed = wasUp and not airborne
	if landed and not still then p.land = c.landSeconds end -- touchdown
	local tuckTo = if up and c.tuckLegs then 1 else 0
	p.tuck = approach(p.tuck, tuckTo, dt * (if tuckTo > p.tuck then c.tuckRate else c.untuckRate))
	local pitchTo = 0
	if airborne and not still then -- (from the first airborne frame: a bump's small vy barely tips it)
		local r = math.clamp(vy / c.jumpPower, -1, 1)
		pitchTo = math.rad(if r >= 0 then c.pitchUpDeg else c.pitchDownDeg) * r
	end
	p.pitch += (pitchTo - p.pitch) * math.min(1, dt * c.pitchRate)
	p.land = math.max(0, p.land - dt)
	p.dip = if p.land > 0 and not still then (1 - c.landSquash) * c.squashHeight else 0
	return landed
end

-- Is another player's horse in the air? Its replicated Humanoid state (Jumping lasts a frame and
-- may lag), or failing that its vertical speed past remoteAirVy (a bump never gets there).
function HorseJump.remoteAirborne(jumpingOrFalling: boolean, vy: number, cfg: any?): boolean
	return jumpingOrFalling or math.abs(vy) > cfgOf(cfg).remoteAirVy
end

-- Roblox side --------------------------------------------------------------------------------
-- flights[humanoid] = { vx, vz, t0, up, root }
local flights = {}
local lastHop = {}
local stepConn = nil

local function stepFlights()
	local now = os.clock()
	for hh, f in flights do
		local root = f.root
		local done = not hh.Parent or not root.Parent or now - f.t0 > cfgOf().holdSeconds
		local air = hh.FloorMaterial == Enum.Material.Air
		if not done then
			if air then f.up = true elseif f.up then done = true end -- landed: let go
			if not f.up and now - f.t0 > 0.25 then done = true end -- the jump never left the ground
		end
		if done then
			flights[hh] = nil
		else
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(f.vx, v.Y, f.vz) -- the vertical stays the jump's own
		end
	end
	if next(flights) == nil and stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
end

-- Is this humanoid in a forward hop right now? Its direction and speed: the ride loop holds Move
-- along it with WalkSpeed = the speed, so the Humanoid's air control agrees with the push (no fight).
function HorseJump.flying(hh: Humanoid): (Vector3?, number)
	local f = flights[hh]
	if not f then return nil, 0 end
	local m = math.sqrt(f.vx * f.vx + f.vz * f.vz)
	return if m > 1e-3 then Vector3.new(f.vx / m, 0, f.vz / m) else nil, m
end

-- Hop: the jump plus the forward push. `cap` = the most forward speed allowed here (a training
-- course's own pace; nil in free riding). Returns whether a hop started.
function HorseJump.hop(hh: Humanoid, cap: number?): boolean
	local c = cfgOf()
	local root = hh.RootPart
	if not root or hh.FloorMaterial == Enum.Material.Air then return false end
	local now = os.clock()
	if now - (lastHop[hh] or -math.huge) < c.cooldownSeconds then return false end
	lastHop[hh] = now
	for h in lastHop do
		if not h.Parent then lastHop[h] = nil end
	end
	hh.Jump = true
	local look = root.CFrame.LookVector
	local v = root.AssemblyLinearVelocity
	local vx, vz, s = HorseJump.launch(v.X, v.Z, look.X, look.Z, c, cap)
	if s <= 0 then return true end -- a stop (a stall, the course's pause): straight up
	flights[hh] = { vx = vx, vz = vz, t0 = now, up = false, root = root }
	root.AssemblyLinearVelocity = Vector3.new(vx, v.Y, vz)
	if not stepConn then
		stepConn = game:GetService("RunService").Stepped:Connect(stepFlights) -- before each physics step
	end
	return true
end

return HorseJump
