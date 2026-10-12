--!nonstrict
-- StyleService (D-050): the Tack & Paint shop on the server.
--   Looks: buy with Diamonds, wear, put away, return within 24 hours.
--   Barn Builder (D-070): BuyCash builds a BarnCatalog item with Green Cash (checked again here:
--   the item, its tier against the best league ever reached, the Green Cash, not owned, the race
--   window and a buy gap; paid and owned in one step), StyleWish sets the wish, StyleReturn gives
--   back the currency paid. Green Cash is never sold and never swapped for Diamonds.
--   Diamond packs: the server shows Roblox's purchase prompt only when it's a calm moment:
--   never while you're in line, racing, on your results, or for 2 minutes after your race; never
--   past our own daily and monthly caps; never if PolicyService can't be read (treated as
--   restricted). The shop never opens or prompts by itself.
--   Free Diamonds from milestones (league promotion, monthly jobs, Fan levels) are paid by the
--   services that see those moments, through Style.earn.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("Style"))
local DiamondProducts = require(Shared:WaitForChild("DiamondProducts"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Profile = require(Shared:WaitForChild("Profile"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local StyleBuy = Profiles.remote("StyleBuy")         -- client -> server: item id
local StyleWear = Profiles.remote("StyleWear")       -- client -> server: item id, wear (bool)
local StyleReturn = Profiles.remote("StyleReturn")   -- client -> server: item id
local BuyDiamonds = Profiles.remote("BuyDiamonds")   -- client -> server: pack index
-- Barn Builder (D-070): Green Cash only, never Diamonds, never sold.
local BuyCash = Profiles.remote("BuyCash")           -- client -> server: item id
local CashBuilt = Profiles.remote("CashBuilt")       -- server -> client: item id (the build moment)
local StyleWish = Profiles.remote("StyleWish")       -- client -> server: item id or "" (clear)
local WishTold = Profiles.remote("WishTold")         -- client -> server: item id (its "You can build" pill was shown)
local ShelfSeen = Profiles.remote("ShelfSeen")       -- client -> server: the "New shelf" note was shown
local GC = GameConfig.greenCash or {}

local last: { [Player]: number } = {}
local policyOk: { [Player]: boolean } = {}

local function busy(player: Player): boolean
	if os.clock() - (last[player] or 0) < 0.4 then return true end
	last[player] = os.clock()
	return false
end

-- Robux spent through Diamond packs in the last 24 hours and the last 30 days (rolling, so a
-- date line in any time zone can't double the limit).
local function spent(data, now: number): (number, number)
	local day, month = 0, 0
	for _, rec in data.purchaseLog or {} do
		if now - rec.t < 86400 then day += rec.robux end
		if now - rec.t < 30 * 86400 then month += rec.robux end
	end
	return day, month
end

-- Why buying Diamonds isn't possible right now (nil = it is).
local function blocked(player: Player, data, pack): string?
	if not policyOk[player] then
		local ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(player) end)
		policyOk[player] = ok and info ~= nil
	end
	if not policyOk[player] then return "Buying Diamonds isn't available right now." end
	if Profiles.isTemporary(player) and not game:GetService("RunService"):IsStudio() then return "Buying Diamonds isn't available right now." end
	if player:GetAttribute("Racing") or player:GetAttribute("InLine") then return "You can visit the shop after your race." end
	local raceEnd = player:GetAttribute("LastRaceEnd")
	if raceEnd and os.time() - raceEnd < DiamondProducts.afterRaceSeconds then return "You can visit the shop a little after your race." end
	local day, month = spent(data, os.time())
	if day + pack.robux > DiamondProducts.caps.dayRobux then return "That's all the Diamonds for today." end
	if month + pack.robux > DiamondProducts.caps.monthRobux then return "That's all the Diamonds for this month." end
	return nil
end

Profiles.addDecorator(function(data, view)
	Profile.syncBestLeague(data) -- the high-water mark (D-070): a promotion opens the next shelf
	view.bestLeague = data.bestLeague
	local day, month = spent(data, os.time())
	local packs = {}
	for i, pack in DiamondProducts.packs do
		table.insert(packs, { index = i, name = pack.name, diamonds = pack.diamonds, robux = pack.robux, ready = pack.productId ~= 0 })
	end
	view.fanXp = (typeof(data.fan) == "table" and data.fan.xp) or 0
	view.shop = {
		packs = packs,
		dayRobux = day, monthRobux = month, caps = DiamondProducts.caps,
		boughtAt = table.clone((data.style and data.style.boughtAt) or {}),
		diamondsBoughtMonth = month,
	}
end)

StyleBuy.OnServerEvent:Connect(function(player: Player, id: any)
	if busy(player) or typeof(id) ~= "string" then return end
	local data = Profiles.get(player)
	if not data then return end
	local ok, msg = Style.buy(data, id, os.time())
	Profiles.notify(player, msg, if ok then "diamond" else "heart")
	if ok then Profiles.changed(player) end
end)

-- The high-water mark moves the moment anything changes (a Cup promotion calls Profiles.changed), not
-- only when a view is built; it never goes down (D-070).
Profiles.Changed.Event:Connect(function(player: Player)
	local data = Profiles.get(player)
	if data then Profile.syncBestLeague(data) end
end)

-- Why building with Green Cash isn't possible right now (nil = it is): never in line, racing,
-- on a training ride or within greenCash.pillAfterRaceSeconds of your race, like the 💎 door.
local function cashWindowShut(player: Player): string?
	if GC.enabled == false then return "Barn Builder is closed right now." end
	if player:GetAttribute("Racing") or player:GetAttribute("InLine") or player:GetAttribute("TrainingRide") then
		return "Barn Builder opens after your race."
	end
	local raceEnd = player:GetAttribute("LastRaceEnd")
	if typeof(raceEnd) == "number" and os.time() - raceEnd < (GC.pillAfterRaceSeconds or 120) then
		return "Barn Builder opens a little after your race."
	end
	return nil
end

local lastBuy: { [Player]: number } = {}
BuyCash.OnServerEvent:Connect(function(player: Player, id: any)
	if busy(player) or typeof(id) ~= "string" or #id > 40 then return end
	if os.clock() - (lastBuy[player] or -math.huge) < (GC.buyGapSeconds or 1) then return end
	lastBuy[player] = os.clock()
	local data = Profiles.get(player)
	if not data then return end
	local why = cashWindowShut(player)
	if why then
		Profiles.notify(player, why, "heart")
		return
	end
	Profile.syncBestLeague(data)
	local ok, msg = Style.buyCash(data, id, os.time()) -- checks, pays and owns in one step
	if not ok then
		Profiles.notify(player, msg, "cash")
		return
	end
	Profiles.changed(player)
	CashBuilt:FireClient(player, id)
end)

StyleWish.OnServerEvent:Connect(function(player: Player, id: any)
	if busy(player) or (id ~= nil and typeof(id) ~= "string") then return end
	local data = Profiles.get(player)
	if not data then return end
	Profile.syncBestLeague(data)
	local ok = Style.setWish(data, if id == "" then nil else id)
	if ok then Profiles.changed(player) end
end)

WishTold.OnServerEvent:Connect(function(player: Player, id: any)
	if busy(player) or typeof(id) ~= "string" then return end
	local data = Profiles.get(player)
	if not data or not data.style or data.style.wish ~= id or data.style.wishTold == id then return end
	data.style.wishTold = id
	Profiles.changed(player)
end)

ShelfSeen.OnServerEvent:Connect(function(player: Player)
	if busy(player) then return end
	local data = Profiles.get(player)
	if not data or not data.style then return end
	Profile.syncBestLeague(data)
	if data.style.shelfSeen == data.bestLeague then return end
	data.style.shelfSeen = data.bestLeague
	Profiles.changed(player)
end)

StyleWear.OnServerEvent:Connect(function(player: Player, id: any, wear: any)
	if busy(player) or typeof(id) ~= "string" then return end
	local data = Profiles.get(player)
	if not data then return end
	if wear == false then
		if Style.unequip(data, id) then Profiles.changed(player) end
		return
	end
	local ok, msg = Style.equip(data, id)
	if ok then Profiles.changed(player) else Profiles.notify(player, msg, "heart") end
end)

StyleReturn.OnServerEvent:Connect(function(player: Player, id: any)
	if busy(player) or typeof(id) ~= "string" then return end
	local data = Profiles.get(player)
	if not data then return end
	local it = Style.item(id)
	local ok, msg = Style.giveBack(data, id, os.time())
	Profiles.notify(player, msg, if it and Style.isCash(it) then "cash" else "diamond")
	if ok then Profiles.changed(player) end
end)

BuyDiamonds.OnServerEvent:Connect(function(player: Player, index: any)
	if busy(player) or typeof(index) ~= "number" then return end
	local pack = DiamondProducts.packs[index]
	local data = Profiles.get(player)
	if not pack or not data then return end
	if pack.productId == 0 then
		Profiles.notify(player, "Diamond packs aren't set up yet.", "diamond")
		return
	end
	local why = blocked(player, data, pack)
	if why then
		Profiles.notify(player, why, "heart")
		return
	end
	MarketplaceService:PromptProductPurchase(player, pack.productId)
end)

local function checkPolicy(player: Player)
	local ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(player) end)
	policyOk[player] = ok and info ~= nil -- unknown policy = restricted (no Diamond prompts)
end

Players.PlayerAdded:Connect(checkPolicy)
for _, p in Players:GetPlayers() do task.spawn(checkPolicy, p) end
Players.PlayerRemoving:Connect(function(player: Player)
	last[player], policyOk[player], lastBuy[player] = nil, nil, nil
end)
