--!nonstrict
-- ClassUp (fun-and-return phase 2, D-076): the class-up ceremony at the Rosette Wall.
--   When a horse's class path step rises (🚀 Rising Star, 🎽 Open, 💐 Top Horse, 🏆 Cup open), the next time
--   you're within classUp.nearStuds of your own Rosette Wall, and not racing, in line or on the results
--   card, the wall bursts with sparkles, tap_good then clap x classUp.claps play (the SoundSheet), and one
--   line shows ("🚀 Comet is a Rising Star!"), for at most classUp.seconds. Any tap skips it. It never
--   touches the results card or Race again. Reduced Motion: the line and the sounds, no sparkles.
--   Steps known when you join never play (only rises seen this session).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local ClassPath = require(Shared:WaitForChild("ClassPath"))

local CFG = GameConfig.classUp or {}
local player = Players.LocalPlayer
local seen: { [string]: number } = {}
local queue: { { name: string, step: string } } = {}
local primed = false

local function calm(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

-- Rises seen in the profile: queue a ceremony per rise (the first snapshot only primes).
PlayerState.watch(function(data)
	if not data or CFG.enabled == false then return end
	for _, h in data.horses or {} do
		local path = h.classPath
		if path and not h.legend then
			local key = h.id .. ":" .. tostring(h.league) -- (S1) a move up starts a new path, not a fall
			local before = seen[key]
			if primed and ClassPath.rose(before, path.at) then
				table.insert(queue, { name = h.name, step = path.step })
			end
			seen[key] = path.at
		end
	end
	primed = true
end)

local function wallPoint(): Vector3?
	local i = player:GetAttribute("PlotIndex")
	if not i then return nil end
	local x, z = WorldLayout.plotPoint(i, 52, 12) -- the Rosette Wall (StableService; GoTo's "wall")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return Vector3.new(x, (if hit then hit.Position.Y else 0) + 6, z)
end

local function busy(): boolean
	return player:GetAttribute("Racing") == true or player:GetAttribute("InLine") == true
		or RaceState.resultsOpen == true or (RaceState.active and RaceState.myLane ~= nil)
end

local gui = Ui.screen("ClassUp", 13)
gui.Enabled = false
local banner = Ui.button(gui, "", UDim2.fromOffset(460, 72), UDim2.new(0.5, -230, 0.22, 0), Ui.colors.gold, 26)
banner.TextWrapped = true
local playing = false

local function play(item)
	playing = true
	local at = wallPoint()
	local part = nil
	if at and not calm() then
		part = Instance.new("Part")
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.CFrame = CFrame.new(at)
		part.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(4, 9)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		e.LightEmission = 1
		e.Color = ColorSequence.new(Color3.fromHex("FFD23F"), Color3.fromHex("FFF6C2"))
		e.Parent = part
		e:Emit(CFG.sparkles or 40)
	end
	banner.Text = ClassPath.ceremonyLine(item.name, item.step)
	gui.Enabled = true
	Ui.pop(banner)
	local token = {}
	local current = token
	local function finish()
		if current ~= token then return end
		current = nil
		gui.Enabled = false
		if part then part:Destroy() end
		playing = false
	end
	if Sound then
		Sound.play(CFG.sound or "tap_good")
		for k = 1, CFG.claps or 3 do
			task.delay(0.25 + 0.15 * k, function() if current == token and Sound then Sound.play(CFG.clap or "clap", 0.6) end end)
		end
	end
	local conn = banner.Activated:Connect(finish)
	local input = UserInputService.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch
			or io.KeyCode == Enum.KeyCode.Space or io.KeyCode == Enum.KeyCode.ButtonA then
			task.defer(finish) -- any tap skips
		end
	end)
	task.delay(math.min(4, CFG.seconds or 3.5), finish)
	task.spawn(function()
		while current == token do task.wait(0.1) end
		conn:Disconnect()
		input:Disconnect()
	end)
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if #queue > 0 and not playing and not busy() then
			local c = player.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart")
			local at = hrp and wallPoint()
			if at and (Vector3.new(hrp.Position.X, at.Y, hrp.Position.Z) - at).Magnitude <= (CFG.nearStuds or 40) then
				play(table.remove(queue, 1))
			end
		end
	end
end)
