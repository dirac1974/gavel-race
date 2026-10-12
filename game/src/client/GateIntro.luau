--!nonstrict
-- GateIntro (AAA Phase 4 Dev B, D-069, GameConfig.gateIntro): the gate line-up camera pass. It runs in
-- the countdown, never in the lobby wait (taking the camera then would pull kids out of grooming, D-061),
-- and the countdown stays at gateCountdownSeconds. As you're seated (start - 3) the camera dollies in front
-- of the gate from the outside lane to lane 1, heightStuds up, looking at the horses' faces, over
-- dollySeconds (eased); then a cut (handOff = "cut", the feel consult: the old blend flew through the
-- horses and whip-panned): a cutFadeSeconds Paper fade (clear, 0.4, clear) with the chase shot set at its
-- peak, and the Follow camera is back. handOff = "blend" is the switch-back (a blendSeconds glide behind
-- your horse). Either way the Follow camera is back by handBackBefore seconds before GO, so the chase view
-- is live before the first pass ("3, 2, 1" shows throughout). Riders only, never spectators, never under Reduced Motion; a late seat goes straight to
-- the chase view (RacePresent.gateRuns).
-- The camera always comes back: the pass stops and hands back the moment the race changes, you leave the
-- saddle, Reduced Motion turns on or anything else takes the camera, and a timer hands back regardless.
-- It never changes the field of view (RaceCamera owns that) or the camera subject.
-- Drawn only. STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RacePresent = require(Shared:WaitForChild("RacePresent"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local Cam = require(script.Parent:WaitForChild("RaceCamera"))

local CFG = GameConfig.gateIntro or { enabled = false }
local BIND = "GiddyUpGateIntro"
local UP = Vector3.new(0, 1, 0)

local Gate = { active = false }

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Reduced Motion, read once and on change (the render step reads it every frame: no closure per frame).
local stillNow = false
local function readStill()
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	stillNow = ok and on == true
end
readStill()
pcall(function() GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(readStill) end)

-- The cut's Paper fade, over everything but the results card.
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "GateFade"
fadeGui.ResetOnSpawn = false
fadeGui.IgnoreGuiInset = true
fadeGui.DisplayOrder = 1
fadeGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.fromHex("FFF7E6") -- Paper
fade.BackgroundTransparency = 1
fade.BorderSizePixel = 0
fade.Active = false
fade.Parent = fadeGui

local token = 0
local owned = false -- the camera is Scriptable because of us

local function stop()
	token += 1
	fade.BackgroundTransparency = 1
	Gate.active = false
	pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	local camera = workspace.CurrentCamera
	if owned and camera and camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = if Cam.on then Enum.CameraType.Follow else Enum.CameraType.Custom
	end
	owned = false
end
Gate.stop = stop

-- The gate's two ends and your horse: (outside lane's horse, lane 1's horse, yours), or nil.
local function horsesFor(courseId: string?, lane: number): (Model?, Model?, Model?)
	local track = RaceState.trackFolder(courseId)
	local horses = track and track:FindFirstChild("Horses")
	if not horses then return nil, nil, nil end
	local outer = nil
	for i = 12, 1, -1 do
		outer = horses:FindFirstChild("Lane" .. i)
		if outer then break end
	end
	return outer, horses:FindFirstChild("Lane1"), horses:FindFirstChild("Lane" .. lane)
end

-- In front of a horse's face, looking back at it.
local function faceShot(horse: Model): (Vector3, Vector3)
	local cf = horse:GetPivot()
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local ground = cf.Position
	return ground + look * (CFG.frontStuds or 16) + UP * (CFG.heightStuds or 7), ground + look * 3 + UP * 4
end

-- About where the Follow camera sits behind your horse.
local function chaseShot(horse: Model): (Vector3, Vector3)
	local cf = horse:GetPivot()
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local head = cf.Position + UP * 7
	return head - look * (CFG.chaseBackStuds or 14) + UP * (CFG.chaseUpStuds or 5), head + look * 4
end

-- Run the pass for your race starting (GO) at `start`, seated now in lane `lane`. `alive()` is false
-- once the HUD has moved on to another race or you're out of the saddle. Returns true if it runs.
function Gate.run(start: number, courseId: string?, lane: number, alive: () -> boolean): boolean
	stop()
	local now = serverNow()
	if not RacePresent.gateRuns(CFG, now, start, GameConfig.gateCountdownSeconds or 3, true, stillNow) then return false end
	local camera = workspace.CurrentCamera
	local outer, inner, mine = horsesFor(courseId, lane)
	if not (camera and outer and inner and mine and Cam.on) then return false end
	local fromEye, fromAt = faceShot(outer)
	local toEye, toAt = faceShot(inner)
	camera.CameraType = Enum.CameraType.Scriptable
	owned = true
	Gate.active = true
	local mineToken = token
	local blendEye, blendAt = nil, nil
	local cut = CFG.handOff ~= "blend"
	local cutAt: number? = nil
	local cutSeconds = CFG.cutFadeSeconds or 0.12
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if mineToken ~= token then return end
		local cam = workspace.CurrentCamera
		if not (cam and alive() and Cam.on and cam.CameraType == Enum.CameraType.Scriptable and not stillNow and mine.Parent) then
			stop()
			return
		end
		local phase, f = RacePresent.gateFrame(CFG, serverNow(), start)
		if phase == "dolly" then
			blendEye, blendAt = fromEye:Lerp(toEye, f), fromAt:Lerp(toAt, f)
			cam.CFrame = CFrame.lookAt(blendEye, blendAt)
		elseif cut then
			-- The cut: Paper fades up to its peak on the last dolly frame, the chase shot is set at the peak
			-- and the Follow camera takes over as the Paper fades back out.
			cutAt = cutAt or os.clock()
			local e = os.clock() - (cutAt :: number)
			fade.BackgroundTransparency = 1 - RacePresent.cutFade(e, cutSeconds)
			if e >= cutSeconds / 2 or phase == "done" then
				local cEye, cAt = chaseShot(mine)
				cam.CFrame = CFrame.lookAt(cEye, cAt)
				stop()
				fade.BackgroundTransparency = 1 - RacePresent.cutFade(cutSeconds / 2, cutSeconds)
				TweenService:Create(fade, TweenInfo.new(cutSeconds / 2), { BackgroundTransparency = 1 }):Play()
			end
		elseif phase == "done" then
			stop()
		else
			local cEye, cAt = chaseShot(mine)
			cam.CFrame = CFrame.lookAt((blendEye or toEye):Lerp(cEye, f), (blendAt or toAt):Lerp(cAt, f))
		end
	end)
	-- Whatever happens, the camera is back by the hand-back time.
	local _, _, handBack = RacePresent.gateTimes(CFG, start)
	task.delay(math.max(0, handBack - now) + 0.1, function()
		if mineToken == token then stop() end
	end)
	return true
end

return Gate
