--!nonstrict
-- RaceService: Phase 1 prototype race loop.
-- Everyone in the server races together (up to 8), bots fill the rest; racing players
-- ride their own horse (D-024) on the Churchill-style track (D-027).
-- Each race: the pace slider from the gate to the final turn (two checkpoints), the Final
-- Burst as the field enters the homestretch (one tap on a big meter, counts double), then
-- the slider again for the stretch drive (D-026, D-031). Race length follows the distance
-- condition (Sprint ~69 s ... ).
-- All scoring and the finish draw happen here; clients only send tap times.
-- Prototype limits: no saving (leaderstats only), no parties, starter ratings,
-- integrity trackers live for the session only (they move to DataStore later).
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
local TrackScene = require(script.Parent:WaitForChild("TrackScene"))

local LEAGUE = "Rookie" -- prototype: one league
local COUNTDOWN = 3
local LATENCY_GRACE = 0.35 -- wait after a segment closes for late packets

local remotes = Instance.new("Folder")
remotes.Name = "RaceRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local LobbyStatus = makeRemote("LobbyStatus")     -- server -> all: seconds until start
local RaceStarted = makeRemote("RaceStarted")     -- server -> all: league, lanes, start, conditions, expected result time, burst open
local PaceSchedule = makeRemote("PaceSchedule")   -- server -> all: the slider's passes for the race
local PaceResult = makeRemote("PaceResult")       -- server -> one: checkpoint, score, label
local BurstOpened = makeRemote("BurstOpened")     -- server -> all: seg, open, close, meter spec, name
local TapResult = makeRemote("TapResult")         -- server -> one: seg, burst score, label
local LiveChances = makeRemote("LiveChances")     -- server -> all: seg, chances after it
local RaceFinished = makeRemote("RaceFinished")   -- server -> all: results
local IntegrityNote = makeRemote("IntegrityNote") -- server -> one: private note (D-022 flag 2)
local RideReport = makeRemote("RideReport")       -- server -> one: stars, places gained by riding, place (D-033)
local Dismount = makeRemote("Dismount")           -- client -> server: rider pressed Done after results or replay
-- On-screen gaps, several times a second; dropping one is harmless, so unreliable.
local RaceOffsets = Instance.new("UnreliableRemoteEvent")
RaceOffsets.Name = "RaceOffsets"                  -- server -> all: feet ahead of the pace per lane (never the luck)
RaceOffsets.Parent = remotes
local BurstSparkle = makeRemote("BurstSparkle")   -- server -> all: lane ids with a Great+ burst (small badge sparkle)
local PaceTap = makeRemote("PaceTap")             -- client -> server: claimed server time
local BurstTap = makeRemote("BurstTap")           -- client -> server: seg, claimed server time

local function now(): number
	return workspace:GetServerTimeNow()
end

local function today(): number
	return math.floor(os.time() / 86400)
end

