--!nonstrict
-- TrainingRideClient (D-053): the ride part of training on this screen.
--   TrainBegin -> 3-2-1 while the horse waits at the start, then Go!: the next hoop (or
--   gymkhana piece) glows, hoofprints lead to it, and dots fill as you go (laps on Sprint
--   Lane, pieces on Mud Splash). No timer anywhere. "Clean hop!", "Splash!" and sparkles when
--   you get one; nothing at all for a miss.
--   A big Jump button on phones (a seated rider has no jump button) hops the horse; keyboard
--   Space and gamepad A hop it as in free riding (RideClient).
--   TrainEnd -> the end card: stars, then the stat bar grows, then the ribbon; Ride again or
--   Done. After the weekly cap: "Speed is full this week. Ride for stars!"
--   TrainAbort -> a gentle note and everything goes away.
--   Gate Break (T3): the practice gate's doors on this screen; TrainCue moments from the server:
--   "Ready…", the bell (doors swing open, "GO!"), "Wait for the bell!", "Great start!", then back
--   round the loop to the gate (the horse stops by itself in the middle of the stall). A stick
--   still pushed from riding in must be let go once before the horse can leave the stall, so
--   nobody is launched into an early go.
--   The countdown and Pip run on the server's clock (TrainBegin's go time and
--   workspace:GetServerTimeNow()), so Pip on this screen is the server's Pip.
--   Hill Climb (T3): Pip the lead pony (a palomino at 0.85 scale in a teal lead-pony cloth) runs
--   ponyAt(seed, t) on this screen only; a glowing ring behind him; inside it your horse keeps
--   Pip's pace by itself. "Stay with Pip!" is the only nudge.
--   Easy Rein (Settings): TrainingState.aim is where RideClient steers strongly.
--   Ghosts (T4): TrainGhosts brings your best ride on the course (and, riding alone, friends'
--   who share theirs); each runs as a see-through horse on the ride clock.
--   Ride together (T4): a friend's invite shows as a card at the top right (away from the
--   thumbstick) with "Ride together" and "Not now"; taps in its first half second don't count,
--   nothing happens unless you accept, and it goes away by itself. While a shop or game panel
--   is open the invite is answered "busy". After the ride the end card shows how your friend
--   did, in stars and ribbons only. In a Gate Break together your friend fades on your screen
--   while you wait in the stall, so their go never looks like yours.
--   This week's course (T5): Mud Splash rides the layout the server picked (TrainBegin's course
--   key, grit_w1..grit_w4); GymkhanaView keeps that layout's props in the arena until the ride
--   ends, even if the week turns over meanwhile.
-- The glow, hoofprints and feedback come from this client's own position with the same
-- tracker the server uses; the server's samples decide the score.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local TrainingState = require(script.Parent:WaitForChild("TrainingState"))
local GymkhanaView = require(script.Parent:WaitForChild("GymkhanaView"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TrainingCourses = require(Shared:WaitForChild("TrainingCourses"))
local TrainingRide = require(Shared:WaitForChild("TrainingRide"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local TrainStart = remotes:WaitForChild("TrainStart")
local TrainBegin = remotes:WaitForChild("TrainBegin")
local TrainEnd = remotes:WaitForChild("TrainEnd")
local TrainAbort = remotes:WaitForChild("TrainAbort")
local TrainCue = remotes:WaitForChild("TrainCue")
local TrainGhosts = remotes:WaitForChild("TrainGhosts")
local TrainInvited = remotes:WaitForChild("TrainInvited")
local TrainInviteReply = remotes:WaitForChild("TrainInviteReply")
local TrainInviteGone = remotes:WaitForChild("TrainInviteGone")
local TrainTogether = remotes:WaitForChild("TrainTogether")
local Ghost = require(Shared:WaitForChild("Ghost"))
local RideTogether = require(Shared:WaitForChild("RideTogether"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))
local CFG = GameConfig.training
local TC = TrainingCourses
local C = Ui.colors
local GROUND_Y = TC.GROUND_Y

local function play(name: string, volume: number?)
	if Sound then Sound.play(name, volume) end
end

-- My ride rig, if I'm in its saddle (the same test as RideClient).
local function myRide(): Model?
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local seat = h and h.SeatPart
	if seat and seat.Name == "Saddle" and seat.Parent and seat.Parent.Parent and seat.Parent.Parent.Name == "RideHorses"
		and seat.Parent:GetAttribute("Owner") == player.UserId then
		return seat.Parent
	end
	return nil
end

-- HUD -----------------------------------------------------------------------------------------
local gui = Ui.screen("TrainingRide", 12)
local hud = Instance.new("Frame")
hud.BackgroundTransparency = 1
hud.Size = UDim2.fromScale(1, 1)
hud.Visible = false
hud.Parent = gui
local courseLabel = Ui.text(hud, "", 26, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0, 360, 0, 32) })
courseLabel.TextStrokeTransparency = 0.5
courseLabel.TextColor3 = C.white
local dots = Instance.new("Frame")
dots.BackgroundTransparency = 1
dots.AnchorPoint = Vector2.new(0.5, 0)
dots.Position = UDim2.new(0.5, 0, 0, 48)
dots.Size = UDim2.new(0, 400, 0, 26)
dots.Parent = hud
local dotLayout = Instance.new("UIListLayout")
dotLayout.FillDirection = Enum.FillDirection.Horizontal
dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotLayout.Padding = UDim.new(0, 8)
dotLayout.Parent = dots
local stopBtn = Ui.button(hud, "✕ Stop", UDim2.fromOffset(104, 46), UDim2.new(1, -16, 0, 64), C.white, 20)
stopBtn.AnchorPoint = Vector2.new(1, 0)
local countdown = Ui.text(gui, "", 120, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0, 400, 0, 140), Visible = false })
countdown.TextColor3 = C.gold
countdown.TextStrokeTransparency = 0
countdown.TextStrokeColor3 = C.ink
local cheer = Ui.text(gui, "", 44, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0, 500, 0, 60), Visible = false })
cheer.TextColor3 = C.white
cheer.TextStrokeTransparency = 0
cheer.TextStrokeColor3 = C.ink
-- Phones: a big Jump button above the dock, where the Gallop button sits in free riding.
local jumpBtn = Ui.button(gui, "⬆️\nJump", UDim2.fromOffset(104, 104), UDim2.new(1, -20, 1, -112), C.gold, 26)
jumpBtn.AnchorPoint = Vector2.new(1, 1)
jumpBtn:SetAttribute("NoPop", true)
jumpBtn.Visible = false

