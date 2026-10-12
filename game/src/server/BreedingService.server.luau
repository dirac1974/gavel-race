--!nonstrict
-- BreedingService (D-080 provisional): the 💞 Foal Barn on Fair Street and its remotes. Server-
-- authoritative: the client sends two horse ids and name words only; the fee (Green Cash only, never
-- Diamonds), eligibility, the stable cap and the one roll all happen in shared/Breeding.luau here.
--   BreedPreview (idA, idB)       -> BreedPreviewResult { idA, idB, family, fee, block }: the expected
--                                    family line (sprouts) and why not, before paying. No randomness.
--   BreedConfirm (idA, idB)       pays the fee and rolls the foal ONCE (Breeding.confirm); the roll is
--                                    stored on p.breeding.pending and saved, so a rejoin can't reroll and a
--                                    second confirm is refused while a foal is on the way.
--   FoalArrive (first, second)    when the stored foal is ready (Breeding.ready: N owner races or the next
--                                    play day): names it from NameGen words, builds it with Horse.new and
--                                    Profile.addHorse (a free stall or the pasture) -> FoalArrived { id, name, coat, parent }.
-- Both confirm and arrival happen at the Foal Barn. Rate limited per player and remote. Off (and the
-- barn hidden) while GameConfig.breeding.enabled is false.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Breeding = require(Shared:WaitForChild("Breeding"))
local Horse = require(Shared:WaitForChild("Horse"))
local Profile = require(Shared:WaitForChild("Profile"))
local Market = require(Shared:WaitForChild("Market"))
local NameGen = require(Shared:WaitForChild("NameGen"))
local HorseBook = require(Shared:WaitForChild("HorseBook"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local WorldScene = require(script.Parent:WaitForChild("WorldScene"))
local Foals = require(script.Parent:WaitForChild("Foals"))

local CFG = GameConfig.breeding
local Preview = Profiles.remote("BreedPreview")             -- client -> server: idA, idB
local PreviewResult = Profiles.remote("BreedPreviewResult") -- server -> client: { idA, idB, family, fee, block }
local Confirm = Profiles.remote("BreedConfirm")             -- client -> server: idA, idB
local ConfirmResult = Profiles.remote("BreedResult")        -- server -> client: { ok, text }
local Arrive = Profiles.remote("FoalArrive")                -- client -> server: first word, second word
local Arrived = Profiles.remote("FoalArrived")              -- server -> client: { id, name, coat, parent } or { text } when refused

local last: { [string]: number } = {}
local function busy(player: Player, gap: number, k: string): boolean
	local key = k .. ":" .. player.UserId
	if os.clock() - (last[key] or 0) < gap then return true end
	last[key] = os.clock()
	return false
end

local function busyState(player: Player)
	return {
		racing = player:GetAttribute("Racing"), inLine = player:GetAttribute("InLine"),
		racingHorse = player:GetAttribute("RacingHorse"), ridingHorse = player:GetAttribute("RidingHorse"),
		trainingRide = player:GetAttribute("TrainingRide"),
	}
end

local function atBarn(player: Player): boolean
	local p = WorldLayout.places.foalBarn
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local cx, cz = p.x, p.z - p.d / 2
	return (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(cx, 0, cz)).Magnitude <= p.w
end

local function okId(x: any): boolean
	return typeof(x) == "string" and #x >= 1 and #x <= 20
end

-- The owner's view: what the panel, the Map tile ("Foal here!") and the Family page need.
Profiles.addDecorator(function(data, view)
	if not CFG.enabled then return end
	local player = nil
	for _, pl in Players:GetPlayers() do
		if Profiles.get(pl) == data then player = pl break end
	end
	view.breeding = Foals.view(data, if player then busyState(player) else {}, os.time())
end, "breeding")

Preview.OnServerEvent:Connect(function(player: Player, idA: any, idB: any)
	if not CFG.enabled or busy(player, 0.3, "preview") or not okId(idA) or not okId(idB) then return end
	local data = Profiles.get(player)
	if not data then return end
	local info = Breeding.preview(data, idA, idB, CFG)
	PreviewResult:FireClient(player, {
		idA = idA, idB = idB, family = info and info.family, fee = info and info.fee,
		block = Breeding.pairBlock(data, idA, idB, busyState(player), CFG),
	})
end)

Confirm.OnServerEvent:Connect(function(player: Player, idA: any, idB: any)
	if not CFG.enabled or busy(player, 2, "confirm") or not okId(idA) or not okId(idB) then return end
	local data = Profiles.get(player)
	if not data then return end
	if not atBarn(player) then
		ConfirmResult:FireClient(player, { ok = false, text = "Come to the Foal Barn first" })
		return
	end
	-- Breeding.confirm checks everything again (pair, wait, room, cash) and rolls once, here only.
	local ok, msg = Breeding.confirm(data, idA, idB, os.time(), Random.new(), busyState(player), CFG)
	ConfirmResult:FireClient(player, { ok = ok, text = if ok then "💞 A foal is on the way!" else msg })
	if ok then Profiles.changed(player) end
end)

Arrive.OnServerEvent:Connect(function(player: Player, first: any, second: any)
	if not CFG.enabled or busy(player, 2, "arrive") then return end
	local data = Profiles.get(player)
	if not data then return end
	local name = NameGen.build(if typeof(first) == "string" then first else nil, if typeof(second) == "string" then second else nil)
	if not name then
		Arrived:FireClient(player, { text = "Pick words for the name" })
		return
	end
	if not atBarn(player) then
		Arrived:FireClient(player, { text = "Come to the Foal Barn first" })
		return
	end
	if not Foals.ready(data, os.time()) then
		Arrived:FireClient(player, { text = "Your foal isn't here yet" })
		return
	end
	if #data.horses >= Market.MAX_HORSES then
		Arrived:FireClient(player, { text = "Make room first" })
		return
	end
	local id = Profile.newHorseId(data)
	local rec = Breeding.arrive(data, id, name, os.time(), CFG)
	if not rec then return end
	local h = Horse.new(id, rec.name, rec.coat, rec.stats, rec.potential, os.time())
	h.bond, h.origin, h.parents, h.paid = rec.bond, "bred", rec.parents, rec.paid
	Profile.addHorse(data, h)
	HorseBook.record(data, "coats", h.coat) -- a bred coat goes on the Coats page as usual
	local parent = Breeding.find(data, rec.parents[1])
	Arrived:FireClient(player, { id = h.id, name = h.name, coat = h.coat, parent = parent and parent.name or "" })
	Profiles.changed(player)
end)

-- The 💞 Foal Barn ---------------------------------------------------------------------------------
-- A small cream barn with sky-blue trim and a red roof (feel vote F3), a white-rail paddock with two
-- grazing foals and flower planters, and a prompt spot by the door (BreedingClient adds the prompt).
-- Code only, 0 Meshy. Hidden while breeding is off.
local CREAM, SKY, ROOF = Color3.fromHex("FFF4C7"), Color3.fromHex("8ED6FF"), Color3.fromHex("C8463D")
local function buildBarn()
	if not CFG.enabled then return end
	local world = workspace:FindFirstChild("World") or WorldScene.build()
	local old = world:FindFirstChild("FoalBarn")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "FoalBarn"
	local p = WorldLayout.places.foalBarn
	local cf = WorldScene.placeCF("foalBarn") -- faces the street; local +X is west
	local barnCF = cf * CFrame.new(22, 0, 0)
	local shop = WorldScene.shop(f, barnCF, 44, 34, 14, CREAM, ROOF, { SKY, Color3.new(1, 1, 1) }, "Foal Barn", "💞")
	for _, d in shop:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Trim" or d.Name == "WindowFrame") then d.Color = SKY end
	end
	-- the paddock, east of the barn (white rails, an open side to the street)
	local x0, x1 = p.x - p.w / 2 + 50, p.x + p.w / 2 - 4
	local z0, z1 = p.z - p.d + 4, p.z - 8
	WorldScene.fence(f, x0, z0, x1, z0)
	WorldScene.fence(f, x0, z0, x0, z1)
	WorldScene.fence(f, x1, z0, x1, z1)
	WorldScene.fence(f, x0, z1, x0 + 10, z1)
	WorldScene.fence(f, x1 - 10, z1, x1, z1)
	for k, coat in { "bay", "chestnut" } do -- two NPC foals grazing (decor)
		local x, z = x0 + (x1 - x0) * (if k == 1 then 0.35 else 0.7), z0 + (z1 - z0) * (if k == 1 then 0.4 else 0.6)
		local fcf = CFrame.new(x, WorldScene.GROUND_Y, z) * CFrame.Angles(0, math.rad(if k == 1 then 40 else -120), 0)
		local m = WorldScene.placeModel(f, "foal_stand_" .. coat, fcf)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
			end
		end
	end
	for _, dx in { -14, 14 } do -- flower planters either side of the door
		local at = barnCF * CFrame.new(dx, WorldScene.GROUND_Y + 1, -2)
		WorldScene.part({ Name = "Planter", Size = Vector3.new(5, 2, 2), Color = SKY, CFrame = at }, f)
		for k = -1, 1 do
			WorldScene.part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CanCollide = false,
				Color = if k == 0 then Color3.fromHex("FF8FB1") else Color3.fromHex("FFD23F"), CFrame = at * CFrame.new(k * 1.5, 1.4, 0) }, f)
		end
	end
	local spot = WorldScene.part({ Name = "FoalBarnSpot", Size = Vector3.new(6, 6, 2), Transparency = 1, CanCollide = false,
		CanQuery = false, CanTouch = false, CFrame = barnCF * CFrame.new(0, WorldScene.GROUND_Y + 3, -3) }, f)
	spot:SetAttribute("FoalBarn", true)
	-- where the arrival plays: the parent stands here and the foal steps out from behind it
	local stage = WorldScene.part({ Name = "FoalStage", Size = Vector3.new(2, 1, 2), Transparency = 1, CanCollide = false,
		CanQuery = false, CanTouch = false, CFrame = cf * CFrame.new(-22, WorldScene.GROUND_Y + 0.5, 14) }, f)
	stage:SetAttribute("FoalStage", true)
	f.Parent = world
end

Profiles.Loaded.Event:Connect(function(player: Player)
	if CFG.enabled then Foals.onLoaded(player) end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	for _, k in { "preview", "confirm", "arrive" } do last[k .. ":" .. player.UserId] = nil end
end)

local function build()
	local ok, err = pcall(buildBarn)
	if not ok then warn("[BreedingService] barn: " .. tostring(err)) end
end
task.defer(build)
task.spawn(function() -- again once the uploaded foal models load
	local folder = ReplicatedStorage:WaitForChild("RaceModels", 60)
	if folder and not folder:GetAttribute("Loaded") then folder:GetAttributeChangedSignal("Loaded"):Wait() end
	build()
end)
