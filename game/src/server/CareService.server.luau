--!nonstrict
-- CareService (D-038): the server side of care, the garden, chores and the Feed & Seed.
-- Checks every request (your own horse, near your own barn or the shop, sane arguments,
-- not too fast), applies the rule in Care.luau, saves, and answers with a friendly toast.
-- Visitors (D-060): on a friend's plot only VisitCare's pat and treat are allowed (Visits.luau);
-- every other care action still needs your own horse at your own barn.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Care = require(Shared:WaitForChild("Care"))
local Profile = require(Shared:WaitForChild("Profile"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Visits = require(Shared:WaitForChild("Visits"))
local VisitAccess = require(script.Parent:WaitForChild("VisitAccess"))

local CareAction = Profiles.remote("CareAction")   -- client -> server: horseId, "feed"|"groom"|"treat"|"pet", item?
local Garden = Profiles.remote("Garden")           -- client -> server: bed, "plant"|"harvest", seed?
local Chore = Profiles.remote("Chore")             -- client -> server: stall
local Shop = Profiles.remote("Shop")               -- client -> server: "buy"|"sell", item, qty
local CareFx = Profiles.remote("CareFx")           -- server -> all: plot, horseId, kind (hearts, sparkles)
local VisitCare = Profiles.remote("VisitCare")     -- client -> server: ownerUserId, horseId, "pat"|"treat" (D-060)

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
	local ok, msg, counted = nil, nil, true
	if action == "feed" and typeof(item) == "string" then
		ok, msg = Care.feed(data, h, item, now, GameConfig.energy)
	elseif action == "groom" then
		ok, msg = Care.groom(data, h, now, GameConfig.energy)
	elseif action == "treat" and typeof(item) == "string" then
		ok, msg = Care.treat(data, h, item, now)
	elseif action == "pet" then
		ok, msg, counted = Care.pet(data, h, now)
	else
		return
	end
	reply(player, ok, msg, if action == "groom" then "brush" else "heart")
	if ok then
		CareFx:FireAllClients(player:GetAttribute("PlotIndex"), horseId, action)
		if counted then Progress.record(player, action, 1) end
	end
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
	if ok then Progress.record(player, action, 1) end
end)

Chore.OnServerEvent:Connect(function(player: Player, stall: any)
	if busy(player) or typeof(stall) ~= "number" then return end
	local data = Profiles.get(player)
	if not data or not atOwnPlot(player) then return end
	local ok, msg = Care.chore(data, stall, os.time())
	reply(player, ok, msg, "hay")
	if ok then Progress.record(player, "chore", 1) end
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
	elseif action == "sellAll" then
		ok, msg = Care.sellAll(data, qty)
	else
		return
	end
	reply(player, ok, msg, "cash")
end)

-- Visiting a friend's barn (D-060): pat (no bond; pat them all for a Tour stamp) and one free
-- treat a day (bond, inside the visitors' daily cap). Nothing else on someone else's plot.
VisitCare.OnServerEvent:Connect(function(player: Player, ownerId: any, horseId: any, action: any)
	if busy(player) or typeof(horseId) ~= "string" or not Visits.visitorMay(action) or action == "post" then return end
	local owner = VisitAccess.owner(ownerId)
	local ok, why = VisitAccess.check(player, owner)
	if not ok then
		if why == "closed" then Profiles.notify(player, "The gate is closed right now", "heart") end
		return
	end
	if not VisitAccess.near(player, owner) then return end
	local vdata, odata = Profiles.get(player), Profiles.get(owner)
	if not vdata or not odata then return end
	local ids = VisitAccess.barnHorses(owner, odata)
	local h = table.find(ids, horseId) and Profile.horse(odata, horseId)
	if not h then return end
	local now = os.time()
	local cfg = GameConfig.visit
	if action == "pat" then
		local done, res = Visits.pat(vdata, owner.UserId, horseId, ids, now)
		if not done then return end
		if res.stamp then
			Profiles.notify(player, "Tour stamp! You toured " .. owner.DisplayName .. "'s barn", "heart")
		elseif res.left > 0 and not res.already then
			Profiles.notify(player, h.name .. " nuzzles you! " .. res.left .. " more pats for a stamp", "heart")
		else
			Profiles.notify(player, h.name .. " nuzzles you!", "heart")
		end
		Profiles.changed(player)
		CareFx:FireAllClients(owner:GetAttribute("PlotIndex"), horseId, "pet")
	else
		local done, res = Visits.treat(vdata, owner.UserId, h, now, cfg)
		if not done then
			Profiles.notify(player, "You gave a treat here today. Come back tomorrow!", "heart")
			return
		end
		Profiles.notify(player, h.name .. " loved your treat!" .. (if res.bond > 0 then " +" .. res.bond .. " bond" else ""), "heart")
		Profiles.changed(player)
		if res.bond > 0 then Profiles.changed(owner) end
		CareFx:FireAllClients(owner:GetAttribute("PlotIndex"), horseId, "treat")
	end
end)

Players.PlayerRemoving:Connect(function(player: Player) last[player] = nil end)
