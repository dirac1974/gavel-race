--!nonstrict
-- FanClient (D-019, D-020, D-041): watching a race you're not riding in.
--   Cheer bar: the eight horses of the race you're watching; tap one before the first
--   checkpoint to cheer for it (free).
--   Clap Along: after cheering, a big 👏 button; clap when the ring pulses with the hoofbeat.
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

-- Cheer bar --------------------------------------------------------------------------
local bar = Ui.card(gui, UDim2.fromOffset(640, 96), UDim2.new(0.5, 0, 1, -168), C.paper) -- above the dock and pinned job
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Visible = false
local barScale = Instance.new("UIScale")
barScale.Parent = bar
local function rescale()
	local cam = workspace.CurrentCamera
	if cam then barScale.Scale = math.min(1, (cam.ViewportSize.X - 20) / 640) end
end
rescale()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
local barTitle = Ui.text(bar, "📣 Cheer for a horse!", 20, { Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, 0, 0, 24) })
local chips = Instance.new("Frame")
chips.BackgroundTransparency = 1
chips.Size = UDim2.new(1, -16, 0, 56)
chips.Position = UDim2.new(0, 8, 0, 32)
chips.Parent = bar
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
cl.Padding = UDim.new(0, 6)
cl.Parent = chips

-- Clap button and beat ring ---------------------------------------------------------------
local clap = Ui.button(gui, "👏 CLAP!", UDim2.fromOffset(170, 90), UDim2.new(1, -24, 1, -230), C.gold, 30) -- clear of the jump button
clap.AnchorPoint = Vector2.new(1, 1)
clap.Visible = false
local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromScale(1.3, 1.6)
ring.BackgroundTransparency = 1
ring.Parent = clap
Ui.corner(ring, 40)
local ringStroke = Ui.stroke(ring, 5, C.orange)
local clapLabel = Ui.text(gui, "", 26, { Size = UDim2.fromOffset(170, 34), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -326) })
clapLabel.TextColor3 = C.orangeDark
clapLabel.TextStrokeTransparency = 0.6

-- State ------------------------------------------------------------------------------
local watching = nil -- { course, lanes, cheered, beats, cheerOpen, finished }

local function showChips(laneList)
	for _, ch in chips:GetChildren() do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	for i, lane in laneList do
		local b = Ui.button(chips, "", UDim2.fromOffset(72, 54), UDim2.new(), LANE[i], 14)
		Ui.text(b, tostring(i), 22, { Size = UDim2.new(1, 0, 0, 24), TextColor3 = if i == 3 or i == 2 or i == 6 then C.ink else C.white })
		local name = Ui.text(b, lane.name, 11, { Position = UDim2.new(0, 2, 0, 26), Size = UDim2.new(1, -4, 0, 26) })
		name.TextColor3 = if i == 3 or i == 2 or i == 6 then C.ink else C.white
		b.Activated:Connect(function()
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
			bar.Visible, clap.Visible = false, false
			return
		end
	end
	if not RaceState.consider(courseId, laneList, start) then return end
	watching = { course = courseId, lanes = laneList, cheered = nil, beats = nil, cheerOpen = true, finished = false }
	barTitle.Text = "📣 Cheer for a horse!"
	showChips(laneList)
	bar.Visible = true
	clap.Visible = false
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
		bar.Size = UDim2.fromOffset(640, 40)
		clap.Visible = true
	end
end)

remotes.LiveChances.OnClientEvent:Connect(function(seg, _live, courseId)
	if watching and watching.course == courseId and seg == 1 then
		watching.cheerOpen = false
		if not watching.cheered then bar.Visible = false end
	end
end)

remotes.RaceFinished.OnClientEvent:Connect(function(_summary, courseId)
	if watching and watching.course == courseId then
		watching.finished = true
		task.delay(3, function()
			if watching and watching.finished then
				bar.Visible, clap.Visible = false, false
				bar.Size = UDim2.fromOffset(640, 96)
			end
		end)
	end
end)
remotes:WaitForChild("RaceAborted").OnClientEvent:Connect(function(courseId)
	if watching and watching.course == courseId then
		watching = nil
		bar.Visible, clap.Visible = false, false
		bar.Size = UDim2.fromOffset(640, 96)
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
	if not watching or not watching.cheered or watching.finished then return end
	local t = serverNow()
	remotes:WaitForChild("ClapTap"):FireServer(watching.course, t)
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

RunService.RenderStepped:Connect(function()
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

remotes:WaitForChild("TopFans").OnClientEvent:Connect(function(courseId, board, rank, xp, level, levelUp)
	if board then
		if not (watching and watching.course == courseId) then return end
		for k, r in rows do
			local e = board[k]
			r.Text = if e then string.format("%d. %s 📣 %s · %d", k, e.name, e.horse, e.score) else ""
		end
		mine.Text, xpLine.Text = "", ""
		panelTitle.Text = "⭐ Top Fans"
		panel.Visible = true
		hideAt = os.clock() + 9
	else
		-- Your own line: rank (if you clapped) and Fan XP.
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
