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
--   The bells come from a server-only seed (never sent); the shared seed is Pip's. TrainBegin
--   carries the go time on the server's clock, so the rider's screen runs the countdown and Pip
--   on workspace:GetServerTimeNow(). Hill Climb ends when Pip finishes his two laps.
--   Latency allowances (capped at 0.3 s): Gate Break takes the round trip + margin off each
--   reaction, measured when that bell rings; Hill Climb lags Pip's clock by one way + margin
--   (the server sees the rider one trip late), from the ride's median ping.
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
--   Quick train (T4): the server seeds each 10-second game (QuickStart -> QuickBegin), the client
--   sends tap times (QuickTap), each resolved with TapTime.resolve (D-021), and the server
--   scores them with QuickTrain (quality capped at quickQualityCap) and says QuickEnd. There is
--   no client-scored path any more.
--   Ghosts (T4): a finished, unflagged ride becomes the player's ghost for that course if it's
--   their best (Ghosts, its own DataStore key); TrainGhosts sends your ghost, and in a solo
--   ride the ghosts of friends here who share theirs (settings.shareGhost, off by default).
--   Ride together (T4): TrainFriends lists Roblox friends nearby who can be invited (both with
--   stable visits not "Nobody"); TrainInvite -> the friend's TrainInvited card, accept-only,
--   lapsing after 20 s (TrainInviteGone), rate-limited (RideTogether). On "Ride together" both
--   start the course on one countdown and one Pip, each scored alone; TrainTogether shares
--   stars and ribbons only.
--   This week's course (T5): Mud Splash has four layouts, one a week in turn. The server picks
--   the layout from its own clock (TrainingCourses.resolve: whatever the client asked for) when
--   a ride starts, and the ride keeps it to the end, so a week turning over never changes a ride
--   under anyone; the next ride takes the new one. ReplicatedStorage's WeeklyCourse attribute
--   names this week's layout for the clients (the arena's props and the picker). Ribbons, best
--   runs and ghosts are kept per layout (its course key), so a layout's ribbons can be earned
--   whenever it comes back; no countdown anywhere.
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
local QuickTrain = require(Shared:WaitForChild("QuickTrain"))
local Ghost = require(Shared:WaitForChild("Ghost"))
local RideTogether = require(Shared:WaitForChild("RideTogether"))
local TapTime = require(Shared:WaitForChild("TapTime"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Ghosts = require(script.Parent:WaitForChild("Ghosts"))
local TrainingFriends = require(script.Parent:WaitForChild("TrainingFriends"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Rides = require(script.Parent:WaitForChild("Rides"))
local WorldScene = require(script.Parent:WaitForChild("WorldScene"))

local CFG = GameConfig.training
local QuickStart = Profiles.remote("QuickStart")   -- client -> server: horseId, stat (Quick train)
local QuickBegin = Profiles.remote("QuickBegin")   -- server -> client: stat, seed, start (server time)
local QuickTap = Profiles.remote("QuickTap")       -- client -> server: kind ("tap" | "down" | "up"), claimed server time
local QuickEnd = Profiles.remote("QuickEnd")       -- server -> client: score
local QuickStop = Profiles.remote("QuickStop")     -- client -> server: the game was closed (no gain)
local TrainGhosts = Profiles.remote("TrainGhosts") -- server -> client: course, ghosts
local TrainFriends = Profiles.remote("TrainFriends")         -- client -> server: who can I invite?
local TrainFriendsList = Profiles.remote("TrainFriendsList") -- server -> client: { { userId, name } }
local TrainInvite = Profiles.remote("TrainInvite")           -- client -> server: friend's userId, course
local TrainInvited = Profiles.remote("TrainInvited")         -- server -> friend: invite id, inviter's name, course
local TrainInviteReply = Profiles.remote("TrainInviteReply") -- friend -> server: invite id, accept?
local TrainInviteGone = Profiles.remote("TrainInviteGone")   -- server -> friend: invite id (lapsed or withdrawn)
local TrainTogether = Profiles.remote("TrainTogether")       -- server -> riders: stars and ribbons of the group
local VetVisit = Profiles.remote("VetVisit")       -- client -> server: horseId, score
local TrainStart = Profiles.remote("TrainStart")   -- client -> server: horseId, course
local TrainBegin = Profiles.remote("TrainBegin")   -- server -> client: course, seed, countdown seconds
local TrainEnd = Profiles.remote("TrainEnd")       -- server -> client: result
local TrainAbort = Profiles.remote("TrainAbort")   -- both ways: reason / stop
local TrainCue = Profiles.remote("TrainCue")       -- server -> client: Gate Break moments
local SESSION_GAP = CFG.sessionGapSeconds          -- seconds between sessions (each game takes longer)
local CARD_SECONDS = 90                            -- safety net: TrainingRide clears this long after the end card opens

local rng = Random.new()

local function median(list: { number }): number
	if #list == 0 then return 0 end
	local c = table.clone(list)
	table.sort(c)
	return c[(#c + 1) // 2]
end

local lastTrain: { [Player]: number } = {}
local lastVet: { [Player]: number } = {}
local sessions: { [Player]: any } = {}
local history: { [Player]: { number } } = {}
local pending: { [Player]: boolean } = {}
local cards: { [Player]: any } = {}                -- end card showing: { untilT }
local quick: { [Player]: any } = {}                -- Quick train games in play
local invites = RideTogether.book()
local lastAsk: { [Player]: number } = {}
local GROUP_LEAD = 2.5                             -- a group's countdown starts this much later (horses being called)
local nextGroupId = 1
local GHOST_COURSES = { speed = true } -- courses with ghosts: Sprint Lane and every Mud Splash layout (see finish)
for _, key in TrainingCourses.LAYOUTS do GHOST_COURSES[key] = true end

-- This week's Mud Splash layout (T5) for the clients, from the server's clock.
local function publishWeek(): string
	local key = TrainingCourses.weekCourse(os.time())
	if ReplicatedStorage:GetAttribute("WeeklyCourse") ~= key then ReplicatedStorage:SetAttribute("WeeklyCourse", key) end
	return key
end
publishWeek()

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

-- Quick train: the 10-second games, seeded and scored by the server (T4).
-- The game was closed (or a race is starting): it ends with no gain, and doesn't count as a
-- session, so opening another one straight away works.
local function stopQuick(player: Player)
	local q = quick[player]
	if not q then return end
	quick[player] = nil
	lastTrain[player] = q.prevTrain
	local h = history[player]
	local i = h and table.find(h, q.startedAt)
	if i then table.remove(h, i) end
end

QuickStart.OnServerEvent:Connect(function(player: Player, horseId: any, stat: any)
	if typeof(stat) ~= "string" or not Training.GAMES[stat] then return end
	if quick[player] then stopQuick(player) end -- a game left behind (its panel closed): it ends with no gain
	if sessions[player] or pending[player] then
		Profiles.notify(player, "Finish your ride first, then try a quick game!", "heart")
		return
	end
	if racing(player) then
		Profiles.notify(player, "Training can wait: your race is coming up!", "heart")
		return
	end
	if os.clock() - (lastTrain[player] or 0) < SESSION_GAP then
		Profiles.notify(player, "Your horse is catching its breath. Try again in a moment!", "heart")
		return
	end
	local h = horseFor(player, horseId)
	if not h then
		Profiles.notify(player, "Pick a horse from a stall to train!", "heart")
		return
	end
	if not near(player, "paddock", 30) then
		Profiles.notify(player, "Training happens at the Training Paddock on Fair Street", "map_fair")
		return
	end
	history[player] = history[player] or {}
	local ok = TrainingRide.rateCheck(history[player], os.clock(), CFG)
	if not ok then
		Profiles.notify(player, "What a lot of training! Give your horse a rest, or try a race.", "heart")
		return
	end
	local prevTrain = lastTrain[player]
	lastTrain[player] = os.clock()
	table.insert(history[player], os.clock())
	local q = {
		stat = stat, horseId = horseId, seed = rng:NextInteger(1, 2 ^ 30), events = {}, prevTrain = prevTrain, startedAt = os.clock(),
		startAt = workspace:GetServerTimeNow() + QuickTrain.LEAD,
		allowance = TapTime.rewindAllowance(player:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds),
	}
	quick[player] = q
	QuickBegin:FireClient(player, stat, q.seed, q.startAt)
end)

local QUICK_KINDS = { speed = { tap = true }, accel = { tap = true }, grit = { tap = true }, stamina = { down = true, up = true } }
QuickTap.OnServerEvent:Connect(function(player: Player, kind: any, claimed: any)
	local q = quick[player]
	if not q or typeof(kind) ~= "string" or typeof(claimed) ~= "number" or claimed ~= claimed then return end
	if not QUICK_KINDS[q.stat][kind] then return end
	local t = TapTime.resolve(claimed, workspace:GetServerTimeNow(), q.startAt, q.startAt + QuickTrain.MAX_GAME, q.allowance)
	if t then QuickTrain.addEvent(q.events, t - q.startAt, kind) end
end)

QuickStop.OnServerEvent:Connect(stopQuick)

local function finishQuick(player: Player, q, score: number, played: boolean)
	quick[player] = nil
	if not player.Parent then return end
	QuickEnd:FireClient(player, score)
	if not played or racing(player) then return end -- no taps that counted (or a race began): no gain, no toast
	local h = horseFor(player, q.horseId)
	if not h then return end
	local quality = if CFG.mode == "rides" then TrainingRide.quickScore(score, CFG) else score -- courses own the top scores (D-053)
	local ok, _, msg = Training.train(h, q.stat, quality, os.time())
	Profiles.notify(player, msg, if ok then "stat_" .. q.stat else "heart")
	if ok then
		Progress.record(player, "train", 1)
		Profiles.changed(player)
	end
end

local function tickQuick(serverNow: number)
	for player, q in quick do
		local t = serverNow - q.startAt
		local res = QuickTrain.play(q.stat, q.seed, q.events, t)
		if racing(player) then
			stopQuick(player) -- a race is starting: the game ends, no gain, no toast
		elseif (res.done and t >= (res.endT or 0) + QuickTrain.SETTLE) or t >= QuickTrain.MAX_GAME + QuickTrain.SETTLE then
			local ok, err = pcall(finishQuick, player, q, res.score, QuickTrain.played(q.stat, q.events, res))
			if not ok then
				quick[player] = nil
				warn("[Training] quick train failed: " .. tostring(err))
			end
		end
	end
end

-- Training rides -------------------------------------------------------------------------
-- Ride together: tell everyone in the group how everyone did (stars and ribbons only).
local function shareGroup(group)
	if not group then return end
	local list = {}
	for _, m in group.members do
		local r = group.results[m.UserId]
		table.insert(list, { userId = m.UserId, name = m.DisplayName, done = r ~= nil, stars = r and r.stars,
			ribbon = r and r.ribbon, resting = r and r.resting })
	end
	for _, m in group.members do
		if m.Parent then TrainTogether:FireClient(m, group.course, list, group.id) end
	end
end

-- A rider whose ride ended without a result (stopped, an error, gone): their friend's card
-- shows them resting instead of "still riding" forever.
local function restGroup(player: Player, s)
	local group = s and s.group
	if not group or group.results[player.UserId] then return end
	group.results[player.UserId] = { resting = true }
	shareGroup(group)
end

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
	restGroup(player, s)
end

-- Something went wrong part-way (an error): whatever state the session got to, clear it all,
-- even if the session was already taken off the list, and tell the client.
local function fail(player: Player, s)
	restGroup(player, s)
	if s and sessions[player] == s then sessions[player] = nil end
	pcall(Rides.setTraining, player, false)
	cards[player] = nil
	setTrainingRide(player, false)
	if player.Parent then TrainAbort:FireClient(player, "off", ABORT_TEXT.off) end
end

local function finish(player: Player, s, seconds: number, timedOut: boolean?)
	if not endSession(player, s) then return end
	local result = TrainingRide.run(s.course, s.samples, CFG, seconds, {
		seed = s.seed, lag = TrainingRide.lagAllowance(median(s.pings)),
		bellSeed = s.bellSeed, allowances = s.tracker.allowances, allowance = s.allowance,
	})
	local data = Profiles.get(player)
	local h = data and Profile.horse(data, s.horseId)
	if not result or not h then
		closeCard(player)
		TrainAbort:FireClient(player, "off", ABORT_TEXT.off)
		restGroup(player, s)
		return
	end
	if timedOut and not TrainingRide.timeoutCounts(result, s.tracker) then
		closeCard(player) -- out of time with no real riding: no gain, no ribbon, no job
		TrainAbort:FireClient(player, "again", ABORT_TEXT.again)
		restGroup(player, s)
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
	-- Ghost: the player's best validated ride on this course (kept in its own store). Only
	-- Sprint Lane and Mud Splash: a Gate Break ghost would bolt at another ride's bell, and a
	-- Hill Climb ghost followed another Pip.
	if not result.flagged and GHOST_COURSES[s.course] then
		local okG, errG = pcall(function()
			local kept = TrainingRide.keptSamples(s.course, s.samples, CFG)
			local pts = Ghost.fromSamples(kept)
			if #pts >= 4 then
				local g = Ghost.encode(pts)
				g.score, g.seconds, g.t0, g.coat, g.horse = result.score, result.seconds, kept[1].t, h.coat, h.name
				Ghosts.offer(player, s.course, g)
			end
		end)
		if not okG then warn("[Training] ghost failed: " .. tostring(errG)) end
	end
	if s.group then
		s.group.results[player.UserId] = { stars = result.stars, ribbon = result.ribbon }
		task.defer(shareGroup, s.group)
	end
	Progress.record(player, "train", 1)
	Profiles.changed(player)
	TrainEnd:FireClient(player, {
		course = s.course, horseId = s.horseId, horseName = h.name, groupId = s.group and s.group.id,
		stars = result.stars, ribbon = result.ribbon, newRibbon = newRibbon,
		gained = gain.gained, before = gain.before, after = gain.after, capped = gain.capped, rested = gain.rested,
		potential = if h.stamps and h.stamps.potential then h.potential[course.stat] else nil,
		detail = if s.course == "speed" then { hoops = result.detail.hoops, of = result.detail.of }
			elseif s.course == "accel" then { breaks = result.detail.scored, quick = result.detail.quick }
			elseif s.course == "stamina" then { share = result.detail.share }
			else { mud = result.detail.mud, logs = result.detail.logs, poles = result.detail.poles },
		finished = seconds ~= nil and (s.tracker.finished or s.course == "stamina"), -- Hill Climb ends when Pip finishes
	})
end

-- Ghosts for a ride: your own, and (riding alone) friends here who share theirs (and don't
-- keep visitors out), up to two. Sprint Lane and Mud Splash only.
local function sendGhosts(player: Player, s)
	if not GHOST_COURSES[s.course] then return end
	Ghosts.ensure(player)
	local friends = {}
	if not s.group then
		for _, f in TrainingFriends.friendsOf(player) do
			local fd = Profiles.get(f)
			if fd and fd.settings and fd.settings.shareGhost == true and fd.settings.visits ~= "Nobody" then
				table.insert(friends, f)
				Ghosts.ensure(f)
			end
		end
	end
	local function allReady(): boolean
		if not Ghosts.ready(player) then return false end
		for _, f in friends do
			if f.Parent and not Ghosts.ready(f) then return false end
		end
		return true
	end
	local deadline = os.clock() + 2.5
	while not allReady() and os.clock() < deadline do task.wait(0.2) end
	if sessions[player] ~= s then return end
	local list = {}
	local function add(run, label: string, mine: boolean)
		if run then
			table.insert(list, { label = label, mine = mine, coat = run.coat, v = run.v, hz = run.hz, q = run.q, n = run.n, d = run.d, t0 = run.t0 })
		end
	end
	add(Ghosts.run(player, s.course), "Your best", true)
	local shared = 0
	for _, f in friends do
		local run = f.Parent and Ghosts.run(f, s.course)
		if run and shared < 2 then
			shared += 1
			add(run, f.DisplayName, false)
		end
	end
	if #list > 0 then TrainGhosts:FireClient(player, s.course, list) end
end

-- opts (Ride together): { seed, goAtServer, group, side, course } so riders share one countdown,
-- one Pip and one Mud Splash layout (the group's course key, resolved once).
local function startCourse(player: Player, horseId: any, requested: any, opts: any?)
	local o = opts or {}
	if CFG.mode ~= "rides" then return end
	publishWeek()
	-- Mud Splash: this week's layout by the server's clock, whatever the client asked for (T5)
	local course = o.course or TrainingCourses.resolve(requested, os.time())
	if not course then return end
	local stat = TrainingCourses.courses[course].stat
	if not CFG.courses[stat] then
		Profiles.notify(player, TrainingCourses.courses[course].name .. " is coming soon!", "stat_" .. stat)
		return
	end
	if racing(player) then
		Profiles.notify(player, "Training can wait: your race is coming up!", "heart")
		return
	end
	if quick[player] then return end -- a Quick train game is on
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
	-- riding together: side by side (the practice gate has room for one, so both share it)
	local side = if c.kind == "gate" then 0 else (o.side or 0) * 4.5
	local sx, sz = st.x - st.lookZ * side, st.z + st.lookX * side
	local base = Vector3.new(sx, WorldScene.GROUND_Y + TrainingCourses.groundHeight(sx, sz), sz)
	Rides.travel(player, CFrame.lookAt(base, base + Vector3.new(st.lookX, 0, st.lookZ)))
	if rig.PrimaryPart then rig.PrimaryPart.AssemblyLinearVelocity = Vector3.zero end
	table.insert(history[player], os.clock())
	local now = os.clock()
	local seed = o.seed or rng:NextInteger(1, 2 ^ 30) -- shared: Pip's path (one Pip for a group)
	local bellSeed = rng:NextInteger(1, 2 ^ 30)  -- server only: the bells
	-- the bell goes out and the go comes back: the whole round trip, plus a margin, capped
	-- (measured again when each bell rings)
	local allowance = TrainingRide.bellAllowance(player:GetNetworkPing())
	local s = {
		course = course, horseId = horseId, rig = rig, seed = seed, bellSeed = bellSeed, allowance = allowance,
		goAt = now + CFG.countdownSeconds, goAtServer = workspace:GetServerTimeNow() + CFG.countdownSeconds, group = o.group,
		lastSample = now, samples = {}, base = {}, baseY = nil, pings = { player:GetNetworkPing() },
		outside = 0, tracker = TrainingRide.tracker(course, { seed = bellSeed, allowance = allowance }),
		screen = TrainingRide.screener(function(x: number, z: number): boolean return TrainingCourses.onCourse(course, x, z) end),
		endT = if course == "stamina" then TrainingCourses.idealSeconds("stamina", seed) else nil,
		bellSent = 0,
	}
	if o.goAtServer then
		-- one countdown for the group, however long this rider's horse took to come
		local left = math.max(1, o.goAtServer - workspace:GetServerTimeNow())
		s.goAt, s.goAtServer = now + left, workspace:GetServerTimeNow() + left
	end
	-- Register first, then change groups and attributes: an error from here on is undone by fail().
	sessions[player] = s
	cards[player] = nil
	setTrainingRide(player, true)
	Rides.setTraining(player, true)
	local partners = {}
	for _, m in (o.group and o.group.members) or {} do
		if m ~= player then table.insert(partners, m.UserId) end
	end
	TrainBegin:FireClient(player, course, s.seed, CFG.countdownSeconds, s.goAtServer, partners)
	task.spawn(sendGhosts, player, s)
end

TrainStart.OnServerEvent:Connect(function(player: Player, horseId: any, course: any)
	if pending[player] or sessions[player] or quick[player] then return end
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

-- Ride together -------------------------------------------------------------------------------
local function nearCourses(player: Player): boolean
	local rig = Rides.horseOf(player)
	local root = rig and rig.PrimaryPart
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local pos = (root and root.Position) or (hrp and hrp.Position)
	return pos ~= nil and TrainingCourses.nearTraining(pos.X, pos.Z, 30)
end

local function inviteCtx(from: Player, to: Player, ignoreInvites: boolean?)
	local fd, td = Profiles.get(from), Profiles.get(to)
	local toBusy = racing(to) or sessions[to] ~= nil or pending[to] == true or quick[to] ~= nil
	if not ignoreInvites then toBusy = toBusy or RideTogether.pendingFor(invites, to.UserId) ~= nil end
	return {
		same = from == to, friends = TrainingFriends.areFriends(from, to), toLoaded = td ~= nil,
		fromVisits = fd and fd.settings and fd.settings.visits, toVisits = td and td.settings and td.settings.visits,
		toNear = nearCourses(to), toBusy = toBusy,
	}
end

TrainFriends.OnServerEvent:Connect(function(player: Player)
	if os.clock() - (lastAsk[player] or 0) < 1 then return end
	lastAsk[player] = os.clock()
	local list = {}
	for _, f in TrainingFriends.friendsOf(player) do
		if RideTogether.canInvite(inviteCtx(player, f)) then table.insert(list, { userId = f.UserId, name = f.DisplayName }) end
	end
	local data = Profiles.get(player)
	TrainFriendsList:FireClient(player, list, data and data.settings and data.settings.visits == "Nobody")
end)

TrainInvite.OnServerEvent:Connect(function(player: Player, toId: any, course: any)
	if typeof(toId) ~= "number" or typeof(course) ~= "string" or not CFG.courses[course] or CFG.mode ~= "rides" then return end
	local to = Players:GetPlayerByUserId(toId)
	if not to or racing(player) or sessions[player] or pending[player] or quick[player] then return end
	local ok = RideTogether.canInvite(inviteCtx(player, to))
	if not ok then
		Profiles.notify(player, to.DisplayName .. " can't ride right now. Try again later!", "heart")
		return
	end
	local id, why = RideTogether.invite(invites, player.UserId, to.UserId, course, os.clock())
	if not id then
		Profiles.notify(player, if why == "pending" then "Your invite is on its way. Give it a moment!"
			elseif why == "declined" or why == "full" then to.DisplayName .. " will ride another time. Ride on!"
			else "Give your friends a little while, then invite again!", "heart")
		return
	end
	TrainInvited:FireClient(to, id, player.DisplayName, course)
	Profiles.notify(player, "Invite sent to " .. to.DisplayName .. "!", "stat_" .. course)
end)

local function startGroup(a: Player, b: Player, requested: string)
	publishWeek()
	local course = TrainingCourses.resolve(requested, os.time()) -- one Mud Splash layout for both (T5)
	if not course then return end
	local group = { id = nextGroupId, members = { a, b }, course = course, results = {} }
	nextGroupId += 1
	local seed = rng:NextInteger(1, 2 ^ 30)
	local goAtServer = workspace:GetServerTimeNow() + CFG.countdownSeconds + GROUP_LEAD
	for i, p in group.members do
		task.spawn(function()
			local data = Profiles.get(p)
			if pending[p] or sessions[p] or quick[p] or not data then
				restGroup(p, { group = group })
				return
			end
			pending[p] = true
			local ok, err = pcall(startCourse, p, data.activeHorse, course, { seed = seed, goAtServer = goAtServer, group = group,
				side = if i == 1 then -1 else 1, course = course })
			pending[p] = nil
			if not ok then
				warn("[Training] group start failed: " .. tostring(err))
				fail(p, sessions[p])
			end
			if not sessions[p] then
				group.results[p.UserId] = { resting = true } -- couldn't ride this time; the other rides on
				for _, q in group.members do
					if q ~= p and q.Parent then Profiles.notify(q, p.DisplayName .. " can't ride this time. Ride on!", "heart") end
				end
			end
		end)
	end
end

-- answer: true ("Ride together"), false ("Not now": no new invite from them for a minute) or
-- "busy" (a shop or game panel was open: no cooldown)
TrainInviteReply.OnServerEvent:Connect(function(player: Player, id: any, answer: any)
	local accept = answer == true
	local inv = RideTogether.reply(invites, id, player.UserId, os.clock(), if accept then true elseif answer == "busy" then "busy" else false)
	if not inv then return end
	local from = Players:GetPlayerByUserId(inv.from)
	if not from then return end
	if not accept then
		Profiles.notify(from, player.DisplayName .. (if answer == "busy" then " is busy right now. Try again soon!" else " will ride another time. Ride on!"), "heart")
		return
	end
	-- still friends, nearby and free, both ways
	if not RideTogether.canInvite(inviteCtx(from, player, true)) or not RideTogether.canInvite(inviteCtx(player, from, true)) then
		Profiles.notify(player, "That ride can't start right now. Try again later!", "heart")
		Profiles.notify(from, "That ride can't start right now. Try again later!", "heart")
		return
	end
	Profiles.notify(from, player.DisplayName .. " said yes! Off to the start!", "stat_" .. inv.course)
	startGroup(from, player, inv.course)
end)

local function tickInvites()
	for _, inv in RideTogether.sweep(invites, os.clock()) do
		local to = Players:GetPlayerByUserId(inv.to)
		local from = Players:GetPlayerByUserId(inv.from)
		if to then TrainInviteGone:FireClient(to, inv.id) end
		if from and to then Profiles.notify(from, to.DisplayName .. " will ride another time. Ride on!", "heart") end
	end
end

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
		restGroup(player, s)
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
		for _, e in s.tracker.events do
			-- only what the screen needs (never a bell time)
			TrainCue:FireClient(player, e.kind, { breakNo = e.breakNo, attempt = e.attempt, rerun = e.rerun, score = e.score, last = e.last })
		end
		table.clear(s.tracker.events)
		if s.tracker.finished then return finish(player, s, s.tracker.finishT or t) end
	elseif s.course == "stamina" then
		if #s.samples % CFG.sampleHz == 0 then table.insert(s.pings, player:GetNetworkPing()) end
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
		tr.allowances[tr.arms] = TrainingRide.bellAllowance(player:GetNetworkPing()) -- this bell's latency
		TrainCue:FireClient(player, "bell", { breakNo = tr.breakNo })
	end
end

local nextSlowTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now >= nextSlowTick then
		nextSlowTick = now + 0.2
		tickQuick(workspace:GetServerTimeNow())
		tickInvites()
		publishWeek()
	end
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
	if sessions[player] then restGroup(player, sessions[player]) end
	sessions[player], history[player], pending[player], cards[player] = nil, nil, nil, nil
	quick[player], lastAsk[player] = nil, nil
	for _, inv in invites.invites do
		if inv.from == player.UserId then
			local to = Players:GetPlayerByUserId(inv.to)
			if to then TrainInviteGone:FireClient(to, inv.id) end
		end
	end
	RideTogether.forget(invites, player.UserId)
end)
