--!nonstrict
-- TrainingService (D-039, D-040): training sessions at the Training Paddock and check-ups at
-- the Vet. Checks the horse is yours and stalled, that you're at the right place, and rate
-- limits; the weekly cap in Training.luau is the real limit on gains.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Training = require(Shared:WaitForChild("Training"))
local Profile = require(Shared:WaitForChild("Profile"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local Train = Profiles.remote("Train")         -- client -> server: horseId, stat, score
local VetVisit = Profiles.remote("VetVisit")   -- client -> server: horseId, score
local SESSION_GAP = 6                          -- seconds between sessions (each game takes longer)

local last: { [Player]: number } = {}

local function near(player: Player, key: string, radius: number): boolean
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local p = WorldLayout.places[key]
	if not hrp or not p then return false end
	local r = WorldLayout.placeRect(key)
	local pos = hrp.Position
	if r then
		return pos.X >= r[1] - radius and pos.X <= r[3] + radius and pos.Z >= r[2] - radius and pos.Z <= r[4] + radius
	end
	return (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(p.x, 0, p.z)).Magnitude <= radius
end

local function horseFor(player: Player, horseId: any)
	if typeof(horseId) ~= "string" then return nil end
	local data = Profiles.get(player)
	local h = data and Profile.horse(data, horseId)
	if not h or not Profile.isStalled(data, horseId) then return nil end
	return h
end

Train.OnServerEvent:Connect(function(player: Player, horseId: any, stat: any, score: any)
	if os.clock() - (last[player] or 0) < SESSION_GAP then return end
	if typeof(stat) ~= "string" or typeof(score) ~= "number" then return end
	local h = horseFor(player, horseId)
	if not h then return end
	if not near(player, "paddock", 30) then
		Profiles.notify(player, "Training happens at the Training Paddock on Fair Street", "map_fair")
		return
	end
	last[player] = os.clock()
	local ok, _, msg = Training.train(h, stat, score, os.time())
	Profiles.notify(player, msg, if ok then "stat_" .. stat else "heart")
	if ok then
		Progress.record(player, "train", 1)
		Profiles.changed(player)
	end
end)

VetVisit.OnServerEvent:Connect(function(player: Player, horseId: any, score: any)
	if os.clock() - (last[player] or 0) < 2 then return end
	if typeof(score) ~= "number" then return end
	local h = horseFor(player, horseId)
	if not h then return end
	if not near(player, "vet", 30) then
		Profiles.notify(player, "Check-ups happen at the Vet on Fair Street", "map_vet")
		return
	end
	last[player] = os.clock()
	local ok, msg, stamp = Training.checkup(h, score, os.time())
	Profiles.notify(player, msg, if stamp then "stamp_" .. stamp else "stethoscope")
	if ok then
		Progress.record(player, "checkup", 1)
		Profiles.changed(player)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player) last[player] = nil end)
