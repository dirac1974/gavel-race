--!nonstrict
-- FanService (D-019, D-020, D-041): spectators cheering and clapping along.
--   Cheer: anyone not riding in a race picks one horse before its first checkpoint closes.
--   Clap Along: cheered fans clap on the race's hoofbeats (tempo per race, drifting); before
--   each segment closes, every lane's crowd (best fan + small assists) becomes a tiny boost.
--   After the race: Fan XP (cosmetic, capped) and a Top Fans board, separate from results.
--   Fans whose claps are inhumanly steady count zero for the rest of the race, quietly, and get
--   a strike: 2nd = a private gentle note, 3rd = fan play off for 30 days; strikes expire
--   after 90 days. Never shown to others; riding is never affected.
-- RaceService calls start / beforeClose / finish; clients use the Cheer and ClapTap remotes.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fans = require(Shared:WaitForChild("Fans"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TapTime = require(Shared:WaitForChild("TapTime"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Style = require(Shared:WaitForChild("Style"))

local FanService = {}

local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local function remote(name: string): RemoteEvent
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end
local Cheer = remote("Cheer")             -- client -> server: course, lane
local ClapTap = remote("ClapTap")         -- client -> server: course, claimed server time
local ClapBeats = remote("ClapBeats")     -- server -> all: course, beats (server times)
local FanStatus = remote("FanStatus")     -- server -> one: course, cheered lane (or nil), message
local TopFans = remote("TopFans")         -- server -> all: course, top five; server -> one: your rank and Fan XP

local STRIKE_EXPIRY = 90 * 86400
local BAN_SECONDS = 30 * 86400
local MAX_CLAPS = 600

-- races[course] = { session, riders = {[Player]=true}, cheers = {[Player]=lane}, claps = {[Player]={t}},
--                   beats, tStart, tEnd, cheerOpen, flagged = {[Player]=true} }
local races: { [string]: any } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function fanData(player: Player)
	local data = Profiles.get(player)
	if not data then return nil end
	if typeof(data.fan) ~= "table" then data.fan = {} end
	local f = data.fan
	f.xp = tonumber(f.xp) or 0
	f.day = tonumber(f.day) or -1
	f.dayXp = tonumber(f.dayXp) or 0
	f.strikes = if typeof(f.strikes) == "table" then f.strikes else {}
	f.banUntil = tonumber(f.banUntil) or 0
	return f, data
end

local function activeStrikes(f, t: number): number
	local last = f.strikes[#f.strikes]
	if not last or t - last >= STRIKE_EXPIRY then return 0 end
	return #f.strikes
end

function FanService.start(courseId: string, session, riders: { Player }, tStart: number, tEnd: number)
	local riderSet = {}
	for _, p in riders do riderSet[p] = true end
	local beats = Fans.beats(Random.new(), tStart, tEnd, 0.55, 0.03)
	races[courseId] = {
		session = session, riders = riderSet, cheers = {}, claps = {}, beats = beats,
		tStart = tStart, tEnd = tEnd, cheerOpen = true, flagged = {},
	}
	ClapBeats:FireAllClients(courseId, beats)
end

-- Before segment `seg` closes: crowd per lane from the claps so far, as the session's boost.
function FanService.beforeClose(courseId: string, seg: number)
	local r = races[courseId]
	if not r then return end
	if seg == 1 then r.cheerOpen = false end -- cheers lock at the first checkpoint
	local t = now()
	local beatsSoFar = {}
	for _, b in r.beats do
		if b <= t then table.insert(beatsSoFar, b) end
	end
	table.clear(r.session.crowd) -- rebuilt from the fans who still count (a flagged fan's boost ends now)
	local byLane: { [number]: { number } } = {}
	for player, lane in r.cheers do
		if player.Parent and not r.flagged[player] then
			local claps = r.claps[player] or {}
			if Fans.flagged(beatsSoFar, claps) then
				r.flagged[player] = true -- quietly counts zero from now on
			else
				byLane[lane] = byLane[lane] or {}
				table.insert(byLane[lane], Fans.clapScore(beatsSoFar, claps))
			end
		end
	end
	for lane, scores in byLane do
		r.session:setCrowd(lane, Fans.boost(Fans.crowd(scores)))
	end
end

-- After the race: Fan XP, Top Fans, strikes.
function FanService.finish(courseId: string, winnerLane: number)
	local r = races[courseId]
	races[courseId] = nil
	if not r then return end
	for player in r.cheers do -- flags come down when the race ends
		local head = player.Character and player.Character:FindFirstChild("Head")
		local flag = head and head:FindFirstChild("FanFlag")
		if flag then task.delay(8, function() if flag.Parent then flag:Destroy() end end) end
	end
	local session = r.session
	local entries = {}
	local t = os.time()
	for player, lane in r.cheers do
		if player.Parent then
			local claps = r.claps[player] or {}
			local score = Fans.clapScore(r.beats, claps)
			local flagged = r.flagged[player] or Fans.flagged(r.beats, claps)
			local laneData = session.lanes[lane]
			table.insert(entries, { id = tostring(player.UserId), name = player.DisplayName, horse = laneData and laneData.name or "",
				score = math.floor(score + 0.5), flagged = flagged, player = player, lane = lane })
		end
	end
	local top = Fans.topFans(entries)
	local board = {}
	for _, e in top do table.insert(board, { name = e.name, horse = e.horse, score = e.score }) end
	if #board > 0 then TopFans:FireAllClients(courseId, board) end
	for _, e in entries do
		local f = fanData(e.player)
		if f then
			local today = t // 86400
			if f.day ~= today then f.day, f.dayXp = today, 0 end
			local scores = {}
			local laneData = session.lanes[e.lane]
			for seg in GameConfig.segments do
				local s = laneData and laneData.scores[seg]
				if s then table.insert(scores, s) end
			end
			local xp = Fans.raceXp(scores, e.lane == winnerLane, f.dayXp)
			local levelBefore = Fans.level(f.xp)
			f.xp += xp
			f.dayXp += xp
			local _, profile = fanData(e.player)
			for _ = levelBefore + 1, Fans.level(f.xp) do
				Style.earn(profile, Style.EARN_FAN_LEVEL) -- a milestone gift per Fan level (D-050)
			end
			if e.flagged then -- one strike per race at most
				local last = f.strikes[#f.strikes]
				if last and t - last >= STRIKE_EXPIRY then table.clear(f.strikes) end -- 90 days without a flag
				table.insert(f.strikes, t)
				local n = activeStrikes(f, t)
				if n == 2 then
					Profiles.notify(e.player, "Your claps looked automatic, so they didn't count. Auto-clickers or scripts can turn off fan play.", "heart")
				elseif n >= 3 then
					f.banUntil = t + BAN_SECONDS
				end
			end
			TopFans:FireClient(e.player, courseId, nil, Fans.rankOf(entries, e.id), xp, Fans.level(f.xp), Fans.level(f.xp) > levelBefore)
			Progress.record(e.player, "cheer", 1)
			Profiles.changed(e.player)
		end
	end
end

function FanService.abort(courseId: string)
	races[courseId] = nil
end

Cheer.OnServerEvent:Connect(function(player: Player, courseId: any, lane: any)
	local r = typeof(courseId) == "string" and races[courseId]
	if not r or typeof(lane) ~= "number" or not r.cheerOpen then return end
	if r.riders[player] or r.cheers[player] or player:GetAttribute("Racing") then return end
	for otherId, other in races do
		if otherId ~= courseId and (other.cheers[player] or other.riders[player]) then return end
	end
	local laneData = r.session.lanes[lane]
	if not laneData or laneData.isBot then return end -- bots never have fans (D-020)
	local f = fanData(player)
	if f and f.banUntil > os.time() then
		FanStatus:FireClient(player, courseId, nil, "Fan play is resting for now. You can still ride!")
		return
	end
	r.cheers[player] = lane
	FanStatus:FireClient(player, courseId, lane, "Cheering for " .. r.session.lanes[lane].name .. "!")
	-- Your fan flag (earned with Fan levels) over your head while the race runs.
	local data = Profiles.get(player)
	local flag = data and Style.worn(data, "fan")
	local head = player.Character and player.Character:FindFirstChild("Head")
	if flag and head and not head:FindFirstChild("FanFlag") then
		local bb = Instance.new("BillboardGui")
		bb.Name = "FanFlag"
		bb.Size = UDim2.fromOffset(36, 36)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 120
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Text = flag.emoji
		t.Parent = bb
		bb.Parent = head
		task.delay(240, function() if bb.Parent then bb:Destroy() end end)
	end
end)

ClapTap.OnServerEvent:Connect(function(player: Player, courseId: any, claimed: any)
	local r = typeof(courseId) == "string" and races[courseId]
	if not r or not r.cheers[player] or typeof(claimed) ~= "number" then return end
	local allowance = TapTime.rewindAllowance(player:GetNetworkPing(), GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
	local t = TapTime.resolve(claimed, now(), r.tStart, r.tEnd, allowance)
	if not t then return end
	local list = r.claps[player]
	if not list then
		list = {}
		r.claps[player] = list
	end
	if #list < math.min(MAX_CLAPS, 2 * #r.beats) then table.insert(list, t) end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	for _, r in races do
		r.cheers[player], r.claps[player], r.flagged[player] = nil, nil, nil
	end
end)

return FanService