-- Prototype player state ----------------------------------------------------
local starterStats: { [number]: { [string]: number } } = {}
local trackers: { [number]: any } = {}
local DISTANCES = { "Sprint", "Mile", "Classic", "Marathon" }
local SURFACES = { "Dirt", "Turf", "Sand" }
local WEATHERS = { "Sunny", "Rain", "Wind" }
local function setupPlayer(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local cash = Instance.new("IntValue")
	cash.Name = ThemePack.currency.earned
	cash.Parent = stats
	local points = Instance.new("IntValue")
	points.Name = "League Points"
	points.Parent = stats
	-- Prototype starter racer: random stats 40-60 (no stable or saving yet).
	local racer = {}
	for _, k in { "speed", "accel", "stamina", "grit", "focus" } do
		racer[k] = math.random(40, 60)
	end
	starterStats[player.UserId] = racer
	trackers[player.UserId] = Integrity.new()
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in Players:GetPlayers() do setupPlayer(p) end

-- Race state shared with the tap handlers -------------------------------------
-- { session, seg, kind ("pace" | "burst" | nil when closed), open, close,
--   taps = { [userId] = {times} }, allowances = { [userId] = seconds }, maxTaps }
local current = nil

-- Latency is snapshotted per checkpoint so a lag spike can't widen it (D-021).
local function snapshotAllowances(): { [number]: number }
	local out = {}
	for _, p in Players:GetPlayers() do
		out[p.UserId] = TapTime.rewindAllowance(p:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	end
	return out
end

local function resolveTap(player: Player, claimed: any, kind: string): number?
	if not current or current.kind ~= kind or typeof(claimed) ~= "number" then return nil end
	local allowance = current.allowances[player.UserId]
		or TapTime.rewindAllowance(player:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	return TapTime.resolve(claimed, now(), current.open, current.close, allowance)
end

PaceTap.OnServerEvent:Connect(function(player: Player, claimed: any)
	local t = resolveTap(player, claimed, "pace")
	if not t then return end
	local list = current.taps[player.UserId]
	if not list then
		list = {}
		current.taps[player.UserId] = list
	end
	if #list < current.maxTaps then table.insert(list, t) end -- extra taps would score 0 anyway
end)

BurstTap.OnServerEvent:Connect(function(player: Player, seg: any, claimed: any)
	if not current or seg ~= current.seg then return end
	local t = resolveTap(player, claimed, "burst")
	if not t then return end
	local score = current.session:submitBurst(tostring(player.UserId), seg, t - current.open)
	if score then
		TapResult:FireClient(player, seg, score, GameConfig.labelFor(score))
	end
end)

Dismount.OnServerEvent:Connect(function(player: Player)
	if current then return end -- not during a race
	TrackScene.dismount(player.Character)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	if current and current.seg then
		current.session:dropSegment(tostring(player.UserId), current.seg)
	end
	task.defer(function()
		starterStats[player.UserId] = nil
		trackers[player.UserId] = nil -- session-only until DataStore (STATUS backlog)
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

-- Main loop -------------------------------------------------------------------
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

local function runRace(players: { Player })
	local rng = Random.new()
	local league = GameConfig.leagues[LEAGUE]
	local distances = league.distances or DISTANCES
	local cond = {
		distance = distances[rng:NextInteger(1, #distances)],
		surface = SURFACES[rng:NextInteger(1, #SURFACES)],
		weather = WEATHERS[rng:NextInteger(1, #WEATHERS)],
	}
	local humans = {}
	for _, p in players do
		local stats = starterStats[p.UserId] or { speed = 50, accel = 50, stamina = 50, grit = 50, focus = 50 }
		local rating = RaceRating.rating(stats, cond, 0.5, 0, nil, 0)
		table.insert(humans, { id = tostring(p.UserId), name = p.DisplayName, rating = rating, isBot = false })
	end
	local lanes = RaceSession.fillWithBots(humans, GameConfig.lanes, GameConfig, ThemePack, rng)
	local session = RaceSession.new({
		deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape },
		config = GameConfig,
		leagueName = LEAGUE,
		lanes = lanes,
		rng = rng,
	})
	applyIntegrity(session, players)

	-- Timeline (D-026, D-027, D-031): gate -> pace (2 checkpoints) -> into the homestretch:
	-- "FINAL BURST" -> burst -> stretch drive (pace, 1 checkpoint) -> the line.
	local cfg = TrackLayout.churchill
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

	TrackScene.dismountAll() -- anyone still sitting from the last race
	TrackScene.build(plan) -- rebuilt each race: the gate moves with the distance, models appear once approved
	RaceStarted:FireAllClients(LEAGUE, lanesSummary(session), tStart, cond, resultAt, burstOpen)
	PaceSchedule:FireAllClients(passes)
	task.delay(math.max(0, tStart - now()), TrackScene.openGate) -- and they're off
	local isBot = {}
	for i, lane in session.lanes do -- racing players ride their own horse as the jockey
		isBot[i] = lane.isBot
		if not lane.isBot then
			local p = Players:GetPlayerByUserId(tonumber(lane.id))
			if p then TrackScene.seatRider(i, p.Character) end
		end
	end
	TrackScene.addJockeys(isBot) -- Roblox-style jockeys on the bot horses

	local preLast, postLast = tStart, postStart
	for _, p in passes do
		if p.t0 < burstOpen then preLast = math.max(preLast, p.t1) else postLast = math.max(postLast, p.t1) end
	end
	current = {
		session = session, seg = 1, kind = "pace", open = tStart, close = preLast,
		taps = {}, allowances = snapshotAllowances(), maxTaps = #passes * 2 + 10,
	}
	-- Live chances shown on screen: closed segments, refreshed each second in the stretch drive.
	local shownLive = table.clone(session.live)
	local racing = true
	task.spawn(function()
		local period = 1 / GameConfig.offsetsPerSecond
		while racing do
			local w = RaceShape.blendWeight(now(), tFar, postEnd, GameConfig.raceShape.blendPower)
			RaceOffsets:FireAllClients(session:displayOffsets(shownLive, w, GameConfig.raceShape))
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
				partial[i] = (PaceMeter.score(done, current.taps[tonumber(lane.id)] or {}))
			end
		end
		shownLive = session:previewLive(seg, partial)
		LiveChances:FireAllClients(seg, shownLive)
	end

	local errors: { [number]: { number } } = {}
	local matched: { [number]: number } = {}
	for seg, kind in GameConfig.segments do
		current.seg = seg
		if kind == "pace" then
			if seg > 1 and GameConfig.segments[seg - 1] == "burst" then
				current.kind, current.open, current.close = "pace", postStart, postLast -- the stretch drive
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
			current.allowances = snapshotAllowances()
			for _, p in players do
				local res = session:scorePace(tostring(p.UserId), seg, current.taps[p.UserId] or {})
				if res then
					local list = errors[p.UserId] or {}
					for _, e in res.errors do table.insert(list, e) end
					errors[p.UserId] = list
					matched[p.UserId] = (matched[p.UserId] or 0) + res.matched
					PaceResult:FireClient(p, seg, res.score, GameConfig.labelFor(res.score))
				end
			end
		else
			waitUntil(burstOpen)
			current.kind, current.open, current.close = "burst", burstOpen, burstClose
			current.allowances = snapshotAllowances()
			BurstOpened:FireAllClients(seg, burstOpen, burstClose, session:burstSpec(), ThemePack.words.burst)
			waitUntil(burstClose + LATENCY_GRACE)
			current.kind = "pace" -- taps before the stretch drive opens are outside its window and dropped
			current.open, current.close = postStart, postLast
			local great = {}
			for _, p in players do
				local i = session:laneIndex(tostring(p.UserId))
				local s = i and session.lanes[i].scores[seg]
				if s and s >= 80 then table.insert(great, tostring(p.UserId)) end
			end
			if #great > 0 then BurstSparkle:FireAllClients(great) end
		end
		shownLive = session:closeSegment(seg)
		LiveChances:FireAllClients(seg, shownLive)
	end
	current.seg = nil

	local result = session:finish() -- by now the order on screen is this order (D-033)
	task.delay(GameConfig.runInSeconds + 2, function() racing = false end)
	local summary = {}
	for _, prize in result.prizes do
		local laneIdx = session:laneIndex(prize.id)
		local lane = session.lanes[laneIdx]
		table.insert(summary, { name = lane.name, place = prize.place, cash = prize.cash, isBot = prize.isBot, id = prize.id, lane = laneIdx })
		if not prize.isBot then
			local player = Players:GetPlayerByUserId(tonumber(prize.id))
			local stats = player and player:FindFirstChild("leaderstats")
			if stats then
				stats[ThemePack.currency.earned].Value += prize.cash
				stats["League Points"].Value += prize.leaguePoints
			end
		end
	end
	RaceFinished:FireAllClients(summary)
	-- Your ride: stars from your score, and places your riding gained versus riding at the race
	-- average (same luck, everything else the same). Only gains are shown to the rider.
	local S = session:scoresSoFar()
	local placeOf = {}
	for place, laneIdx in result.order do placeOf[laneIdx] = place end
	for _, p in players do
		local i = session:laneIndex(tostring(p.UserId))
		if i then
			local stars = if S[i] >= 85 then 3 elseif S[i] >= 65 then 2 elseif S[i] >= 40 then 1 else 0
			RideReport:FireClient(p, stars, session:ridingGain(i), placeOf[i])
		end
	end
	recordIntegrity(players, errors, matched)
	-- Riders stay on their horse for the results and replay; they press Done to get off.
	task.delay(GameConfig.dismountTimeoutSeconds, TrackScene.dismountAll)
	current = nil
end

task.delay(3, function()
	TrackScene.build(TrackLayout.plan(TrackLayout.churchill, TrackLayout.distances.Sprint)) -- a scene for the lobby
end)

while true do
	while #Players:GetPlayers() == 0 do task.wait(1) end
	local deadline = os.clock() + GameConfig.lobbyFillSeconds
	while os.clock() < deadline and #Players:GetPlayers() < GameConfig.lanes do
		LobbyStatus:FireAllClients(math.ceil(deadline - os.clock()))
		task.wait(1)
	end
	local racers = {}
	for _, p in Players:GetPlayers() do
		if #racers < GameConfig.lanes then table.insert(racers, p) end
	end
	if #racers > 0 then
		local ok, err = pcall(runRace, racers)
		if not ok then
			warn("Race failed: " .. tostring(err))
			current = nil
			TrackScene.dismountAll()
		end
	end
	task.wait(5) -- results screen
end
