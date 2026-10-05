--!nonstrict
-- Purchases (D-050): Robux → Diamonds through developer products, nothing else.
-- Roblox calls ProcessReceipt until we answer PurchaseGranted, possibly more than once and
-- possibly in another server, so each purchase id is recorded in the player's profile and the
-- profile is saved before we say PurchaseGranted (a repeat of a recorded id is just granted
-- again without adding Diamonds). If the save fails, the grant is undone and Roblox retries.
-- Product ids live in DiamondProducts (created in the Creator Dashboard); 0 = not set up yet.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DiamondProducts = require(Shared:WaitForChild("DiamondProducts"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local MAX_RECEIPTS = 200

local byProduct: { [number]: any } = {}
for _, pack in DiamondProducts.packs do
	if pack.productId ~= 0 then byProduct[pack.productId] = pack end
end

local function hasReceipt(data, id: string): boolean
	for _, r in data.receipts do
		if r == id then return true end
	end
	return false
end

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local data = Profiles.get(player) or Profiles.whenLoaded(player, 20)
	if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local pack = byProduct[info.ProductId]
	if not pack then
		warn("[Purchases] unknown product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = tostring(info.PurchaseId)
	if hasReceipt(data, id) then return Enum.ProductPurchaseDecision.PurchaseGranted end
	data.diamonds += pack.diamonds
	table.insert(data.receipts, id)
	while #data.receipts > MAX_RECEIPTS do table.remove(data.receipts, 1) end
	data.diamondsBought = (data.diamondsBought or 0) + pack.diamonds
	data.robuxSpent = (data.robuxSpent or 0) + (tonumber(info.CurrencySpent) or 0)
	data.purchaseLog = if typeof(data.purchaseLog) == "table" then data.purchaseLog else {}
	table.insert(data.purchaseLog, { t = os.time(), robux = pack.robux }) -- for the daily and monthly caps
	while #data.purchaseLog > 100 do table.remove(data.purchaseLog, 1) end
	if not Profiles.saveNow(player) then
		-- Undo and let Roblox retry later, so a failed save can never lose or double a purchase.
		data.diamonds -= pack.diamonds
		data.diamondsBought -= pack.diamonds
		data.robuxSpent -= (tonumber(info.CurrencySpent) or 0)
		table.remove(data.purchaseLog)
		local i = table.find(data.receipts, id)
		if i then table.remove(data.receipts, i) end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Profiles.notify(player, string.format("+%d 💎 Diamonds. Thank you!", pack.diamonds), "diamond")
	Profiles.changed(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
