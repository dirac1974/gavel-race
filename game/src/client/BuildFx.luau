--!nonstrict
-- BuildFx (D-070, provisional): the Barn Builder build moment on this screen only. Nothing here
-- changes the server's barn: pieces are hidden, dropped in and painted locally.
--   BuildFx.hide(model)            a new piece waits, invisible, until you walk home to see it
--   BuildFx.dropIn(model, still)   it drops in: scale 0 -> 1.15 -> 1 (Back easing), a dust puff and a
--                                  sparkle burst; `still` (Reduced Motion or greenCash.buildFx off) fades it in
--   BuildFx.holdPaint(part, old)   a repainted barn part shows its old colour until you arrive...
--   BuildFx.sweep(part, still)     ...then the new colour sweeps across it over 0.6 s (still: a fade)
--   BuildFx.sparkle(at, n)         one burst of sparkles (a friend arriving at a fresh build)
--   BuildFx.reducedMotion()
-- STATUS: written without Studio access; verify in Studio before relying on it.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BuildFx = {}

local held: { [BasePart]: { new: Color3 } } = setmetatable({}, { __mode = "k" }) :: any

function BuildFx.reducedMotion(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

local function eachVisible(m: Instance, fn: (Instance) -> ())
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("SurfaceGui") or d:IsA("Decal") then fn(d) end
	end
end

function BuildFx.hide(m: Instance)
	eachVisible(m, function(d)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
			-- nothing invisible to bump into before the reveal (on this screen only)
			if d:GetAttribute("BaseCollide") == nil then d:SetAttribute("BaseCollide", d.CanCollide) end
			d.CanCollide = false
		elseif d:IsA("SurfaceGui") then
			d.Enabled = false
		elseif d:IsA("Decal") then
			if d:GetAttribute("BaseT") == nil then d:SetAttribute("BaseT", d.Transparency) end
			d.Transparency = 1
		end
	end)
	m:SetAttribute("BuildHidden", true)
end

local function show(m: Instance)
	eachVisible(m, function(d)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 0
			local c = d:GetAttribute("BaseCollide")
			if c ~= nil then d.CanCollide = c end
		elseif d:IsA("SurfaceGui") then
			d.Enabled = true
		elseif d:IsA("Decal") then
			d.Transparency = d:GetAttribute("BaseT") or 0
		end
	end)
	m:SetAttribute("BuildHidden", nil)
end

local function burst(at: Vector3, kind: string, n: number)
	if BuildFx.reducedMotion() then return end -- every sparkle and dust puff (code review N7)
	local p = Instance.new("Part")
	p.Name = "BuildFx"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	if kind == "dust" then
		e.Color = ColorSequence.new(Color3.fromHex("E3B985"))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(4, 8)
		e.SpreadAngle = Vector2.new(80, 10)
		e.Drag = 4
	else
		e.Color = ColorSequence.new(Color3.fromHex("FFE066"), Color3.fromHex("FFFFFF"))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(5, 10)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -4, 0)
	end
	e.Parent = p
	e:Emit(n)
	task.delay(2, function() p:Destroy() end)
end

-- A small dust puff (D-074: a ride horse landing a hop); none under Reduced Motion.
function BuildFx.dust(at: Vector3, n: number?)
	burst(at, "dust", n or 8)
end

function BuildFx.sparkle(at: Vector3, n: number?)
	burst(at, "sparkle", n or 24)
end

