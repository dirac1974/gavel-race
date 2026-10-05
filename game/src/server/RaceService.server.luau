--!nonstrict
-- RaceService: the races (D-024 to D-036).
-- Two courses, the dirt oval and the turf course inside it, each run their own race, so two
-- can be on at once (D-036). Each course shows its next race as a card (league, distance,
-- surface, weather, riders in line) on the Race Board and in the RACE! picker; players join a
-- card with the horse they choose, and bots fill the empty lanes after the fill time.
-- Each race: the pace slider from the gate to the final turn (two checkpoints), the Final
-- Burst as the field enters the homestretch (one tap on a big meter, counts double), then the
-- slider again for the stretch drive (D-026, D-031). Race length follows the distance.
-- All scoring and the finish draw happen here; clients only send tap times. Race events go
-- to everyone (spectators watch both courses) with the course id as the LAST argument, so
-- each client follows the race it rides in, or the newest one when watching.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceMath = require(Shared:WaitForChild("RaceMath"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ThemePack = require(Shared:WaitForChild("ThemePack"))
local BurstMeter = require(Shared:WaitForChild("BurstMeter"))
local PaceMeter = require(Shared:WaitForChild("PaceMeter"))
local TapTime = require(Shared:WaitForChild("TapTime"))
local Integrity = require(Shared:WaitForChild("Integrity"))
local RaceSession = require(Shared:WaitForChild("RaceSession"))
local RaceRating = require(Shared:WaitForChild("RaceRating"))
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local RaceShape = require(Shared:WaitForChild("RaceShape"))
local Profile = require(Shared:WaitForChild("Profile"))
local Horse = require(Shared:WaitForChild("Horse"))
local TrackScene = require(script.Parent:WaitForChild("TrackScene"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Rides = require(script.Parent:WaitForChild("Rides"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Leagues = require(Shared:WaitForChild("Leagues"))
local Style = require(Shared:WaitForChild("Style"))

local DEFAULT_LEAGUE = "Rookie" -- an open card (nobody in line yet) shows this until the first rider sets it
local COUNTDOWN = GameConfig.gateCountdownSeconds -- "3, 2, 1" on every screen (D-055)
local LATENCY_GRACE = 0.35 -- wait after a segment closes for late packets
local COURSE_ORDER = { "dirt", "turf" }
local SURFACE = { dirt = "Dirt", turf = "Turf" }
local WEATHERS = { "Sunny", "Sunny", "Rain", "Wind" }
local DISTANCES = { "Sprint", "Mile", "Classic", "Marathon" }

local remotes = Instance.new("Folder")
remotes.Name = "RaceRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local LobbyStatus = makeRemote("LobbyStatus")     -- server -> queued: seconds until start, course
local RaceStarted = makeRemote("RaceStarted")     -- server -> all: league, lanes, start, conditions, result time, burst open, course
local PaceSchedule = makeRemote("PaceSchedule")   -- server -> all: the slider's passes, course
local PaceResult = makeRemote("PaceResult")       -- server -> one: checkpoint, score, label, course
local BurstOpened = makeRemote("BurstOpened")     -- server -> all: seg, open, close, meter spec, name, course
local TapResult = makeRemote("TapResult")         -- server -> one: seg, burst score, label, course
local LiveChances = makeRemote("LiveChances")     -- server -> all: seg, chances, course
local RaceFinished = makeRemote("RaceFinished")   -- server -> all: results, course
local IntegrityNote = makeRemote("IntegrityNote") -- server -> one: private note (D-022 flag 2)
local RideReport = makeRemote("RideReport")       -- server -> one: stars, places gained by riding, place, course (D-033)
local Dismount = makeRemote("Dismount")           -- client -> server: rider pressed Done after results or replay
-- On-screen gaps, several times a second; dropping one is harmless, so unreliable.
local RaceOffsets = Instance.new("UnreliableRemoteEvent")
RaceOffsets.Name = "RaceOffsets"                  -- server -> all: feet ahead of the pace per lane (never the luck), course
RaceOffsets.Parent = remotes
local BurstSparkle = makeRemote("BurstSparkle")   -- server -> all: lane ids with a Great+ burst, course
local JoinRace = makeRemote("JoinRace")           -- client -> server: want (bool), course id?, horse id?
local QueueStatus = makeRemote("QueueStatus")     -- server -> one: in line?, riders in line, seconds (or nil), course
local RaceAborted = makeRemote("RaceAborted")     -- server -> all: the race stopped with an error, course
local RaceCards = makeRemote("RaceCards")         -- server -> all: the next race on each course (Race Board)
local PaceTap = makeRemote("PaceTap")             -- client -> server: claimed server time
local BurstTap = makeRemote("BurstTap")           -- client -> server: seg, claimed server time
-- After the remotes exist: FanService waits for RaceRemotes when it loads.
local FanService = require(script.Parent:WaitForChild("FanService"))
-- Fan code must never stop a race: a failure there is logged and the race carries on.
local function fans(fn: string, ...)
	local ok, err = pcall(FanService[fn], ...)
	if not ok then warn("[RaceService] FanService." .. fn .. " failed: " .. tostring(err)) end
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Courses -------------------------------------------------------------------------
-- course = { id, cfg, scene, surface, queue, fillDeadline, current, card, charged, nextDistance }
local courses: { [string]: any } = {}
for _, id in COURSE_ORDER do
	local cfg = TrackLayout.courses[id]
	courses[id] = {
		id = id, cfg = cfg, scene = TrackScene.course(id, cfg), surface = SURFACE[id],
		queue = {}, fillDeadline = nil, current = nil, card = nil, charged = {}, nextDistance = if id == "dirt" then 1 else 2,
	}
end

local trackers: { [number]: any } = {}
local inLine: { [Player]: any } = {}   -- player -> course whose line they're in
local riding: { [Player]: any } = {}   -- player -> course they're racing on
local chosen: { [Player]: string } = {} -- player -> horse id picked for the race

local function setupPlayer(player: Player)
	trackers[player.UserId] = Integrity.new()
end
Players.PlayerAdded:Connect(setupPlayer)
for _, p in Players:GetPlayers() do setupPlayer(p) end

-- A card is open (league nil) until its first rider joins: their horse's league and the race
-- kind they picked (regular, Cup or Practice) set it (D-046).
local function pickDistance(slot: number, leagueName: string): string
	local league = GameConfig.leagues[leagueName] or GameConfig.leagues[DEFAULT_LEAGUE]
	local distances = league.distances or DISTANCES
	return distances[((slot - 1) % #distances) + 1]
end

local function newCard(c)
	local slot = c.nextDistance
	c.nextDistance += 1
	c.card = { league = nil, cup = false, practice = false, slot = slot, distance = pickDistance(slot, DEFAULT_LEAGUE),
		surface = c.surface, weather = WEATHERS[math.random(1, #WEATHERS)] }
end

local function claimCard(c, leagueName: string, kind: string)
	c.card.league = leagueName
	c.card.cup = kind == "cup"
	c.card.practice = kind == "practice"
	c.card.distance = pickDistance(c.card.slot, leagueName) -- same slot, so Rookie's Sprint stays a Sprint
end

local function openCard(c)
	if c.card then c.card.league, c.card.cup, c.card.practice = nil, false, false end
end

-- A horse's strength for the league ceiling: its best base Rating over every condition,
-- without care or bond (so caring for a horse never closes races to it).
local function bestRating(h): number
	local best = 0
	local league = GameConfig.leagues[h.league] or GameConfig.leagues[DEFAULT_LEAGUE]
	for _, d in league.distances or DISTANCES do
		for _, s in { "Dirt", "Turf" } do
			for w in RaceRating.WEATHER_SHIFT do
				best = math.max(best, RaceRating.rating(h.stats, { distance = d, surface = s, weather = w }, 0, 0, nil, 0))
			end
		end
	end
	return best
end

local function cardsView()
	local out = {}
	for _, id in COURSE_ORDER do
		local c = courses[id]
		local card = c.card or {}
		table.insert(out, {
			course = id,
			league = card.league,
			open = card.league == nil,
			cup = card.cup,
			practice = card.practice,
			distance = card.distance,
			surface = card.surface,
			weather = card.weather,
			riders = #c.queue,
			lanes = GameConfig.lanes,
			seconds = if c.fillDeadline then math.max(0, math.ceil(c.fillDeadline - os.clock())) else nil,
			racing = c.current ~= nil,
		})
	end
	return out
end

-- The Race Board on Fair Street shows the same cards.
local function updateBoard(view)
	local world = workspace:FindFirstChild("World")
	local board = world and world:FindFirstChild("Places") and world.Places:FindFirstChild("RaceBoard")
	local info = board and board:FindFirstChild("Info", true)
	if not info then return end
	local lines = {}
	for _, card in view do
		local status = if card.racing then "racing now" elseif card.seconds then string.format("starts in %ds", card.seconds)
			elseif card.riders > 0 then "filling" else "open"
		local kind = if card.cup then "🏆 Cup" elseif card.practice then "Practice" else (card.league or "Open")
		table.insert(lines, string.format("%s %s · %s %s · %d/%d · %s", if card.course == "dirt" then "🟤" else "🟢",
			card.surface or "", if card.cup or card.practice then (card.league or "") .. " " .. kind else kind,
			card.distance or "", card.riders, card.lanes, status))
	end
	info.Text = table.concat(lines, "\n")
end

local function publishCards()
	local view = cardsView()
	RaceCards:FireAllClients(view)
	updateBoard(view)
end

local function queueStatus(c)
	local seconds = if c.fillDeadline then math.max(0, math.ceil(c.fillDeadline - os.clock())) else nil
	for _, p in c.queue do QueueStatus:FireClient(p, true, #c.queue, seconds, c.id) end
end

local function leaveLine(player: Player)
	local c = inLine[player]
	if not c then return end
	inLine[player] = nil
	player:SetAttribute("InLine", nil)
	local i = table.find(c.queue, player)
	if i then table.remove(c.queue, i) end
	if #c.queue == 0 then
		c.fillDeadline = nil
		openCard(c) -- nobody waiting for the next race: its card is open again
	end
	QueueStatus:FireClient(player, false, #c.queue, nil, c.id)
	queueStatus(c)
end

-- Tap handlers ----------------------------------------------------------------------
-- course.current = { session, seg, kind ("pace" | "burst" | nil), open, close, taps, allowances, maxTaps }

-- Latency is snapshotted per checkpoint so a lag spike can't widen it (D-021).
local function snapshotAllowances(players: { Player }): { [number]: number }
	local out = {}
	for _, p in players do
		out[p.UserId] = TapTime.rewindAllowance(p:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	end
	return out
end

local function resolveTap(player: Player, claimed: any, kind: string)
	local c = riding[player]
	local cur = c and c.current
	if not cur or cur.kind ~= kind or typeof(claimed) ~= "number" then return nil, nil end
	local allowance = cur.allowances[player.UserId]
		or TapTime.rewindAllowance(player:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	return TapTime.resolve(claimed, now(), cur.open, cur.close, allowance), cur
end

PaceTap.OnServerEvent:Connect(function(player: Player, claimed: any)
	local t, cur = resolveTap(player, claimed, "pace")
	if not t then return end
	local list = cur.taps[player.UserId]
	if not list then
		list = {}
		cur.taps[player.UserId] = list
	end
	if #list < cur.maxTaps then table.insert(list, t) end -- extra taps would score 0 anyway
end)

BurstTap.OnServerEvent:Connect(function(player: Player, seg: any, claimed: any)
	local c = riding[player]
	if not c or not c.current or seg ~= c.current.seg then return end
	local t, cur = resolveTap(player, claimed, "burst")
	if not t then return end
	local score = cur.session:submitBurst(tostring(player.UserId), seg, t - cur.open)
	if score then
		TapResult:FireClient(player, seg, score, GameConfig.labelFor(score), c.id)
	end
end)

-- Joining ----------------------------------------------------------------------------
-- Can this player ride? Their chosen horse if it's stalled, else the active one.
-- Energy cost of a card for a horse: Practice and Rookie races are free (D-015).
local function costOf(card, h): number
	if card.practice or GameConfig.energy.freeLeagues[card.league or h.league] then return 0 end
	return GameConfig.energy.costPerCashRace
end

-- Can this player ride on this card? Their chosen horse if it's stalled, else the active one.
-- `card` is the course's card with the league and kind it would have once they join.
local function rideable(player: Player, horseId: string?, card)
	local data = Profiles.get(player)
	if not data then return nil, "Your stable is still loading" end
	local h = nil
	if horseId and Profile.isStalled(data, horseId) then h = Profile.horse(data, horseId) end
	h = h or Profile.activeHorse(data)
	if not h then return nil, "Pick your first horse to race" end
	if card then
		local ok, why = Leagues.canEnter(h, card, bestRating(h))
		if not ok then return nil, why end
		local cost = costOf(card, h)
		if cost > 0 and Horse.syncEnergy(h, os.time(), GameConfig.energy) < cost then
			return nil, h.name .. " is resting. Try a Practice race, or care for your horse while it naps!"
		end
	end
	return h, nil
end

-- Each horse in the owner's view: its Cup status, for the picker and the board.
Profiles.addDecorator(function(data, view)
	for i, hv in view.horses or {} do
		local h = data.horses[i]
		if h then
			local best = bestRating(h)
			hv.cupOpen = Leagues.cupOpen(h, best)
			hv.pointsToCup = Leagues.pointsToCup(h)
			hv.overCeiling = Leagues.overCeiling(h, best)
		end
	end
	view.hallOfFame = data.hallOfFame or {}
end)

-- With no course picked: join riders already waiting, else a free course, else the shorter line.
local function bestCourse()
	local best, bestScore = nil, -math.huge
	for _, id in COURSE_ORDER do
		local c = courses[id]
		if #c.queue < GameConfig.lanes then
			local score = #c.queue * 10 + (if c.current then -50 else 0) + (if c.fillDeadline then 5 else 0)
			if score > bestScore then best, bestScore = c, score end
		end
	end
	return best
end

local lastJoin: { [Player]: number } = {}
JoinRace.OnServerEvent:Connect(function(player: Player, want: any, courseId: any, horseId: any, kind: any)
	if os.clock() - (lastJoin[player] or 0) < 0.5 then return end
	lastJoin[player] = os.clock()
	if want == false then
		leaveLine(player)
		publishCards()
		return
	end
	if riding[player] then return end
	local c = if typeof(courseId) == "string" and courses[courseId] then courses[courseId] else bestCourse()
	if not c then
		Profiles.notify(player, "Both races are full. Try again after these races!", "flag_ready")
		return
	end
	kind = if kind == "cup" or kind == "practice" then kind else "race"
	-- An open card takes this rider's league and kind; a claimed card must match.
	local wanted = c.card
	local alone = #c.queue == 0 or (#c.queue == 1 and c.queue[1] == player)
	local claiming = alone and (c.card.league == nil or inLine[player] == c)
	if claiming then
		local data = Profiles.get(player)
		local pick = data and ((typeof(horseId) == "string" and Profile.isStalled(data, horseId) and Profile.horse(data, horseId)) or Profile.activeHorse(data))
		wanted = table.clone(c.card)
		wanted.league = if pick then pick.league else DEFAULT_LEAGUE
		wanted.cup, wanted.practice = kind == "cup", kind == "practice"
	end
	local h, why = rideable(player, if typeof(horseId) == "string" then horseId else nil, wanted)
	if not h then
		Profiles.notify(player, why, "zzz_resting")
		if not inLine[player] then QueueStatus:FireClient(player, false, 0, nil, c.id) end
		return
	end
	if inLine[player] == c then
		chosen[player] = h.id -- changing horse (and, alone in line, the kind)
		if claiming then
			claimCard(c, wanted.league, kind)
			publishCards()
		end
		return
	end
	if #c.queue >= GameConfig.lanes then
		Profiles.notify(player, "That race is full. Try the other course!", "flag_ready")
		return
	end
	leaveLine(player)
	if claiming then claimCard(c, wanted.league, kind) end
	table.insert(c.queue, player)
	inLine[player] = c
	player:SetAttribute("InLine", true)
	chosen[player] = h.id
	if not c.fillDeadline and not c.current then c.fillDeadline = os.clock() + GameConfig.lobbyFillSeconds end
	queueStatus(c)
	publishCards()
end)

Dismount.OnServerEvent:Connect(function(player: Player)
	local c = riding[player]
	if c and c.current then return end -- not during your race
	TrackScene.dismount(player.Character)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local c = riding[player]
	if c and c.current and c.current.seg then
		c.current.session:dropSegment(tostring(player.UserId), c.current.seg)
	end
	leaveLine(player)
	riding[player], chosen[player], lastJoin[player] = nil, nil, nil
	task.defer(function()
		trackers[player.UserId] = nil -- session-only until saved trackers (STATUS backlog)
	end)
end)

-- Integrity (D-022, D-026) -------------------------------------------------------
local function applyIntegrity(session, players: { Player })
	local cfg = GameConfig.integrity
	for _, p in players do
		local tr = trackers[p.UserId]
		if tr then
			local action = Integrity.action(Integrity.activeStrikes(tr, today(), cfg), cfg)
			if action == "warn" or action == "review" then
				-- Edge removed while a check is pending; the pause after review needs tooling (not built).
				session:setAverageOnly(tostring(p.UserId), true)
			end
		end
	end
end

local function recordIntegrity(players: { Player }, errors: { [number]: { number } }, matched: { [number]: number })
	local cfg = GameConfig.integrity
	for _, p in players do
		local tr = trackers[p.UserId]
		if tr then
			Integrity.addRace(tr, errors[p.UserId] or {}, matched[p.UserId] or 0, today())
			local spread = Integrity.spread(tr)
			if Integrity.check(tr, today(), cfg) then
				local strikes = Integrity.activeStrikes(tr, today(), cfg)
				local action = Integrity.action(strikes, cfg)
				print(string.format("[Integrity] %s (%d): strike %d, timing spread %.1f ms, action %s",
					p.Name, p.UserId, strikes, spread * 1000, action))
				if action == "warn" then
					IntegrityNote:FireClient(p, "Your taps looked automatic, so they count as practice for now. "
						.. "Auto-clickers and scripts aren't allowed in cash races. If that wasn't you, tap Ask for a check.")
				end
			end
		end
	end
end

-- A race ------------------------------------------------------------------------------
local function lanesSummary(session)
	local out = {}
	for i, lane in session.lanes do
		out[i] = { id = lane.id, name = lane.name, isBot = lane.isBot, chance = session.q[i], purse = session.purses[i] }
	end
	return out
end

local function waitUntil(t: number)
	task.wait(math.max(0, t - now()))
end

local function runRace(c, players: { Player })
	local rng = Random.new()
	local card = table.clone(c.card)
	if not card.league then -- shouldn't happen (the first rider claims the card); take theirs
		local data = players[1] and Profiles.get(players[1])
		local h0 = data and (Profile.horse(data, chosen[players[1]] or "") or Profile.activeHorse(data))
		card.league = if h0 then h0.league else DEFAULT_LEAGUE
	end
	local leagueName = card.league
	local league = GameConfig.leagues[leagueName]
	local cond = { distance = card.distance, surface = card.surface, weather = card.weather }
	local humans = {}
	local horseOf: { [number]: string } = {}
	local coatOf: { [string]: string } = {}
	local riders = {}
	for _, p in players do
		local h = rideable(p, chosen[p], card)
		if h and h.league ~= leagueName then h = nil end -- cash fields never mix leagues
		local cost = if h then costOf(card, h) else 0
		local data = Profiles.get(p)
		if h and data and not riding[p] and (cost == 0 or Horse.spendEnergy(h, cost, os.time(), GameConfig.energy)) then
			local rating = Horse.rating(h, cond, os.time(), RaceRating)
			table.insert(humans, { id = tostring(p.UserId), name = h.name, rating = rating, isBot = false })
			horseOf[p.UserId] = h.id
			coatOf[tostring(p.UserId)] = h.coat
			table.insert(riders, p)
			if cost > 0 then
				c.charged[p] = h.id
				Profiles.changed(p)
			end
		end
	end
	players = riders
	if #players == 0 then
		if #c.queue == 0 then openCard(c) end
		return
	end
	newCard(c) -- the board shows the next race on this course while this one runs
	local lanes = RaceSession.fillWithBots(humans, GameConfig.lanes, GameConfig, ThemePack, rng)
	local coats = {}
	for i, lane in lanes do coats[i] = coatOf[lane.id] end -- bots keep the default coats
	local session = RaceSession.new({
		deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape },
		config = GameConfig,
		leagueName = leagueName,
		lanes = lanes,
		rng = rng,
	})
	for i in session.purses do
		if card.practice then
			session.purses[i] = 0
		elseif card.cup then
			session.purses[i] = Leagues.CUP_PURSE * league.B
		end
	end
	applyIntegrity(session, players)

	-- Timeline (D-026, D-027, D-031): gate -> pace (2 checkpoints) -> into the homestretch:
	-- "FINAL BURST" -> burst -> stretch drive (pace, 1 checkpoint) -> the line.
	local cfg = c.cfg
	local plan = TrackLayout.plan(cfg, TrackLayout.distances[cond.distance])
	local speed = GameConfig.raceSpeedStudsPerSecond
	local tStart = now() + COUNTDOWN
	local tFinish = tStart + plan.lengths[1] / speed
	local tTop = tFinish - cfg.finishFromTop / speed -- the field enters the homestretch
	local burstOpen = tTop + GameConfig.burstAfterTurnSeconds
	local burstClose = burstOpen + league.windowSeconds
	local preEnd = burstOpen - GameConfig.burstLeadSeconds
	local postStart = burstClose + GameConfig.stretchGapSeconds
	local postEnd = tFinish - GameConfig.finishMarginSeconds
	-- Stop scheduling a pass early so the last one in each span ends on time.
	local longestPass = league.sweepSeconds / 2 * (1 + GameConfig.pace.speedDrift)
	local mid = tStart + (preEnd - tStart) / 2
	local passes = session:paceSchedule(
		{ { tStart, preEnd - tStart - longestPass }, { postStart, postEnd - postStart - longestPass } },
		{ { tStart, mid }, { mid, preEnd }, { postStart, postEnd } })
	local resultAt = postEnd + LATENCY_GRACE
	-- Luck shows from the field entering the final far turn until the last tap (D-033).
	local r1 = TrackLayout.laneRadius(cfg, 1)
	local tFar = tFinish - (cfg.finishFromTop + math.pi * r1) / speed

	c.scene:dismountAll() -- anyone still sitting from this course's last race
	c.scene:build(plan, coats) -- rebuilt each race: the gate moves with the distance, riders' own coats
	local title = if card.cup then leagueName .. " Cup" elseif card.practice then "Practice" else leagueName
	RaceStarted:FireAllClients(title, lanesSummary(session), tStart, cond, resultAt, burstOpen, c.id)
	PaceSchedule:FireAllClients(passes, c.id)
	fans("start", c.id, session, players, tStart, tFinish) -- cheers and Clap Along (D-019, D-020)
	task.delay(math.max(0, tStart - now()), function() c.scene:openGate() end) -- and they're off
	local isBot = {}
	for i, lane in session.lanes do -- racing players ride their own horse as the jockey
		isBot[i] = lane.isBot
		if not lane.isBot then
			local p = Players:GetPlayerByUserId(tonumber(lane.id))
			if p then
				riding[p] = c
				p:SetAttribute("Racing", true)
				Rides.dismount(p) -- off your own horse before the race horse
				TrackScene.dismount(p.Character) -- and off the other course's horse after its race
				c.scene:seatRider(i, p.Character)
			end
		end
	end
	c.scene:addJockeys(isBot) -- Roblox-style jockeys on the bot horses

	local preLast, postLast = tStart, postStart
	for _, p in passes do
		if p.t0 < burstOpen then preLast = math.max(preLast, p.t1) else postLast = math.max(postLast, p.t1) end
	end
	local cur = {
		session = session, seg = 1, kind = "pace", open = tStart, close = preLast,
		taps = {}, allowances = snapshotAllowances(players), maxTaps = #passes * 2 + 10,
	}
	c.current = cur
	publishCards()
	-- Live chances shown on screen: closed segments, refreshed each second in the stretch drive.
	local shownLive = table.clone(session.live)
	local racing = true
	task.spawn(function()
		local period = 1 / GameConfig.offsetsPerSecond
		while racing and (c.current == cur or c.current == nil) do
			local w = RaceShape.blendWeight(now(), tFar, postEnd, GameConfig.raceShape.blendPower)
			RaceOffsets:FireAllClients(session:displayOffsets(shownLive, w, GameConfig.raceShape), c.id)
			task.wait(period)
		end
	end)
	local function previewStretch(seg: number)
		-- Riders' provisional stretch-drive scores over the passes finished so far.
		local done = {}
		for _, p in session:pacePasses(seg) do
			if p.t1 <= now() then table.insert(done, p) end
		end
		if #done == 0 then return end
		local partial = {}
		for i, lane in session.lanes do
			if not lane.isBot then
				partial[i] = (PaceMeter.score(done, cur.taps[tonumber(lane.id)] or {}, GameConfig.pace.bounceSeconds))
			end
		end
		shownLive = session:previewLive(seg, partial)
		LiveChances:FireAllClients(seg, shownLive, c.id)
	end

	local errors: { [number]: { number } } = {}
	local matched: { [number]: number } = {}
	local greatTaps: { [number]: number } = {}  -- Great or Perfect pace taps, for Stable Board jobs
	local greatBurst: { [number]: boolean } = {} -- tapped a Great or Perfect Final Burst
	for seg, kind in GameConfig.segments do
		cur.seg = seg
		if kind == "pace" then
			if seg > 1 and GameConfig.segments[seg - 1] == "burst" then
				cur.kind, cur.open, cur.close = "pace", postStart, postLast -- the stretch drive
			end
			local segPasses = session:pacePasses(seg)
			local lastEnd = if #segPasses > 0 then segPasses[#segPasses].t1 else select(2, session:paceRange(seg))
			if seg > 1 and GameConfig.segments[seg - 1] == "burst" then
				-- The stretch drive stays live: taps move the horse while it runs (D-033).
				while now() < lastEnd do
					task.wait(GameConfig.stretchPreviewSeconds)
					previewStretch(seg)
				end
			end
			waitUntil(lastEnd + LATENCY_GRACE)
			cur.allowances = snapshotAllowances(players)
			for _, p in players do
				local res = session:scorePace(tostring(p.UserId), seg, cur.taps[p.UserId] or {})
				if res then
					greatTaps[p.UserId] = (greatTaps[p.UserId] or 0) + PaceMeter.countAtLeast(segPasses, cur.taps[p.UserId] or {}, 80, GameConfig.pace.bounceSeconds)
					local list = errors[p.UserId] or {}
					for _, e in res.errors do table.insert(list, e) end
					errors[p.UserId] = list
					matched[p.UserId] = (matched[p.UserId] or 0) + res.matched
					PaceResult:FireClient(p, seg, res.score, GameConfig.labelFor(res.score), c.id)
				end
			end
		else
			waitUntil(burstOpen)
			cur.kind, cur.open, cur.close = "burst", burstOpen, burstClose
			cur.allowances = snapshotAllowances(players)
			BurstOpened:FireAllClients(seg, burstOpen, burstClose, session:burstSpec(), ThemePack.words.burst, c.id)
			waitUntil(burstClose + LATENCY_GRACE)
			cur.kind = "pace" -- taps before the stretch drive opens are outside its window and dropped
			cur.open, cur.close = postStart, postLast
			local great = {}
			for _, p in players do
				local i = session:laneIndex(tostring(p.UserId))
				local s = i and session.lanes[i].scores[seg]
				if s and s >= 80 then
					table.insert(great, tostring(p.UserId))
					greatBurst[p.UserId] = true
				end
			end
			if #great > 0 then BurstSparkle:FireAllClients(great, c.id) end
		end
		fans("beforeClose", c.id, seg) -- the crowd's tiny boost joins this segment's close
		shownLive = session:closeSegment(seg)
		LiveChances:FireAllClients(seg, shownLive, c.id)
	end
	cur.seg = nil

	local result = session:finish() -- by now the order on screen is this order (D-033)
	task.delay(GameConfig.runInSeconds + 2, function() racing = false end)
	local summary = {}
	for _, prize in result.prizes do
		local laneIdx = session:laneIndex(prize.id)
		local lane = session.lanes[laneIdx]
		-- Practice pays nothing and earns no points; a Cup win pays 3B (D-046).
		local cash, points = prize.cash, prize.leaguePoints
		if card.practice then
			cash, points = 0, 0 -- the Cup winner's purse is already the locked session purse
		end
		table.insert(summary, { name = lane.name, place = prize.place, cash = cash, isBot = prize.isBot, id = prize.id, lane = laneIdx })
		if not prize.isBot then
			local player = Players:GetPlayerByUserId(tonumber(prize.id))
			local data = player and Profiles.get(player)
			if data and horseOf[player.UserId] then
				if not card.practice then
					Profile.recordRace(data, horseOf[player.UserId], prize.place, cash, points, os.time())
				end
				if card.cup and prize.place == 1 then
					local h = Profile.horse(data, horseOf[player.UserId])
					local nxt = h and Leagues.promote(h)
					if nxt then
						Style.earn(data, Style.EARN_PROMOTION) -- a milestone gift (D-050)
						task.delay(GameConfig.runInSeconds + 1, function()
							Profiles.notify(player, string.format("🏆 %s won the %s Cup and moves up to %s!", h.name, leagueName, nxt), "trophy")
						end)
						Progress.record(player, "promote", 1)
					end
				end
				Profiles.changed(player)
			end
		end
	end
	RaceFinished:FireAllClients(summary, c.id)
	fans("finish", c.id, result.order[1])
	table.clear(c.charged) -- the race counted
	-- Your ride: stars from your score, and places your riding gained versus riding at the race
	-- average (same luck, everything else the same). Only gains are shown to the rider.
	local S = session:scoresSoFar()
	local placeOf = {}
	for place, laneIdx in result.order do placeOf[laneIdx] = place end
	for _, p in players do
		local i = session:laneIndex(tostring(p.UserId))
		if i then
			local stars = if S[i] >= 85 then 3 elseif S[i] >= 65 then 2 elseif S[i] >= 40 then 1 else 0
			RideReport:FireClient(p, stars, session:ridingGain(i), placeOf[i], c.id)
		end
	end
	recordIntegrity(players, errors, matched)
	-- Stable Board jobs count effort, never wins (D-043).
	for _, p in players do
		Progress.record(p, "race", 1)
		Progress.record(p, "great_tap", greatTaps[p.UserId] or 0)
		if greatBurst[p.UserId] then Progress.record(p, "burst_great", 1) end
	end
	-- Riders stay on their horse for the results and replay; they press Done to get off.
	task.delay(GameConfig.dismountTimeoutSeconds, function()
		if not c.current then c.scene:dismountAll() end
	end)
	for _, p in players do
		p:SetAttribute("Racing", nil)
		p:SetAttribute("LastRaceEnd", os.time()) -- no Diamond prompts for a while after (D-050)
		if riding[p] == c then riding[p] = nil end
	end
	c.current = nil
end

-- One loop per course ---------------------------------------------------------------
local function courseLoop(c)
	newCard(c)
	publishCards()
	while true do
		-- Wait for someone to join this course's line, then give others the fill time to join too.
		while #c.queue == 0 do task.wait(0.5) end
		c.fillDeadline = c.fillDeadline or (os.clock() + GameConfig.lobbyFillSeconds)
		while #c.queue > 0 and os.clock() < (c.fillDeadline or 0) and #c.queue < GameConfig.lanes do
			for _, p in c.queue do LobbyStatus:FireClient(p, math.ceil((c.fillDeadline or 0) - os.clock()), c.id) end
			queueStatus(c)
			task.wait(1)
		end
		-- The first race after a server start waits (up to 10 s more) for the horse models to
		-- load, so no horse runs without its running legs (D-055). Riders stay in line meanwhile.
		local models = ReplicatedStorage:FindFirstChild("RaceModels")
		local waited = 0
		while models and not models:GetAttribute("Loaded") and waited < 10 do
			waited += task.wait(0.25)
		end
		local racers = {}
		while #c.queue > 0 and #racers < GameConfig.lanes do
			local p = table.remove(c.queue, 1)
			inLine[p] = nil
			p:SetAttribute("InLine", nil)
			table.insert(racers, p)
		end
		c.fillDeadline = nil
		for _, p in racers do QueueStatus:FireClient(p, false, #c.queue, nil, c.id) end
		if #racers > 0 then
			local ok, err = pcall(runRace, c, racers)
			if not ok then
				warn(string.format("Race on %s failed: %s", c.id, tostring(err)))
				c.current = nil
				c.scene:dismountAll()
				fans("abort", c.id)
				RaceAborted:FireAllClients(c.id)
				for p, horseId in c.charged do -- give back the Energy for a race that didn't count
					local data = Profiles.get(p)
					local h = data and Profile.horse(data, horseId)
					if h then
						Horse.addEnergy(h, GameConfig.energy.costPerCashRace, os.time(), GameConfig.energy)
						Profiles.changed(p)
					end
				end
				table.clear(c.charged)
				if #c.queue == 0 then openCard(c) end
				for _, p in racers do
					p:SetAttribute("Racing", nil)
					if riding[p] == c then riding[p] = nil end
				end
			end
		end
		publishCards()
		task.wait(5) -- results screen
		if #c.queue > 0 then c.fillDeadline = os.clock() + GameConfig.lobbyFillSeconds end
		queueStatus(c)
	end
end

-- Lobby scenes: a gate and horses on both courses before the first races.
task.delay(3, function()
	for _, id in COURSE_ORDER do
		local c = courses[id]
		if not c.current then c.scene:build(TrackLayout.plan(c.cfg, TrackLayout.distances.Sprint)) end
	end
end)

-- Cards tick down once a second for the board and the picker.
task.spawn(function()
	while true do
		task.wait(1)
		publishCards()
	end
end)

for _, id in COURSE_ORDER do
	task.spawn(courseLoop, courses[id])
end
