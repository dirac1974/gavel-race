--!nonstrict
-- How a horse looks (fun-and-return phases 3 and 4, D-077, D-078), built in code (0 Meshy credits).
--   Wraps: the Cool-down Check's soft leg wraps, in the colour the kid picked, on the next
--   legs.wrapRaces races (Legs.takeWrap) and in the stall and on rides while they last (Legs.wrapNow).
--   The Veteran look: a frosted muzzle and brows and a silver-and-blue bridle rosette by the left ear
--   (gold on a Legend). Wise, never ill: no dull coat, no sunken eyes, nothing droops.
-- Parts are added to the model, massless, non-colliding, welded to the part they sit on (the leg or the
-- body), so they move with posed legs and the race bob. Positions are fractions of the model's
-- bounding box (GameConfig.horseLook; the model faces -Z), tuned in Studio.
-- `look` = { wrap = "hex"?, veteran = boolean?, legend = boolean? }. HorseLook.of / forRace are pure
-- (Lune); apply needs Roblox.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")
local Ageing = if script then require(script.Parent.Ageing) :: any else require("./Ageing")
local Legs = if script then require(script.Parent.Legs) :: any else require("./Legs")
local HorseLegs = if script then require(script.Parent.HorseLegs) :: any else require("./HorseLegs")

local HorseLook = {}

local function cfg(): any
	return GameConfig.horseLook or {}
end

-- The look for a horse record now (stall, rides): wraps while they last, Veteran or Legend.
function HorseLook.of(h: any): any?
	local races = h.record and h.record.races or 0
	local legend = h.legend ~= nil and h.legend ~= false
	local stage = Ageing.stage(races, legend)
	local look = {
		wrap = Legs.wrapNow(h),
		veteran = cfg().veteranLook ~= false and (stage == "Veteran" or (legend and races >= GameConfig.ageing.veteranAt)),
		legend = legend,
	}
	if not look.wrap and not look.veteran then return nil end
	return look
end

-- A bred foal's shape (D-080, GameConfig.foalLook): { body, legY } growing to 1 by growRaces counted
-- races (smoothstep), or nil for a grown or never-bred horse. Out of races only.
function HorseLook.foal(h: any): any?
	local F = GameConfig.foalLook
	if not F or F.enabled == false or h == nil or h.origin ~= "bred" then return nil end
	local races = tonumber(h.record and h.record.races) or 0
	local t = math.clamp(races / math.max(1, F.growRaces), 0, 1)
	if t >= 1 then return nil end
	local s = t * t * (3 - 2 * t)
	return { body = F.body + (1 - F.body) * s, legY = F.legY + (1 - F.legY) * s }
end

-- In races a foal is one uniform size, never under foalLook.raceMinScale (nil = full size).
function HorseLook.raceScale(h: any): number?
	local f = HorseLook.foal(h)
	if not f then return nil end
	local k = math.max(GameConfig.foalLook.raceMinScale, f.body)
	return if k < 1 then k else nil
end

-- A short key for the foal shape (the barn rebuilds as it grows), in 0.05 steps.
function HorseLook.foalKey(h: any): string
	local f = HorseLook.foal(h)
	return if f then "F" .. math.floor(f.body * 20 + 0.5) else ""
end

-- The look for a race: `wrap` is what Legs.takeWrap gave this race (wraps only when wrapsInRace);
-- `scale` a foal's uniform race size (D-080).
function HorseLook.forRace(h: any, wrap: string?): any?
	local look = HorseLook.of(h) or {}
	look.wrap = if cfg().wrapsInRace ~= false then wrap else nil
	look.scale = HorseLook.raceScale(h)
	if not look.wrap and not look.veteran and not look.scale then return nil end
	return look
end

-- A short key for a look (the barn rebuilds when it changes).
function HorseLook.key(look: any?): string
	if not look then return "" end
	return (look.wrap or "") .. (if look.veteran then "V" else "") .. (if look.legend then "L" else "")
