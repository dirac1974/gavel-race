--!nonstrict
-- RaceView: animates the horses round the racecourse on every client (D-025, D-027,
-- D-033, D-036), so they gallop smoothly. Everyone gets the same timeline from the server, so
-- all screens show the same races. Riders are welded to their horse's saddle and move with it.
-- Both courses (dirt and turf) can race at once; every race on screen is animated, and the
-- one this client follows (RaceState.focus) also feeds the places, the race map and the replay.
--   Pace: every horse runs at the race's constant speed, so the field reaches the line as
--   the race ends.
--   Gaps: the server sends each horse's offset from the pace a few times a second. Up to
--   the far turn it comes from live chance (skill); from the far turn to the last tap it
--   blends toward the projected finish order (luck), so late chargers come through and the
--   order on screen at the line is the result. No reshuffle at the line.
--   Your own horse also gets a small instant nudge on a Great or Perfect tap (same size for
--   everyone, never luck), so a rider sees their tap work straight away.
-- It also records the followed race (positions 10 times a second) for the replay.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))

local myId = tostring(Players.LocalPlayer.UserId)
local BOB_HZ, BOB_STUDS = 1.8, 0.3
local PAST_LINE = 0.012     -- past the line, horses ease to a stop within about this fraction
local RECORD_HZ = 10

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- races[course] = { course, cfg, start, plan, lanes, myLane, offset = {}, target = {}, done, doneAt, focus }
local races: { [string]: any } = {}

local function horseModel(courseId: string?, i: number): Model?
	local track = RaceState.trackFolder(courseId)
	local horses = track and track:FindFirstChild("Horses")
	return horses and horses:FindFirstChild("Lane" .. i)
end

local lastPlaced = setmetatable({}, { __mode = "k" }) -- horse -> { p, t } for the legs

-- `timeScale`: how fast the race clock runs (replays in slow motion), so the legs pick the gait
-- for the race's real speed.
local function place(i: number, p: number, bob: number, plan, courseId: string?, timeScale: number?)
	local horse = horseModel(courseId, i)
	if not horse then return end
	local cfg = TrackLayout.courses[courseId or "dirt"] or TrackLayout.churchill
	local x, z, dx, dz = TrackLayout.lanePoint(cfg, plan, i, p)
	local pos = Vector3.new(x, bob, z)
	horse:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)))
	-- Running legs (D-051): stride with the distance covered since the last frame.
	if HorseLegs.has(horse) then
		local now = os.clock()
		local prev = lastPlaced[horse]
		local dist = if prev then math.max(0, (p - prev.p) * plan.lengths[i]) else 0
		local dt = if prev then math.clamp(now - prev.t, 0, 0.2) else 0
		if prev then
			prev.p, prev.t = p, now
		else
			lastPlaced[horse] = { p = p, t = now }
		end
		HorseLegs.apply(horse, dist, dt, timeScale)
	end
end
RaceState.placeHorse = place -- the replay uses the same placement

-- Legs straight down for every horse on a course (a race or replay has ended).
function RaceState.restHorses(courseId: string?, lanes: number)
	for i = 1, lanes do
		local horse = horseModel(courseId, i)
		if horse then
			lastPlaced[horse] = nil
			HorseLegs.rest(horse)
		end
	end
end

-- Past the line, ease to a stop instead of running on.
local function easePastLine(p: number): number
	if p <= 1 then return p end
	return 1 + PAST_LINE * (1 - math.exp(-(p - 1) / PAST_LINE))
end

remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList, start, cond, _resultAt, _burstOpen, courseId)
	courseId = courseId or "dirt"
	local cfg = TrackLayout.courses[courseId] or TrackLayout.churchill
	local plan = TrackLayout.plan(cfg, TrackLayout.distances[cond and cond.distance or "Sprint"] or TrackLayout.distances.Sprint)
	local race = { course = courseId, cfg = cfg, start = start, plan = plan, lanes = #laneList, offset = {}, target = {}, done = false }
	for i, lane in laneList do
		race.offset[i], race.target[i] = 0, 0
		if lane.id == myId then race.myLane = i end
	end
	local focus = RaceState.consider(courseId, laneList, start)
	races[courseId] = race
	if focus then
		RaceState.active, RaceState.final, RaceState.plan, RaceState.lanes = true, false, plan, #laneList
		RaceState.progress, RaceState.place, RaceState.order = {}, {}, {}
		RaceState.myLane = race.myLane
		RaceState.course = courseId
		RaceState.recording = { start = start, plan = plan, lanes = #laneList, frames = {}, events = {}, course = courseId, myLane = race.myLane }
		RaceState.nudgeAt = -math.huge
	end
end)

remotes.RaceOffsets.OnClientEvent:Connect(function(offsets, courseId)
	local race = races[courseId or "dirt"]
	if not race then return end
	for i, feet in offsets do race.target[i] = feet end
end)

remotes:WaitForChild("RaceAborted").OnClientEvent:Connect(function(courseId)
	local race = races[courseId or "dirt"]
	races[courseId or "dirt"] = nil
	if race and RaceState.focus == (courseId or "dirt") then
		RaceState.active = false
		RaceState.recording = nil
	end
	if race and race.myLane then RaceState.releaseMyRace() end
end)

remotes.RaceFinished.OnClientEvent:Connect(function(summary, courseId)
	local race = races[courseId or "dirt"]
	if not race then return end
	race.done = true
	race.doneAt = serverNow()
	if RaceState.focus == (courseId or "dirt") then
		RaceState.setFinal(summary)
		if RaceState.recording then RaceState.recording.summary = summary end
	end
end)

local lastRecord = 0
RunService.RenderStepped:Connect(function(dt)
	local t = serverNow()
	local k = math.min(1, dt * 2.5)
	for courseId, race in races do
		local isFocus = RaceState.focus == courseId -- only the followed race writes the shared state
		local base = math.max(0, (t - race.start) * GameConfig.raceSpeedStudsPerSecond)
		local nudge = if isFocus then GameConfig.tapNudgeFeet * math.exp(-(t - (RaceState.nudgeAt or -math.huge)) / 0.6) else 0
		local allStopped = true
		for i = 1, race.lanes do
			race.offset[i] += (race.target[i] - race.offset[i]) * k
			local len = race.plan.lengths[i]
			-- Gaps grow in over the first 30% so the field leaves the gate together.
			local feet = base + race.offset[i] * math.min(1, base / (0.3 * len))
			if i == race.myLane then feet += nudge end
			local raw = math.max(0, feet / len)
			local p = easePastLine(raw)
			local moving = t > race.start and raw < 1 + 3 * PAST_LINE
			if moving then allStopped = false end
			local bob = if moving then BOB_STUDS * math.abs(math.sin((t * BOB_HZ + i * 0.37) * math.pi)) else 0
			place(i, p, bob, race.plan, courseId)
			if isFocus then RaceState.progress[i] = p end
		end
		if isFocus then
			RaceState.rank()
			-- Record for the replay.
			local rec = RaceState.recording
			if rec and rec.course == courseId and t - lastRecord >= 1 / RECORD_HZ and t >= race.start then
				lastRecord = t
				local frame = { t = t }
				for i = 1, race.lanes do frame[i] = RaceState.progress[i] end
				table.insert(rec.frames, frame)
			end
		end
		if race.done and (allStopped or t - race.doneAt > GameConfig.runInSeconds + 4) then
			RaceState.restHorses(courseId, race.lanes)
			races[courseId] = nil -- the horses stay where they stopped until the next race (or the replay)
			if isFocus then RaceState.active = false end
		end
	end
end)
