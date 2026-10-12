--!nonstrict
-- Starter: pick your first horse and name it (D-037). Three coats with equal stats, shown
-- as slowly turning 3D horses; the name is built by tapping word chips (NameGen), so there
-- is no typing and nothing to filter. Opens by itself for a player with no horses.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Horse = require(Shared:WaitForChild("Horse"))
local NameGen = require(Shared:WaitForChild("NameGen"))
local Tour = require(Shared:WaitForChild("Tour"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")

local C = Ui.colors
local gui = Ui.screen("Starter", 15)
gui.Enabled = false

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.35
dim.Parent = gui

-- The first screen anyone sees, at the floors (AAA Phase 2): its smallest text is 18 px and its
-- smallest button 64 px, so it shrinks to 0.875 at most (14 px text and 56 px buttons rendered);
-- what still doesn't fit a short phone scrolls instead of shrinking further.
-- A short phone (under ui.starterCompactBelowPx tall, the UI/UX consult): smaller horse pictures
-- and 🔀 New words in the button row, so the panel is 404 px (353 rendered) and Next ▶ shows whole
-- without scrolling.
local COMPACT = (function()
	local waited = 0
	while (not workspace.CurrentCamera or workspace.CurrentCamera.ViewportSize.Y < 2) and waited < 2 do
		waited += task.wait()
	end
	local cam = workspace.CurrentCamera
	return cam ~= nil and cam.ViewportSize.Y > 1 and cam.ViewportSize.Y < (GameConfig.ui.starterCompactBelowPx or 0)
end)()
local VP = if COMPACT then 104 else 150 -- the horse pictures' height
local W, H = 720, if COMPACT then 404 else 470
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
local slideIn = Ui.fitPanel(panel, W, H, nil, 18, 64)

local title = Ui.text(panel, "Choose your first horse!", 36, { Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 44) })
local subtitle = Ui.text(panel, "They're all just as fast. Pick the one you love!", 20,
	{ Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 26) })
subtitle.TextColor3 = C.plum

-- Step 1: three horse cards ----------------------------------------------------------
local step1 = Instance.new("Frame")
step1.BackgroundTransparency = 1
step1.Size = UDim2.new(1, -40, 1, -180)
step1.Position = UDim2.new(0, 20, 0, 100)
step1.Parent = panel

local picked: string? = nil
local cards = {}
local spinners = {}

local function horseModel(coat: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("RaceModels")
	if not folder then return nil end
	local m = folder:FindFirstChild("horse_stand_" .. coat) or folder:FindFirstChild("horse_" .. coat)
	return m and m:Clone()
end

local function viewport(parent: GuiObject, coat: string)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -16, 0, VP)
	vp.Position = UDim2.new(0, 8, 0, 8)
	vp.BackgroundColor3 = C.sky
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.fromRGB(255, 244, 220)
	Ui.corner(vp, 14)
	vp.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local holder = Instance.new("WorldModel")
	holder.Parent = vp
	local function fill()
		holder:ClearAllChildren()
		local m = horseModel(coat)
		if not m then
			m = Instance.new("Model")
			local body = Instance.new("Part")
			body.Size = Vector3.new(2, 3, 7)
			body.Color = Ui.coatColors[coat] or Ui.coatColors.bay
			body.CFrame = CFrame.new(0, 3, 0)
			body.Parent = m
			local head = Instance.new("Part")
			head.Size = Vector3.new(1.4, 1.6, 2.4)
			head.Color = body.Color
			head.CFrame = CFrame.new(0, 5, -4)
			head.Parent = m
			m.PrimaryPart = body
		end
		m:PivotTo(CFrame.new())
		m.Parent = holder
		local cf, size = m:GetBoundingBox()
		local dist = math.max(size.X, size.Y, size.Z) * 2.4
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist, size.Y * 0.35, dist * 0.2), cf.Position)
		return m
	end
	local model = fill()
	table.insert(spinners, function(dt)
		if model and model.Parent then model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 0.6, 0)) end
	end)
	-- Swap in the real model once art loads.
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("RaceModels", 30)
		if folder and not folder:GetAttribute("Loaded") then folder:GetAttributeChangedSignal("Loaded"):Wait() end
		if horseModel(coat) then model = fill() end
	end)
end

for i, s in Horse.STARTERS do
	local card = Ui.card(step1, UDim2.new(1 / 3, -14, 1, 0), UDim2.new((i - 1) / 3, 7, 0, 0), C.cream)
	viewport(card, s.coat)
	Ui.text(card, s.label, 26, { Position = UDim2.new(0, 0, 0, VP + 14), Size = UDim2.new(1, 0, 0, 30) })
	local blurb = Ui.text(card, s.blurb, 18, { Position = UDim2.new(0, 0, 0, VP + 44), Size = UDim2.new(1, 0, 0, 24) })
	blurb.TextColor3 = C.plum
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 5
	hit.Parent = card
	cards[s.coat] = card
	hit.Activated:Connect(function()
		picked = s.coat
		for coat, c in cards do
			local stroke = c:FindFirstChildOfClass("UIStroke")
			stroke.Color = if coat == picked then C.orange else C.ink
			stroke.Thickness = if coat == picked then 6 else 3
		end
		Ui.pop(card)
	end)
