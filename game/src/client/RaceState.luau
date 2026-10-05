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
-- Your race has finished but its results card isn't up yet (RaceController). The Hud holds the
-- coin chime until then: the prize lands just before the leader reaches the line.
RaceState.resultsPending = false
RaceState.ResultsShown = Instance.new("BindableEvent") -- arg: true when your results card shows, false if it never will
RaceState.resultsOpen = false   -- a results card is on screen (the Hud keeps the dock away)
RaceState.holdFocus = false     -- it's your own card: a new race on that course doesn't take the HUD
RaceState.burstShowing = false  -- the Final Burst bar is up (the race map steps aside)
RaceState.myHome = false        -- your horse is past the line and pulling up (hoofbeats stop)
RaceState.watchHidden = false   -- watching: the HUD is hidden (busy, or walked out of range)
RaceState.cheeredLane = nil     -- watching: the lane you cheered for (FanClient)...
RaceState.cheeredCourse = nil   -- ...in a race on this course
RaceState.cheerOpen = false     -- watching: the cheer strip is still open (FanClient)

-- Race HUD size on small screens (D-055): the board, place badge, results card and race map
-- shrink with the screen height. The race map's top and unscaled height place the badge under it.
RaceState.MAP_TOP, RaceState.MAP_HEIGHT = 50, 208
function RaceState.hudScale(): number
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	return math.clamp(height / 600, 0.62, 1)
end

-- Two courses can race at once (D-036). Each client follows one race, the "focus": the race
-- it rides in, or else the newest race when watching. RaceView and RaceController both ask
-- `consider` when a race starts; the first answer for that race sticks.
local localPlayer = game:GetService("Players").LocalPlayer
local myId = tostring(localPlayer.UserId)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
RaceState.focus = nil      -- course id ("dirt" | "turf") the HUD follows
RaceState.myCourse = nil   -- the course of your own race, kept until you're off its horse
local decided: { [string]: boolean } = {}

-- Watching is for players at the racecourse (D-055): someone brushing their horse in the barn
-- gets no race HUD, results card or cheer strip. `studs` defaults to the follow range.
function RaceState.nearCourse(courseId: string?, studs: number?): boolean
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local cfg = TrackLayout.courses[courseId or "dirt"] or TrackLayout.churchill
	return TrackLayout.distanceToTrack(cfg, root.Position.X, root.Position.Z) <= (studs or GameConfig.spectate.rangeStuds)
end

-- Busy (D-055): a training ride (the server sets TrainingRide), a care or training game, or a
-- full-screen panel. A spectator's race HUD waits until the kid is done.
local PANELS = { "Care", "Paddock", "Taming", "MyHorses", "MarketCard", "RacePicker", "StableBoard", "Starter",
	"StyleShop", "Map", "GrownUpsPanel" }
function RaceState.busy(): boolean
	if localPlayer:GetAttribute("TrainingRide") then return true end
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end
	for _, name in PANELS do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then return true end
	end
	return false
end

-- The lane you cheered for, if it's in the race the HUD follows.
function RaceState.myCheer(): number?
	if RaceState.cheeredCourse ~= nil and RaceState.cheeredCourse == RaceState.focus then return RaceState.cheeredLane end
	return nil
end

-- The cheer strip (560 px at the top centre) would cover the race map (top right): on phones,
-- and on screens narrower than strip plus map side by side (a tablet), the map steps aside.
function RaceState.stripCoversMap(): boolean
	local camera = workspace.CurrentCamera
	if not camera then return false end
	return camera.ViewportSize.X < 592 + 640 * RaceState.hudScale()
end

-- A phone-sized screen (short side 500 px or less).
function RaceState.phone(): boolean
	local camera = workspace.CurrentCamera
	if not camera then return false end
	return math.min(camera.ViewportSize.X, camera.ViewportSize.Y) <= 500
end

function RaceState.consider(courseId: string?, laneList, start: number): boolean
	local key = tostring(courseId) .. ":" .. tostring(start)
	if decided[key] ~= nil then return decided[key] end
	local mine = false
	for _, lane in laneList do
		if lane.id == myId then mine = true end
	end
	-- Your own race (still racing, on its results card or replay, or still in its saddle)
	-- keeps the focus; other races are only watched when you have none, and only from near
	-- their course. The next race on your own course waits while your results card is up.
	local busy = RaceState.myCourse ~= nil and (RaceState.myCourse ~= courseId or RaceState.holdFocus)
	local focus = mine or (not busy and RaceState.nearCourse(courseId))
	decided[key] = focus
	if focus then
		RaceState.focus = courseId
	elseif RaceState.focus == courseId then
		RaceState.focus = nil -- the last race followed on this course is over; this one isn't followed
		RaceState.active = false -- (it may still be pulling up)
	end
	if mine then RaceState.myCourse = courseId end
	return focus
end

-- Done with your race: watching other races can take the focus again.
function RaceState.releaseMyRace()
	RaceState.myCourse = nil
	RaceState.holdFocus = false
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
