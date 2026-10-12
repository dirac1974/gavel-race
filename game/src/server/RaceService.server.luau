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
local Trip = require(Shared:WaitForChild("Trip"))
local TripBaseline = require(Shared:WaitForChild("TripBaseline"))
local ResultsText = require(Shared:WaitForChild("ResultsText"))
local PacePreview = require(Shared:WaitForChild("PacePreview")) -- (D-067) when the post-lock preview runs
local PREVIEW_AFTER_LOCK = GameConfig.pacePreviewAfterLock
local TapPreview = require(Shared:WaitForChild("TapPreview")) -- (D-071) the draw-only pre-lock preview
local Profile = require(Shared:WaitForChild("Profile"))
local Horse = require(Shared:WaitForChild("Horse"))
local TrackScene = require(script.Parent:WaitForChild("TrackScene"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Rides = require(script.Parent:WaitForChild("Rides"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Leagues = require(Shared:WaitForChild("Leagues"))
local Career = require(Shared:WaitForChild("Career"))
local Style = require(Shared:WaitForChild("Style"))
local Spa = require(Shared:WaitForChild("Spa"))
local RaceQueues = require(Shared:WaitForChild("RaceQueues"))
local NameGen = require(Shared:WaitForChild("NameGen"))
local HorseBook = require(Shared:WaitForChild("HorseBook"))
local StableStar = require(Shared:WaitForChild("StableStar")) -- first-win rosettes on the Rosette Wall (D-062)

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
local LiveChances = makeRemote("LiveChances")     -- server -> all: seg, chances, course, preview (true: a preview, not a checkpoint closing; D-067)
local RaceFinished = makeRemote("RaceFinished")   -- server -> all: results, course
local IntegrityNote = makeRemote("IntegrityNote") -- server -> one: private note (D-022 flag 2)
local RideRank = makeRemote("RideRank")           -- server -> one: your ride score's rank in the race, only when it's 1st to 3rd, course (D-067)
local RideReport = makeRemote("RideReport")       -- server -> one: stars, places gained by riding, place, [trip stars, places gained by the trip (riders with the steering buttons),] course (D-033, D-054)
local TripInfo = makeRemote("TripInfo")           -- server -> all: steering on, lock time (server time), course (D-054)
local TripLocked = makeRemote("TripLocked")       -- server -> all: lanes locked at the far turn, course (D-054)
local SteerControls = makeRemote("SteerControls") -- server -> one rider: buttons shown, Smart Steer on, first-time tip, first-brush tip (D-057 N5), course (D-054 S3)
local SteerRequest = makeRemote("SteerRequest")   -- client -> server: dir (-1 in toward the rail, 1 out), seq (D-054 S3)
local SteerBrush = makeRemote("SteerBrush")       -- server -> all: a brush (mover, other, dir, server time, course), D-057 N5
local PackEvent = makeRemote("PackEvent")         -- server -> all: a pack event ("out" | "pass" | "shut", horse, other, flag, server time, course), D-072
local SteerLane = makeRemote("SteerLane")         -- server -> one rider, on change: own lane tgt, destination, last seq answered, waiting press, its race time, tucking, in side, out side, the state's race time, course (D-054 S3, D-057 N4)
local Dismount = makeRemote("Dismount")           -- client -> server: rider pressed Done after results or replay
local PersonalBest = makeRemote("PersonalBest")   -- server -> one: distance, ride score, earlier best, course ("New best!", D-063)
-- On-screen gaps, several times a second; dropping one is harmless, so unreliable.
local RaceOffsets = Instance.new("UnreliableRemoteEvent")
RaceOffsets.Name = "RaceOffsets"                  -- server -> all: feet ahead of the pace per lane (never the luck), [lane positions, server time,] course
RaceOffsets.Parent = remotes
-- (D-071) To the rider only, never to spectators: their taps' message over their horse, and how far
-- lane room holds their drawn horse back (the pressure cue and the chip on their own screen).
local TapNote = makeRemote("TapNote")             -- server -> one rider: "up" or "away", course
local TapHeld = Instance.new("UnreliableRemoteEvent")
TapHeld.Name = "TapHeld"                          -- server -> one rider: feet held back by lane room, course
TapHeld.Parent = remotes
local BurstSparkle = makeRemote("BurstSparkle")   -- server -> all: lane ids with a Great+ burst, course
local JoinRace = makeRemote("JoinRace")           -- client -> server: want (bool), course id?, horse id?
local QueueStatus = makeRemote("QueueStatus")     -- server -> one: in line?, riders in line, seconds (or nil), course
local QueueGate = makeRemote("QueueGate")         -- server -> one in line: course (nil = league line), riders {name, coat, user}, lanes, seconds (or nil), racing (D-061 stage 2)
local RaceTime = makeRemote("RaceTime")           -- server -> racers: the gate filled, "Race time!" (D-061 stage 2), course
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
-- course = { id, cfg, scene, surface, queue, fillDeadline, current, card, charged, shined, nextDistance }
-- (shined: player -> horse id whose Spa shine this race took, D-058; given back if the race aborts)
local courses: { [string]: any } = {}
for _, id in COURSE_ORDER do
	local cfg = TrackLayout.courses[id]
	courses[id] = {
		id = id, cfg = cfg, scene = TrackScene.course(id, cfg), surface = SURFACE[id],
		queue = {}, fillDeadline = nil, current = nil, card = nil, charged = {}, shined = {}, nextDistance = if id == "dirt" then 1 else 2,
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
	leagueName = RaceQueues.claimLeague(leagueName, kind) -- Open Practice: always openPracticeLeague (D-068)
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

-- The queue card's gate (D-061 stage 2): each rider's horse name and coat, in line order.
local function gateRiders(list: { Player }): { any }
	local out = {}
	for _, p in list do
		local data = Profiles.get(p)
		local h = data and ((chosen[p] and Profile.horse(data, chosen[p])) or Profile.activeHorse(data))
		if h and #out < GameConfig.lanes then
			table.insert(out, { name = h.name, coat = h.coat, user = p.UserId })
		end
	end
	return out
end

local function queueStatus(c)
	local seconds = if c.fillDeadline then math.max(0, math.ceil(c.fillDeadline - os.clock())) else nil
	local riders = gateRiders(c.queue)
	for _, p in c.queue do
		QueueStatus:FireClient(p, true, #c.queue, seconds, c.id)
		QueueGate:FireClient(p, c.id, riders, GameConfig.lanes, seconds, c.current ~= nil)
	end
end

-- Per-league queues (D-061 core, stage 1): riders wait in their league-and-kind queue until a
-- course can take them (RaceQueues.pump). GameConfig.queue.mode = "cards" is the D-036 claiming.
local LEAGUE_QUEUES = GameConfig.queue == nil or GameConfig.queue.mode ~= "cards"
local waits = RaceQueues.new()

-- A rider waiting in a league queue (no course yet): in line, how many wait with them, no course.
local function waitStatus(player: Player)
	QueueStatus:FireClient(player, true, RaceQueues.waitingWith(waits, player), nil, nil)
	local key = waits.of[player]
	local q = key and waits.queues[key]
	local list = {}
	for _, w in (q and q.riders) or {} do table.insert(list, w.rider) end
	QueueGate:FireClient(player, nil, gateRiders(list), GameConfig.lanes, nil, false)
end

-- Find it (D-075): the queue card names your line and why from these (QueueView.lineTitle, lineWhy).
local function markLine(player: Player, key: string?, horseName: string?)
	player:SetAttribute("LineKey", key)
	player:SetAttribute("LineHorse", if key then horseName else nil)
end

local function leaveLine(player: Player)
	if RaceQueues.leave(waits, player) then
		player:SetAttribute("InLine", nil)
		markLine(player, nil)
		QueueStatus:FireClient(player, false, 0, nil, nil)
	end
	local c = inLine[player]
	if not c then return end
	RaceTime:FireClient(player, c.id, true) -- cancels a "Race time!" already shown (D-061 stage 2)
	inLine[player] = nil
	player:SetAttribute("InLine", nil)
	markLine(player, nil)
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
	if #list < cur.maxTaps then table.insert(list, t) end -- room for a bounce per pass (D-055); more would score 0 anyway
end)

-- Steering (D-054 S3): a rider's lane-change press. Trip.submit checks it as it arrives (in this
-- race, before the lock, dir -1 or 1, seq rising, not spam) and the next 10 Hz tick applies it.
-- Riders whose buttons are hidden (their first introRaces races; 0 since D-072) can't steer, nor can
-- anyone in a fixed-lanes race (Hurdles, D-072: no SteerControls are sent).
SteerRequest.OnServerEvent:Connect(function(player: Player, dir: any, seq: any)
	local c = riding[player]
	local cur = c and c.current
	if not cur or not cur.trip or cur.aborted or not cur.steers[player] then return end
	Trip.submit(cur.trip, cur.session, tostring(player.UserId), dir, seq, now() - cur.tStart)
end)

BurstTap.OnServerEvent:Connect(function(player: Player, seg: any, claimed: any)
	local c = riding[player]
	if not c or not c.current or seg ~= c.current.seg then return end
	local t, cur = resolveTap(player, claimed, "burst")
	if not t then return end
	-- A tap before the burst is armed (GameConfig.burstArmSeconds, D-066) comes back nil: ignored,
	-- and the rider's one tap is still to come. (A resolved time is never earlier than the claim,
	-- so a tap the client saw armed is armed here too.)
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
			return nil, h.name .. " is napping. Try a Practice race!"
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
			-- Class badge (D-062): First Win, Rising Star, Open or Cup, a label only.
			hv.class = Leagues.classOf(h, hv.cupOpen)
			hv.leagueWins = table.clone(Leagues.wins(h))
		end
	end
	view.hallOfFame = data.hallOfFame or {}
end, "races")

-- Cards mode (D-036): with no course picked, join riders already waiting, else a free course,
-- else the shorter line, whatever its league.
local function bestCourseCards()
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

-- Move waiting riders onto courses that can take them: a card already theirs, or an open course
-- for the longest-waiting queue, which claims its card (RaceQueues.pump).
local function pumpQueues()
	if not LEAGUE_QUEUES then return end
	local touched = {}
	local moved = RaceQueues.pump(waits, courses, COURSE_ORDER, GameConfig.lanes, function(c, league, kind)
		if not c.card then newCard(c) end
		claimCard(c, league, kind)
	end, function(p, c)
		inLine[p] = c
		touched[c] = true
	end)
	if moved == 0 then return end
	for c in touched do
		if not c.fillDeadline and not c.current then c.fillDeadline = os.clock() + GameConfig.lobbyFillSeconds end
		queueStatus(c)
	end
	publishCards()
end

-- League queues: check the horse for its own league's card, then wait in that league-and-kind
-- queue; pumpQueues puts the rider on a course when one can take them. A picked course is only a
-- wish: a card for another league never takes them.
-- `follow` (Race with a friend, D-068): courseId is the friend's course; move there even when
-- already in line (alone, or in Open Practice on another course) if it has room.
local function joinQueue(player: Player, courseId: any, horseId: any, kind: string, follow: boolean?)
	local data = Profiles.get(player)
	local id = if typeof(horseId) == "string" then horseId else nil
	local pick = data and ((id and Profile.isStalled(data, id) and Profile.horse(data, id)) or Profile.activeHorse(data))
	local wanted = { league = if pick then pick.league else DEFAULT_LEAGUE, cup = kind == "cup", practice = kind == "practice" }
	local h, why = rideable(player, id, wanted)
	if not h and kind == "race" then -- (D-061 stage 2) a tired or outgrown horse still gets a race: Practice
		local practice = { league = wanted.league, cup = false, practice = true }
		local hp = rideable(player, id, practice)
		if hp then
			h, kind = hp, "practice"
			Profiles.notify(player, hp.name .. " is resting, so this one is a Practice race!", "zzz_resting")
		end
	end
	if not h then
		Profiles.notify(player, why, "zzz_resting")
		if not inLine[player] and not RaceQueues.isWaiting(waits, player) then QueueStatus:FireClient(player, false, 0, nil, nil) end
		return
	end
	local key = RaceQueues.key(h.league, kind)
	local c = inLine[player]
	local target = if follow and typeof(courseId) == "string" then courses[courseId] else nil
	if c and target and target ~= c and RaceQueues.canTake(target, key, GameConfig.lanes) then
		leaveLine(player) -- follow the friend: no same-card or alone-in-line shortcut
		c = nil
	end
	if c then
		if RaceQueues.cardKey(c.card) == key then -- same race, maybe another horse of the league
			chosen[player] = h.id
			markLine(player, key, h.name)
			return
		end
		if #c.queue == 1 and c.queue[1] == player then -- alone in line: the card follows the new pick
			chosen[player] = h.id
			claimCard(c, h.league, kind)
			markLine(player, RaceQueues.cardKey(c.card), h.name)
			publishCards()
			return
		end
		leaveLine(player)
	end
	chosen[player] = h.id
	local want = if typeof(courseId) == "string" and courses[courseId] then courseId else nil
	RaceQueues.join(waits, player, h.league, kind, os.clock(), want)
	player:SetAttribute("InLine", true)
	markLine(player, key, h.name)
	pumpQueues()
	if RaceQueues.isWaiting(waits, player) then
		waitStatus(player)
		if not follow then Profiles.notify(player, "You're in line! You race when a course is free.", "flag_ready") end
	end
	publishCards()
end

-- "Race with [friend]" (AAA Phase 3, D-068): a Practice join that names a Roblox friend in this
-- server asks for the course that friend is in line for, when it's a Practice line (Open Practice).
-- Nothing is ever sent to the friend: no invites.
local TrainingFriends = require(script.Parent:WaitForChild("TrainingFriends"))
-- Returns (the friend's course id or nil, the friend or nil). A friend whose stable visits are set to
-- Nobody is never followed to a course (the join still goes to Open Practice).
local function friendPracticeCourse(player: Player, kind: string, friendId: any): (string?, Player?)
	if kind ~= "practice" or typeof(friendId) ~= "number" or not Leagues.openPractice() then return nil, nil end
	if friendId ~= friendId or math.abs(friendId) == math.huge or friendId ~= math.floor(friendId) then return nil, nil end
	local friend = Players:GetPlayerByUserId(friendId)
	if not friend or not TrainingFriends.areFriends(player, friend) then return nil, nil end
	local fd = Profiles.get(friend)
	if fd and fd.settings and fd.settings.visits == "Nobody" then return nil, friend end
	local c = inLine[friend]
	return (if c and c.card and c.card.practice then c.id else nil), friend
end

local lastJoin: { [Player]: number } = {}
JoinRace.OnServerEvent:Connect(function(player: Player, want: any, courseId: any, horseId: any, kind: any, friendId: any)
	if os.clock() - (lastJoin[player] or 0) < 0.5 then return end
	lastJoin[player] = os.clock()
	if want == false then
		leaveLine(player)
		pumpQueues()
		publishCards()
		return
	end
	if riding[player] then return end
	kind = if kind == "cup" or kind == "practice" then kind else "race"
	if LEAGUE_QUEUES then
		local friendCourse, friend = friendPracticeCourse(player, kind, friendId)
		if not friend then
			joinQueue(player, courseId, horseId, kind)
			return
		end
		joinQueue(player, friendCourse, horseId, kind, true)
		-- One notice from the join (D-068): honest about whether the friend's race was found.
		local c = inLine[player]
		local with = friendCourse ~= nil and c ~= nil and c.id == friendCourse
		local together = waits.of[player] ~= nil and waits.of[player] == waits.of[friend] -- both still waiting
		if c or RaceQueues.isWaiting(waits, player) then
			Profiles.notify(player, if with or together then string.format("🎈 You're in %s's race!", friend.DisplayName)
				else string.format("Ask %s to tap 🎈 Practice too!", friend.DisplayName), "flag_ready")
		end
		return
	end
	local c = if typeof(courseId) == "string" and courses[courseId] then courses[courseId] else bestCourseCards()
	if not c then
		Profiles.notify(player, "Both races are full. Try again after these races!", "flag_ready")
		return
	end
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
		markLine(player, RaceQueues.cardKey(c.card), h.name)
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
	markLine(player, RaceQueues.cardKey(c.card), h.name)
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
	local trip = c and c.current and c.current.trip
	if trip and not trip.locked then -- a rider who leaves goes to Smart Steer (D-054)
		local i = c.current.session:laneIndex(tostring(player.UserId))
		if i then Trip.setSmart(trip, i, true) end
	end
	leaveLine(player)
	task.defer(pumpQueues) -- a card they held may be open now
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
					IntegrityNote:FireClient(p, "Your taps looked automatic, so races are practice for now.")
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
	local shineOf: { [string]: boolean } = {} -- a Spa Day's shine, for this race (D-058)
	local riders = {}
	for _, p in players do
		local h = rideable(p, chosen[p], card)
		-- cash fields never mix leagues; Open Practice does (D-068: no purse, no League Points)
		if h and h.league ~= leagueName and not (card.practice and Leagues.openPractice()) then h = nil end
		local cost = if h then costOf(card, h) else 0
		local data = Profiles.get(p)
		if h and data and not riding[p] and (cost == 0 or Horse.spendEnergy(h, cost, os.time(), GameConfig.energy)) then
			local rating = Horse.rating(h, cond, os.time(), RaceRating)
			table.insert(humans, { id = tostring(p.UserId), name = h.name, rating = rating, isBot = false })
			horseOf[p.UserId] = h.id
			coatOf[tostring(p.UserId)] = h.coat
			if GameConfig.spa.shine and Spa.takeShine(h) then
				shineOf[tostring(p.UserId)] = true
				c.shined[p] = h.id
				Profiles.changed(p)
			end
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
	-- Bots rated by league (D-061 stage 2), named from the horse-name chips.
	local lanes = RaceSession.fillWithBots(humans, GameConfig.lanes, GameConfig, ThemePack, rng, { league = leagueName, nameParts = NameGen })
	if card.practice and GameConfig.queue.practiceEqualHorses then RaceSession.equalizeRatings(lanes) end -- D-068
	local coats = {}
	local shines = {}
	for i, lane in lanes do
		coats[i] = coatOf[lane.id] -- bots keep the default coats
		shines[i] = shineOf[lane.id]
	end
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

	-- Posts (D-054): drawn from the race's generator after every draw above (bots, luck, bot
	-- scores, the slider's passes), so those keep their draws; lanes are then numbered by post, so
	-- humans no longer start on the inside. Coats follow their horses. The Final Burst's random
	-- start (drawn when the burst opens) comes n - 1 draws later than before, which is harmless:
	-- the generator is an unseeded Random.new(), the start is uniform, and every lane shares it.
	-- GameConfig.steering.drawPosts = false keeps the old humans-first lanes.
	local order = RaceSession.postOrder(GameConfig, #session.lanes, rng)
	session:assignPosts(order)
	local postCoats = {}
	local postShines = {}
	for post, old in order do postCoats[post], postShines[post] = coats[old], shines[old] end
	coats, shines = postCoats, postShines

	-- Steering (D-054): the trip state, built after the posts (lane index = post), drawing its
	-- two uniforms per lane after every other gate draw. Bots steer with Smart Steer and its bot
	-- variety. nil when GameConfig.steering.enabled is false: today's race exactly.
	-- Rider controls (S3, Trip.riderControls): the ◀ ▶ buttons show from a player's introRaces +
	-- 1-th race that counts, the first time with a ghost-thumb tip. Riders ride with Smart Steer,
	-- which their presses pause; a rider who turned it off in Settings and has the buttons steers
	-- alone. While the buttons are hidden everyone has Smart Steer (no kid is left at their post
	-- with no way to move) and their tau is 0 (they can't affect their trip).
	-- D-072: a rider in their first learner.races counted races is a learner (no shut doors, their
	-- own presses never push tau below learner.tauFloor), and each style's baseline joins the post's
	-- (TripBaseline.styles). A fixed-lanes race (card.fixedLanes, false by default; Hurdles later)
	-- keeps every horse in its post lane with tau 0, and nobody gets the buttons.
	local trip = nil
	local controls: { [Player]: { shown: boolean, smart: boolean, tip: boolean, bumpTip: boolean, kind: string, pips: boolean,
		learner: boolean, races: number } } = {}
	local steers: { [Player]: boolean } = {}
	local fixedLanes = card.fixedLanes == true
	if GameConfig.steering.enabled then
		local tripRow = TripBaseline[c.id] and TripBaseline[c.id][cond.distance]
		if not tripRow then
			warn(string.format("[RaceService] no trip baseline for %s %s; posts count as equal", c.id, tostring(cond.distance)))
			tripRow = table.create(GameConfig.lanes, 0)
		end
		local riders, learners = {}, {}
		for _, p in players do
			local ctl = Trip.riderControls(Profiles.get(p), GameConfig.steering, GameConfig.steerHud)
			if not fixedLanes then
				controls[p] = ctl
				if ctl.shown then steers[p] = true end
			end
			riders[tostring(p.UserId)] = ctl.kind
			learners[tostring(p.UserId)] = ctl.learner
		end
		trip = Trip.start(GameConfig, session, cfg, plan, tripRow, rng, TrackLayout, riders,
			{ learners = learners, fixedLanes = fixedLanes, styleRow = Trip.styleRow(TripBaseline, c.id, cond.distance) })
	end

	c.scene:dismountAll() -- anyone still sitting from this course's last race
	c.scene:build(plan, coats, shines) -- rebuilt each race: the gate moves with the distance, riders' own coats
	local title = if card.cup then leagueName .. " Cup" elseif card.practice then "Practice" else leagueName
	RaceStarted:FireAllClients(title, lanesSummary(session), tStart, cond, resultAt, burstOpen, c.id)
	if trip then
		TripInfo:FireAllClients(true, tStart + trip.lockT, c.id)
		for p, ctl in controls do
			SteerControls:FireClient(p, ctl.shown, ctl.smart, ctl.tip, ctl.bumpTip, c.id)
			local data = ctl.tip and Profiles.get(p)
			if data then -- the ghost-thumb tip shows once
				data.flags.steerTip = true
				Profiles.changed(p)
			end
		end
	end
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
				p:SetAttribute("RacingHorse", horseOf[p.UserId]) -- its stall shows "at the races" (D-056)
				Rides.dismount(p) -- off your own horse before the race horse
				TrackScene.dismount(p.Character) -- and off the other course's horse after its race
				c.scene:seatRider(i, p.Character)
			end
		end
	end
	c.scene:addJockeys(isBot) -- Roblox-style jockeys on the bot horses

	-- Tap preview (D-071, provisional; GameConfig.tapPreview): before the lock each rider's drawn horse
	-- leads Trip's by what their taps in the open checkpoint have earned so far (TapPreview). Drawn
	-- only, and only in races with a human: nothing is made or computed for an all-bot race. With
	-- steering off (no trip) the open checkpoint's shown chances refresh at each pass end instead
	-- (PacePreview.beforeLock). enabled = false: neither, today's race exactly.
	local tapCfg = GameConfig.tapPreview
	local tapOn = TapPreview.enabled(tapCfg)
	local tp = nil
	local tapRiders = {} -- { i = lane, uid, p = Player, hs = the held feet's send state } per human lane
	if tapOn then
		for i, lane in session.lanes do
			local uid = if lane.isBot then nil else tonumber(lane.id)
			local p = uid and Players:GetPlayerByUserId(uid)
			if p then
				table.insert(tapRiders, { i = i, uid = uid, p = p, hs = TapPreview.newHeldSend() })
			end
		end
	end
	if trip and #tapRiders > 0 then
		tp = TapPreview.new(#session.lanes, tapCfg, trip.lead, GameConfig.steering.gapRampSeconds, GameConfig.steering.laneBand)
		for i, lane in session.lanes do TapPreview.setRider(tp, i, not lane.isBot) end
	end
	local tapWholeRace = trip == nil and #tapRiders > 0 -- (steering off)
	-- (tapPartial, tapClean and tapDone are made once a race and reused; previewOwn and PaceMeter.score
	-- still allocate at each pass end, one or two a second)
	local tapPartial, tapClean, tapDone = {}, {}, {}
	local NO_TAPS = {}
	-- A pass counts as finished once its late taps are in: a tap's claimed time is kept for up to
	-- maxTapRewindSeconds of latency, so a Perfect at the pass's end can still be on its way (D-071).
	-- (Layer off: 0, the D-067 previews as before.)
	local TAP_GRACE = if tapOn then GameConfig.maxTapRewindSeconds or 0 else 0

	local preLast, postLast = tStart, postStart
	for _, p in passes do
		if p.t0 < burstOpen then preLast = math.max(preLast, p.t1) else postLast = math.max(postLast, p.t1) end
	end
	local cur = {
		session = session, seg = 1, kind = "pace", open = tStart, close = preLast,
		taps = {}, allowances = snapshotAllowances(players), maxTaps = #passes * 3 + 10,
		trip = trip, tStart = tStart, steers = steers, -- steering requests (D-054 S3)
	}
	c.current = cur
	publishCards()
	-- Live chances shown on screen: closed segments, refreshed each second in the stretch drive.
	local shownLive = table.clone(session.live)
	local racing = true
	-- The offsets loop runs while this race is on; a race that errors is marked aborted by
	-- courseLoop and stops here too (no trip lock or remotes for a dead race).
	local function alive(): boolean
		return racing and not cur.aborted and (c.current == cur or c.current == nil)
	end
	-- The far-turn lock (D-054): Trip steps every fixed tick up to it, books the far turn, and the
	-- trip tau joins the race (clamped; 0 until now, so it never depends on luck).
	-- A late server steps the missed ticks with the live chances of now, so around checkpoint 1 a
	-- tick or two can use the new chances a tick early or late. That is fair: live chances are the
	-- same for every horse, it moves only when their skill gaps grow (by a tick), and tau is
	-- measured against that same field.
	local tapLockAt: number? = nil -- (D-071) when the lock came: the after-lock previews count from it
	local previewStretch: (seg: number, own: boolean?) -> () -- (below; the lock refreshes the shown chances with it, D-071)
	local function advanceTrip(t: number)
		if not trip or trip.locked or cur.aborted then return end
		debug.profilebegin("TripStep") -- (D-072 consult) the trip's ticks, learners' shadows included
		local lockedNow = Trip.advance(trip, session.live, t - tStart)
		debug.profileend()
		if lockedNow then
			tapLockAt = now()
			session:setTrip(Trip.raceTau(trip))
			shownLive = table.clone(session.live)
			TripLocked:FireAllClients(c.id)
			-- One line for the playtest logs (D-054): each rider's post, steering and tau, and how
			-- the riders' requests were answered.
			-- Brushes (D-057 N5) per rider with how many went into each other horse ("into post 4 x2"):
			-- the plan's griefing line counts one rider brushing the same horse 3+ times.
			local parts, answers = {}, {}
			for i, lane in session.lanes do
				if not lane.isBot then
					local into = {}
					for j, count in Trip.brushesInto(trip, i) do table.insert(into, string.format("post %d x%d", j, count)) end
					table.sort(into)
					table.insert(parts, string.format("post %d %s tau %.4f brushes %d%s cost %.3f", i, trip.riderKind[i] or "smart",
						session.tau[i], trip.brushes[i], if #into > 0 then " (into " .. table.concat(into, ", ") .. ")" else "",
						Trip.brushCharge(trip, i)))
				end
			end
			for answer, count in trip.answers do table.insert(answers, answer .. " " .. count) end
			table.sort(answers)
			local pack = { out = 0, pass = 0, shut = 0 } -- (D-072) the field's passes and shut doors
			for _, e in trip.packEvents do pack[e[2]] = (pack[e[2]] or 0) + 1 end
			print(string.format("[Trip] %s %s locked at %.1f s: %s; requests: %s; held by the reverse or weave gap %d, waits dropped %d; pack: out %d, passes %d, doors shut %d%s",
				c.id, cond.distance, trip.lockT, table.concat(parts, ", "), if #answers > 0 then table.concat(answers, ", ") else "none",
				trip.gapHeld or 0, trip.waitDropped or 0, pack.out, pack.pass, pack.shut, if trip.fixed then " (fixed lanes)" else ""))
			-- The chances shown pick tau up at once (when the lock comes before checkpoint 1, as it
			-- can in a Sprint, the checkpoint's own update carries it).
			if session.closed > 0 then LiveChances:FireAllClients(session.closed, shownLive, c.id) end
			-- (D-071) Once at the lock, the open checkpoint's preview (as each second after it): the shown
			-- offsets rise to where the tap preview drew the horses while it holds, so its residual is
			-- absorbed rather than eased away.
			-- (Only while the checkpoint's passes still run, as each second after it.)
			if tp and cur.seg and PacePreview.afterLock(PREVIEW_AFTER_LOCK, true, cur.seg, session.closed, false) then
				local segPasses = session:pacePasses(cur.seg)
				local lastEnd = if #segPasses > 0 then segPasses[#segPasses].t1 else -math.huge
				if now() < lastEnd then previewStretch(cur.seg) end
			end
		end
	end
	task.spawn(function()
		local period = 1 / GameConfig.offsetsPerSecond
		if not trip then -- steering off: today's offsets
			while alive() do
				local w = RaceShape.blendWeight(now(), tFar, postEnd, GameConfig.raceShape.blendPower)
				RaceOffsets:FireAllClients(session:displayOffsets(shownLive, w, GameConfig.raceShape), c.id)
				task.wait(period)
			end
			return
		end
		-- Steering: the screen shows what the server sends, all race: Trip's gaps and lanes up to the
		-- lock, one sample for every fixed tick (the loop wakes about every 0.117 s, so it steps and
		-- sends each tick that has come due, and none is skipped); after it, the race shape's gaps as
		-- the screen eases them, held so no horse runs through another, with make-room lanes
		-- (Trip.frame), one sample a wake. Lanes go out when they change, on the two samples after,
		-- and once a second (a dropped packet is harmless). Every sample carries the server time its
		-- state stands for, and the screen draws by that time, not by arrival (Playback, D-057 N3):
		-- before the lock tStart + tick * dt (Trip's state after `tick` ticks; up to one tick ahead of
		-- now, which the screen's lag estimate absorbs); before the gate, now (nothing moves); after
		-- the lock, now, with the make-room step taken from the last sample's time, so the samples'
		-- spacing is exactly how far they moved.
		local lastStamp = tStart
		local sentLanes, lanesAt, resend = nil, -math.huge, 0
		local sentOwn: { [Player]: any } = {}
		local sentBrushes, sentPack = 0, 0
		-- Brushes (D-057 N5) go to every screen following the course, before that tick's SteerLane,
		-- stamped with the server time they happened: the mover leans and nods, the other nods, a
		-- soft tick at the mover's horse, and the mover's chip. Bots and Smart Steer never brush;
		-- nothing happens after the lock (Trip).
		-- A rider's first brush ever brings the one-time tip on their screen (SteerControls' bumpTip):
		-- from then on the profile says it has come.
		local function bumpTipShown(i: number)
			local lane = session.lanes[i]
			if not lane or lane.isBot then return end
			local p = Players:GetPlayerByUserId(tonumber(lane.id) or 0)
			local ctl = if p then controls[p] else nil
			if not p or not ctl or not ctl.bumpTip then return end
			ctl.bumpTip = false
			local data = Profiles.get(p)
			if data then
				data.flags.bumpTip = true
				Profiles.changed(p)
			end
		end
		-- (D-072) Pack events go to every screen following the course the same way, stamped as the
		-- samples are: "out" (a horse moves out to pass another), "pass" (it is clear and heads back in)
		-- and "shut" (a bot shuts the door on a horse moving into its lane: RaceView turns the bot toward
		-- it, and the rider whose press it held hears it). Drawn only; none after the lock.
		local function sendPack()
			while sentPack < #trip.packEvents do
				sentPack += 1
				local e = trip.packEvents[sentPack]
				PackEvent:FireAllClients(e[2], e[3], e[4], e[5], tStart + e[1] + trip.dt, c.id)
			end
		end
		local function sendBrushes()
			sendPack()
			while sentBrushes < #trip.events do
				sentBrushes += 1
				local e = trip.events[sentBrushes]
				-- (stamped as the samples are: the state after its tick)
				if e[2] == "brush" then
					SteerBrush:FireAllClients(e[3], e[4], e[5], tStart + e[1] + trip.dt, c.id)
					bumpTipShown(e[3])
				end
			end
		end
		local scratchOwn = {}
		-- (D-071) Each rider's own word from the tap preview, to them alone: the message over their
		-- horse (TapPreview.message, before the lock), and how far lane room holds their drawn horse
		-- back (TapPreview.held; 0 after the lock), unreliable, when TapPreview.heldSendDue says
		-- (tapPreview.heldSend: on a 1 ft change at most every 0.5 s, at once across the cue's thresholds
		-- or down to 0, and resent each second while above 0 so a lost packet can't strand it). Nothing
		-- here allocates.
		local function tapNotes(stamp: number)
			local rt = stamp - tStart
			for _, r in tapRiders do
				if r.p.Parent then
					local kind = TapPreview.message(tp, r.i, rt)
					if kind then TapNote:FireClient(r.p, kind, c.id) end
					if TapPreview.heldSendDue(r.hs, TapPreview.held(tp, r.i), stamp, tapCfg) then
						TapHeld:FireClient(r.p, r.hs.last, c.id)
					end
				end
			end
		end
		local function send(stamp: number, frameDt: number)
			debug.profilebegin("RaceSend")
			sendBrushes()
			local w = RaceShape.blendWeight(stamp, tFar, postEnd, GameConfig.raceShape.blendPower)
			local offsets, lanes = Trip.frame(trip, session, shownLive, w, GameConfig.raceShape, frameDt, stamp - tStart)
			lastStamp = stamp
			if tp then -- (D-071) the drawn preview on Trip's offsets: tp.d, the same table each call, sent below at once
				offsets = TapPreview.step(tp, offsets, if trip.locked then trip.shown else trip.x,
					if trip.locked then trip.shownTgt else trip.tgt, stamp - tStart, trip.locked)
				tapNotes(stamp)
			end
			-- Each rider with the buttons (and nobody else) hears about their own lane when it changes,
			-- up to the lock (Trip.riderLane): the lane taken, where it ends, the last press answered
			-- (their screen's look cue and, with D-054's linear glide, its prediction: SteerPredict),
			-- a press waiting for room and since when, tuck-back, and each side's room (the grey
			-- arrows, the wait ring, the wobble and the chips: SteerHud, SteerChips, D-057 N4).
			if not trip.locked then
				for p in steers do
					local i = session:laneIndex(tostring(p.UserId))
					if i and p.Parent then
						local was = sentOwn[p]
						local own = Trip.riderLane(trip, i, scratchOwn, trip.tick * trip.dt)
						if not was or was.tgt ~= own.tgt or was.dest ~= own.dest or was.ack ~= own.ack or was.wait ~= own.wait
							or was.waitAt ~= own.waitAt or was.tucking ~= own.tucking or was.inSide ~= own.inSide
							or was.outSide ~= own.outSide then
							sentOwn[p] = table.clone(own)
							SteerLane:FireClient(p, own.tgt, own.dest, own.ack, own.wait, own.waitAt, own.tucking, own.inSide,
								own.outSide, own.t, c.id)
						end
					end
				end
			end
			local changed = sentLanes == nil or stamp - lanesAt >= 1
			if not changed and lanes then
				for i, x in lanes do
					if x ~= sentLanes[i] then changed = true end
				end
			end
			if changed then resend = 2 end -- (and on the next two samples: a dropped packet can't strand a lane)
			if (changed or resend > 0) and lanes then
				if not changed then resend -= 1 end
				sentLanes, lanesAt = lanes, stamp
				RaceOffsets:FireAllClients(offsets, lanes, stamp, c.id)
			else
				RaceOffsets:FireAllClients(offsets, stamp, c.id)
			end
			debug.profileend()
		end
		while alive() do
			local t = now()
			if t < tStart then
				send(t, 0)
			else
				while not trip.locked and tStart + trip.tick * trip.dt <= t and alive() do
					local tick = trip.tick
					advanceTrip(tStart + tick * trip.dt) -- exactly the next tick (or the lock)
					if trip.locked then break end
					if trip.tick == tick then break end -- (nothing stepped: never spin)
					send(tStart + trip.tick * trip.dt, 0)
				end
				if trip.locked then
					local base = math.max(lastStamp, tStart + trip.tick * trip.dt) -- (the lock's tick, right after it)
					local stamp = math.max(t, base)
					send(stamp, stamp - base)
				end
			end
			task.wait(1 / GameConfig.steering.sendHz)
		end
	end)
	previewStretch = function(seg: number, own: boolean?)
		-- Riders' provisional stretch-drive scores over the passes finished so far (late taps in).
		local done = {}
		for _, p in session:pacePasses(seg) do
			if p.t1 + TAP_GRACE <= now() then table.insert(done, p) end
		end
		if #done == 0 then return end
		local partial = {}
		for i, lane in session.lanes do
			if not lane.isBot then
				partial[i] = (PaceMeter.score(done, cur.taps[tonumber(lane.id)] or {}, GameConfig.pace.bounceSeconds))
			end
		end
		-- own (D-071, steering off before the lock): every other lane keeps its pace, so only the riders'
		-- own taps move the shown chances and the field's scores arrive at the close (as the layer's).
		shownLive = if own then session:previewOwn(seg, partial) else session:previewLive(seg, partial)
		LiveChances:FireAllClients(seg, shownLive, c.id, true) -- (D-067) a preview, not a checkpoint closing
	end
	-- (D-071) A pass end in the open checkpoint before the lock: the riders' scores so far and the
	-- share of their passes tapped exactly once, and the chances if it closed now with every other lane
	-- keeping its pace (previewOwn: only a rider's own taps move their horse) go to the tap preview.
	-- With steering off, the shown chances refresh instead (PacePreview.beforeLock).
	local function tapPassEnd(seg: number, segPasses)
		if tp then
			if trip.locked or seg ~= session.closed + 1 then return end
			table.clear(tapDone)
			local t = now()
			for _, p in segPasses do
				if p.t1 + TAP_GRACE <= t then table.insert(tapDone, p) end
			end
			local n = #tapDone
			if n == 0 then return end
			for _, r in tapRiders do
				local score, _, single = PaceMeter.score(tapDone, cur.taps[r.uid] or NO_TAPS, GameConfig.pace.bounceSeconds)
				tapPartial[r.i], tapClean[r.i] = score, single / n
			end
			TapPreview.setPreview(tp, session.live, session:previewOwn(seg, tapPartial), n, tapPartial, tapClean)
		elseif tapWholeRace and PacePreview.beforeLock(tapCfg, false, seg, session.closed, false) then
			previewStretch(seg, true)
		end
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
			elseif tp or tapWholeRace then
				-- (D-071) Wake at each pass end once its late taps are in (the tap preview, or with steering
				-- off the shown chances), and after the lock each second as below (D-067), counted from the
				-- lock (which refreshes them itself).
				local afterOn = trip ~= nil and PREVIEW_AFTER_LOCK ~= nil and PREVIEW_AFTER_LOCK.enabled ~= false
				local every = if afterOn then PREVIEW_AFTER_LOCK.seconds or 1 else 1
				local k, nextAfter, sawLock = 0, math.huge, false
				while now() < lastEnd and alive() do
					if afterOn and trip.locked and not sawLock then
						sawLock = true
						nextAfter = (tapLockAt or now()) + every
					end
					local wake = lastEnd
					if segPasses[k + 1] then wake = math.min(wake, segPasses[k + 1].t1 + TAP_GRACE) end
					if sawLock then wake = math.min(wake, nextAfter) end
					task.wait(math.max(0.05, wake - now()))
					local t = now()
					if afterOn and trip.locked and not sawLock then
						sawLock = true
						nextAfter = (tapLockAt or t) + every
					end
					local ended = false
					while segPasses[k + 1] and segPasses[k + 1].t1 + TAP_GRACE <= t do
						k += 1
						ended = true
					end
					if ended then tapPassEnd(seg, segPasses) end
					if sawLock and t >= nextAfter then
						nextAfter = t + every
						if PacePreview.afterLock(PREVIEW_AFTER_LOCK, trip.locked, seg, session.closed, false) and t < lastEnd then
							previewStretch(seg)
						end
					end
				end
			elseif trip and PREVIEW_AFTER_LOCK and PREVIEW_AFTER_LOCK.enabled ~= false then
				-- After the far-turn lock (AAA Phase 2, D-067): the open checkpoint's chances refresh each
				-- second from its finished passes, as in the stretch drive, so taps move horses on screen
				-- sooner. Drawn only: tau is fixed at the lock, before it nothing changes, and previewLive
				-- stores nothing (the checkpoint's own close sets the scores and the chances, as before).
				while now() < lastEnd and alive() do
					task.wait(math.min(PREVIEW_AFTER_LOCK.seconds or 1, math.max(0.05, lastEnd - now())))
					if PacePreview.afterLock(PREVIEW_AFTER_LOCK, trip.locked, seg, session.closed, false) and now() < lastEnd then
						previewStretch(seg)
					end
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
		if tp then TapPreview.closed(tp) end -- (D-071) the next checkpoint starts at 0 passes
		LiveChances:FireAllClients(seg, shownLive, c.id)
	end
	cur.seg = nil

	advanceTrip(math.huge) -- the lock is long past by the line; make sure the trip is in
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
					local before, after = Profile.recordRace(data, horseOf[player.UserId], prize.place, cash, points, os.time())
					-- Careers (D-059): a badge every career.badgeEvery races, Veteran at career.veteranAt.
					local badge, veteran = Career.crossed(before, after)
					local hc = (badge or veteran) and Profile.horse(data, horseOf[player.UserId])
					if hc then
						local name = hc.name
						task.delay(GameConfig.runInSeconds + 2, function()
							if not player.Parent then return end
							if veteran then
								Profiles.notify(player, Career.veteranToast(name), "trophy")
							elseif badge then
								Profiles.notify(player, Career.badgeToast(name, badge), "trophy")
							end
						end)
					end
					-- A horse's first win in a league (D-062): +firstWinBonus points once, before any
					-- Cup promotion, and a rosette in the league's colour on the Rosette Wall.
					local wh = prize.place == 1 and Profile.horse(data, horseOf[player.UserId])
					if wh and Leagues.recordWin(wh, leagueName) then
						StableStar.firstWin(data, leagueName)
						if not card.cup then
							local bonus = Leagues.FIRST_WIN_BONUS
							task.delay(GameConfig.runInSeconds + 1, function()
								if player.Parent then
									Profiles.notify(player, string.format("🐣 First %s win! +%d League Points", leagueName, bonus), "rosette")
								end
							end)
						end
					end
				end
				-- The Horse Book (D-063): this course, and a top-three place in a race that counts.
				HorseBook.record(data, "courses", c.id)
				if not card.practice and prize.place <= 3 then HorseBook.record(data, "places", tostring(prize.place)) end
				if card.cup and prize.place == 1 then
					local h = Profile.horse(data, horseOf[player.UserId])
					if h then h.record.cups = (h.record.cups or 0) + 1 end -- career Cups (D-059)
					local nxt = h and Leagues.promote(h)
					if nxt then
						HorseBook.record(data, "cups", leagueName)
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
	-- D-058: the race used a rider's last Energy and every one of their horses is napping now.
	for p in c.charged do
		local data = Profiles.get(p)
		local h = data and Profile.horse(data, horseOf[p.UserId] or "")
		if h and Spa.allNapping(data.horses, os.time(), GameConfig.energy) then
			task.delay(GameConfig.runInSeconds + 3, function()
				if p.Parent then Profiles.notify(p, Spa.dreamLine(h.name), "sleeping_horse") end
			end)
		end
	end
	table.clear(c.charged) -- the race counted
	table.clear(c.shined)
	-- Your ride: stars from your score, and places your riding gained versus riding at the race
	-- average (same luck, everything else the same). Only gains are shown to the rider.
	local S = session:scoresSoFar()
	local placeOf = {}
	for place, laneIdx in result.order do placeOf[laneIdx] = place end
	for _, p in players do
		local i = session:laneIndex(tostring(p.UserId))
		if i then
			local stars = if S[i] >= 85 then 3 elseif S[i] >= 65 then 2 elseif S[i] >= 40 then 1 else 0
			-- Your trip (D-054): stars, and places it gained, for riders who had the buttons.
			local tripStars = if trip and steers[p] then Trip.stars(session.tau[i], GameConfig.steering) else nil
			local tripGain = if tripStars then session:tripGain(i) else nil
			RideReport:FireClient(p, table.unpack(ResultsText.reportArgs(stars, session:ridingGain(i), placeOf[i], c.id, tripStars, tripGain)))
			-- "Best ride in the race!" (AAA Phase 2, D-067): your ride score ranked against every horse in
			-- the race, bots included; sent to you alone and only for the top 3, so it can't become a board.
			local rank = if GameConfig.results.riderRank ~= false then ResultsText.rideRank(S, i) else nil
			if rank and rank <= 3 then RideRank:FireClient(p, rank, c.id) end
			-- Personal best at this distance (D-063): private; only beating an earlier best says so.
			local data = Profiles.get(p)
			if data and not (GameConfig.comeback and GameConfig.comeback.bests == false) then
				local isNew, prev = HorseBook.recordBest(data, cond.distance, S[i])
				if isNew then PersonalBest:FireClient(p, cond.distance, data.bests[cond.distance], prev, c.id) end
				if isNew or prev == nil then Profiles.changed(p) end -- the best moved (or the first one was set)
			end
		end
	end
	recordIntegrity(players, errors, matched)
	-- Stable Board jobs count effort, never wins (D-043).
	for _, p in players do
		Progress.record(p, "race", 1)
		Progress.record(p, "great_tap", greatTaps[p.UserId] or 0)
		if (greatTaps[p.UserId] or 0) > 0 then Progress.record(p, "great_race", 1) end -- a Stable Star skill goal (D-062)
		if greatBurst[p.UserId] then Progress.record(p, "burst_great", 1) end
	end
	-- Riders stay on their horse for the results and replay; they press Done to get off.
	task.delay(GameConfig.dismountTimeoutSeconds, function()
		if not c.current then c.scene:dismountAll() end
	end)
	for _, p in players do
		p:SetAttribute("Racing", nil)
		p:SetAttribute("RacingHorse", nil)
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
		-- "Race time!" (D-061 stage 2): riders hear it raceTimeSeconds before the gate, or when it
		-- fills, wherever they are (grooming, riding, visiting); the race then seats them.
		local called: { [Player]: boolean } = {}
		local callAt = (GameConfig.queueCard and GameConfig.queueCard.raceTimeSeconds) or 3
		local function callBack()
			for _, p in c.queue do
				if not called[p] then
					called[p] = true
					RaceTime:FireClient(p, c.id)
				end
			end
		end
		while #c.queue > 0 and os.clock() < (c.fillDeadline or 0) and #c.queue < GameConfig.lanes do
			for _, p in c.queue do LobbyStatus:FireClient(p, math.ceil((c.fillDeadline or 0) - os.clock()), c.id) end
			queueStatus(c)
			if (c.fillDeadline or 0) - os.clock() <= callAt + 0.05 then callBack() end
			local left = (c.fillDeadline or 0) - os.clock()
			task.wait(if left > callAt + 0.05 then math.clamp(left - callAt, 0.05, 1) else math.clamp(left, 0.05, 1))
		end
		callBack()
		-- A gate that filled early: the riders just heard "Race time!"; give them its seconds.
		if #c.queue >= GameConfig.lanes and os.clock() < (c.fillDeadline or 0) - callAt then task.wait(callAt) end
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
			markLine(p, nil)
			table.insert(racers, p)
		end
		c.fillDeadline = nil
		for _, p in racers do QueueStatus:FireClient(p, false, #c.queue, nil, c.id) end
		if #racers > 0 then
			local ok, err = pcall(runRace, c, racers)
			if not ok and c.current then c.current.aborted = true end -- its loops stop (RaceService alive())
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
				for p, horseId in c.shined do -- and the Spa shine (D-058)
					local data = Profiles.get(p)
					local h = data and Profile.horse(data, horseId)
					if h then
						h.shine = true
						Profiles.changed(p)
					end
				end
				table.clear(c.shined)
				if #c.queue == 0 then openCard(c) end
				for _, p in racers do
					p:SetAttribute("Racing", nil)
					p:SetAttribute("RacingHorse", nil)
					if riding[p] == c then riding[p] = nil end
				end
			end
		end
		publishCards()
		task.wait(5) -- results screen
		if #c.queue > 0 then c.fillDeadline = c.fillDeadline or (os.clock() + GameConfig.lobbyFillSeconds) end
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

-- Cards tick down once a second for the board and the picker. Waiting riders go to any course
-- that has opened (a race started and its next card is open, or a line emptied), and those still
-- waiting hear how many wait with them.
task.spawn(function()
	while true do
		task.wait(1)
		local ok, err = pcall(pumpQueues)
		if not ok then warn("[RaceService] queue pump failed: " .. tostring(err)) end
		for p in waits.of do
			if p.Parent then waitStatus(p) end
		end
		publishCards()
	end
end)

for _, id in COURSE_ORDER do
	task.spawn(courseLoop, courses[id])
end
