--!strict
-- Visiting other stables (D-060, D-042, D-079). Pure rules, tested under Lune; StableService,
-- VisitService and CareService check who and where, then call these.
--   Who: the owner's setting (Visits.setting) is Friends (default), Everyone here or Nobody ("Club"
--     and anything unknown read as Friends). Roblox friends in this server may come in unless it's
--     Nobody; anyone in the server may come in when it's Everyone here. A closed gate (the owner's
--     one tap) keeps everyone out until it opens again.
--   What a visitor can do (Visits.may, the permission matrix): everyone let in may look, walk the
--     4-stop tour (a Tour pin, once ever per barn), pat (no bond) and send a preset cheer (the owner
--     sees it anonymously). Friends may also give one free treat a day (bond only) and drop one of
--     their own carrots in the post box. Nothing else: nothing can be taken, moved or written.
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
	everyone: boolean?,
	cheersPerBarnPerDay: number?,
	tourStops: { { id: string, inward: number, across: number } }?,
}

-- The care actions a visitor may send through CareService's VisitCare (unchanged since D-060; the
-- permission matrix below decides who may do each).
Visits.ACTIONS = { pat = true, treat = true, post = true }

-- The permission matrix (D-079): what a friend and what a stranger may do once let in. "enter" is
-- being listed, travelling to the gate and standing in the yard; "look" is a tour stop.
Visits.FRIEND_MAY = { enter = true, look = true, pat = true, cheer = true, treat = true, post = true }
Visits.STRANGER_MAY = { enter = true, look = true, pat = true, cheer = true }
Visits.SETTINGS = { "Friends", "Everyone", "Nobody" }

-- The 4 tour stops, in order (D-079; positions in GameConfig.visit.tourStops). The 4th is the Legend
-- paddock when the owner has a Legend, else their garden, so every stop shows something (feel consult).
Visits.STOPS = { "wall", "horses", "decor", "paddock" }
Visits.ALL_STOPS = { "wall", "horses", "decor", "paddock", "garden" }
Visits.STOP_NAMES = { wall = "Rosette Wall", horses = "The horses", decor = "Their yard", paddock = "Legend paddock",
	garden = "Their garden" }

-- The 4 stops at a barn: the Legend paddock only when the owner has a Legend.
function Visits.stopsFor(hasLegend: boolean?): { string }
	return { "wall", "horses", "decor", if hasLegend then "paddock" else "garden" }
end

-- The 4 preset cheers (no text anywhere). Order = the buttons.
Visits.CHEERS = { "clap", "yay", "love", "rainbow" }
Visits.CHEER_ICONS = { clap = "👏", yay = "🎉", love = "😍", rainbow = "🌈" }

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
-- The owner's setting as one of Visits.SETTINGS. Old saves: "Club" (hidden since D-060) and anything
-- unknown read as Friends. everyone == false (GameConfig.visit.everyone off) reads Everyone as Friends.
function Visits.setting(v: any, everyone: boolean?): string
	if v == "Nobody" then return "Nobody" end
	if v == "Everyone" and everyone ~= false then return "Everyone" end
	return "Friends"
end

-- The permission matrix, before the gate: may a friend (or a stranger) do `action` at a barn whose
-- owner chose `setting`? Nobody blocks everything; strangers only where it's Everyone here.
function Visits.may(setting: any, friend: boolean, action: any, everyone: boolean?): boolean
	local s = Visits.setting(setting, everyone)
	if s == "Nobody" or typeof(action) ~= "string" then return false end
	if friend then return Visits.FRIEND_MAY[action] == true end
	return s == "Everyone" and Visits.STRANGER_MAY[action] == true
end

export type Access = {
	same: boolean?,        -- the owner themself
	friends: boolean,      -- Player:IsFriendsWith, cached by the server (a failed check is false)
	visits: string?,       -- the owner's "Who can visit my stable?" setting
	gateClosed: boolean?,  -- the owner closed the gate
	enabled: boolean?,     -- GameConfig.visit.enabled
	everyone: boolean?,    -- GameConfig.visit.everyone (false: Everyone reads as Friends)
	strangersOk: boolean?, -- false: PolicyService says no stranger contact for one of the two (VisitAccess)
	askedOut: boolean?,    -- the owner asked this visitor to leave a little while ago (visit.askLeaveSeconds)
	action: string?,       -- what the visitor wants to do (Visits.FRIEND_MAY); nil = the strictest, "treat"
}

-- (ok, reason): reason is "self", "off", "action", "friends", "private", "asked" or "closed". With no action
-- the check is the friends-only one, so callers written before D-079 (CareService's VisitCare) stay
-- friends-only.
function Visits.canVisit(a: Access): (boolean, string?)
	if a.same then return false, "self" end
	if a.enabled == false then return false, "off" end
	local action = a.action or "treat"
	if not Visits.FRIEND_MAY[action] then return false, "action" end
	local s = Visits.setting(a.visits, a.everyone)
	if not a.friends and not (s == "Everyone" and a.strangersOk ~= false and Visits.STRANGER_MAY[action]) then
		return false, "friends"
	end
	if s == "Nobody" then return false, "private" end
	if a.askedOut then return false, "asked" end
	if a.gateClosed then return false, "closed" end
	return true, nil
end

-- The client's copy of the server's entry check, from what the server publishes (code review S2):
-- the plot's Visits attribute (already Friends while the owner's PolicyService says no strangers),
-- the plot's GateClosed, the local player's VisitStrangersOk, and AskedOutOf / AskedOutUntil (Ask
-- to leave). `serverNow` is workspace:GetServerTimeNow().
export type Seen = { visits: any, gateClosed: any, friend: boolean, strangersOk: any, askedOutOf: any, askedOutUntil: any,
	ownerId: number, serverNow: number }
