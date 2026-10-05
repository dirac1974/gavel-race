--!nonstrict
-- AssetService: brings the uploaded playtest art into the game (D-023).
-- UI sheets are Decals (UiImages); an ImageLabel needs the Decal's inner image id, which
-- only InsertService can read, so each is loaded once and published as ReplicatedStorage
-- attribute UiSheet_<sheet>. Models (MeshAssets) are loaded, sized, turned to face -Z and
-- given collision per ModelSpecs (docs/art/IMPORT.md), then stored in
-- ReplicatedStorage.RaceModels for TrackScene and the world.
-- Loads fail until Roblox moderation approves an asset, or if the place isn't owned by the
-- same group as the assets; the placeholders stay in that case.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiImages = require(Shared:WaitForChild("UiImages"))
local MeshAssets = require(Shared:WaitForChild("MeshAssets"))
local ModelSpecs = require(Shared:WaitForChild("ModelSpecs"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))

-- Used when a slot has no ModelSpecs entry (and warned about), so a new upload still shows.
local FALLBACK = { axis = "Y", studs = 4.0, yaw = 0, collide = true }

-- Exact slot first, then the longest prefix ending in "_" (horse_, foal_). The second
-- result is true for prefix matches (creatures: never collide or take queries).
local function specFor(slot: string)
	local exact = ModelSpecs[slot]
	if exact then return exact, false end
	local best, bestLen = nil, 0
	for key, spec in ModelSpecs do
		if string.sub(key, -1) == "_" and #key > bestLen and string.sub(slot, 1, #key) == key then
			best, bestLen = spec, #key
		end
	end
	if best then return best, true end
	warn(`[AssetService] no ModelSpecs entry for {slot}; using the fallback size`)
	return FALLBACK, false
end

local models = Instance.new("Folder")
models.Name = "RaceModels"
models.Parent = ReplicatedStorage

local function imageId(texture: string): number?
	local id = string.match(texture, "(%d+)%s*$")
	return if id then tonumber(id) else nil
end

local function resolveSheet(sheet: string, decalId: number)
	local ok, res = pcall(function() return InsertService:LoadAsset(decalId) end)
	if not ok then
		warn(`[AssetService] UI sheet {sheet} ({decalId}) not loaded yet: {res}`)
		return
	end
	local decal = res:FindFirstChildWhichIsA("Decal", true)
	local id = decal and imageId(decal.Texture)
	res:Destroy()
	if id then
		ReplicatedStorage:SetAttribute("UiSheet_" .. sheet, id)
	else
		warn(`[AssetService] UI sheet {sheet}: no Decal image inside the asset`)
	end
end

local function normalize(container: Model, slot: string): Model
	local model = Instance.new("Model")
	model.Name = slot
	for _, child in container:GetChildren() do child.Parent = model end
	container:Destroy()
	local size, creature = specFor(slot)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = size.collide
			d.CanTouch = false
			d.CanQuery = not creature
		end
	end
	-- Scale so the named axis reaches the target size.
	local _, extents = model:GetBoundingBox()
	local current = if size.axis == "Y" then extents.Y else math.max(extents.X, extents.Z)
	if current > 0 then model:ScaleTo(model:GetScale() * size.studs / current) end
	-- Turn to face -Z (ModelSpecs yaw), then put an unrotated pivot at the bottom centre so
	-- PivotTo(CFrame.new(p)) faces -Z standing on p.
	local yaw = size.yaw
	local cf = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)
	model:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, yaw, 0))
	local cf2, ext = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf2.Position - Vector3.new(0, ext.Y / 2, 0))
	-- Running-legs horses (D-051): remember where each leg rests, and keep the fitted saddle
	-- cloth hidden until a race or a rider's look shows it.
	if HorseLegs.has(model) then
		HorseLegs.markRest(model)
		local cloth = model:FindFirstChild("Cloth", true)
		if cloth and cloth:IsA("BasePart") then
			cloth.Transparency = 1
			cloth.CastShadow = false
		end
	end
	return model
end

local function loadModel(slot: string, assetId: number)
	local ok, res = pcall(function() return InsertService:LoadAsset(assetId) end)
	if not ok then
		warn(`[AssetService] model {slot} ({assetId}) not loaded yet: {res}`)
		return
	end
	local model = normalize(res, slot)
	model:SetAttribute("AssetId", assetId)
	model.Parent = models
end

for sheet, decalId in UiImages do
	if decalId ~= 0 then task.spawn(resolveSheet, sheet, decalId) end
end
local pending = 0
for slot, assetId in MeshAssets do
	if assetId ~= 0 then
		pending += 1
		task.spawn(function()
			loadModel(slot, assetId)
			pending -= 1
			if pending == 0 then models:SetAttribute("Loaded", true) end
		end)
	end
end
if pending == 0 then models:SetAttribute("Loaded", true) end
