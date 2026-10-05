--!nonstrict
-- StyleService (D-050): the Tack & Paint shop on the server.
--   Looks: buy with Diamonds, wear, put away, return within 24 hours.
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

local StyleBuy = Profiles.remote("StyleBuy")         -- client -> server: item id
local StyleWear = Profiles.remote("StyleWear")       -- client -> server: item id, wear (bool)
local StyleReturn = Profiles.remote("StyleReturn")   -- client -> server: item id
local BuyDiamonds = Profiles.remote("BuyDiamonds")   -- client -> server: pack index

local last: { [Player]: number } = {}
local policyOk: { [Player]: boolean } = {}

local function busy(player: Player): boolean
	if os.clock() - (last[player] or 0) < 0.4 then return true end
	last[player] = os.clock()
	return false
end

-- Robux spent through Diamond packs today and this month (from saved purchase records).
local function spent(data, now: number): (number, number)
	local day, month = 0, 0
	local today = now // 86400
	local t = os.date("!*t", now)
	for _, rec in data.purchaseLog or {} do
		if rec.t // 86400 == today then day += rec.robux end
		local rt = os.date("!*t", rec.t)
		if rt.year == t.year and rt.month == t.month then month += rec.robux end
	end
	return day, month
end

-- Why buying Diamonds isn't possible right now (nil = it is).
local function blocked(player: Player, data, pack): string?
	if not policyOk[player] then return "Buying Diamonds isn't available right now." end
	if player:GetAttribute("Racing") or player:GetAttribute("InLine") then return "You can visit the shop after your race." end
	local raceEnd = player:GetAttribute("LastRaceEnd")
	if raceEnd and os.time() - raceEnd < DiamondProducts.afterRaceSeconds then return "You can visit the shop a little after your race." end
	local day, month = spent(data, os.time())
	if day + pack.robux > DiamondProducts.caps.dayRobux then return "That's the most Diamonds for today. Come back tomorrow!" end
	if month + pack.robux > DiamondProducts.caps.monthRobux then return "That's the most Diamonds for this month." end
	return nil
end

Profiles.addDecorator(function(data, view)
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
	local ok, msg = Style.giveBack(data, id, os.time())
	Profiles.notify(player, msg, "diamond")
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
	last[player], policyOk[player] = nil, nil
end)