function Visits.clientMay(v: Seen, action: string): boolean
	if v.gateClosed == true then return false end
	if v.askedOutOf == v.ownerId and typeof(v.askedOutUntil) == "number" and v.askedOutUntil > v.serverNow then return false end
	return Visits.may(v.visits, v.friend or false, action) and (v.friend or v.strangersOk == true)
end

export type Owner = { userId: number, name: string, visits: string?, gateClosed: boolean?, hasBarn: boolean, fresh: boolean?,
	policyOk: boolean? }

-- The Map's barns list for `viewer` (D-060, D-079): friends with a barn whose setting lets them in
-- (closed gates included, shown greyed, "Gate closed"), and every other barn in the server whose
-- owner chose Everyone here, gate open. friend marks who's a friend. Friends first, then by name
-- (never by anything counted), at most cfg.listMax. A "Nobody" barn is never on it, and with
-- strangersOk false (the viewer's PolicyService couldn't be read) no stranger's barn is either.
-- fresh (D-070): a Barn Builder build under greenCash.newBuildHours old (a ✨; no counts).
function Visits.list(viewer: number, owners: { Owner }, isFriend: (number, number) -> boolean, cfg: Config, strangersOk: boolean?): { { userId: number, name: string, closed: boolean, fresh: boolean, friend: boolean } }
	local out = {}
	if not cfg.enabled or not cfg.mapList then return out end
	for _, o in owners do
		if o.hasBarn and o.userId ~= viewer then
			local friends = isFriend(viewer, o.userId)
			local ok, why = Visits.canVisit({ friends = friends, visits = o.visits, gateClosed = o.gateClosed, everyone = cfg.everyone,
				strangersOk = strangersOk ~= false and o.policyOk ~= false, action = "enter" })
			if ok or (friends and why == "closed") then
				table.insert(out, { userId = o.userId, name = o.name, closed = not ok, fresh = o.fresh == true, friend = friends })
			end
		end
	end
	table.sort(out, function(x, y)
		if x.friend ~= y.friend then return x.friend end
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
-- `horseIds` are the owner's stalled horses (the ones in the barn). A pat never gives bond, and since
-- D-079 never a Tour pin either: the pin is the walkaround's only (code review N3). Returns (ok,
-- result): result = { left = horses still to pat today, stamp = false, already = the pin was earned }.
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
	return true, { left = left, stamp = false, already = tour.stamps[k] ~= nil }
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

-- The walkaround (D-079) ---------------------------------------------------------------
-- Standing at tour stop `stopId` of `ownerId`'s barn (one of Visits.stopsFor(hasLegend)). Stops reset
-- each day; all 4 on one day earn that barn's Tour pin, once ever (the D-060 Tour stamps, at most
-- MAX_TOUR_STAMPS). Returns (ok, result): result = { done = stops seen today, left, pin = true when
-- this stop earned the pin, already = the pin was earned before, fresh = this stop wasn't seen
-- today }, or (false, { reason }): "stop" (not a stop here) or "full" (MAX_TOUR_FRIENDS barns today,
-- so the client backs off; code review N2).
function Visits.stop(visitor: any, ownerId: number, stopId: any, now: number, hasLegend: boolean?): (boolean, any)
	local stops = Visits.stopsFor(hasLegend)
	if typeof(stopId) ~= "string" or not table.find(stops, stopId) then return false, { reason = "stop" } end
	local tour = tourToday(visitor, now)
	local k = key(ownerId)
	local already = tour.stamps[k] ~= nil
	local set = tour.stops[k]
	if not set then
		local n = 0
		for _ in tour.stops do n += 1 end
		if n >= Profile.MAX_TOUR_FRIENDS then return false, { reason = "full" } end
		set = {}
		tour.stops[k] = set
	end
	local fresh = set[stopId] ~= true
	set[stopId] = true
	local done = 0
	for _, id in stops do
		if set[id] then done += 1 end
	end
	local pin = false
	if done == #stops and not already and Profile.tourStampCount(visitor) < Profile.MAX_TOUR_STAMPS then
		tour.stamps[k] = day(now)
		pin = true
	end
	return true, { done = done, left = #stops - done, pin = pin, already = already, fresh = fresh }
end

-- The stops `visitor` has seen at `ownerId`'s barn today, in tour order.
function Visits.stopsToday(visitor: any, ownerId: number, now: number, hasLegend: boolean?): { string }
	local tour = tourToday(visitor, now)
	local set = tour.stops[key(ownerId)] or {}
	local out = {}
	for _, id in Visits.stopsFor(hasLegend) do
		if set[id] then table.insert(out, id) end
	end
	return out
end

-- Cheer (D-079) -----------------------------------------------------------------------
-- A preset cheer (Visits.CHEERS) to the owner, cfg.cheersPerBarnPerDay a day from one visitor at one
-- barn. The owner sees it with no name. Returns (ok, result): result.icon, or result.reason "kind"
-- or "used".
function Visits.cheer(visitor: any, ownerId: number, kind: any, now: number, cfg: Config): (boolean, any)
	if typeof(kind) ~= "string" or not Visits.CHEER_ICONS[kind] then return false, { reason = "kind" } end
	local tour = tourToday(visitor, now)
	local k = key(ownerId)
	local sent = tour.cheers[k] or 0
	if sent >= (cfg.cheersPerBarnPerDay or 3) then return false, { reason = "used" } end
	if sent == 0 then
		local n = 0
		for _ in tour.cheers do n += 1 end
		if n >= Profile.MAX_TOUR_FRIENDS then return false, { reason = "used" } end
	end
	tour.cheers[k] = sent + 1
	return true, { icon = Visits.CHEER_ICONS[kind] }
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