end

-- Roblox only below ---------------------------------------------------------------------------------
local function find(model: Instance, name: string): BasePart?
	local p = model:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function biggest(model: Instance): BasePart?
	local best, size = nil, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Size.Magnitude > size then best, size = d, d.Size.Magnitude end
	end
	return best
end

local function piece(model: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, onto: BasePart, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.Anchored = false
	p.CastShadow = false
	p:SetAttribute("HorseLook", true)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = onto, p
	w.Parent = p
	p.Parent = model
	return p
end

-- Remove a look added before (a barn rebuild makes new models; this is for reused ones).
function HorseLook.clear(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("HorseLook") then d:Destroy() end
	end
end

local LEG_NAMES = { "LegFL", "LegFR", "LegBL", "LegBR" }

local function wraps(model: Model, color: Color3)
	local c = cfg().wrap or {}
	local legs = {}
	for _, n in LEG_NAMES do
		local leg = find(model, n)
		if leg then table.insert(legs, leg) end
	end
	if #legs == 0 then -- a placeholder horse: its four parts named Leg
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Leg" then table.insert(legs, d) end
		end
	end
	if #legs > 0 then
		for _, leg in legs do
			-- the lower part of the leg, a little wider than it (the leg's own frame, Y up the leg)
			local s = leg.Size
			local from, to = c.from or 0.08, c.to or 0.38
			local h = s.Y * (to - from)
			local y = -s.Y / 2 + s.Y * (from + to) / 2
			piece(model, "LegWrap", Vector3.new(s.X * (c.grow or 1.18), h, s.Z * (c.grow or 1.18)), leg.CFrame * CFrame.new(0, y, 0),
				color, leg, nil, Enum.Material.Fabric)
		end
		return
	end
	-- One-piece horse models: four soft bands where the legs stand, on the body (no separate legs to follow).
	local cf, size = model:GetBoundingBox()
	local body = find(model, "Body") or biggest(model)
	if not body then return end
	local base = cf * CFrame.new(0, -size.Y / 2, 0)
	for _, xz in { { -0.18, -0.36 }, { 0.18, -0.36 }, { -0.18, 0.36 }, { 0.18, 0.36 } } do
		local at = base * CFrame.new(xz[1] * size.X, size.Y * 0.12, xz[2] * size.Z)
		piece(model, "LegWrap", Vector3.new(size.X * 0.16, size.Y * 0.1, size.X * 0.16), at, color, body, nil, Enum.Material.Fabric)
	end
end

local function veteranLook(model: Model, legend: boolean)
	local c = cfg()
	local cf, size = model:GetBoundingBox()
	local body = find(model, "Body") or biggest(model)
	if not body then return end
	local base = cf * CFrame.new(0, -size.Y / 2, 0) -- bottom centre, facing -Z like the model
	local function at(spot): CFrame
		return base * CFrame.new(spot.x * size.X, spot.y * size.Y, spot.z * size.Z)
	end
	local frost = Color3.fromHex(c.frost or "E9ECEF")
	-- the frosted muzzle: a soft pale ball over the nose
	local m = c.muzzle or {}
	local mp = piece(model, "FrostMuzzle", Vector3.one * (m.size or 0.11) * size.Z, at(m), frost, body, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	mp.Transparency = c.frostTransparency or 0.25
	-- the brows: two little pale dashes above the eyes
	local b = c.brow or {}
	for _, sx in { -1, 1 } do
		local spot = { x = (b.x or 0.07) * sx, y = b.y or 0.86, z = b.z or -0.4 }
		local bp = piece(model, "FrostBrow", Vector3.new(size.X * 0.09, size.Y * 0.012, size.Z * (b.size or 0.05)), at(spot), frost, body)
		bp.Transparency = c.frostTransparency or 0.25
	end
	-- the bridle rosette by the left ear: 8 Fabric petals round a button
	local r = c.rosette or {}
	local centre = at(r) * CFrame.Angles(0, math.pi / 2, 0) -- facing sideways, out from the left cheek
	local px = (r.size or 0.07) * size.Z
	local petal = Color3.fromHex(if legend and c.legendRosette ~= false then (c.gold or "FFD23F") else (c.silver or "C0C7D4"))
	for k = 1, 8 do
		local a = (k - 1) * math.pi / 4
		piece(model, "VeteranRosette", Vector3.new(px * 0.2, px * 0.45, px * 0.45),
			centre * CFrame.new(0, math.cos(a) * px * 0.42, math.sin(a) * px * 0.42), petal, body, Enum.PartType.Ball, Enum.Material.Fabric)
	end
	piece(model, "VeteranRosette", Vector3.new(px * 0.25, px * 0.5, px * 0.5), centre * CFrame.new(-px * 0.05, 0, 0),
		Color3.fromHex(c.blue or "2F6FDE"), body, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
end

-- A foal's shape on a horse model already placed where it stands (D-080, the feel vote F2): the
-- whole model scaled by foal.body, then legs stretched to legY (relative to the body) from the hip
-- down; a one-piece model gets a gentler stretch upward instead (foalLook.onePieceStretch; 0 = uniform).
-- The hooves stay on the ground it stood on, and the legs' rest pose is re-recorded at the new size
-- (HorseLegs.markRest + forget), so running legs never splay. Call before welding or seating anything
-- to the model; a model shaped again (a growth step) is a fresh clone, re-recorded the same way.
function HorseLook.shapeFoal(model: Instance?, foal: any?)
	if not model or not foal or not model:IsA("Model") then return end
	local ok, err = pcall(function()
		local cf0, size0 = model:GetBoundingBox()
		local ground = cf0.Position.Y - size0.Y / 2
		model:ScaleTo(model:GetScale() * foal.body)
		local stretch = foal.legY / foal.body
		local legs = {}
		for _, n in LEG_NAMES do
			local leg = find(model, n)
			if leg then table.insert(legs, leg) end
		end
		if #legs > 0 then
			for _, leg in legs do
				local add = leg.Size.Y * (stretch - 1)
				local hip = leg.CFrame * CFrame.new(0, leg.Size.Y / 2, 0)
				leg.Size = Vector3.new(leg.Size.X, leg.Size.Y + add, leg.Size.Z)
				leg.CFrame = hip * CFrame.new(0, -leg.Size.Y / 2, 0)
			end
		else
			-- one piece: stretch everything upward a little from the hooves (long-legged, not squashed)
			local k = 1 + (stretch - 1) * (GameConfig.foalLook.onePieceStretch or 0) -- 0 = a uniform small foal
			local cf, size = model:GetBoundingBox()
			local bottom = cf.Position.Y - size.Y / 2
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local p = d.Position
					d.Size = Vector3.new(d.Size.X, d.Size.Y * k, d.Size.Z)
					d.CFrame = d.CFrame + Vector3.new(0, (p.Y - bottom) * (k - 1), 0)
				end
			end
		end
		local cf1, size1 = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() + Vector3.new(0, ground - (cf1.Position.Y - size1.Y / 2), 0))
		-- (the feel consult's must-fix) the running legs place each leg from its LegRest, recorded at
		-- adult size: record it again at this size and drop any cached pose, so legs stay under the body
		HorseLegs.markRest(model)
		HorseLegs.forget(model)
	end)
	if not ok then warn("[HorseLook] foal: " .. tostring(err)) end
end

-- Put a look on a horse model (already placed where it stands).
function HorseLook.apply(model: Instance?, look: any?)
	if not model or not look or not model:IsA("Model") then return end
	local ok, err = pcall(function()
		if look.wrap then wraps(model, Color3.fromHex(look.wrap)) end
		if look.veteran then veteranLook(model, look.legend == true) end
	end)
	if not ok then warn("[HorseLook] " .. tostring(err)) end
end

return HorseLook