-- The piece drops in where it stands (Back easing, overshooting to 1.15), or fades in.
function BuildFx.dropIn(m: Model, still: boolean)
	if not m.Parent then return end
	local box, size = m:GetBoundingBox()
	local base = box.Position - Vector3.new(0, size.Y / 2, 0)
	if still then
		local parts = {}
		eachVisible(m, function(d) if d:IsA("BasePart") then table.insert(parts, d) end end)
		show(m)
		for _, d in parts do d.LocalTransparencyModifier = 1 end
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local a = math.clamp((os.clock() - t0) / 0.5, 0, 1)
			for _, d in parts do if d.Parent then d.LocalTransparencyModifier = 1 - a end end
			if a >= 1 then conn:Disconnect() end
		end)
		BuildFx.sparkle(box.Position, 12)
		return
	end
	local pivot0 = m:GetPivot()
	m:SetAttribute("Dropping", true) -- (the weathervane spinner leaves it alone meanwhile)
	m.WorldPivot = CFrame.new(base) * pivot0.Rotation -- scale about the foot of the piece
	local home = m:GetPivot()
	local ok = pcall(function() m:ScaleTo(0.05) end)
	show(m)
	if not ok then
		m:SetAttribute("Dropping", nil)
		BuildFx.sparkle(box.Position, 16)
		return
	end
	local t0 = os.clock()
	local GROW, SETTLE = 0.35, 0.25
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not m.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local s, drop
		if t < GROW then
			local a = TweenService:GetValue(t / GROW, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			s, drop = 0.05 + 1.1 * a, (1 - a) * 4
		else
			local a = math.clamp((t - GROW) / SETTLE, 0, 1)
			s, drop = 1.15 - 0.15 * TweenService:GetValue(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 0
		end
		pcall(function() m:ScaleTo(math.max(0.05, s)) end)
		m:PivotTo(home + Vector3.new(0, drop, 0))
		if t >= GROW + SETTLE then
			conn:Disconnect()
			pcall(function() m:ScaleTo(1) end)
			m:PivotTo(home)
			m:SetAttribute("Dropping", nil)
		end
	end)
	task.delay(GROW, function()
		burst(base + Vector3.new(0, 0.5, 0), "dust", 14)
		BuildFx.sparkle(box.Position + Vector3.new(0, size.Y * 0.2, 0), 24)
	end)
end

-- "✨ Here!" over a hidden piece until it's on screen (the feel consult): turn toward it to see it build.
function BuildFx.marker(at: Vector3): BillboardGui
	local p = Instance.new("Part")
	p.Name = "BuildHere"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(at)
	p.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 52)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 250
	bb.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromHex("FFF7E6")
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 26
	t.TextColor3 = Color3.fromHex("1D2433")
	t.Text = "✨ Here!"
	t.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = t
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromHex("1D2433")
	st.Parent = t
	return bb
end

-- Is `at` on screen and within `maxDeg` of where the camera looks?
function BuildFx.inView(at: Vector3, maxDeg: number): boolean
	local cam = workspace.CurrentCamera
	if not cam then return false end
	local _, onScreen = cam:WorldToViewportPoint(at)
	if not onScreen then return false end
	local to = at - cam.CFrame.Position
	if to.Magnitude < 1 then return true end
	return cam.CFrame.LookVector:Dot(to.Unit) >= math.cos(math.rad(maxDeg))
end

-- Paint: keep the old colour on this screen until the build moment.
function BuildFx.holdPaint(p: BasePart, old: Color3)
	if p.Color == old then return end
	held[p] = { new = p.Color }
	p.Color = old
end

function BuildFx.holding(): boolean
	for p in held do
		if p.Parent then return true end
	end
	return false
end

-- The new colour sweeps across the part from one side (a cover in the old colour shrinks away).
function BuildFx.sweep(p: BasePart, still: boolean)
	local h = held[p]
	held[p] = nil
	if not h or not p.Parent then return end
	if still then
		TweenService:Create(p, TweenInfo.new(0.5), { Color = h.new }):Play()
		return
	end
	local cover = p:Clone()
	for _, ch in cover:GetChildren() do ch:Destroy() end
	cover.Name = "PaintCover"
	cover.CanCollide, cover.CanQuery, cover.CanTouch = false, false, false
	cover.Size = p.Size + Vector3.new(0.06, 0.06, 0.06)
	cover.Parent = workspace
	p.Color = h.new
	local start = cover.CFrame
	local w = cover.Size.X
	TweenService:Create(cover, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Size = Vector3.new(0.05, cover.Size.Y, cover.Size.Z),
		CFrame = start * CFrame.new(w / 2, 0, 0),
	}):Play()
	task.delay(0.65, function() cover:Destroy() end)
end

function BuildFx.sweepAll(still: boolean): Vector3?
	local centre, n = Vector3.zero, 0
	for p in held do
		if p.Parent then
			centre += p.Position
			n += 1
			BuildFx.sweep(p, still)
		end
	end
	table.clear(held)
	return if n > 0 then centre / n else nil
end

-- Weathervanes (BarnDecor, tag "Weathervane"): each VaneSpin turns slowly on this screen; held still
-- with Reduced Motion. Only vanes near the camera are turned.
function BuildFx.startVanes()
	local CollectionService = game:GetService("CollectionService")
	local base: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
	local nextAt = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextAt then return end
		nextAt = now + 1 / 20
		if BuildFx.reducedMotion() then return end
		local cam = workspace.CurrentCamera
		for _, spin in CollectionService:GetTagged("Weathervane") do
			local build = spin:IsA("Model") and spin.Parent and spin:FindFirstAncestorWhichIsA("Model")
			if build and not build:GetAttribute("Dropping") and not build:GetAttribute("BuildHidden") then
				base[spin] = base[spin] or spin:GetPivot()
				local b = base[spin]
				if not cam or (cam.CFrame.Position - b.Position).Magnitude < 400 then
					local a = now * 0.25 + 0.35 * math.sin(now * 0.4)
					spin:PivotTo(CFrame.new(b.Position) * CFrame.Angles(0, a, 0) * b.Rotation)
				end
			end
		end
	end)
end

return BuildFx
