--!nonstrict
-- FanClient (D-019, D-020, D-041): watching a race you're not riding in.
--   Cheer strip: the eight horses of the race you're watching, in a quiet strip at the top
--   centre (D-056); tap one before the first checkpoint to cheer for it (free).
--   Clap Along: after cheering, a big 👏 button left of the movement buttons; clap when the ring
--   pulses with the hoofbeat.
--   Only for races you watch from the course, and never while you're busy (D-055).
--   Your own claps show Perfect / Great / Good; nothing about other fans is shown live.
--   Top Fans: after the race, its best five fans (separate from the results), your own rank
--   and the Fan XP you earned.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
local C = Ui.colors
local LANE = {
	Color3.fromHex("D55E00"), Color3.fromHex("56B4E9"), Color3.fromHex("F0E442"), Color3.fromHex("009E73"),
	Color3.fromHex("CC79A7"), Color3.fromHex("E69F00"), Color3.fromHex("0072B2"), Color3.fromHex("3A3F4B"),
}
local myId = tostring(Players.LocalPlayer.UserId)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local gui = Ui.screen("Fans", 6)
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local FANS = GameConfig.fans
local CLAP_AT = UDim2.new(1, FANS.clapOffset[1], 1, FANS.clapOffset[2])

-- Cheer strip ------------------------------------------------------------------------
-- A quiet strip at the top centre, under the status line (D-056): 56 px, chips at least 48 px.
local STRIP_W, STRIP_H, LINE_H = 560, 56, 40
local bar = Ui.card(gui, UDim2.fromOffset(STRIP_W, STRIP_H), UDim2.new(0.5, 0, 0, 84), C.paper)
bar.AnchorPoint = Vector2.new(0.5, 0)
if not FANS.cheerStripTop then -- the D-019 spot, above the dock
	bar.Size = UDim2.fromOffset(640, 96)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -168)
end
bar.Visible = false
local barScale = Instance.new("UIScale")
barScale.Parent = bar
local function rescale()
	local cam = workspace.CurrentCamera
	if cam then barScale.Scale = math.min(1, (cam.ViewportSize.X - 20) / bar.Size.X.Offset) end
end
rescale()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
local barTitle = Ui.text(bar, "📣 Cheer!", 16, { Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(0, 72, 1, 0) })
barTitle.TextWrapped = true
local chips = Instance.new("Frame")
chips.BackgroundTransparency = 1
chips.Size = UDim2.new(1, -88, 1, -8)
chips.Position = UDim2.new(0, 84, 0, 4)
chips.Parent = bar
if not FANS.cheerStripTop then
	barTitle.Text = "📣 Cheer for a horse!"
	barTitle.Size, barTitle.Position = UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 4)
	chips.Size, chips.Position = UDim2.new(1, -16, 0, 56), UDim2.new(0, 8, 0, 32)
end
local function stripSize(cheered: boolean)
	if not FANS.cheerStripTop then
		bar.Size = UDim2.fromOffset(640, if cheered then 40 else 96)
	else
		bar.Size = UDim2.fromOffset(STRIP_W, if cheered then LINE_H else STRIP_H)
		barTitle.Size = if cheered then UDim2.new(1, -16, 1, 0) else UDim2.new(0, 72, 1, 0)
	end
end
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
cl.Padding = UDim.new(0, 6)
cl.Parent = chips

-- Clap button and beat ring ---------------------------------------------------------------
local clap = Ui.button(gui, "👏 CLAP!", UDim2.fromOffset(FANS.clapSizeOnFoot[1], FANS.clapSizeOnFoot[2]), CLAP_AT, C.gold, 30)
clap.AnchorPoint = Vector2.new(1, 1) -- one column left of Gallop and Hop (D-056)
clap.Visible = false
clap:SetAttribute("NoPop", true) -- it claps instead
local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromScale(1.3, 1.6)
ring.BackgroundTransparency = 1
ring.Parent = clap
Ui.corner(ring, 40)
local ringStroke = Ui.stroke(ring, 5, C.orange)
local clapLabel = Ui.text(gui, "", 26, { Size = UDim2.fromOffset(170, 34), AnchorPoint = Vector2.new(1, 1),
	Position = CLAP_AT + UDim2.fromOffset(0, -96) })
clapLabel.TextColor3 = C.orangeDark
clapLabel.TextStrokeTransparency = 0.6

