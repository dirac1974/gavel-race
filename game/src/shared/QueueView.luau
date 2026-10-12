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

-- The compact phone card's one line (AAA Phase 2, D-067): "Race in 12 · 3 riders".
-- Find it (D-075): with the line's short name (QueueView.lineShort) it names the line instead, and the
-- seconds stay in the ring beside it: "🟠 Bronze line · 3 riders".
function QueueView.compactLine(v: View, short: string?): string
	if v.phase == "racetime" then return "Race time! GO!" end
	local riders = 0
	for _, sl in v.slots do if sl.filled then riders += 1 end end
	local full = riders >= #v.slots and #v.slots > 0
	if short and short ~= "" then
		if v.phase == "countdown" then
			return if full then short .. " · full gate!" else string.format("%s · %d rider%s", short, riders, if riders == 1 then "" else "s")
		end
		return short
	end
	if v.phase == "countdown" then
		if full then return string.format("Race in %d · full gate!", v.seconds or 0) end
		return string.format("Race in %d · %d rider%s", v.seconds or 0, riders, if riders == 1 then "" else "s")
	end
	return v.title
end

-- Which line you're in, and why (Find it, D-075; David: "how does the queue work for each one?").
-- The server names your line in the player attribute LineKey (RaceQueues.key: "Bronze|race",
-- "Silver|cup", "Open|practice") and your horse in LineHorse. League colours are dots, as on the
-- race cards (Ui.leagueColors): 🥉 already means 3rd place and a bronze medal (one symbol per meaning, D-064).
QueueView.LEAGUE_DOT = { Rookie = "🟢", Bronze = "🟠", Silver = "⚪", Gold = "🟡", Champion = "🟣" }

-- "Bronze|race" -> "Bronze", "race"; nil or a malformed key -> nil, nil.
function QueueView.parseKey(key: string?): (string?, string?)
	if typeof(key) ~= "string" then return nil, nil end
	local league, kind = string.match(key, "^(%w+)|(%w+)$")
	if kind ~= "race" and kind ~= "cup" and kind ~= "practice" then return nil, nil end
	return league, kind
end

-- The full card's title: "🟠 Bronze race line", "🏆 Bronze Cup line", "🎈 Open Practice line".
function QueueView.lineTitle(key: string?): string
	local league, kind = QueueView.parseKey(key)
	if not league then return "" end
	if kind == "practice" then return if league == "Open" then "🎈 Open Practice line" else "🎈 " .. league .. " Practice line" end
	if kind == "cup" then return "🏆 " .. league .. " Cup line" end
	return (QueueView.LEAGUE_DOT[league :: string] or "🏁") .. " " .. league .. " race line"
end

-- Why you're in it, in 6 words or fewer: "Horses like Comet race here".
function QueueView.lineWhy(key: string?, horse: string?, equalPractice: boolean?): string
	local league, kind = QueueView.parseKey(key)
	if not league then return "" end
	if kind == "practice" then return if equalPractice then "Anyone! Horses all equal" else "Anyone can practice here" end
	if kind == "cup" then return "Only Cup horses" end
	return "Horses like " .. (if horse and horse ~= "" then horse else "yours") .. " race here"
end

-- The phone row's name: "🟠 Bronze line", "🏆 Cup line", "🎈 Practice line".
function QueueView.lineShort(key: string?): string
	local league, kind = QueueView.parseKey(key)
	if not league then return "" end
	if kind == "practice" then return "🎈 Practice line" end
	if kind == "cup" then return "🏆 Cup line" end
	return (QueueView.LEAGUE_DOT[league :: string] or "🏁") .. " " .. league .. " line"
end

-- The picker's Join button says which line it puts you in: "Join Bronze line".
function QueueView.joinWord(league: string?, kind: string?): string
	if kind == "practice" then return "Join Practice line" end
	if kind == "cup" then return "Join Cup line" end
	return "Join " .. (league or "Rookie") .. " line"
end

-- The warm-up slider's word for a practice tap (it counts nothing and is never sent anywhere).
-- Kind words only: "Early" and "Late" instead of a miss (the race's own rule, D-055).
function QueueView.warmWord(score: number, early: boolean): string
	if score >= 95 then return "Perfect!" end
	if score >= 80 then return "Great!" end
	if score >= 60 then return "Good!" end
	return if early then "Early" else "Late"
end

return QueueView
