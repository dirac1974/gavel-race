--!nonstrict
-- VisitClient (D-060): visiting a friend's barn, and the owner's gate button.
--   At a friend's barn (a Roblox friend whose barn lets you in): a Pat prompt and a Treat prompt
--   on each stall door, and "Drop a carrot" on the post box. The server checks everything again
--   (Visits.luau); pats give no bond, treats are one a day, and nothing else can be done there.
--   Your own barn: while anyone is visiting, a big "🚪 Close gate" button sits over the dock;
--   one tap closes the gate and visitors are walked out to Barn Lane. "🔓 Open gate" opens it.
--   No visitor counts or names anywhere.
--   D-079: barns open to Everyone here let anyone in. There a stranger gets the Pat prompt only;
--   Treat and "Drop a carrot" show for friends only (Visits.may), and the server checks each again.
--   Pats go through VisitService (VisitHello), which lets in friends and strangers alike.
--   The prompts follow what the server publishes (Visits.clientMay: the effective setting, your
--   PolicyService answer, Ask to leave), so no prompt shows that the server would refuse.
--   Owner: while anyone is in the yard, "👋 Ask to leave" sits beside the gate button. It lists who's
--   in (display names, as over their heads), and one tap walks that visitor out kindly (AskToLeave).
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

local Visits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Visits"))

