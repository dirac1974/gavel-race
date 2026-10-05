--!strict
-- Horse records (D-037, D-038): what a player owns, saved in their profile. Pure, so it
-- runs under Lune. Times are os.time() seconds; days are whole UTC days (os.time() // 86400).
--   Energy (D-015): stored with the time it was last brought up to date; regenerates while
--   the player is away and never goes above the cap. It gates cash-race entry only.
--   Care: feeding and grooming each fill half of today's care; full care is the +5% Rating
--   bonus (D-014) until the day rolls over, then care is back to baseline (never below).
--   Bond 0..100 adds a small Rating bonus (D-014) and grows with care, rides and races.
--   Potential (one per stat) is hidden until the vet's Potential stamp reveals it (D-039).

local Horse = {}

Horse.STATS = { "speed", "accel", "stamina", "grit" }
Horse.COATS = { "bay", "chestnut", "grey", "black", "palomino", "pinto", "appaloosa", "buckskin", "dun", "roan", "white", "chestnut_blaze" }
Horse.STYLES = { "FrontRunner", "Stalker", "Closer" }

export type Stats = { speed: number, accel: number, stamina: number, grit: number }
export type Care = { day: number, fed: boolean, groomed: boolean, feedAt: number, groomAt: number }
export type Record = { races: number, wins: number, places: number, cash: number }
export type Horse = {
	id: string,
	name: string,
	coat: string,
	style: string,
	stats: Stats,
	potential: Stats,
	league: string,
	points: number,
	energy: number,
	energyAt: number,
	care: Care,
	bond: number,
	record: Record,
	stamps: { [string]: boolean },
	born: number,
	lastRaceAt: number,
	daily: { day: number, treats: number, petted: boolean },
}

export type EnergyConfig = { maxPerRacer: number, regenSeconds: number, careCooldownSeconds: number }

local function day(t: number): number
	return t // 86400
end
Horse.day = day

-- Starter horses (D-037): three coats, equal stats; Potential drawn per horse.
Horse.STARTERS = {
	{ coat = "bay", label = "Bay", blurb = "Brave and steady" },
	{ coat = "palomino", label = "Palomino", blurb = "Sunny and bold" },
	{ coat = "grey", label = "Dapple grey", blurb = "Calm and clever" },
}
Horse.STARTER_STAT = 45

function Horse.new(id: string, name: string, coat: string, stats: Stats, potential: Stats, now: number): Horse
	return {
		id = id,
		name = name,
		coat = coat,
		style = "Stalker",
		stats = table.clone(stats) :: Stats,
		potential = table.clone(potential) :: Stats,
		league = "Rookie",
		points = 0,
		energy = 5,
		energyAt = now,
		care = { day = day(now), fed = false, groomed = false, feedAt = 0, groomAt = 0 },
		bond = 0,
		record = { races = 0, wins = 0, places = 0, cash = 0 },
		stamps = {},
		born = now,
		lastRaceAt = 0,
		daily = { day = day(now), treats = 0, petted = false },
	}
end

-- A starter: equal stats, Potential 70-85 per stat. `rng` has NextInteger(lo, hi).
function Horse.starter(id: string, name: string, coat: string, rng: any, now: number): Horse
	local s = Horse.STARTER_STAT
	local pot = {}
	for _, k in Horse.STATS do pot[k] = rng:NextInteger(70, 85) end
	return Horse.new(id, name, coat, { speed = s, accel = s, stamina = s, grit = s }, pot :: any, now)
end

-- Energy ------------------------------------------------------------------------
-- Bring energy up to date (regen while away) and return it.
function Horse.syncEnergy(h: Horse, now: number, cfg: EnergyConfig): number
	if h.energy >= cfg.maxPerRacer then
		h.energy = cfg.maxPerRacer
		h.energyAt = now
		return h.energy
	end
	local elapsed = math.max(0, now - h.energyAt)
	local gained = elapsed // cfg.regenSeconds
	if gained > 0 then
		h.energy = math.min(cfg.maxPerRacer, h.energy + gained)
		h.energyAt = if h.energy >= cfg.maxPerRacer then now else h.energyAt + gained * cfg.regenSeconds
	end
	return h.energy
end

-- Seconds until the next point of energy (0 when full). Shown only as "Resting", never a timer.
function Horse.nextEnergyIn(h: Horse, now: number, cfg: EnergyConfig): number
	Horse.syncEnergy(h, now, cfg)
	if h.energy >= cfg.maxPerRacer then return 0 end
	return cfg.regenSeconds - (now - h.energyAt)
end

function Horse.spendEnergy(h: Horse, amount: number, now: number, cfg: EnergyConfig): boolean
	Horse.syncEnergy(h, now, cfg)
	if h.energy < amount then return false end
	local wasFull = h.energy >= cfg.maxPerRacer
	h.energy -= amount
	if wasFull then h.energyAt = now end -- regen starts from the spend
	return true
end

function Horse.addEnergy(h: Horse, amount: number, now: number, cfg: EnergyConfig)
	Horse.syncEnergy(h, now, cfg)
	h.energy = math.min(cfg.maxPerRacer, h.energy + amount)
	if h.energy >= cfg.maxPerRacer then h.energyAt = now end
end

-- Care --------------------------------------------------------------------------
local function rollCare(h: Horse, now: number)
	local today = day(now)
	if h.care.day ~= today then
		h.care.day, h.care.fed, h.care.groomed = today, false, false
	end
end

-- Today's care 0..1 (0.5 fed + 0.5 groomed). Back to 0 the next day, never below.
function Horse.care(h: Horse, now: number): number
	rollCare(h, now)
	return (if h.care.fed then 0.5 else 0) + (if h.care.groomed then 0.5 else 0)
end

-- Feed or groom ("feed" | "groom"). Returns (firstToday, energyTopUp): care fills once a
-- day; the +1 Energy top-up has its own cooldown (D-015).
function Horse.tend(h: Horse, kind: string, now: number, cfg: EnergyConfig, topUps: { [string]: number }): (boolean, boolean)
	rollCare(h, now)
	local first = false
	if kind == "feed" and not h.care.fed then
		h.care.fed, first = true, true
	elseif kind == "groom" and not h.care.groomed then
		h.care.groomed, first = true, true
	end
	local field = if kind == "feed" then "feedAt" else "groomAt"
	local careT = h.care :: any
	local topUp = false
	if now - (careT[field] :: number) >= cfg.careCooldownSeconds and (topUps[kind] or 0) > 0 then
		Horse.addEnergy(h, topUps[kind], now, cfg)
		careT[field] = now
		topUp = true
	end
	if first then Horse.addBond(h, 1) end
	return first, topUp
end

function Horse.addBond(h: Horse, amount: number)
	h.bond = math.clamp(h.bond + amount, 0, 100)
end

-- Rating (D-014) for these conditions, with today's care and bond. `RaceRating` is passed
-- in so this module stays dependency-free.
function Horse.rating(h: Horse, cond: any, now: number, RaceRating: any, pilotLevel: number?): number
	return RaceRating.rating(h.stats, cond, Horse.care(h, now), pilotLevel or 0, h.style, h.bond / 100)
end

-- Races -------------------------------------------------------------------------
function Horse.recordRace(h: Horse, place: number, cash: number, points: number, now: number)
	h.record.races += 1
	if place == 1 then h.record.wins += 1 end
	if place <= 3 then h.record.places += 1 end
	h.record.cash += cash
	h.points += points
	h.lastRaceAt = now
	Horse.addBond(h, 1)
end

-- What the owner's client may see: everything except Potential, unless revealed.
function Horse.view(h: Horse, now: number, cfg: EnergyConfig): { [string]: any }
	Horse.syncEnergy(h, now, cfg)
	return {
		id = h.id,
		name = h.name,
		coat = h.coat,
		style = h.style,
		stats = table.clone(h.stats),
		potential = if h.stamps.potential then table.clone(h.potential) else nil,
		league = h.league,
		points = h.points,
		energy = h.energy,
		resting = h.energy < cfg.maxPerRacer,
		care = Horse.care(h, now),
		fed = h.care.fed,
		groomed = h.care.groomed,
		bond = h.bond,
		treatsToday = if h.daily and h.daily.day == day(now) then h.daily.treats else 0,
		pettedToday = h.daily ~= nil and h.daily.day == day(now) and h.daily.petted,
		record = table.clone(h.record),
		stamps = table.clone(h.stamps),
	}
end

-- Repair a loaded record (missing fields from older saves, out-of-range values).
function Horse.repair(h: any, now: number): Horse
	h.stats = h.stats or {}
	h.potential = h.potential or {}
	for _, k in Horse.STATS do
		h.stats[k] = math.clamp(tonumber(h.stats[k]) or Horse.STARTER_STAT, 0, 100)
		h.potential[k] = math.clamp(tonumber(h.potential[k]) or 75, h.stats[k], 100)
	end
	if not table.find(Horse.COATS, h.coat) then h.coat = "bay" end
	if not table.find(Horse.STYLES, h.style) then h.style = "Stalker" end
	h.league = h.league or "Rookie"
	h.points = tonumber(h.points) or 0
	h.energy = math.clamp(tonumber(h.energy) or 5, 0, 5)
	h.energyAt = tonumber(h.energyAt) or now
	h.care = h.care or {}
	h.care.day = tonumber(h.care.day) or day(now)
	h.care.fed, h.care.groomed = h.care.fed == true, h.care.groomed == true
	h.care.feedAt, h.care.groomAt = tonumber(h.care.feedAt) or 0, tonumber(h.care.groomAt) or 0
	h.bond = math.clamp(tonumber(h.bond) or 0, 0, 100)
	h.record = h.record or {}
	for _, k in { "races", "wins", "places", "cash" } do h.record[k] = tonumber(h.record[k]) or 0 end
	h.stamps = h.stamps or {}
	h.born = tonumber(h.born) or now
	h.lastRaceAt = tonumber(h.lastRaceAt) or 0
	h.daily = if typeof(h.daily) == "table" then h.daily else {}
	h.daily.day = tonumber(h.daily.day) or day(now)
	h.daily.treats = math.max(0, math.floor(tonumber(h.daily.treats) or 0))
	h.daily.petted = h.daily.petted == true
	h.daily.pets = math.max(0, math.floor(tonumber(h.daily.pets) or 0))
	h.name = if typeof(h.name) == "string" and #h.name > 0 then string.sub(h.name, 1, 40) else "Comet"
	return h :: Horse
end

return Horse
