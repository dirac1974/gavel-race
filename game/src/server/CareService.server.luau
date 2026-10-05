--!nonstrict
-- CareService (D-038): the server side of care, the garden, chores and the Feed & Seed.
-- Checks every request (your own horse, near your own barn or the shop, sane arguments,
-- not too fast), applies the rule in Care.luau, saves, and answers with a friendly toast.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Care = require(Shared:WaitForChild("Care"))
local Profile = require(Shared:WaitForChild("Profile"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local CareAction = Profiles.remote("CareAction")   -- client -> server: horseId, "feed"|"groom"|"treat"|"pet", item?
local Garden = Profiles.remote("Garden")           -- client -> server: bed, "plant"|"harvest", seed?
local Chore = Profiles.remote("Chore")             -- client -> server: stall
local Shop = Profiles.remote("Shop")               -- client -> server: "buy"|"sell", item, qty
local CareFx = Profiles.remote("CareFx")           -- server -> all: plot, horseId, kind (hearts, sparkles)

local NEAR_PLOT = 30   -- studs outside your plot's rectangle that still count as "at your barn"
local NEAR_SHOP = 40
local GAP = 0.35

local last: { [Player]: number } = {}

local function busy(player: Player): boolean
	if os.clock() - (last[player] or 0) < GAP then return true end
	last[player] = os.clock()
	return false
end

local function position(player: Player): Vector3?
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function atOwnPlot(player: Player): boolean
	local i = player:GetAttribute("PlotIndex")
	local pos = position(player)
	if not i or not pos then return false end
	local r = WorldLayout.plotRect(i)
	return pos.X >= r[1] - NEAR_PLOT and pos.X <= r[3] + NEAR_PLOT and pos.Z >= r[2] - NEAR_PLOT and pos.Z <= r[4] + NEAR_PLOT
end

local function atShop(player: Player): boolean
	local pos = position(player)
	local p = WorldLayout.places.feedStore
	return pos ~= nil and (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(p.x, 0, p.z)).Magnitude <= NEAR_SHOP
end

local function reply(player: Player, ok: boolean, msg: string, icon: string?)
	Profiles.notify(player, msg, if ok then icon else "heart")
	if ok then Profiles.changed(player) end
end

CareAction.OnServerEvent:Connect(function(player: Player, horseId: any, action: any, item: any)
	if busy(player) or typeof(horseId) ~= "string" or typeof(action) ~= "string" then return end
	local data = Profiles.get(player)
	local h = data and Profile.horse(data, horseId)
	if not h or not Profile.isStalled(data, horseId) then return end
	if not atOwnPlot(player) then
		Profiles.notify(player, "Go to your barn to care for " .. h.name, "map_stable")
		return
	end
	local now = os.time()
	local ok, msg
	if action == "feed" and typeof(item) == "string" then
		ok, msg = Care.feed(data, h, item, now, GameConfig.energy)
	elseif action == "groom" then
		ok, msg = Care.groom(data, h, now, GameConfig.energy)
	elseif action == "treat" and typeof(item) == "string" then
		ok, msg = Care.treat(data, h, item, now)
	elseif action == "pet" then
		ok, msg = Care.pet(data, h, now)
	else
		return
	end
	reply(player, ok, msg, if action == "groom" then "care_star" else "heart")
	if ok then CareFx:FireAllClients(player:GetAttribute("PlotIndex"), horseId, action) end
end)

Garden.OnServerEvent:Connect(function(player: Player, bedIndex: any, action: any, seed: any)
	if busy(player) or typeof(bedIndex) ~= "number" then return end
	local data = Profiles.get(player)
	if not data or not atOwnPlot(player) then return end
	local ok, msg
	if action == "plant" and typeof(seed) == "string" then
		ok, msg = Care.plant(data, bedIndex, seed, os.time())
	elseif action == "harvest" then
		ok, msg = Care.harvest(data, bedIndex, os.time())
	else
		return
	end
	reply(player, ok, msg, "carrot")
end)

Chore.OnServerEvent:Connect(function(player: Player, stall: any)
	if busy(player) or typeof(stall) ~= "number" then return end
	local data = Profiles.get(player)
	if not data or not atOwnPlot(player) then return end
	local ok, msg = Care.chore(data, stall, os.time())
	reply(player, ok, msg, "hay")
end)

Shop.OnServerEvent:Connect(function(player: Player, action: any, item: any, qty: any)
	if busy(player) or typeof(item) ~= "string" or typeof(qty) ~= "number" then return end
	local data = Profiles.get(player)
	if not data then return end
	if not atShop(player) then
		Profiles.notify(player, "Visit Feed & Seed on Fair Street to shop", "map_fair")
		return
	end
	local ok, msg
	if action == "buy" then
		ok, msg = Care.buy(data, item, qty)
	elseif action == "sell" then
		ok, msg = Care.sell(data, item, qty)
	else
		return
	end
	reply(player, ok, msg, "cash")
end)

Players.PlayerRemoving:Connect(function(player: Player) last[player] = nil end)
