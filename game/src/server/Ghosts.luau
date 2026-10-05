--!nonstrict
-- Ghosts (D-053, T4): each player's best training ride per course, kept in its own DataStore
-- key (`ghosts_<userId>` in GiddyUp_Ghosts_v1) so profiles stay small. Loaded lazily (the first
-- time a ride needs it) with pcall and retries, never blocking the profile. Saving merges with
-- what's stored (the better run per course wins), so two servers can't overwrite a better
-- ghost and a failed load never wipes anything.
--   Ghosts.ensure(player)            start loading if needed; returns the entry
--   Ghosts.ready(player)             loaded (or given up on)?
--   Ghosts.run(player, course)       the best run kept in memory, or nil
--   Ghosts.offer(player, course, run) keep it if it's better; true if it was
-- A run: { score, seconds, t0, coat, horse, v, hz, q, n, d } (Ghost.encode plus who rode it).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ghost = require(Shared:WaitForChild("Ghost"))
local Profile = require(Shared:WaitForChild("Profile"))

local Ghosts = {}

local STORE_NAME = "GiddyUp_Ghosts_v1"
local ATTEMPTS = 3
local AUTOSAVE_SECONDS = 120

local store = nil
do
	local ok, res = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
	if ok then store = res else warn("[Ghosts] DataStore unavailable: " .. tostring(res)) end
end

-- [userId] = { state = "loading" | "ready" | "failed", runs = { [course] = run }, dirty }
local entries: { [number]: any } = {}

local function key(userId: number): string
	return "ghosts_" .. userId
end

local COURSES = {}
for _, c in Profile.COURSES do COURSES[c] = true end

-- Only well-formed runs on real courses survive a load.
local function clean(runs: any): { [string]: any }
	local out = {}
	if typeof(runs) ~= "table" then return out end
	for course, run in runs do
		if COURSES[course] and typeof(run) == "table" and typeof(run.score) == "number" and typeof(run.seconds) == "number"
			and Ghost.decode(run) ~= nil then
			out[course] = run
		end
	end
	return out
end

local function merge(into: { [string]: any }, from: { [string]: any })
	for course, run in from do
		if Ghost.better(run, into[course]) then into[course] = run end
	end
end

function Ghosts.ensure(player: Player)
	local id = player.UserId
	local e = entries[id]
	if e then return e end
	e = { state = "loading", runs = {}, dirty = false }
	entries[id] = e
	task.spawn(function()
		if not store then
			e.state = "failed"
			return
		end
		for attempt = 1, ATTEMPTS do
			local ok, res = pcall(function() return store:GetAsync(key(id)) end)
			if ok then
				if entries[id] ~= e then return end
				merge(e.runs, clean(typeof(res) == "table" and res.runs))
				e.state = "ready"
				return
			end
			warn(string.format("[Ghosts] load %d for %d failed: %s", attempt, id, tostring(res)))
			task.wait(2 ^ attempt)
		end
		e.state = "failed" -- ghosts this session stay in memory; saving still merges safely
	end)
	return e
end

function Ghosts.ready(player: Player): boolean
	local e = entries[player.UserId]
	return e ~= nil and e.state ~= "loading"
end

function Ghosts.run(player: Player, course: string): any?
	local e = entries[player.UserId]
	return e and e.runs[course]
end

function Ghosts.offer(player: Player, course: string, run: any): boolean
	if not COURSES[course] then return false end
	local e = Ghosts.ensure(player)
	if not Ghost.better(run, e.runs[course]) then return false end
	e.runs[course] = run
	e.dirty = true
	return true
end

local function save(userId: number)
	local e = entries[userId]
	if not e or not e.dirty or not store then return end
	local mine = e.runs
	local ok, err = pcall(function()
		store:UpdateAsync(key(userId), function(old)
			local runs = clean(typeof(old) == "table" and old.runs)
			merge(runs, mine) -- keep the better run per course, whoever saved it
			return { v = 1, runs = runs }, { userId }
		end)
	end)
	if ok then e.dirty = false else warn("[Ghosts] save for " .. userId .. " failed: " .. tostring(err)) end
end
Ghosts.save = save

Players.PlayerRemoving:Connect(function(player: Player)
	local id = player.UserId
	save(id)
	entries[id] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for id, e in entries do
			if e.dirty then task.spawn(save, id) end
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for id, e in entries do
		if e.dirty then
			pending += 1
			task.spawn(function()
				save(id)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 20
	while pending > 0 and os.clock() < deadline do task.wait(0.2) end
end)

return Ghosts
