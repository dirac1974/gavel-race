--!nonstrict
-- RaceState: live race positions shared between the client scripts (D-030).
-- RaceView writes each lane's progress (0 at the gate, 1 at the line) every frame and
-- works out places from it; RaceController (board, place badge) and Minimap read it.
-- Every client animates the same timeline, so every screen agrees on the places.

local RaceState = {
	active = false,
	plan = nil,          -- TrackLayout plan for this race's distance
	lanes = 0,
	progress = {},       -- lane -> progress
	place = {},          -- lane -> current place (1 = leading)
	order = {},          -- place -> lane
}

-- Replay requests from the results panel (RaceController) to the replay player (Replay).
RaceState.ReplayRequested = Instance.new("BindableEvent") -- arg: "finish" | "full"
RaceState.ReplayClosed = Instance.new("BindableEvent")
RaceState.recording = nil  -- { start, plan, lanes, frames = { {t, p1..pn} }, events = { {t, kind, ...} }, summary }
RaceState.myLane = nil

local SUFFIX = { "st", "nd", "rd" }

function RaceState.ordinal(n: number): string
	local teen = n % 100 >= 11 and n % 100 <= 13
	return tostring(n) .. (if not teen and SUFFIX[n % 10] then SUFFIX[n % 10] else "th")
end

-- Re-rank from progress. Ties keep the lower lane number ahead, so places never flicker.
function RaceState.rank()
	if RaceState.final then return end -- the official order stands once the result is in
	local order = {}
	for i = 1, RaceState.lanes do order[i] = i end
	table.sort(order, function(a, b)
		local pa, pb = RaceState.progress[a] or 0, RaceState.progress[b] or 0
		if math.abs(pa - pb) > 1e-6 then return pa > pb end
		return a < b
	end)
	RaceState.order = order
	for place, lane in order do RaceState.place[lane] = place end
end

-- The official finish replaces the running order once the result is in.
function RaceState.setFinal(summary)
	local order = {}
	for _, row in summary do
		if row.lane then order[row.place] = row.lane end
	end
	RaceState.order = order
	for place, lane in order do RaceState.place[lane] = place end
	RaceState.final = true
end

return RaceState
