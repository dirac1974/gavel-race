--!nonstrict
-- RaceView: animates the horses round the racecourse on every client (D-025, D-027), so they gallop
-- smoothly instead of stepping with server updates. Everyone gets the same timeline from
-- the server (start time, expected end, live chances, finish order), so all screens show
-- the same race. Riders are welded to their horse's saddle and move with it.
--   During the race: all horses run at the race's constant speed, so they reach the line
--   when the race ends; near the line they ease toward it until the result is known;
--   the likelier winners (live win chance) edge ahead, eased in so nobody lurches.
--   Run-in: when the result arrives, horses cross the line in finish order, one by one.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local RaceState = require(script.Parent:WaitForChild("RaceState"))

local CFG = TrackLayout.churchill
local LEAD_FEET = 320        -- feet of lead per unit of (win chance - fair share): ~55 ft for a strong favourite
local SOFT_FROM, SOFT_MAX = 0.975, 0.995 -- near the line, ease toward it; nobody crosses before the result
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

-- Past SOFT_FROM, progress bends smoothly toward SOFT_MAX instead of stopping dead.
local function soften(p: number): number
	if p <= SOFT_FROM then return p end
	local room = SOFT_MAX - SOFT_FROM
	return SOFT_FROM + room * (1 - math.exp(-(p - SOFT_FROM) / room))
end

-- Progress of lane i during the race (before the result): the race's constant speed plus
-- the horse's lead, which grows in over the first third.
local function racing(i: number, t: number): number
	local b = math.max(0, (t - race.start) * GameConfig.raceSpeedStudsPerSecond / race.plan.lengths[1])
	return soften(math.max(0, b + race.offset[i] * math.min(1, b / 0.3)))
end

remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList, start, cond, finishEst)
	local plan = TrackLayout.plan(CFG, TrackLayout.distances[cond and cond.distance or "Sprint"] or TrackLayout.distances.Sprint)
	race = { start = start, finishEst = finishEst or (start + 60), plan = plan,
		lanes = #laneList, offset = {}, target = {}, runIn = nil }
	for i = 1, #laneList do
		race.offset[i], race.target[i] = 0, 0
	end
	RaceState.active, RaceState.final, RaceState.plan, RaceState.lanes = true, false, plan, #laneList
	RaceState.progress, RaceState.place, RaceState.order = {}, {}, {}
end)

remotes.LiveChances.OnClientEvent:Connect(function(_seg, live)
	if not race then return end
	local fair = 1 / race.lanes
	for i, c in live do race.target[i] = LEAD_FEET * (c - fair) / race.plan.lengths[i] end
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
	task.delay(GameConfig.runInSeconds, RaceState.setFinal, summary) -- official order once they're home
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
				local over = math.min(tau - tc, 3)
				p = 1 + speed * (over - over * over / 6) -- eases to a stop 3 s past the line, never backwards
			end
			moving = tau < tc + 3
		else
			p = racing(i, t)
			moving = t > race.start
		end
		local bob = if moving then BOB_STUDS * math.abs(math.sin((t * BOB_HZ + i * 0.37) * math.pi)) else 0
		place(i, p, bob)
		RaceState.progress[i] = p
	end
	RaceState.rank()
	if race.runIn and t - race.runIn.t0 > GameConfig.runInSeconds + 4 then
		race = nil -- the server rebuilds the track at the next race
		RaceState.active = false
	end
end)
