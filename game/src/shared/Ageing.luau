--!strict
-- Ageing (fun-and-return 2026-10-12, systems rulings): life stages and the gentle Veteran decline,
-- counted in races (Practice never counts). Pure rules, tested under Lune; mirrors src/life_arc.py
-- exactly (tests/fixtures/ageing.json).
--   Young · Prime · Veteran · Legend. Decline waits for the horse's peak: h.ageing.declineFrom is
--   stored (Ageing.updateDeclineFrom) the first time the horse has ageing.veteranAt counted races
--   AND stats at ageing.peakShare of Potential, and is never un-set. Steps count from it. The
--   decline only changes the Rating a horse races with in rated races (Ageing.racedRating); never
--   Practice, League Points, ceilings (bestRating) or stats.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")

local Ageing = {}

Ageing.STATS = { "speed", "accel", "stamina", "grit" }

local function cfgOf(cfg: any?): any
	return cfg or GameConfig.ageing
end

local function races(n: any): number
	local x = tonumber(n)
	if x == nil or x ~= x or x <= 0 then return 0 end
	return math.floor(math.min(x, 1e9))
end

function Ageing.stage(n: any, legend: boolean?, cfg: any?): string
	local c = cfgOf(cfg)
	if legend then return "Legend" end
	local r = races(n)
	if r < c.youngRaces then return "Young" end
	return if r < c.veteranAt then "Prime" else "Veteran"
end

-- Mean of stat / Potential over the four stats (a stat with no Potential counts as full).
function Ageing.peakShare(stats: { [string]: number }, potential: { [string]: number }): number
	local sum = 0
	for _, k in Ageing.STATS do
		local pot = tonumber(potential[k]) or 0
		if pot <= 0 then
			sum += 1
		else
			sum += math.min(1, math.max(0, tonumber(stats[k]) or 0) / pot)
		end
	end
	return sum / #Ageing.STATS
end

function Ageing.atPeak(stats: { [string]: number }, potential: { [string]: number }, cfg: any?): boolean
	return Ageing.peakShare(stats, potential) >= cfgOf(cfg).peakShare - 1e-12
end

-- The stored declineFrom after a check at `n` counted races: unchanged once set.
function Ageing.updateDeclineFrom(declineFrom: number?, n: any, stats: { [string]: number }, potential: { [string]: number }, cfg: any?): number?
	if declineFrom ~= nil then return declineFrom end
	local c = cfgOf(cfg)
	local r = races(n)
	return if r >= c.veteranAt and Ageing.atPeak(stats, potential, c) then r else nil
end

local function startOf(declineFrom: number, c: any): number
	return math.max(races(declineFrom), c.veteranAt)
end

function Ageing.declineSteps(n: any, declineFrom: number?, cfg: any?): number
	if declineFrom == nil then return 0 end
	local c = cfgOf(cfg)
	local r, start = races(n), startOf(declineFrom, c)
	if r < start then return 0 end
	return math.min(c.declineCap, (r - start) // c.declinePer)
end

-- Race Rating change (<= 0) for a horse with `n` counted races before this race.
function Ageing.ratingOffset(n: any, declineFrom: number?, cfg: any?): number
	local steps = Ageing.declineSteps(n, declineFrom, cfg)
	return if steps > 0 then -cfgOf(cfg).declineScale * steps else 0
end

function Ageing.racedRating(rating: number, n: any, declineFrom: number?, practice: boolean?, cfg: any?): number
	if practice then return rating end
	return rating + Ageing.ratingOffset(n, declineFrom, cfg)
end

-- Counted races until the next decline step, or nil (decline off, not at its peak yet, or capped).
function Ageing.racesToNextStep(n: any, declineFrom: number?, cfg: any?): number?
	local c = cfgOf(cfg)
	if c.declineScale <= 0 or declineFrom == nil then return nil end
	local r = races(n)
	local steps = Ageing.declineSteps(r, declineFrom, c)
	if steps >= c.declineCap then return nil end
	return startOf(declineFrom, c) + (steps + 1) * c.declinePer - r
end

function Ageing.declineWarning(n: any, declineFrom: number?, cfg: any?): boolean
	local left = Ageing.racesToNextStep(n, declineFrom, cfg)
	return left ~= nil and left >= 1 and left <= cfgOf(cfg).warnAhead
end

function Ageing.veteranSoon(n: any, cfg: any?): boolean
	local c = cfgOf(cfg)
	local left = c.veteranAt - races(n)
	return left >= 1 and left <= c.warnAhead
end

function Ageing.trainMult(n: any, cfg: any?): number
	local c = cfgOf(cfg)
	return if races(n) < c.youngRaces then c.youngTrainMult else 1
end

-- On a horse record (fun-and-return phase 4, D-078) -------------------------------------------------
Ageing.STAGES = { "Young", "Prime", "Veteran", "Legend" }
Ageing.EMOJI = { Young = "🍼", Prime = "💪", Veteran = "🦉", Legend = "👑" }

-- h.ageing = { declineFrom = n? }: repaired on load (older saves have none: not at its peak yet).
function Ageing.ensure(h: any): any
	local a = if typeof(h.ageing) == "table" then h.ageing else {}
	local f = tonumber(a.declineFrom)
	a.declineFrom = if f and f == f and f >= 0 and f < 1e9 then math.floor(f) else nil
	h.ageing = a
	return a
end

function Ageing.declineFromOf(h: any): number?
	return Ageing.ensure(h).declineFrom
end

-- After a counted race: store declineFrom the first time the horse is a Veteran at its peak.
function Ageing.note(h: any, cfg: any?): number?
	local a = Ageing.ensure(h)
	a.declineFrom = Ageing.updateDeclineFrom(a.declineFrom, h.record and h.record.races or 0, h.stats or {}, h.potential or {}, cfg)
	return a.declineFrom
end

-- What the owner's card shows: the stage, "Veteran in N races" (veteranSoon), the kind warning 10
-- races before the first decline step, "at full strength" once declineFrom is stored (before any
-- step), and the steps taken. Never a Rating number.
function Ageing.view(h: any, cfg: any?): { [string]: any }
	local c = cfgOf(cfg)
	local n = races(h.record and h.record.races or 0)
	local from = Ageing.declineFromOf(h)
	local steps = if c.declineScale > 0 then Ageing.declineSteps(n, from, c) else 0
	local warn = steps == 0 and Ageing.declineWarning(n, from, c)
	return {
		stage = Ageing.stage(n, h.legend ~= nil and h.legend ~= false, c),
		toVeteran = if Ageing.veteranSoon(n, c) then c.veteranAt - n else nil,
		warning = warn,
		peak = from ~= nil and steps == 0 and not warn,
		steps = steps,
		young = n < c.youngRaces,
	}
end

-- Kind words (the copy test reads these).
function Ageing.warnLines(name: string): (string, string)
	return "🦉 " .. name .. " is getting wise", "Soon a little slower"
end
function Ageing.peakLine(name: string): string
	return "💪 " .. name .. " is at full strength!"
end
Ageing.WISE_LINE = "🦉 Wise and steady"
Ageing.YOUNG_LINE = "🍼 Young: training grows faster!"
Ageing.PRACTICE_LINE = "Equal in Practice!"

return Ageing
