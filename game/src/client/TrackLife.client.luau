--!nonstrict
-- TrackLife (AAA Phase 4, D-069): the racecourse comes alive on this screen. Drawn only.
--   Crowd: the crowd Textures on the grandstand risers (server/TrackDressing) bounce, calm in the
--     lobby (calmStuds at calmHz) and cheering (cheerStuds at cheerHz) from the burst until your
--     results card shows. Rows bounce a little out of step.
--   Flags: each pennant flutters a few degrees of yaw about its pole.
--   Both are still under Reduced Motion.
--   Everything here ticks only while you're within spectate.keepStuds of a course, at trackLife.updateHz
--   (phoneHz on phones).
--   Big Board: a SurfaceGui (this client only) on the infield board shows the followed race's top 4
--     (place, lane chip, horse name) from RaceState.order, the same order as the place badge,
--     refreshed at bigBoard.refreshHz. No race: the board's own "GIDDY-UP!" shows. Never a win %,
--     a purse or a prize (rule 1, D-055).
--   Practice with a friend (AAA Phase 3 should-fix): a small friends mark under a friend's lane badge,
--     on the screens of the riders in that race only.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TrackLifeView = require(Shared:WaitForChild("TrackLifeView"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local L = GameConfig.trackLife or { enabled = false }
local BOARD = GameConfig.bigBoard or { live = false }
local FRIEND = GameConfig.friendRace or { badge = false }
local TAG_CROWD, TAG_FLAG, TAG_BOARD = "GiddyCrowd", "GiddyFlag", "GiddyBigBoard" -- (TrackDressing's tags)
local player = Players.LocalPlayer
local myId = tostring(player.UserId)

local still = false
local function readStill()
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	still = ok and on == true
end
readStill()
pcall(function() GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(readStill) end)

-- Tagged instances, kept in arrays so the per-frame loop allocates nothing.
local crowd: { Texture } = {}
local crowdRow: { number } = {}
local flags: { Attachment } = {}
local flagLen: { number } = {}
local flagY: { number } = {}

local function track(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
	for _, inst in CollectionService:GetTagged(tag) do add(inst) end
end

local function removeFrom(list, parallel, inst)
	local i = table.find(list, inst)
	if not i then return end
	local last = #list
	list[i] = list[last]
	list[last] = nil
	for _, p in parallel do
		p[i] = p[last]
		p[last] = nil
	end
end

track(TAG_CROWD, function(inst)
	if inst:IsA("Texture") and not table.find(crowd, inst) then
		table.insert(crowd, inst)
		table.insert(crowdRow, inst:GetAttribute("Row") or 0)
	end
end, function(inst) removeFrom(crowd, { crowdRow }, inst) end)

track(TAG_FLAG, function(inst)
	if inst:IsA("Attachment") and not table.find(flags, inst) then
		table.insert(flags, inst)
		table.insert(flagLen, inst:GetAttribute("Length") or 7)
		table.insert(flagY, inst:GetAttribute("HingeY") or inst.Position.Y)
	end
end, function(inst) removeFrom(flags, { flagLen, flagY }, inst) end)

-- Horse names for each course's current race (only the names: nothing else from the lane list).
local names: { [string]: { string } } = {}

-- The Big Board ------------------------------------------------------------------------------
local board: BasePart? = nil
local gui: SurfaceGui? = nil
local rowLabels: { { chip: TextLabel, text: TextLabel, frame: Frame } } = {}
local rows = {}
local INK, PAPER, GOLD = Color3.fromHex("1D2433"), Color3.fromHex("FFF7E6"), Color3.fromHex("FFD23F")

local function label(parent: Instance, props): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = PAPER
	for k, v in props do t[k] = v end
	t.Parent = parent
	return t
end

local function buildBoardGui(part: BasePart)
	if gui then gui:Destroy() end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "BigBoardLive"
	sg.Face = Enum.NormalId.Right -- +X, toward the grandstand (as the board's own sign)
	sg.CanvasSize = Vector2.new(850, 300)
	sg.LightInfluence = 0
	sg.ZOffset = 1
	sg.Adornee = part
	sg.Enabled = false
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = INK
	bg.BorderSizePixel = 0
	bg.Parent = sg
	label(bg, { Name = "Title", Size = UDim2.new(1, -40, 0.2, 0), Position = UDim2.new(0, 20, 0, 6), TextColor3 = GOLD,
		Text = TrackLifeView.LIVE_TITLE, TextXAlignment = Enum.TextXAlignment.Left })
	table.clear(rowLabels)
	for k = 1, BOARD.rows or 4 do
		local f = Instance.new("Frame")
		f.Name = "Row" .. k
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, -40, 0.19, 0)
		f.Position = UDim2.new(0, 20, 0.22 + (k - 1) * 0.195, 0)
		f.Parent = bg
		local chip = label(f, { Name = "Chip", Size = UDim2.fromScale(0.08, 0.9), Position = UDim2.fromScale(0, 0.05),
			BackgroundTransparency = 0, TextColor3 = PAPER, Text = "" })
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = chip
		local stroke = Instance.new("UIStroke")
		stroke.Color = PAPER
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = chip
		local text = label(f, { Name = "Text", Size = UDim2.fromScale(0.89, 1), Position = UDim2.fromScale(0.11, 0),
			TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
		rowLabels[k] = { chip = chip, text = text, frame = f }
	end
	sg.Parent = player:WaitForChild("PlayerGui")
	gui = sg
end

local function setIdle(idle: boolean)
	if gui then gui.Enabled = not idle end
	if board then -- the board's own sign (built by the server) shows when idle
		for _, child in board:GetChildren() do
			if child:IsA("SurfaceGui") then child.Enabled = idle end
		end
	end
end

local shownLive = false
local function refreshBoard()
	if not (BOARD.live and board and board.Parent and gui) then
		if shownLive then
			shownLive = false
			setIdle(true)
		end
		return
	end
	local course = RaceState.focus
	local live = RaceState.active and course ~= nil and #RaceState.order > 0
	if not live then
		if shownLive then
			shownLive = false
			setIdle(true)
		end
		return
	end
	local n = TrackLifeView.boardRows(RaceState.order, names[course], #rowLabels, rows)
	for k, ui in rowLabels do
		local row = rows[k]
		if k <= n and row then
			ui.frame.Visible = true
			local hex = TrackLifeView.LANE_HEX[row.lane] or "3A3F4B"
			ui.chip.BackgroundColor3 = Color3.fromHex(hex)
			ui.chip.TextColor3 = if TrackLifeView.LIGHT_LANES[row.lane] then INK else PAPER
			local num = tostring(row.lane)
			if ui.chip.Text ~= num then ui.chip.Text = num end
			local text = TrackLifeView.rowText(row)
			if ui.text.Text ~= text then ui.text.Text = text end
		else
			ui.frame.Visible = false
		end
	end
	if not shownLive then
		shownLive = true
		setIdle(false)
	end
end

if BOARD.live then
	track(TAG_BOARD, function(inst)
		if inst:IsA("BasePart") then
			board = inst
			buildBoardGui(inst)
			shownLive = false
		end
	end, function(inst)
		if inst == board then
			board = nil
			if gui then gui.Enabled = false end
		end
	end)
end

-- Practice with a friend: a friends mark under the friend's lane badge -------------------------
local friendCache: { [string]: boolean } = {}
local function isFriend(id: string): boolean
	if friendCache[id] ~= nil then return friendCache[id] end
	local userId = tonumber(id)
	if not userId then return false end
	local ok, res = pcall(function() return player:IsFriendsWith(userId) end)
	if ok then friendCache[id] = res == true end -- a failed check isn't cached
	return ok and res == true
end

local function markFriend(courseId: string, lane: number)
	local folder = RaceState.trackFolder(courseId)
	local horses = folder and folder:WaitForChild("Horses", 10)
	local horse = horses and horses:WaitForChild("Lane" .. lane, 10)
	if not horse or horse:FindFirstChild("FriendMark") then return end
	local mark = Instance.new("BillboardGui")
	mark.Name = "FriendMark"
	mark.Size = UDim2.fromOffset(40, 30)
	mark.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0) -- the lane badge's spot...
	mark.SizeOffset = Vector2.new(0, -1.5)            -- ...and just under it
	mark.AlwaysOnTop = true
	mark.MaxDistance = 400
	label(mark, { Size = UDim2.fromScale(1, 1), Text = "👫" })
	mark.Parent = horse
end

remotes.RaceStarted.OnClientEvent:Connect(function(title, laneList, _start, _cond, _resultAt, _burstOpen, courseId)
	courseId = courseId or "dirt"
	local list = {}
	local mine = false
	for i, lane in laneList do
		list[i] = lane.name
		if lane.id == myId then mine = true end
	end
	names[courseId] = list
	if not (FRIEND.badge and mine and title == "Practice") then return end
	for i, lane in laneList do
		if not lane.isBot and lane.id ~= myId and lane.id ~= nil then
			task.spawn(function()
				if isFriend(tostring(lane.id)) then markFriend(courseId, i) end
			end)
		end
	end
end)

-- The loop -----------------------------------------------------------------------------------
if not L.enabled and not BOARD.live then return end
local function tickSeconds(): number
	local hz = if RaceState.phone() then (L.phoneHz or L.updateHz or 30) else (L.updateHz or 30)
	return 1 / math.max(1, hz)
end
local tickEvery = tickSeconds()
local nearAcc, near = math.huge, false
local KEEP = (GameConfig.spectate and GameConfig.spectate.keepStuds) or 300
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
-- Near any course? (checked once a second; at the barn or on the Trail nothing ticks)
local function nearAnyCourse(): boolean
	for id in TrackLayout.courses do
		if RaceState.nearCourse(id, KEEP) then return true end
	end
	return false
end
local boardEvery = 1 / math.max(1, BOARD.refreshHz or 4)
local acc, boardAcc = 0, 0
local wasStill = false
local state = { active = false, burstShowing = false, resultsOpen = false, leaderProgress = 0 }

RunService.Heartbeat:Connect(function(dt)
	nearAcc += dt
	if nearAcc >= 1 then
		nearAcc = 0
		near = nearAnyCourse()
		tickEvery = tickSeconds()
	end
	if not near then return end
	boardAcc += dt
	if boardAcc >= boardEvery then
		boardAcc = 0
		refreshBoard()
	end
	if not L.enabled then return end
	acc += dt
	if acc < tickEvery then return end
	acc = 0
	if still then
		if not wasStill then -- settle once, then leave everything alone
			wasStill = true
			for _, tex in crowd do tex.OffsetStudsV = 0 end
			for i, tip in flags do tip.Position = Vector3.new(0, flagY[i], -flagLen[i]) end
		end
		return
	end
	wasStill = false
	local t = os.clock()
	state.active = RaceState.active and RaceState.focus ~= nil
	state.burstShowing = RaceState.burstShowing == true
	state.resultsOpen = RaceState.resultsOpen == true
	local leader = RaceState.order[1]
	state.leaderProgress = if leader then RaceState.progress[leader] or 0 else 0
	local mode = TrackLifeView.crowdMode(state, L)
	for i, tex in crowd do
		tex.OffsetStudsV = TrackLifeView.crowdOffset(t, mode, L, crowdRow[i], false)
	end
	for i, tip in flags do
		local yaw = TrackLifeView.flagYaw(t, L, i, false)
		local len = flagLen[i]
		tip.Position = Vector3.new(len * math.sin(yaw), flagY[i], -len * math.cos(yaw)) -- (Vector3 is a value: no allocation)
	end
end)
