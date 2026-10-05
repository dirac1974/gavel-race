--!nonstrict
-- WildHorses (D-037): wild horses graze and wander in the Trail meadow. Every client draws
-- them from the same seed and the server clock, so everyone sees them in the same places
-- without the server moving anything. Walk up, "Make friends", and play the gentle game:
-- tap when the horse's ears are forward (the heart glows), never while it's startled. You
-- need a treat; one new friend a day (the server checks).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Market = require(Shared:WaitForChild("Market"))
local HorseLegs = require(Shared:WaitForChild("HorseLegs"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local C = Ui.colors

local GROUND_Y = -0.5
local COUNT = #Market.WILD_COATS -- one of each natural rare coat

local folder = Instance.new("Folder")
folder.Name = "WildHorses"
folder.Parent = workspace

local function modelFor(coat: string): Model
	local f = ReplicatedStorage:FindFirstChild("RaceModels")
	local anim = f and f:FindFirstChild("horse_anim_" .. coat)
	if anim and not HorseLegs.has(anim) then anim = nil end -- legs didn't import separately
	local m = f and (anim or f:FindFirstChild("horse_stand_" .. coat) or f:FindFirstChild("horse_gallop_" .. coat))
	if m then
		local c = m:Clone()
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end
		end
		return c
	end
	local p = Instance.new("Model")
	local body = Instance.new("Part")
	body.Anchored, body.CanCollide = true, false
	body.Size, body.Color = Vector3.new(2, 3, 6.5), Ui.coatColors[coat] or Ui.coatColors.dun
	body.CFrame = CFrame.new(0, 3.5, 0)
	body.Parent = p
	p.PrimaryPart = body
	p.WorldPivot = CFrame.new()
	return p
end

local horses = {}
local function build()
	folder:ClearAllChildren()
	table.clear(horses)
	for i = 1, COUNT do
		local coat = Market.WILD_COATS[((i - 1) % #Market.WILD_COATS) + 1]
		local m = modelFor(coat)
		m.Name = "Wild_" .. coat
		m:SetAttribute("Coat", coat)
		m.Parent = folder
		local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TamePrompt"
		prompt.ActionText = "Make friends"
		prompt.ObjectText = "Wild " .. coat:gsub("_", " ")
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		horses[i] = { model = m, coat = coat, prompt = prompt, still = false, index = i }
	end
end
build()
task.spawn(function()
	local f = ReplicatedStorage:WaitForChild("RaceModels", 60)
	if f and not f:GetAttribute("Loaded") then f:GetAttributeChangedSignal("Loaded"):Wait() end
	build()
end)

local lastPos = setmetatable({}, { __mode = "k" })
local LEGS_RANGE = 150 -- studs from the camera; farther horses glide (nobody can see their feet)
local TURN_RATE = 3     -- the heading eases toward the next spot (no spinning on the spot, D-056)
local RETURN_SECONDS = 1.2 -- after a taming game the horse walks back into its wander
local function yawOf(dx: number, dz: number): number
	return math.atan2(-dx, -dz) -- CFrame.Angles(0, yaw, 0) looks along (-sin yaw, 0, -cos yaw)
end
RunService.Heartbeat:Connect(function(dt)
	local t = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for i, h in horses do
		if h.model.Parent and not h.still then
			-- graze for the first half of a leg, then walk to the next spot (Market.wildPosition)
			local x, z, dx, dz, walk = Market.wildPosition(WorldLayout.meadow, i, t)
			local pos = Vector3.new(x, GROUND_Y, z)
			local want = yawOf(dx, dz)
			h.yaw = h.yaw or want
			h.yaw += ((want - h.yaw + math.pi) % (2 * math.pi) - math.pi) * math.min(1, dt * TURN_RATE)
			if h.returnFrom then -- ease from where the taming game left it back to its wander
				local a = math.clamp((os.clock() - h.returnFrom.t0) / RETURN_SECONDS, 0, 1)
				a = a * a * (3 - 2 * a)
				pos = h.returnFrom.pos:Lerp(pos, a)
				if a >= 1 then h.returnFrom = nil end
			end
			local bob = if walk > 0 and walk < 1 then 0.12 * math.abs(math.sin(t * 6 + i)) else 0
			h.model:PivotTo(CFrame.new(pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, h.yaw, 0))
			local prev = lastPos[h.model]
			lastPos[h.model] = pos
			if eye and (pos - eye).Magnitude < LEGS_RANGE and HorseLegs.has(h.model) then
				h.legsOn = true
				HorseLegs.apply(h.model, if prev then (pos - prev).Magnitude else 0, dt)
			elseif h.legsOn then
				h.legsOn = false
				HorseLegs.rest(h.model) -- out of range: stand the legs straight, then stop posing
			end
		end
	end
end)

-- The gentle game ----------------------------------------------------------------------
local gui = Ui.screen("Taming", 11)
gui.Enabled = false
local card = Ui.card(gui, UDim2.fromOffset(460, 330), UDim2.fromScale(0.5, 0.5), C.paper)
card.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = Instance.new("UIScale")
scale.Parent = card
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	local function rescale()
		local v = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (v.X - 20) / 460, (v.Y - 20) / 330)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
local title = Ui.text(card, "", 26, { Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 32) })
local hint = Ui.text(card, "Tap when the heart glows. Stay calm when it's startled!", 16, { Position = UDim2.new(0, 16, 0, 46), Size = UDim2.new(1, -32, 0, 22) })
hint.TextColor3 = C.plum
local heart = Ui.text(card, "🤍", 80, { Size = UDim2.fromOffset(110, 110), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 140), TextScaled = true })
local trust = Instance.new("Frame")
trust.Size = UDim2.new(1, -60, 0, 18)
trust.Position = UDim2.new(0, 30, 0, 206)
trust.BackgroundColor3 = C.white
Ui.corner(trust, 9)
Ui.stroke(trust, 2)
trust.Parent = card
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromHex("FF6FA5")
Ui.corner(fill, 9)
fill.Parent = trust
local tapBtn = Ui.button(card, "🥕 Offer", UDim2.fromOffset(200, 60), UDim2.new(0.5, -100, 1, -76), C.gold, 26)
local closeBtn = Ui.button(card, "✕", UDim2.fromOffset(40, 40), UDim2.new(1, -50, 0, 10), C.white, 20)

local answer: (boolean) -> () -- defined below
local session = nil -- { horse, phase, phaseUntil, good, bad, conns }
local NEED = 3
local waiting = 0 -- counts sends; the server's answer closes the newest

-- The server's answer to a won game: a new friend, or not this time (never "so close", D-056).
answer = function(ok: boolean)
	waiting += 1
	if session then return end
	title.Text = if ok then "💖 Friends!" else "Not yet, try again!"
	if ok then Ui.pop(heart) end
	task.delay(1.4, function() if not session then gui.Enabled = false end end)
end
task.spawn(function() gameRemotes:WaitForChild("TameResult").OnClientEvent:Connect(answer) end)

local function setPrompts(on: boolean)
	for _, h in horses do h.prompt.Enabled = on end
end

-- The horse walks back into its wander from where it stood still.
local function release(h)
	h.still = false
	h.returnFrom = { pos = Vector3.new(h.model:GetPivot().Position.X, GROUND_Y, h.model:GetPivot().Position.Z), t0 = os.clock() }
end

local function finish(score: number)
	if not session then return end
	local s = session
	session = nil
	release(s.horse)
	setPrompts(true)
	for _, c in s.conns do c:Disconnect() end
	-- The server decides (it checks you were next to the horse when the game began): a win waits
	-- for its answer before celebrating (D-056); a lost game just closes.
	gameRemotes:WaitForChild("Tame"):FireServer(s.horse.index, score, s.startedAt)
	if score <= 0 then
		task.delay(0.8, function() if not session then gui.Enabled = false end end)
		return
	end
	waiting += 1
	local mine = waiting
	title.Text = "Getting to know you…"
	task.delay(6, function() -- no answer: never leave the card hanging
		if waiting == mine then answer(false) end
	end)
end

local function tap()
	if not session then return end
	if session.phase == "glow" then
		session.good += 1
		session.phase, session.phaseUntil = "rest", os.clock() + 0.6
		fill.Size = UDim2.fromScale(session.good / NEED, 1)
		Ui.pop(heart)
		if session.good >= NEED then
			title.Text = "💖 It trusts you!"
			finish(100 - session.bad * 20)
		end
	elseif session.phase == "startle" then
		session.bad += 1
		title.Text = "Easy… it got startled"
		if session.bad >= 3 then
			title.Text = "It trotted off. Try again later!"
			finish(0)
		end
	end
end
tapBtn.MouseButton1Down:Connect(tap)
closeBtn.Activated:Connect(function()
	if session then
		release(session.horse)
		for _, c in session.conns do c:Disconnect() end
		session = nil
	end
	setPrompts(true)
	gui.Enabled = false
end)

local function start(h)
	if session then return end
	local d = PlayerState.data
	if d and d.market and not d.market.canTame then
		Ui.toast("You made a new friend today, or need a treat (carrot, apple or sugar cube).", "heart", "🥕")
		return
	end
	h.still = true
	if HorseLegs.has(h.model) then HorseLegs.rest(h.model) end -- stands still, not frozen mid-stride
	setPrompts(false)
	title.Text = "Make friends with the wild " .. (string.gsub(h.coat, "_", " "))
	fill.Size = UDim2.fromScale(0, 1)
	session = { horse = h, phase = "wait", phaseUntil = os.clock() + 1.2, good = 0, bad = 0, conns = {},
		startedAt = workspace:GetServerTimeNow() }
	gui.Enabled = true
	local rng = Random.new()
	table.insert(session.conns, RunService.RenderStepped:Connect(function()
		if not session then return end
		local t = os.clock()
		if t >= session.phaseUntil then
			if session.phase == "glow" then
				session.phase, session.phaseUntil = "wait", t + rng:NextNumber(0.8, 1.6) -- missed it, no harm
			elseif session.phase == "rest" or session.phase == "wait" then
				if rng:NextNumber() < 0.3 then
					session.phase, session.phaseUntil = "startle", t + rng:NextNumber(0.7, 1.2)
				else
					session.phase, session.phaseUntil = "glow", t + 0.9
				end
			elseif session.phase == "startle" then
				session.phase, session.phaseUntil = "wait", t + rng:NextNumber(0.6, 1.2)
			end
		end
		heart.Text = if session.phase == "glow" then "💖" elseif session.phase == "startle" then "😮" else "🤍"
	end))
	table.insert(session.conns, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Space then tap() end
	end))
end

game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "TamePrompt" then return end
	for _, h in horses do
		if h.prompt == prompt then start(h) end
	end
end)
