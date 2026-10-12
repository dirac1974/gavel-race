--!strict
-- Legs and the vet (fun-and-return phase 3, D-077; David's decision: over-running can need the vet).
-- Pure rules on horse records, tested under Lune; the run rules mirror src/life_arc.py (run_after_race,
-- run_after_care, run_now, needs_vet, legs_warning) exactly.
--   h.legs = { run, raceAt, feedAt, groomAt, wraps, wrap, checks }
--   run: counted races in a row on this horse (Practice never counts). It only grows after the horse's
--   first legs.fromRaces counted races. At legs.warnAt the card shows "🧣 Worked hard! Cool-down soon"; at legs.runLimit
--   rated races wait for the Cool-down Check (Practice stays open).
--   Feed or groom: -legs.careLowers, once per kind per legs.careCooldownSeconds. legs.restSeconds with no
--   counted race on this horse, the Spa, a training session or the Cool-down Check reset it to 0.
--   It comes from over-running only, never from neglect: no illness, nothing permanent, nothing for sale,
--   never Rating, bond, Energy or cash. wraps: races left showing the Cool-down Check's wraps.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")

local Legs = {}

Legs.CHIP_WARN = "🧣 Worked hard! Cool-down soon"
Legs.CHIP_VET = "🩺 Vet check time!"
Legs.CHIP_FRESH = "Fresh legs!"
Legs.RACE_WORD = "🩺 VET CHECK"
Legs.STEPS = { "check", "hose", "wraps", "carrot" }
Legs.STEP_TEXT = {
	check = { emoji = "👀", title = "Check legs", tap = "Tap each leg" },
	hose = { emoji = "💧", title = "Cold hose", tap = "Tap to cool" },
	wraps = { emoji = "🧶", title = "Soft wraps", tap = "Pick a colour" },
	carrot = { emoji = "🥕", title = "Carrot!", tap = "Tap the carrot" },
}

local function cfgOf(cfg: any?): any
	return cfg or GameConfig.legs
end

local function num(x: any, default: number): number
	local n = tonumber(x)
	if n == nil or n ~= n or math.abs(n) == math.huge then return default end
	return n
end

local function races(n: any): number
	local x = tonumber(n)
	if x == nil or x ~= x or x <= 0 then return 0 end
	return math.floor(math.min(x, 1e9))
end

-- The pure run rules (life_arc.py) ---------------------------------------------------------------
-- The run after a counted race; racesAfter is the horse's counted races including it.
function Legs.runAfterRace(run: number, racesAfter: any, cfg: any?): number
	return if races(racesAfter) > cfgOf(cfg).fromRaces then run + 1 else 0
end

-- Feed or groom: -careLowers once per kind per careCooldownSeconds (pass that kind's last counted
-- time). Returns (run, counted).
function Legs.runAfterCare(run: number, lastCountedAt: number, now: number, cfg: any?): (number, boolean)
	local c = cfgOf(cfg)
	if now - lastCountedAt < c.careCooldownSeconds then return run, false end
	return math.max(0, run - c.careLowers), true
end

-- restSeconds without a counted race on this horse clears the run.
function Legs.runNow(run: number, lastRaceAt: number, now: number, cfg: any?): number
	return if now - lastRaceAt >= cfgOf(cfg).restSeconds then 0 else run
end

function Legs.needsVetRun(run: number, cfg: any?): boolean
	return run >= cfgOf(cfg).runLimit
end

function Legs.warningRun(run: number, cfg: any?): boolean
	local c = cfgOf(cfg)
	return c.warnAt <= run and run < c.runLimit
end

-- On a horse record ---------------------------------------------------------------------------------
-- Repair or create h.legs (older saves have none: a fresh run).
function Legs.ensure(h: any): any
	local l = if typeof(h.legs) == "table" then h.legs else {}
	l.run = math.clamp(math.floor(num(l.run, 0)), 0, 1000)
	l.raceAt = num(l.raceAt, 0)
	l.feedAt = num(l.feedAt, -1e9)
	l.groomAt = num(l.groomAt, -1e9)
	l.wraps = math.clamp(math.floor(num(l.wraps, 0)), 0, 100)
	l.wrap = if typeof(l.wrap) == "string" and #l.wrap <= 8 then l.wrap else nil
	l.checks = math.max(0, math.floor(num(l.checks, 0)))
	h.legs = l
	return l
end

-- The run now (the rest rule applied and saved).
function Legs.sync(h: any, now: number, cfg: any?): number
	local l = Legs.ensure(h)
	l.run = Legs.runNow(l.run, l.raceAt, now, cfg)
	return l.run
end

function Legs.enabled(cfg: any?): boolean
	return cfgOf(cfg).enabled ~= false
end

-- Does this horse need its Cool-down Check before a rated race?
function Legs.needsVet(h: any, now: number, cfg: any?): boolean
	if not Legs.enabled(cfg) then return false end
	return Legs.needsVetRun(Legs.sync(h, now, cfg), cfg)
end

function Legs.warning(h: any, now: number, cfg: any?): boolean
	if not Legs.enabled(cfg) then return false end
	return Legs.warningRun(Legs.sync(h, now, cfg), cfg)
end

-- After a counted race (h.record.races already includes it).
function Legs.afterRace(h: any, now: number, cfg: any?)
	local l = Legs.ensure(h)
	l.run = Legs.runAfterRace(Legs.sync(h, now, cfg), h.record and h.record.races or 0, cfg)
	l.raceAt = now
end

-- Feed or groom ("feed" | "groom"). Returns whether it lowered the run (once per kind per cooldown).
function Legs.care(h: any, kind: string, now: number, cfg: any?): boolean
	if kind ~= "feed" and kind ~= "groom" then return false end
	local l = Legs.ensure(h)
	local field = if kind == "feed" then "feedAt" else "groomAt"
	local run = Legs.sync(h, now, cfg)
	local after, counted = Legs.runAfterCare(run, l[field], now, cfg)
	if counted then
		l.run, l[field] = after, now
	end
	return counted
end

-- The Spa, a training session: a fresh run.
function Legs.reset(h: any)
	Legs.ensure(h).run = 0
end

-- The Cool-down Check is done: a fresh run, and wraps in `colour` (one of vetCheck.wraps) for the
-- next legs.wrapRaces races.
function Legs.vetDone(h: any, colour: string?, cfg: any?)
	local l = Legs.ensure(h)
	l.run = 0
	l.checks += 1
	local ok = false
	for _, c in GameConfig.vetCheck.wraps do
		if c == colour then ok = true end
	end
	l.wrap = if ok then colour else GameConfig.vetCheck.wraps[1]
	l.wraps = cfgOf(cfg).wrapRaces
end

-- A race starts (any race, Practice too): the wraps it shows, or nil; one race fewer to go.
function Legs.takeWrap(h: any): string?
	local l = Legs.ensure(h)
	if l.wraps <= 0 or not l.wrap then return nil end
	l.wraps -= 1
	return l.wrap
end

-- The wraps showing now (stall, rides), or nil.
function Legs.wrapNow(h: any): string?
	local l = Legs.ensure(h)
	return if l.wraps > 0 then l.wrap else nil
end

-- What the owner's card shows: the run as pips, its chip, and the wraps.
function Legs.view(h: any, now: number, cfg: any?): { [string]: any }
	local c = cfgOf(cfg)
	if not Legs.enabled(cfg) then return { enabled = false, run = 0, limit = c.runLimit } end
	local run = Legs.sync(h, now, cfg)
	local vet = Legs.needsVetRun(run, cfg)
	local warn = Legs.warningRun(run, cfg)
	return {
		enabled = true,
		run = math.min(run, c.runLimit),
		limit = c.runLimit,
		warn = warn,
		needsVet = vet,
		chip = if vet then Legs.CHIP_VET elseif warn then Legs.CHIP_WARN else Legs.CHIP_FRESH,
		wraps = Legs.ensure(h).wraps,
		wrap = Legs.wrapNow(h),
	}
end

-- Words a kid reads (the copy test and the hurt-word lint read these).
function Legs.vetLine(name: string): string
	return "🩺 " .. name .. " needs a vet check!"
end
Legs.REJECT = "🩺 Vet check first! Practice is open."
function Legs.freshLine(name: string): string
	return "🩺 " .. name .. " is fresh and ready!"
end

return Legs
