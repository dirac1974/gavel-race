--!nonstrict
-- Sound: the client's sound effects and race announcer (docs/audio/AUDIO_PLAN.md).
--   Sound.play(name, volume?, at?, speed?)  one-shot; `at` (a BasePart or Attachment) makes it positional;
--                                           `speed` is the PlaybackSpeed (pitch and tempo), 1 by default
--   Sound.loop(name, volume?, speed?)       starts a loop and returns its stop function
--   Sound.stop(name)                        stops a 2D one-shot that is still playing
--   Sound.recent(name, seconds)             true if that sound started playing within the last `seconds`
--   Sound.speaking()                        true while an announcer line (vo_*) plays
--   Sound.music(id)                         a looping music Sound (a library track id) in the same group, so
--                                           the Sound setting mutes it; silent until its Volume is set (MusicBed)
-- Ids come from the generated SoundAssets (tools/roblox/upload_assets.py). A name with no own id plays
-- its stand-in clip from the generated SoundSheet (tools/audio/synth_sheet.py: every effect in one
-- Audio asset, played by PlaybackRegion), so an effect uploaded on its own later replaces its clip.
-- A name with neither plays nothing, and nothing here ever errors into the caller.
-- The Sound setting (Settings tab, PlayerState settings.sound, on by default) mutes everything,
-- including loops already running; a loop started while muted is heard once Sound is back On.
-- Announcer lines (vo_*) never talk over each other.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local okIds, ids = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundAssets", 10))
end)
if not okIds or type(ids) ~= "table" then ids = {} end
local okSheet, sheet = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundSheet", 10))
end)
if not okSheet or type(sheet) ~= "table" or type(sheet.clips) ~= "table" then sheet = { assetId = 0, clips = {} } end

local Sound = {}

-- Default levels, before the caller's volume: the announcer on top, UI ticks quiet, loops under.
-- The voice files peak near full scale (-0.3 dBFS), so the announcer sits below 1.
local LEVEL = {
	gallop_loop = 0.45, crowd_cheer = 0.55, gate_bell = 0.5, burst_whoosh = 0.6, tap_good = 0.35,
	finish_fanfare = 0.6, ui_pop = 0.3, coin = 0.45, horse_nicker = 0.5, brush = 0.5, munch = 0.5,
	harvest_pop = 0.5, job_done = 0.55, clap = 0.45, heartbeat = 0.6, lock_tick = 0.35, tap_ok = 0.25,
	count_tick = 0.45, bump_soft = 0.45,
}
local VOICE_LEVEL = 0.7
local DEFAULT_LEVEL = 0.5

local group = Instance.new("SoundGroup")
group.Name = "GiddyUp"
group.Parent = SoundService
local folder = Instance.new("Folder") -- 2D sounds live here (not inside a part, so not positional)
folder.Name = "GiddyUpSounds"
folder.Parent = SoundService

local cache: { [string]: Sound } = {}
local voice: Sound? = nil
local lastPlayed: { [string]: number } = {}

-- PlayerState (for the Sound setting) loads in the background below; until it has, sound is on.
-- A failed load is not remembered, so it's tried again and Sound Off always takes effect.
local playerState = nil
local function loadPlayerState()
	if playerState then return playerState end
	local module = script.Parent:WaitForChild("PlayerState", 5)
	if module then
		local ok, ps = pcall(require, module)
		if ok and type(ps) == "table" then playerState = ps end
	end
	return playerState
end

local function enabled(): boolean
	local d = playerState and playerState.data
	return not (d and d.settings and d.settings.sound == false)
end

type Clip = { start: number, length: number, loop: boolean }

-- Where a name's audio is: its own asset (clip nil), else its region of the sheet, else id 0.
local function sourceOf(name: string): (number, Clip?)
	local id = ids[name]
	if type(id) == "number" and id ~= 0 then return id, nil end
	local clip = sheet.clips[name]
	if type(sheet.assetId) == "number" and sheet.assetId ~= 0 and type(clip) == "table" then
		return sheet.assetId, clip
	end
	return 0, nil
