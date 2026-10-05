--!nonstrict
-- AssetService: brings the uploaded playtest art into the game (D-023).
-- UI sheets are Decals (UiImages); an ImageLabel needs the Decal's inner image id, which
-- only InsertService can read, so each is loaded once and published as ReplicatedStorage
-- attribute UiSheet_<sheet>. Models (MeshAssets) are loaded, sized and turned to face -Z
-- per docs/art/IMPORT.md, then stored in ReplicatedStorage.RaceModels for TrackScene.
-- Loads fail until Roblox moderation approves an asset, or if the place isn't owned by the
-- same group as the assets; the placeholders stay in that case.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiImages = require(Shared:WaitForChild("UiImages"))
local MeshAssets = require(Shared:WaitForChild("MeshAssets"))

-- Target size in studs along the named axis after scaling (docs/art/IMPORT.md).
local SIZES = {
	horse = { axis = "Z", studs = 8.0 },
	finish_post = { axis = "Y", studs = 14.0 },
	gate_stall = { axis = "Y", studs = 8.0 },
}

-- Turn applied after import so each model faces -Z (Roblox forward). Playtest showed the
-- imported horses already face -Z (the 180-degree turn from docs/art/IMPORT.md put them
-- backwards), so no turn by default; set math.pi for a slot that comes in reversed.
local YAW = {
	horse = 0,
	finish_post = 0,
	gate_stall = 0,
}

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
	local isHorse = string.sub(slot, 1, 6) == "horse_"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = not isHorse
			d.CanTouch = false
			d.CanQuery = not isHorse
		end
	end
	-- Scale so the named axis reaches the target size.
	local size = if isHorse then SIZES.horse else SIZES[slot]
	local _, extents = model:GetBoundingBox()
	local current = if size.axis == "Y" then extents.Y else math.max(extents.X, extents.Z)
	if current > 0 then model:ScaleTo(model:GetScale() * size.studs / current) end
	-- Turn to face -Z (YAW above), then put an unrotated pivot at the bottom centre so
	-- PivotTo(CFrame.new(p)) faces -Z standing on p.
	local yaw = if isHorse then YAW.horse else (YAW[slot] or 0)
	local cf = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)
	model:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, yaw, 0))
	local cf2, ext = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf2.Position - Vector3.new(0, ext.Y / 2, 0))
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
