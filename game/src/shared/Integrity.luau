--!strict
-- Macro detection for Giddy-up stretches (D-022), reusable for Clap Along (D-020).
-- Pure. Evidence is the spread of gap errors (tap gap - beat gap): people are off by
-- 30-50 ms, beat-tracking bots by ~5 ms. Constant device lag cancels out of gaps.
--
-- A flag needs spread < maxSpreadSeconds over minBeats matched taps, across minRaces
-- races on minDays different days. Each flag is a strike and starts a fresh evidence
-- window, so the next strike needs new taps. Strikes expire after strikeExpiryDays.

export type Config = {
	logOnly: boolean,          -- first month: log, never act
	maxSpreadSeconds: number,
	minBeats: number,
	minRaces: number,
	minDays: number,
	warnAt: number,            -- strikes for the private note + race-average taps
	reviewAt: number,          -- strikes for human review, then a cash-race pause
	strikeExpiryDays: number,
}

export type Tracker = {
	n: number, sum: number, sumSq: number, -- gap errors in the current evidence window
	beats: number,
	races: number,
	days: { [number]: boolean },
	strikes: { number },                  -- day numbers of strikes
}

export type Action = "none" | "log" | "warn" | "review"

local Integrity = {}

function Integrity.new(): Tracker
	return { n = 0, sum = 0, sumSq = 0, beats = 0, races = 0, days = {}, strikes = {} }
end

function Integrity.addRace(tr: Tracker, gapErrors: { number }, matchedBeats: number, day: number)
	for _, e in gapErrors do
		tr.n += 1
		tr.sum += e
		tr.sumSq += e * e
	end
	tr.beats += matchedBeats
	tr.races += 1
	tr.days[day] = true
end

-- Population standard deviation of the gap errors (math.huge with fewer than 2).
function Integrity.spread(tr: Tracker): number
	if tr.n < 2 then return math.huge end
	local mean = tr.sum / tr.n
	return math.sqrt(math.max(0, tr.sumSq / tr.n - mean * mean))
end

function Integrity.dayCount(tr: Tracker): number
	local c = 0
	for _ in tr.days do c += 1 end
	return c
end

function Integrity.isSuspicious(tr: Tracker, cfg: Config): boolean
	return tr.beats >= cfg.minBeats
		and tr.races >= cfg.minRaces
		and Integrity.dayCount(tr) >= cfg.minDays
		and Integrity.spread(tr) < cfg.maxSpreadSeconds
end

function Integrity.activeStrikes(tr: Tracker, today: number, cfg: Config): number
	local c = 0
	for _, d in tr.strikes do
		if today - d < cfg.strikeExpiryDays then c += 1 end
	end
	return c
end

function Integrity.action(strikes: number, cfg: Config): Action
	if strikes <= 0 then return "none" end
	if cfg.logOnly then return "log" end
	if strikes >= cfg.reviewAt then return "review" end
	if strikes >= cfg.warnAt then return "warn" end
	return "log"
end

-- Call after addRace. Returns true if this race produced a new strike.
function Integrity.check(tr: Tracker, today: number, cfg: Config): boolean
	if not Integrity.isSuspicious(tr, cfg) then return false end
	table.insert(tr.strikes, today)
	tr.n, tr.sum, tr.sumSq, tr.beats, tr.races, tr.days = 0, 0, 0, 0, 0, {}
	return true
end

return Integrity
