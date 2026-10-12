--!nonstrict
-- BarnBuilder (D-070, provisional): the Green Cash shop at the Feed & Seed counter on Fair Street.
-- Its own shop, so a kid never mixes it up with Tack & Paint: a 🔨 header on a green 💵 band, 💵 on
-- every price, and no 💎 anywhere. It opens only when you tap its counter (never by itself, never
-- around your races: the door is shut in line, racing, on a training ride, on your results and for
-- greenCash.pillAfterRaceSeconds after). Building asks first ("Use 💵 300? You'll have 💵 940 left.").
-- Shelves: every open tier (the best league any horse has ever reached), then only the next tier,
-- greyed, with its league badge and "Opens when a horse reaches Silver" and no prices; later tiers
-- stay hidden. 💭 Wish marks one thing to save for (the cash card shows its icon and a bar). A build
-- can be returned until tomorrow ("↩️ Return", then "Sure? ↩️"; no clock).
-- The build moment: "Go see it!" and See it ▶ walk golden hoofprints to the spot in your yard; the new
-- piece waits, hidden on your screen, until you get there, then drops in with a bounce, dust and a
-- sparkle (paint sweeps across), with job_done and "<name> built!". Reduced Motion or
-- greenCash.buildFx = false: a fade. The moment waits until the spot is on screen and roughly ahead
-- ("✨ Here!" floats over it until then). "New shelf at Barn Builder!" is a one-time Next-thing pill
-- (Advice.shelfPill). Weathervanes turn slowly (BuildFx.startVanes).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local GoTo = require(script.Parent:WaitForChild("GoTo")) -- Find it (D-075): GO opens this feature
local BuildFx = require(script.Parent:WaitForChild("BuildFx"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("Style"))
local BarnCatalog = require(Shared:WaitForChild("BarnCatalog"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))

local player = Players.LocalPlayer
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local C = Ui.colors
local GC = GameConfig.greenCash or {}

BuildFx.startVanes() -- every weathervane in the server, owner or not

if GC.enabled == false then return end

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function shut(): boolean
	return RaceState.shopClosed(GC.pillAfterRaceSeconds or 120)
end

local function still(): boolean
	return GC.buildFx == false or BuildFx.reducedMotion()
end

-- The panel ----------------------------------------------------------------------------------
local gui = Ui.screen("BarnBuilder", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local W, H = 560, 600
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
-- Floors (AAA Phase 2): 16 px text and 64 px buttons, unscaled. On a short screen the panel gets shorter
-- (down to 300) and only the shelves scroll, so the 🔨 band, the balance and the ✕ stay pinned (UI/UX consult).
local slide = Ui.fitPanel(panel, W, H, 300, 16, 64)
local band = Instance.new("Frame") -- the green 💵 band: this is the Green Cash shop
band.Name = "CashBand"
band.BackgroundColor3 = C.cash
band.BorderSizePixel = 0
band.Size = UDim2.new(1, 0, 0, 84)
band.Parent = panel
Ui.corner(band, 18)
local title = Ui.text(band, "🔨 Barn Builder", 32, { Position = UDim2.new(0, 18, 0, 10), Size = UDim2.new(1, -110, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left })
title.TextColor3 = C.white
Ui.text(band, "Built with 💵 Green Cash you earn", 18, { Position = UDim2.new(0, 18, 0, 50), Size = UDim2.new(1, -110, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Left }) -- ink on the band: 4.5:1 at 18 px (white only for the big title)
local closeBtn = Ui.closeButton(panel)
local balance = Ui.text(panel, "", 26, { Position = UDim2.new(0, 18, 0, 94), Size = UDim2.new(1, -36, 0, 32), TextXAlignment = Enum.TextXAlignment.Left })
balance.TextColor3 = C.textGood
local content = Instance.new("ScrollingFrame")
content.Name = "Shelves"
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Position = UDim2.new(0, 16, 0, 136)
content.Size = UDim2.new(1, -24, 1, -146)
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.ScrollBarThickness = 8
content.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = content

local confirming: string? = nil
local returning: string? = nil
local justBuilt: string? = nil -- the banner: "<name> built! Go see it!"

local function data() return PlayerState.data end
local function cash(): number return (data() and data().cash) or 0 end
local function owns(id: string): boolean
	local d = data()
	return d ~= nil and Style.owns({ style = d.style, diamonds = d.diamonds, fan = { xp = d.fanXp or 0 } }, id)
end
local function worn(it): boolean
	local eq = data() and data().style and data().style.equipped or {}
	if it.slot == "yard" then return eq["yard:" .. it.id] == true end
	return eq[it.slot] == it.id
end
local function canReturn(id: string): boolean
	local d = data()
	local at = d and d.shop and d.shop.boughtAt and d.shop.boughtAt[id]
	return at ~= nil and owns(id) and workspace:GetServerTimeNow() - at < Style.returnSeconds(Style.item(id))
end
local function wished(id: string): boolean
	return data() ~= nil and data().style ~= nil and data().style.wish == id
end

local function swatch(parent: Instance, it, faded: boolean)
	local sw = Instance.new("Frame")
	sw.Size = UDim2.fromOffset(64, 64)
	sw.Position = UDim2.new(0, 12, 0, 12)
	sw.BackgroundColor3 = if it.color and not faded then Color3.fromHex(it.color) else C.cream
	Ui.corner(sw, 14)
	Ui.stroke(sw, 2)
	sw.Parent = parent
	if it.color2 and not faded then
		local roof = Instance.new("Frame")
		roof.Size = UDim2.new(1, 0, 0.3, 0)
		roof.BackgroundColor3 = Color3.fromHex(it.color2)
		Ui.corner(roof, 14)
		roof.Parent = sw
	end
	local e = Ui.text(sw, it.emoji, 30, { Size = UDim2.fromScale(1, 1), TextScaled = true })
	if faded then e.TextTransparency = 0.45 end
end

local render
local function button(row: Instance, text: string, color: Color3, w: number, fn: () -> ())
	local b = Ui.button(row, text, UDim2.fromOffset(w, 64), UDim2.new(), color, 18)
	b.Activated:Connect(fn)
	return b
end

local function buttonRow(card: Instance, y: number): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -24, 0, 64)
	row.Position = UDim2.new(0, 12, 0, y)
	row.Parent = card
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 8)
	rl.Parent = row
	return row
end

-- The build moment ------------------------------------------------------------------------------
-- pending: { id, kind = "model" | "paint" | "worn", snapshot = { [paintKey]: Color3 }, at = os.clock(), confirmed }
local pending = nil
local seeTarget: Vector3? = nil

local function myBarn(): Instance?
	local i = player:GetAttribute("PlotIndex")
	local world = workspace:FindFirstChild("World")
	local plot = i and world and world:FindFirstChild("Plots") and world.Plots:FindFirstChild("Plot" .. i)
	return plot and plot:FindFirstChild("Barn")
end

local function kindOf(it): string
	if it.slot == "yard" or it.slot == "frame" or it.slot == "fence" then return "model" end
	if it.slot == "cloth" or it.slot == "helmet" then return "worn" end
	return "paint"
end

local function snapshot(): { [string]: Color3 }
	local out = {}
	local barn = myBarn()
	for _, d in (barn and barn:GetDescendants()) or {} do
		local k = d:IsA("BasePart") and d:GetAttribute("Paint")
		if k and not out[k] then out[k] = d.Color end
	end
	return out
end

-- Hide the new piece (or hold the old paint) on this screen until you arrive.
local function holdBack(barn: Instance)
	if not pending then return end
	if pending.kind == "model" then
		local m = barn:FindFirstChild("Build_" .. pending.id)
		if m then BuildFx.hide(m) end
	elseif pending.kind == "paint" then
		for _, d in barn:GetDescendants() do
			local k = d:IsA("BasePart") and d:GetAttribute("Paint")
			local old = k and pending.snapshot[k]
			if old then BuildFx.holdPaint(d, old) end
		end
	end
end

local function lookPoint(it): Vector3?
	local i = player:GetAttribute("PlotIndex")
	if not i then return nil end
	local a, c = BarnCatalog.lookAt(it)
	local x, z = WorldLayout.plotPoint(i, a, c)
	return Vector3.new(x, 0, z)
end

local function seeIt(id: string)
	local it = Style.item(id)
	local p = it and lookPoint(it)
	gui.Enabled = false
	if not p then return end
	seeTarget = p
	Guide.to(p.X, p.Z)
	Ui.toast("Go see it! Follow the hoofprints", "hoofprint", "🐾")
end

local function reveal(withFx: boolean)
	local pd = pending
	pending = nil
	if not pd then return end
	local it = Style.item(pd.id)
	local barn = myBarn()
	local fx = withFx and not still()
	if pd.kind == "model" then
		local m = barn and barn:FindFirstChild("Build_" .. pd.id)
		if m then
			if withFx then BuildFx.dropIn(m, not fx) else BuildFx.dropIn(m, true) end
		end
	elseif pd.kind == "paint" then
		local at = BuildFx.sweepAll(not fx)
		if withFx and at then BuildFx.sparkle(at + Vector3.new(0, 4, 0), 24) end
	else
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if withFx and root then BuildFx.sparkle(root.Position + Vector3.new(0, 3, 0), 20) end
	end
	if withFx and it then
		if Sound then Sound.play("job_done") end
		if pd.kind == "worn" then
			Ui.toast(it.name .. " is ready to ride!", "cash", it.emoji)
		else
			Ui.toast(it.name .. " built!", "cash", it.emoji)
		end
	end
	if seeTarget then
		Guide.clear()
		seeTarget = nil
	end
end

-- Where the reveal happens (the piece, or the barn for a paint look); nil for a worn look (it's on you).
local function focusPoint(it): Vector3?
	if not pending or pending.kind == "worn" then return nil end
	local barn = myBarn()
	local m = barn and pending.kind == "model" and barn:FindFirstChild("Build_" .. pending.id)
	local at = m and m:GetAttribute("BuildAt")
	if typeof(at) == "Vector3" then return at end
	local i = player:GetAttribute("PlotIndex")
	if not i then return nil end
	local x, z = WorldLayout.plotPoint(i, 92, 0)
	return Vector3.new(x, 8, z)
end

local marker: BillboardGui? = nil
local function showMarker(at: Vector3)
	if marker and marker.Parent then
		(marker.Parent :: BasePart).Position = at + Vector3.new(0, 4, 0)
		return
	end
	marker = BuildFx.marker(at + Vector3.new(0, 4, 0))
end
local function clearMarker()
	if marker then
		if marker.Parent then marker.Parent:Destroy() end
		marker = nil
	end
end

-- Keep the new piece hidden through barn rebuilds, and play the moment when you arrive.
task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	local plots = world and world:WaitForChild("Plots", 60)
	if not plots then return end
	plots.DescendantAdded:Connect(function(d)
		if not pending then return end
		if d.Name == "Barn" and d:GetAttribute("Owner") == player.UserId then
			task.defer(function() if d.Parent then holdBack(d) end end)
		elseif pending.kind == "model" then
			-- the piece itself, or something added to it later (the silhouette once its image loads)
			local m = if d.Name == "Build_" .. pending.id then d else d:FindFirstAncestor("Build_" .. pending.id)
			if m then task.defer(function() if m.Parent and pending then BuildFx.hide(m) end end) end
		end
	end)
	while true do
		task.wait(0.25)
		if pending then
			local it = Style.item(pending.id)
			-- a buy that didn't go through (the server said no): forget it
			if not pending.confirmed and os.clock() - pending.at > 4 and not owns(pending.id) then
				local barn = myBarn()
				pending = nil
				clearMarker()
				if barn then BuildFx.sweepAll(true) end
			elseif os.clock() - pending.at > (GC.pendingBuildSeconds or 900) then
				clearMarker()
				reveal(false)
			elseif pending.confirmed and it then
				local p = lookPoint(it)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local i = player:GetAttribute("PlotIndex")
				if p and root and i then
					local r = WorldLayout.plotRect(i)
					local pos = root.Position
					local inYard = pos.X >= r[1] and pos.X <= r[3] and pos.Z >= r[2] and pos.Z <= r[4]
					local near = inYard and Vector3.new(pos.X - p.X, 0, pos.Z - p.Z).Magnitude < 26 and not RaceState.busy()
					-- The reveal waits until the spot is on screen and within ~60° of where the camera looks
					-- (the feel consult); until then "✨ Here!" floats over it so the kid turns to look.
					local focus = focusPoint(it)
					if near and (focus == nil or BuildFx.inView(focus, 60)) then
						clearMarker()
						reveal(true)
					elseif near and focus then
						showMarker(focus)
					else
						clearMarker()
					end
				end
			end
		end
	end
end)

gameRemotes:WaitForChild("CashBuilt").OnClientEvent:Connect(function(id)
	local it = typeof(id) == "string" and Style.item(id)
	if not it then return end
	if not pending or pending.id ~= id then
		pending = { id = id, kind = kindOf(it), snapshot = {}, at = os.clock() }
	end
	pending.confirmed = true
	pending.at = os.clock()
	local barn = myBarn()
	if barn then holdBack(barn) end
	justBuilt = id
	if render then render() end
	content.CanvasPosition = Vector2.zero -- the "built! Go see it!" banner is at the top: show it
end)

-- Cards --------------------------------------------------------------------------------------
local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function header(text: string, tier: string, locked: boolean)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, if locked then 72 else 48)
	f.LayoutOrder = nextOrder()
	f.Parent = content
	Ui.icon(f, Ui.badge(tier), "🏅", UDim2.fromOffset(40, 40), UDim2.new(0, 0, 0, 4))
	Ui.text(f, text, 24, { Position = UDim2.new(0, 50, 0, 6), Size = UDim2.new(1, -50, 0, 32), TextXAlignment = Enum.TextXAlignment.Left })
	if locked then
		local l = Ui.text(f, "Opens when a horse reaches " .. tier, 18, { Position = UDim2.new(0, 50, 0, 40),
			Size = UDim2.new(1, -50, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
		l.TextColor3 = C.plum
	end
end

local function lockedCard(it)
	local card = Ui.card(content, UDim2.new(1, -8, 0, 88), UDim2.new(), C.shade)
	card.BackgroundTransparency = 0.35
	card.LayoutOrder = nextOrder()
	swatch(card, it, true)
	local n = Ui.text(card, it.name, 20, { Position = UDim2.new(0, 88, 0, 12), Size = UDim2.new(1, -100, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left })
	n.TextTransparency = 0.25
	-- (no price on a locked shelf; "Opens when a horse reaches …" is said once, on its header)
end

local function itemCard(it)
	local own = owns(it.id)
	local on = own and worn(it)
	local back = canReturn(it.id)
	local tall = own and back
	local card = Ui.card(content, UDim2.new(1, -8, 0, if tall then 236 else 164), UDim2.new(),
		if on then C.gold elseif own then C.cream else C.white)
	card.LayoutOrder = nextOrder()
	swatch(card, it, false)
	Ui.text(card, it.name, 20, { Position = UDim2.new(0, 88, 0, 10), Size = UDim2.new(1, -100, 0, 28), TextXAlignment = Enum.TextXAlignment.Left })
	local sub = Ui.text(card, "", 18, { Position = UDim2.new(0, 88, 0, 42), Size = UDim2.new(1, -100, 0, 44), TextXAlignment = Enum.TextXAlignment.Left })
	sub.TextColor3 = C.textGood
	local row = buttonRow(card, 92)
	if own then
		sub.Text = if on then "Yours ✓ (in your yard)" else "Yours ✓"
		if it.slot == "cloth" or it.slot == "helmet" then sub.Text = if on then "Yours ✓ (wearing)" else "Yours ✓" end
		if on then
			button(row, if it.slot == "yard" then "Put away" else "Take off", C.white, 150, function()
				gameRemotes:WaitForChild("StyleWear"):FireServer(it.id, false)
			end)
		else
			button(row, if it.slot == "yard" then "Place it" else "Use it", C.sky, 150, function()
				gameRemotes:WaitForChild("StyleWear"):FireServer(it.id, true)
			end)
		end
		button(row, "See it ▶", C.orange, 150, function() seeIt(it.id) end)
		if back then
			-- two taps to return (like Legend and Back to races); no clock
			local row2 = buttonRow(card, 164)
			local note = Ui.text(card, "You can return it until tomorrow", 16, { Position = UDim2.new(0, 330, 0, 164),
				Size = UDim2.new(1, -342, 0, 64), TextXAlignment = Enum.TextXAlignment.Left })
			note.TextColor3 = C.plum
			if returning == it.id then
				button(row2, "Sure? ↩️", C.gold, 150, function()
					returning = nil
					gameRemotes:WaitForChild("StyleReturn"):FireServer(it.id)
					render()
				end)
				button(row2, "Keep it", C.white, 150, function()
					returning = nil
					render()
				end)
				note.Text = "You get 💵 " .. fmt(it.price) .. " back"
				note.TextColor3 = C.textGood
			else
				button(row2, "↩️ Return", C.white, 150, function()
					returning = it.id
					render()
				end)
			end
		end
		return
	end
	if confirming == it.id then
		local left = cash() - it.price
		if left >= 0 then
			sub.Text = string.format("Use 💵 %s? You'll have 💵 %s left.", fmt(it.price), fmt(left))
			button(row, "Yes, build", C.green, 150, function()
				confirming = nil
				justBuilt = nil
				pending = { id = it.id, kind = kindOf(it), snapshot = snapshot(), at = os.clock() }
				gameRemotes:WaitForChild("BuyCash"):FireServer(it.id)
				render()
			end)
			button(row, "No", C.white, 120, function()
				confirming = nil
				render()
			end)
			return
		end
		sub.Text = "You need 💵 " .. fmt(-left) .. " more"
		button(row, if wished(it.id) then "💭 Wished" else "💭 Wish", if wished(it.id) then C.gold else C.white, 150, function()
			confirming = nil
			gameRemotes:WaitForChild("StyleWish"):FireServer(if wished(it.id) then "" else it.id)
		end)
		button(row, "OK", C.white, 120, function()
			confirming = nil
			render()
		end)
		return
	end
	sub.Text = "💵 " .. fmt(it.price)
	button(row, "Build", C.orange, 150, function()
		confirming, returning = it.id, nil
		render()
	end)
	button(row, if wished(it.id) then "💭 Wished" else "💭 Wish", if wished(it.id) then C.gold else C.white, 150, function()
		gameRemotes:WaitForChild("StyleWish"):FireServer(if wished(it.id) then "" else it.id)
	end)
end

local function builtBanner(id: string)
	local it = Style.item(id)
	if not it then return end
	local card = Ui.card(content, UDim2.new(1, -8, 0, 96), UDim2.new(), C.gold)
	card.LayoutOrder = nextOrder()
	Ui.text(card, "🔨 " .. it.name .. " built! Go see it!", 20, { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -190, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left })
	local b = Ui.button(card, "See it ▶", UDim2.fromOffset(160, 64), UDim2.new(1, -172, 0.5, -32), C.orange, 20)
	b.Activated:Connect(function() seeIt(id) end)
end

render = function()
	if not gui.Enabled then return end
	local d = data()
	if not d then return end
	balance.Text = "💵 " .. fmt(cash()) .. " Green Cash"
	for _, ch in content:GetChildren() do
		if not ch:IsA("UIListLayout") then ch:Destroy() end
	end
	order = 0
	if justBuilt then builtBanner(justBuilt) end
	local open, nextTier, locked = Style.shelf(d)
	local lastTier = nil
	for _, it in open do
		if it.tier ~= lastTier then
			lastTier = it.tier
			header(BarnCatalog.TIER_LABEL[it.tier] .. " shelf", it.tier, false)
		end
		itemCard(it)
	end
	if nextTier and #locked > 0 then
		header(BarnCatalog.TIER_LABEL[nextTier] .. " shelf", nextTier, true)
		for _, it in locked do lockedCard(it) end
	end
end

local function open()
	if not PlayerState.data or shut() then return end
	gui.Enabled = true
	confirming, returning = nil, nil
	render()
	slide()
end
local function close()
	gui.Enabled = false
	confirming, returning, justBuilt = nil, nil, nil
end
GoTo.register("barnBuilder", open) -- (open is shut around races, like the counter)
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
PlayerState.Changed.Event:Connect(function() render() end)
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if player:GetAttribute("Racing") and gui.Enabled then close() end
end)
player:GetAttributeChangedSignal("InLine"):Connect(function()
	if player:GetAttribute("InLine") and gui.Enabled then close() end
end)

-- The counter at Feed & Seed (a little table with its own sign, beside the Feed & Seed counter).
do
	local p = WorldLayout.places.feedStore
	local folder = Instance.new("Model")
	folder.Name = "BarnBuilderCounter"
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
		local b = Instance.new("Part")
		b.Name = name
		b.Anchored, b.CanQuery, b.CanTouch = true, false, false
		b.Size, b.CFrame, b.Color = size, cf, color
		b.Material = material or Enum.Material.WoodPlanks
		b.Parent = folder
		return b
	end
	local base = CFrame.lookAt(Vector3.new(p.x + 14, -0.5, p.z + 7), Vector3.new(p.x + 14, -0.5, p.z + 20)) -- faces the street
	local counter = piece("Counter", Vector3.new(6, 3, 2.4), base * CFrame.new(0, 1.5, 0), Color3.fromHex("C48A55"))
	piece("CounterTop", Vector3.new(6.6, 0.3, 2.8), base * CFrame.new(0, 3.15, 0), Color3.fromHex("2E9E5B"), Enum.Material.SmoothPlastic)
	for _, sd in { -1, 1 } do piece("SignPost", Vector3.new(0.4, 4, 0.4), base * CFrame.new(sd * 2.6, 5, 0.6), Color3.fromHex("8A5A36")) end
	local sign = piece("Sign", Vector3.new(6.2, 1.6, 0.3), base * CFrame.new(0, 7.4, 0.6), Color3.fromHex("2E9E5B"), Enum.Material.SmoothPlastic)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front -- toward the street
	sg.CanvasSize = Vector2.new(310, 80)
	sg.LightInfluence = 0.2
	sg.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Ui.font
	t.TextScaled = true
	t.TextColor3 = C.white
	t.Text = "🔨 Barn Builder 💵"
	t.Parent = sg
	folder.Parent = workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Build", "Barn Builder"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(open)
	task.spawn(function()
		while true do
			local s = shut()
			if prompt.Enabled == s then prompt.Enabled = not s end
			if s and gui.Enabled then close() end
			task.wait(0.5)
		end
	end)
end

-- "New shelf at Barn Builder!" is a one-time Next-thing pill with GO to Feed & Seed (Advice.shelfPill,
-- the same calm-moment rules as "You can build"); StableBoard tells the server once it was shown (ShelfSeen).
