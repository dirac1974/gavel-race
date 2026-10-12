--!nonstrict
-- TrackDressing (AAA Phase 4, D-069): County Fair dressing on the racecourse, built once with the venue
-- (TrackScene.buildVenue calls `build`). Drawn only: nothing here touches a race.
--   Bunting: Beams textured with bunting_strip (Wrap, sagging) along the grandstand roof edge every
--     roofSpacing studs, on railPostStuds posts outside the outer homestretch rail (from a furlong
--     before the finish to railPastFeet past it), and from each of the Twin Spires down to the roof.
--   Flags: poles on the roof every flagSpacing studs and on each spire's finial, each flying a
--     flag_pennant Beam (TrackLife flutters them on the client).
--   Crowd: a crowd_strip Texture on the track-facing riser of every StandTier (no new parts).
-- Until an image is loaded (WorldArt) the Beams show plain fair colours and the crowd isn't drawn,
-- so nothing breaks if an upload is late. `plan` is pure (tested under Lune); it enforces the budget:
-- at most maxParts new parts and maxBeams Beams.

local TrackDressing = {}

TrackDressing.TAG_CROWD = "GiddyCrowd"     -- the crowd Textures (TrackLife bounces them)
TrackDressing.TAG_FLAG = "GiddyFlag"       -- the flag Beams' tip Attachments (TrackLife flutters them)
TrackDressing.TAG_BOARD = "GiddyBigBoard"  -- the infield Big Board part (TrackLife draws the race on it)
-- Bunting fallback colours (docs/art/ART_DIRECTION.md): Giddy-up orange, Gold, Sky, Teal, Paper.
TrackDressing.BUNTING_HEX = { "FF9F1C", "FFD23F", "8ED6FF", "17A398", "FFF7E6" }
TrackDressing.FLAG_HEX = "FF9F1C"
TrackDressing.POLE_HEX = "FBFBF5"
TrackDressing.FLAG_LENGTH, TrackDressing.FLAG_HEIGHT = 7, 3.5
TrackDressing.ROOF_POLE, TrackDressing.SPIRE_POLE = 12, 8

export type Point = { x: number, y: number, z: number }
export type Geometry = {
	roofEdgeX: number, roofTopY: number, roofUnderY: number, z0: number, z1: number,
	finials: { Point }, tiers: number, -- finial tops of the Twin Spires; StandTier parts (each gets a Texture)
}
export type Plan = {
	roof: { Point }, rail: { Point }, roofFlags: { Point }, spireFlags: { Point },
	spireLinks: { { a: Point, b: Point } },
	parts: number, beams: number, textures: number,
}

local function pt(x: number, y: number, z: number): Point
	return { x = x, y = y, z = z }
end

-- Evenly spaced stations from a to b (both ends included), about `step` apart.
local function stations(a: number, b: number, step: number): { number }
	local n = math.max(1, math.ceil(math.abs(b - a) / step - 1e-9))
	local out = table.create(n + 1)
	for k = 0, n do out[k + 1] = a + (b - a) * k / n end
	return out
end

