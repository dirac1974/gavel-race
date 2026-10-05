--!nonstrict
-- SettingsService (D-042, D-045, D-049): the owner's own settings and the gentle extras.
--   Stable visits: Friends (default) or Nobody (D-042); the plot's walls follow it.
--   Break reminder: optional, off by default (D-045).
--   Sound: on by default; Off mutes the client's effects and announcer (Sound.luau).
--   Smart Steer: on by default; Off means your race horse changes lane only when you press ◀ ▶ (D-054).
--   Play time this week: counted while playing, shown in the For grown-ups panel (D-045).
--   The first-ten-minutes tour (D-049): each step finishes when the player does the thing
--   (Progress events); players can skip it.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tour = require(Shared:WaitForChild("Tour"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local SetSetting = Profiles.remote("SetSetting")   -- client -> server: key, value
local TourSkip = Profiles.remote("TourSkip")       -- client -> server
local BoardOpened = Profiles.remote("BoardOpened") -- client -> server: the Stable Board was opened (tour step)

local VISITS = { Friends = true, Nobody = true }
local last: { [Player]: number } = {}

local function week(t: number): number
	return (t // 86400 + 3) // 7
end

local function ensure(data)
	data.settings = data.settings or {}
	if data.settings.breakReminder == nil then data.settings.breakReminder = false end
	if typeof(data.playtime) ~= "table" then data.playtime = { week = week(os.time()), seconds = 0 } end
end

-- Older saves that already raced skip the tour.
Profiles.Loaded.Event:Connect(function(player: Player)
	local data = Profiles.get(player)
	if not data then return end
	ensure(data)
	if data.flags.tourStep == nil and not data.flags.tourDone and (data.totals.races or 0) > 0 then
		data.flags.tourDone = true
	end
	Profiles.changed(player)
end)

-- Tour steps finish on the same events as Stable Board jobs.
Progress.onRecord = function(player: Player, event: string)
	local data = Profiles.get(player)
	if not data or not data.flags.starterPicked then return end
	local _, moved = Tour.advance(data.flags, event)
	if moved then
		if data.flags.tourDone then Profiles.notify(player, "You're all set! Have fun with your horses 🐴", "heart") end
	end
end

Profiles.addDecorator(function(data, view)
	ensure(data)
	view.playtimeWeek = if data.playtime.week == week(os.time()) then data.playtime.seconds else 0
	view.settings.breakReminder = data.settings.breakReminder
end)

SetSetting.OnServerEvent:Connect(function(player: Player, key: any, value: any)
	if os.clock() - (last[player] or 0) < 0.3 then return end
	last[player] = os.clock()
	local data = Profiles.get(player)
	if not data then return end
	ensure(data)
	if key == "visits" and typeof(value) == "string" and VISITS[value] then
		data.settings.visits = value
	elseif key == "breakReminder" and typeof(value) == "boolean" then
		data.settings.breakReminder = value
	elseif key == "sound" and typeof(value) == "boolean" then
		data.settings.sound = value -- client Sound module; nil = on
	elseif key == "easyRein" and typeof(value) == "boolean" then
		data.settings.easyRein = value -- steering help on training courses (D-053); no score change
	elseif key == "smartSteer" and typeof(value) == "boolean" then
		data.settings.smartSteer = value -- Smart Steer in races (D-054); on by default
	elseif key == "shareGhost" and typeof(value) == "boolean" then
		data.settings.shareGhost = value -- friends here may see your training ghosts (D-053); off by default
	elseif key == "tour" and value == "restart" then
		data.flags.tourStep, data.flags.tourDone, data.flags.tourDid = 1, nil, nil
	else
		return
	end
	Profiles.changed(player)
end)

TourSkip.OnServerEvent:Connect(function(player: Player)
	local data = Profiles.get(player)
	if not data then return end
	Tour.skip(data.flags)
	Profiles.changed(player)
end)

BoardOpened.OnServerEvent:Connect(function(player: Player)
	if os.clock() - (last[player] or 0) < 0.3 then return end
	last[player] = os.clock()
	Progress.record(player, "board", 1)
end)

-- Count play time once a minute (it saves with the profile).
task.spawn(function()
	while true do
		task.wait(60)
		local w = week(os.time())
		for _, player in Players:GetPlayers() do
			local data = Profiles.get(player)
			if data then
				ensure(data)
				if data.playtime.week ~= w then data.playtime.week, data.playtime.seconds = w, 0 end
				data.playtime.seconds += 60
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player) last[player] = nil end)
