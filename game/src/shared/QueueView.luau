--!strict
-- QueueView (D-061 stage 2): what the queue card shows, from the server's queue events. Pure, so
-- Lune tests it; QueueCard.client.luau draws it.
--   QueueStatus (in line?, riders, seconds or nil, course or nil) -> QueueView.status
--   QueueGate (course or nil, riders {name, coat, user}, lanes, seconds or nil, racing) -> QueueView.gate
--   RaceTime (course) -> QueueView.raceTime: the gate is full or the countdown hit 0
-- Phases: "hidden"; "waiting" (in your league's line, no course yet); "next" (in a course's line
-- while its race runs); "countdown" (the gate fills, bots join at 0); "racetime" ("Race time!",
-- kept for raceTimeSeconds even after the server says you've left the line to race).
-- Clocks are the caller's (os.clock on the client); nothing here reads one.

local QueueView = {}

export type Rider = { name: string, coat: string?, user: number? }
export type Slot = { filled: boolean, name: string?, coat: string?, you: boolean }
export type State = {
	inLine: boolean,
	course: string?,
	riders: { Rider },
	lanes: number,
	deadline: number?,   -- the caller's clock when the countdown reaches 0
	total: number,       -- the full countdown (lobbyFillSeconds), for the ring
	racing: boolean,     -- the course's race is running (you're in line for the next one)
	raceTimeUntil: number?,
}
export type View = {
	phase: string,
	seconds: number?,
	ring: number,        -- 1 = full ring (just started), 0 = empty (go); waiting phases keep it full
	title: string,
	subtitle: string,
	slots: { Slot },
	showLeave: boolean,
	showChoices: boolean,
}

function QueueView.new(lanes: number, total: number): State
	return { inLine = false, course = nil, riders = {}, lanes = lanes, deadline = nil, total = total, racing = false, raceTimeUntil = nil }
end

-- QueueStatus from the server.
function QueueView.status(s: State, isIn: boolean, _count: number?, seconds: number?, course: string?, now: number)
	s.inLine = isIn
	if not isIn then
		s.deadline = nil
		if not s.raceTimeUntil or now >= s.raceTimeUntil then
			s.riders, s.course, s.racing = {}, nil, false
		end
		return
	end
	s.course = course
	QueueView.setSeconds(s, seconds, now)
end

-- The server rounds the countdown up to whole seconds; keep a smooth local deadline unless it
-- drifts by more than a second (a new countdown, or a lag spike).
function QueueView.setSeconds(s: State, seconds: number?, now: number)
	if seconds == nil then
		s.deadline = nil
		return
	end
	local d = now + math.max(0, seconds)
	if not s.deadline or math.abs(s.deadline - d) > 1 then s.deadline = d end
end

-- QueueGate from the server: who is in your gate (or your league's line), and the countdown.
function QueueView.gate(s: State, course: string?, riders: { Rider }?, lanes: number?, seconds: number?, racing: boolean?, now: number)
	s.course = course
	s.riders = riders or {}
	if lanes and lanes > 0 then s.lanes = lanes end
	s.racing = racing == true
	QueueView.setSeconds(s, seconds, now)
end

-- RaceTime from the server: the gate filled. "Race time!" shows for `holdSeconds`.
function QueueView.raceTime(s: State, course: string?, holdSeconds: number, now: number)
	s.course = course or s.course
	s.raceTimeUntil = now + holdSeconds
	s.deadline = nil
end

-- Your race has started (or the race-time call is over): back to hidden.
function QueueView.clear(s: State)
	s.inLine, s.course, s.riders, s.deadline, s.racing, s.raceTimeUntil = false, nil, {}, nil, false, nil
end

function QueueView.slots(s: State, me: number?): { Slot }
	local out: { Slot } = {}
	for i = 1, s.lanes do
		local r = s.riders[i]
		if r then
			table.insert(out, { filled = true, name = r.name, coat = r.coat, you = me ~= nil and r.user == me })
		else
			table.insert(out, { filled = false, name = nil, coat = nil, you = false })
		end
	end
	return out
end

function QueueView.view(s: State, me: number?, now: number): View
	local slots = QueueView.slots(s, me)
	if s.raceTimeUntil and now < s.raceTimeUntil then
		return { phase = "racetime", seconds = 0, ring = 0, title = "Race time!", subtitle = "GO! To the gate!",
			slots = slots, showLeave = false, showChoices = false }
	end
	if not s.inLine then
		return { phase = "hidden", seconds = nil, ring = 1, title = "", subtitle = "", slots = slots, showLeave = false, showChoices = false }
	end
	local full = #s.riders >= s.lanes
	if s.course == nil then
		return { phase = "waiting", seconds = nil, ring = 1, title = "Finding a race…",
			subtitle = "You race as soon as a course is free", slots = slots, showLeave = true, showChoices = true }
	end
	if s.racing or not s.deadline then
		return { phase = "next", seconds = nil, ring = 1, title = "You race next!",
			subtitle = "Right after this race", slots = slots, showLeave = true, showChoices = true }
	end
	local left = math.max(0, s.deadline - now)
	local ring = if s.total > 0 then math.clamp(left / s.total, 0, 1) else 0
	return { phase = "countdown", seconds = math.ceil(left), ring = ring, title = "Race starts soon!",
		subtitle = if full then "Full gate! Here we go" else "🤖 Bots join at 0", slots = slots, showLeave = true, showChoices = true }
end

return QueueView