local function say(text: string, color: Color3?)
	cheer.Text = text
	cheer.TextColor3 = color or C.white
	cheer.Visible = true
	cheer.TextTransparency, cheer.TextStrokeTransparency = 0, 0
	cheer.Position = UDim2.fromScale(0.5, 0.32)
	TweenService:Create(cheer, TweenInfo.new(0.9), { Position = UDim2.fromScale(0.5, 0.26), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function hop()
	local rig = myRide()
	local hh = rig and rig:FindFirstChildOfClass("Humanoid")
	-- The horse hops; the rider stays in the saddle (their own jump stays off while riding).
	if hh and TrainingState.phase == "ride" and hh.FloorMaterial ~= Enum.Material.Air then hh.Jump = true end
end
jumpBtn.MouseButton1Down:Connect(hop)

-- Glow and hoofprints (on this screen only) --------------------------------------------------
local printsFolder = Instance.new("Folder")
printsFolder.Name = "TrainingHoofprints"
printsFolder.Parent = workspace
local glowing: { [BasePart]: { Color3 | Enum.Material } } = {}

local function clearGlow()
	for p, was in glowing do
		if p.Parent then p.Color, p.Material = was[1] :: Color3, was[2] :: Enum.Material end
	end
	table.clear(glowing)
end

-- A piece of the course by name: "Hoop3", "Mud1" ... (gymkhana), "Finish" (the gymkhana's
-- arch) or "StartLine" (the oval's start and finish line). The gymkhana on this screen is the
-- layout GymkhanaView shows (the one being ridden).
local function courseModel(name: string): Instance?
	if string.sub(name, 1, 4) ~= "Hoop" and name ~= "StartLine" then return GymkhanaView.find(name) end
	local world = workspace:FindFirstChild("World")
	local tg = world and world:FindFirstChild("TrainingGround")
	if not tg then return nil end
	if name == "StartLine" then return tg:FindFirstChild("StartLine") end
	local folder = tg:FindFirstChild("Hoops")
	return folder and folder:FindFirstChild(name)
end

local function glow(name: string?)
	clearGlow()
	local m = name and courseModel(name)
	if not m then return end
	local parts = if m:IsA("BasePart") then { m } else m:GetDescendants()
	for _, d in parts do
		if d:IsA("BasePart") then
			glowing[d] = { d.Color, d.Material }
			d.Color, d.Material = C.gold, Enum.Material.Neon
		end
	end
end

local function glowParts(parts: { BasePart })
	clearGlow()
	for _, d in parts do
		glowing[d] = { d.Color, d.Material }
		d.Color, d.Material = C.gold, Enum.Material.Neon
	end
end

local function trainingGround(): Instance?
	local world = workspace:FindFirstChild("World")
	return world and world:FindFirstChild("TrainingGround")
end

local function flagParts(): { BasePart }
	local out = {}
	local tg = trainingGround()
	for _, name in { "FlagPole", "Flag", "FlagLine" } do
		local p = tg and tg:FindFirstChild(name)
		if p and p:IsA("BasePart") then table.insert(out, p) end
	end
	return out
end

local function clearPrints()
	printsFolder:ClearAllChildren()
end

local function printAt(x: number, z: number, side: number, fx: number, fz: number)
	local y = GROUND_Y + TC.groundHeight(x, z) + 0.18
	local p = Instance.new("Part")
	p.Name = "Hoofprint"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.1, 1.3, 1.3)
	p.Color = C.ink
	p.Transparency = 0.45
	p.Material = Enum.Material.SmoothPlastic
	-- step a little left and right of the line, like hooves
	local lx, lz = -fz * side * 0.7, fx * side * 0.7
	p.CFrame = CFrame.new(x + lx, y, z + lz) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = printsFolder
end

-- Prints along a list of points, every `gap` studs, at most `max`.
local function printsAlong(pts: { { x: number, z: number } }, gap: number, max: number)
	clearPrints()
	local carry, n, side = gap * 0.5, 0, 1
	for k = 2, #pts do
		local a, b = pts[k - 1], pts[k]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 1e-6 then
			local fx, fz = dx / len, dz / len
			local at = carry
			while at <= len do
				printAt(a.x + fx * at, a.z + fz * at, side, fx, fz)
				side, n = -side, n + 1
				if n >= max then return end
				at += gap
			end
			carry = at - len
		end
	end
end

-- Course extras: the practice gate's doors, Pip and his ring (this screen only) ---------------
local extras: { Instance } = {}
local doors: { { part: BasePart, closed: CFrame, open: CFrame } } = {}

local function clearExtras()
	for _, inst in extras do inst:Destroy() end
	table.clear(extras)
	table.clear(doors)
end

local function localPart(props): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do (p :: any)[k] = v end
	p.Parent = printsFolder.Parent
	table.insert(extras, p)
	return p
end

local function buildDoors()
	local ac = TC.courses.accel
	local gz = ac.start.z
	local half = ac.stallWidth / 2
	for _, sd in { -1, 1 } do
		-- hinged at the stall's front corners; opening swings them forward
		local hinge = CFrame.new(ac.doorX + 0.25, GROUND_Y + 2.8, gz + sd * half)
		local offset = CFrame.new(0, 0, -sd * half / 2)
		local part = localPart({ Name = "GateDoor", Size = Vector3.new(0.3, 4.4, half - 0.1), Color = C.red,
			Material = Enum.Material.SmoothPlastic, CFrame = hinge * offset })
		table.insert(doors, { part = part, closed = hinge * offset, open = hinge * CFrame.Angles(0, -sd * 1.6, 0) * offset })
	end
end

local function setDoors(open: boolean, lit: boolean)
	for _, d in doors do
		d.part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		d.part.Color = if lit then C.gold else C.red
		TweenService:Create(d.part, TweenInfo.new(if open then 0.25 else 0.4, Enum.EasingStyle.Quad),
			{ CFrame = if open then d.open else d.closed }):Play()
	end
end

local PIP_SCALE = 0.85
local function buildPip(): Model
	local f = ReplicatedStorage:FindFirstChild("RaceModels")
	local anim = f and f:FindFirstChild("horse_anim_palomino")
	if anim and not HorseLegs.has(anim) then anim = nil end
	local src = f and (anim or f:FindFirstChild("horse_stand_palomino") or f:FindFirstChild("horse_palomino"))
	local m: Model
	if src then
		m = src:Clone()
	else
		m = Instance.new("Model")
		local body = Instance.new("Part")
		body.Size, body.Color = Vector3.new(2, 2.6, 5.5), Ui.coatColors.palomino
		body.CFrame = CFrame.new(0, 3, 0)
		body.Parent = m
		m.PrimaryPart = body
		m.WorldPivot = CFrame.new()
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
	end
	if src then
		pcall(function() m:ScaleTo(m:GetScale() * PIP_SCALE) end)
		if HorseLegs.has(m) then HorseLegs.markRest(m) end -- legs rest where the smaller pony has them
	end
	-- the lead pony's cloth: the fitted Cloth piece, teal, "Pip" on both sides
	local cloth = m:FindFirstChild("Cloth", true)
	if cloth and cloth:IsA("MeshPart") then
		cloth.TextureID = ""
		cloth.Material = Enum.Material.Fabric
		cloth.Color = C.teal
		cloth.Transparency = 0
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local sg = Instance.new("SurfaceGui")
			sg.Face = face
			sg.CanvasSize = Vector2.new(200, 120)
			sg.Parent = cloth
			local l = Instance.new("TextLabel")
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5, 0.6)
			l.Size = UDim2.fromScale(0.6, 0.45)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.TextColor3 = C.white
			l.Text = "Pip"
			l.Parent = sg
		end
	end
	local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if anchor then
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(120, 30)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
		tag.AlwaysOnTop = true
		tag.Parent = anchor
		local l = Ui.text(tag, "Pip 🐴", 22, { Size = UDim2.fromScale(1, 1), TextScaled = true })
		l.TextColor3 = C.white
		l.TextStrokeTransparency = 0.3
	end
	m.Name = "Pip"
	m.Parent = printsFolder.Parent
	table.insert(extras, m)
	return m
end

-- A see-through horse for a ghost (the coat it was ridden on), labelled.
local function buildGhost(coat: string?, text: string, mine: boolean): Model
	local f = ReplicatedStorage:FindFirstChild("RaceModels")
	local c = coat or "bay"
	local anim = f and f:FindFirstChild("horse_anim_" .. c)
	if anim and not HorseLegs.has(anim) then anim = nil end
	local src = f and (anim or f:FindFirstChild("horse_stand_" .. c) or f:FindFirstChild("horse_gallop_" .. c) or f:FindFirstChild("horse_" .. c))
	local m: Model
	if src then
		m = src:Clone()
	else
		m = Instance.new("Model")
		local body = Instance.new("Part")
		body.Size, body.Color = Vector3.new(2, 3, 6.5), Ui.coatColors[c] or Ui.coatColors.bay
		body.CFrame = CFrame.new(0, 3.5, 0)
		body.Parent = m
		m.PrimaryPart = body
		m.WorldPivot = CFrame.new()
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
			d.Transparency = math.max(d.Transparency, if mine then 0.6 else 0.7)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = math.max(d.Transparency, 0.6)
		end
	end
	local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if anchor then
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(150, 26)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
		tag.MaxDistance = 120
		tag.Parent = anchor
		local l = Ui.text(tag, "👻 " .. text, 18, { Size = UDim2.fromScale(1, 1), TextScaled = true })
		l.TextColor3 = C.white
		l.TextStrokeTransparency = 0.4
		l.TextTransparency = 0.2
	end
	m.Name = "Ghost"
	m.Parent = printsFolder.Parent
	table.insert(extras, m)
	return m
end

local function placePip(pip: Model, pony: any, dt: number?, last: Vector3?): Vector3
	local _, _, tx, tz = TC.ovalPoint(pony.d, pony.lateral)
	local pos = Vector3.new(pony.x, GROUND_Y + pony.y, pony.z)
	pip:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(tx, 0, tz)))
	if dt and HorseLegs.has(pip) then HorseLegs.apply(pip, if last then (pos - last).Magnitude else 0, dt) end
	return pos