-- May you do `action` at this plot right now (the owner's setting, friends, the gate)? Visits.may is
-- the same permission matrix the server checks.
local function letIn(plot: Instance, action: string?): boolean
	local owner = plot:GetAttribute("OwnerId")
	if not GameConfig.visit.enabled or typeof(owner) ~= "number" or owner == player.UserId then return false end
	local visits = plot:GetAttribute("Visits")
	return Visits.clientMay({ visits = visits, gateClosed = plot:GetAttribute("GateClosed"),
		friend = Visits.setting(visits) ~= "Nobody" and isFriend(owner), strangersOk = player:GetAttribute("VisitStrangersOk"),
		askedOutOf = player:GetAttribute("AskedOutOf"), askedOutUntil = player:GetAttribute("AskedOutUntil"), ownerId = owner,
		serverNow = workspace:GetServerTimeNow() }, action or "enter")
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
			pat.Triggered:Connect(function() gameRemotes:WaitForChild("VisitHello"):FireServer(owner, "pat", id) end)
			local treat = prompt(d, "VisitTreat", "Treat", name, Enum.KeyCode.T)
			treat.Triggered:Connect(function() gameRemotes:WaitForChild("VisitCare"):FireServer(owner, id, "treat") end)
			table.insert(prompts, { pat, d, "pat" })
			table.insert(prompts, { treat, d, "treat" })
		elseif d:IsA("BasePart") and d.Name == "PostBox" and not d:FindFirstChild("VisitPost") then
			local post = prompt(d, "VisitPost", "Drop a carrot", "Post box", Enum.KeyCode.E)
			post.Triggered:Connect(function() gameRemotes:WaitForChild("PostBox"):FireServer(owner) end)
			table.insert(prompts, { post, nil, "post" })
		end
	end
	local function apply()
		for _, pr in prompts do
			-- an empty stall (the horse is out riding or racing) has nobody to pat
			pr[1].Enabled = letIn(plot, pr[3]) and not (pr[2] and pr[2]:GetAttribute("Away") == true)
		end
	end
	apply()
	plot:GetAttributeChangedSignal("Visits"):Connect(apply)
	plot:GetAttributeChangedSignal("GateClosed"):Connect(apply)
	player:GetAttributeChangedSignal("VisitStrangersOk"):Connect(apply)
	player:GetAttributeChangedSignal("AskedOutUntil"):Connect(function()
		apply()
		local untilT = player:GetAttribute("AskedOutUntil")
		if typeof(untilT) == "number" then task.delay(math.max(0, untilT - workspace:GetServerTimeNow()) + 0.5, apply) end
	end)
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

-- Ask to leave (code review S3): beside the gate button; a short list of who's in the yard.
local askBtn = Ui.button(gui, "👋 Ask to leave", UDim2.fromOffset(200, 64), UDim2.new(), C.white, 22)
askBtn.Visible = false
local askList = Ui.card(gui, UDim2.fromOffset(240, 64), UDim2.new(), C.paper)
askList.Visible = false
local askRows = Instance.new("Frame") -- (inside the card, so the card's lip stays out of the list)
askRows.BackgroundTransparency = 1
askRows.Size = UDim2.fromScale(1, 1)
askRows.Parent = askList
local askLayout = Instance.new("UIListLayout")
askLayout.Padding = UDim.new(0, 6)
askLayout.Parent = askRows
Ui.pad(askRows, 6)
local inYard: { { userId: number, name: string } } = {}

local function placeAsk()
	-- to the right of the gate button, the list above them both
	local p = gateBtn.Position
	askBtn.AnchorPoint = gateBtn.AnchorPoint
	askBtn.Position = UDim2.new(p.X.Scale, p.X.Offset + (if Ui.touchLayout() then 240 else 230), p.Y.Scale, p.Y.Offset)
	askList.AnchorPoint = Vector2.new(askBtn.AnchorPoint.X, 1)
	askList.Position = UDim2.new(askBtn.Position.X.Scale, askBtn.Position.X.Offset, askBtn.Position.Y.Scale, askBtn.Position.Y.Offset - 72)
end

local function drawAskList()
	for _, ch in askRows:GetChildren() do
		if ch:IsA("TextButton") then ch:Destroy() end
	end
	for k, v in inYard do
		local b = Ui.button(askRows, "👋 " .. v.name, UDim2.fromOffset(228, 64), UDim2.new(), C.cream, 20)
		b.LayoutOrder = k
		b.TextTruncate = Enum.TextTruncate.AtEnd
		b.Activated:Connect(function()
			gameRemotes:WaitForChild("AskToLeave"):FireServer(v.userId)
			askList.Visible = false
		end)
	end
	askList.Size = UDim2.fromOffset(240, 12 + #inYard * 70)
end

local function refresh()
	gateBtn.Text = if closed then "🔓 Open gate" else "🚪 Close gate"
	gateBtn.BackgroundColor3 = if closed then C.gold else C.cream
	gateBtn.Visible = (visitorsIn or closed) and not player:GetAttribute("Racing")
	askBtn.Visible = visitorsIn and #inYard > 0 and not player:GetAttribute("Racing")
	if not askBtn.Visible then askList.Visible = false end
	placeAsk()
end
player:GetAttributeChangedSignal("Racing"):Connect(refresh)
Ui.TouchChanged.Event:Connect(refresh)
askBtn.Activated:Connect(function()
	askList.Visible = not askList.Visible
	if askList.Visible then drawAskList() end
end)
gameRemotes:WaitForChild("GateState").OnClientEvent:Connect(function(isIn, isClosed, list)
	visitorsIn, closed = isIn == true, isClosed == true
	table.clear(inYard)
	if typeof(list) == "table" then
		for _, v in list do
			if typeof(v) == "table" and typeof(v.userId) == "number" and typeof(v.name) == "string" then table.insert(inYard, v) end
		end
	end
	if askList.Visible then drawAskList() end
	refresh()
end)
gateBtn.Activated:Connect(function()
	gameRemotes:WaitForChild("GateToggle"):FireServer()
end)

-- A friend's new build (D-070): when you walk into a friend's yard that built something in the last
-- greenCash.newBuildHours, it sparkles once (once per build per visit to this server). No counts.
do
	local WorldLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldLayout"))
	local okFx, BuildFx = pcall(require, script.Parent:WaitForChild("BuildFx", 10))
	local sparkled: { [string]: boolean } = {}
	local inside: number? = nil
	task.spawn(function()
		local world = workspace:WaitForChild("World", 60)
		local plots = world and world:WaitForChild("Plots", 60)
		while plots and okFx do
			task.wait(0.5)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local here: number? = nil
			if root then
				for i = 1, WorldLayout.PLOT_COUNT do
					local r = WorldLayout.plotRect(i)
					if root.Position.X >= r[1] and root.Position.X <= r[3] and root.Position.Z >= r[2] and root.Position.Z <= r[4] then
						here = i
						break
					end
				end
			end
			if here ~= inside then
				inside = here
				local plot = here and plots:FindFirstChild("Plot" .. here)
				local id = plot and plot:GetAttribute("FreshBuildId")
				if plot and typeof(id) == "string" and letIn(plot) and not sparkled[tostring(plot:GetAttribute("OwnerId")) .. ":" .. id] then
					sparkled[tostring(plot:GetAttribute("OwnerId")) .. ":" .. id] = true
					local barn = plot:FindFirstChild("Barn")
					local build = barn and barn:FindFirstChild("Build_" .. id)
					local at = build and build:GetAttribute("BuildAt")
					if typeof(at) ~= "Vector3" then
						local x, z = WorldLayout.plotPoint(here :: number, 80, 0)
						at = Vector3.new(x, 10, z) -- a look on the barn itself (paint, trim, doors)
					end
					BuildFx.sparkle(at :: Vector3, 20)
				end
			end
		end
	end)
end
