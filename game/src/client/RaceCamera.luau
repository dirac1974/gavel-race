--!nonstrict
-- RaceCamera: the riding camera and its kicks, moved out of RaceController (AAA Phase 2, D-067:
-- RaceController was near Luau's 200 top-level locals).
-- Riding camera (D-026, amended): a close chase view from just behind and above the rider, a little
-- wider than normal so nearby horses are in view, turning with the horse round the bends (Follow
-- camera). Scroll or pinch in for first person, or out for more.
-- Camera kicks (D-066): this module is their one owner. Each widens the riding view a little and
-- eases back; together they never pass raceFx.fovMaxDeg. A Perfect pace tap kicks at most once
-- every perfectFovEverySeconds; the Final Burst's kick is the big one. Only in the saddle camera,
-- and none under Reduced Motion. The view goes back to RIDE_FOV exactly when the last kick ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RaceFx = require(Shared:WaitForChild("RaceFx"))

local player = Players.LocalPlayer
local FX = GameConfig.raceFx
local DEFAULT_MAX_ZOOM = 128
local RIDE_ZOOM = 14

local Cam = {
	RIDE_FOV = 80,
	NORMAL_FOV = 70,
	on = false, -- the riding camera is on
}

local still = false
local function readStill()
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	still = ok and on == true
end
readStill()
pcall(function() GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(readStill) end)

function Cam.ride(on: boolean)
	local camera = workspace.CurrentCamera
	Cam.on = on
	if on then
		if camera then
			camera.CameraType = Enum.CameraType.Follow
			camera.FieldOfView = Cam.RIDE_FOV
		end
		player.CameraMinZoomDistance = RIDE_ZOOM
		player.CameraMaxZoomDistance = RIDE_ZOOM -- snaps the camera to the chase distance
		task.delay(0.2, function()
			player.CameraMinZoomDistance = 0.5 -- then allow zooming in to first person
			player.CameraMaxZoomDistance = 40
		end)
	else
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = Cam.NORMAL_FOV
		end
		player.CameraMaxZoomDistance = DEFAULT_MAX_ZOOM
		player.CameraMinZoomDistance = 0.5
	end
end

local kicks: { { at: number, deg: number, fall: number } } = {}
local lastPerfect = -math.huge
function Cam.kick(deg: number, fall: number)
	if not FX.enabled or deg <= 0 or not Cam.on or still then return end
	table.insert(kicks, { at = os.clock(), deg = deg, fall = fall })
end
-- A Perfect pace tap's kick, rate-limited (RaceFx.canKickPerfect).
function Cam.kickPerfect()
	if RaceFx.canKickPerfect(lastPerfect, os.clock(), FX) then
		lastPerfect = os.clock()
		Cam.kick(FX.perfectFovDeg, FX.fovFallSeconds)
	end
end
function Cam.clearKicks()
	table.clear(kicks)
end
RunService.RenderStepped:Connect(function()
	if #kicks == 0 then return end
	local camera = workspace.CurrentCamera
	if not Cam.on or not camera or still then
		table.clear(kicks)
		if Cam.on and camera then camera.FieldOfView = Cam.RIDE_FOV end
		return
	end
	camera.FieldOfView = Cam.RIDE_FOV + RaceFx.fov(kicks, os.clock(), FX)
end)

return Cam
