--!strict
-- Oval racecourse geometry (D-025). Pure numbers, no Roblox types, so it runs under Lune.
--
-- Two straights parallel to Z joined by two semicircular turns. Seen from above, lanes run
-- down the right-hand (home) straight toward -Z, round the far turn, back up the left
-- straight toward +Z, and round the near turn to the start/finish line at the near end of
-- the home straight. Lane 1 is on the inside; each lane has its own radius, so outer
-- lanes are longer. A race is one lap: progress p = 0 at the gate, p = 1 at the line.

export type Config = {
	centerX: number,
	centerZ: number,
	straight: number,     -- length of each straight (studs)
	innerRadius: number,  -- inner rail radius at the turns
	margin: number,       -- dirt between the inner rail and lane 1, and outside lane N
	laneWidth: number,
	lanes: number,
}

local OvalTrack = {}

OvalTrack.default = {
	centerX = 0,
	centerZ = -120,
	straight = 180,
	innerRadius = 50,
	margin = 2,
	laneWidth = 5,
	lanes = 8,
} :: Config

function OvalTrack.width(cfg: Config): number
	return 2 * cfg.margin + cfg.lanes * cfg.laneWidth
end

function OvalTrack.outerRadius(cfg: Config): number
	return cfg.innerRadius + OvalTrack.width(cfg)
end

-- Radius of lane i's running line (centre of the lane).
function OvalTrack.laneRadius(cfg: Config, i: number): number
	return cfg.innerRadius + cfg.margin + (i - 0.5) * cfg.laneWidth
end

function OvalTrack.lapLength(cfg: Config, r: number): number
	return 2 * cfg.straight + 2 * math.pi * r
end

-- Point and unit heading at distance d along the loop of radius r (d wraps every lap).
function OvalTrack.atDistance(cfg: Config, r: number, d: number): (number, number, number, number)
	local L, cx, cz = cfg.straight, cfg.centerX, cfg.centerZ
	local lap = OvalTrack.lapLength(cfg, r)
	d = d % lap
	local turn = math.pi * r
	if d < L then -- home straight, toward -Z
		return cx + r, cz + L / 2 - d, 0, -1
	end
	d -= L
	if d < turn then -- far turn, centred at (cx, cz - L/2)
		local a = d / r
		return cx + r * math.cos(a), cz - L / 2 - r * math.sin(a), -math.sin(a), -math.cos(a)
	end
	d -= turn
	if d < L then -- back straight, toward +Z
		return cx - r, cz - L / 2 + d, 0, 1
	end
	d -= L
	local a = d / r -- near turn, centred at (cx, cz + L/2)
	return cx - r * math.cos(a), cz + L / 2 + r * math.sin(a), math.sin(a), math.cos(a)
end

-- Lane i at race progress p (fraction of a lap; values past 1 run on past the line).
function OvalTrack.lanePoint(cfg: Config, i: number, p: number): (number, number, number, number)
	local r = OvalTrack.laneRadius(cfg, i)
	return OvalTrack.atDistance(cfg, r, p * OvalTrack.lapLength(cfg, r))
end

-- The start/finish line: x range across the home straight, and its z.
function OvalTrack.startLine(cfg: Config): (number, number, number)
	return cfg.centerX + cfg.innerRadius, cfg.centerX + OvalTrack.outerRadius(cfg), cfg.centerZ + cfg.straight / 2
end

return OvalTrack
