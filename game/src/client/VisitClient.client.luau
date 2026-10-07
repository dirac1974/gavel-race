--!nonstrict
-- VisitClient (D-060): visiting a friend's barn, and the owner's gate button.
--   At a friend's barn (a Roblox friend whose barn lets you in): a Pat prompt and a Treat prompt
--   on each stall door, and "Drop a carrot" on the post box. The server checks everything again
--   (Visits.luau); pats give no bond, treats are one a day, and nothing else can be done there.
--   Your own barn: while anyone is visiting, a big "🚪 Close gate" button sits over the dock;
--   one tap closes the gate and visitors are walked out to Barn Lane. "🔓 Open gate" opens it.
--   No visitor counts or names anywhere.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local C = Ui.colors

-- Friends (asked once per owner and cached, like the privacy walls).
local friendCache: { [number]: boolean } = {}
local function isFriend(userId: number): boolean
	if friendCache[userId] == nil then
		local ok, res = pcall(function() return player:IsFriendsWith(userId) end)
		if not ok then return false end
		friendCache[userId] = res == true
	end
	return friendCache[userId]
end

local function letIn(plot: Instance): boolean
	local owner = plot:GetAttribute("OwnerId")
	if not GameConfig.visit.enabled or not owner or owner == player.UserId then return false end
	if plot:GetAttribute("Visits") == "Nobody" or plot:GetAttribute("GateClosed") then return false end
	return isFriend(owner)
end

local function prompt(parent: Instance, name: string, action: string, object: string, key: Enum.KeyCode): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Prompts on one friend's barn, switched on and off with their setting and gate.
local function attach(plot: Instance, barn: Instance)
	local owner = barn:GetAttribute("Owner")
	if typeof(owner) ~= "number" or owner == player.UserId then return end
	local prompts = {}
	for _, d in barn:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("HorseId") and not d:FindFirstChild("VisitPat") then
			local id, name = d:GetAttribute("HorseId"), d:GetAttribute("HorseName") or "Horse"
			local pat = prompt(d, "VisitPat", "Pat", name, Enum.KeyCode.E)
			pat.UIOffset = Vector2.new(0, 40)
			pat.Triggered:Connect(function() gameRemotes:WaitForChild("VisitCare"):FireServer(owner, id, "pat") end)
			local treat = prompt(d, "VisitTreat", "Treat", name, Enum.KeyCode.T)
			treat.Triggered:Connect(function() gameRemotes:WaitForChild("VisitCare"):FireServer(owner, id, "treat") end)
			table.insert(prompts, { pat, d })
			table.insert(prompts, { treat, d })
		elseif d:IsA("BasePart") and d.Name == "PostBox" and not d:FindFirstChild("VisitPost") then
			local post = prompt(d, "VisitPost", "Drop a carrot", "Post box", Enum.KeyCode.E)
			post.Triggered:Connect(function() gameRemotes:WaitForChild("PostBox"):FireServer(owner) end)
			table.insert(prompts, { post })
		end
	end
	local function apply()
		local on = letIn(plot)
		for _, pr in prompts do
			-- an empty stall (the horse is out riding or racing) has nobody to pat
			pr[1].Enabled = on and not (pr[2] and pr[2]:GetAttribute("Away") == true)
		end
	end
	apply()
	plot:GetAttributeChangedSignal("Visits"):Connect(apply)
	plot:GetAttributeChangedSignal("GateClosed"):Connect(apply)
	for _, pr in prompts do
		if pr[2] then pr[2]:GetAttributeChangedSignal("Away"):Connect(apply) end
	end
end

task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	local plots = world and world:WaitForChild("Plots", 60)
	if not plots then return end
	local function watch(plot: Instance)
		local function onBarn(ch: Instance)
			if ch.Name == "Barn" then task.delay(0.2, function() if ch.Parent then attach(plot, ch) end end) end
		end
		for _, ch in plot:GetChildren() do onBarn(ch) end
		plot.ChildAdded:Connect(onBarn)
	end
	for _, plot in plots:GetChildren() do watch(plot) end
	plots.ChildAdded:Connect(watch)
end)

-- The owner's gate button -------------------------------------------------------------
local gui = Ui.screen("Gate", 6)
local gateBtn = Ui.button(gui, "🚪 Close gate", UDim2.fromOffset(230, 64), UDim2.new(), C.cream, 26)
gateBtn.AnchorPoint = Vector2.new(0.5, 1)
gateBtn.Visible = false
local visitorsIn, closed = false, false

local function place()
	-- over the dock: centred on a PC, at the left with the dock on a touch screen (Hop and
	-- Gallop live at the bottom right)
	if Ui.touchLayout() then
		gateBtn.AnchorPoint = Vector2.new(0, 1)
		gateBtn.Position = UDim2.new(0, 12, 1, -112)
	else
		gateBtn.AnchorPoint = Vector2.new(0.5, 1)
		gateBtn.Position = UDim2.new(0.5, 0, 1, -112)
	end
end
place()
Ui.TouchChanged.Event:Connect(place)

local function refresh()
	gateBtn.Text = if closed then "🔓 Open gate" else "🚪 Close gate"
	gateBtn.BackgroundColor3 = if closed then C.gold else C.cream
	gateBtn.Visible = (visitorsIn or closed) and not player:GetAttribute("Racing")
end
player:GetAttributeChangedSignal("Racing"):Connect(refresh)
gameRemotes:WaitForChild("GateState").OnClientEvent:Connect(function(isIn, isClosed)
	visitorsIn, closed = isIn == true, isClosed == true
	refresh()
end)
gateBtn.Activated:Connect(function()
	gameRemotes:WaitForChild("GateToggle"):FireServer()
end)
