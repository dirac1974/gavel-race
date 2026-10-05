--!strict
-- Spectators (D-019, D-020, D-041). Pure rules, tested under Lune.
--   Cheer: a spectator picks one horse before the first checkpoint closes. Free. Fan XP comes
--   from that rider's checkpoint and burst results (Perfect 3, Great 2, Good 1) plus a flat 2
--   if it wins, at most 11 a race and 100 a day. Never scaled by win chance; cosmetic only.
--   Clap Along: fans clap on their horse's hoofbeats. Each beat takes its nearest clap within
--   ±80 ms, scored 1 − |error| / 80 ms; every extra clap subtracts 1; fan score 0..100.
--   Crowd for a lane: D = min(1, s₁ + 0.15 s₂ + 0.10 s₃) over its three best fans (÷100), so
--   one great fan can max it, friends help, and a fourth adds nothing. Boost c = 0.03 · D joins
--   the live tilt exponent (κR + c): a full crowd lifts a 12.5% horse to about 12.8%.
--   Flagged (inhumanly steady) fans count zero for the rest of the race, quietly.

local Fans = {}

Fans.WINDOW = 0.08          -- ±80 ms
Fans.ASSISTS = { 1, 0.15, 0.10 }
Fans.BOOST = 0.03
Fans.XP_PER_RACE = 11
Fans.XP_PER_DAY = 100
Fans.XP_WIN = 2
Fans.XP_PER_LEVEL = 100
Fans.FLAG_SPREAD = 0.012    -- seconds; tap-gap vs beat-gap spread below this looks automatic
Fans.FLAG_MIN_BEATS = 48

-- XP for one result label (checkpoint or burst score).
function Fans.xpFor(score: number): number
	return if score >= 95 then 3 elseif score >= 80 then 2 elseif score >= 60 then 1 else 0
end

-- Fan XP for a race: the cheered rider's segment scores, plus a flat 2 for a win; capped per
-- race and by what's left of today's cap.
function Fans.raceXp(scores: { number }, won: boolean, todaySoFar: number): number
	local xp = 0
	for _, s in scores do xp += Fans.xpFor(s) end
	if won then xp += Fans.XP_WIN end
	xp = math.min(xp, Fans.XP_PER_RACE)
	return math.max(0, math.min(xp, Fans.XP_PER_DAY - todaySoFar))
end

function Fans.level(xp: number): number
	return 1 + xp // Fans.XP_PER_LEVEL
end

-- Clap Along score 0..100 for one fan: beats and claps are server times.
function Fans.clapScore(beats: { number }, claps: { number }): number
	if #beats == 0 then return 0 end
	local used: { [number]: boolean } = {}
	local total = 0
	for _, b in beats do
		local best, bestErr = nil, Fans.WINDOW
		for k, c in claps do
			if not used[k] then
				local e = math.abs(c - b)
				if e <= bestErr then best, bestErr = k, e end
			end
		end
		if best then
			used[best] = true
			total += 1 - bestErr / Fans.WINDOW
		end
	end
	local extra = 0
	for k in claps do
		if not used[k] then extra += 1 end
	end
	return math.max(0, 100 * (total - extra) / #beats)
end

-- Spread (s) of clap gaps against beat gaps, over consecutive matched beats; nil if too few.
function Fans.spread(beats: { number }, claps: { number }): number?
	local matched: { { number } } = {}
	local used: { [number]: boolean } = {}
	for _, b in beats do
		local best, bestErr = nil, Fans.WINDOW
		for k, c in claps do
			if not used[k] and math.abs(c - b) <= bestErr then best, bestErr = k, math.abs(c - b) end
		end
		if best then
			used[best] = true
			table.insert(matched, { b, claps[best] })
		end
	end
	if #matched < Fans.FLAG_MIN_BEATS then return nil end
	local diffs = {}
	for k = 2, #matched do
		table.insert(diffs, (matched[k][2] - matched[k - 1][2]) - (matched[k][1] - matched[k - 1][1]))
	end
	local mean = 0
	for _, d in diffs do mean += d end
	mean /= #diffs
	local var = 0
	for _, d in diffs do var += (d - mean) ^ 2 end
	return math.sqrt(var / #diffs)
end

function Fans.flagged(beats: { number }, claps: { number }): boolean
	local s = Fans.spread(beats, claps)
	return s ~= nil and s < Fans.FLAG_SPREAD
end

-- Crowd 0..1 for a lane from its fans' scores (0..100), flagged fans already removed.
function Fans.crowd(scores: { number }): number
	local sorted = table.clone(scores)
	table.sort(sorted, function(a, b) return a > b end)
	local d = 0
	for k, w in Fans.ASSISTS do
		if sorted[k] then d += w * sorted[k] / 100 end
	end
	return math.min(1, d)
end

function Fans.boost(crowd: number): number
	return Fans.BOOST * math.clamp(crowd, 0, 1)
end

-- Clap Along beats for a span: tempo per race, drifting a little each stride (macros can't
-- lock on). `rng` has NextNumber().
function Fans.beats(rng: any, t0: number, t1: number, interval: number, drift: number): { number }
	local out = {}
	local t = t0 + interval
	local step = interval
	while t < t1 do
		table.insert(out, t)
		step = math.clamp(step * (1 + (rng:NextNumber() * 2 - 1) * drift), interval * 0.85, interval * 1.15)
		t += step
	end
	return out
end

-- Top Fans: the best five by score, flagged fans left off, plus the viewer's own rank.
function Fans.topFans(entries: { { id: string, name: string, score: number, flagged: boolean } }): { any }
	local list = {}
	for _, e in entries do
		if not e.flagged and e.score > 0 then table.insert(list, e) end
	end
	table.sort(list, function(a, b) return a.score > b.score end)
	local out = {}
	for k = 1, math.min(5, #list) do out[k] = list[k] end
	return out
end

function Fans.rankOf(entries: { { id: string, score: number, flagged: boolean } }, id: string): number?
	local list = {}
	local mine = nil
	for _, e in entries do
		if e.id == id then mine = e end
		if not e.flagged and e.score > 0 then table.insert(list, e) end
	end
	if not mine or mine.score <= 0 then return nil end
	local rank = 1
	for _, e in list do
		if e.id ~= id and e.score > mine.score then rank += 1 end
	end
	return rank
end

return Fans
