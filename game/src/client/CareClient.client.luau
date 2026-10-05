--!nonstrict
-- CareClient (D-038): caring for your horses at your own barn, the garden, chores and the
-- Feed & Seed. Prompts are made on this client for your own plot only (visitors never see
-- them). One "Care for <name>" prompt per horse opens a card with big buttons: Feed, Groom
-- (a quick brushing game), Treat and Pet, with today's care and bond shown.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Care = require(Shared:WaitForChild("Care"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))

local player = Players.LocalPlayer
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local C = Ui.colors

local function remote(name: string): RemoteEvent
	return gameRemotes:WaitForChild(name)
end

local ITEM_LABEL = { hay = "Hay", grain = "Grain", carrot = "Carrot", apple = "Apple", oats = "Oats", treat = "Sugar cube",
	seed_carrot = "Carrot seeds", seed_apple = "Apple seeds", seed_oats = "Oat seeds" }
local ITEM_EMOJI = { hay = "🌾", grain = "🥣", carrot = "🥕", apple = "🍎", oats = "🌾", treat = "🧊",
	seed_carrot = "🌱", seed_apple = "🌱", seed_oats = "🌱" }

local function count(item: string): number
	local d = PlayerState.data
	return d and d.items[item] or 0
end

-- Generic modal card ----------------------------------------------------------------
local gui = Ui.screen("Care", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local card = Ui.card(gui, UDim2.fromOffset(560, 380), UDim2.fromScale(0.5, 0.5), C.paper)
card.AnchorPoint = Vector2.new(0.5, 0.5)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
local function rescale()
	local cam = workspace.CurrentCamera
	if cam then cardScale.Scale = math.min(1, (cam.ViewportSize.X - 24) / 560, (cam.ViewportSize.Y - 24) / 380) end
end
rescale()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
local title = Ui.text(card, "", 32, { Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 38) })
local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, -32, 1, -70)
body.Position = UDim2.new(0, 16, 0, 60)
body.Parent = card
local closeBtn = Ui.button(card, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 12), C.white, 22)
local onClose = nil
local function closeCard()
	gui.Enabled = false
	if onClose then onClose() onClose = nil end
end
closeBtn.Activated:Connect(closeCard)
dim.Activated:Connect(closeCard)
local function openCard(text: string, height: number?)
	if onClose then
		onClose()
		onClose = nil
	end
	body:ClearAllChildren()
	title.Text = text
	card.Size = UDim2.fromOffset(560, height or 380)
	gui.Enabled = true
	card.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

-- Grooming game: brush the dusty spots away -------------------------------------------
local function groomGame(horseName: string, coat: string, done: () -> ())
	openCard("Brush " .. horseName .. "!", 400)
	local area = Instance.new("Frame")
	area.Size = UDim2.new(1, 0, 0, 250)
	area.BackgroundColor3 = C.sky
	Ui.corner(area, 16)
	area.Parent = body
	local horseArt = Ui.text(area, "🐴", 160, { Size = UDim2.fromScale(1, 1), TextScaled = true })
	horseArt.TextTransparency = 0
	local spots = {}
	local rng = Random.new()
	for _ = 1, 9 do
		local s = Instance.new("Frame")
		local size = rng:NextInteger(34, 52)
		s.Size = UDim2.fromOffset(size, size)
		s.Position = UDim2.new(rng:NextNumber(0.2, 0.75), 0, rng:NextNumber(0.2, 0.7), 0)
		s.BackgroundColor3 = Color3.fromHex("8C6A43")
		s.BackgroundTransparency = 0.15
		Ui.corner(s, size // 2)
		s.Parent = area
		table.insert(spots, s)
	end
	local hint = Ui.text(body, "Hold and swipe over the mud spots", 20, { Position = UDim2.new(0, 0, 0, 258), Size = UDim2.new(1, 0, 0, 26) })
	hint.TextColor3 = C.plum
	local left = #spots
	local pressing = false
	local conns = {}
	local function brushAt(pos: Vector2)
		for _, s in spots do
			if s.Parent and s.BackgroundTransparency < 1 then
				local p, sz = s.AbsolutePosition, s.AbsoluteSize
				if pos.X >= p.X - 12 and pos.X <= p.X + sz.X + 12 and pos.Y >= p.Y - 12 and pos.Y <= p.Y + sz.Y + 12 then
					s.BackgroundTransparency += 0.34
					if s.BackgroundTransparency >= 0.99 then
						s.BackgroundTransparency = 1
						left -= 1
						if left == 0 then
							hint.Text = "✨ Shiny! ✨"
							for _, c in conns do c:Disconnect() end
							task.delay(0.6, function()
								closeCard()
								done()
							end)
						end
					end
				end
			end
		end
	end
	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressing = true
			brushAt(Vector2.new(input.Position.X, input.Position.Y))
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pressing = false end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if pressing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			brushAt(Vector2.new(input.Position.X, input.Position.Y))
		end
	end))
	onClose = function()
		for _, c in conns do c:Disconnect() end
	end