-- Where everything goes, and the counts. `layout` is TrackLayout, `cfg` its churchill config.
function TrackDressing.plan(geom: Geometry, D, layout, cfg): Plan
	local out: Plan = { roof = {}, rail = {}, roofFlags = {}, spireFlags = {}, spireLinks = {}, parts = 0, beams = 0, textures = 0 }
	if D.bunting then
		local y = geom.roofUnderY - 1.3
		for _, z in stations(geom.z0, geom.z1, D.roofSpacing) do table.insert(out.roof, pt(geom.roofEdgeX - 0.3, y, z)) end
		local r = layout.outerRadius(cfg) + D.railPostOffset
		local from, to = cfg.finishFromTop - D.railFromFeet, cfg.finishFromTop + D.railPastFeet
		local _, _, lineZ = layout.finishLine(cfg)
		for _, d in stations(from, to, D.railSpacing) do
			local x, z = layout.atDistance(cfg, r, d)
			if math.abs(z - lineZ) > 3 or math.abs(x - r - cfg.centerX) > 1 then -- never a post on the finish line
				table.insert(out.rail, pt(x, 0, z))
			end
		end
		for _, f in geom.finials do
			for _, dz in { -60, 60 } do
				table.insert(out.spireLinks, { a = pt(geom.roofEdgeX - 0.3, geom.roofTopY - 0.5, f.z + dz), b = f })
			end
		end
		if #geom.finials >= 2 then
			table.insert(out.spireLinks, { a = geom.finials[1], b = geom.finials[2] })
		end
	end
	if D.flags then
		for _, z in stations(geom.z0 + 40, geom.z1 - 40, D.flagSpacing) do
			local clear = true
			for _, f in geom.finials do
				if math.abs(z - f.z) < D.flagClearOfSpires then clear = false end
			end
			if clear then table.insert(out.roofFlags, pt(geom.roofEdgeX + 6, geom.roofTopY, z)) end
		end
		for _, f in geom.finials do table.insert(out.spireFlags, f) end
	end
	-- Budget: trim the least-seen pieces first (roof flags, then the far rail bunting) if over a cap.
	local function count()
		out.parts = #out.rail + #out.roofFlags + #out.spireFlags -- one post or pole each; the flags are Beams
		out.beams = math.max(0, #out.roof - 1) + math.max(0, #out.rail - 1) + #out.spireLinks + #out.roofFlags + #out.spireFlags
	end
	count()
	while (out.parts > D.maxParts or out.beams > D.maxBeams) and #out.roofFlags > 0 do
		table.remove(out.roofFlags)
		count()
	end
	while (out.parts > D.maxParts or out.beams > D.maxBeams) and #out.rail > 0 do
		table.remove(out.rail)
		count()
	end
	while out.beams > D.maxBeams and #out.roof > 0 do
		table.remove(out.roof)
		count()
	end
	out.textures = if D.crowd then geom.tiers else 0
	return out
end

-- Roblox side ----------------------------------------------------------------------------------
local function v3(p: Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function buntingColours(): ColorSequence
	local keys = {}
	local n = #TrackDressing.BUNTING_HEX
	for k, hex in TrackDressing.BUNTING_HEX do -- hard steps: blocks of colour, like pennants from afar
		local c = Color3.fromHex(hex)
		table.insert(keys, ColorSequenceKeypoint.new((k - 1) / n, c))
		table.insert(keys, ColorSequenceKeypoint.new(math.min(1, k / n - 1e-3), c))
	end
	keys[#keys] = ColorSequenceKeypoint.new(1, keys[#keys].Value)
	return ColorSequence.new(keys)
end

-- An Attachment at world position p whose X axis (the Beam curve's axis) points down, so a positive
-- CurveSize0 and a negative CurveSize1 sag the Beam between two of them.
local function hang(parent: BasePart, p: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Parent = parent
	a.WorldCFrame = CFrame.fromMatrix(p, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
	return a
end

function TrackDressing.build(venue: Folder): Plan?
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
	local WorldArt = require(Shared:WaitForChild("WorldArt"))
	local D = GameConfig.trackDressing
	if not D or not D.enabled then return nil end

	local roof = venue:FindFirstChild("Roof")
	if not (roof and roof:IsA("BasePart")) then return nil end
	local finials, tiers = {}, {}
	for _, child in venue:GetChildren() do
		if child.Name == "Finial" and child:IsA("BasePart") then
			table.insert(finials, pt(child.Position.X, child.Position.Y + child.Size.Y / 2, child.Position.Z))
		elseif child.Name == "StandTier" and child:IsA("BasePart") then
			table.insert(tiers, child)
		elseif child.Name == "BigBoard" then
			CollectionService:AddTag(child, TrackDressing.TAG_BOARD)
		end
	end
	table.sort(finials, function(a, b) return a.z < b.z end)
	local geom: Geometry = {
		roofEdgeX = roof.Position.X - roof.Size.X / 2, roofTopY = roof.Position.Y + roof.Size.Y / 2,
		roofUnderY = roof.Position.Y - roof.Size.Y / 2, z0 = roof.Position.Z - roof.Size.Z / 2 + 5,
		z1 = roof.Position.Z + roof.Size.Z / 2 - 5, finials = finials, tiers = #tiers,
	}
	local plan = TrackDressing.plan(geom, D, TrackLayout, TrackLayout.churchill)

	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	local fallback = buntingColours()
	local bunting: { Beam } = {}
	local function beam(a0: Attachment, a1: Attachment, sag: number): Beam
		local b = Instance.new("Beam")
		b.Name = "Bunting"
		if D.buntingFlip then a0, a1 = a1, a0 end
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = D.buntingWidth, D.buntingWidth
		b.CurveSize0, b.CurveSize1 = if D.buntingFlip then -sag else sag, if D.buntingFlip then sag else -sag
		b.FaceCamera = true
		b.Segments = 12
		b.LightInfluence = 1
		b.Transparency = NumberSequence.new(0)
		b.Color = fallback
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = D.buntingTileStuds
		b.Parent = a0.Parent
		table.insert(bunting, b)
		return b
	end
	local function post(p: Vector3, height: number, name: string): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromHex(TrackDressing.POLE_HEX)
		part.Size = Vector3.new(0.6, height, 0.6)
		part.CFrame = CFrame.new(p + Vector3.new(0, height / 2, 0))
		part.Parent = folder
		return part
	end

	-- Roof edge: one line of sagging bunting, end to end.
	local prev: Attachment? = nil
	for _, p in plan.roof do
		local a = hang(roof, v3(p))
		if prev then beam(prev, a, D.sag) end
		prev = a
	end
	-- Homestretch rail: posts, with bunting from post top to post top.
	prev = nil
	for _, p in plan.rail do
		local part = post(v3(p), D.railPostStuds, "BuntingPost")
		local a = hang(part, v3(p) + Vector3.new(0, D.railPostStuds - 0.2, 0))
		if prev then beam(prev, a, D.sag * 0.6) end
		prev = a
	end
	-- Twin Spires: strings of pennants from each finial down to the roof edge, and between the spires.
	for _, link in plan.spireLinks do
		local a = hang(roof, v3(link.a))
		local b = hang(roof, v3(link.b) + Vector3.new(0, -0.5, 0))
		beam(a, b, D.sag * 2)
	end
	-- Flags: a pole with a pennant Beam from its top (hinge) to the tip, flown toward -Z (down the stretch).
	local flags: { Beam } = {}
	local function flag(base: Vector3, height: number)
		local pole = post(base, height, "Flagpole")
		local hinge = Instance.new("Attachment")
		hinge.Name = "FlagHinge"
		hinge.Parent = pole
		hinge.Position = Vector3.new(0, height / 2 - TrackDressing.FLAG_HEIGHT / 2, 0)
		local tip = Instance.new("Attachment")
		tip.Name = "FlagTip"
		tip.Parent = pole
		tip.Position = hinge.Position + Vector3.new(0, 0, -TrackDressing.FLAG_LENGTH)
		tip:SetAttribute("Length", TrackDressing.FLAG_LENGTH)
		tip:SetAttribute("HingeY", hinge.Position.Y)
		CollectionService:AddTag(tip, TrackDressing.TAG_FLAG)
		local b = Instance.new("Beam")
		b.Name = "Flag"
		b.Attachment0, b.Attachment1 = hinge, tip
		b.Width0, b.Width1 = TrackDressing.FLAG_HEIGHT, TrackDressing.FLAG_HEIGHT
		b.FaceCamera = true
		b.Segments = 6
		b.LightInfluence = 1
		b.Transparency = NumberSequence.new(0)
		b.Color = ColorSequence.new(Color3.fromHex(TrackDressing.FLAG_HEX))
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
		b.Parent = pole
		table.insert(flags, b)
	end
	for _, p in plan.roofFlags do flag(v3(p), TrackDressing.ROOF_POLE) end
	for _, p in plan.spireFlags do flag(v3(p), TrackDressing.SPIRE_POLE) end

	-- Images when they arrive (now if already loaded): white tint so the art shows its own colours.
	WorldArt.whenReady("bunting_strip", function(image)
		for _, b in bunting do
			b.Texture = image
			b.Color = ColorSequence.new(Color3.new(1, 1, 1))
		end
	end)
	WorldArt.whenReady("flag_pennant", function(image)
		for _, b in flags do
			b.Texture = image
			b.Color = ColorSequence.new(Color3.new(1, 1, 1))
		end
	end)
	if D.crowd then
		WorldArt.whenReady("crowd_strip", function(image)
			for _, tier in tiers do
				if not tier.Parent then continue end
				local t = Instance.new("Texture")
				t.Name = "Crowd"
				t.Texture = image
				t.Face = Enum.NormalId.Left -- -X: the grandstand faces the track
				t.StudsPerTileU, t.StudsPerTileV = D.crowdTileU, D.crowdTileV
				t:SetAttribute("Row", math.max(0, math.floor(tier.Size.Y / D.crowdTileV + 0.5) - 1))
				t.Parent = tier
				CollectionService:AddTag(t, TrackDressing.TAG_CROWD)
			end
		end)
	end
	folder.Parent = venue
	return plan
end

return TrackDressing
