--!strict
-- Spa Day and rest cues (D-058, stage 4 of docs/plans/horse-life-and-retention.md). Pure rules on
-- horse records, tested under Lune.
--   Rest cues: a horse yawns at energy.yawnAt (1) and naps in the straw at energy.restingLabelAt
--   (0). Tired is happy-tired: nothing here is ever sore, hurt or ill (hard rule 3).
--   Spa Day at the Vet: hose, brush and towel, tapping only. Free, spa.perDay times per horse per
--   server day (UTC days, like care); then "Spa opens again tomorrow", never a countdown. Gives
--   +spa.energy Energy (never above the cap), a Health Passport stamp (counted in spaDays) and a
--   cosmetic shine on the horse's next race. Never bond, Rating or win chance.

local Horse = if script then require(script.Parent.Horse) :: any else require("./Horse")

local Spa = {}

Spa.STEPS = { "hose", "brush", "towel" }
Spa.STEP_TEXT = {
	hose = { emoji = "🚿", verb = "Rinse", tap = "TAP TO RINSE" },
	brush = { emoji = "🪮", verb = "Brush", tap = "TAP TO BRUSH" },
	towel = { emoji = "🧺", verb = "Dry", tap = "TAP TO DRY" },
}
Spa.STAMP = "spa"
Spa.STAMP_LABEL = "Spa Day"
Spa.CLOSED = "Spa opens again tomorrow"
Spa.AGAIN = "Let's try the Spa again!"
Spa.YAWN = "🥱 Yawn!"
Spa.NAP = "💤 Napping"

export type SpaConfig = { enabled: boolean, perDay: number, energy: number, minSeconds: number, shine: boolean, lagAllowance: number? }

local function today(now: number): number
	return now // 86400
end

local function ensure(h: any)
	if typeof(h.spa) ~= "table" then h.spa = { day = -1, count = 0 } end
	h.spa.day = tonumber(h.spa.day) or -1
	h.spa.count = math.max(0, math.floor(tonumber(h.spa.count) or 0))
	h.spaDays = math.max(0, math.floor(tonumber(h.spaDays) or 0))
	h.shine = h.shine == true
end
Spa.repair = ensure

-- Spa Days this horse has had today.
function Spa.usedToday(h: any, now: number): number
	ensure(h)
	return if h.spa.day == today(now) then h.spa.count else 0
end

function Spa.open(h: any, now: number, cfg: SpaConfig): boolean
	return cfg.enabled and Spa.usedToday(h, now) < cfg.perDay
end

-- Give a Spa Day. Returns (ok, message, energyGained).
function Spa.give(h: any, now: number, energyCfg: any, cfg: SpaConfig): (boolean, string, number)
	ensure(h)
	if not cfg.enabled then return false, "The Spa is closed today", 0 end
	if not Spa.open(h, now, cfg) then return false, Spa.CLOSED, 0 end
	local d = today(now)
	if h.spa.day ~= d then h.spa.day, h.spa.count = d, 0 end
	h.spa.count += 1
	h.spaDays += 1
	if h.stamps then h.stamps[Spa.STAMP] = true end
	local before = Horse.syncEnergy(h, now, energyCfg)
	Horse.addEnergy(h, cfg.energy, now, energyCfg)
	local gained = h.energy - before
	if cfg.shine then h.shine = true end
	if gained > 0 then
		return true, "✨ " .. h.name .. " is squeaky clean! +" .. gained .. " Energy", gained
	end
	return true, "✨ " .. h.name .. " is squeaky clean and full of Energy!", 0
end

-- The horse's look in its stall from its Energy: "nap" (lying in the straw with Zzz), "yawn",
-- or nil (standing, bright-eyed).
function Spa.restPose(energy: number, energyCfg: any): string?
	if energy <= (energyCfg.restingLabelAt or 0) then return "nap" end
	if energy <= (energyCfg.yawnAt or 1) then return "yawn" end
	return nil
end

-- Is every one of these horses napping? (Horse records; brings their Energy up to date.)
function Spa.allNapping(horses: { any }, now: number, energyCfg: any): boolean
	if #horses == 0 then return false end
	for _, h in horses do
		if Horse.syncEnergy(h, now, energyCfg) > (energyCfg.restingLabelAt or 0) then return false end
	end
	return true
end

function Spa.dreamLine(name: string): string
	return "Great day! " .. name .. "'s dreaming of tomorrow."
end

-- Take the shine for a race (it lasts one race). Returns whether the horse shines.
function Spa.takeShine(h: any): boolean
	ensure(h)
	local s = h.shine
	h.shine = false
	return s
end

-- Every line a kid can read from the Spa and the rest cues (the copy test reads these).
function Spa.copy(): { string }
	local out = { Spa.CLOSED, Spa.AGAIN, Spa.YAWN, Spa.NAP, Spa.STAMP_LABEL, Spa.dreamLine("Comet"),
		"🛁 Spa Day", "Hose, brush and dry. +1 Energy!", "Hose, brush and dry!", "Spa Day for Comet", "The Spa is closed today",
		"✨ Comet is squeaky clean! +1 Energy", "✨ Comet is squeaky clean and full of Energy!",
		"Spa Days happen at the Vet on Fair Street", "Give a horse a Spa Day", "Next: a Spa Day at the Vet",
		"All clean! Time to go" }
	for _, s in Spa.STEPS do
		table.insert(out, Spa.STEP_TEXT[s].verb)
		table.insert(out, Spa.STEP_TEXT[s].tap)
	end
	return out
end

return Spa
