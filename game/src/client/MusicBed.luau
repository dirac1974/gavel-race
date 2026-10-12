--!nonstrict
-- MusicBed (AAA Phase 4 Dev B, D-069, GameConfig.audio.music): one beatless bed under the whole game,
-- from Roblox's licensed music library (no upload: the last audio upload this window is kept for an
-- emergency). With id = 0 (the default until David picks a track) there is no music and nothing is made.
-- Levels (RacePresent.musicLevel): lobby; race while your slider runs (far under the tap tick, so kids tap
-- to the marker, never to a beat); a training ride's slider the same; spectate while you watch a race;
-- finish for the finish moment and the results card; ducked under any announcer line (duckUnderVoice).
-- Every change fades over fadeSeconds. The Sound setting mutes it with everything else (Sound's group).
-- Started once by RaceController (MusicBed.start). STATUS: written without Studio access; verify in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RacePresent = require(Shared:WaitForChild("RacePresent"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local okT, TrainingState = pcall(require, script.Parent:WaitForChild("TrainingState", 5))
if not okT then TrainingState = nil end
local okS, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okS then Sound = nil end

local CFG = (GameConfig.audio or {}).music or { id = 0 }

local Music = {}

-- Which level the bed plays at now.
function Music.mode(): string
	if RaceState.resultsOpen or (RaceState.active and RaceState.myLane ~= nil and RaceState.myHome) then return "finish" end
	if RaceState.active and RaceState.myLane ~= nil then return "race" end
	if TrainingState and TrainingState.active then return "race" end
	if RaceState.active and RaceState.focus ~= nil and not RaceState.watchHidden then return "spectate" end
	return "lobby"
end

local started = false
function Music.start()
	if started then return end
	started = true
	if not Sound or type(CFG.id) ~= "number" or CFG.id == 0 then return end -- no track: no music
	local bed = Sound.music(CFG.id)
	if not bed then return end
	local level = 0
	RunService.Heartbeat:Connect(function(dt)
		local target = RacePresent.musicLevel(CFG, Music.mode(), Sound.speaking())
		if target ~= level then
			level = RacePresent.musicStep(CFG, level, target, dt)
			bed.Volume = level
		end
	end)
end

return Music
