--!nonstrict
-- ComeBackClient (D-063, stage 6): the little moments that make coming back nice.
--   Welcome Back Hay Bale: after 3+ days away your horse trots up beside you with a hay bale
--   tied with a red bow, and a card shows the gift (always the same size; already in your
--   stable). "Thanks!" closes it. No streaks, no "you missed", no timers.
--   "New best!": a pill beside your results card when a ride beats your best at that distance.
--   Photo Finish: a 📷 Photo button beside your results card when you win, and the photo board
--   in your yard. Both use Roblox's own CaptureService: it takes the picture, then Roblox's own
--   Save and Share prompts ask the player. The game never uploads or keeps a picture.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local C = Ui.colors
local player = Players.LocalPlayer
local CB = GameConfig.comeback or {}

local MIN_TOUCH = math.max(56, (GameConfig.ui and GameConfig.ui.minTouchPx) or 56)
local TEXT = math.max(16, (GameConfig.ui and GameConfig.ui.labelPx) or 16)

local ITEM_WORDS = {
	hay = { "🌾", "hay" }, seed_carrot = { "🥕", "carrot seeds" }, seed_apple = { "🍎", "apple seeds" }, seed_oats = { "🌾", "oat seeds" },
	treat = { "🍬", "treat" }, carrot = { "🥕", "carrots" }, apple = { "🍎", "apples" }, grain = { "🌽", "grain" }, oats = { "🌾", "oats" },
}

local gui = Ui.screen("ComeBack", 12)

-- Welcome Back Hay Bale ------------------------------------------------------------------
local welcomeCard = Ui.card(gui, UDim2.fromOffset(400, 250), UDim2.fromScale(0.5, 0.5), C.paper)
welcomeCard.AnchorPoint = Vector2.new(0.5, 0.5)
welcomeCard.Visible = false
local welcomeScale = Instance.new("UIScale")
welcomeScale.Parent = welcomeCard
local welcomeTitle = Ui.text(welcomeCard, "", 26, { Position = UDim2.new(0, 12, 0, 14), Size = UDim2.new(1, -24, 0, 64) })
local welcomeGift = Ui.text(welcomeCard, "", 20, { Position = UDim2.new(0, 12, 0, 84), Size = UDim2.new(1, -24, 0, 70) })
welcomeGift.TextColor3 = C.cash
local thanksBtn = Ui.button(welcomeCard, "💛 Thanks!", UDim2.fromOffset(200, MIN_TOUCH + 8), UDim2.new(0.5, -100, 1, -MIN_TOUCH - 24), C.orange, 24)

local scene: Model? = nil
local shownFor = false -- shown this session (the server clears pending on Thanks)

local function groundAt(pos: Vector3): number
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else pos.Y - 3
end

local function cloneModel(names: { string }): Model?
	local f = ReplicatedStorage:FindFirstChild("RaceModels")
	for _, n in names do
		local src = f and f:FindFirstChild(n)
		if src then return src:Clone() end
	end
	return nil
end

