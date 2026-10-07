--!strict
-- Visiting friends' barns (D-060, D-042). Pure rules, tested under Lune; StableService and
-- CareService check who and where, then call these.
--   Who: only Roblox friends in this server whose stable visits aren't "Nobody" ("Club" counts
--     as Friends until clubs exist) are listed or let in. A closed gate (the owner's one tap)
--     keeps everyone out until it opens again.
--   What a visitor can do: pat each horse (no bond; patting every stalled horse earns that
--     friend's Tour stamp, once ever), give one free treat a day at each friend's barn (bond
--     only), and drop one of their own carrots in the post box (the owner sees a count, never
--     who). Nothing else: feeding, grooming, the garden, chores and the shop stay owner-only.
--   Bond from all visitors together is capped per horse per day (visit.bondPerHorsePerDay).
--   Never: visitor counts, likes, rankings or guestbook text.

local Profile = if script then require(script.Parent.Profile) :: any else require("./Profile")

local Visits = {}

export type Config = {
	enabled: boolean,
	mapList: boolean,
	bondPerHorsePerDay: number,
	treatsPerFriendPerDay: number,
	treatBond: number,
	carrotsPerFriendPerDay: number,
	postBoxPerDay: number,
	nearStuds: number,
	travelGapSeconds: number,
	listMax: number,
}

-- The only things a visitor may do on someone else's plot.
Visits.ACTIONS = { pat = true, treat = true, post = true }

function Visits.visitorMay(action: any): boolean
	return typeof(action) == "string" and Visits.ACTIONS[action] == true
end

local function day(now: number): number
	return now // 86400
end

local function key(userId: number): string
	return tostring(math.floor(userId))
end

-- Who may come in ----------------------------------------------------------------------
export type Access = {
	same: boolean?,       -- the owner themself
	friends: boolean,     -- Player:IsFriendsWith, cached by the server (a failed check is false)
	visits: string?,      -- the owner's "Who can visit my stable?" setting
	gateClosed: boolean?, -- the owner closed the gate
	enabled: boolean?,    -- GameConfig.visit.enabled
}

-- (ok, reason): reason is "self", "off", "friends", "private" or "closed".
function Visits.canVisit(a: Access): (boolean, string?)
	if a.same then return false, "self" end
	if a.enabled == false then return false, "off" end
	if not a.friends then return false, "friends" end
	if a.visits == "Nobody" then return false, "private" end
	if a.gateClosed then return false, "closed" end
	return true, nil
end

export type Owner = { userId: number, name: string, visits: string?, gateClosed: boolean?, hasBarn: boolean }

-- The Friends' barns list for `viewer`: friends with a barn whose setting lets them in, closed
-- gates included (shown greyed, "Gate closed"), sorted by name, at most cfg.listMax. A
-- non-friend or a "Nobody" barn is never on it.
function Visits.list(viewer: number, owners: { Owner }, isFriend: (number, number) -> boolean, cfg: Config): { { userId: number, name: string, closed: boolean } }
	local out = {}
	if not cfg.enabled or not cfg.mapList then return out end
	for _, o in owners do
		if o.hasBarn and o.userId ~= viewer then
			local friends = isFriend(viewer, o.userId)
			local ok, why = Visits.canVisit({ friends = friends, visits = o.visits, gateClosed = o.gateClosed })
			if ok or why == "closed" then
				table.insert(out, { userId = o.userId, name = o.name, closed = not ok })
			end
		end
	end
	table.sort(out, function(x, y)
		if x.name ~= y.name then return x.name < y.name end
		return x.userId < y.userId
	end)
	while #out > cfg.listMax do table.remove(out) end
	return out
end

-- Today's maps on the visitor's Tour, cleared on a new day.
local function tourToday(p: any, now: number): any
	if typeof(p.tour) ~= "table" or p.tour.day ~= day(now) then Profile.repairVisits(p, now) end
	return p.tour
end

-- Bond from visitors, capped per horse per day: returns how much was given (0 at the cap).
function Visits.giveBond(h: any, amount: number, now: number, cfg: Config): number
	local d = day(now)
	if typeof(h.visitBond) ~= "table" or h.visitBond.day ~= d then h.visitBond = { day = d, n = 0 } end
	local give = math.max(0, math.min(amount, cfg.bondPerHorsePerDay - (tonumber(h.visitBond.n) or 0)))
	if give > 0 then
		h.visitBond.n += give
		h.bond = math.clamp((tonumber(h.bond) or 0) + give, 0, 100)
	end
	return give
end

-- Pat --------------------------------------------------------------------------------
-- `horseIds` are the owner's stalled horses (the ones in the barn). A pat never gives bond.
-- Returns (ok, result): result = { left = horses still to pat today, stamp = true when this pat
-- earned the friend's Tour stamp, already = true when the stamp was earned before }.
function Visits.pat(visitor: any, ownerId: number, horseId: string, horseIds: { string }, now: number): (boolean, any)
	if not table.find(horseIds, horseId) then return false, { reason = "horse" } end
	local tour = tourToday(visitor, now)
	local k = key(ownerId)
	local set = tour.patted[k]
	if not set then
		local n = 0
		for _ in tour.patted do n += 1 end
		if n >= Profile.MAX_TOUR_FRIENDS then return true, { left = 0, already = tour.stamps[k] ~= nil } end
		set = {}
		tour.patted[k] = set
	end
	set[horseId] = true
	local left = 0
	for _, id in horseIds do
		if not set[id] then left += 1 end
	end
	local already = tour.stamps[k] ~= nil
	local stamp = false
	if left == 0 and not already and Profile.tourStampCount(visitor) < Profile.MAX_TOUR_STAMPS then
		tour.stamps[k] = day(now)
		stamp = true
	end
	return true, { left = left, stamp = stamp, already = already }
end

-- Treat ------------------------------------------------------------------------------
-- One free treat a day at each friend's barn (D-042): nothing leaves the visitor's bag. The
-- horse gets bond inside the visitors' daily cap. Returns (ok, result): result.bond is the
-- bond given (0 when the horse already had its visitor bond today), or result.reason.
function Visits.treat(visitor: any, ownerId: number, h: any, now: number, cfg: Config): (boolean, any)
	local tour = tourToday(visitor, now)
	local k = key(ownerId)
	local given = tour.treats[k] or 0
	if given >= cfg.treatsPerFriendPerDay then return false, { reason = "used" } end
	tour.treats[k] = given + 1
	return true, { bond = Visits.giveBond(h, cfg.treatBond, now, cfg) }
end

-- Post box ----------------------------------------------------------------------------
-- The visitor drops one of their own carrots; the owner gets it and an anonymous count.
-- Returns (ok, result): result.today is the owner's count today, or result.reason is "used"
-- (one a day per friend), "full" (the post box took postBoxPerDay today) or "none" (no carrots).
function Visits.post(visitor: any, owner: any, ownerId: number, now: number, cfg: Config): (boolean, any)
	local tour = tourToday(visitor, now)
	local k = key(ownerId)
	local dropped = tour.carrots[k] or 0
	if dropped >= cfg.carrotsPerFriendPerDay then return false, { reason = "used" } end
	if typeof(owner.postBox) ~= "table" or owner.postBox.day ~= day(now) then Profile.repairVisits(owner, now) end
	if owner.postBox.today >= cfg.postBoxPerDay then return false, { reason = "full" } end
	if not Profile.takeItem(visitor, "carrot", 1) then return false, { reason = "none" } end
	tour.carrots[k] = dropped + 1
	owner.postBox.today += 1
	owner.postBox.total += 1
	Profile.addItem(owner, "carrot", 1)
	return true, { today = owner.postBox.today }
end

-- The gate ----------------------------------------------------------------------------
-- Who to walk out when the gate closes: everyone but the owner standing inside the plot's
-- rectangle grown by `margin` (rect = { x0, z0, x1, z1 }).
function Visits.inside(rect: { number }, x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return x >= rect[1] - m and x <= rect[3] + m and z >= rect[2] - m and z <= rect[4] + m
end

function Visits.toWalkOut(rect: { number }, ownerId: number, people: { { userId: number, x: number, z: number } }): { number }
	local out = {}
	for _, p in people do
		if p.userId ~= ownerId and Visits.inside(rect, p.x, p.z) then table.insert(out, p.userId) end
	end
	return out
end

return Visits