end

-- Horse care card ------------------------------------------------------------------------
local openHorseId: string? = nil
local refreshHorse: (() -> ())? = nil

local function horseCard(id: string)
	local h = PlayerState.horse(id)
	if not h then return end
	openHorseId = id
	openCard("Care for " .. h.name, 400)
	local status = Ui.text(body, "", 22, { Size = UDim2.new(1, 0, 0, 28) })
	local bondBar = Instance.new("Frame")
	bondBar.Size = UDim2.new(1, -120, 0, 18)
	bondBar.Position = UDim2.new(0, 110, 0, 36)
	bondBar.BackgroundColor3 = C.cream
	Ui.corner(bondBar, 9)
	Ui.stroke(bondBar, 2)
	bondBar.Parent = body
	local bondFill = Instance.new("Frame")
	bondFill.BackgroundColor3 = Color3.fromHex("FF6FA5")
	Ui.corner(bondFill, 9)
	bondFill.Parent = bondBar
	Ui.text(body, "❤️ Bond", 18, { Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(0, 100, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 230)
	grid.Position = UDim2.new(0, 0, 0, 70)
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -8, 0, 104)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.Parent = grid

	local function action(text: string, color: Color3, fn)
		local b = Ui.button(grid, text, UDim2.new(), UDim2.new(), color, 24)
		b.Activated:Connect(fn)
		return b
	end
	local feedBtn = action("🌾 Feed", C.gold, function()
		local item = if count("grain") > 0 and count("hay") == 0 then "grain" else "hay"
		remote("CareAction"):FireServer(id, "feed", item)
	end)
	local groomBtn = action("🪮 Groom", C.sky, function()
		local horse = PlayerState.horse(id)
		if not horse then return end
		groomGame(horse.name, horse.coat, function() remote("CareAction"):FireServer(id, "groom") end)
	end)
	local treatBtn = action("🥕 Treat", C.orange, function()
		for _, item in { "carrot", "apple", "oats", "treat" } do
			if count(item) > 0 then
				remote("CareAction"):FireServer(id, "treat", item)
				return
			end
		end
		Ui.toast("No treats! Grow carrots or buy sugar cubes", "carrot", "🥕")
	end)
	action("❤️ Pet", Color3.fromHex("FFB3CF"), function() remote("CareAction"):FireServer(id, "pet") end)

	refreshHorse = function()
		local horse = PlayerState.horse(id)
		if not horse or not gui.Enabled or openHorseId ~= id then return end
		local care = math.floor(horse.care * 2 + 0.5)
		status.Text = string.format("Care today: %s   ⚡ %d   🌾 %d hay", string.rep("⭐", care) .. string.rep("☆", 2 - care), horse.energy, count("hay"))
		bondFill.Size = UDim2.fromScale(math.clamp(horse.bond / 100, 0.02, 1), 1)
		feedBtn.Text = if horse.fed then "🌾 Fed ✓" else "🌾 Feed"
		groomBtn.Text = if horse.groomed then "🪮 Shiny ✓" else "🪮 Groom"
		local treats = 0
		for _, item in { "carrot", "apple", "oats", "treat" } do treats += count(item) end
		treatBtn.Text = string.format("🥕 Treat (%d)", treats)
	end
	refreshHorse()
	onClose = function() openHorseId = nil end
end

PlayerState.Changed.Event:Connect(function()
	if refreshHorse then refreshHorse() end
end)

-- Garden card -----------------------------------------------------------------------
local function gardenCard(bedIndex: number)
	local d = PlayerState.data
	local b = d and d.garden and d.garden[bedIndex]
	if not b then return end
	if b.seed ~= "" then
		local seed = Care.SEEDS[b.seed]
		local progress = Care.cropProgress(b, workspace:GetServerTimeNow())
		if progress >= 1 then
			remote("Garden"):FireServer(bedIndex, "harvest")
		else
			Ui.toast(string.format("%s growing: %d%%", seed.label, math.floor(progress * 100)), "seed_carrot", "🌱")
		end
		return
	end
	openCard("Plant something", 300)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 180)
	row.Parent = body
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Padding = UDim.new(0, 12)
	l.Parent = row
	for _, seedItem in { "seed_carrot", "seed_apple", "seed_oats" } do
		local seed = Care.SEEDS[seedItem]
		local hours = seed.seconds / 3600
		local b2 = Ui.button(row, string.format("%s\n%s\n%d h · have %d", ITEM_EMOJI[seed.crop], seed.label, hours, count(seedItem)),
			UDim2.fromOffset(150, 170), UDim2.new(), if count(seedItem) > 0 then C.cream else C.shade, 20)
		b2.Activated:Connect(function()
			remote("Garden"):FireServer(bedIndex, "plant", seedItem)
			closeCard()
		end)
	end