local function settle(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
	end
end

-- The hay bale and the horse that trots up with it, on this screen only.
local function playWelcome(coat: string)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if scene then scene:Destroy() end
	local m = Instance.new("Model")
	m.Name = "WelcomeBack"
	scene = m
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then look = Vector3.new(0, 0, -1) end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local spot = hrp.Position + look * 9
	local y = groundAt(spot)
	local baleCF = CFrame.lookAt(Vector3.new(spot.X, y, spot.Z), Vector3.new(hrp.Position.X, y, hrp.Position.Z))
	local bale = cloneModel({ "welcome_hay_bale", "hay_bale" })
	if bale then
		settle(bale)
		bale:PivotTo(baleCF)
		bale.Parent = m
	else
		local p = Instance.new("Part")
		p.Size, p.Color, p.Material = Vector3.new(4, 3, 3), Color3.fromHex("E8C76A"), Enum.Material.Fabric
		p.CFrame = baleCF * CFrame.new(0, 1.5, 0)
		p.Parent = m
	end
	-- a red bow, carrots and an apple on top (a retexture can't add them)
	local top = baleCF * CFrame.new(0, 3.6, 0)
	for _, s in { -1, 1 } do
		local loop = Instance.new("Part")
		loop.Shape = Enum.PartType.Ball
		loop.Size, loop.Color = Vector3.new(1.1, 0.7, 0.7), C.red
		loop.CFrame = top * CFrame.new(s * 0.55, 0.3, 0)
		loop.Parent = m
	end
	for k = -1, 1, 2 do
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Cylinder
		c.Size, c.Color = Vector3.new(1.2, 0.4, 0.4), Color3.fromHex("FF8A1F")
		c.CFrame = top * CFrame.new(k * 0.9, 0, 0.8) * CFrame.Angles(0, 0.4 * k, 0)
		c.Parent = m
	end
	local apple = Instance.new("Part")
	apple.Shape = Enum.PartType.Ball
	apple.Size, apple.Color = Vector3.new(0.8, 0.8, 0.8), C.red
	apple.CFrame = top * CFrame.new(0, 0, -0.9)
	apple.Parent = m
	settle(m)
	m.Parent = workspace
	-- The horse trots in from the side and stops beside the bale, facing you.
	local f = ReplicatedStorage:FindFirstChild("RaceModels")
	local anim = f and f:FindFirstChild("horse_anim_" .. coat)
	if anim and not HorseLegs.has(anim) then anim = nil end
	local horse = if anim then anim:Clone() else cloneModel({ "horse_stand_" .. coat, "horse_" .. coat })
	if not horse then return end
	settle(horse)
	horse.Parent = m
	local from = spot + right * 34
	local to = spot + right * 6
	local t0, dur = os.clock(), 2.6
	local last = from
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not horse.Parent then
			conn:Disconnect()
			return
		end
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		local ease = 1 - (1 - a) * (1 - a)
		local pos = from:Lerp(to, ease)
		local gy = groundAt(pos)
		local face = if a < 1 then pos + (to - from).Unit else Vector3.new(hrp.Position.X, gy, hrp.Position.Z)
		horse:PivotTo(CFrame.lookAt(Vector3.new(pos.X, gy, pos.Z), Vector3.new(face.X, gy, face.Z)))
		if HorseLegs.has(horse) then HorseLegs.apply(horse, (pos - last).Magnitude, dt) end
		last = pos
		if a >= 1 then conn:Disconnect() end
	end)
end

local function giftText(gift): string
	local bits = {}
	for _, item in { "hay", "seed_carrot", "seed_apple", "seed_oats", "carrot", "apple", "grain", "oats", "treat" } do
		local n = gift[item]
		if n and n > 0 then
			local w = ITEM_WORDS[item] or { "🎁", item }
			table.insert(bits, string.format("%s %d %s", w[1], n, w[2]))
		end
	end
	return table.concat(bits, "   ")
end

local function showWelcome()
	local d = PlayerState.data
	local w = d and d.welcome
	if not w or shownFor or #d.horses == 0 then return end
	if RaceState.active and RaceState.myLane then return end
	shownFor = true
	local h = PlayerState.activeHorse()
	local name = (h and h.name) or "Your horse"
	welcomeTitle.Text = string.format("🐴 Welcome back! %s has a gift for you!", name)
	welcomeGift.Text = giftText(w.gift or {})
	-- Narrow screens get a narrower card, never smaller text or buttons (D-064 floors).
	local cam = workspace.CurrentCamera
	local w = if cam then math.clamp(cam.ViewportSize.X - 24, 280, 400) else 400
	welcomeCard.Size = UDim2.fromOffset(w, 250)
	welcomeScale.Scale = 1
	welcomeCard.Visible = true
	Ui.pop(welcomeCard)
	pcall(playWelcome, (h and h.coat) or "bay")
end

thanksBtn.Activated:Connect(function()
	welcomeCard.Visible = false
	gameRemotes:WaitForChild("WelcomeSeen"):FireServer()
	local m = scene
	scene = nil
	if m then task.delay(4, function() m:Destroy() end) end
end)

task.spawn(function()
	-- Give the world a moment to load, then show the gift once (if there is one).
	while not PlayerState.data do task.wait(0.5) end
	task.wait(4)
	if (CB.welcome or {}).enabled ~= false then showWelcome() end
	PlayerState.Changed.Event:Connect(function()
		if not shownFor then showWelcome() end
	end)
end)

-- Right-side column beside the results card: "New best!" and the 📷 Photo button ----------
local column = Instance.new("Frame")
column.BackgroundTransparency = 1
column.AnchorPoint = Vector2.new(1, 0.5)
column.Position = UDim2.new(1, -16, 0.5, 0)
column.Size = UDim2.fromOffset(170, 240)
column.Parent = gui
local colLayout = Instance.new("UIListLayout")
colLayout.Padding = UDim.new(0, 10)
colLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
colLayout.VerticalAlignment = Enum.VerticalAlignment.Center
colLayout.SortOrder = Enum.SortOrder.LayoutOrder
colLayout.Parent = column

local bestPill = Ui.card(column, UDim2.fromOffset(170, 84), UDim2.new(), C.gold)
bestPill.LayoutOrder = 1
bestPill.Visible = false
Ui.text(bestPill, "🏅 New best!", 22, { Position = UDim2.new(0, 6, 0, 8), Size = UDim2.new(1, -12, 0, 28), TextWrapped = false })
local bestSub = Ui.text(bestPill, "", TEXT, { Position = UDim2.new(0, 6, 0, 42), Size = UDim2.new(1, -12, 0, 30) })

local photoBtn = Ui.button(column, "📷 Photo", UDim2.fromOffset(150, MIN_TOUCH + 8), UDim2.new(), C.sky, 22)
photoBtn.LayoutOrder = 2
photoBtn.Visible = false

local pendingBest = nil -- { distance, score } waiting for the results card
local wonRace = false

-- Roblox's own prompts: save to the device, or share. Nothing is uploaded by the game.
local choice = Ui.card(gui, UDim2.fromOffset(340, 170), UDim2.fromScale(0.5, 0.5), C.paper)
choice.AnchorPoint = Vector2.new(0.5, 0.5)
choice.Visible = false
Ui.text(choice, "📷 Nice photo!", 24, { Position = UDim2.new(0, 10, 0, 12), Size = UDim2.new(1, -20, 0, 30) })
local saveBtn = Ui.button(choice, "💾 Save", UDim2.fromOffset(140, MIN_TOUCH), UDim2.new(0, 20, 1, -MIN_TOUCH - 20), C.green, 20)
local shareBtn = Ui.button(choice, "📤 Share", UDim2.fromOffset(140, MIN_TOUCH), UDim2.new(1, -160, 1, -MIN_TOUCH - 20), C.sky, 20)
local closeChoice = Ui.button(choice, "✕", UDim2.fromOffset(MIN_TOUCH, MIN_TOUCH), UDim2.new(1, -MIN_TOUCH - 6, 0, 6), C.white, 22)
local lastCapture: any = nil
closeChoice.Activated:Connect(function() choice.Visible = false end)
saveBtn.Activated:Connect(function()
	choice.Visible = false
	if lastCapture then
		pcall(function() CaptureService:PromptSaveCapturesToGallery({ lastCapture }, function() end) end)
	end
end)
shareBtn.Activated:Connect(function()
	choice.Visible = false
	if lastCapture then
		pcall(function() CaptureService:PromptShareCapture(lastCapture, "", function() end, function() end) end)
	end
end)

local snapping = false
local function takePhoto()
	if snapping or CB.photo == false then return end
	snapping = true
	-- Hide the game's screens for a clean picture, then bring back exactly what was showing.
	-- Each screen we hide is tagged; one that another script changed meanwhile (turned back on, or
	-- tag cleared) is left as that script set it.
	local hidden = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			g:SetAttribute("PhotoHidden", true)
			table.insert(hidden, g)
		end
	end
	local done = false
	local function restore()
		if done then return end
		done = true
		for _, g in hidden do
			if g.Parent and g:GetAttribute("PhotoHidden") and not g.Enabled then g.Enabled = true end
			g:SetAttribute("PhotoHidden", nil)
		end
		snapping = false
	end
	for _, g in hidden do -- a screen another script turns on or off meanwhile keeps its new state
		local c
		c = g:GetPropertyChangedSignal("Enabled"):Connect(function()
			c:Disconnect()
			if not done then g:SetAttribute("PhotoHidden", nil) end
		end)
		task.delay(4, function() if c.Connected then c:Disconnect() end end)
	end
	RunService.RenderStepped:Wait() -- let the hidden screens leave the frame first
	RunService.RenderStepped:Wait()
	local ok = pcall(function()
		CaptureService:CaptureScreenshot(function(contentId)
			restore()
			lastCapture = contentId
			choice.Visible = true
			Ui.pop(choice)
		end)
	end)
	if not ok then
		restore()
		Ui.toast("The camera isn't ready. Try again!", "", "📷")
		return
	end
	task.delay(3, restore) -- never leave the screens hidden
end
photoBtn.Activated:Connect(takePhoto)

-- The photo board in your yard (StableService puts a PhotoPrompt on it).
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who == player and prompt.Name == "PhotoPrompt" then takePhoto() end
end)

