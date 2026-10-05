--!strict
-- Racecourse layout modelled on Churchill Downs (D-027). Pure numbers, no Roblox types,
-- so it runs under Lune. 1 stud ~ 1 foot here (a horse model is 8 studs long).
--
-- Main track: a one-mile dirt oval, 80 ft wide, quarter-mile straights, run
-- counter-clockwise (left turns) as in the US. Seen from above: the home straight is on
-- the +X side running toward -Z past the grandstand; the finish line is 1,234.5 ft down it
-- (Churchill's homestretch); then the clubhouse turn, the backstretch (toward +Z), the far
-- turn, and the top of the stretch. A turf course sits inside the dirt.
--
-- Distances (by the race's distance condition) start the gate on a straight so many feet
-- before the finish, snapped forward out of a turn. Lanes keep their own radius, so a
-- gate straight across the track gives outer lanes a slightly longer trip, as on a real
-- track. Loop distance d = 0 is the top of the stretch.

export type Config = {
	centerX: number,
	centerZ: number,
	straight: number,     -- each straight
	railRadius: number,   -- main track inner rail at the turns
	width: number,        -- main track width
	laneOffset: number,   -- rail to the inside edge of lane 1
	laneWidth: number,
	lanes: number,
	finishFromTop: number, -- top of the stretch to the finish line
	turfGap: number,      -- grass between the turf course's outer rail and the dirt's inner rail
	turfWidth: number,
}

export type Plan = {
	distance: number,     -- nominal race distance (lane 1)
	gateD: number,        -- lane-1 loop distance of the gate
	gateStraight: string, -- "home" or "back"
	gateOffset: number,   -- distance along that straight
	laps: number,
	starts: { number },   -- per lane: loop distance at the gate
	lengths: { number },  -- per lane: distance to run
}

local TrackLayout = {}

TrackLayout.churchill = {
	centerX = 0,
	centerZ = 0,
	straight = 1320,
	railRadius = 417,
	width = 80,
	laneOffset = 4,
	laneWidth = 6,
	lanes = 8,
	finishFromTop = 1234.5,
	turfGap = 30,
	turfWidth = 80,
} :: Config

-- Furlongs: Sprint 6f, Mile 8f, Classic 10f (the Derby), Marathon 12f.
TrackLayout.distances = { Sprint = 3960, Mile = 5280, Classic = 6600, Marathon = 7920 }

function TrackLayout.outerRadius(cfg: Config): number
	return cfg.railRadius + cfg.width
end

function TrackLayout.laneRadius(cfg: Config, i: number): number
	return cfg.railRadius + cfg.laneOffset + (i - 0.5) * cfg.laneWidth
end

function TrackLayout.lapLength(cfg: Config, r: number): number
	return 2 * cfg.straight + 2 * math.pi * r
end

-- Point and unit heading at loop distance d on the loop of radius r.
function TrackLayout.atDistance(cfg: Config, r: number, d: number): (number, number, number, number)
	local L, cx, cz = cfg.straight, cfg.centerX, cfg.centerZ
	d = d % TrackLayout.lapLength(cfg, r)
	local turn = math.pi * r
	if d < L then -- home straight, toward -Z, past the grandstand
		return cx + r, cz + L / 2 - d, 0, -1
	end
	d -= L
	if d < turn then -- clubhouse turn, centred at (cx, cz - L/2)
		local a = d / r
		return cx + r * math.cos(a), cz - L / 2 - r * math.sin(a), -math.sin(a), -math.cos(a)
	end
	d -= turn
	if d < L then -- backstretch, toward +Z
		return cx - r, cz - L / 2 + d, 0, 1
	end
	d -= L
	local a = d / r -- far turn, centred at (cx, cz + L/2), into the top of the stretch
	return cx - r * math.cos(a), cz + L / 2 + r * math.sin(a), math.sin(a), math.cos(a)
end

-- Loop distance of a point on a straight, for the loop of radius r.
local function straightD(cfg: Config, r: number, straight: string, offset: number): number
	if straight == "home" then return offset end
	return cfg.straight + math.pi * r + offset
end

-- Where the race of `distance` starts, per lane, and how far each lane runs.
function TrackLayout.plan(cfg: Config, distance: number): Plan
	local r1 = TrackLayout.laneRadius(cfg, 1)
	local lap1 = TrackLayout.lapLength(cfg, r1)
	local laps = math.floor((distance - 1e-6) / lap1)
	local d = (cfg.finishFromTop - (distance - laps * lap1)) % lap1
	-- Snap a gate that would sit in a turn forward to the start of the next straight.
	local L, turn = cfg.straight, math.pi * r1
	local straight, offset
	if d < L then
		straight, offset = "home", d
	elseif d < L + turn then
		straight, offset = "back", 0
	elseif d < 2 * L + turn then
		straight, offset = "back", d - L - turn
	else
		straight, offset = "home", 0 -- the top of the stretch
	end
	local starts, lengths = {}, {}
	local finishD = cfg.finishFromTop
	for i = 1, cfg.lanes do
		local r = TrackLayout.laneRadius(cfg, i)
		local lap = TrackLayout.lapLength(cfg, r)
		local s = straightD(cfg, r, straight, offset)
		starts[i] = s
		lengths[i] = (finishD - s) % lap + laps * lap
		if lengths[i] < 1 then lengths[i] += lap end
	end
	return {
		distance = distance,
		gateD = straightD(cfg, r1, straight, offset),
		gateStraight = straight,
		gateOffset = offset,
		laps = laps,
		starts = starts,
		lengths = lengths,
	}
end

-- Lane i at race progress p (0 at the gate, 1 at the finish; past 1 runs on).
function TrackLayout.lanePoint(cfg: Config, plan: Plan, i: number, p: number): (number, number, number, number)
	return TrackLayout.atDistance(cfg, TrackLayout.laneRadius(cfg, i), plan.starts[i] + p * plan.lengths[i])
end

-- The finish line across the main track: x range and z.
function TrackLayout.finishLine(cfg: Config): (number, number, number)
	return cfg.centerX + cfg.railRadius, cfg.centerX + TrackLayout.outerRadius(cfg), cfg.centerZ + cfg.straight / 2 - cfg.finishFromTop
end

return TrackLayout
