--!nonstrict
-- Race map (D-030, D-032), top-right during a race. The design council's fix for the
-- overlapping dots: a race strip like a TV broadcast's running order.
--   Race strip: one row per lane, so dots never stack; zoomed to the field (leader near the
--   right edge, everyone spaced by their real gap) so gaps are readable; a checkered flag
--   slides in when the line is in range; a line of text gives your gap in horse lengths.
--   Lap map: a small, still oval showing only your own dot, to answer "where are we?".
-- Positions come from RaceState (RaceView writes them every frame).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackLayout = require(Shared:WaitForChild("TrackLayout"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")

local player = Players.LocalPlayer
local myId = tostring(player.UserId)
local CFG = TrackLayout.churchill
local HORSE_LENGTH = 8   -- feet (studs)
local MIN_WINDOW = 80    -- the strip always shows at least ~10 lengths
local LEADER_AT = 0.8    -- leader's place across the strip; the flag slides into the rest
local W, PAD = 320, 10
local ROW_H, DOT, MY_DOT = 13, 12, 18
local OVAL_W, OVAL_H = 120, 56
local LANE_COLOURS = {
	Color3.fromHex("D55E00"), Color3.fromHex("56B4E9"), Color3.fromHex("F0E442"), Color3.fromHex("009E73"),
	Color3.fromHex("CC79A7"), Color3.fromHex("E69F00"), Color3.fromHex("0072B2"), Color3.fromHex("3A3F4B"),
}
local LIGHT_LANES = { [2] = true, [3] = true, [6] = true }

local gui = Instance.new("ScreenGui")
gui.Name = "RaceMap"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local mapScale = Instance.new("UIScale") -- shrinks on phones with the rest of the race HUD (D-055)

local stripH = 8 * ROW_H
local panelH = PAD + OVAL_H + 6 + stripH + 22 + PAD
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, RaceState.MAP_TOP)
panel.Size = UDim2.fromOffset(W, panelH)
mapScale.Parent = panel
panel.BackgroundColor3 = Color3.fromHex("1F2A22")
panel.BackgroundTransparency = 0.2
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local function round(frame)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = frame
end

-- Lap map (small, still; only your dot moves round it) ---------------------------
local oval = Instance.new("Frame")
oval.Position = UDim2.fromOffset(PAD, PAD)
oval.Size = UDim2.fromOffset(OVAL_W, OVAL_H)
oval.BackgroundTransparency = 1
oval.Parent = panel
local R = TrackLayout.outerRadius(CFG)
local zMin, zMax = CFG.centerZ - CFG.straight / 2 - R, CFG.centerZ + CFG.straight / 2 + R
local xMin, xMax = CFG.centerX - R, CFG.centerX + R
local function toOval(x: number, z: number): UDim2
	-- homestretch along the bottom, top of the stretch on the left (like a TV graphic)
	local u = (zMax - z) / (zMax - zMin)
	local v = (x - xMin) / (xMax - xMin)
	return UDim2.fromOffset(4 + u * (OVAL_W - 8), 4 + v * (OVAL_H - 8))
end
local rMid = CFG.railRadius + CFG.width / 2
local lap = TrackLayout.lapLength(CFG, rMid)
for k = 0, 59 do
	local x, z = TrackLayout.atDistance(CFG, rMid, lap * k / 60)
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Size = UDim2.fromOffset(5, 5)
	d.Position = toOval(x, z)
	d.BackgroundColor3 = Color3.fromHex("C68A52")
	d.BorderSizePixel = 0
	d.Parent = oval
	round(d)
end
local fx0, _, fz = TrackLayout.finishLine(CFG)
local flagTick = Instance.new("Frame")
flagTick.AnchorPoint = Vector2.new(0.5, 0.5)
flagTick.Size = UDim2.fromOffset(3, 10)
flagTick.Position = toOval(fx0 + CFG.width / 2, fz)
flagTick.BackgroundColor3 = Color3.new(1, 1, 1)
flagTick.BorderSizePixel = 0
flagTick.Parent = oval
local myOvalDot = Instance.new("Frame")
myOvalDot.AnchorPoint = Vector2.new(0.5, 0.5)
myOvalDot.Size = UDim2.fromOffset(11, 11)
myOvalDot.BackgroundColor3 = Color3.fromHex("FFD34D")
myOvalDot.ZIndex = 3
myOvalDot.Visible = false
myOvalDot.Parent = oval
round(myOvalDot)
local ovalStroke = Instance.new("UIStroke")
ovalStroke.Thickness = 2
ovalStroke.Color = Color3.new(1, 1, 1)
ovalStroke.Parent = myOvalDot

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(PAD + OVAL_W + 8, PAD)
title.Size = UDim2.fromOffset(W - OVAL_W - 2 * PAD - 8, OVAL_H)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextWrapped = true
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = ""
title.Parent = panel

-- Race strip -----------------------------------------------------------------------
local strip = Instance.new("Frame")
strip.Position = UDim2.fromOffset(PAD, PAD + OVAL_H + 6)
strip.Size = UDim2.fromOffset(W - 2 * PAD, stripH)
strip.BackgroundTransparency = 1
strip.ClipsDescendants = true
strip.Parent = panel
local SW = W - 2 * PAD
local rows = {}
for i = 1, 8 do
	local line = Instance.new("Frame")
	line.Position = UDim2.fromOffset(0, (i - 0.5) * ROW_H - 1)
	line.Size = UDim2.new(1, 0, 0, 2)
	line.BackgroundColor3 = LANE_COLOURS[i]
	line.BackgroundTransparency = 0.7
	line.BorderSizePixel = 0
	line.Parent = strip
	local dot = Instance.new("TextLabel")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(DOT, DOT)
	dot.Position = UDim2.fromOffset(0, (i - 0.5) * ROW_H)
	dot.BackgroundColor3 = LANE_COLOURS[i]
	dot.Text = tostring(i)
	dot.Font = Enum.Font.GothamBlack
	dot.TextSize = 9
	dot.TextColor3 = if LIGHT_LANES[i] then Color3.fromHex("1F2430") else Color3.new(1, 1, 1)
	dot.ZIndex = 3
	dot.Parent = strip
	round(dot)
	local ring = Instance.new("UIStroke")
	ring.Thickness = 0
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = dot
	rows[i] = { dot = dot, ring = ring, line = line }
end
local flag = Instance.new("Frame") -- checkered finish line across all rows
flag.AnchorPoint = Vector2.new(0.5, 0)
flag.Size = UDim2.fromOffset(6, stripH)
flag.BackgroundColor3 = Color3.new(1, 1, 1)
flag.ZIndex = 2
flag.Visible = false
flag.Parent = strip
for k = 0, 7 do
	local sq = Instance.new("Frame")
	sq.Size = UDim2.fromOffset(3, ROW_H / 2)
	sq.Position = UDim2.fromOffset(if k % 2 == 0 then 0 else 3, k * ROW_H + (if k % 2 == 0 then 0 else ROW_H / 2))
	sq.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
	sq.BorderSizePixel = 0
	sq.ZIndex = 2
	sq.Parent = flag
end

local gapText = Instance.new("TextLabel")
gapText.Position = UDim2.fromOffset(PAD, PAD + OVAL_H + 6 + stripH + 2)
gapText.Size = UDim2.fromOffset(W - 2 * PAD, 20)
gapText.BackgroundTransparency = 1
gapText.Font = Enum.Font.GothamBold
gapText.TextSize = 15
gapText.TextColor3 = Color3.fromHex("FFD34D")
gapText.Text = ""
gapText.Parent = panel

local myLane = nil
local window = MIN_WINDOW
remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList, start, _cond, _resultAt, _burstOpen, courseId)
	if not RaceState.consider(courseId or "dirt", laneList, start) then return end
	myLane = nil
	window = MIN_WINDOW
	for i, lane in laneList do
		if lane.id == myId then myLane = i end
	end
	for i, r in rows do
		local mine = i == myLane
		r.dot.Size = if mine then UDim2.fromOffset(MY_DOT, MY_DOT) else UDim2.fromOffset(DOT, DOT)
		r.dot.TextSize = if mine then 12 else 9
		r.ring.Thickness = if mine then 2 else 0
		r.dot.ZIndex = if mine then 5 else 3
		r.line.BackgroundTransparency = if mine then 0.4 else 0.7
	end
