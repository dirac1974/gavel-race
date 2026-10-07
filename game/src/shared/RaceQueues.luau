--!strict
-- RaceQueues (D-061 core, D-065; stage 1 of docs/plans/horse-life-and-retention.md): one queue
-- per league and race kind ("Rookie|race", "Bronze|cup", "Silver|practice"), so a rider is never
-- locked out by another league's card. RaceService owns the courses; this module only decides
-- who goes where, and works on plain tables so it is tested under Lune.
--   A course is { id, card = { league, cup, practice }, queue = { riders in its line },
--   current = the race running on it or nil }. A card with league = nil is open.
--   A rider joins their own queue (RaceQueues.join); pump moves riders into a course line:
--   first into a course whose card is already theirs and has room, then an open course with an
--   empty line goes to the longest-waiting queue (its card is claimed for that queue).
--   A claimed card never takes a rider of another league or kind.
-- Riders are opaque values (Players on the server, strings in tests).

local RaceQueues = {}

export type Waiting = { rider: any, at: number, want: string? }
export type Queue = { key: string, league: string, kind: string, riders: { Waiting } }
export type State = { queues: { [string]: Queue }, of: { [any]: string } }

function RaceQueues.new(): State
	return { queues = {}, of = {} }
end

function RaceQueues.key(league: string, kind: string): string
	return league .. "|" .. kind
end

-- The queue key a claimed card serves, or nil when it is open.
function RaceQueues.cardKey(card: any): string?
	if not card or card.league == nil then return nil end
	return RaceQueues.key(card.league, if card.cup then "cup" elseif card.practice then "practice" else "race")
end

-- Could a rider of this queue go into this course's line now? Its card is theirs with room, or it
-- is open with nobody in line.
function RaceQueues.canTake(c: any, key: string, lanes: number): boolean
	if #c.queue >= lanes then return false end
	local ck = RaceQueues.cardKey(c.card)
	if ck then return ck == key end
	return #c.queue == 0
end

-- The course a rider of this queue should go to, or nil (then they wait in their queue).
-- `want` is a course id the rider picked; it wins when it can take them. Otherwise a course
-- with no race running comes first (nobody waits through a race while a course sits idle): a
-- card already theirs (the fullest), then an open one; then the same order among courses whose
-- race is running (their next race).
function RaceQueues.bestCourse(courses: { [string]: any }, order: { string }, key: string, lanes: number, want: string?): any
	if want and courses[want] and RaceQueues.canTake(courses[want], key, lanes) then return courses[want] end
	local best, bestScore = nil, -math.huge
	for _, id in order do
		local c = courses[id]
		if c and RaceQueues.canTake(c, key, lanes) then
			local score = (if RaceQueues.cardKey(c.card) then 100 else 0) + #c.queue * 10 + (if c.current then -1000 else 0)
			if score > bestScore then best, bestScore = c, score end
		end
	end
	return best
end

-- Put a rider in the queue for (league, kind). Joining the queue they're already in keeps their
-- place (and updates the course they'd like); another queue starts a new wait.
function RaceQueues.join(state: State, rider: any, league: string, kind: string, now: number, want: string?)
	local key = RaceQueues.key(league, kind)
	if state.of[rider] == key then
		for _, w in state.queues[key].riders do
			if w.rider == rider then w.want = want end
		end
		return
	end
	RaceQueues.leave(state, rider)
	local q = state.queues[key]
	if not q then
		q = { key = key, league = league, kind = kind, riders = {} }
		state.queues[key] = q
	end
	table.insert(q.riders, { rider = rider, at = now, want = want })
	state.of[rider] = key
end

-- Take a rider out of their queue (if any). Returns true if they were waiting.
function RaceQueues.leave(state: State, rider: any): boolean
	local key = state.of[rider]
	if not key then return false end
	state.of[rider] = nil
	local q = state.queues[key]
	if q then
		for i, w in q.riders do
			if w.rider == rider then
				table.remove(q.riders, i)
				break
			end
		end
		if #q.riders == 0 then state.queues[key] = nil end
	end
	return true
end

function RaceQueues.isWaiting(state: State, rider: any): boolean
	return state.of[rider] ~= nil
end

-- How many riders wait in this rider's queue (them included), or 0.
function RaceQueues.waitingWith(state: State, rider: any): number
	local key = state.of[rider]
	local q = key and state.queues[key]
	return if q then #q.riders else 0
end

-- Queues by how long their first rider has waited, longest first (ties by key, so it's stable).
function RaceQueues.byWait(state: State): { Queue }
	local list = {}
	for _, q in state.queues do
		if #q.riders > 0 then table.insert(list, q) end
	end
	table.sort(list, function(a, b)
		if a.riders[1].at ~= b.riders[1].at then return a.riders[1].at < b.riders[1].at end
		return a.key < b.key
	end)
	return list
end

-- Move waiting riders into course lines. claim(course, league, kind) is called before an open
-- course takes its first rider (RaceService sets the card); moved(rider, course) after each move.
-- Returns the number of riders moved.
function RaceQueues.pump(state: State, courses: { [string]: any }, order: { string }, lanes: number,
	claim: (any, string, string) -> (), moved: ((any, any) -> ())?): number
	local count = 0
	for _, q in RaceQueues.byWait(state) do
		while #q.riders > 0 do
			local w = q.riders[1]
			local c = RaceQueues.bestCourse(courses, order, q.key, lanes, w.want)
			if not c then break end
			if RaceQueues.cardKey(c.card) == nil then claim(c, q.league, q.kind) end
			table.remove(q.riders, 1)
			state.of[w.rider] = nil
			table.insert(c.queue, w.rider)
			count += 1
			if moved then moved(w.rider, c) end
		end
		if #q.riders == 0 then state.queues[q.key] = nil end
	end
	return count
end

return RaceQueues
