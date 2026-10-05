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
local Tame = Profiles.remote("Tame")               -- client -> server: wild horse index, game score, start time
local TameResult = Profiles.remote("TameResult")   -- server -> client: true when a new friend is coming home
local BuyStall = Profiles.remote("BuyStall")       -- client -> server
local SwapStall = Profiles.remote("SwapStall")     -- client -> server: stalled id, pasture id
local Rename = Profiles.remote("RenameHorse")      -- client -> server: horse id, first word, second word
local Retire = Profiles.remote("RetireHorse")      -- client -> server: horse id (player's choice, D-046)
local Leagues = require(Shared:WaitForChild("Leagues"))

local last: { [Player]: number } = {}
local function busy(player: Player, gap: number?, key: string?): boolean
	local k = (key or "market") .. ":" .. player.UserId
	if os.clock() - (last[k] or 0) < (gap or 0.4) then return true end
	last[k] = os.clock()
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

Tame.OnServerEvent:Connect(function(player: Player, index: any, score: any, startedAt: any)
	if typeof(index) ~= "number" or typeof(score) ~= "number" then return end
	local coat = Market.WILD_COATS[index]
	if not coat then return end
	if busy(player, 3, "tame") then
		Profiles.notify(player, "Easy does it: try again in a moment", "heart")
		TameResult:FireClient(player, false)
		return
	end
	local data = Profiles.get(player)
	if not data then
		TameResult:FireClient(player, false)
		return
	end
	-- The wild horse is where every client drew it when the game began (it stands still on the
	-- tamer's screen while they play, D-056): the tamer must be next to that spot. A start time
	-- more than 60 s old (or in the future) is clamped, so it can't be used to reach far-off horses.
	local now = workspace:GetServerTimeNow()
	local at = if typeof(startedAt) == "number" and startedAt == startedAt then math.clamp(startedAt, now - 60, now) else now
	local x, z = Market.wildPosition(WorldLayout.meadow, index, at)
	if not near(player, x, z, 30) then
		Profiles.notify(player, "Get a little closer to the wild horse, then try again", "heart")
		TameResult:FireClient(player, false)
		return
	end
	if score < 50 then
		Profiles.notify(player, "The wild horse trotted off. Try again, gently!", "heart")
		TameResult:FireClient(player, false)
		return
	end
	local ok, msg = Market.tame(data, coat, Random.new(), os.time())
	Profiles.notify(player, msg, "heart")
	TameResult:FireClient(player, ok == true)
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
	if busy(player, 3, "rename") or typeof(id) ~= "string" then return end
	local data = Profiles.get(player)
	if not data then return end
	local ok, msg = Market.rename(data, id, if typeof(first) == "string" then first else nil, if typeof(second) == "string" then second else nil)
	Profiles.notify(player, msg, "heart")
	if ok then Profiles.changed(player) end
end)

Retire.OnServerEvent:Connect(function(player: Player, id: any)
	if busy(player, 1, "retire") or typeof(id) ~= "string" then return end
	local data = Profiles.get(player)
	if not data then return end
	if player:GetAttribute("Racing") or player:GetAttribute("InLine") then
		Profiles.notify(player, "Retire after your race!", "heart")
		return
	end
	if #data.horses <= 1 then
		Profiles.notify(player, "Keep at least one horse in your stable!", "heart")
		return
	end
	local plaque = Leagues.retire(data, id, os.time())
	if plaque then
		Profiles.notify(player, string.format("%s retires a legend: %d races, %d wins. See the Hall of Fame!", plaque.name, plaque.races, plaque.wins), "trophy")
		Profiles.changed(player)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	for _, k in { "market", "tame", "rename", "retire" } do last[k .. ":" .. player.UserId] = nil end
end)

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