end

-- Feed & Seed shop --------------------------------------------------------------------
local function shopCard()
	openCard("Feed & Seed", 420)
	local cash = Ui.text(body, "", 22, { Size = UDim2.new(1, 0, 0, 28) })
	cash.TextColor3 = C.cash
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 250)
	grid.Position = UDim2.new(0, 0, 0, 34)
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 3, -10, 0, 118)
	layout.CellPadding = UDim2.fromOffset(12, 10)
	layout.Parent = grid
	local labels = {}
	for _, row in Care.SHOP do
		local cell = Ui.card(grid, UDim2.new(), UDim2.new(), C.cream)
		Ui.text(cell, ITEM_EMOJI[row.item] .. " " .. row.label, 18, { Position = UDim2.new(0, 0, 0, 6), Size = UDim2.new(1, 0, 0, 24) })
		local have = Ui.text(cell, "", 15, { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 18) })
		have.TextColor3 = C.plum
		labels[row.item] = have
		local b1 = Ui.button(cell, "💵 " .. row.price, UDim2.new(0.46, 0, 0, 44), UDim2.new(0.03, 0, 1, -52), C.gold, 18)
		local b5 = Ui.button(cell, "×5", UDim2.new(0.42, 0, 0, 44), UDim2.new(0.55, 0, 1, -52), C.white, 18)
		b1.Activated:Connect(function() remote("Shop"):FireServer("buy", row.item, 1) end)
		b5.Activated:Connect(function() remote("Shop"):FireServer("buy", row.item, 5) end)
	end
	local sell = Ui.button(body, "Sell crops", UDim2.fromOffset(170, 44), UDim2.new(0.5, -85, 1, -50), C.teal, 20)
	sell.Activated:Connect(function()
		remote("Shop"):FireServer("sellAll", "crops", 5) -- keeps 5 of each for treats
	end)
	local function refresh()
		if not gui.Enabled then return end
		cash.Text = "💵 " .. tostring(PlayerState.data and PlayerState.data.cash or 0) .. " Green Cash"
		for item, label in labels do label.Text = "You have " .. count(item) end
	end
	refresh()
	local conn = PlayerState.Changed.Event:Connect(refresh)
	onClose = function() conn:Disconnect() end
end

