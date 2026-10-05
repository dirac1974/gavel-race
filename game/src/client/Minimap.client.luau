--!nonstrict
-- Minimap (D-030): the oval in the top-right corner during a race, with a dot per horse in
-- its lane colour and number, your own dot larger with a white ring, and the finish line.
-- Drawn from TrackLayout, the same geometry the horses run on; positions come from
-- RaceState (RaceView writes them every frame).
-- Turned 90 degrees so it reads like a TV graphic: the homestretch runs left to right
-- along the bottom (the grandstand side), and the horses go round counter-clockwise.
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
local W, H, PAD = 300, 140, 12
local OUTLINE_POINTS = 90
local LANE_COLOURS = {
	Color3.fromHex("D55E00"), Color3.fromHex("56B4E9"), Color3.fromHex("F0E442"), Color3.fromHex("009E73"),
	Color3.fromHex("CC79A7"), Color3.fromHex("E69F00"), Color3.fromHex("0072B2"), Color3.fromHex("3A3F4B"),
}
local LIGHT_LANES = { [2] = true, [3] = true, [6] = true }

-- World extent of the oval (outer rail), mapped into the panel.
local R = TrackLayout.outerRadius(CFG)
local zMin, zMax = CFG.centerZ - CFG.straight / 2 - R, CFG.centerZ + CFG.straight / 2 + R
local xMin, xMax = CFG.centerX - R, CFG.centerX + R
local function toPanel(x: number, z: number): UDim2
	-- Screen x from world z (top of the stretch on the left), screen y from world x (home straight at the bottom).
	local u = (zMax - z) / (zMax - zMin)
	local v = (x - xMin) / (xMax - xMin)
	return UDim2.fromOffset(PAD + u * (W - 2 * PAD), PAD + v * (H - 2 * PAD))
end

local gui = Instance.new("ScreenGui")
gui.Name = "Minimap"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 50)
panel.Size = UDim2.fromOffset(W, H)
panel.BackgroundColor3 = Color3.fromHex("2E6B34") -- infield green
panel.BackgroundTransparency = 0.15
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = panel

-- Track outline: dots along the middle of the dirt, so it reads as the oval.
local rMid = CFG.railRadius + CFG.width / 2
local lap = TrackLayout.lapLength(CFG, rMid)
for k = 0, OUTLINE_POINTS - 1 do
	local x, z = TrackLayout.atDistance(CFG, rMid, lap * k / OUTLINE_POINTS)
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Size = UDim2.fromOffset(9, 9)
	d.Position = toPanel(x, z)
	d.BackgroundColor3 = Color3.fromHex("C68A52")
	d.BorderSizePixel = 0
	d.Parent = panel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = d
end

-- Finish line tick across the homestretch.
local fx0, fx1, fz = TrackLayout.finishLine(CFG)
local a, b = toPanel(fx0, fz), toPanel(fx1, fz)
local finish = Instance.new("Frame")
finish.AnchorPoint = Vector2.new(0.5, 0)
finish.Size = UDim2.fromOffset(3, b.Y.Offset - a.Y.Offset + 8)
finish.Position = UDim2.fromOffset(a.X.Offset, a.Y.Offset - 4)
finish.BackgroundColor3 = Color3.new(1, 1, 1)
finish.BorderSizePixel = 0
finish.ZIndex = 2
finish.Parent = panel

-- Horse dots.
local dots = {}
for i = 1, 8 do
	local dot = Instance.new("TextLabel")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(16, 16)
	dot.BackgroundColor3 = LANE_COLOURS[i]
	dot.Text = tostring(i)
	dot.Font = Enum.Font.GothamBlack
	dot.TextSize = 11
	dot.TextColor3 = if LIGHT_LANES[i] then Color3.fromHex("1F2430") else Color3.new(1, 1, 1)
	dot.ZIndex = 3
	dot.Visible = false
	dot.Parent = panel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = dot
	local ring = Instance.new("UIStroke")
	ring.Thickness = 0
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = dot
	dots[i] = { dot = dot, ring = ring }
end

local myLane = nil
remotes.RaceStarted.OnClientEvent:Connect(function(_league, laneList)
	myLane = nil
	for i, lane in laneList do
		if lane.id == myId then myLane = i end
	end
	for i, d in dots do
		local mine = i == myLane
		d.dot.Size = if mine then UDim2.fromOffset(22, 22) else UDim2.fromOffset(16, 16)
		d.ring.Thickness = if mine then 3 else 0
		d.dot.ZIndex = if mine then 5 else 3
	end
end)

RunService.RenderStepped:Connect(function()
	local plan = RaceState.plan
	gui.Enabled = RaceState.active and plan ~= nil
	if not gui.Enabled then return end
	for i, d in dots do
		local p = RaceState.progress[i]
		if p and i <= RaceState.lanes then
			local x, z = TrackLayout.lanePoint(CFG, plan, i, p)
			d.dot.Position = toPanel(x, z)
			d.dot.Visible = true
		else
			d.dot.Visible = false
		end
	end
end)
