--!nonstrict
-- RaceService: Phase 1 prototype race loop.
-- Everyone in the server races together (up to 8), bots fill the rest.
-- All scoring and the finish draw happen here; clients only send tap times.
-- Prototype limits: no saving (leaderstats only), no parties, starter ratings.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceMath = require(Shared:WaitForChild("RaceMath"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ThemePack = require(Shared:WaitForChild("ThemePack"))
local GavelMeter = require(Shared:WaitForChild("GavelMeter"))
local RaceSession = require(Shared:WaitForChild("RaceSession"))

local LEAGUE = "Rookie" -- prototype: one league
local COUNTDOWN = 3
local LATENCY_GRACE = 0.35 -- wait after a window closes for late packets

local remotes = Instance.new("Folder")
remotes.Name = "GavelRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local LobbyStatus = makeRemote("LobbyStatus")   -- server -> all: seconds until start
local RaceStarted = makeRemote("RaceStarted")   -- server -> all: lanes, chances, purses
local WindowOpened = makeRemote("WindowOpened") -- server -> all: window, open, close, meter spec
local TapResult = makeRemote("TapResult")       -- server -> one: score, label
local LiveChances = makeRemote("LiveChances")   -- server -> all: chances after a window
local RaceFinished = makeRemote("RaceFinished") -- server -> all: results
local Tap = makeRemote("Tap")                   -- client -> server: window, claimed server time

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Prototype player state ----------------------------------------------------
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
	player:SetAttribute("RacerRating", 50 + math.random(-5, 5))
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in Players:GetPlayers() do setupPlayer(p) end

-- Race state shared with the Tap handler ------------------------------------
local current = nil -- { session, windows = { {open, close} }, activeWindow }

Tap.OnServerEvent:Connect(function(player: Player, window: any, claimed: any)
	if not current or typeof(window) ~= "number" or typeof(claimed) ~= "number" then return end
	if window ~= current.activeWindow then return end
	local w = current.windows[window]
	local arrival = now()
	local t = GavelMeter.resolveTapTime(claimed, arrival, w.open, w.close, GameConfig.maxTapRewindSeconds)
	if not t then return end
	local score = current.session:submitTap(tostring(player.UserId), window, t - w.open)
	if score then
		TapResult:FireClient(player, window, score, GameConfig.labelFor(score))
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	if current and current.activeWindow then
		current.session:dropWindow(tostring(player.UserId), current.activeWindow)
	end
end)

-- Main loop -------------------------------------------------------------------
local function lanesSummary(session)
	local out = {}
	for i, lane in session.lanes do
		out[i] = { id = lane.id, name = lane.name, isBot = lane.isBot, chance = session.q[i], purse = session.purses[i] }
	end
	return out
end

local function runRace(players: { Player })
	local rng = Random.new()
	local humans = {}
	for _, p in players do
		table.insert(humans, { id = tostring(p.UserId), name = p.DisplayName, rating = p:GetAttribute("RacerRating") or 50, isBot = false })
	end
	local lanes = RaceSession.fillWithBots(humans, GameConfig.lanes, GameConfig, ThemePack, rng)
	local session = RaceSession.new({
		deps = { RaceMath = RaceMath, GavelMeter = GavelMeter },
		config = GameConfig,
		leagueName = LEAGUE,
		lanes = lanes,
		rng = rng,
	})
	local league = GameConfig.leagues[LEAGUE]
	local start = now() + COUNTDOWN
	local windows = {}
	for w = 1, GameConfig.windowsPerRace do
		local open = start + w * GameConfig.windowGapSeconds + (w - 1) * league.windowSeconds
		windows[w] = { open = open, close = open + league.windowSeconds }
	end
	current = { session = session, windows = windows, activeWindow = nil }
	RaceStarted:FireAllClients(LEAGUE, lanesSummary(session), start)

	for w = 1, GameConfig.windowsPerRace do
		task.wait(math.max(0, windows[w].open - now()))
		current.activeWindow = w
		WindowOpened:FireAllClients(w, windows[w].open, windows[w].close, session:meterSpec(w), ThemePack.windows[w])
		task.wait(math.max(0, windows[w].close + LATENCY_GRACE - now()))
		current.activeWindow = nil
		LiveChances:FireAllClients(w, session:closeWindow(w))
	end

	task.wait(2) -- final stretch animation time
	local result = session:finish()
	local summary = {}
	for _, payout in result.payouts do
		local lane = session.lanes[session:laneIndex(payout.id)]
		table.insert(summary, { name = lane.name, place = payout.place, cash = payout.cash, isBot = payout.isBot, id = payout.id })
		if not payout.isBot then
			local player = Players:GetPlayerByUserId(tonumber(payout.id))
			local stats = player and player:FindFirstChild("leaderstats")
			if stats then
				stats[ThemePack.currency.earned].Value += payout.cash
				stats["League Points"].Value += payout.leaguePoints
			end
		end
	end
	RaceFinished:FireAllClients(summary)
	current = nil
end

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
		end
	end
	task.wait(5) -- results screen
end
