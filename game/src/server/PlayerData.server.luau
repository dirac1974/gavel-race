--!nonstrict
-- PlayerData: starts profile loading/saving (Profiles) and handles the owner's requests
-- about their own horses: the starter pick and name (D-037), and choosing the active horse.
-- Also mirrors Green Cash and wins into leaderstats for the player list.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Profile = require(Shared:WaitForChild("Profile"))
local Horse = require(Shared:WaitForChild("Horse"))
local NameGen = require(Shared:WaitForChild("NameGen"))
local ThemePack = require(Shared:WaitForChild("ThemePack"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local ChooseStarter = Profiles.remote("ChooseStarter")     -- client -> server: coat, first word, second word
local SetActiveHorse = Profiles.remote("SetActiveHorse")   -- client -> server: horse id

local rng = Random.new()

local function leaderstats(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	if stats then return stats end
	stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = ThemePack.currency.earned
	cash.Parent = stats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats
	stats.Parent = player
	return stats
end

local function mirror(player: Player)
	local data = Profiles.get(player)
	if not data then return end
	local stats = leaderstats(player)
	stats[ThemePack.currency.earned].Value = data.cash
	stats.Wins.Value = data.totals.wins
end

Profiles.Changed.Event:Connect(mirror)
Profiles.Loaded.Event:Connect(mirror)

ChooseStarter.OnServerEvent:Connect(function(player: Player, coat: any, first: any, second: any)
	local data = Profiles.get(player)
	if not data or #data.horses > 0 then return end -- one starter per player
	local ok = false
	for _, s in Horse.STARTERS do
		if s.coat == coat then ok = true end
	end
	if not ok then return end
	local name = NameGen.build(if typeof(first) == "string" then first else nil, if typeof(second) == "string" then second else nil)
	if not name then return end
	local h = Horse.starter(Profile.newHorseId(data), name, coat, rng, os.time())
	Profile.addHorse(data, h)
	data.flags.starterPicked = true
	Profiles.changed(player) -- the client says hello to the new horse
end)

local lastActive: { [Player]: number } = {}
SetActiveHorse.OnServerEvent:Connect(function(player: Player, id: any)
	if os.clock() - (lastActive[player] or 0) < 3 then
		Profiles.notify(player, "One moment…", "heart")
		return
	end
	lastActive[player] = os.clock()
	local data = Profiles.get(player)
	if not data or typeof(id) ~= "string" then return end
	if Profile.setActive(data, id) then Profiles.changed(player) end
end)

Players.PlayerAdded:Connect(leaderstats)
for _, p in Players:GetPlayers() do leaderstats(p) end

Profiles.start()
