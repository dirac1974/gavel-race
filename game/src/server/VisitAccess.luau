--!nonstrict
-- VisitAccess (D-060): the server's live answers for visiting friends' barns, shared by
-- StableService (list, travel, gate, post box) and CareService (pat, treat). The rules are in
-- shared/Visits.luau; this adds the live facts: Roblox friendship (TrainingFriends' cache,
-- asked once per pair on join; a failed check is "not friends"), the owner's setting, the
-- gate (closed by the owner's one tap, open again on the next tap or when they leave) and
-- where the visitor stands.
-- D-079: every check names its action (Visits.FRIEND_MAY); with none it is the friends-only check, so
-- CareService's VisitCare (pat and treat, written before D-079) stays friends-only. Strangers come in
-- only where the owner chose Everyone here, and only when PolicyService allows it for both players.
-- PolicyService rule (code review S1). GetPolicyInfoForPlayerAsync has no field named for contact
-- with non-friends; its fields are listed at
--   https://create.roblox.com/docs/reference/engine/classes/PolicyService (GetPolicyInfoForPlayerAsync).
-- The nearest are:
--   IsContentSharingAllowed: "the player can use features related to sharing UGC within an
--     experience". It reflects age group and region. A barn is the kid's own made thing, shown to
--     strangers, so it must be true for both owner and visitor.
--   IsSubjectToChinaPolicies: when true, the experience "should enforce compliance changes", so no
--     stranger visits.
-- It fails closed: an error, a missing field or a non-boolean leaves the player friends-only. A failed
-- read retries once after visit.policyRetrySeconds. Each player's answer is published as the player
-- attribute VisitStrangersOk, so the clients' walls and prompts agree with the server (code review S2).
-- Ask to leave (code review S3): the owner walks one visitor out, and that visitor can't come back in
-- for visit.askLeaveSeconds (published as the visitor's AskedOutOf / AskedOutUntil attributes).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visits = require(Shared:WaitForChild("Visits"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local TrainingFriends = require(script.Parent:WaitForChild("TrainingFriends"))

local PolicyService = game:GetService("PolicyService")

local VisitAccess = {}

local closed: { [number]: boolean } = {} -- owner userId -> gate closed
local policyOk: { [Player]: boolean } = {} -- PolicyService answered for this player (D-079)

-- Strangers' visits need PolicyService to allow them for the player (see the header).
function VisitAccess.policyOk(player: Player): boolean
	return policyOk[player] == true
end

-- The rule on a PolicyService answer (pure; fail closed on anything missing or odd).
function VisitAccess.strangersAllowed(info: any): boolean
	if typeof(info) ~= "table" then return false end
	return info.IsContentSharingAllowed == true and info.IsSubjectToChinaPolicies == false
end

local function askPolicy(player: Player, retry: boolean?)
	local ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(player) end)
	if not player.Parent then return end
	policyOk[player] = ok and VisitAccess.strangersAllowed(info)
	player:SetAttribute("VisitStrangersOk", policyOk[player])
	if not ok and not retry then
		task.delay(GameConfig.visit.policyRetrySeconds, function()
			if player.Parent then askPolicy(player, true) end
		end)
	end
end
Players.PlayerAdded:Connect(function(p: Player) askPolicy(p) end)
for _, p in Players:GetPlayers() do task.spawn(askPolicy, p) end

-- Ask to leave ------------------------------------------------------------------------
local askedOut: { [number]: { [number]: number } } = {} -- owner userId -> visitor userId -> until (os.clock)

function VisitAccess.askOut(owner: Player, visitor: Player)
	local m = askedOut[owner.UserId] or {}
	askedOut[owner.UserId] = m
	m[visitor.UserId] = os.clock() + GameConfig.visit.askLeaveSeconds
	visitor:SetAttribute("AskedOutOf", owner.UserId)
	visitor:SetAttribute("AskedOutUntil", workspace:GetServerTimeNow() + GameConfig.visit.askLeaveSeconds)
end

function VisitAccess.isAskedOut(owner: Player, visitor: Player): boolean
	local m = askedOut[owner.UserId]
	local t = m and m[visitor.UserId]
	if t and t <= os.clock() then
		m[visitor.UserId] = nil
		t = nil
	end
	return t ~= nil
end

function VisitAccess.gateClosed(owner: Player): boolean
	return closed[owner.UserId] == true
end

function VisitAccess.setGate(owner: Player, isClosed: boolean)
	closed[owner.UserId] = if isClosed then true else nil
end

function VisitAccess.friends(a: Player, b: Player): boolean
	return TrainingFriends.areFriends(a, b)
end

-- (ok, reason) for `visitor` doing `action` at `owner`'s barn, before checking where they stand.
-- action nil = "treat", the friends-only check (Visits.canVisit).
function VisitAccess.check(visitor: Player, owner: Player?, action: string?): (boolean, string?)
	if not owner or not owner.Parent then return false, "gone" end
	local data = Profiles.get(owner)
	if not data or not owner:GetAttribute("PlotIndex") then return false, "gone" end
	return Visits.canVisit({
		same = visitor == owner,
		enabled = GameConfig.visit.enabled,
		everyone = GameConfig.visit.everyone,
		friends = TrainingFriends.areFriends(visitor, owner),
		strangersOk = VisitAccess.policyOk(visitor) and VisitAccess.policyOk(owner),
		askedOut = VisitAccess.isAskedOut(owner, visitor),
		visits = data.settings and data.settings.visits,
		gateClosed = VisitAccess.gateClosed(owner),
		action = action,
	})
end

-- The owner's setting as the clients see it (Visits.setting: Club reads as Friends). Everyone here
-- reads as Friends while PolicyService doesn't allow strangers for the owner (code review S2).
function VisitAccess.setting(owner: Player): string
	local data = Profiles.get(owner)
	local s = Visits.setting(data and data.settings and data.settings.visits, GameConfig.visit.everyone)
	if s == "Everyone" and not VisitAccess.policyOk(owner) then return "Friends" end
	return s
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
	for k = 1, data.stalls do -- stalls stored per horse (D-059): an empty stall has no horse to pat
		local h = nil
		for _, x in data.horses do
			if x.stall == k then h = x end
		end
		local id = h and h.id
		if id and owner:GetAttribute("RacingHorse") ~= id and owner:GetAttribute("RidingHorse") ~= id then table.insert(ids, id) end
	end
	return ids
end

function VisitAccess.owner(userId: any): Player?
	if typeof(userId) ~= "number" or userId ~= userId then return nil end
	return Players:GetPlayerByUserId(userId)
end

Players.PlayerRemoving:Connect(function(player: Player)
	closed[player.UserId] = nil
	policyOk[player] = nil
	askedOut[player.UserId] = nil
end)

return VisitAccess
