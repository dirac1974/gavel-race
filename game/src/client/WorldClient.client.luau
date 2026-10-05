--!nonstrict
-- WorldClient: the client side of the world (D-035, D-042).
--   Privacy: each plot publishes its owner and visit setting; this client turns a plot's
--   invisible walls solid for itself when it isn't allowed in (default Friends only).
--   Map: the dock's Map button opens five big picture buttons for fast travel.
--   Race Board: its prompt puts you in line like the RACE! button.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local WorldLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldLayout"))

local player = Players.LocalPlayer
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local raceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors

-- Privacy walls ------------------------------------------------------------------------
local friendCache: { [number]: boolean } = {}
local function isFriend(userId: number): boolean
	if friendCache[userId] == nil then
		local ok, res = pcall(function() return player:IsFriendsWith(userId) end)
		if not ok then return false end -- try again next time; never cache a failed check
		friendCache[userId] = res == true
	end
	return friendCache[userId]
end

local function allowed(plot: Model): boolean
	local owner = plot:GetAttribute("OwnerId")
	if not owner or owner == player.UserId then return true end
	local visits = plot:GetAttribute("Visits") or "Friends"
	if visits == "Nobody" then return false end
	return isFriend(owner) -- "Club" is treated as Friends until clubs exist
end

local function applyPlot(plot: Model)
	local walls = plot:FindFirstChild("PrivacyWalls")
	if not walls then return end
	local solid = not allowed(plot)
	for _, w in walls:GetChildren() do
		if w:IsA("BasePart") then w.CanCollide = solid end
	end
	-- Standing inside a plot that just closed to you (a new owner arrived): step out to the lane.
	local i = plot:GetAttribute("PlotIndex")
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if solid and i and hrp then
		local r = WorldLayout.plotRect(i)
		local pos = hrp.Position
		if pos.X > r[1] and pos.X < r[3] and pos.Z > r[2] and pos.Z < r[4] then
			local x, z = WorldLayout.plotPoint(i, -10, 0)
			c:PivotTo(CFrame.new(x, pos.Y + 1, z))
		end
	end
end

local function watchPlot(plot: Instance)
	if not plot:IsA("Model") then return end
	applyPlot(plot)
	plot:GetAttributeChangedSignal("OwnerId"):Connect(function() applyPlot(plot) end)
	plot:GetAttributeChangedSignal("Visits"):Connect(function() applyPlot(plot) end)
	plot.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.Parent and d.Parent.Name == "PrivacyWalls" then applyPlot(plot) end
	end)
end

task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	local plots = world and world:WaitForChild("Plots", 60)
	if not plots then return end
	for _, plot in plots:GetChildren() do watchPlot(plot) end
	plots.ChildAdded:Connect(watchPlot)
end)

-- Map -----------------------------------------------------------------------------
local gui = Ui.screen("Map", 12)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text = ""
dim.AutoButtonColor = false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.45
dim.Parent = gui
local panel = Ui.card(gui, UDim2.fromOffset(640, 300), UDim2.fromScale(0.5, 0.5), C.paper)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = Instance.new("UIScale")
scale.Parent = panel
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.min(1, (v.X - 24) / 640, (v.Y - 24) / 300)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
Ui.text(panel, "Where to?", 34, { Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 40) })
local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Size = UDim2.new(1, -32, 0, 190)
row.Position = UDim2.new(0, 16, 0, 70)
row.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 12)
layout.Parent = row
local close = Ui.button(panel, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 12), C.white, 22)

local function hide() gui.Enabled = false end
local function show()
	gui.Enabled = true
	panel.Position = UDim2.fromScale(0.5, 0.56)
	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end
for _, dest in WorldLayout.MAP do
	local b = Ui.button(row, "", UDim2.fromOffset(108, 170), UDim2.new(), C.cream, 18)
	Ui.icon(b, WorldLayout.MAP_ICONS[dest], WorldLayout.MAP_EMOJI[dest], UDim2.fromOffset(78, 78), UDim2.new(0.5, -39, 0, 14))
	Ui.text(b, WorldLayout.MAP_LABELS[dest], 20, { Position = UDim2.new(0, 4, 0, 104), Size = UDim2.new(1, -8, 0, 56) })
	b.Activated:Connect(function()
		if dest == "stable" and not (PlayerState.data and #PlayerState.data.horses > 0) then
			Ui.toast("Pick your first horse to open your stable!", "heart", "🐴")
			return
		end
		gameRemotes:WaitForChild("Travel"):FireServer(dest)
		hide()
	end)
end
close.Activated:Connect(hide)
dim.Activated:Connect(hide)

local openMap = HudEvents:FindFirstChild("OpenMap")
if not openMap then
	openMap = Instance.new("BindableEvent")
	openMap.Name = "OpenMap"
	openMap.Parent = HudEvents
end
openMap.Event:Connect(function()
	if gui.Enabled then hide() else show() end
end)

-- Race Board prompt -----------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "RacePrompt" then
		if not PlayerState.activeHorse() then
			HudEvents:WaitForChild("OpenStarter"):Fire()
		else
			raceRemotes:WaitForChild("JoinRace"):FireServer(true)
		end
	end
end)
