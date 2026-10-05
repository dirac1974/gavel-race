--!nonstrict
-- TrackScene: a simple race presentation for the playtest (D-023 art).
-- Builds a straight dirt track in front of the spawn: eight starting stalls, white rails,
-- a finish post and line, and one horse per lane (uploaded models from
-- ReplicatedStorage.RaceModels, or block placeholders until they load). During a race
-- the horses move up the track after each segment, spaced by live win chance, then run
-- to the line in the drawn finish order. Lane badges float over each horse; each client
-- adds its own YOU marker.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TrackScene = {}

local LANES = 8
local LANE_WIDTH = 6
local START_Z = -30          -- gate line, in front of the default spawn
local TRACK_LENGTH = 200
local FINISH_Z = START_Z - TRACK_LENGTH
local COATS = { "bay", "chestnut", "grey", "black", "palomino", "bay", "chestnut", "grey" }
-- Lane colours from docs/art/ART_DIRECTION.md (colour-blind-safe set, with numbers).
local LANE_COLOURS = {
	Color3.fromHex("D55E00"), Color3.fromHex("56B4E9"), Color3.fromHex("F0E442"), Color3.fromHex("009E73"),
	Color3.fromHex("CC79A7"), Color3.fromHex("E69F00"), Color3.fromHex("0072B2"), Color3.fromHex("3A3F4B"),
}

local LIGHT_LANES = { [2] = true, [3] = true, [6] = true } -- dark numbers read better on these
local UiAtlas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiAtlas"))

local root: Folder? = nil
local horses: { Model } = {}

local function laneX(i: number): number
	return (i - (LANES + 1) / 2) * LANE_WIDTH
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	return p
end

local function modelFor(slot: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("RaceModels")
	local m = folder and folder:FindFirstChild(slot)
	return if m then m:Clone() else nil
end

local function placeholderHorse(i: number): Model
	local m = Instance.new("Model")
	local body = part({ Size = Vector3.new(1.8, 3.5, 7), Color = Color3.fromRGB(120, 72, 40), CanCollide = false, Name = "Body" })
	body.CFrame = CFrame.new(0, 3.5, 0)
	body.Parent = m
	local head = part({ Size = Vector3.new(1.4, 1.6, 2.4), Color = Color3.fromRGB(110, 66, 36), CanCollide = false, Name = "Head" })
	head.CFrame = CFrame.new(0, 5.6, -4)
	head.Parent = m
	m.WorldPivot = CFrame.new(0, 0, 0)
	m.Name = "Placeholder" .. i
	return m
end

local function badge(i: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "LaneBadge"
	gui.Size = UDim2.fromOffset(44, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
	gui.AlwaysOnTop = true
	local rect = UiAtlas["lane_" .. i]
	local imageId = rect and ReplicatedStorage:GetAttribute("UiSheet_" .. rect.sheet)
	if imageId then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = "rbxassetid://" .. imageId
		img.ImageRectOffset = Vector2.new(rect.x, rect.y)
		img.ImageRectSize = Vector2.new(rect.w, rect.h)
		img.Parent = gui
		return gui
	end
	local chip = Instance.new("TextLabel")
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = LANE_COLOURS[i]
	chip.Text = tostring(i)
	chip.Font = Enum.Font.GothamBlack
	chip.TextScaled = true
	chip.TextColor3 = if LIGHT_LANES[i] then Color3.fromHex("1F2430") else Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = chip
	chip.Parent = gui
	return gui
end

function TrackScene.build()
	if root then root:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "RaceTrack"
	local width = LANES * LANE_WIDTH + 8
	part({ Name = "Dirt", Size = Vector3.new(width, 1, TRACK_LENGTH + 40), Color = Color3.fromHex("C68A52"),
		Material = Enum.Material.Ground, CFrame = CFrame.new(0, -0.45, START_Z - TRACK_LENGTH / 2 + 10) }).Parent = folder
	for _, side in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(0.6, 0.6, TRACK_LENGTH + 30), Color = Color3.fromHex("FBFBF5"),
			CFrame = CFrame.new(side * width / 2, 3, START_Z - TRACK_LENGTH / 2 + 5) }).Parent = folder
	end
	-- Checkered finish line from parts (bold checks; the finish post model sits beside it).
	for k = 0, math.floor(width / 2) - 1 do
		for row = 0, 1 do
			part({ Name = "Finish", Size = Vector3.new(2, 0.05, 2), CanCollide = false,
				Color = if (k + row) % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(28, 31, 38),
				CFrame = CFrame.new(-width / 2 + 1 + k * 2, 0.08, FINISH_Z - row * 2) }).Parent = folder
		end
	end
	local post = modelFor("finish_post")
	if post then
		post:PivotTo(CFrame.new(width / 2 + 3, 0, FINISH_Z))
		post.Parent = folder
	end
	for i = 1, LANES do
		local stall = modelFor("gate_stall")
		if stall then
			stall:PivotTo(CFrame.new(laneX(i), 0, START_Z + 2))
			stall.Parent = folder
		end
	end
	local horseFolder = Instance.new("Folder")
	horseFolder.Name = "Horses"
	horseFolder.Parent = folder
	horses = {}
	for i = 1, LANES do
		local horse = modelFor("horse_" .. COATS[i]) or placeholderHorse(i)
		horse.Name = "Lane" .. i
		horse:PivotTo(CFrame.new(laneX(i), 0, START_Z))
		badge(i).Parent = horse
		horse.Parent = horseFolder
		horses[i] = horse
	end
	folder.Parent = workspace
	root = folder
end

-- Move every horse to its progress (0 = gate, 1 = finish line) over `seconds`.
function TrackScene.moveTo(progress: { number }, seconds: number)
	for i, horse in horses do
		local p = math.clamp(progress[i] or 0, 0, 1.08)
		local target = CFrame.new(laneX(i), 0, START_Z - p * TRACK_LENGTH)
		-- Tween a CFrameValue and pivot the model with it (models can't be tweened directly).
		local cv = Instance.new("CFrameValue")
		cv.Value = horse:GetPivot()
		cv.Changed:Connect(function(v) if horse.Parent then horse:PivotTo(v) end end)
		local tween = TweenService:Create(cv, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = target })
		tween.Completed:Connect(function() cv:Destroy() end)
		tween:Play()
	end
end

-- After segment `seg` of `segments`: everyone moves up; the likelier winners lead a little.
function TrackScene.afterSegment(seg: number, segments: number, live: { number }, seconds: number)
	local progress = {}
	local base = 0.85 * seg / segments
	for i = 1, #horses do
		progress[i] = base + 0.6 * ((live[i] or 0) - 1 / #horses) * (seg / segments)
	end
	TrackScene.moveTo(progress, seconds)
end

-- Run to the line in finish order (order = lane indices, 1st to last).
function TrackScene.finish(order: { number }, seconds: number)
	local progress = {}
	for place, laneIdx in order do
		progress[laneIdx] = 1.06 - (place - 1) * 0.035
	end
	TrackScene.moveTo(progress, seconds)
end

function TrackScene.reset()
	local progress = {}
	for i = 1, #horses do progress[i] = 0 end
	TrackScene.moveTo(progress, 0.01)
end

return TrackScene