end

-- Points along a route from where you are to its end (the practice gate's loop back).
local function routeAhead(route: any, x: number, z: number, hint: number): { { x: number, z: number } }
	local _, _, k = TC.routeCarrot(route, x, z, hint, 0)
	local pts = { { x = x, z = z } }
	for i = k + 1, #route.points do table.insert(pts, route.points[i]) end
	return pts
end

-- Session --------------------------------------------------------------------------------------
local session = nil -- { course, c, tracker, goAt, base, baseY, target, prev, got = {} }

-- Dots: done ones gold, the one you're on orange (laps on Sprint Lane, pieces on Mud Splash).
local function setDots(count: number, filled: number, current: boolean?)
	if dots:GetAttribute("Count") ~= count then
		dots:SetAttribute("Count", count)
		for _, ch in dots:GetChildren() do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		local size = if count > 6 then 18 else 24
		for k = 1, count do
			local d = Instance.new("Frame")
			d.Name = "Dot" .. k
			d.LayoutOrder = k
			d.Size = UDim2.fromOffset(size, size)
			d.BackgroundColor3 = C.white
			Ui.corner(d, size // 2)
			Ui.stroke(d, 2)
			d.Parent = dots
		end
	end
	for k = 1, count do
		local d = dots:FindFirstChild("Dot" .. k)
		if d then
			local state = if k <= filled then "done" elseif current and k == filled + 1 then "now" else "todo"
			if d:GetAttribute("State") ~= state then
				d:SetAttribute("State", state)
				d.BackgroundColor3 = if state == "done" then C.gold elseif state == "now" then C.orange else C.white
				if state == "done" then Ui.pop(d) end
			end
		end
	end
end

local fadePartners: (any, boolean) -> () -- defined with Gate Break below (stopVisuals needs it first)

local function stopVisuals()
	if session then fadePartners(session, false) end
	session = nil
	TrainingState.reset()
	clearGlow()
	clearPrints()
	clearExtras()
	GymkhanaView.unpin() -- the arena follows the week again (a new week's layout shows now)
	hud.Visible = false
	countdown.Visible = false
	jumpBtn.Visible = false
end

-- Hoofprints from where you are to the target.
local function speedPrints(tr, hp)
	local post = TC.courses.speed.posts[hp.post]
	local d0 = tr.lastD
	local ahead = math.max(0, hp.s - tr.progress)
	local rig = myRide()
	local root = rig and rig.PrimaryPart
	local lat0 = 0
	if root then
		local _, l = TC.ovalProject(root.Position.X, root.Position.Z)
		lat0 = math.clamp(l, -CFG.oval.width / 2, CFG.oval.width / 2)
	end
	local pts = {}
	local steps = math.max(2, math.floor(ahead / 6))
	for k = 0, steps do
		local f = k / steps
		local x, z = TC.ovalPoint(d0 + ahead * f, lat0 * (1 - f) + post.lateral * f)
		table.insert(pts, { x = x, z = z })
	end
	printsAlong(pts, 7, 18)
end

-- After the last hoop: hoofprints from where you are to the finish line.
local function finishPrints(tr)
	local c = TC.courses.speed
	local ahead = math.max(0, c.finish - tr.progress)
	local rig = myRide()
	local root = rig and rig.PrimaryPart
	local lat0 = 0
	if root then
		local _, l = TC.ovalProject(root.Position.X, root.Position.Z)
		lat0 = math.clamp(l, -CFG.oval.width / 2, CFG.oval.width / 2)
	end
	local pts = {}
	local steps = math.max(2, math.floor(ahead / 6))
	for k = 0, steps do
		local f = k / steps
		local x, z = TC.ovalPoint(tr.lastD + ahead * f, lat0 * (1 - f))
		table.insert(pts, { x = x, z = z })
	end
	printsAlong(pts, 7, 18)
end

-- Per Mud Splash layout: gymkhana piece -> nearest route point.
local routeIndexes: { [string]: { [number]: number } } = {}
local function routeIndexFor(g): { [number]: number }
	local cached = routeIndexes[g.key]
	if cached then return cached end
	local routeIndex = {}
	for i, e in g.elements do
		local best, bestD = 1, math.huge
		for k, pt in g.route.points do
			local d = (pt.x - e.x) ^ 2 + (pt.z - (e.weaveZ or e.z)) ^ 2
			if d < bestD then best, bestD = k, d end
		end
		routeIndex[i] = best
	end
	routeIndexes[g.key] = routeIndex
	return routeIndex
end

local function gritPrints(g, index: number)
	local routeIndex = routeIndexFor(g)
	local rig = myRide()
	local root = rig and rig.PrimaryPart
	if not root then return end
	local pos = root.Position
	local startK, bestD = 1, math.huge
	local stop = routeIndex[index] or #g.route.points
	for k = math.max(1, (routeIndex[index - 1] or 1) - 2), stop do
		local pt = g.route.points[k]
		local d = (pt.x - pos.X) ^ 2 + (pt.z - pos.Z) ^ 2
		if d < bestD then startK, bestD = k, d end
	end
	local pts = { { x = pos.X, z = pos.Z } }
	for k = startK + 1, stop do table.insert(pts, g.route.points[k]) end
	local e = g.elements[index]
	if e then table.insert(pts, { x = e.x, z = e.weaveZ or e.z }) end
	printsAlong(pts, 6, 18)
end

local function sampleNow(s): any?
	local rig = myRide()
	local root = rig and rig.PrimaryPart
	if not root then return nil end
	local pos = root.Position
	local hh = (rig :: Model):FindFirstChildOfClass("Humanoid")
	local y = pos.Y - (s.baseY or pos.Y) - TC.groundHeight(pos.X, pos.Z)
	if hh and hh.FloorMaterial ~= Enum.Material.Air then y = math.min(y, 0.5) end -- on the ground, whatever the baseline says
	return { t = TrainingRide.rideClock(workspace:GetServerTimeNow(), s.goAtServer), x = pos.X, z = pos.Z, y = y }
end

local function onGo(s)
	table.sort(s.base)
	s.baseY = if #s.base > 0 then s.base[(#s.base + 1) // 2] else nil
	s.tracker = TrainingRide.tracker(s.course)
	s.prev = sampleNow(s)
	TrainingState.phase = "ride"
	if s.course == "accel" then
		-- Gate Break starts on the bell, not here: no "Go!", and nothing hides "Ready…" later
		if s.gate == "countdown" then
			s.gate = "settle"
			countdown.Visible = false
		end
		return
	end
	countdown.Text = "Go!"
	Ui.pop(countdown)
	play("vo_giddyup", 0.8)
	task.delay(0.7, function()
		if session == s then countdown.Visible = false end
	end)
end

local function beginSession(course: string, n: number, seed: number, goAtServer: number, partners: { number }?)
	stopVisuals()
	local c = TC.courses[course]
	if not c then return end
	local s = { course = course, c = c, seed = seed, goAtServer = goAtServer, base = {}, got = {}, target = nil, recent = {},
		hops = {}, hoopsHit = 0, hint = 1, breaksDone = 0, gate = "countdown", outSince = nil, nudgedAt = -math.huge,
		released = false, partners = partners or {} }
	session = s
	TrainingState.active, TrainingState.course, TrainingState.phase = true, course, "countdown"
	courseLabel.Text = c.emoji .. " " .. c.name
	local dotCount = if course == "speed" or course == "stamina" then c.laps
		elseif course == "accel" then CFG.accel.breaks else #c.elements
	setDots(dotCount, 0, true)
	if c.kind == "arena" then
		GymkhanaView.pin(course) -- this ride's layout stays in the arena until it ends
	end
	if course == "accel" then
		buildDoors()
	elseif course == "stamina" then
		s.pip = buildPip()
		s.pipPos = placePip(s.pip, TC.ponyAt(seed, 0))
		s.ring = localPart({ Name = "PipRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 14, 14), Color = C.gold,
			Material = Enum.Material.Neon, Transparency = 0.55, CastShadow = false })
	end
	hud.Visible = true
	jumpBtn.Visible = UserInputService.TouchEnabled
	countdown.Visible = true
	task.spawn(function()
		-- 3-2-1 on the server's clock: GO is the server's go time, however late we got here
		local shown = nil
		while session == s do
			local left = goAtServer - workspace:GetServerTimeNow()
			if left <= 0 then break end
			local k = math.max(1, math.ceil(left))
			if k ~= shown then
				shown = k
				countdown.Text = tostring(k)
				Ui.pop(countdown)
				play("ui_pop")
			end
			local rig = myRide() -- the horse's riding height, while it stands at the start
			if rig and rig.PrimaryPart then table.insert(s.base, rig.PrimaryPart.Position.Y) end
			task.wait(math.min(0.1, math.max(0, left)))
		end
		if session == s then onGo(s) end
	end)
end

local function cheerFor(s, prev, cur)
	local g = CFG.grit
	-- Logs: decided a moment after the crossing, with the server's rule (airborne within
	-- logWindow studs of the log).
	table.insert(s.recent, cur)
	while #s.recent > 0 and cur.t - s.recent[1].t > 1 do table.remove(s.recent, 1) end
	for i = #s.hops, 1, -1 do
		local hop = s.hops[i]
		if cur.t - hop.x.t >= 0.3 then
			table.remove(s.hops, i)
			if not s.got[hop.e.name] and TrainingRide.cleared(s.recent, hop.x, hop.e, g) then
				s.got[hop.e.name] = true
				say("Clean hop!", C.gold)
				play("tap_good", 0.7)
			end
		end
	end
	if s.course == "speed" then
		-- the tracker counts hoops with the server's rule
		local n = 0
		for _ in s.tracker.hit do n += 1 end
		if n > s.hoopsHit then
			s.hoopsHit = n
			say("✨", C.gold)
			play("tap_good", 0.6)
		end
		return
	end
	for _, e in s.c.elements do
		if not s.got[e.name] then
			if e.kind == "mud" then
				if TC.inRect(e.rect, cur.x, cur.z) then
					s.got[e.name] = true
					say("Splash! 💦", C.sky)
					play("tap_good", 0.6)
				end
			else
				local xs = TrainingRide.crossings({ prev, cur }, e.gate)
				if xs[1] and xs[1].dir > 0 then
					if e.kind == "pole" then
						s.got[e.name] = true
						say("Nice bend!", C.white)
						play("tap_good", 0.5)
					else
						table.insert(s.hops, { e = e, x = xs[1] }) -- a grounded crossing just doesn't score
					end
				end
			end
		end
	end
end

-- Riding Gate Break together: your friend's horse and rider fade on your screen while you wait
-- in the stall, so their go (at their own bell) never looks like yours.
local function partnerParts(s): { BasePart }
	local out = {}
	local folder = workspace:FindFirstChild("RideHorses")
	for _, uid in s.partners or {} do
		for _, rig in (if folder then folder:GetChildren() else {}) do
			if rig:GetAttribute("Owner") == uid then
				for _, d in rig:GetDescendants() do
					if d:IsA("BasePart") then table.insert(out, d) end
				end
			end
		end
		local other = Players:GetPlayerByUserId(uid)
		for _, d in (if other and other.Character then other.Character:GetDescendants() else {}) do
			if d:IsA("BasePart") then table.insert(out, d) end
		end
	end
	return out
end

fadePartners = function(s, on: boolean)
	if not s.partners or #s.partners == 0 then return end
	if not on and not s.faded then return end
	for _, part in partnerParts(s) do
		if on then
			part.LocalTransparencyModifier = math.max(part.LocalTransparencyModifier, 0.85)
		else
			-- the standing and galloping models take turns (RideClient's Shown); everything else shows
			local pose = part:FindFirstAncestor("Stand") or part:FindFirstAncestor("Gallop")
			part.LocalTransparencyModifier = if pose and pose:GetAttribute("Shown") == false then 1 else 0
		end
	end
	s.faded = on
end

-- Gate Break: pace, aim, glow and prints for where you are in a break.
--   settle / back: canter; stop by itself in the middle of the stall
--   ready / bell:  standing in the stall; the stick must be let go once after coming in, then
--                  any push is a go (early before the bell)
--   dash:          gallop to the flag
local STICK_DEADZONE = 0.2
local function gateFrame(s, cur)
	local ac = TC.courses.accel
	local gz = ac.start.z
	-- where the horse stops: the middle of the stall (doorX - 8 .. doorX)
	local hold = { ac.doorX - 5.5, gz - 3, ac.doorX - 1.5, gz + 3 }
	setDots(CFG.accel.breaks, s.breaksDone, true)
	fadePartners(s, s.gate ~= "dash" and TC.inRect(ac.stall, cur.x, cur.z))
	if not TC.inRect(ac.stall, cur.x, cur.z) then
		s.released = false
	elseif (TrainingState.stick or 0) < STICK_DEADZONE then
		s.released = true
	end
	if s.gate == "ready" or s.gate == "bell" then
		TrainingState.speed = if s.released then nil else 0
		TrainingState.aim = { x = ac.flag.ax + 10, z = gz }
		return
	elseif s.gate == "dash" then
		TrainingState.speed = nil -- a gallop
		TrainingState.aim = { x = ac.flag.ax + 10, z = gz }
		return
	end
	-- settling or heading back: canter, and stop by itself in the stall (for up to 3 s, so a
	-- horse the server hasn't readied yet can still move)
	if TC.inRect(hold, cur.x, cur.z) then
		s.holdSince = s.holdSince or os.clock()
		TrainingState.speed = if os.clock() - s.holdSince < 3 then 0 else 8
	else
		s.holdSince = nil
		TrainingState.speed = CFG.canter
	end
	local ax, az, hint = TC.routeCarrot(ac.route, cur.x, cur.z, s.hint, 10)
	s.hint = hint
	TrainingState.aim = { x = ax, z = az }
	if os.clock() - (s.backPrintsAt or 0) > 1.5 and s.gate == "back" then
		s.backPrintsAt = os.clock()
		printsAlong(routeAhead(ac.route, cur.x, cur.z, s.hint), 6, 18)
	end
end

-- Hill Climb: Pip, his ring, and your pace inside it.
local function pipFrame(s, cur, dt: number)
	local st = CFG.stamina
	local t = cur.t
	local pony = TC.ponyAt(s.seed, t)
	if s.pip then s.pipPos = placePip(s.pip, pony, dt, s.pipPos) end
	local rd = pony.d - (st.ringNear + st.ringFar) / 2
	local rx, rz = TC.ovalPoint(rd, pony.lateral)
	local inside = TrainingRide.inRing(s.seed, t, cur.x, cur.z, 0, CFG)
	if s.ring then
		s.ring.CFrame = CFrame.new(rx, GROUND_Y + TC.groundHeight(rx, rz) + 0.3, rz) * CFrame.Angles(0, 0, math.pi / 2)
		s.ring.Color = if inside then C.gold else C.white
		s.ring.Transparency = if inside then 0.45 else 0.65
	end
	-- inside the ring your horse keeps Pip's pace; behind it (by any amount, even more than half
	-- a lap) a gallop catches up; ahead of it, ease off
	local behindAll = pony.s - s.tracker.progress
	TrainingState.speed = if inside then pony.speed elseif behindAll > st.ringFar then CFG.gallop else pony.speed * 0.7
	TrainingState.aim = (function()
		local ax, az = TC.ovalCarrot(cur.x, cur.z, 12, pony.lateral)
		return { x = ax, z = az }
	end)()
	setDots(s.c.laps, math.clamp(math.floor((pony.s - s.c.lead) / TC.LAP), 0, s.c.laps), true)
	if inside or t < st.grace then
		s.outSince = nil
	else
		s.outSince = s.outSince or t
		if t - s.outSince > 1.5 and os.clock() - s.nudgedAt > 4 then
			s.nudgedAt = os.clock()
			say("Stay with Pip!", C.white)
		end
	end
end

local function ghostFrame(s, dt: number)
	if not s.ghosts then return end
	local t = TrainingRide.rideClock(workspace:GetServerTimeNow(), s.goAtServer)
	for _, gh in s.ghosts do
		local x, y, z, fx, fz = Ghost.at(gh.points, gh.hz, math.max(0, t - gh.t0))
		if x then
			local pos = Vector3.new(x, GROUND_Y + TC.groundHeight(x, z :: number) + math.max(0, y :: number), z :: number)
			if fx and (fx * fx + (fz :: number) ^ 2) > 0.01 then gh.look = Vector3.new(fx, 0, fz :: number).Unit end
			gh.model:PivotTo(CFrame.lookAt(pos, pos + gh.look))
			if HorseLegs.has(gh.model) then HorseLegs.apply(gh.model, if gh.last then (pos - gh.last).Magnitude else 0, dt) end
			gh.last = pos
		elseif gh.model.Parent then
			gh.model.Parent = nil -- the ghost has finished its ride
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local s = session
	if not s then return end
	TrainingState.easyRein = PlayerState.data ~= nil and PlayerState.data.settings ~= nil and PlayerState.data.settings.easyRein == true
	ghostFrame(s, dt)
	if TrainingState.phase ~= "ride" or not s.tracker then return end
	local cur = sampleNow(s)
	if not cur then return end
	local prev = s.prev or cur
	if s.course == "accel" then
		s.prev = cur
		gateFrame(s, cur)
		return
	elseif s.course == "stamina" then
		TrainingRide.feed(s.tracker, cur, CFG) -- your progress round the oval, to know how far behind Pip
		s.prev = cur
		pipFrame(s, cur, dt)
		return
	end
	TrainingRide.feed(s.tracker, cur, CFG)
	if prev ~= cur then cheerFor(s, prev, cur) end
	s.prev = cur
	if s.course == "speed" then
		local hpAim = TrainingRide.nextHoop(s.tracker)
		local ax, az = TC.ovalCarrot(cur.x, cur.z, 14, if hpAim then s.c.posts[hpAim.post].lateral else 0)
		TrainingState.aim = { x = ax, z = az }
	else
		local ax, az, hint = TC.routeCarrot(s.c.route, cur.x, cur.z, s.hint, 10)
		s.hint = hint
		TrainingState.aim = { x = ax, z = az }
	end
	if s.course == "speed" then
		setDots(s.c.laps, TrainingRide.laps(s.tracker), not s.tracker.finished)
		local hp = TrainingRide.nextHoop(s.tracker)
		local key = if hp then hp.index else "finish"
		if key ~= s.target then
			s.target = key
			if hp then
				local post = s.c.posts[hp.post]
				glow("Hoop" .. hp.post)
				TrainingState.target = { x = post.x, z = post.z, nx = post.tx, nz = post.tz, half = post.width / 2 }
				speedPrints(s.tracker, hp)
			else
				-- the last hoop is behind you: on to the line
				glow("StartLine")
				TrainingState.target = nil
				courseLabel.Text = "🏁 To the finish line!"
				s.printsAt = s.tracker.progress
				finishPrints(s.tracker)
			end
		elseif not hp and s.tracker.progress - (s.printsAt or 0) > 20 then
			s.printsAt = s.tracker.progress -- keep the prints just ahead of the horse
			finishPrints(s.tracker)
		end
	else
		local nextIndex = s.tracker.next
		setDots(#s.c.elements, nextIndex - 1, not s.tracker.finished)
		if nextIndex ~= s.target then
			s.target = nextIndex
			local e = s.c.elements[nextIndex]
			if e then
				glow(e.name)
			else
				glow("Finish")
				courseLabel.Text = "🏁 To the finish!"
			end
			gritPrints(s.c, nextIndex) -- after the last piece the prints lead to the finish
		end
	end
end)

stopBtn.Activated:Connect(function()
	if session then
		TrainAbort:FireServer()
		stopVisuals()
	end
end)

-- End card ----------------------------------------------------------------------------------------
local cardGui = Ui.screen("TrainingCard", 13)
cardGui.Enabled = false
local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.55
dim.Parent = cardGui
local CW, CH = 520, 420
local card = Ui.card(cardGui, UDim2.fromOffset(CW, CH), UDim2.fromScale(0.5, 0.5), C.paper)
card.AnchorPoint = Vector2.new(0.5, 0.5)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
local function rescale()
	local cam = workspace.CurrentCamera
	if cam then cardScale.Scale = math.min(1, (cam.ViewportSize.X - 20) / CW, (cam.ViewportSize.Y - 20) / CH) end
end
rescale()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Size = UDim2.fromScale(1, 1)
body.Parent = card
local cardGen = 0
local lastResult = nil
local together = nil -- { course, list } from TrainTogether
local togetherStrip: Frame? = nil

local RIBBON = {
	bronze = { emoji = "🥉", text = "Bronze ribbon", color = Color3.fromHex("E3A26B") },
	silver = { emoji = "🥈", text = "Silver ribbon", color = Color3.fromHex("D7DCE3") },
	gold = { emoji = "🥇", text = "Gold ribbon", color = C.gold },
}

local RIBBON_EMOJI = { bronze = "🥉", silver = "🥈", gold = "🥇" }

-- Ride together: how your friend did, stars and ribbons only (never times or places).
local function renderTogether()
	local strip = togetherStrip
	if not strip or not together or not lastResult or together.course ~= lastResult.course
		or together.groupId == nil or together.groupId ~= lastResult.groupId then return end
	strip:ClearAllChildren()
	local parts = {}
	for _, m in together.list do
		if m.userId ~= player.UserId then
			local what = if m.resting then "🐴 is taking a rest"
				elseif m.done then string.rep("★", math.clamp(tonumber(m.stars) or 1, 1, 3)) .. " " .. (RIBBON_EMOJI[m.ribbon] or "")
				else "🐴 still riding…"
			table.insert(parts, tostring(m.name) .. "  " .. what)
		end
	end
	if #parts == 0 then return end
	strip.Visible = true
	Ui.text(strip, "👫 " .. table.concat(parts, "   ·   "), 20, { Size = UDim2.fromScale(1, 1), TextColor3 = C.plum })
end

local function closeCard(tellServer: boolean)
	cardGen += 1
	if cardGui.Enabled and tellServer then TrainAbort:FireServer() end -- the card is gone: TrainingRide clears
	cardGui.Enabled = false
	body:ClearAllChildren()
end

local function detailLine(r): string
	local d = r.detail or {}
	if r.course == "speed" then
		return if (d.hoops or 0) > 0 then string.format("You rode through %d hoops!", d.hoops) else "You rode the whole course!"
	elseif r.course == "accel" then
		local quick = d.quick or 0
		return if quick >= 3 then "Three great starts!" elseif quick > 0 then string.format("%d great start%s!", quick, if quick == 1 then "" else "s")
			else "Three starts from the gate!"
	elseif r.course == "stamina" then
		local share = d.share or 0
		return if share >= 0.9 then "You stayed right with Pip!" elseif share >= 0.6 then "You stayed with Pip most of the way!"
			else "You and Pip rode the hill together!"
	end
	local parts = {}
	if (d.mud or 0) > 0 then table.insert(parts, string.format("💦 %d splash%s", d.mud, if d.mud == 1 then "" else "es")) end
	if (d.logs or 0) > 0 then table.insert(parts, string.format("🪵 %d hop%s", d.logs, if d.logs == 1 then "" else "s")) end
	if (d.poles or 0) > 0 then table.insert(parts, string.format("🚩 %d pole%s", d.poles, if d.poles == 1 then "" else "s")) end
	return if #parts > 0 then table.concat(parts, " · ") else "You rode the whole course!"
end

local function showCard(r)
	closeCard(false)
	lastResult = r
	local gen = cardGen
	local c = TC.courses[r.course]
	if not c then return end
	cardGui.Enabled = true
	card.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	Ui.text(body, c.emoji .. " " .. c.name, 30, { Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 36) })
	local horse = Ui.text(body, r.horseName or "", 18, { Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(1, 0, 0, 22) })
	horse.TextColor3 = C.plum
	-- Stars, one at a time.
	local starRow = Instance.new("Frame")
	starRow.BackgroundTransparency = 1
	starRow.Position = UDim2.new(0, 0, 0, 78)
	starRow.Size = UDim2.new(1, 0, 0, 64)
	starRow.Parent = body
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sl.Padding = UDim.new(0, 14)
	sl.Parent = starRow
	local stars = {}
	for k = 1, 3 do
		local st = Ui.text(starRow, "★", 60, { Size = UDim2.fromOffset(64, 64), LayoutOrder = k })
		st.TextColor3 = C.shade
		stars[k] = st
	end
	Ui.text(body, detailLine(r), 18, { Position = UDim2.new(0, 20, 0, 146), Size = UDim2.new(1, -40, 0, 24) })
	-- The stat bar.
	local label = c.label
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.new(0, 40, 0, 206)
	barBack.Size = UDim2.new(1, -80, 0, 26)
	barBack.BackgroundColor3 = C.white
	Ui.corner(barBack, 13)
	Ui.stroke(barBack, 2)
	barBack.Parent = body
	local top = math.max(1, r.potential or 100)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp((r.before or 0) / top, 0, 1), 1)
	fill.BackgroundColor3 = C.teal
	Ui.corner(fill, 13)
	fill.Parent = barBack
	local barLabel = Ui.text(body, string.format("%s %.1f", label, r.before or 0), 18,
		{ Position = UDim2.new(0, 40, 0, 180), Size = UDim2.new(1, -80, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	local gainText = Ui.text(body, "", 22, { Position = UDim2.new(0, 20, 0, 238), Size = UDim2.new(1, -40, 0, 50) })
	gainText.TextColor3 = C.cash
	-- The ribbon.
	local ribbon = Ui.card(body, UDim2.fromOffset(300, 48), UDim2.new(0.5, -150, 0, 292), C.cream)
	ribbon.Visible = false
	local ribbonText = Ui.text(ribbon, "", 22, { Size = UDim2.fromScale(1, 1) })
	-- Riding together: your friend's stars and ribbon (the card grows to fit).
	local withFriend = together ~= nil and together.course == r.course and together.groupId ~= nil and together.groupId == r.groupId
	CH = if withFriend then 470 else 420
	card.Size = UDim2.fromOffset(CW, CH)
	rescale()
	togetherStrip = Instance.new("Frame")
	togetherStrip.BackgroundTransparency = 1
	togetherStrip.Position = UDim2.new(0, 20, 0, 346)
	togetherStrip.Size = UDim2.new(1, -40, 0, 40)
	togetherStrip.Visible = false
	togetherStrip.Parent = body
	renderTogether()
	-- Buttons.
	local again = Ui.button(body, "🔁 Ride again", UDim2.fromOffset(200, 56), UDim2.new(0.5, -210, 1, -72), C.orange, 22)
	local done = Ui.button(body, "Done", UDim2.fromOffset(200, 56), UDim2.new(0.5, 10, 1, -72), C.green, 22)
	again.Activated:Connect(function()
		local res = lastResult
		closeCard(false)
		if res then TrainStart:FireServer(res.horseId, res.course) end
	end)
	done.Activated:Connect(function() closeCard(true) end)

	task.spawn(function()
		task.wait(0.35)
		for k = 1, math.clamp(r.stars or 1, 1, 3) do
			if gen ~= cardGen then return end
			stars[k].TextColor3 = C.gold
			Ui.pop(stars[k])
			play("tap_good", 0.7)
			task.wait(0.35)
		end
		if gen ~= cardGen then return end
		task.wait(0.2)
		if (r.gained or 0) > 0 then
			TweenService:Create(fill, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp((r.after or 0) / top, 0, 1), 1) }):Play()
			barLabel.Text = string.format("%s %.1f", label, r.after or 0)
			gainText.Text = string.format("+%.1f %s!%s", r.gained, label, if r.rested then " Rested bonus ✨" else "")
		elseif r.capped == "full" then
			gainText.TextColor3 = C.plum
			gainText.Text = string.format("%s's %s is as high as it goes. Ride for stars!", r.horseName or "Your horse", label)
		else
			gainText.TextColor3 = C.plum
			gainText.Text = string.format("%s is full this week. Ride for stars!", label)
		end
		task.wait(1)
		if gen ~= cardGen then return end
		local rb = RIBBON[r.ribbon] or RIBBON.bronze
		ribbon.BackgroundColor3 = rb.color
		ribbonText.Text = rb.emoji .. " " .. rb.text .. (if r.newRibbon then "  New!" else "")
		ribbon.Visible = true
		Ui.pop(ribbon)
		if r.newRibbon then play("job_done", 0.8) end
	end)
end

-- Remotes -----------------------------------------------------------------------------------------
TrainBegin.OnClientEvent:Connect(function(course, seed, n, goAtServer, partners)
	closeCard(false)
	together = nil
	local count = tonumber(n) or CFG.countdownSeconds
	local list = {}
	for _, uid in (if typeof(partners) == "table" then partners else {}) do
		if typeof(uid) == "number" then table.insert(list, uid) end
	end
	beginSession(course, count, tonumber(seed) or 1, tonumber(goAtServer) or (workspace:GetServerTimeNow() + count), list)
end)

-- Gate Break moments.
TrainCue.OnClientEvent:Connect(function(kind, data)
	local s = session
	if not s or s.course ~= "accel" or typeof(data) ~= "table" then return end
	local ac = TC.courses.accel
	-- each moment starts a fresh leg: the route aim from the start of the loop, a fresh stall stop
	s.hint, s.holdSince = 1, nil
	if kind == "armed" then
		s.gate = "ready"
		setDoors(false, false)
		clearGlow()
		clearPrints()
		countdown.Text = "Ready…"
		countdown.Visible = true
		Ui.pop(countdown)
	elseif kind == "bell" then
		s.gate = "bell"
		setDoors(true, false)
		play("gate_bell", 0.8)
		countdown.Text = "GO!"
		countdown.Visible = true
		Ui.pop(countdown)
		glowParts(flagParts())
		local rig = myRide()
		local root = rig and rig.PrimaryPart
		if root then printsAlong({ { x = root.Position.X, z = root.Position.Z }, { x = ac.flag.ax, z = ac.start.z } }, 7, 18) end
		task.delay(0.8, function()
			if session == s and s.gate ~= "ready" then countdown.Visible = false end
		end)
	elseif kind == "early" then
		countdown.Visible = false
		if data.rerun then
			s.gate, s.released = "back", false
			say("Wait for the bell!", C.white)
			setDoors(true, true)
			s.backPrintsAt = 0
		else
			-- early again: this break counts as an easy start; off to the flag (no bell to wait for)
			s.gate = "dash"
			say("Off you go! Ride to the flag!", C.gold)
			setDoors(true, false)
			glowParts(flagParts())
			local rig = myRide()
			local root = rig and rig.PrimaryPart
			if root then printsAlong({ { x = root.Position.X, z = root.Position.Z }, { x = ac.flag.ax, z = ac.start.z } }, 7, 18) end
		end
	elseif kind == "go" then
		s.gate = "dash"
		local score = tonumber(data.score) or 0
		say(if score >= 90 then "Great start!" elseif score >= 60 then "Good start!" else "Off you go!", C.gold)
		play("tap_good", 0.7)
	elseif kind == "flag" then
		s.breaksDone = math.max(s.breaksDone, tonumber(data.breakNo) or 0)
		setDots(CFG.accel.breaks, s.breaksDone, not data.last)
		clearGlow()
		clearPrints()
		if not data.last then
			s.gate, s.released = "back", false
			s.backPrintsAt = 0
			setDoors(true, true)
			say("Back to the gate!", C.white)
		end
	end
end)

TrainGhosts.OnClientEvent:Connect(function(course, list)
	local s = session
	if not s or s.course ~= course or typeof(list) ~= "table" then return end
	s.ghosts = s.ghosts or {}
	for i, g in list do
		if i > 3 then break end
		local pts = Ghost.decode(g)
		if pts and #pts > 1 then
			local model = buildGhost(g.coat, if g.mine then "Your best" else tostring(g.label), g.mine == true)
			table.insert(s.ghosts, { points = pts, hz = tonumber(g.hz) or Ghost.HZ, t0 = tonumber(g.t0) or 0, model = model,
				look = Vector3.new(TC.courses[course].start.lookX, 0, TC.courses[course].start.lookZ) })
		end
	end
end)

TrainTogether.OnClientEvent:Connect(function(course, list, groupId)
	if typeof(list) ~= "table" or typeof(groupId) ~= "number" then return end
	together = { course = course, list = list, groupId = groupId }
	if cardGui.Enabled and lastResult and lastResult.course == course and lastResult.groupId == groupId then
		if CH ~= 470 then
			CH = 470
			card.Size = UDim2.fromOffset(CW, CH)
			rescale()
		end
		renderTogether()
	end
end)

-- A friend's invite: accept-only, no timer shown, and it goes away by itself.
local inviteGui = Ui.screen("TrainingInvite", 14)
inviteGui.Enabled = false
local IW, IH = 400, 176
local inviteCard = Ui.card(inviteGui, UDim2.fromOffset(IW, IH), UDim2.new(1, -16, 0, 70), C.paper)
inviteCard.AnchorPoint = Vector2.new(1, 0) -- top right: away from the thumbstick and the Jump button
local inviteScale = Instance.new("UIScale")
inviteScale.Parent = inviteCard
local function fitInvite()
	local cam = workspace.CurrentCamera
	if cam then inviteScale.Scale = math.clamp(math.min((cam.ViewportSize.X * 0.55) / IW, (cam.ViewportSize.Y - 100) / IH), 0.55, 1) end
end
fitInvite()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitInvite)
end)
local inviteText = Ui.text(inviteCard, "", 22, { Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(1, -194, 1, -28) })
local inviteYes = Ui.button(inviteCard, "👫 Ride together", UDim2.fromOffset(160, 66), UDim2.new(1, -174, 0, 14), C.green, 20)
local inviteNo = Ui.button(inviteCard, "Not now", UDim2.fromOffset(160, 66), UDim2.new(1, -174, 0, 96), C.white, 20)
local inviteId = nil
local inviteShownAt = 0
local function closeInvite(answer: any)
	if inviteId ~= nil and answer ~= nil then TrainInviteReply:FireServer(inviteId, answer) end
	inviteId = nil
	inviteGui.Enabled = false
