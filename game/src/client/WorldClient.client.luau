--!nonstrict
-- WorldClient: the client side of the world (D-035, D-042).
--   Privacy: each plot publishes its owner and visit setting; this client turns a plot's
--   invisible walls solid for itself when it isn't allowed in (default Friends only) or the
--   owner has closed the gate (D-060).
--   Map: the dock's Map button opens five big picture buttons for fast travel, and a sixth,
--   "Friends' barns" (D-060): the faces and names of Roblox friends in this server whose barn
--   lets you in; tap one to go to their gate. Your Tour stamps show under the list.
--   Race Board: its prompt puts you in line like the RACE! button.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local WorldLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldLayout"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

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
	if plot:GetAttribute("GateClosed") then return false end -- the owner closed the gate (D-060)
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
	plot:GetAttributeChangedSignal("GateClosed"):Connect(function() applyPlot(plot) end)
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
local PANEL_W, PANEL_H = 760, 300
local panel = Ui.card(gui, UDim2.fromOffset(PANEL_W, PANEL_H), UDim2.fromScale(0.5, 0.5), C.paper)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = Instance.new("UIScale")
scale.Parent = panel
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.min(1, (v.X - 24) / PANEL_W, (v.Y - 24) / PANEL_H)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
local title = Ui.text(panel, "Where to?", 34, { Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 40) })
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
local close = Ui.button(panel, "✕", UDim2.fromOffset(56, 56), UDim2.new(1, -68, 0, 10), C.white, 24)

local friendsPage: Frame
local back: TextButton
local function hide() gui.Enabled = false end
local function show()
	gui.Enabled = true
	row.Visible = true
	friendsPage.Visible = false
	back.Visible = false
	title.Text = "Where to?"
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

-- Friends' barns (D-060) ---------------------------------------------------------------
local friendsBtn = Ui.button(row, "", UDim2.fromOffset(108, 170), UDim2.new(), C.gold, 18)
friendsBtn.LayoutOrder = 99
friendsBtn.Visible = GameConfig.visit.enabled and GameConfig.visit.mapList
Ui.icon(friendsBtn, "friends", "👫", UDim2.fromOffset(78, 78), UDim2.new(0.5, -39, 0, 14))
Ui.text(friendsBtn, "Friends' barns", 20, { Position = UDim2.new(0, 4, 0, 104), Size = UDim2.new(1, -8, 0, 56) })

friendsPage = Instance.new("Frame")
friendsPage.BackgroundTransparency = 1
friendsPage.Size = UDim2.new(1, -32, 1, -70)
friendsPage.Position = UDim2.new(0, 16, 0, 62)
friendsPage.Visible = false
friendsPage.Parent = panel
back = Ui.button(panel, "◀ Back", UDim2.fromOffset(140, 56), UDim2.new(0, 12, 0, 10), C.white, 22)
back.Visible = false
local faces = Instance.new("ScrollingFrame")
faces.BackgroundTransparency = 1
faces.BorderSizePixel = 0
faces.Size = UDim2.new(1, 0, 0, 176)
faces.CanvasSize = UDim2.new()
faces.AutomaticCanvasSize = Enum.AutomaticSize.X
faces.ScrollingDirection = Enum.ScrollingDirection.X
faces.ScrollBarThickness = 6
faces.Parent = friendsPage
local facesLayout = Instance.new("UIListLayout")
facesLayout.FillDirection = Enum.FillDirection.Horizontal
facesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
facesLayout.Padding = UDim.new(0, 12)
facesLayout.SortOrder = Enum.SortOrder.LayoutOrder
facesLayout.Parent = faces
local empty = Ui.text(friendsPage, "", 22, { Position = UDim2.new(0, 10, 0, 30), Size = UDim2.new(1, -20, 0, 110) })
empty.TextColor3 = C.plum
-- Your Tour stamps (the Horse Book gets this card in stage 6).
local stampRow = Instance.new("Frame")
stampRow.BackgroundTransparency = 1
stampRow.Size = UDim2.new(1, 0, 0, 40)
stampRow.Position = UDim2.new(0, 0, 1, -42)
stampRow.Parent = friendsPage
Ui.icon(stampRow, "stamp_checkup", "🎫", UDim2.fromOffset(36, 36), UDim2.new(0, 8, 0, 2))
local stampText = Ui.text(stampRow, "", 22, { Position = UDim2.new(0, 52, 0, 0), Size = UDim2.new(1, -60, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left })

local thumbs: { [number]: string } = {}
local function face(userId: number, img: ImageLabel)
	if thumbs[userId] then
		img.Image = thumbs[userId]
		return
	end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and typeof(url) == "string" then
			thumbs[userId] = url
			if img.Parent then img.Image = url end
		end
	end)
