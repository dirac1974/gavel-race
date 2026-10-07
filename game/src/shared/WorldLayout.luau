--!strict
-- World layout (D-035): where everything is, in studs (1 stud ~ 1 ft), on the grandstand
-- side of the racecourse. Plain numbers (no Roblox types) so the server (building), the
-- client (Map, hoofprint guide) and the Lune tests all share it.
--   The racecourse (TrackLayout.churchill) is centred on the origin with the homestretch and
--   grandstand on +X. A tunnel through the grandstand opens onto Fair Street, an east-west
--   street (z = STREET_Z) with the Race Board, Feed & Seed, the Vet, the Training Paddock and
--   the Market Corral. Fair Street crosses Barn Lane (north-south): 20 stable plots, 10 on
--   each side. The street carries on east to the Trail Gate and the Trail loop.

local WorldLayout = {}

export type Point = { x: number, z: number }
export type Plot = {
	index: number,
	x: number, z: number,       -- front-centre, on the lane's edge
	fx: number, fz: number,     -- unit vector from the plot toward the lane
	side: number,               -- -1 west of the lane, +1 east
}
export type Place = { x: number, z: number, fx: number, fz: number, label: string, w: number?, d: number? }

WorldLayout.STREET_Z = -324
WorldLayout.STREET_WIDTH = 40
WorldLayout.STREET_X0 = 632          -- tunnel exit behind the grandstand
WorldLayout.STREET_X1 = 1470         -- the Trail Gate
WorldLayout.LANE_X = 1220
WorldLayout.LANE_WIDTH = 36
WorldLayout.LANE_Z0 = -840
WorldLayout.LANE_Z1 = 190
WorldLayout.TUNNEL_WIDTH = 30
WorldLayout.BOUNDS = { x0 = -612, x1 = 1900, z0 = -1259, z1 = 1259 }

WorldLayout.PLOT_FRONT = 90
WorldLayout.PLOT_DEPTH = 118
WorldLayout.PLOT_COUNT = 20

-- Plot centres along the lane: five north of Fair Street and five south, on both sides.
local SLOTS_Z = { -420, -510, -600, -690, -780, -228, -138, -48, 42, 132 }

function WorldLayout.plot(index: number): Plot
	assert(index >= 1 and index <= WorldLayout.PLOT_COUNT, "plot index")
	local side = if index <= 10 then -1 else 1
	return {
		index = index,
		x = WorldLayout.LANE_X + side * WorldLayout.LANE_WIDTH / 2,
		z = SLOTS_Z[((index - 1) % 10) + 1],
		fx = -side,
		fz = 0,
		side = side,
	}
end

-- A point `inward` studs into the plot from its front and `across` studs to the plot's right
-- (looking in from the lane).
function WorldLayout.plotPoint(index: number, inward: number, across: number): (number, number)
	local p = WorldLayout.plot(index)
	local inX, inZ = -p.fx, -p.fz
	local rightX, rightZ = -inZ, inX
	return p.x + inX * inward + rightX * across, p.z + inZ * inward + rightZ * across
end

-- Axis-aligned rectangle { x0, z0, x1, z1 }.
function WorldLayout.plotRect(index: number): { number }
	local p = WorldLayout.plot(index)
	local backX = p.x - p.fx * WorldLayout.PLOT_DEPTH
	local h = WorldLayout.PLOT_FRONT / 2
	return { math.min(p.x, backX), p.z - h, math.max(p.x, backX), p.z + h }
end

local N = WorldLayout.STREET_Z - WorldLayout.STREET_WIDTH / 2
local S = WorldLayout.STREET_Z + WorldLayout.STREET_WIDTH / 2

-- Buildings: front-centre on the street edge, facing the street; w along the street, d deep.
WorldLayout.places = {
	raceBoard = { x = 690, z = N - 4, fx = 0, fz = 1, label = "Race Board", w = 40, d = 10 },
	feedStore = { x = 790, z = N - 4, fx = 0, fz = 1, label = "Feed & Seed", w = 60, d = 46 },
	vet = { x = 900, z = N - 4, fx = 0, fz = 1, label = "Vet", w = 60, d = 46 },
	paddock = { x = 760, z = S + 4, fx = 0, fz = -1, label = "Training Paddock", w = 170, d = 150 },
	market = { x = 990, z = S + 4, fx = 0, fz = -1, label = "Market Corral", w = 110, d = 110 },
	tackShop = { x = 890, z = S + 4, fx = 0, fz = -1, label = "Tack & Paint", w = 56, d = 40 },
	trailGate = { x = WorldLayout.STREET_X1, z = WorldLayout.STREET_Z, fx = -1, fz = 0, label = "Trail" },
	plaza = { x = 700, z = WorldLayout.STREET_Z, fx = -1, fz = 0, label = "Fair Street" },
	track = { x = 525, z = -500, fx = -1, fz = 0, label = "Racetrack" },
	-- Training Ground (D-053): the training oval, south of the paddock (x 650-950, z -70 to 70).
	trainingGround = { x = 800, z = -70, fx = 0, fz = -1, label = "Training Ground", w = 300, d = 140 },
} :: { [string]: Place }

