--!nonstrict
-- RaceView: animates the horses round the racecourse on every client (D-025, D-027,
-- D-033), so they gallop smoothly. Everyone gets the same timeline from the server, so all
-- screens show the same race. Riders are welded to their horse's saddle and move with it.
--   Pace: every horse runs at the race's constant speed, so the field reaches the line as
--   the race ends.
--   Gaps: the server sends each horse's offset from the pace a few times a second. Up to
--   the far turn it comes from live chance (skill); from the far turn to the last tap it
--   blends toward the projected finish order (luck), so late chargers come through and the
--   order on screen at the line is the result. No reshuffle at the line.
--   Your own horse also gets a small instant nudge on a Great or Perfect tap (same size for
--   everyone, never luck), so a rider sees their tap work straight away.
-- It also records the race (positions 10 times a second) for the replay.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local RaceState = require(script.Parent:WaitForChild("RaceState"))

local CFG = TrackLayout.churchill
local myId = tostring(Players.LocalPlayer.UserId)
local BOB_HZ, BOB_STUDS = 1.8, 0.3
local PAST_LINE = 0.012     -- past the line, horses ease to a stop within about this fraction
local RECORD_HZ = 10

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- race = { start, plan, lanes, myLane, offset = {}, target = {}, done = false, doneAt }
local race = nil

local function horseModel(i: number): Model?
	local track = workspace:FindFirstChild("RaceTrack")
	local horses = track and track:FindFirstChild("Horses")
	return horses and horses:FindFirstChild("Lane" .. i)
end

local function place(i: number, p: number, bob: number, plan)
	local horse = horseModel(i)
	if not horse then return end
	local x, z, dx, dz = TrackLayout.lanePoint(CFG, plan, i, p)
	local pos = Vector3.new(x, bob, z)
	horse:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)))
end
RaceState.placeHorse = place -- the replay uses the same placement

-- Past the line, ease to a stop instead of running on.
local function easePastLine(p: number): number
	if p <= 1 then return p end
	return 1 + PAST_LINE * (1 - math.exp(-(p - 1) / PAST_LINE))
end

remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList, start, cond)
	local plan = TrackLayout.plan(CFG, TrackLayout.distances[cond and cond.distance or "Sprint"] or TrackLayout.distances.Sprint)
	race = { start = start, plan = plan, lanes = #laneList, offset = {}, target = {}, done = false }
	for i, lane in laneList do
		race.offset[i], race.target[i] = 0, 0
		if lane.id == myId then race.myLane = i end
	end
	RaceState.active, RaceState.final, RaceState.plan, RaceState.lanes = true, false, plan, #laneList
	RaceState.progress, RaceState.place, RaceState.order = {}, {}, {}
	RaceState.myLane = race.myLane
	RaceState.recording = { start = start, plan = plan, lanes = #laneList, frames = {}, events = {} }
	RaceState.nudgeAt = -math.huge
end)

remotes.RaceOffsets.OnClientEvent:Connect(function(offsets)
	if not race then return end
	for i, feet in offsets do race.target[i] = feet end
end)

remotes:WaitForChild("RaceAborted").OnClientEvent:Connect(function()
	race = nil
	RaceState.active = false
	RaceState.recording = nil
end)

remotes.RaceFinished.OnClientEvent:Connect(function(summary)
	if not race then return end
	RaceState.setFinal(summary)
	race.done = true
	race.doneAt = serverNow()
	if RaceState.recording then RaceState.recording.summary = summary end
end)

local lastRecord = 0
RunService.RenderStepped:Connect(function(dt)
	if not race then return end
	local t = serverNow()
	local k = math.min(1, dt * 2.5)
	local base = math.max(0, (t - race.start) * GameConfig.raceSpeedStudsPerSecond)
	local nudge = GameConfig.tapNudgeFeet * math.exp(-(t - (RaceState.nudgeAt or -math.huge)) / 0.6)
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
		place(i, p, bob, race.plan)
		RaceState.progress[i] = p
	end
	RaceState.rank()
	-- Record for the replay.
	local rec = RaceState.recording
	if rec and t - lastRecord >= 1 / RECORD_HZ and t >= race.start then
		lastRecord = t
		local frame = { t = t }
		for i = 1, race.lanes do frame[i] = RaceState.progress[i] end
		table.insert(rec.frames, frame)
	end
	if race.done and (allStopped or t - race.doneAt > GameConfig.runInSeconds + 4) then
		race = nil -- the horses stay where they stopped until the next race (or the replay)
		RaceState.active = false
	end
end)