end
-- a clear tap: nothing in the card's first half second counts (a steering thumb landing on it)
inviteYes.Activated:Connect(function()
	if os.clock() - inviteShownAt >= 0.5 then closeInvite(true) end
end)
inviteNo.Activated:Connect(function()
	if os.clock() - inviteShownAt >= 0.5 then closeInvite(false) end
end)

-- Shop and game panels that mean "busy" (no card on top of them).
local BUSY_PANELS = { "StyleShop", "MarketCard", "Starter", "Taming", "Care", "RacePicker" }
local function panelOpen(): boolean
	local pg = player:FindFirstChildOfClass("PlayerGui")
	for _, name in BUSY_PANELS do
		local g = pg and pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then return true end
	end
	return false
end

TrainInvited.OnClientEvent:Connect(function(id, fromName, course)
	local c = TC.info(course) -- a stat ("grit" is this week's Mud Splash)
	if typeof(id) ~= "number" or not c then return end
	if session or player:GetAttribute("Racing") or player:GetAttribute("InLine") or panelOpen() then
		TrainInviteReply:FireServer(id, "busy") -- riding, racing or in a shop: "busy", no cooldown
		return
	end
	inviteId = id
	inviteShownAt = os.clock()
	inviteText.Text = string.format("🐴 %s would like to ride %s %s with you!", tostring(fromName), c.emoji, c.name)
	inviteGui.Enabled = true
	Ui.pop(inviteCard)
	task.delay(RideTogether.INVITE_SECONDS, function()
		if inviteId == id then closeInvite(nil) end
	end)
end)

TrainInviteGone.OnClientEvent:Connect(function(id)
	if inviteId == id then closeInvite(nil) end
end)

TrainEnd.OnClientEvent:Connect(function(result)
	stopVisuals()
	if typeof(result) == "table" then showCard(result) end
end)

TrainAbort.OnClientEvent:Connect(function(_reason, text)
	stopVisuals()
	if typeof(text) == "string" then Ui.toast(text, "heart", "🐴") end
end)

-- Picker and picture signs ask through TrainingState (PaddockClient): ride your active horse.
TrainingState.StartRequested.Event:Connect(function(course: string)
	local h = PlayerState.activeHorse()
	if not h then
		Ui.toast("Pick your first horse to start training!", "heart", "🐴")
		return
	end
	if session then return end
	TrainStart:FireServer(h.id, course)
end)

-- Your race starting closes the card (the race HUD needs the screen).
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if player:GetAttribute("Racing") then
		stopVisuals()
		closeCard(true)
	end
end)