-- The gate in the paddock's south fence and the path from it to the Training Ground. The link
-- rect is kept clear of trees and holds the picture signs either side of the path.
WorldLayout.PADDOCK_SOUTH_GATE = { x = 760, width = 20 }
WorldLayout.trainingLink = { 715, -150, 805, -70 } -- x0, z0, x1, z1
WorldLayout.TRAINING_PATH_WIDTH = 18

-- The Spa Day wash bay (D-058) beside the Vet, in the Vet's frame: `across` studs to its right
-- (looking out of its front), `out` studs toward the street (negative: back from its front).
WorldLayout.SPA = { across = 44, out = -12, rackAcross = 35, rackOut = -6 }

-- A point in a place's frame -> world x, z.
function WorldLayout.placePoint(key: string, across: number, out: number): (number, number)
	local p = WorldLayout.places[key]
	return p.x - p.fz * across + p.fx * out, p.z + p.fx * across + p.fz * out
end

-- The wash bay and towel rack with room around them (kept clear of trees).
function WorldLayout.spaRect(): { number }
	local S = WorldLayout.SPA
	local ax, az = WorldLayout.placePoint("vet", S.across, S.out)
	local bx, bz = WorldLayout.placePoint("vet", S.rackAcross, S.rackOut)
	return { math.min(ax, bx) - 10, math.min(az, bz) - 10, math.max(ax, bx) + 10, math.max(az, bz) + 10 }
end

-- Rectangle covered by a building (for overlap checks).
function WorldLayout.placeRect(key: string): { number }?
	local p = WorldLayout.places[key]
	if not p or not p.w or not p.d then return nil end
	local w, d = p.w :: number, p.d :: number
	local cx, cz = p.x - p.fx * d / 2, p.z - p.fz * d / 2
	local hx = if p.fx ~= 0 then d / 2 else w / 2
	local hz = if p.fz ~= 0 then d / 2 else w / 2
	return { cx - hx, cz - hz, cx + hx, cz + hz }
end

-- The Trail: a loop of waypoints through woods and the meadow, east of Barn Row.
WorldLayout.trail = {
	{ x = 1470, z = -324 }, { x = 1560, z = -440 }, { x = 1700, z = -580 }, { x = 1830, z = -440 },
	{ x = 1850, z = -160 }, { x = 1770, z = 60 }, { x = 1620, z = 130 }, { x = 1520, z = -90 },
	{ x = 1470, z = -324 },
} :: { Point }
WorldLayout.meadow = { x = 1690, z = -250, radius = 110 }

-- Map fast-travel (D-035). "stable" means the player's own plot.
WorldLayout.MAP = { "stable", "track", "plaza", "vet", "trailGate" }
WorldLayout.MAP_LABELS = { stable = "My Stable", track = "Racetrack", plaza = "Fair Street", vet = "Vet", trailGate = "Trail" }
WorldLayout.MAP_ICONS = { stable = "map_stable", track = "map_track", plaza = "map_fair", vet = "map_vet", trailGate = "map_trail" }
WorldLayout.MAP_EMOJI = { stable = "🏠", track = "🏁", plaza = "🎪", vet = "🩺", trailGate = "🌲" }

-- Where a player arrives: (x, z, lookX, lookZ). Just inside your gate for "stable",
-- otherwise on the street a little in front of the place, facing it.
function WorldLayout.arrival(dest: string, plotIndex: number?): (number, number, number, number)
	if dest == "stable" and plotIndex then
		local x, z = WorldLayout.plotPoint(plotIndex, 16, 0)
		local bx, bz = WorldLayout.plotPoint(plotIndex, 60, 0)
		return x, z, bx, bz
	end
	local p = WorldLayout.places[dest] or WorldLayout.places.plaza
	local x, z = p.x + p.fx * 18, p.z + p.fz * 18
	return x, z, p.x, p.z
end

-- Visiting a friend (D-060): on Barn Lane just outside their gate, facing in (never inside the
-- barn). Visitors walked out when the gate closes land here too.
WorldLayout.GATE_OUTSIDE = 8
function WorldLayout.gateArrival(plotIndex: number): (number, number, number, number)
	local x, z = WorldLayout.plotPoint(plotIndex, -WorldLayout.GATE_OUTSIDE, 0)
	local lx, lz = WorldLayout.plotPoint(plotIndex, 20, 0)
	return x, z, lx, lz
end

function WorldLayout.overlaps(a: { number }, b: { number }): boolean
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

function WorldLayout.inBounds(r: { number }): boolean
	local B = WorldLayout.BOUNDS
	return r[1] >= B.x0 and r[3] <= B.x1 and r[2] >= B.z0 and r[4] <= B.z1
end

return WorldLayout