-- Prompts on your own plot ----------------------------------------------------------------
local function prompt(parent: Instance, action: string, object: string, key: Enum.KeyCode?, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "CarePrompt"
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Default
	p.Parent = parent
	return p
end

local function attachBarn(barn: Instance)
	if barn:GetAttribute("Owner") ~= player.UserId then return end
	-- Stall k holds the k-th horse (StableService); both prompts hang on its half door, which
	-- is where a kid stands (the horse itself is too far into the barn to reach).
	local d = PlayerState.data
	for _, m in barn:GetChildren() do
		if m:IsA("BasePart") and m.Name == "Noticeboard" then
			if not m:FindFirstChild("CarePrompt") then
				prompt(m, "Read", "Stable Board", Enum.KeyCode.E).Triggered:Connect(function()
					ReplicatedStorage:WaitForChild("HudEvents"):WaitForChild("OpenBoard"):Fire()
				end)
			end
		elseif m:IsA("BasePart") and string.sub(m.Name, 1, 5) == "Stall" then
			local stall = tonumber(string.sub(m.Name, 6))
			local h = stall and d and d.horses[stall]
			if h and not m:FindFirstChild("CarePrompt") then
				local id = h.id
				local p = prompt(m, "Care", h.name)
				p.UIOffset = Vector2.new(0, 40)
				p.Triggered:Connect(function() horseCard(id) end)
			end
			if stall and not m:FindFirstChild("ChorePrompt") then
				local chore = prompt(m, "Muck out", "Stall", Enum.KeyCode.F, 1.2)
				chore.Name = "ChorePrompt"
				chore.Triggered:Connect(function()
					remote("Chore"):FireServer(stall)
				end)
			end
		end
	end
end

local function attachGarden(garden: Instance)
	if garden:GetAttribute("Owner") ~= player.UserId then return end
	for _, bed in garden:GetChildren() do
		local bedIndex = tonumber(string.sub(bed.Name, 4))
		local anchor = bed:FindFirstChild("Box") or bed:FindFirstChildWhichIsA("BasePart", true)
		if bedIndex and anchor and not anchor:FindFirstChild("CarePrompt") then
			prompt(anchor, "Garden", "Bed " .. bedIndex, Enum.KeyCode.G).Triggered:Connect(function() gardenCard(bedIndex) end)
		end
	end
end

-- Little hearts and sparkles over a horse when someone cares for it (everyone sees them).
local FX = { feed = "😋", groom = "✨", treat = "❤️", pet = "❤️" }
gameRemotes:WaitForChild("CareFx").OnClientEvent:Connect(function(plotIndex, horseId, kind)
	local world = workspace:FindFirstChild("World")
	local plot = world and world:FindFirstChild("Plots") and world.Plots:FindFirstChild("Plot" .. tostring(plotIndex))
	local barn = plot and plot:FindFirstChild("Barn")
	local hm = barn and barn:FindFirstChild("Horse_" .. tostring(horseId))
	local anchor = hm and (hm.PrimaryPart or hm:FindFirstChildWhichIsA("BasePart", true))
	if not anchor then return end
	for k = 1, 5 do
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(40, 40)
		bb.StudsOffsetWorldSpace = Vector3.new((k - 3) * 0.8, 5, 0)
		bb.Adornee = anchor
		bb.Parent = anchor
		local t = Ui.text(bb, FX[kind] or "❤️", 30, { Size = UDim2.fromScale(1, 1), TextScaled = true })
		task.delay(k * 0.08, function()
			TweenService:Create(bb, TweenInfo.new(1.4), { StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, 4, 0) }):Play()
			TweenService:Create(t, TweenInfo.new(1.4), { TextTransparency = 1 }):Play()
			task.wait(1.5)
			bb:Destroy()
		end)
	end
end)

task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	local plots = world and world:WaitForChild("Plots", 60)
	if not plots then return end
	local function scan()
		local i = player:GetAttribute("PlotIndex")
		local plot = i and plots:FindFirstChild("Plot" .. i)
		local barn = plot and plot:FindFirstChild("Barn")
		if barn then attachBarn(barn) end
		local garden = plot and plot:FindFirstChild("Garden")
		if garden then attachGarden(garden) end
	end
	local pending = false
	plots.DescendantAdded:Connect(function(d)
		if pending then return end
		if d.Name == "Barn" or d.Name == "Garden" then
			pending = true
			task.delay(0.2, function()
				pending = false
				scan()
			end)
		end
	end)
	player:GetAttributeChangedSignal("PlotIndex"):Connect(scan)
	PlayerState.Changed.Event:Connect(function(_, before)
		if before == nil then scan() end -- first profile view: add the Care prompts
	end)
	scan()
	-- The shop counter on Fair Street.
	local places = world:WaitForChild("Places", 60)
	local function shopPrompt()
		local store = places and places:FindFirstChild("Feed & Seed") or (places and places:FindFirstChild("feed_store"))
		local p = WorldLayout.places.feedStore
		local anchor = Instance.new("Part")
		anchor.Name = "ShopCounter"
		anchor.Anchored, anchor.CanCollide, anchor.Transparency = true, false, 1
		anchor.Size = Vector3.new(4, 4, 4)
		anchor.CFrame = CFrame.new(p.x, 2, p.z + 6)
		anchor.Parent = workspace
		prompt(anchor, "Shop", "Feed & Seed").Triggered:Connect(shopCard)
		return store
	end
	shopPrompt()
end)

-- Toasts for results come from the server's Notice remote (Hud).
