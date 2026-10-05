--!nonstrict
-- JobService (D-043): Stable Board jobs on the server. Rolls sets over (auto-claiming any
-- finished rewards), counts a visit per day and trips to the Trail meadow, and handles Claim
-- and the free daily Swap. Adds the jobs and garden readiness to the owner's profile view.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Jobs = require(Shared:WaitForChild("Jobs"))
local Care = require(Shared:WaitForChild("Care"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local JobClaim = Profiles.remote("JobClaim")     -- client -> server: kind, index
local JobReroll = Profiles.remote("JobReroll")   -- client -> server: daily index

local TRAIL_COOLDOWN = 10 * 60
local trailAt: { [Player]: number } = {}
local last: { [Player]: number } = {}

Profiles.decorate = function(data, view)
	view.jobs = Jobs.view(data)
	local now = os.time()
	for i, b in view.garden or {} do
		b.ready = b.seed ~= "" and Care.cropProgress(data.garden[i], now) >= 1
	end
end

Profiles.Loaded.Event:Connect(function(player: Player)
	local data = Profiles.get(player)
	if not data then return end
	local now = os.time()
	local auto = Jobs.refresh(data, player.UserId, now)
	if auto > 0 then
		Profiles.notify(player, string.format("Welcome back! %d finished job%s paid out while you were away", auto, if auto == 1 then "" else "s"), "gift")
	end
	-- One "day" a day for the weekly and monthly visit jobs (days played, never in a row).
	local today = now // 86400
	if data.jobs.dayCounted ~= today then
		data.jobs.dayCounted = today
		Progress.record(player, "day", 1)
	else
		Profiles.changed(player)
	end
end)

local function busy(player: Player): boolean
	if os.clock() - (last[player] or 0) < 0.3 then return true end
	last[player] = os.clock()
	return false
end

JobClaim.OnServerEvent:Connect(function(player: Player, kind: any, index: any)
	if busy(player) or typeof(kind) ~= "string" or typeof(index) ~= "number" then return end
	local data = Profiles.get(player)
	if not data then return end
	local ok, def = Jobs.claim(data, player.UserId, kind, index, os.time())
	if ok and def then
		Profiles.notify(player, "Reward collected!", "gift")
		Profiles.changed(player)
	end
end)

JobReroll.OnServerEvent:Connect(function(player: Player, index: any)
	if busy(player) or typeof(index) ~= "number" then return end
	local data = Profiles.get(player)
	if not data then return end
	if Jobs.reroll(data, player.UserId, index, os.time()) then
		Profiles.notify(player, "New job on your board!", "clipboard")
		Profiles.changed(player)
	end
end)

-- Rolling over at midnight (UTC) for players who stay on: refresh now and then.
task.spawn(function()
	while true do
		task.wait(3)
		local now = os.time()
		local m = WorldLayout.meadow
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(m.x, 0, m.z)).Magnitude < m.radius then
				if now - (trailAt[player] or 0) > TRAIL_COOLDOWN then
					trailAt[player] = now
					Progress.record(player, "visit_trail", 1)
					Profiles.notify(player, "What a pretty meadow!", "map_trail")
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local data = Profiles.get(player)
			if data and data.jobs and data.jobs.dailyPeriod ~= Jobs.periods(now).daily then
				local auto = Jobs.refresh(data, player.UserId, now)
				if auto > 0 then Profiles.notify(player, "New day! Yesterday's finished jobs paid out", "gift") end
				data.jobs.dayCounted = now // 86400
				Progress.record(player, "day", 1)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	trailAt[player] = nil
	last[player] = nil
end)