end

-- Step 2: name chips -------------------------------------------------------------
local step2 = Instance.new("Frame")
step2.BackgroundTransparency = 1
step2.Size = UDim2.new(1, -40, 1, -180)
step2.Position = UDim2.new(0, 20, 0, 100)
step2.Visible = false
step2.Parent = panel

local preview = Ui.text(step2, "", 44, { Size = UDim2.new(1, 0, 0, 54) })
-- (the chosen name in deep orange: the bright one fails contrast on paper)
preview.TextColor3 = C.textWarn
local rows = {}
for r = 1, 2 do
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 64)
	row.Position = UDim2.new(0, 0, 0, 58 + (r - 1) * 72)
	row.Parent = step2
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Padding = UDim.new(0, 8)
	l.Parent = row
	rows[r] = row
end
local chosen = { nil, nil }
local rng = Random.new()

local function updatePreview()
	local name = NameGen.build(chosen[1], chosen[2])
	preview.Text = name or "Tap words to name your horse"
	preview.TextColor3 = if name then C.textWarn else C.plum
end

local function fillChips()
	local first, second = NameGen.offer(rng, 5)
	for r, words in { first, second } do
		for _, c in rows[r]:GetChildren() do
			if c:IsA("TextButton") then c:Destroy() end
		end
		chosen[r] = nil
		for _, w in words do
			local b = Ui.button(rows[r], w, UDim2.fromOffset(118, 64), UDim2.new(), C.white, 20)
			b.Activated:Connect(function()
				chosen[r] = if chosen[r] == w then nil else w
				for _, other in rows[r]:GetChildren() do
					if other:IsA("TextButton") then
						other.BackgroundColor3 = if other.Text == chosen[r] then C.gold else C.white
					end
				end
				updatePreview()
			end)
		end
	end
	updatePreview()
end

local shuffle = Ui.button(step2, "🔀 New words", UDim2.fromOffset(180, 64), UDim2.new(0.5, -90, 0, 208), C.sky, 20)
shuffle.Activated:Connect(fillChips)

-- Buttons -------------------------------------------------------------------------
local back = Ui.button(panel, "◀ Back", UDim2.fromOffset(130, 64), UDim2.new(0, 24, 1, -80), C.white, 22)
local nextBtn = Ui.button(panel, "Next ▶", UDim2.fromOffset(if COMPACT then 220 else 250, 64),
	UDim2.new(1, if COMPACT then -244 else -274, 1, -80), C.orange, 26)
back.Visible = false
if COMPACT then -- (between Back and Next, only on the naming step)
	shuffle.Parent = panel
	shuffle.Position = UDim2.new(0, 166, 1, -80)
	shuffle.Visible = false
end

local step = 1
local function showStep(n: number)
	step = n
	step1.Visible, step2.Visible = n == 1, n == 2
	back.Visible = n == 2
	if COMPACT then shuffle.Visible = n == 2 end
	if n == 1 then
		title.Text, subtitle.Text = "Choose your first horse!", "They're all just as fast. Pick the one you love!"
		nextBtn.Text = "Next ▶"
	else
		title.Text, subtitle.Text = "Name your horse", "Tap one or two words"
		nextBtn.Text = "That's my horse!"
		fillChips()
	end
end

nextBtn.Activated:Connect(function()
	if step == 1 then
		if not picked then
			subtitle.Text = "Tap a horse first!"
			Ui.pop(subtitle)
			return
		end
		showStep(2)
	else
		if not NameGen.build(chosen[1], chosen[2]) then
			Ui.pop(preview)
			return
		end
		nextBtn.Text = "..."
		gameRemotes:WaitForChild("ChooseStarter"):FireServer(picked, chosen[1], chosen[2])
		task.delay(5, function()
			if gui.Enabled and step == 2 then nextBtn.Text = "That's my horse!" end -- no reply: let them try again
		end)
	end
end)
back.Activated:Connect(function() showStep(1) end)

local spinConn = nil
local function open()
	if gui.Enabled then return end
	showStep(1)
	gui.Enabled = true
	spinConn = RunService.RenderStepped:Connect(function(dt)
		for _, f in spinners do f(dt) end
	end)
	slideIn()
end

local function close()
	gui.Enabled = false
	if spinConn then spinConn:Disconnect() spinConn = nil end
end

HudEvents:WaitForChild("OpenStarter").Event:Connect(open)

local welcomed = false
PlayerState.watch(function(data)
	if not welcomed then -- "Welcome to Giddy-Up!" once per visit, when your stable has loaded
		welcomed = true
		if Sound then Sound.play("vo_welcome") end
	end
	if #data.horses == 0 then
		open()
	elseif gui.Enabled then
		close()
		-- The tour takes it from here (AAA Phase 2: one voice in the first minute); without the tour
		-- (skipped, or turned off) a toast says what to do.
		local touring = (GameConfig.firstMinute or {}).tourOwnsScreen ~= false and Tour.current(data.flags or {}) ~= nil
		local h = PlayerState.activeHorse()
		if h and not touring then Ui.toast(string.format("Meet %s! Tap RACE! when you're ready.", h.name), "heart", "❤️") end
	end
end)
