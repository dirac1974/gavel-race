--!strict
-- Race Rating from racer stats, race conditions, care, and pilot (D-014).
-- Pure and theme-agnostic. Mirrors src/race_rating.py exactly.

local RaceRating = {}

RaceRating.STATS = { "speed", "accel", "stamina", "grit" }

RaceRating.DISTANCE_WEIGHTS = {
	Sprint = { speed = 0.30, accel = 0.45, stamina = 0.10, grit = 0.15 },
	Mile = { speed = 0.45, accel = 0.25, stamina = 0.20, grit = 0.10 },
	Classic = { speed = 0.40, accel = 0.15, stamina = 0.35, grit = 0.10 },
	Marathon = { speed = 0.25, accel = 0.10, stamina = 0.55, grit = 0.10 },
}
RaceRating.SURFACE_SHIFT = {
	Dirt = {},
	Turf = { speed = 0.10 },
	Sand = { grit = 0.10, stamina = 0.05 },
}
RaceRating.WEATHER_SHIFT = {
	Sunny = {},
	Rain = { grit = 0.20 },
	Wind = { stamina = 0.10 },
}
RaceRating.STRATEGY_SUITS = {
	FrontRunner = { Sprint = true, Mile = true },
	Stalker = { Mile = true, Classic = true },
	Closer = { Classic = true, Marathon = true },
}
RaceRating.CARE_MAX = 0.05
RaceRating.PILOT_MAX = 3.0
RaceRating.STRATEGY_BONUS = 2.0
RaceRating.BOND_MAX = 2.0

export type Conditions = { distance: string, surface: string, weather: string }

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function RaceRating.weights(cond: Conditions): { [string]: number }
	local w = table.clone(RaceRating.DISTANCE_WEIGHTS[cond.distance])
	for _, shift in { RaceRating.SURFACE_SHIFT[cond.surface], RaceRating.WEATHER_SHIFT[cond.weather] } do
		for k, v in shift do
			w[k] += v
		end
	end
	local total = 0
	for _, k in RaceRating.STATS do total += w[k] end
	local out = {}
	for _, k in RaceRating.STATS do out[k] = w[k] / total end
	return out
end

-- care, pilotLevel, bond are 0..1. Stats are 0..100.
function RaceRating.rating(
	stats: { [string]: number },
	cond: Conditions,
	care: number?,
	pilotLevel: number?,
	strategy: string?,
	bond: number?
): number
	local w = RaceRating.weights(cond)
	local base = 0
	for _, k in RaceRating.STATS do
		base += w[k] * math.clamp(stats[k], 0, 100)
	end
	local r = base * (1 + RaceRating.CARE_MAX * clamp01(care or 0))
	r += RaceRating.PILOT_MAX * clamp01(pilotLevel or 0)
	if strategy and RaceRating.STRATEGY_SUITS[strategy] and RaceRating.STRATEGY_SUITS[strategy][cond.distance] then
		r += RaceRating.STRATEGY_BONUS
	end
	r += RaceRating.BOND_MAX * clamp01(bond or 0)
	return r
end

return RaceRating
