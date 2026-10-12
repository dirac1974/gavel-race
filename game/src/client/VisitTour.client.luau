--!nonstrict
-- VisitTour (D-079): visiting someone else's barn, the visitor's side.
--   Arrival: when the server says you walked into a barn that lets you in (VisitArrive), the gate
--   bell rings (gate_bell, existing SoundSheet clip) and a banner pops in, "Welcome to Mia's barn!"
--   (the owner's display name, the same as the barn sign), and fades after visit.bannerSeconds.
--   Visitor bar (top slot, under every other card): the barn's name, 4 tour pips, 🎉 Cheer (4 preset
--   cheers, no text) and 🏠 Home.
--   Walkaround: glowing hoofprints (Guide) lead to the next tour stop (Rosette Wall, the horses, their
--   yard, then the Legend paddock, or their garden when they have no Legend; Visits.stopsFor and
--   GameConfig.visit.tourStops). Standing at a stop sends it; the server checks you're there
--   (VisitHello "stop") and answers with today's stops (VisitTour). At each stop the featured thing
--   gets a gold outline (Highlight) and a 12-particle gold sparkle (visit.stopFx). All 4 in a day earn
--   that barn's Tour pin once (tap_ok per stop, job_done for the pin). A barn already pinned shows its
--   pips but draws no trail.
--   A sent cheer (VisitCheer) floats its emoji up from the barn door with clap (🎉: tap_good), the same
--   for the owner when they're home (visit.cheerFx).
--   Nothing here can change the owner's stable. Reduced Motion: the banner fades with no pop, the stop
--   keeps its outline but no sparkle, and the cheer emoji fades in place.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local GoTo = require(script.Parent:WaitForChild("GoTo"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Visits = require(Shared:WaitForChild("Visits"))

local player = Players.LocalPlayer
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local C = Ui.colors
local CFG = GameConfig.visit

local function reducedMotion(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

-- The arrival banner ---------------------------------------------------------------------
local bannerGui = Ui.screen("VisitBanner", 13)
bannerGui.Enabled = false
local banner = Ui.card(bannerGui, UDim2.fromOffset(460, 84), UDim2.fromScale(0.5, 0.3), C.cream)
banner.AnchorPoint = Vector2.new(0.5, 0.5)
local bannerText = Ui.text(banner, "", 30, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 1, -18),
	TextScaled = true, TextWrapped = false })
local bannerFit = Instance.new("UITextSizeConstraint")
bannerFit.MinTextSize, bannerFit.MaxTextSize = 18, 30
bannerFit.Parent = bannerText
local bannerSeq = 0

local function showBanner(name: string)
	bannerSeq += 1
	local seq = bannerSeq
	bannerText.Text = "Welcome to " .. name .. "'s barn!" -- 4 words; the name is the barn sign's
	bannerText.TextTransparency = 0
	banner.BackgroundTransparency = 0
	bannerGui.Enabled = true
	if not reducedMotion() then Ui.pop(banner) end
	task.delay(CFG.bannerSeconds, function()
		if seq ~= bannerSeq then return end
		local info = TweenInfo.new(0.4)
		TweenService:Create(bannerText, info, { TextTransparency = 1 }):Play()
		TweenService:Create(banner, info, { BackgroundTransparency = 1 }):Play()
		task.delay(0.45, function()
			if seq == bannerSeq then bannerGui.Enabled = false end
		end)
	end)
end

-- The visitor bar ------------------------------------------------------------------------
local W, H = 540, 76
local barGui = Ui.screen("VisitBar", 9)
local bar = Ui.card(barGui, UDim2.fromOffset(W, H), UDim2.new(0.5, 0, 0, 60), C.paper)
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Visible = false
local wantTop = Ui.slot("visit", GameConfig.topSlot.visit or 10, bar)
local barName = Ui.text(bar, "", 22, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -300, 0, 28),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
local barLine = Ui.text(bar, "", 16, { Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -300, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
barLine.TextColor3 = C.plum
local cheerBtn = Ui.button(bar, "🎉 Cheer", UDim2.fromOffset(130, 64), UDim2.new(1, -278, 0, 4), C.cream, 20)
local homeBtn = Ui.button(bar, "🏠 Home", UDim2.fromOffset(130, 64), UDim2.new(1, -140, 0, 4), C.white, 20)

-- The 4 preset cheers: a row that takes the bar's place while open.
local cheerRow = Instance.new("Frame")
cheerRow.BackgroundTransparency = 1
cheerRow.Size = UDim2.new(1, -150, 1, -8)
cheerRow.Position = UDim2.fromOffset(8, 4)
cheerRow.Visible = false
cheerRow.Parent = bar
local crl = Instance.new("UIListLayout")
crl.FillDirection = Enum.FillDirection.Horizontal
crl.Padding = UDim.new(0, 8)
crl.VerticalAlignment = Enum.VerticalAlignment.Center
crl.Parent = cheerRow

type State = { ownerId: number, name: string, plot: number, friend: boolean, done: { [string]: boolean }, pinned: boolean,
	stops: { string }, full: boolean }
local state: State? = nil
local lookUntil = 0
local lookText = ""
local guideAt: Vector3? = nil
local pendingStop: string? = nil
local pendingAt = 0

local function stopSpec(id: string): any
	for _, s in CFG.tourStops do
		if s.id == id then return s end
	end
	return nil
end

local function stopPoint(plot: number, id: string): (number?, number?)
	local s = stopSpec(id)
	if s then return WorldLayout.plotPoint(plot, s.inward, s.across) end
	return nil, nil
end

-- The ground height under (x, z) (the plots sit on one ground, but ask the world, not a constant).
local function groundY(x: number, z: number): number
	local params = RaycastParams.new()
	local chars = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(chars, p.Character) end
	end
	params.FilterDescendantsInstances = chars
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0), params)
	return if hit then hit.Position.Y else 0
end

-- The stop's featured thing: the barn piece (or the garden) nearest its look point (visit.lookStuds).
local function featured(plot: number, id: string): Instance?
	local s = stopSpec(id)
	local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Plots")
	local shell = plots and plots:FindFirstChild("Plot" .. plot)
	if not s or not shell then return nil end
	if id == "garden" then return shell:FindFirstChild("Garden") end
	local barn = shell:FindFirstChild("Barn")
	if id == "paddock" and barn and barn:FindFirstChild("LegendPaddock") then return barn.LegendPaddock end
	if not barn then return nil end
	local lx, lz = WorldLayout.plotPoint(plot, s.lookIn, s.lookAcross)
	local best, bestD = nil, CFG.lookStuds
	for _, ch in barn:GetChildren() do
		local pos: Vector3? = nil
		if ch:IsA("Model") then
			pos = ch:GetPivot().Position
		elseif ch:IsA("BasePart") and ch.Transparency < 1 then
			pos = ch.Position
		end
		if pos then
			local d = Vector3.new(pos.X - lx, 0, pos.Z - lz).Magnitude
			if d < bestD then best, bestD = ch, d end
		end
	end
	return best
end

-- The stop in the world (feel consult): a gold outline on the featured thing for highlightSeconds,
-- fading over the last fadeSeconds, and a gold sparkle (none under Reduced Motion).
local FX = CFG.stopFx
local function stopFx(plot: number, id: string)
	local thing = featured(plot, id)
	local gold = Color3.fromHex(FX.color)
	local at: Vector3
	if thing then
		local hl = Instance.new("Highlight")
		hl.Adornee = thing
		hl.FillTransparency = 1
		hl.OutlineColor = gold
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = workspace
		task.delay(FX.highlightSeconds - FX.fadeSeconds, function()
			if hl.Parent then TweenService:Create(hl, TweenInfo.new(FX.fadeSeconds), { OutlineTransparency = 1 }):Play() end
		end)
		task.delay(FX.highlightSeconds, function() hl:Destroy() end)
		if thing:IsA("Model") then
			at = (thing :: Model):GetBoundingBox().Position
		else
			at = (thing :: BasePart).Position
		end
	else
		local s = stopSpec(id)
		local x, z = WorldLayout.plotPoint(plot, s.lookIn, s.lookAcross)
		at = Vector3.new(x, groundY(x, z) + 3, z)
	end
	if reducedMotion() then return end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(gold)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(FX.sparkleLife)
	e.Speed = NumberRange.new(FX.sparkleSpeed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = p
	e:Emit(FX.sparkles)
	task.delay(FX.sparkleLife + 1, function() p:Destroy() end)
end

-- A cheer floats up from the barn door (feel consult): 64 px emoji, rising, fading at the end.
local CH = CFG.cheerFx
local function cheerFx(plot: number, kind: string)
	local icon = Visits.CHEER_ICONS[kind]
	if not icon then return end
	if kind == "yay" then Sound.play("tap_good", CH.volume, nil, CH.yaySpeed) else Sound.play("clap", CH.volume) end
	local x, z = WorldLayout.plotPoint(plot, CH.doorIn, CH.doorAcross)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(x, groundY(x, z) + CH.startStuds, z)
	p.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(CH.px, CH.px)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = p
	local t = Ui.text(bb, icon, CH.px - 8, { Size = UDim2.fromScale(1, 1), TextWrapped = false })
	if not reducedMotion() then
		TweenService:Create(bb, TweenInfo.new(CH.seconds), { StudsOffsetWorldSpace = Vector3.new(0, CH.riseStuds, 0) }):Play()
	end
	task.delay(CH.seconds - CH.fadeSeconds, function()
		if t.Parent then TweenService:Create(t, TweenInfo.new(CH.fadeSeconds), { TextTransparency = 1 }):Play() end
	end)
	task.delay(CH.seconds, function() p:Destroy() end)
end

local function render()
	local st = state
	if not st then return end
	barName.Text = "🏡 " .. st.name .. "'s barn" .. (if st.friend then "  👫" else "")
	local pips = ""
	for _, id in st.stops do pips ..= if st.done[id] then "📍" else "⚪" end
	if os.clock() < lookUntil then
		barLine.Text = lookText
	elseif st.pinned then
		barLine.Text = pips .. "  Tour pin ✓"
	else
		barLine.Text = pips .. "  Follow the hoofprints"
	end
end

local function clearOurTrail()
	local t = Guide.target()
	if t and guideAt and Vector3.new(t.X - guideAt.X, 0, t.Z - guideAt.Z).Magnitude < 0.5 then Guide.clear() end
	guideAt = nil
end

local function guideNext()
	local st = state
	clearOurTrail()
	if not st or st.pinned or st.full then return end
	for _, id in st.stops do
		if not st.done[id] then
			local x, z = stopPoint(st.plot, id)
			if x then
				Guide.to(x, z :: number, nil, CFG.stopArriveStuds)
				guideAt = Vector3.new(x, 0, z :: number)
			end
			return
		end
	end
end

local function setDone(st: State, list: any)
	table.clear(st.done)
	if typeof(list) == "table" then
		for _, id in list do
			if typeof(id) == "string" then st.done[id] = true end
		end
	end
end

for _, kind in Visits.CHEERS do
	local b = Ui.button(cheerRow, Visits.CHEER_ICONS[kind], UDim2.fromOffset(64, 64), UDim2.new(), C.white, 30)
	b.Activated:Connect(function()
		local st = state
		cheerRow.Visible = false
		barName.Visible, barLine.Visible = true, true
		cheerBtn.Text = "🎉 Cheer"
		if st then gameRemotes:WaitForChild("VisitHello"):FireServer(st.ownerId, "cheer", kind) end
	end)
end

cheerBtn.Activated:Connect(function()
	local open = not cheerRow.Visible
	cheerRow.Visible = open
	barName.Visible, barLine.Visible = not open, not open
	cheerBtn.Text = if open then "◀ Back" else "🎉 Cheer"
end)

homeBtn.Activated:Connect(function()
	clearOurTrail()
	GoTo.place("stable")
end)

gameRemotes:WaitForChild("VisitCheer").OnClientEvent:Connect(function(plot, kind)
	if typeof(plot) == "number" and typeof(kind) == "string" then cheerFx(plot, kind) end
end)

gameRemotes:WaitForChild("VisitArrive").OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" or typeof(info.ownerId) ~= "number" or typeof(info.name) ~= "string" or typeof(info.plot) ~= "number" then
		state = nil
		pendingStop = nil
		clearOurTrail()
		return
	end
	local st: State = { ownerId = info.ownerId, name = info.name, plot = info.plot, friend = info.friend == true, done = {},
		pinned = info.pinned == true, stops = Visits.stopsFor(info.legend == true), full = false }
	setDone(st, info.done)
	state = st
	pendingStop = nil
	cheerRow.Visible = false
	barName.Visible, barLine.Visible = true, true
	cheerBtn.Text = "🎉 Cheer"
	if info.quiet ~= true then -- back in the same barn soon after: no second bell or banner (code review N1)
		Sound.play("gate_bell", CFG.bellVolume, nil, CFG.bellSpeed)
		showBanner(st.name)
	end
	render()
	guideNext()
end)

gameRemotes:WaitForChild("VisitTour").OnClientEvent:Connect(function(ownerId, done, pin, full)
	local st = state
	if not st or st.ownerId ~= ownerId then return end
	pendingStop = nil
	if full == true then -- no more barns to tour today: stop sending (code review N2)
		st.full = true
		clearOurTrail()
		return
	end
	local before = table.clone(st.done)
	setDone(st, done)
	for id in st.done do
		if not before[id] then stopFx(st.plot, id) end
	end
	if pin == true then
		st.pinned = true
		Sound.play("job_done")
	end
	render()
	guideNext()
end)

-- At a stop: send it once (the server checks where you stand), "Look!" in the bar for a moment.
task.spawn(function()
	while true do
		task.wait(0.25)
		local st = state
		local on = st ~= nil and not player:GetAttribute("Racing")
		local shown = wantTop(on)
		bar.Visible = shown
		if shown then
			local cx, w, top = Ui.topSlotPlace(W)
			bar.Position = UDim2.fromOffset(cx, top)
			bar.Size = UDim2.fromOffset(w, H)
		end
		if st and on then
			if pendingStop and os.clock() - pendingAt > CFG.helloGapSeconds * 4 then pendingStop = nil end -- no answer: try again
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and not pendingStop and not st.full then
				for _, id in st.stops do
					local x, z = stopPoint(st.plot, id)
					if not st.done[id] and x and Vector3.new(root.Position.X - x, 0, root.Position.Z - (z :: number)).Magnitude < CFG.stopArriveStuds then
						pendingStop, pendingAt = id, os.clock()
						lookText, lookUntil = "Look! " .. Visits.STOP_NAMES[id], os.clock() + 2
						Sound.play("tap_ok")
						gameRemotes:WaitForChild("VisitHello"):FireServer(st.ownerId, "stop", id)
						break
					end
				end
			end
			render()
		end
	end
end)