local open = false -- your results card is up (see the Heartbeat below)
local function showBest()
	if not pendingBest then return end
	bestSub.Text = string.format("%s  %d", tostring(pendingBest.distance), tonumber(pendingBest.score) or 0)
	bestPill.Visible = true
	Ui.pop(bestPill)
end

raceRemotes:WaitForChild("PersonalBest").OnClientEvent:Connect(function(distance, score, _prev, _courseId)
	if CB.bests == false then return end
	pendingBest = { distance = distance, score = score }
	if open then showBest() end -- the card beat the message here
end)

-- A new race of yours starts clean (nothing carried over from the last card).
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if player:GetAttribute("Racing") then
		pendingBest, wonRace = nil, false
		bestPill.Visible, photoBtn.Visible = false, false
	end
end)

raceRemotes:WaitForChild("RaceFinished").OnClientEvent:Connect(function(summary, _courseId)
	for _, row in summary or {} do
		if not row.isBot and row.id == tostring(player.UserId) then
			wonRace = row.place == 1
			return
		end
	end
end)

-- Show the column while your own results card is up; clear it when it closes.
RunService.Heartbeat:Connect(function()
	local up = RaceState.resultsOpen and RaceState.holdFocus
	if up and not open then
		open = true
		showBest()
		photoBtn.Visible = wonRace and CB.photo ~= false
	elseif not up and open then
		open = false
		pendingBest, wonRace = nil, false
		bestPill.Visible, photoBtn.Visible = false, false
	end
end)
