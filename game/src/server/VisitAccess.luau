--!nonstrict
-- VisitAccess (D-060): the server's live answers for visiting friends' barns, shared by
-- StableService (list, travel, gate, post box) and CareService (pat, treat). The rules are in
-- shared/Visits.luau; this adds the live facts: Roblox friendship (TrainingFriends' cache,
-- asked once per pair on join; a failed check is "not friends"), the owner's setting, the
-- gate (closed by the owner's one tap, open again on the next tap or when they leave) and
-- where the visitor stands.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visits = require(Shared:WaitForChild("Visits"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local TrainingFriends = require(script.Parent:WaitForChild("TrainingFriends"))

local VisitAccess = {}

local closed: { [number]: boolean } = {} -- owner userId -> gate closed

function VisitAccess.gateClosed(owner: Player): boolean
	return closed[owner.UserId] == true
end

function VisitAccess.setGate(owner: Player, isClosed: boolean)
	closed[owner.UserId] = if isClosed then true else nil
end

function VisitAccess.friends(a: Player, b: Player): boolean
	return TrainingFriends.areFriends(a, b)
end

-- (ok, reason) for `visitor` at `owner`'s barn, before checking where they stand.
function VisitAccess.check(visitor: Player, owner: Player?): (boolean, string?)
	if not owner or not owner.Parent then return false, "gone" end
	local data = Profiles.get(owner)
	if not data or not owner:GetAttribute("PlotIndex") then return false, "gone" end
	return Visits.canVisit({
		same = visitor == owner,
		enabled = GameConfig.visit.enabled,
		friends = TrainingFriends.areFriends(visitor, owner),
		visits = data.settings and data.settings.visits,
		gateClosed = VisitAccess.gateClosed(owner),
	})
end

local function position(player: Player): Vector3?
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end
VisitAccess.position = position

-- Standing at the owner's barn: inside their plot or within visit.nearStuds of it.
function VisitAccess.near(visitor: Player, owner: Player): boolean
	local i = owner:GetAttribute("PlotIndex")
	local pos = position(visitor)
	if not i or not pos then return false end
	return Visits.inside(WorldLayout.plotRect(i), pos.X, pos.Z, GameConfig.visit.nearStuds)
end

-- The horses in the owner's barn right now: stalled, and not out riding or at the races.
function VisitAccess.barnHorses(owner: Player, data): { string }
	local ids = {}
	for k = 1, math.min(data.stalls, #data.horses) do
		local id = data.horses[k].id
		if owner:GetAttribute("RacingHorse") ~= id and owner:GetAttribute("RidingHorse") ~= id then table.insert(ids, id) end
	end
	return ids
end

function VisitAccess.owner(userId: any): Player?
	if typeof(userId) ~= "number" or userId ~= userId then return nil end
	return Players:GetPlayerByUserId(userId)
end

Players.PlayerRemoving:Connect(function(player: Player) closed[player.UserId] = nil end)

return VisitAccess