end

local function idOf(name: string): number
	return (sourceOf(name))
end

local function make(name: string, parent: Instance, looped: boolean?): Sound?
	local id, clip = sourceOf(name)
	if id == 0 then return nil end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. id
	s.SoundGroup = group
	if clip then -- play only this clip's stretch of the sheet
		local region = NumberRange.new(clip.start, clip.start + clip.length)
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = region
		if looped then s.LoopRegion = region end
	end
	s.Parent = parent
	return s
end

-- Rewind to the start of the sound (the clip's start, on the sheet).
local function rewind(name: string, s: Sound)
	local _, clip = sourceOf(name)
	s.TimePosition = if clip then clip.start else 0
end

local function level(name: string, volume: number?): number
	local base = if string.sub(name, 1, 3) == "vo_" then VOICE_LEVEL else (LEVEL[name] or DEFAULT_LEVEL)
	return math.clamp(base * (volume or 1), 0, 2)
end

function Sound.play(name: string, volume: number?, at: Instance?, speed: number?)
	pcall(function()
		if not enabled() or idOf(name) == 0 then return end
		if at then -- positional: its own Sound on the part, gone when it ends
			local s = make(name, at)
			if not s then return end
			s.Volume = level(name, volume)
			s.PlaybackSpeed = math.clamp(speed or 1, 0.25, 4)
			rewind(name, s)
			s.RollOffMaxDistance = 80
			s.Ended:Once(function() s:Destroy() end)
			s:Play()
			lastPlayed[name] = os.clock()
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
		s.PlaybackSpeed = math.clamp(speed or 1, 0.25, 4)
		rewind(name, s)
		s:Play()
		lastPlayed[name] = os.clock()
	end)
end

function Sound.stop(name: string)
	local s = cache[name]
	if s then pcall(function() s:Stop() end) end
end

function Sound.recent(name: string, seconds: number): boolean
	local t = lastPlayed[name]
	return t ~= nil and os.clock() - t <= seconds
end

function Sound.speaking(): boolean -- (every Heartbeat from MusicBed: no closure)
	local v = voice
	return v ~= nil and v.IsPlaying == true
end

-- (AAA Phase 4, D-069) The music bed: one looping Sound for a library track id, started at volume 0 in
-- the GiddyUp group (Sound Off mutes it like everything else). id 0 or a bad id: nil.
function Sound.music(id: number): Sound?
	if type(id) ~= "number" or id <= 0 then return nil end
	local s: Sound? = nil
	pcall(function()
		local m = Instance.new("Sound")
		m.Name = "MusicBed"
		m.SoundId = "rbxassetid://" .. math.floor(id)
		m.SoundGroup = group
		m.Looped = true
		m.Volume = 0
		m.Parent = folder
		m:Play()
		s = m
	end)
	return s
end

-- A loop plays even while Sound is Off: the muted group keeps it silent, and it's heard again
-- as soon as Sound is turned back On (say, mid-race).
function Sound.loop(name: string, volume: number?, speed: number?): () -> ()
	local s: Sound? = nil
	pcall(function()
		s = make(name, folder, true)
		if not s then return end
		s.Looped = true
		s.Volume = level(name, volume)
		s.PlaybackSpeed = math.clamp(speed or 1, 0.25, 4)
		rewind(name, s)
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
	local ps = loadPlayerState()
	while not ps do
		task.wait(5)
		ps = loadPlayerState()
	end
	local function sync() group.Volume = if enabled() then 1 else 0 end
	pcall(function() ps.Changed.Event:Connect(sync) end)
	sync()
end)

-- Load the sounds in the background so the first race line plays on time.
task.spawn(function()
	local list = {}
	local names = {}
	for name in ids do names[name] = true end
	for name in sheet.clips do names[name] = true end
	for name in names do
		local s = idOf(name) ~= 0 and (cache[name] or make(name, folder))
		if s then
			cache[name] = s
			table.insert(list, s)
		end
	end
	pcall(function() ContentProvider:PreloadAsync(list) end)
end)

return Sound
