--!strict
-- RideTogether (D-053, T4): riding a training course with a Roblox friend. Pure rules, tested
-- under Lune; TrainingFriends (server) holds the live state.
--   canInvite(ctx) -> ok, reason: only Roblox friends, both with stable visits not "Nobody",
--     the friend near the training courses and free (not racing, not already riding).
--   The invite book: an invite is accept-only (the friend taps "Ride together" or it lapses
--   after INVITE_SECONDS); one pending invite per rider either way; an inviter waits GAP
--   seconds between invites and sends at most PER_WINDOW in WINDOW seconds.
-- No text of any kind travels with an invite: a course key and the inviter's Roblox name.

local RideTogether = {}

RideTogether.INVITE_SECONDS = 20
RideTogether.GAP = 8
RideTogether.WINDOW = 300
RideTogether.PER_WINDOW = 5
RideTogether.MAX_RIDERS = 2

export type Ctx = {
	friends: boolean,        -- Player:IsFriendsWith (cached)
	fromVisits: string?,     -- the inviter's "Who can visit my stable?" setting
	toVisits: string?,       -- the friend's
	toNear: boolean,         -- the friend is at the paddock, the path or the Training Ground
	toBusy: boolean,         -- the friend is racing, in line, riding a course or deciding on an invite
	same: boolean?,          -- inviting yourself
}

function RideTogether.canInvite(ctx: Ctx): (boolean, string?)
	if ctx.same then return false, "self" end
	if not ctx.friends then return false, "friends" end
	if ctx.fromVisits == "Nobody" or ctx.toVisits == "Nobody" then return false, "private" end
	if not ctx.toNear then return false, "far" end
	if ctx.toBusy then return false, "busy" end
	return true, nil
end

export type Invite = { id: number, from: number, to: number, course: string, at: number }

function RideTogether.book()
	return { invites = {} :: { [number]: Invite }, sent = {} :: { [number]: { number } }, nextId = 1 }
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

-- A new invite: returns its id, or nil and why ("gap", "many", "pending").
function RideTogether.invite(book: any, from: number, to: number, course: string, now: number): (number?, string?)
	RideTogether.sweep(book, now)
	local sent = book.sent[from] or {}
	book.sent[from] = sent
	local i = 1
	while i <= #sent do
		if now - sent[i] >= RideTogether.WINDOW then table.remove(sent, i) else i += 1 end
	end
	if #sent > 0 and now - sent[#sent] < RideTogether.GAP then return nil, "gap" end
	if #sent >= RideTogether.PER_WINDOW then return nil, "many" end
	if pendingFor(book, from) or pendingFor(book, to) then return nil, "pending" end
	local id = book.nextId
	book.nextId += 1
	book.invites[id] = { id = id, from = from, to = to, course = course, at = now }
	table.insert(sent, now)
	return id, nil
end

-- The friend's answer. Returns the invite if it was theirs and still open (accepted or not).
function RideTogether.reply(book: any, id: any, by: number, now: number): (Invite?, string?)
	RideTogether.sweep(book, now)
	local inv = typeof(id) == "number" and book.invites[id] or nil
	if not inv then return nil, "gone" end
	if inv.to ~= by then return nil, "notyou" end
	book.invites[inv.id] = nil
	return inv, nil
end

-- Someone left: their invites go.
function RideTogether.forget(book: any, userId: number)
	for id, inv in book.invites do
		if inv.from == userId or inv.to == userId then book.invites[id] = nil end
	end
	book.sent[userId] = nil
end

return RideTogether
