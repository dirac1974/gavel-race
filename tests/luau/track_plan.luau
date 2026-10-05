--!strict
-- Prints TrackLayout.plan for every course and distance as JSON. tests/test_trip.py checks the
-- phase-A geometry in src/trip.py against it. Run with: lune run tests/luau/track_plan
local serde = require("@lune/serde")
local TrackLayout = require("../../game/src/shared/TrackLayout")

local out = {}
for course, cfg in TrackLayout.courses do
	out[course] = {}
	for name, distance in TrackLayout.distances do
		local plan = TrackLayout.plan(cfg, distance)
		out[course][name] = {
			straight = plan.gateStraight,
			offset = plan.gateOffset,
			laps = plan.laps,
			length = plan.lengths[1],
			r1 = TrackLayout.laneRadius(cfg, 1),
		}
	end
end
print(serde.encode("json", out))