end

local function showStamps()
	local n = PlayerState.data and PlayerState.data.tourStamps or 0
	stampText.Text = if n == 0 then "Tour stamps: none yet. Pat every horse in a friend's barn to get one!"
		else "Tour stamps: " .. n .. (if n == 1 then " barn toured" else " barns toured")
end

local function drawFriends(list)
	for _, ch in faces:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	if typeof(list) ~= "table" then list = {} end
	empty.Visible = #list == 0
	empty.Text = "No friends' barns here yet.\nWhen a Roblox friend is in this game, their face shows up here."
	for k, f in list do
		if typeof(f) == "table" and typeof(f.userId) == "number" and typeof(f.name) == "string" then
			local b = Ui.button(faces, "", UDim2.fromOffset(132, 168), UDim2.new(), if f.closed then C.white else C.cream, 18)
			b.LayoutOrder = k
			local img = Instance.new("ImageLabel")
			img.BackgroundColor3 = C.sky
			img.Size = UDim2.fromOffset(84, 84)
			img.Position = UDim2.new(0.5, -42, 0, 10)
			img.Parent = b
			Ui.corner(img, 42)
			face(f.userId, img)
			Ui.text(b, f.name, 18, { Position = UDim2.new(0, 4, 0, 98), Size = UDim2.new(1, -8, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
			local go = Ui.text(b, if f.closed then "🔒 Gate closed" else "🏡 Visit ▶", 18, { Position = UDim2.new(0, 4, 0, 128), Size = UDim2.new(1, -8, 0, 30) })
			go.TextColor3 = if f.closed then C.plum else C.ink
			if f.closed then
				img.ImageTransparency = 0.5
				b.Activated:Connect(function() Ui.toast("That gate is closed right now. Try again later!", "heart", "🔒") end)
			else
				b.Activated:Connect(function()
					gameRemotes:WaitForChild("VisitFriend"):FireServer(f.userId)
					hide()
				end)
			end
		end
	end
	showStamps()
end

gameRemotes:WaitForChild("FriendBarns").OnClientEvent:Connect(function(list)
	if friendsPage.Visible then drawFriends(list) end
end)

local function showFriends()
	row.Visible = false
	friendsPage.Visible = true
	back.Visible = true
	title.Text = "Friends' barns"
	empty.Visible = true
	empty.Text = "Looking for your friends..."
	for _, ch in faces:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	showStamps()
	gameRemotes:WaitForChild("FriendBarns"):FireServer()
end
local function showPlaces()
	row.Visible = true
	friendsPage.Visible = false
	back.Visible = false
	title.Text = "Where to?"
end
friendsBtn.Activated:Connect(function()
	if not (PlayerState.data and #PlayerState.data.horses > 0) then
		Ui.toast("Pick your first horse to open your stable!", "heart", "🐴")
		return
	end
	showFriends()
end)
back.Activated:Connect(showPlaces)
PlayerState.Changed.Event:Connect(function()
	if friendsPage.Visible then showStamps() end
end)

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
			HudEvents:WaitForChild("OpenRacePicker"):Fire()
		end
	end
end)