-- State ------------------------------------------------------------------------------
local watching = nil -- { course, lanes, cheered, beats, cheerOpen, finished }
-- What the strip and CLAP would show; RenderStepped hides them while you're busy or out of
-- range (RaceState.watchHidden, D-055).
local barOn, clapOn = false, false
local function setShown(barWanted: boolean, clapWanted: boolean)
	barOn, clapOn = barWanted, clapWanted
	bar.Visible = barOn and not RaceState.watchHidden
	clap.Visible = clapOn and not RaceState.watchHidden
end
local function share()
	RaceState.cheeredLane = watching and watching.cheered or nil
	RaceState.cheerOpen = watching ~= nil and watching.cheerOpen and not watching.cheered and barOn
end

local function showChips(laneList)
	for _, ch in chips:GetChildren() do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	for i, lane in laneList do
		local w, h = if FANS.cheerStripTop then 52 else 72, if FANS.cheerStripTop then 46 else 54
		local b = Ui.button(chips, "", UDim2.fromOffset(w, h), UDim2.new(), if lane.isBot then C.shade else LANE[i], 14)
		Ui.text(b, tostring(i), 20, { Size = UDim2.new(1, 0, 0, h * 0.42), TextColor3 = if i == 3 or i == 2 or i == 6 then C.ink else C.white })
		local name = Ui.text(b, lane.name, 11, { Position = UDim2.new(0, 2, 0, h * 0.42), Size = UDim2.new(1, -4, 0, h * 0.55) })
		name.TextColor3 = if i == 3 or i == 2 or i == 6 then C.ink else C.white
		b.Activated:Connect(function()
			if lane.isBot then
				Ui.toast("Cheer for a rider! Practice horses don't have fans.", "job_cheer", "📣")
				return
			end
			if watching and watching.cheerOpen and not watching.cheered then
				remotes:WaitForChild("Cheer"):FireServer(watching.course, i)
			end
		end)
	end
end

remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList, start, _cond, _resultAt, _burstOpen, courseId)
	courseId = courseId or "dirt"
	for _, lane in laneList do
		if lane.id == myId then
			watching = nil -- riding: no cheering in your own race
			setShown(false, false)
			share()
			return
		end
	end
	if not RaceState.consider(courseId, laneList, start) then return end
	if watching and watching.cheered and not watching.finished then return end -- keep clapping for your horse
	local anyRider = false
	for _, lane in laneList do
		if not lane.isBot then anyRider = true end
	end
	if not anyRider then return end -- nothing to cheer in an all-bot race
	watching = { course = courseId, lanes = laneList, cheered = nil, beats = nil, cheerOpen = true, finished = false }
	stripSize(false)
	barTitle.Text = if FANS.cheerStripTop then "📣 Cheer!" else "📣 Cheer for a horse!"
	showChips(laneList)
	setShown(true, false)
	share()
end)

remotes:WaitForChild("ClapBeats").OnClientEvent:Connect(function(courseId, beats)
	if watching and watching.course == courseId then watching.beats = beats end
end)

remotes:WaitForChild("FanStatus").OnClientEvent:Connect(function(courseId, lane, message)
	if message then Ui.toast(message, "job_cheer", "📣") end
	if watching and watching.course == courseId and lane then
		watching.cheered = lane
		barTitle.Text = string.format("📣 Your horse: %d · %s", lane, watching.lanes[lane] and watching.lanes[lane].name or "")
		for _, ch in chips:GetChildren() do if ch:IsA("TextButton") then ch.Visible = false end end
		stripSize(true)
		setShown(true, true)
		share()
	end
end)

remotes.LiveChances.OnClientEvent:Connect(function(seg, _live, courseId)
	if watching and watching.course == courseId and seg == 1 then
		watching.cheerOpen = false
		if not watching.cheered then setShown(false, clapOn) end
		share()
	end
end)

remotes.RaceFinished.OnClientEvent:Connect(function(_summary, courseId)
	if watching and watching.course == courseId then
		watching.finished = true
		task.delay(3, function()
			if watching and watching.finished then
				setShown(false, false)
				stripSize(false)
				share()
			end
		end)
	end
end)
remotes:WaitForChild("RaceAborted").OnClientEvent:Connect(function(courseId)
	if watching and watching.course == courseId then
		watching = nil
		setShown(false, false)
		stripSize(false)
		share()
	end
end)

