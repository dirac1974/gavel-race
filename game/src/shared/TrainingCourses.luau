--!strict
-- TrainingCourses (D-053): where the training rides go. Pure numbers (no Roblox types) so the
-- server (building, scoring), the client (glow, hoofprints) and the Lune tests share it.
--   The training oval fills the Training Ground south of the paddock: two 160-stud straights,
--   centre-line radius 55, 24 studs wide, run counter-clockwise (left turns) like the
--   racecourse. Oval distance d = 0 is the east end of the north straight (the home straight,
--   nearest the paddock); `lateral` is studs outward from the centre line. A gentle hill (the
--   berm) rises on the south straight. Riders come in from the paddock's south gate through a
--   gap in the outer rail.
--   Courses (keys are the stats they train):
--     speed    Sprint Lane: 3 laps through 18 hoops (6 per lap), only the next one glowing.
--     accel    Gate Break: a practice gate in the infield, dash 120 studs to the flag, canter
--              round the gate loop and back in (scored in T3).
--     stamina  Hill Climb: follow Pip the lead pony for 2 laps over the hill (scored in T3).
--     grit     Mud Splash: a gymkhana in the paddock arena, six lanes joined by turns, with 4
--              puddles, 3 low logs and 4 bending poles in a canter zone.
--   A gate is a segment (a -> b) with a unit forward normal (nx, nz): riding across it along
--   the normal is a forward crossing. Rects are { x0, z0, x1, z1 }.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")
local WorldLayout = if script then require(script.Parent.WorldLayout) :: any else require("./WorldLayout")
local Training = if script then require(script.Parent.Training) :: any else require("./Training")

export type Gate = { ax: number, az: number, bx: number, bz: number, nx: number, nz: number }
export type Rect = { number }
export type Pose = { x: number, z: number, lookX: number, lookZ: number }

local TC = {}

local CFG = GameConfig.training
local O = CFG.oval
local S, R, W = O.straight, O.radius, O.width
local TURN = math.pi * R

TC.LAP = 2 * S + 2 * TURN
TC.RAIL_LATERAL = W / 2 + 0.5           -- rails stand just outside the dirt
TC.ENTRY = { x0 = 748, x1 = 772 }       -- gap in both north-straight rails (path and infield)
TC.HILL = { u0 = 20, ramp = 40, top = 40, height = CFG.stamina.hill, halfWidth = W / 2 + 2 }
TC.GROUND_Y = -0.5                      -- top of the ground parts (WorldScene.GROUND_Y)
TC.RIDE_HOP = 4.5                       -- the ride rig's hop (JumpPower 42: 42² / (2 × 196.2))

local function gate(cx: number, cz: number, ux: number, uz: number, half: number, nx: number, nz: number): Gate
	return { ax = cx - ux * half, az = cz - uz * half, bx = cx + ux * half, bz = cz + uz * half, nx = nx, nz = nz }
end
TC.gate = gate