end)

local function lengths(feet: number): string
	local n = math.floor(feet / HORSE_LENGTH * 2 + 0.5) / 2
	if n < 0.5 then return "a nose" end
	return string.format("%g length%s", n, if n == 1 then "" else "s")
end

RunService.RenderStepped:Connect(function(dt)
	local plan = RaceState.plan
	-- Steps aside for the Final Burst, while a spectator is busy or out of range, and on a phone
	-- while the cheer strip is open (D-055).
	gui.Enabled = RaceState.active and plan ~= nil and not RaceState.burstShowing and not RaceState.watchHidden
		and not (RaceState.cheerOpen and RaceState.phone())
	if not gui.Enabled then return end
	mapScale.Scale = RaceState.hudScale()
	local n = math.min(RaceState.lanes, 8)
	-- Distance covered and to go, in feet, per lane.
	local covered, togo = {}, {}
	local lead, last = -math.huge, math.huge
	for i = 1, n do
		local p = RaceState.progress[i] or 0
		covered[i] = p * plan.lengths[1] -- progress is timed on lane 1 for every lane (D-055)
		togo[i] = math.max(0, plan.lengths[1] - covered[i])
		lead, last = math.max(lead, covered[i]), math.min(last, covered[i])
	end
	if lead == -math.huge then return end
	-- Zoom to the field, easing so the scale doesn't jump.
	local want = math.max(MIN_WINDOW, (lead - last) * 1.1)
	window += (want - window) * math.min(1, dt * 2)
	local scale = LEADER_AT * SW / window
	for i = 1, 8 do
		local r = rows[i]
		r.dot.Visible = i <= n
		r.line.Visible = i <= n
		if i <= n then
			local x = LEADER_AT * SW - (lead - covered[i]) * scale
			r.dot.Position = UDim2.fromOffset(math.max(r.dot.Size.X.Offset / 2, x), (i - 0.5) * ROW_H)
		end
	end
	-- The finish slides in once it's within the strip.
	local leaderLane = RaceState.order[1]
	local toLine = leaderLane and togo[leaderLane] or math.huge
	local fx = LEADER_AT * SW + toLine * scale
	flag.Visible = fx <= SW - 3
	flag.Position = UDim2.fromOffset(fx, 0)
	-- Your gap, in horse lengths, and where you are on the lap.
	if myLane and myLane <= n then
		local myPlace = RaceState.place[myLane]
		if myPlace == 1 then
			local second = RaceState.order[2]
			gapText.Text = second and ("Leading by " .. lengths(covered[myLane] - covered[second])) or "Leading"
		else
			gapText.Text = lengths(lead - covered[myLane]) .. " behind the leader"
		end
		local x, z = TrackLayout.lanePoint(TrackLayout.courses[RaceState.course or "dirt"] or CFG, plan, myLane, RaceState.progress[myLane] or 0)
		myOvalDot.Position = toOval(x, z)
		myOvalDot.Visible = true
		title.Text = if togo[myLane] < CFG.finishFromTop then "Homestretch!" else string.format("%d ft to go", math.floor(togo[myLane] / 10 + 0.5) * 10)
	else
		gapText.Text = ""
		myOvalDot.Visible = false
		title.Text = ""
	end
end)