-- Clapping: tap the button (or press C) when the ring pulses.
local function nearestBeat(t: number): number?
	if not watching or not watching.beats then return nil end
	local best, err = nil, math.huge
	for _, b in watching.beats do
		local e = math.abs(t - b)
		if e < err then best, err = b, e end
		if b > t + 1 then break end
	end
	return best
end

local function doClap()
	if not watching or not watching.cheered or watching.finished or not clap.Visible then return end
	local t = serverNow()
	remotes:WaitForChild("ClapTap"):FireServer(watching.course, t)
	if Sound then Sound.play("clap") end
	local b = nearestBeat(t)
	local err = if b then math.abs(t - b) else 1
	local label = if err <= 0.02 then "Perfect!" elseif err <= 0.045 then "Great!" elseif err <= 0.08 then "Good" else "Keep the beat"
	clapLabel.Text = label
	clapLabel.TextTransparency = 0
	TweenService:Create(clapLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	Ui.pop(clap)
end
clap.MouseButton1Down:Connect(doClap)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.C then doClap() end
end)

-- CLAP is smaller while you sit on your own horse (D-056).
local function onHorse(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end
RunService.RenderStepped:Connect(function()
	bar.Visible = barOn and not RaceState.watchHidden
	clap.Visible = clapOn and not RaceState.watchHidden
	local size = if onHorse() then FANS.clapSizeRiding else FANS.clapSizeOnFoot
	if clap.Size.X.Offset ~= size[1] then clap.Size = UDim2.fromOffset(size[1], size[2]) end
	if not clap.Visible or not watching or not watching.beats then return end
	local t = serverNow()
	local pulse = 0
	for _, b in watching.beats do
		local d = t - b
		if d >= -0.05 and d < 0.2 then pulse = math.max(pulse, 1 - math.abs(d) / 0.2) end
		if b > t + 1 then break end
	end
	ringStroke.Transparency = 1 - pulse
	ring.Size = UDim2.fromScale(1.3 + 0.2 * pulse, 1.6 + 0.2 * pulse)
end)

-- Top Fans --------------------------------------------------------------------------------
local panel = Ui.card(gui, UDim2.fromOffset(360, 260), UDim2.new(0, 16, 0.5, 0), C.paper)
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Visible = false
local panelTitle = Ui.text(panel, "⭐ Top Fans", 26, { Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 30) })
local rows = {}
for k = 1, 5 do
	local r = Ui.text(panel, "", 18, { Position = UDim2.new(0, 16, 0, 42 + (k - 1) * 30), Size = UDim2.new(1, -32, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
	r.TextTruncate = Enum.TextTruncate.AtEnd
	rows[k] = r
end
local mine = Ui.text(panel, "", 18, { Position = UDim2.new(0, 16, 1, -62), Size = UDim2.new(1, -32, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
mine.TextColor3 = C.orangeDark
local xpLine = Ui.text(panel, "", 16, { Position = UDim2.new(0, 16, 1, -34), Size = UDim2.new(1, -32, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
xpLine.TextColor3 = C.plum
local hideAt = 0
local boardCourse = nil

remotes:WaitForChild("TopFans").OnClientEvent:Connect(function(courseId, board, rank, xp, level, levelUp)
	if board then
		if not (watching and watching.course == courseId) then return end
		boardCourse = courseId
		for k, r in rows do
			local e = board[k]
			r.Text = if e then string.format("%d. %s 📣 %s · %d", k, e.name, e.horse, e.score) else ""
		end
		mine.Text, xpLine.Text = "", ""
		panelTitle.Text = "⭐ Top Fans"
		panel.Visible = true
		hideAt = os.clock() + 9
	else
		-- Your own line: rank (if you clapped) and Fan XP; a stale board from another race is cleared.
		if boardCourse ~= courseId then
			for _, r in rows do r.Text = "" end
			boardCourse = courseId
		end
		if not rank and not (xp and xp > 0) then return end
		mine.Text = if rank then string.format("You: #%d", rank) else ""
		if xp and xp > 0 then
			xpLine.Text = string.format("+%d Fan XP · Fan level %d", xp, level or 1)
			Ui.toast(string.format("+%d Fan XP%s", xp, if levelUp then string.format("! Fan level %d", level) else ""), "job_cheer", "📣")
		end
		panel.Visible = true
		hideAt = os.clock() + 9
	end
end)
RunService.Heartbeat:Connect(function()
	if panel.Visible and os.clock() > hideAt then panel.Visible = false end
end)
