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

-- Two courses can race at once (D-036). Each client follows one race, the "focus": the race
-- it rides in, or else the newest race when watching. RaceView and RaceController both ask
-- `consider` when a race starts; the first answer for that race sticks.
local myId = tostring(game:GetService("Players").LocalPlayer.UserId)
RaceState.focus = nil      -- course id ("dirt" | "turf") the HUD follows
RaceState.myCourse = nil   -- the course of your own race, kept until you're off its horse
local decided: { [string]: boolean } = {}

function RaceState.consider(courseId: string?, laneList, start: number): boolean
	local key = tostring(courseId) .. ":" .. tostring(start)
	if decided[key] ~= nil then return decided[key] end
	local mine = false
	for _, lane in laneList do
		if lane.id == myId then mine = true end
	end
	-- Your own race (still racing, on its results card or replay, or still in its saddle)
	-- keeps the focus; other races are only watched when you have none.
	local busyElsewhere = RaceState.myCourse ~= nil and RaceState.myCourse ~= courseId
	local focus = mine or not busyElsewhere
	decided[key] = focus
	if focus then RaceState.focus = courseId end
	if mine then RaceState.myCourse = courseId end
	return focus
end

-- Done with your race: watching other races can take the focus again.
function RaceState.releaseMyRace()
	RaceState.myCourse = nil
end

function RaceState.isFocus(courseId: string?): boolean
	return courseId == nil or courseId == RaceState.focus
end

-- The folder holding a course's gate and horses (TrackScene).
function RaceState.trackFolder(courseId: string?): Instance?
	return workspace:FindFirstChild(if courseId == nil or courseId == "dirt" then "RaceTrack" else "RaceTrack_" .. courseId)
end

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
