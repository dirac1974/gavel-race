--!nonstrict
-- RaceView: animates the horses round the racecourse on every client (D-025, D-027), so they gallop
-- smoothly instead of stepping with server updates. Everyone gets the same timeline from
-- the server (start time, expected end, live chances, finish order), so all screens show
-- the same race. Riders are welded to their horse's saddle and move with it.
--   During the race: all horses advance together along the race plan for the distance,
--   reaching about a second short of the line when the Final Burst closes;
--   the likelier winners (live win chance) edge ahead, eased in so nobody lurches.
--   Run-in: when the result arrives, horses cross the line in finish order, one by one.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local CFG = TrackLayout.churchill
local LEAD_SCALE = 0.25      -- lap fraction of lead per unit of (win chance - fair share)
local MAX_BEFORE_RESULT = 0.995 -- nobody crosses the line before the result is known
local BOB_HZ, BOB_STUDS = 1.8, 0.3
local FIRST_CROSS, CROSS_GAP = 1.0, 0.25 -- run-in: winner crosses after 1 s, the rest 0.25 s apart

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- race = { start, finishEst, lanes = n, offset = {}, target = {}, ids = {[userId] = lane},
--          runIn = nil | { t0, from = {}, cross = {} } }
local race = nil

local function horseModel(i: number): Model?
	local track = workspace:FindFirstChild("RaceTrack")
	local horses = track and track:FindFirstChild("Horses")
	return horses and horses:FindFirstChild("Lane" .. i)
end

local function place(i: number, p: number, bob: number)
	local horse = horseModel(i)
	if not horse then return end
	local x, z, dx, dz = TrackLayout.lanePoint(CFG, race.plan, i, p)
	local pos = Vector3.new(x, bob, z)
	horse:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)))
end

local function cruise(t: number): number
	local span = math.max(1, race.finishEst - race.start)
	return race.cruiseEnd * math.clamp((t - race.start) / span, 0, 1)
end

-- Progress of lane i during the race (before the result): shared pace plus its lead,
-- with the lead growing in over the first third of the lap.
local function racing(i: number, t: number): number
	local b = cruise(t)
	return math.clamp(b + race.offset[i] * math.min(1, b / 0.3), 0, MAX_BEFORE_RESULT)
end

remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList, start, cond, finishEst)
	local plan = TrackLayout.plan(CFG, TrackLayout.distances[cond and cond.distance or "Sprint"] or TrackLayout.distances.Sprint)
	-- At the expected end (the burst closing) horses are about burstBeforeLine seconds from the line.
	local cruiseEnd = 1 - GameConfig.raceSpeedStudsPerSecond * GameConfig.burstBeforeLineSeconds / plan.lengths[1]
	race = { start = start, finishEst = finishEst or (start + 60), plan = plan, cruiseEnd = cruiseEnd,
		lanes = #laneList, offset = {}, target = {}, runIn = nil }
	for i = 1, #laneList do
		race.offset[i], race.target[i] = 0, 0
	end
end)

remotes.LiveChances.OnClientEvent:Connect(function(_seg, live)
	if not race then return end
	local fair = 1 / race.lanes
	for i, c in live do race.target[i] = LEAD_SCALE * (c - fair) end
end)

remotes.RaceFinished.OnClientEvent:Connect(function(summary)
	if not race then return end
	local t = serverNow()
	local from, cross = {}, {}
	for i = 1, race.lanes do from[i] = racing(i, t) end
	for _, row in summary do
		local lane = row.lane
		if lane then cross[lane] = FIRST_CROSS + (row.place - 1) * CROSS_GAP end
	end
	for i = 1, race.lanes do cross[i] = cross[i] or (FIRST_CROSS + race.lanes * CROSS_GAP) end
	race.runIn = { t0 = t, from = from, cross = cross }
end)

RunService.RenderStepped:Connect(function(dt)
	if not race then return end
	local t = serverNow()
	local k = math.min(1, dt * 1.2)
	for i = 1, race.lanes do
		race.offset[i] += (race.target[i] - race.offset[i]) * k
		local p, moving
		if race.runIn then
			-- Reach the line (p = 1) exactly at this horse's crossing time, then ease off.
			local tau = t - race.runIn.t0
			local tc, p0 = race.runIn.cross[i], race.runIn.from[i]
			local speed = (1 - p0) / tc
			if tau <= tc then
				p = p0 + speed * tau
			else
				local over = tau - tc
				p = 1 + speed * over * math.max(0, 1 - over / 3) -- slows to a walk past the line
			end
			moving = tau < tc + 3
		else
			p = racing(i, t)
			moving = t > race.start
		end
		local bob = if moving then BOB_STUDS * math.abs(math.sin((t * BOB_HZ + i * 0.37) * math.pi)) else 0
		place(i, p, bob)
	end
	if race.runIn and t - race.runIn.t0 > GameConfig.runInSeconds + 4 then
		race = nil -- the server rebuilds the track at the next race
	end
end)
