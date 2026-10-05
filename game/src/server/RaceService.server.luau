--!nonstrict
-- RaceService: Phase 1 prototype race loop.
-- Everyone in the server races together (up to 8), bots fill the rest.
-- Each race: three Giddy-up stretches (tap on the horse's stride), then the Final
-- Burst (one tap on a sweeping meter, counts double) (D-022).
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
local Stride = require(Shared:WaitForChild("Stride"))
local TapTime = require(Shared:WaitForChild("TapTime"))
local Integrity = require(Shared:WaitForChild("Integrity"))
local RaceSession = require(Shared:WaitForChild("RaceSession"))
local RaceRating = require(Shared:WaitForChild("RaceRating"))
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
local RaceStarted = makeRemote("RaceStarted")     -- server -> all: league, lanes, start, conditions
local StretchOpened = makeRemote("StretchOpened") -- server -> all: seg, beat times, name, half window
local StretchResult = makeRemote("StretchResult") -- server -> one: seg, score, label
local BurstOpened = makeRemote("BurstOpened")     -- server -> all: seg, open, close, meter spec, name
local TapResult = makeRemote("TapResult")         -- server -> one: seg, burst score, label
local LiveChances = makeRemote("LiveChances")     -- server -> all: seg, chances after it
local RaceFinished = makeRemote("RaceFinished")   -- server -> all: results
local IntegrityNote = makeRemote("IntegrityNote") -- server -> one: private note (D-022 flag 2)
local BurstSparkle = makeRemote("BurstSparkle")   -- server -> all: lane ids with a Great+ burst (small badge sparkle)
local StrideTap = makeRemote("StrideTap")         -- client -> server: seg, claimed server time
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
-- { session, seg, kind ("stride" | "burst" | nil when closed), open, close,
--   taps = { [userId] = {times} }, allowances = { [userId] = seconds } }
local current = nil

-- Latency is snapshotted when a segment opens so a lag spike mid-segment can't widen it (D-021).
local function snapshotAllowances(): { [number]: number }
	local out = {}
	for _, p in Players:GetPlayers() do
		out[p.UserId] = TapTime.rewindAllowance(p:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	end
	return out
end

local function resolveTap(player: Player, seg: any, claimed: any, kind: string): number?
	if not current or current.kind ~= kind or seg ~= current.seg or typeof(claimed) ~= "number" then return nil end
	local allowance = current.allowances[player.UserId]
		or TapTime.rewindAllowance(player:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	return TapTime.resolve(claimed, now(), current.open, current.close, allowance)
end

StrideTap.OnServerEvent:Connect(function(player: Player, seg: any, claimed: any)
	local t = resolveTap(player, seg, claimed, "stride")
	if not t then return end
	local list = current.taps[player.UserId]
	if not list then
		list = {}
		current.taps[player.UserId] = list
	end
	if #list < GameConfig.stride.beats * GameConfig.stride.maxTapsPerBeat + 4 then
		table.insert(list, t)
	end
end)

BurstTap.OnServerEvent:Connect(function(player: Player, seg: any, claimed: any)
	local t = resolveTap(player, seg, claimed, "burst")
	if not t then return end
	local score = current.session:submitBurst(tostring(player.UserId), seg, t - current.open)
	if score then
		TapResult:FireClient(player, seg, score, GameConfig.labelFor(score))
	end
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

-- Integrity (D-022) ------------------------------------------------------------
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

local function recordIntegrity(players: { Player }, gaps: { [number]: { number } }, matched: { [number]: number })
	local cfg = GameConfig.integrity
	for _, p in players do
		local tr = trackers[p.UserId]
		if tr then
			Integrity.addRace(tr, gaps[p.UserId] or {}, matched[p.UserId] or 0, today())
			local spread = Integrity.spread(tr)
			if Integrity.check(tr, today(), cfg) then
				local strikes = Integrity.activeStrikes(tr, today(), cfg)
				local action = Integrity.action(strikes, cfg)
				print(string.format("[Integrity] %s (%d): strike %d, gap spread %.1f ms, action %s",
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

-- How long the race runs from the gate to the Final Burst closing, so clients can pace
-- the horses round the lap (stretch tempos are picked later, so this uses the midpoint).
local function expectedDuration(league): number
	local d, s = 0, GameConfig.stride
	for _, kind in GameConfig.segments do
		d += GameConfig.windowGapSeconds
		if kind == "stride" then
			d += s.leadInSeconds + (s.beats - 1) * (league.strideIntervalLo + league.strideIntervalHi) / 2
				+ s.halfWindowSeconds + LATENCY_GRACE
		else
			d += league.windowSeconds + LATENCY_GRACE
		end
	end
	return d
end

local function waitUntil(t: number)
	task.wait(math.max(0, t - now()))
end

local function runRace(players: { Player })
	local rng = Random.new()
	local cond = {
		distance = DISTANCES[rng:NextInteger(1, #DISTANCES)],
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
		deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, Stride = Stride },
		config = GameConfig,
		leagueName = LEAGUE,
		lanes = lanes,
		rng = rng,
	})
	applyIntegrity(session, players)
	TrackScene.build() -- rebuilt each race so models appear as soon as moderation clears them
	local league = GameConfig.leagues[LEAGUE]
	local strideCfg = GameConfig.stride
	current = { session = session, seg = nil, kind = nil, taps = {}, allowances = {} }
	local t = now() + COUNTDOWN
	RaceStarted:FireAllClients(LEAGUE, lanesSummary(session), t, cond, t + expectedDuration(league))
	task.delay(math.max(0, t - now()), TrackScene.openGate) -- and they're off
	-- Racing players ride their own horse as the jockey.
	for i, lane in session.lanes do
		if not lane.isBot then
			local p = Players:GetPlayerByUserId(tonumber(lane.id))
			if p then TrackScene.seatRider(i, p.Character) end
		end
	end

	local gaps: { [number]: { number } } = {}
	local matched: { [number]: number } = {}
	for seg, kind in GameConfig.segments do
		t += GameConfig.windowGapSeconds
		waitUntil(t)
		current.seg, current.taps, current.allowances = seg, {}, snapshotAllowances()
		if kind == "stride" then
			local beats = session:openStretch(seg, t + strideCfg.leadInSeconds)
			current.open, current.close = t, beats[#beats] + strideCfg.halfWindowSeconds
			current.kind = "stride"
			StretchOpened:FireAllClients(seg, beats, ThemePack.windows[seg] or "", strideCfg.halfWindowSeconds)
			waitUntil(current.close + LATENCY_GRACE)
			current.kind = nil
			for _, p in players do
				local res = session:scoreStretch(tostring(p.UserId), seg, current.taps[p.UserId] or {})
				if res then
					local list = gaps[p.UserId] or {}
					for _, e in res.gapErrors do table.insert(list, e) end
					gaps[p.UserId] = list
					matched[p.UserId] = (matched[p.UserId] or 0) + res.matched
					StretchResult:FireClient(p, seg, res.score, GameConfig.labelFor(res.score, GameConfig.stretchLabels))
				end
			end
		else
			local spec = session:burstSpec()
			current.open, current.close = t, t + league.windowSeconds
			current.kind = "burst"
			BurstOpened:FireAllClients(seg, current.open, current.close, spec, ThemePack.words.burst)
			waitUntil(current.close + LATENCY_GRACE)
			current.kind = nil
			local great = {}
			for _, p in players do
				local i = session:laneIndex(tostring(p.UserId))
				local s = i and session.lanes[i].scores[seg]
				if s and s >= 80 then table.insert(great, tostring(p.UserId)) end
			end
			if #great > 0 then BurstSparkle:FireAllClients(great) end
		end
		local live = session:closeSegment(seg)
		LiveChances:FireAllClients(seg, live)
		t = current.close + LATENCY_GRACE
	end
	current.seg = nil

	local result = session:finish() -- clients run the horses home in this order, then show results
	local summary = {}
	for _, prize in result.prizes do
		local lane = session.lanes[session:laneIndex(prize.id)]
		table.insert(summary, { name = lane.name, place = prize.place, cash = prize.cash, isBot = prize.isBot, id = prize.id,
			lane = session:laneIndex(prize.id) })
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
	recordIntegrity(players, gaps, matched)
	task.delay(GameConfig.runInSeconds + 3, TrackScene.dismountAll) -- run-in, results, then off the horse
	current = nil
end

task.delay(3, TrackScene.build) -- a scene to look at in the lobby

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
