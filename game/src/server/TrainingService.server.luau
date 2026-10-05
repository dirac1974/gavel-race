--!nonstrict
-- TrainingService (D-039, D-040, D-053): training rides at the Training Ground and the paddock
-- gymkhana, the Quick train games, and check-ups at the Vet.
--   Training rides (D-053):
--     TrainStart(horseId, course)   client -> server: ride this course on my active horse
--     TrainBegin(course, seed, n)   server -> client: you're at the start; GO in n seconds
--     TrainEnd(result)              server -> client: stars, gain, ribbon for the end card
--     TrainAbort(reason)            server -> client: the session ended with no gain (a race,
--                                   getting off, riding away); client -> server: stop riding
--     TrainCue(kind, data)          server -> client: Gate Break moments ("armed" = Ready,
--                                   "bell", "early", "go", "flag")
--   Gate Break runs a live tracker on screened samples (the same screening a replay uses), so
--   the bell the rider hears is the one the score uses; bell times come from the session seed.
--   Hill Climb ends when Pip finishes his two laps. Both take the player's latency allowance
--   (round trip + margin, capped at 0.3 s): off each reaction, and as Pip's clock lag.
--   The client sends no score. The server checks the horse is yours, stalled and the one you
--   ride, that you're at the paddock or the Training Ground and not racing, and the session
--   limits; puts you at the start; then samples the ride rig's root at 10 Hz on its own clock
--   and scores the samples (TrainingRide). Gains go through Training.train and its weekly cap;
--   training costs no Energy. Too many dropped samples are only logged while enforceFloor is
--   off (the first two weeks).
--   While a course session runs, from the countdown until the end card closes, the player has
--   the attribute TrainingRide = true (other HUDs read it). It clears on the card's Done, an
--   abort, an error, leaving, or after CARD_SECONDS as a safety net if the card never says.
--   A ride that runs out of time (maxSessionSeconds) counts only with real riding in it;
--   otherwise it ends kindly with no gain ("Let's try that one again!").
--   Quick train (the old 10-second games) still sends a client score until T4; its quality is
--   capped at GameConfig.training.quickQualityCap.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Training = require(Shared:WaitForChild("Training"))
local TrainingCourses = require(Shared:WaitForChild("TrainingCourses"))
local TrainingRide = require(Shared:WaitForChild("TrainingRide"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Profile = require(Shared:WaitForChild("Profile"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local TapTime = require(Shared:WaitForChild("TapTime"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Rides = require(script.Parent:WaitForChild("Rides"))
local WorldScene = require(script.Parent:WaitForChild("WorldScene"))

local CFG = GameConfig.training
local Train = Profiles.remote("Train")             -- client -> server: horseId, stat, score (Quick train)
local VetVisit = Profiles.remote("VetVisit")       -- client -> server: horseId, score
local TrainStart = Profiles.remote("TrainStart")   -- client -> server: horseId, course
local TrainBegin = Profiles.remote("TrainBegin")   -- server -> client: course, seed, countdown seconds
local TrainEnd = Profiles.remote("TrainEnd")       -- server -> client: result
local TrainAbort = Profiles.remote("TrainAbort")   -- both ways: reason / stop
local TrainCue = Profiles.remote("TrainCue")       -- server -> client: Gate Break moments
local SESSION_GAP = CFG.sessionGapSeconds          -- seconds between sessions (each game takes longer)
local CARD_SECONDS = 90                            -- safety net: TrainingRide clears this long after the end card opens

local lastTrain: { [Player]: number } = {}
local lastVet: { [Player]: number } = {}
local sessions: { [Player]: any } = {}
local history: { [Player]: { number } } = {}
local pending: { [Player]: boolean } = {}
local cards: { [Player]: any } = {}                -- end card showing: { untilT }

local function setTrainingRide(player: Player, on: boolean)
	if player.Parent then player:SetAttribute("TrainingRide", if on then true else nil) end
end

local ABORT_TEXT = {
	race = "Your race is starting! Training paused.",
	off = "Training paused. Hop back on and ride again any time!",
	left = "You rode off the course, so training paused. Ride again any time!",
	again = "Let's try that one again!",
}

local function near(player: Player, key: string, radius: number): boolean
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local p = WorldLayout.places[key]
	if not hrp or not p then return false end
	local r = WorldLayout.placeRect(key)
	local pos = hrp.Position
	if r then
		return pos.X >= r[1] - radius and pos.X <= r[3] + radius and pos.Z >= r[2] - radius and pos.Z <= r[4] + radius
	end
	return (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(p.x, 0, p.z)).Magnitude <= radius
end

local function horseFor(player: Player, horseId: any)
	if typeof(horseId) ~= "string" then return nil end
	local data = Profiles.get(player)
	local h = data and Profile.horse(data, horseId)
	if not h or not Profile.isStalled(data, horseId) then return nil end
	return h
end

local function racing(player: Player): boolean
	return player:GetAttribute("Racing") == true or player:GetAttribute("InLine") == true
end

-- Quick train: the 10-second games (client-scored until T4).
Train.OnServerEvent:Connect(function(player: Player, horseId: any, stat: any, score: any)
	if typeof(stat) ~= "string" or typeof(score) ~= "number" or score ~= score then return end
	if sessions[player] then return end
	if os.clock() - (lastTrain[player] or 0) < SESSION_GAP then
		Profiles.notify(player, "Your horse is catching its breath. Try again in a moment!", "heart")
		return
	end
	local h = horseFor(player, horseId)
	if not h then return end
	if not near(player, "paddock", 30) then
		Profiles.notify(player, "Training happens at the Training Paddock on Fair Street", "map_fair")
		return
	end
	lastTrain[player] = os.clock()
	if CFG.mode == "rides" then score = TrainingRide.quickScore(score, CFG) end -- courses own the top scores (D-053)
	local ok, _, msg = Training.train(h, stat, score, os.time())
	Profiles.notify(player, msg, if ok then "stat_" .. stat else "heart")
	if ok then
		Progress.record(player, "train", 1)
		Profiles.changed(player)
	end
end)

-- Training rides -------------------------------------------------------------------------
local function endSession(player: Player, s)
	if sessions[player] ~= s then return false end
	sessions[player] = nil
	Rides.setTraining(player, false)
	return true
end

local function closeCard(player: Player)
	cards[player] = nil
	if not sessions[player] then setTrainingRide(player, false) end
end

local function abort(player: Player, s, reason: string)
	if not endSession(player, s) then return end
	closeCard(player)
	if player.Parent then TrainAbort:FireClient(player, reason, ABORT_TEXT[reason]) end
end

-- Something went wrong part-way (an error): whatever state the session got to, clear it all,
-- even if the session was already taken off the list, and tell the client.
local function fail(player: Player, s)
	if s and sessions[player] == s then sessions[player] = nil end
	pcall(Rides.setTraining, player, false)
	cards[player] = nil
	setTrainingRide(player, false)
	if player.Parent then TrainAbort:FireClient(player, "off", ABORT_TEXT.off) end
end

local function finish(player: Player, s, seconds: number, timedOut: boolean?)
	if not endSession(player, s) then return end
	local result = TrainingRide.run(s.course, s.samples, CFG, seconds, { seed = s.seed, allowance = s.allowance })
	local data = Profiles.get(player)
	local h = data and Profile.horse(data, s.horseId)
	if not result or not h then
		closeCard(player)
		TrainAbort:FireClient(player, "off", ABORT_TEXT.off)
		return
	end
	if timedOut and not TrainingRide.timeoutCounts(result, s.tracker) then
		closeCard(player) -- out of time with no real riding: no gain, no ribbon, no job
		TrainAbort:FireClient(player, "again", ABORT_TEXT.again)
		return
	end
	cards[player] = { untilT = os.clock() + CARD_SECONDS } -- TrainingRide stays set while the end card shows
	if result.flagged then
		-- Log only (D-053): replication jitter on phones can drop honest samples.
		warn(string.format("[Training] %d %s: %.0f%% of %d samples too fast or teleported (%d stale, %d off course)%s",
			player.UserId, s.course, result.badShare * 100, #s.samples, result.counts.stale, result.counts.off,
			if result.floored then " (scored at the floor)" else " (log only)"))
	end
	local course = TrainingCourses.courses[s.course]
	local now = os.time()
	local gain = TrainingRide.applyGain(h, course.stat, result.score, now)
	local newRibbon = TrainingRide.record(h, s.course, result)
	Progress.record(player, "train", 1)
	Profiles.changed(player)
	TrainEnd:FireClient(player, {
		course = s.course, horseId = s.horseId, horseName = h.name,
		stars = result.stars, ribbon = result.ribbon, newRibbon = newRibbon,
		gained = gain.gained, before = gain.before, after = gain.after, capped = gain.capped, rested = gain.rested,
		potential = if h.stamps and h.stamps.potential then h.potential[course.stat] else nil,
		detail = if s.course == "speed" then { hoops = result.detail.hoops, of = result.detail.of }
			elseif s.course == "accel" then { breaks = result.detail.scored, quick = result.detail.quick }
			elseif s.course == "stamina" then { share = result.detail.share }
			else { mud = result.detail.mud, logs = result.detail.logs, poles = result.detail.poles },
		finished = seconds ~= nil and s.tracker.finished,
	})
end

local function startCourse(player: Player, horseId: any, course: any)
	if typeof(course) ~= "string" or not TrainingCourses.courses[course] then return end
	if CFG.mode ~= "rides" then return end
	if not CFG.courses[course] then
		Profiles.notify(player, TrainingCourses.courses[course].name .. " is coming soon!", "stat_" .. course)
		return
	end
	if racing(player) then
		Profiles.notify(player, "Training can wait: your race is coming up!", "heart")
		return
	end
	history[player] = history[player] or {}
	local ok, why = TrainingRide.rateCheck(history[player], os.clock(), CFG)
	if not ok then
		Profiles.notify(player, if why == "gap" then "Your horse is catching its breath. Try again in a moment!"
			else "What a lot of riding! Give your horse a rest, or try a race.", "heart")
		return
	end
	local data = Profiles.get(player)
	local h = horseFor(player, horseId)
	if not data or not h then return end
	if data.activeHorse ~= horseId then
		Profiles.notify(player, "Pick " .. h.name .. " as your horse in My Horses to ride the courses", "heart")
		return
	end
	local function where(): Vector3?
		local rig = Rides.horseOf(player)
		local root = rig and rig.PrimaryPart
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return (root and root.Position) or (hrp and hrp.Position)
	end
	local pos = where()
	if not pos or not TrainingCourses.nearTraining(pos.X, pos.Z, 30) then
		Profiles.notify(player, "Training happens at the Training Paddock on Fair Street", "map_fair")
		return
	end
	-- Not riding yet? Bring the horse (with the Ride button's throttle) and wait for the saddle.
	local rig, rigHorse = Rides.horseOf(player)
	if not rig then
		Rides.request(player)
		for _ = 1, 25 do
			if Rides.isSeated(player) or not player.Parent then break end
			task.wait(0.1)
		end
		rig, rigHorse = Rides.horseOf(player)
	end
	if not player.Parent or sessions[player] then return end
	if not rig or rigHorse ~= horseId or not Rides.isSeated(player) then
		Profiles.notify(player, "Hop on " .. h.name .. " to ride the course!", "heart")
		return
	end
	if racing(player) then return end
	-- To the start, facing the way to go.
	local c = TrainingCourses.courses[course]
	local st = c.start
	local base = Vector3.new(st.x, WorldScene.GROUND_Y + TrainingCourses.groundHeight(st.x, st.z), st.z)
	Rides.travel(player, CFrame.lookAt(base, base + Vector3.new(st.lookX, 0, st.lookZ)))
	if rig.PrimaryPart then rig.PrimaryPart.AssemblyLinearVelocity = Vector3.zero end
	table.insert(history[player], os.clock())
	local now = os.clock()
	local seed = math.random(1, 2 ^ 30)
	-- the bell goes out and the go comes back: the whole round trip, plus a margin, capped
	local allowance = TapTime.rewindAllowance(2 * player:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	local s = {
		course = course, horseId = horseId, rig = rig, seed = seed, allowance = allowance,
		goAt = now + CFG.countdownSeconds, lastSample = now, samples = {}, base = {}, baseY = nil,
		outside = 0, tracker = TrainingRide.tracker(course, { seed = seed, allowance = allowance }),
		screen = TrainingRide.screener(function(x: number, z: number): boolean return TrainingCourses.onCourse(course, x, z) end),
		endT = if course == "stamina" then TrainingCourses.idealSeconds("stamina", seed) else nil,
		bellSent = 0,
	}
	-- Register first, then change groups and attributes: an error from here on is undone by fail().
	sessions[player] = s
	cards[player] = nil
	setTrainingRide(player, true)
	Rides.setTraining(player, true)
	TrainBegin:FireClient(player, course, s.seed, CFG.countdownSeconds)
end

TrainStart.OnServerEvent:Connect(function(player: Player, horseId: any, course: any)
	if pending[player] or sessions[player] then return end
	pending[player] = true
	local ok, err = pcall(startCourse, player, horseId, course)
	pending[player] = nil
	if not ok then
		warn("[Training] start failed: " .. tostring(err))
		fail(player, sessions[player])
		return
	end
	if not sessions[player] and cards[player] then closeCard(player) end -- "Ride again" that didn't start
end)

-- From the client: stop riding (no gain), or the end card closed.
TrainAbort.OnServerEvent:Connect(function(player: Player)
	local s = sessions[player]
	if s then
		abort(player, s, "stop")
	elseif cards[player] then
		closeCard(player)
	end
end)

-- The sampler: the rider's own ride rig, 10 times a second on the server's clock.
local function sample(player: Player, s, now: number)
	if not player.Parent then
		endSession(player, s)
		return
	end
	if racing(player) then return abort(player, s, "race") end
	local rig, id = Rides.horseOf(player)
	if rig ~= s.rig or id ~= s.horseId or not rig.Parent or not Rides.isSeated(player) then return abort(player, s, "off") end
	local root = rig.PrimaryPart
	if not root then return abort(player, s, "off") end
	local pos = root.Position
	if now < s.goAt then
		table.insert(s.base, pos.Y) -- standing at the start: the horse's riding height
		return
	end
	if not s.baseY then
		table.sort(s.base)
		s.baseY = if #s.base > 0 then s.base[(#s.base + 1) // 2] else pos.Y
	end
	local t = now - s.goAt
	local smp = { t = t, x = pos.X, z = pos.Z, y = pos.Y - s.baseY - TrainingCourses.groundHeight(pos.X, pos.Z) }
	table.insert(s.samples, smp)
	if TrainingCourses.inArea(s.course, pos.X, pos.Z) then
		s.outside = 0
	else
		s.outside += 1 / CFG.sampleHz
		if s.outside >= CFG.leaveSeconds then return abort(player, s, "left") end
	end
	if s.course == "accel" then
		-- Gate Break: screened samples drive the live tracker; its moments go to the client
		local kind, kept = TrainingRide.screen(s.screen, smp, CFG)
		if kind == "ok" then TrainingRide.feed(s.tracker, kept, CFG) end
		for _, e in s.tracker.events do TrainCue:FireClient(player, e.kind, e) end
		table.clear(s.tracker.events)
		if s.tracker.finished then return finish(player, s, s.tracker.finishT or t) end
	elseif s.course == "stamina" then
		if t >= s.endT then return finish(player, s, s.endT) end -- Pip has finished his two laps
	elseif TrainingRide.feed(s.tracker, smp, CFG) then
		return finish(player, s, s.tracker.finishT or t)
	end
	if t >= CFG.maxSessionSeconds then return finish(player, s, t, true) end -- counts only with real riding
end

-- Gate Break's bell rings on time (Heartbeat), not at the next sample.
local function ringBell(player: Player, s, now: number)
	local tr = s.tracker
	if (tr.phase == "armed" or tr.phase == "go") and tr.bellT and s.bellSent ~= tr.arms and now - s.goAt >= tr.bellT then
		s.bellSent = tr.arms
		TrainCue:FireClient(player, "bell", { breakNo = tr.breakNo })
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, card in cards do
		if now > card.untilT or not player.Parent then closeCard(player) end -- the card's Done normally clears it
	end
	local step = 1 / CFG.sampleHz
	for player, s in sessions do
		if s.course == "accel" then ringBell(player, s, now) end
		if now - s.lastSample >= step then
			s.lastSample = if now - s.lastSample < 2 * step then s.lastSample + step else now
			local ok, err = pcall(sample, player, s, now)
			if not ok then
				warn("[Training] sample failed: " .. tostring(err))
				fail(player, s) -- also when finish() had already ended the session
			end
		end
	end
end)

-- The Vet -----------------------------------------------------------------------------------
VetVisit.OnServerEvent:Connect(function(player: Player, horseId: any, score: any)
	if os.clock() - (lastVet[player] or 0) < 2 then return end
	if typeof(score) ~= "number" then return end
	local h = horseFor(player, horseId)
	if not h then return end
	if not near(player, "vet", 30) then
		Profiles.notify(player, "Check-ups happen at the Vet on Fair Street", "map_vet")
		return
	end
	lastVet[player] = os.clock()
	local ok, msg, stamp, counted = Training.checkup(h, score, os.time())
	Profiles.notify(player, msg, if stamp then "stamp_" .. stamp else "stethoscope")
	if ok then
		if counted then Progress.record(player, "checkup", 1) end
		Profiles.changed(player)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastTrain[player], lastVet[player] = nil, nil
	sessions[player], history[player], pending[player], cards[player] = nil, nil, nil, nil
end)
