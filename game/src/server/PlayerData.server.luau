--!nonstrict
-- PlayerData: starts profile loading/saving (Profiles) and handles the owner's requests
-- about their own horses: the starter pick and name (D-037), and choosing the active horse.
-- No leaderstats (D-065, D-042 "no rankings"): Green Cash and wins stay off the public player list.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Profile = require(Shared:WaitForChild("Profile"))
local Horse = require(Shared:WaitForChild("Horse"))
local NameGen = require(Shared:WaitForChild("NameGen"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local ChooseStarter = Profiles.remote("ChooseStarter")     -- client -> server: coat, first word, second word
local SetActiveHorse = Profiles.remote("SetActiveHorse")   -- client -> server: horse id

local rng = Random.new()

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

Profiles.start()
