--!strict
-- RideTogether (D-053, T4): riding a training course with a Roblox friend. Pure rules, tested
-- under Lune; TrainingFriends (server) holds the live state.
--   canInvite(ctx) -> ok, reason: only Roblox friends, both with stable visits not "Nobody",
--     the friend near the training courses and free (not racing, not already riding).
--   The invite book: an invite is accept-only (the friend taps "Ride together" or it lapses
--   after INVITE_SECONDS); one pending invite per rider either way; an inviter waits GAP
--   seconds between invites and sends at most PER_WINDOW in WINDOW seconds; after "Not now"
--   the same friend can't be asked again for DECLINE_COOLDOWN seconds; and nobody gets more
--   than RECEIVE_MAX invite cards in WINDOW seconds, from anyone.
-- No text of any kind travels with an invite: a course key and the inviter's Roblox name.

local RideTogether = {}

RideTogether.INVITE_SECONDS = 20
RideTogether.GAP = 8
RideTogether.WINDOW = 300
RideTogether.PER_WINDOW = 5
RideTogether.MAX_RIDERS = 2
RideTogether.DECLINE_COOLDOWN = 60
RideTogether.RECEIVE_MAX = 3

export type Ctx = {
	friends: boolean,        -- Player:IsFriendsWith (cached)
	fromVisits: string?,     -- the inviter's "Who can visit my stable?" setting
	toVisits: string?,       -- the friend's
	toNear: boolean,         -- the friend is at the paddock, the path or the Training Ground
	toBusy: boolean,         -- the friend is racing, in line, riding a course or deciding on an invite
	toLoaded: boolean?,      -- the friend's profile has loaded (false: not invitable yet)
	same: boolean?,          -- inviting yourself
}

function RideTogether.canInvite(ctx: Ctx): (boolean, string?)
	if ctx.same then return false, "self" end
	if not ctx.friends then return false, "friends" end
	if ctx.fromVisits == "Nobody" or ctx.toVisits == "Nobody" then return false, "private" end
	if ctx.toLoaded == false then return false, "busy" end
	if not ctx.toNear then return false, "far" end
	if ctx.toBusy then return false, "busy" end
	return true, nil
end

export type Invite = { id: number, from: number, to: number, course: string, at: number }

function RideTogether.book()
	return { invites = {} :: { [number]: Invite }, sent = {} :: { [number]: { number } }, received = {} :: { [number]: { number } },
		declined = {} :: { [string]: number }, nextId = 1 }
end

local function prune(list: { number }, now: number)
	local i = 1
	while i <= #list do
		if now - list[i] >= RideTogether.WINDOW then table.remove(list, i) else i += 1 end
	end
end

local function pair(from: number, to: number): string
	return tostring(from) .. ">" .. tostring(to)
end

local function pendingFor(book: any, userId: number): Invite?
	for _, inv in book.invites do
		if inv.from == userId or inv.to == userId then return inv end
	end
	return nil
end
RideTogether.pendingFor = pendingFor

-- Drop invites that have lapsed; returns them (so their riders can be told, kindly).
function RideTogether.sweep(book: any, now: number): { Invite }
	local gone = {}
	for id, inv in book.invites do
		if now - inv.at >= RideTogether.INVITE_SECONDS then
			book.invites[id] = nil
			table.insert(gone, inv)
		end
	end
	return gone
end

-- A new invite: returns its id, or nil and why ("gap", "many", "pending", "declined", "full").
function RideTogether.invite(book: any, from: number, to: number, course: string, now: number): (number?, string?)
	RideTogether.sweep(book, now)
	local sent = book.sent[from] or {}
	book.sent[from] = sent
	prune(sent, now)
	local got = book.received[to] or {}
	book.received[to] = got
	prune(got, now)
	if #sent > 0 and now - sent[#sent] < RideTogether.GAP then return nil, "gap" end
	if #sent >= RideTogether.PER_WINDOW then return nil, "many" end
	if pendingFor(book, from) or pendingFor(book, to) then return nil, "pending" end
	local no = book.declined[pair(from, to)]
	if no and now - no < RideTogether.DECLINE_COOLDOWN then return nil, "declined" end
	if #got >= RideTogether.RECEIVE_MAX then return nil, "full" end
	local id = book.nextId
	book.nextId += 1
	book.invites[id] = { id = id, from = from, to = to, course = course, at = now }
	table.insert(sent, now)
	table.insert(got, now)
	return id, nil
end

-- The friend's answer (true, false = "Not now", or "busy" when a shop or game is open, which
-- starts no cooldown). Returns the invite if it was theirs and still open.
function RideTogether.reply(book: any, id: any, by: number, now: number, answer: any?): (Invite?, string?)
	RideTogether.sweep(book, now)
	local inv = typeof(id) == "number" and book.invites[id] or nil
	if not inv then return nil, "gone" end
	if inv.to ~= by then return nil, "notyou" end
	book.invites[inv.id] = nil
	if answer == false then book.declined[pair(inv.from, inv.to)] = now end
	return inv, nil
end

-- Someone left: their invites go.
function RideTogether.forget(book: any, userId: number)
	for id, inv in book.invites do
		if inv.from == userId or inv.to == userId then book.invites[id] = nil end
	end
	book.sent[userId] = nil
	book.received[userId] = nil
end

return RideTogether
