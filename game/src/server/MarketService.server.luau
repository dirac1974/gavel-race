--!nonstrict
-- MarketService (D-037): the Market Corral, taming wild horses, building stalls, moving
-- horses between stalls and the pasture, and renaming. The week's stock stands in the
-- corral for everyone to see (it's the same on every server); buying is personal.
-- Wild horses wander the meadow on every client from a shared seed (WildHorses client);
-- the server only checks that a tamer is in the meadow and hasn't made a friend today.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Market = require(Shared:WaitForChild("Market"))
local Profile = require(Shared:WaitForChild("Profile"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local WorldScene = require(script.Parent:WaitForChild("WorldScene"))

local MarketBuy = Profiles.remote("MarketBuy")     -- client -> server: listing id
local Tame = Profiles.remote("Tame")               -- client -> server: wild coat, game score
local BuyStall = Profiles.remote("BuyStall")       -- client -> server
local SwapStall = Profiles.remote("SwapStall")     -- client -> server: stalled id, pasture id
local Rename = Profiles.remote("RenameHorse")      -- client -> server: horse id, first word, second word

local last: { [Player]: number } = {}
local function busy(player: Player, gap: number?): boolean
	if os.clock() - (last[player] or 0) < (gap or 0.4) then return true end
	last[player] = os.clock()
	return false
end

local function near(player: Player, x: number, z: number, radius: number): boolean
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(x, 0, z)).Magnitude <= radius
end

-- The corral: this week's horses standing in a row with signs (name, ★ bloodline, price).
local corral: Folder? = nil
local shownWeek = -1
local function buildCorral()
	local week = Market.week(os.time())
	if week == shownWeek and corral and corral.Parent then return end
	shownWeek = week
	if corral then corral:Destroy() end
	local world = workspace:FindFirstChild("World") or WorldScene.build()
	corral = Instance.new("Folder")
	corral.Name = "MarketHorses"
	local p = WorldLayout.places.market
	for k, l in Market.stock(os.time()) do
		local x = p.x - p.w / 2 + 22 + (k - 1) * ((p.w - 36) / (Market.STOCK_SIZE - 1))
		local z = p.z + p.d * 0.55
		local cf = CFrame.lookAt(Vector3.new(x, WorldScene.GROUND_Y, z), Vector3.new(x, WorldScene.GROUND_Y, p.z)) -- facing the street
		local m = WorldScene.model("horse_stand_" .. l.coat) or WorldScene.model("horse_gallop_" .. l.coat) or WorldScene.model("horse_" .. l.coat)
		if m then
			m.Name = "Listing_" .. l.id
			m:PivotTo(cf)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
			end
			m:SetAttribute("ListingId", l.id)
			m.Parent = corral
		else
			local marker = WorldScene.part({ Name = "Listing_" .. l.id, Size = Vector3.new(2, 3, 6), Color = Color3.fromHex("8B4A2B"),
				CFrame = cf * CFrame.new(0, 2, 0) }, corral)
			marker:SetAttribute("ListingId", l.id)
		end
		WorldScene.sign(corral, (cf * CFrame.new(0, WorldScene.GROUND_Y + 9, -3)).Position, cf.LookVector,
			string.format("%s %s · %d", l.name, string.rep("★", l.stars), l.price), "💵", 16, 2.6)
	end
	corral.Parent = world
end

-- Add the market to the owner's profile view: this week's listings (bought or not), the next
-- stall's price, and whether they can tame today.
Profiles.addDecorator(function(data, view)
	Market.ensure(data)
	local now = os.time()
	local listings = {}
	for _, l in Market.stock(now) do table.insert(listings, Market.viewListing(l, data.market.bought[l.id] == true)) end
	view.market = {
		listings = listings,
		nextStallPrice = Market.nextStallPrice(data),
		canTame = (Market.canTame(data, now)),
		maxHorses = Market.MAX_HORSES,
	}
end)

MarketBuy.OnServerEvent:Connect(function(player: Player, id: any)
	if busy(player) or typeof(id) ~= "string" then return end
	local data = Profiles.get(player)
	if not data then return end
	local p = WorldLayout.places.market
	if not near(player, p.x, p.z + p.d / 2, p.w) then
		Profiles.notify(player, "Visit the Market Corral on Fair Street", "map_fair")
		return
	end
	local ok, msg = Market.buy(data, id, os.time())
	Profiles.notify(player, msg, if ok then "heart" else "cash")
	if ok then Profiles.changed(player) end
end)

Tame.OnServerEvent:Connect(function(player: Player, coat: any, score: any)
	if busy(player, 3) or typeof(coat) ~= "string" or typeof(score) ~= "number" then return end
	local data = Profiles.get(player)
	if not data then return end
	local m = WorldLayout.meadow
	if not near(player, m.x, m.z, m.radius + 30) then return end
	if score < 50 then
		Profiles.notify(player, "The wild horse trotted off. Try again, gently!", "heart")
		return
	end
	local ok, msg = Market.tame(data, coat, Random.new(), os.time())
	Profiles.notify(player, msg, "heart")
	if ok then
		Progress.record(player, "tame", 1)
		Profiles.changed(player)
	end
end)

BuyStall.OnServerEvent:Connect(function(player: Player)
	if busy(player) then return end
	local data = Profiles.get(player)
	if not data then return end
	local ok, msg = Market.buyStall(data)
	Profiles.notify(player, msg, if ok then "map_stable" else "cash")
	if ok then Profiles.changed(player) end
end)

SwapStall.OnServerEvent:Connect(function(player: Player, stalledId: any, pastureId: any)
	if busy(player) or typeof(stalledId) ~= "string" or typeof(pastureId) ~= "string" then return end
	local data = Profiles.get(player)
	if not data or player:GetAttribute("Racing") then return end
	if Profile.swapStall(data, stalledId, pastureId) then
		local h = Profile.horse(data, pastureId)
		Profiles.notify(player, (h and h.name or "Your horse") .. " moved into a stall!", "map_stable")
		Profiles.changed(player)
	end
end)

Rename.OnServerEvent:Connect(function(player: Player, id: any, first: any, second: any)
	if busy(player) or typeof(id) ~= "string" then return end
	local data = Profiles.get(player)
	if not data then return end
	local ok, msg = Market.rename(data, id, if typeof(first) == "string" then first else nil, if typeof(second) == "string" then second else nil)
	Profiles.notify(player, msg, "heart")
	if ok then Profiles.changed(player) end
end)

Players.PlayerRemoving:Connect(function(player: Player) last[player] = nil end)

-- Build the corral now, rebuild when models load and when the week turns.
task.defer(buildCorral)
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("RaceModels", 60)
	if folder and not folder:GetAttribute("Loaded") then folder:GetAttributeChangedSignal("Loaded"):Wait() end
	shownWeek = -1
	buildCorral()
	while true do
		task.wait(60)
		buildCorral()
	end
end)
