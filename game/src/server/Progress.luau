--!nonstrict
-- Progress: counts what players do toward their Stable Board jobs (D-043). Other server
-- scripts call Progress.record(player, event, n) after something succeeds; finished jobs get
-- a friendly toast pointing to the board. Events: feed, groom, treat, pet, plant, harvest,
-- chore, race, great_tap, burst_great, ride, visit_trail, day, checkup, spa (see Jobs.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jobs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Jobs"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local Progress = {}

function Progress.record(player: Player, event: string, n: number?)
	local data = Profiles.get(player)
	if not data or (n or 1) <= 0 then return end
	if Progress.onRecord then Progress.onRecord(player, event) end -- the first-ten-minutes tour (SettingsService)
	local finished = Jobs.record(data, player.UserId, event, n or 1, os.time())
	for _, d in finished do
		Profiles.notify(player, "Job done: " .. d.text .. "! Claim it on your Stable Board", "clipboard")
	end
	Profiles.changed(player)
end

return Progress