local function inRect(r: Rect, x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return x >= r[1] - m and x <= r[3] + m and z >= r[2] - m and z <= r[4] + m
end
TC.inRect = inRect

-- The oval ----------------------------------------------------------------------------
-- Point at oval distance d and `lateral` studs outward: x, z, the direction of travel (tx, tz)
-- and the outward normal (nx, nz).
function TC.ovalPoint(d: number, lateral: number?): (number, number, number, number, number, number)
	local lat = lateral or 0
	local u = d % TC.LAP
	if u < S then -- north straight, heading west
		return O.cx + S / 2 - u, O.cz - R - lat, -1, 0, 0, -1
	end
	u -= S
	if u < TURN then -- west turn
		local th = u / R
		local s, c = math.sin(th), math.cos(th)
		return O.cx - S / 2 - s * (R + lat), O.cz - c * (R + lat), -c, s, -s, -c
	end
	u -= TURN
	if u < S then -- south straight, heading east (the hill)
		return O.cx - S / 2 + u, O.cz + R + lat, 1, 0, 0, 1
	end
	u -= S
	local th = u / R -- east turn
	local s, c = math.sin(th), math.cos(th)
	return O.cx + S / 2 + s * (R + lat), O.cz + c * (R + lat), c, -s, s, c
end

-- Nearest centre-line distance and lateral offset for a point.
function TC.ovalProject(x: number, z: number): (number, number)
	local dx = x - O.cx
	if math.abs(dx) <= S / 2 then
		if z < O.cz then return S / 2 - dx, (O.cz - R) - z end
		return S + TURN + dx + S / 2, z - (O.cz + R)
	elseif dx < 0 then
		local vx, vz = x - (O.cx - S / 2), z - O.cz
		local th = math.atan2(-vx, -vz)
		return S + R * th, math.sqrt(vx * vx + vz * vz) - R
	end
	local vx, vz = x - (O.cx + S / 2), z - O.cz
	local th = math.atan2(vx, vz)
	return (2 * S + TURN + R * th) % TC.LAP, math.sqrt(vx * vx + vz * vz) - R
end

-- Wrap a change in oval distance into [-LAP/2, LAP/2).
function TC.wrap(delta: number): number
	return (delta + TC.LAP / 2) % TC.LAP - TC.LAP / 2
end

-- Height of the track surface above the ground at oval distance d (the hill on the south
-- straight: a ramp up, a flat top, a ramp down).
function TC.surfaceHeight(d: number): number
	local u = (d % TC.LAP) - S - TURN
	if u < 0 or u >= S then return 0 end
	local h = TC.HILL
	local a, b = h.u0, h.u0 + h.ramp
	local c, e = b + h.top, b + h.top + h.ramp
	if u <= a or u >= e then return 0 end
	if u < b then return h.height * (u - a) / h.ramp end
	if u <= c then return h.height end
	return h.height * (e - u) / h.ramp
end

-- Ground height at a world point (the hill only covers the track there).
function TC.groundHeight(x: number, z: number): number
	local d, lat = TC.ovalProject(x, z)
	if math.abs(lat) > TC.HILL.halfWidth then return 0 end
	return TC.surfaceHeight(d)
end

function TC.onOval(x: number, z: number, margin: number?): boolean
	local _, lat = TC.ovalProject(x, z)
	return math.abs(lat) <= W / 2 + (margin or 0)
end

-- A dense polyline from straight and semicircle legs, for routes (hoofprints, ideal times).
type Route = { points: { { x: number, z: number } }, length: number }
local function polyline(pts: { { x: number, z: number } }): Route
	local len = 0
	for k = 2, #pts do
		len += math.sqrt((pts[k].x - pts[k - 1].x) ^ 2 + (pts[k].z - pts[k - 1].z) ^ 2)
	end
	return { points = pts, length = len }
end

local function arc(out: { { x: number, z: number } }, cx: number, cz: number, r: number, a0: number, a1: number, steps: number)
	-- points cx + r·sin(a), cz − r·cos(a) for a from a0 to a1 (excluding a0)
	for k = 1, steps do
		local a = a0 + (a1 - a0) * k / steps
		table.insert(out, { x = cx + r * math.sin(a), z = cz - r * math.cos(a) })
	end
end

-- Sprint Lane ---------------------------------------------------------------------------
local SPEED_START_D = 30
local HOOP_LATERAL = { 0, -5, 5, 0, 5, -5 }
local hilltopD = S + TURN + TC.HILL.u0 + TC.HILL.ramp + TC.HILL.top / 2

local function buildSpeed()
	local sp = CFG.speed
	local n = sp.hoopsPerLap
	local posts = {}
	for k = 1, n do
		-- spaced evenly round the lap so that hoop 4 sits on top of the hill
		local d = (hilltopD + (k - 4) * TC.LAP / n) % TC.LAP
		local lat = HOOP_LATERAL[((k - 1) % #HOOP_LATERAL) + 1]
		local x, z, tx, tz, nx, nz = TC.ovalPoint(d, lat)
		posts[k] = {
			index = k, d = d, lateral = lat, x = x, z = z, y = TC.surfaceHeight(d), tx = tx, tz = tz, nx = nx, nz = nz,
			width = sp.hoopWidth, gate = gate(x, z, nx, nz, sp.hoopWidth / 2, tx, tz),
		}
	end
	local hoops = {}
	for lap = 0, sp.laps - 1 do
		for k = 1, n do
			local s = TC.wrap(posts[k].d - SPEED_START_D) % TC.LAP + lap * TC.LAP -- progress from the start
			table.insert(hoops, { index = lap * n + k, post = k, lap = lap + 1, s = s })
		end
	end
	table.sort(hoops, function(a, b) return a.s < b.s end)
	for i, hp in hoops do hp.index = i end
	local x, z, tx, tz = TC.ovalPoint(SPEED_START_D, 0)
	return {
		key = "speed", kind = "oval", laps = sp.laps, startD = SPEED_START_D, finish = sp.laps * TC.LAP,
		start = { x = x, z = z, lookX = tx, lookZ = tz }, posts = posts, hoops = hoops,
	}
end

-- Gate Break (geometry only until T3) ------------------------------------------------------
local function buildAccel()
	local ac = CFG.accel
	local gz = O.cz - 10
	local gx = O.cx - S / 2 + 15          -- front of the stall
	local flagX = gx + ac.dash
	local r = 12
	local pts = { { x = gx, z = gz }, { x = flagX, z = gz }, { x = flagX + 10, z = gz } }
	arc(pts, flagX + 10, gz + r, r, 0, math.pi, 12)   -- round the east end
	table.insert(pts, { x = gx - 12, z = gz + 2 * r })
	-- round the west end: sin goes negative so the arc bulges west
	for k = 1, 12 do
		local a = math.pi * k / 12
		table.insert(pts, { x = gx - 12 - r * math.sin(a), z = gz + r + r * math.cos(a) })
	end
	table.insert(pts, { x = gx - 4, z = gz })
	local loop = polyline(pts)
	return {
		key = "accel", kind = "gate",
		start = { x = gx - 4, z = gz, lookX = 1, lookZ = 0 },
		stall = { gx - 8, gz - 2.5, gx, gz + 2.5 },        -- where a break must start from
		flag = gate(flagX, gz, 0, 1, 8, 1, 0),
		route = loop,
		returnLength = loop.length - ac.dash,               -- flag back into the stall
		bellMean = (ac.bellMin + ac.bellMax) / 2,
	}
end

-- Hill Climb (Pip's path; scored in T3) -------------------------------------------------------
local PONY_LEAD = (CFG.stamina.ringNear + CFG.stamina.ringFar) / 2

local function lcg(x: number): number
	return (x * 16807) % 2147483647 -- Park-Miller: exact in doubles
end

local function ponyPhases(seed: number): { number }
	local x = (math.floor(math.abs(seed)) % 2147483646) + 1
	local out = {}
	for k = 1, 3 do
		x = lcg(lcg(x))
		out[k] = x / 2147483647 * 2 * math.pi
	end
	return out
end

local W1, W2, W3 = 2 * math.pi / 11, 2 * math.pi / 4.3, 2 * math.pi / 9

-- Pip at `t` seconds after GO for a session seed: oval distance, progress from the start,
-- lateral weave, speed and position. Pace changes smoothly between ponyMin and ponyMax.
function TC.ponyAt(seed: number, t: number)
	local st = CFG.stamina
	local mid, amp = (st.ponyMin + st.ponyMax) / 2, (st.ponyMax - st.ponyMin) / 2
	local a1, a2 = amp * 2 / 3, amp / 3
	local ph = ponyPhases(seed)
	local tt = math.max(0, t)
	local dist = mid * tt + a1 / W1 * (math.cos(ph[1]) - math.cos(W1 * tt + ph[1]))
		+ a2 / W2 * (math.cos(ph[2]) - math.cos(W2 * tt + ph[2]))
	local speed = mid + a1 * math.sin(W1 * tt + ph[1]) + a2 * math.sin(W2 * tt + ph[2])
	local weave = (W / 2 - 5) * math.sin(W3 * tt + ph[3]) * math.min(1, tt / 3)
	local d = (SPEED_START_D + PONY_LEAD + dist) % TC.LAP
	local x, z = TC.ovalPoint(d, weave)
	return { d = d, s = PONY_LEAD + dist, lateral = weave, speed = speed, x = x, z = z, y = TC.surfaceHeight(d) }
end

local function buildStamina()
	local x, z, tx, tz = TC.ovalPoint(SPEED_START_D, 0)
	return { key = "stamina", kind = "oval", laps = CFG.stamina.laps, startD = SPEED_START_D, lead = PONY_LEAD,
		finish = CFG.stamina.laps * TC.LAP, start = { x = x, z = z, lookX = tx, lookZ = tz } }
end

-- Mud Splash: the gymkhana in the paddock arena -----------------------------------------------
-- Element x positions are offsets from the arena's centre line; logs keep 15+ studs clear of
-- it so people walking from gate to gate never meet one. side = +1 passes a pole on the
-- rider's left, -1 on the right.
local GRIT_LAYOUT = {
	{ kind = "mud", lane = 1, dx = 0 },
	{ kind = "log", lane = 2, dx = -45 },
	{ kind = "mud", lane = 3, dx = -30 },
	{ kind = "log", lane = 3, dx = 45 },
	{ kind = "pole", lane = 4, dx = 45, side = 1 },
	{ kind = "pole", lane = 4, dx = 20, side = -1 },
	{ kind = "pole", lane = 4, dx = -5, side = 1 },
	{ kind = "pole", lane = 4, dx = -30, side = -1 },
	{ kind = "mud", lane = 5, dx = -35 },
	{ kind = "log", lane = 5, dx = 40 },
	{ kind = "mud", lane = 6, dx = 30 },
}
local GRIT_LANES, POLE_LANE, FINISH_DX = 6, 4, -48
TC.MUD_HALF = { along = 7, across = 6 }
TC.LOG_HALF = 6
TC.POLE_REACH = { inner = 1.5, outer = 10, weave = 5 }

local function buildGrit()
	local g = CFG.grit
	local pr = WorldLayout.placeRect("paddock") :: Rect
	local cx = (pr[1] + pr[3]) / 2
	local x0, x1 = pr[1] + 17, pr[3] - 17
	local z0, z1 = pr[2] + 18, pr[4] - 18
	local gap = (z1 - z0) / (GRIT_LANES - 1)
	local laneZ = function(k: number): number return z0 + (k - 1) * gap end
	local laneDir = function(k: number): number return if k % 2 == 1 then 1 else -1 end
	local elements = {}
	local counts = { mud = 0, log = 0, pole = 0 }
	for i, e in GRIT_LAYOUT do
		local x, z, dir = cx + e.dx, laneZ(e.lane), laneDir(e.lane)
		counts[e.kind] += 1
		local el: { [string]: any } = { index = i, kind = e.kind, n = counts[e.kind], lane = e.lane, x = x, z = z, dir = dir,
			points = g.points[e.kind], pass = gate(x, z, 0, 1, gap / 2 - 0.4, dir, 0) }
		el.name = string.upper(string.sub(e.kind, 1, 1)) .. string.sub(e.kind, 2) .. el.n -- Mud1, Log2, Pole3
		if e.kind == "mud" then
			el.rect = { x - TC.MUD_HALF.along, z - TC.MUD_HALF.across, x + TC.MUD_HALF.along, z + TC.MUD_HALF.across }
		elseif e.kind == "log" then
			el.gate = gate(x, z, 0, 1, TC.LOG_HALF, dir, 0)
		else
			-- left of travel (dir, 0) is (0, -dir); the pole gate reaches out on the required side
			local sz = -dir * (e.side :: number)
			local mid = (TC.POLE_REACH.inner + TC.POLE_REACH.outer) / 2
			local half = (TC.POLE_REACH.outer - TC.POLE_REACH.inner) / 2
			el.side = e.side
			el.gate = gate(x, z + sz * mid, 0, 1, half, dir, 0)
			el.weaveZ = z + sz * TC.POLE_REACH.weave
		end
		table.insert(elements, el)
	end
	-- The route: lane 1 east, turn, lane 2 west, ... weaving through the poles, to the finish.
	local start = { x = x0 - 4, z = laneZ(1), lookX = 1, lookZ = 0 }
	local pts = { { x = start.x, z = start.z } }
	for k = 1, GRIT_LANES do
		local z, dir = laneZ(k), laneDir(k)
		if k == POLE_LANE then
			local poles = {}
			for _, el in elements do
				if el.kind == "pole" then table.insert(poles, el) end
			end
			table.sort(poles, function(a, b) return a.x * dir < b.x * dir end)
			for _, el in poles do table.insert(pts, { x = el.x, z = el.weaveZ }) end
		end
		local endX = if k == GRIT_LANES then cx + FINISH_DX else (if dir > 0 then x1 else x0)
		table.insert(pts, { x = endX, z = z })
		if k < GRIT_LANES then
			local r = gap / 2
			if dir > 0 then
				arc(pts, x1, z + r, r, 0, math.pi, 10)
			else
				for s = 1, 10 do
					local a = math.pi * s / 10
					table.insert(pts, { x = x0 - r * math.sin(a), z = z + r - r * math.cos(a) })
				end
			end
		end
	end
	local poleZ = laneZ(POLE_LANE)
	return {
		key = "grit", kind = "arena", start = start, elements = elements, route = polyline(pts),
		finish = gate(cx + FINISH_DX, laneZ(GRIT_LANES), 0, 1, gap / 2 - 0.4, laneDir(GRIT_LANES), 0),
		slowZone = { x0, poleZ - gap / 2, x1, poleZ + gap / 2 },
		arena = pr, lanes = GRIT_LANES, laneGap = gap, laneZ = laneZ, laneX = { x0, x1 },
	}
end

TC.courses = {
	speed = buildSpeed(),
	accel = buildAccel(),
	stamina = buildStamina(),
	grit = buildGrit(),
} :: { [string]: any }
TC.ORDER = { "speed", "accel", "stamina", "grit" }
for key, c in TC.courses do
	local info = Training.GAMES[key]
	c.stat, c.name, c.label, c.emoji = key, info.name, info.label, info.emoji
end

-- Where a course is ridden: samples outside are discarded (bounds) and a rider outside the
-- area for a moment ends the session (area).
local groundRect = WorldLayout.placeRect("trainingGround") :: Rect
TC.groundRect = groundRect

function TC.onCourse(key: string, x: number, z: number): boolean
	local c = TC.courses[key]
	if not c then return false end
	if c.kind == "arena" then return inRect(c.arena, x, z) end
	if c.kind == "gate" then return inRect(groundRect, x, z) end
	return TC.onOval(x, z, 3)
end

function TC.inArea(key: string, x: number, z: number): boolean
	local c = TC.courses[key]
	if not c then return false end
	if c.kind == "arena" then return inRect(c.arena, x, z, 10) end
	return inRect(groundRect, x, z, 10)
end

-- Anywhere a training session may be started from: the paddock, the path and the ground.
function TC.nearTraining(x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return inRect(WorldLayout.placeRect("paddock") :: Rect, x, z, m) or inRect(WorldLayout.trainingLink, x, z, m)
		or inRect(groundRect, x, z, m)
end

-- The speed a course rides at here (courses ride at a gallop by themselves; Mud Splash at an
-- arena lope with the poles at a canter).
function TC.speedAt(key: string, x: number, z: number): number
	local c = TC.courses[key]
	if c and c.kind == "arena" then
		return if inRect(c.slowZone, x, z) then CFG.canter else CFG.grit.pace
	end
	return CFG.gallop
end

-- Ideal time at the configured speeds (par = this × parFactor). Gate Break uses the mean bell
-- wait; Hill Climb follows Pip for the given seed (default 1).
function TC.idealSeconds(key: string, seed: number?): number
	local c = TC.courses[key]
	if key == "speed" then return c.finish / CFG.gallop end
	if key == "accel" then
		local ac = CFG.accel
		return ac.breaks * (c.bellMean + ac.dash / CFG.gallop) + (ac.breaks - 1) * c.returnLength / CFG.canter
	end
	if key == "stamina" then
		local target = c.finish
		local lo, hi = 0, target / CFG.stamina.ponyMin + 1
		for _ = 1, 60 do
			local mid = (lo + hi) / 2
			if TC.ponyAt(seed or 1, mid).s - c.lead < target then lo = mid else hi = mid end
		end
		return hi
	end
	if key == "grit" then
		local total = 0
		local pts = c.route.points
		for k = 2, #pts do
			local a, b = pts[k - 1], pts[k]
			local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
			total += len / TC.speedAt("grit", (a.x + b.x) / 2, (a.z + b.z) / 2)
		end
		return total
	end
	return 0
end

function TC.parSeconds(key: string): number
	return TC.idealSeconds(key) * CFG.parFactor
end

-- Picture signs (WorldScene builds them, readable from both sides; the client puts a "Ride"
-- prompt in front of the open ones). The three oval courses stand either side of the path into
-- the Training Ground, facing riders coming from the paddock; Mud Splash stands in the arena
-- by its start, facing in, with a pointer by the path.
TC.signs = {
	{ course = "speed", x = 738, z = -78, lookX = 0, lookZ = -1 },
	{ course = "stamina", x = 724, z = -78, lookX = 0, lookZ = -1 },
	{ course = "accel", x = 782, z = -78, lookX = 0, lookZ = -1 },
	{ course = "grit", x = 796, z = -78, lookX = 0, lookZ = -1, pointer = true },
	{ course = "grit", x = 700, z = -295, lookX = 0, lookZ = 1 },
}
TC.SIGN_SIZE = { w = 12, h = 9 }

return TC
