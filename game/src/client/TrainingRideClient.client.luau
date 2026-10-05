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

local function courseModel(name: string): Instance?
	local world = workspace:FindFirstChild("World")
	local tg = world and world:FindFirstChild("TrainingGround")
	if not tg then return nil end
	local folder = tg:FindFirstChild(if string.sub(name, 1, 4) == "Hoop" then "Hoops" else "Gymkhana")
	return folder and folder:FindFirstChild(name)
end

local function glow(name: string?)
	clearGlow()
	local m = name and courseModel(name)
	if not m then return end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			glowing[d] = { d.Color, d.Material }
			d.Color, d.Material = C.gold, Enum.Material.Neon
		end
	end
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

-- Session --------------------------------------------------------------------------------------
local session = nil -- { course, c, tracker, goAt, base, baseY, target, prev, got = {} }

local function setDots(count: number, filled: number)
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
			local on = k <= filled
			if d:GetAttribute("On") ~= on then
				d:SetAttribute("On", on)
				d.BackgroundColor3 = if on then C.gold else C.white
				if on then Ui.pop(d) end
			end
		end
	end
end

local function stopVisuals()
	session = nil
	TrainingState.reset()
	clearGlow()
	clearPrints()
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

local routeIndex: { [number]: number } = {} -- gymkhana piece -> nearest route point
do
	local g = TC.courses.grit
	for i, e in g.elements do
		local best, bestD = 1, math.huge
		for k, pt in g.route.points do
			local d = (pt.x - e.x) ^ 2 + (pt.z - (e.weaveZ or e.z)) ^ 2
			if d < bestD then best, bestD = k, d end
		end
		routeIndex[i] = best
	end
end

local function gritPrints(index: number)
	local g = TC.courses.grit
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
	return { t = os.clock() - (s.goAt or os.clock()), x = pos.X, z = pos.Z, y = y }
end

local function onGo(s)
	s.goAt = os.clock()
	table.sort(s.base)
	s.baseY = if #s.base > 0 then s.base[(#s.base + 1) // 2] else nil
	s.tracker = TrainingRide.tracker(s.course)
	s.prev = sampleNow(s)
	TrainingState.phase = "ride"
	countdown.Text = "Go!"
	Ui.pop(countdown)
	play("vo_giddyup", 0.8)
	task.delay(0.7, function()
		if session == s then countdown.Visible = false end
	end)
end

local function beginSession(course: string, n: number)
	stopVisuals()
	local c = TC.courses[course]
	if not c then return end
	local s = { course = course, c = c, base = {}, got = {}, target = nil, recent = {}, hops = {} }
	session = s
	TrainingState.active, TrainingState.course, TrainingState.phase = true, course, "countdown"
	courseLabel.Text = c.emoji .. " " .. c.name
	setDots(if course == "speed" then c.laps else #c.elements, 0)
	hud.Visible = true
	jumpBtn.Visible = UserInputService.TouchEnabled
	countdown.Visible = true
	task.spawn(function()
		for k = math.max(1, math.floor(n + 0.5)), 1, -1 do
			if session ~= s then return end
			countdown.Text = tostring(k)
			Ui.pop(countdown)
			play("ui_pop")
			-- the horse's riding height, while it stands at the start
			local t0 = os.clock()
			while os.clock() - t0 < 1 do
				local rig = myRide()
				if rig and rig.PrimaryPart then table.insert(s.base, rig.PrimaryPart.Position.Y) end
				task.wait(0.1)
			end
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
		local hp = TrainingRide.nextHoop(s.tracker)
		local target = s.target
		if target and target ~= hp and not s.got[target.index] then
			local post = TC.courses.speed.posts[target.post]
			local xs = TrainingRide.crossings({ prev, cur }, post.gate)
			if xs[1] and xs[1].dir > 0 then
				s.got[target.index] = true
				say("✨", C.gold)
				play("tap_good", 0.6)
			end
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

RunService.RenderStepped:Connect(function()
	local s = session
	if not s or TrainingState.phase ~= "ride" or not s.tracker then return end
	local cur = sampleNow(s)
	if not cur then return end
	local prev = s.prev or cur
	TrainingRide.feed(s.tracker, cur, CFG)
	if prev ~= cur then cheerFor(s, prev, cur) end
	s.prev = cur
	if s.course == "speed" then
		setDots(s.c.laps, TrainingRide.laps(s.tracker))
		local hp = TrainingRide.nextHoop(s.tracker)
		if hp ~= s.target then
			s.target = hp
			if hp then
				local post = s.c.posts[hp.post]
				glow("Hoop" .. hp.post)
				TrainingState.target = { x = post.x, z = post.z, nx = post.tx, nz = post.tz, half = post.width / 2 }
				speedPrints(s.tracker, hp)
			else
				glow(nil)
				clearPrints()
				TrainingState.target = nil
			end
		end
	else
		local nextIndex = s.tracker.next
		setDots(#s.c.elements, nextIndex - 1)
		if nextIndex ~= s.target then
			s.target = nextIndex
			local e = s.c.elements[nextIndex]
			glow(e and e.name)
			gritPrints(nextIndex) -- after the last piece the prints lead to the finish
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

local RIBBON = {
	bronze = { emoji = "🥉", text = "Bronze ribbon", color = Color3.fromHex("E3A26B") },
	silver = { emoji = "🥈", text = "Silver ribbon", color = Color3.fromHex("D7DCE3") },
	gold = { emoji = "🥇", text = "Gold ribbon", color = C.gold },
}

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
TrainBegin.OnClientEvent:Connect(function(course, _seed, n)
	closeCard(false)
	beginSession(course, tonumber(n) or CFG.countdownSeconds)
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
