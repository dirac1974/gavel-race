--!nonstrict
-- Profiles: loads, locks and saves each player's profile (Profile.luau) in one DataStore
-- key, and keeps the owner's client in sync. Other server scripts use:
--   Profiles.get(player) -> profile or nil      Profiles.changed(player) after any edit
--   Profiles.whenLoaded(player) -> profile      Profiles.Loaded / Profiles.Changed (player)
-- Events pass only the player (BindableEvents copy tables): call Profiles.get for the data.
-- Session lock: each save carries { session, at }, where session is a fresh id per load (so
-- a rejoin on the same server can't reuse the old session's lock). A server refuses a
-- profile whose lock is fresh and retries; autosave refreshes the lock, and a lock older
-- than LOCK_STALE is treated as a crashed server's and taken over.
-- In Studio without API access the player gets a temporary profile that is never saved.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Profile = require(Shared:WaitForChild("Profile"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local STORE_NAME = "GiddyUp_Profiles_v1"
local LOCK_STALE = 5 * 60
local LOAD_ATTEMPTS = 6
local AUTOSAVE_SECONDS = 60
local SYNC_MIN_GAP = 0.2
local REQUEST_GAP = 0.5

local Profiles = {}
Profiles.Loaded = Instance.new("BindableEvent")   -- (player)
Profiles.Changed = Instance.new("BindableEvent")  -- (player)

local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "GameRemotes"
	remotes.Parent = ReplicatedStorage
end
Profiles.remotes = remotes

function Profiles.remote(name: string): RemoteEvent
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end

local ProfileSync = Profiles.remote("ProfileSync")   -- server -> owner: profile view
local RequestSync = Profiles.remote("RequestSync")   -- client -> server: send my view now
local Notice = Profiles.remote("Notice")             -- server -> one: short friendly message (toast)

local store = nil
do
	local ok, res = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
	if ok then store = res else warn("[Profiles] DataStores unavailable: " .. tostring(res)) end
end

-- [Player] = { data, session, temporary, dirty, edits, releasing, syncQueued, lastSync, lockRefresh }
local entries: { [Player]: any } = {}
local waiting: { [Player]: { thread } } = {}

local function key(userId: number): string
	return "u" .. userId
end

local function now(): number
	return os.time()
end

local function sendSync(player: Player)
	local e = entries[player]
	if not e or not player.Parent then return end
	e.syncQueued = false
	e.lastSync = os.clock()
	ProfileSync:FireClient(player, Profile.view(e.data, now(), GameConfig.energy))
end

-- Mark a profile edited: it saves on the next autosave and the client gets a fresh view.
function Profiles.changed(player: Player)
	local e = entries[player]
	if not e then return end
	e.dirty = true
	e.edits += 1
	Profiles.Changed:Fire(player)
	if e.syncQueued then return end
	e.syncQueued = true
	task.delay(math.max(0, SYNC_MIN_GAP - (os.clock() - (e.lastSync or 0))), sendSync, player)
end

function Profiles.get(player: Player)
	local e = entries[player]
	return e and e.data
end

function Profiles.isTemporary(player: Player): boolean
	local e = entries[player]
	return e ~= nil and e.temporary
end

function Profiles.whenLoaded(player: Player, timeout: number?)
	local e = entries[player]
	if e then return e.data end
	local list = waiting[player] or {}
	waiting[player] = list
	local thread = coroutine.running()
	table.insert(list, thread)
	if timeout then
		task.delay(timeout, function()
			local l = waiting[player]
			local i = l and table.find(l, thread)
			if i then
				table.remove(l, i)
				task.spawn(thread, nil)
			end
		end)
	end
	return coroutine.yield()
end

local function isNoAccessError(err: any): boolean
	local s = tostring(err)
	return string.find(s, "StudioAccessToApisNotAllowed") ~= nil or string.find(s, "403") ~= nil
		or string.find(s, "not allowed") ~= nil
end

local function lockIsLive(lock: any, session: string?): boolean
	return lock ~= nil and lock.session ~= session and now() - (tonumber(lock.at) or 0) < LOCK_STALE
end

-- Load and lock. Returns (data, session, temporary), or nil if a live session holds the save.
local function load(userId: number): (any, string?, boolean)
	if not store then return Profile.new(now()), nil, true end
	local session = HttpService:GenerateGUID(false)
	for attempt = 1, LOAD_ATTEMPTS do
		local mine, data = false, nil
		local ok, err = pcall(function()
			local value = store:UpdateAsync(key(userId), function(old)
				mine, data = false, nil -- the transform can run more than once; the last run counts
				if old and lockIsLive(old.lock, session) then
					return nil -- another live session has it; try again shortly
				end
				mine, data = true, Profile.migrate(old and old.data, now())
				return { data = data, lock = { session = session, job = game.JobId, at = now() } }, { userId }
			end)
			if value == nil then mine = false end
		end)
		if ok and mine and data then
			return data, session, false
		elseif not ok and RunService:IsStudio() and isNoAccessError(err) then
			warn("[Profiles] DataStore access is off in Studio: using a temporary profile. " .. tostring(err))
			return Profile.new(now()), nil, true
		elseif not ok then
			warn(string.format("[Profiles] load attempt %d for %d failed: %s", attempt, userId, tostring(err)))
		end
		task.wait(math.min(2 ^ attempt, 20))
	end
	return nil, nil, false
end

-- Save; release = drop the lock (player leaving). Never writes over another session's lock,
-- and an ordinary autosave never re-takes a lock that has been released.
local function save(player: Player, e: any, release: boolean): boolean
	if e.temporary or not store then return true end
	local data = e.data
	local edits = e.edits
	data.lastSeen = now()
	local wrote = false
	local ok, err = pcall(function()
		store:UpdateAsync(key(player.UserId), function(old)
			wrote = false
			if not release and (e.releasing or entries[player] ~= e) then return nil end
			local lock = old and old.lock
			if lock and lock.session ~= e.session then
				-- Someone else holds (or held) it; never overwrite their data.
				if lockIsLive(lock, e.session) then warn("[Profiles] save skipped: another session owns " .. key(player.UserId)) end
				return nil
			end
			wrote = true
			return { data = data, lock = if release then nil else { session = e.session, job = game.JobId, at = now() } }, { player.UserId }
		end)
	end)
	if ok and wrote and e.edits == edits then
		e.dirty = false
	elseif not ok then
		warn("[Profiles] save failed for " .. player.UserId .. ": " .. tostring(err))
	end
	return ok and wrote
end

local function onPlayerAdded(player: Player)
	local data, session, temporary = load(player.UserId)
	if not player.Parent then
		-- Left while loading: release the lock we took.
		if data and session and store then
			pcall(function()
				store:UpdateAsync(key(player.UserId), function(old)
					if old and old.lock and old.lock.session == session then
						old.lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return
	end
	if not data then
		player:Kick("Your stable is still open in another server. Please rejoin in a minute!")
		return
	end
	Profile.touchDay(data, now())
	entries[player] = {
		data = data, session = session, temporary = temporary, dirty = true, edits = 1, releasing = false,
		syncQueued = false, lastSync = 0, lockRefresh = os.clock(),
	}
	player:SetAttribute("ProfileLoaded", true)
	if temporary then player:SetAttribute("TemporaryProfile", true) end
	sendSync(player)
	Profiles.Loaded:Fire(player)
	local list = waiting[player]
	waiting[player] = nil
	for _, thread in list or {} do task.spawn(thread, data) end
end

local function onPlayerRemoving(player: Player)
	local e = entries[player]
	if e then
		e.releasing = true
		save(player, e, true)
		entries[player] = nil
	end
	local list = waiting[player]
	waiting[player] = nil
	for _, thread in list or {} do task.spawn(thread, nil) end
end

local lastRequest: { [Player]: number } = {}

function Profiles.start()
	RequestSync.OnServerEvent:Connect(function(player: Player)
		if os.clock() - (lastRequest[player] or 0) < REQUEST_GAP then return end
		lastRequest[player] = os.clock()
		if entries[player] then sendSync(player) end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		onPlayerRemoving(player)
	end)
	for _, p in Players:GetPlayers() do task.spawn(onPlayerAdded, p) end
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, e in entries do
				-- Save edited profiles; refresh the lock on unedited ones every couple of minutes.
				if e.dirty or os.clock() - e.lockRefresh > LOCK_STALE / 2 then
					e.lockRefresh = os.clock()
					task.spawn(save, player, e, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		if not store then return end
		local pending = 0
		for player, e in entries do
			pending += 1
			task.spawn(function()
				e.releasing = true
				save(player, e, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.2) end
	end)
end

function Profiles.notify(player: Player, text: string, icon: string?)
	Notice:FireClient(player, text, icon)
end

return Profiles
