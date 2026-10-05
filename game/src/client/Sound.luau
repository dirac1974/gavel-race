--!nonstrict
-- Sound: the client's sound effects and race announcer (docs/audio/AUDIO_PLAN.md).
--   Sound.play(name, volume?, at?)  one-shot; `at` (a BasePart or Attachment) makes it positional
--   Sound.loop(name, volume?)       starts a loop and returns its stop function
-- Ids come from the generated SoundAssets (tools/roblox/upload_assets.py). A name with no id (not
-- uploaded yet, or 0) plays nothing, and nothing here ever errors into the caller.
-- The Sound setting (Settings tab, PlayerState settings.sound, on by default) mutes everything,
-- including loops already running. Announcer lines (vo_*) never talk over each other.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local okIds, ids = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundAssets", 10))
end)
if not okIds or type(ids) ~= "table" then ids = {} end

local Sound = {}

-- Default levels, before the caller's volume: the announcer on top, UI ticks quiet, loops under.
local LEVEL = {
	gallop_loop = 0.45, crowd_cheer = 0.55, gate_bell = 0.6, burst_whoosh = 0.6, tap_good = 0.35,
	finish_fanfare = 0.6, ui_pop = 0.3, coin = 0.45, horse_nicker = 0.5, brush = 0.5, munch = 0.5,
	harvest_pop = 0.5, job_done = 0.55, clap = 0.45, heartbeat = 0.6,
}
local VOICE_LEVEL = 0.9
local DEFAULT_LEVEL = 0.5

local group = Instance.new("SoundGroup")
group.Name = "GiddyUp"
group.Parent = SoundService
local folder = Instance.new("Folder") -- 2D sounds live here (not inside a part, so not positional)
folder.Name = "GiddyUpSounds"
folder.Parent = SoundService

local cache: { [string]: Sound } = {}
local voice: Sound? = nil

local playerState = nil
local function enabled(): boolean
	if playerState == nil then
		local module = script.Parent:FindFirstChild("PlayerState")
		local ok, ps = pcall(require, module)
		playerState = if ok and type(ps) == "table" then ps else false
	end
	local d = playerState and playerState.data
	return not (d and d.settings and d.settings.sound == false)
end

local function idOf(name: string): number
	local id = ids[name]
	return if type(id) == "number" then id else 0
end

local function make(name: string, parent: Instance): Sound?
	local id = idOf(name)
	if id == 0 then return nil end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. id
	s.SoundGroup = group
	s.Parent = parent
	return s
end

local function level(name: string, volume: number?): number
	local base = if string.sub(name, 1, 3) == "vo_" then VOICE_LEVEL else (LEVEL[name] or DEFAULT_LEVEL)
	return math.clamp(base * (volume or 1), 0, 2)
end

function Sound.play(name: string, volume: number?, at: Instance?)
	pcall(function()
		if not enabled() or idOf(name) == 0 then return end
		if at then -- positional: its own Sound on the part, gone when it ends
			local s = make(name, at)
			if not s then return end
			s.Volume = level(name, volume)
			s.RollOffMaxDistance = 80
			s.Ended:Once(function() s:Destroy() end)
			s:Play()
			task.delay(15, function() if s.Parent then s:Destroy() end end)
			return
		end
		local s = cache[name] or make(name, folder)
		if not s then return end
		cache[name] = s
		if string.sub(name, 1, 3) == "vo_" then
			if voice and voice ~= s then voice:Stop() end
			voice = s
		end
		s.Volume = level(name, volume)
		s.TimePosition = 0
		s:Play()
	end)
end

function Sound.loop(name: string, volume: number?): () -> ()
	local s: Sound? = nil
	pcall(function()
		if not enabled() then return end
		s = make(name, folder)
		if not s then return end
		s.Looped = true
		s.Volume = level(name, volume)
		s:Play()
	end)
	return function()
		if s then
			pcall(function() s:Destroy() end)
			s = nil
		end
	end
end

-- The Sound setting mutes the group, so loops and sounds already playing go quiet too.
task.spawn(function()
	enabled()
	if playerState then
		local function sync() group.Volume = if enabled() then 1 else 0 end
		pcall(function() playerState.Changed.Event:Connect(sync) end)
		sync()
	end
end)

-- Load the sounds in the background so the first race line plays on time.
task.spawn(function()
	local list = {}
	for name in ids do
		local s = idOf(name) ~= 0 and (cache[name] or make(name, folder))
		if s then
			cache[name] = s
			table.insert(list, s)
		end
	end
	pcall(function() ContentProvider:PreloadAsync(list) end)
end)

return Sound
