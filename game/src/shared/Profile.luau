--!strict
-- Player profile (D-037): everything a player owns, saved as one DataStore key per player
-- (docs/research/2026-10-04-world-structure.md: 4 MB per key, prefer UpdateAsync). Pure, so
-- it runs under Lune; the server's ProfileStore does the loading, locking and saving.
-- Green Cash is earned only (D-002). Items are counts by name. Horses are small records
-- (Horse.luau). Stalls start at 2 and Green Cash buys more, up to 6; extra horses live in
-- the free pasture (can't race until stalled).

-- Roblox requires by instance; Lune (tests) by path.
local Horse = if script then require(script.Parent.Horse) :: any else require("./Horse")
local HorseBook = if script then require(script.Parent.HorseBook) :: any else require("./HorseBook")
local Career = if script then require(script.Parent.Career) :: any else require("./Career")

local Profile = {}

Profile.VERSION = 1
Profile.START_CASH = 50
Profile.START_ITEMS = { hay = 10, carrot = 3, seed_carrot = 2 }
Profile.SEEDS = { seed_carrot = true, seed_apple = true, seed_oats = true } -- garden beds accept only these
Profile.START_STALLS = 2
Profile.MAX_STALLS = 6
Profile.ITEMS = { "hay", "grain", "carrot", "apple", "oats", "treat", "seed_carrot", "seed_apple", "seed_oats" }

export type Profile = {
	version: number,
	created: number,
	lastSeen: number,
	cash: number,
	items: { [string]: number },
	horses: { Horse.Horse },
	activeHorse: string?,
	stalls: number,
	nextHorseId: number,
	days: { played: number, last: number },
	totals: { races: number, wins: number, cashEarned: number },
	settings: { visits: string, sound: boolean?, easyRein: boolean, shareGhost: boolean, smartSteer: boolean },
	flags: { [string]: boolean },
	garden: { { seed: string, at: number } },
	chores: { [string]: number },
	tour: Tour,
	postBox: { day: number, today: number, total: number },
}

-- Visiting friends' barns (D-060), on the visitor's profile: a Tour stamp per friend whose
-- horses you've all patted (kept, at most MAX_TOUR_STAMPS), and today's pats, treats and
-- carrots per friend (only today's are kept). Keys are friends' user ids as strings.
export type Tour = {
	stamps: { [string]: number },              -- friend -> day the stamp was earned
	day: number,                               -- the day the three maps below belong to
	patted: { [string]: { [string]: boolean } }, -- friend -> horse ids patted today
	treats: { [string]: number },              -- friend -> treats given today
	carrots: { [string]: number },             -- friend -> carrots dropped today
}

Profile.BEDS = 3
Profile.MAX_TOUR_STAMPS = 200
Profile.MAX_TOUR_FRIENDS = 50 -- friends a day in the patted, treats and carrots maps

function Profile.emptyTour(day: number): Tour
	return { stamps = {}, day = day, patted = {}, treats = {}, carrots = {} }
end

function Profile.emptyGarden(): { { seed: string, at: number } }
	local g = {}
	for i = 1, Profile.BEDS do g[i] = { seed = "", at = 0 } end
	return g
end

function Profile.new(now: number): Profile
	return {
		version = Profile.VERSION,
		created = now,
		lastSeen = now,
		cash = Profile.START_CASH,
		items = table.clone(Profile.START_ITEMS),
		horses = {},
		activeHorse = nil,
		stalls = Profile.START_STALLS,
		nextHorseId = 1,
		days = { played = 0, last = -1 },
		totals = { races = 0, wins = 0, cashEarned = 0 },
		-- Easy Rein (D-053): steering help on training courses; shareGhost: friends may see your ghosts;
		-- Smart Steer (D-054): your race horse heads for the rail by itself, on until turned off
		settings = { visits = "Friends", easyRein = false, shareGhost = false, smartSteer = true },
		flags = {},
		garden = Profile.emptyGarden(),
		chores = {},
		diamonds = 0,
		style = { owned = {}, equipped = {} },
		receipts = {},
		tour = Profile.emptyTour(now // 86400),
		postBox = { day = now // 86400, today = 0, total = 0 },
		stallMap = 1,  -- stalls stored per horse (D-059)
		rehomed = {},  -- horses at Sunny Meadow Riding School that can still come back (D-059)
		hallOfFame = {},
	}
end

-- Training rides (D-053): per horse, the best ribbon and the best run on each course.
--   h.ribbons[course] = "bronze" | "silver" | "gold"
--   h.trainingBest[course] = { score = 0..100, seconds = ride time }
-- Each Mud Splash layout is its own course (T5, "This week's course"): grit_w1..grit_w4
-- (TrainingCourses.LAYOUTS; a world test keeps these lists the same). The single Mud Splash of
-- T2-T4 was saved as "grit"; it is layout 1, so "grit" and "grit_w1" name the same course:
-- a load gives both the better ribbon and run of the two, and keeps "grit" so a T2-T4 server
-- still finds its Mud Splash ribbon.
-- Repair never erases a course it doesn't know (a newer build's, during a rolling update):
-- any other entry with a string key of up to MAX_KEY_LEN characters and a valid value passes
-- through, at most MAX_EXTRA_KEYS per map (alphabetical first); junk is dropped.
Profile.COURSES = { "speed", "accel", "stamina", "grit_w1", "grit_w2", "grit_w3", "grit_w4" }
Profile.COURSE_STAT = { speed = "speed", accel = "accel", stamina = "stamina", grit_w1 = "grit", grit_w2 = "grit", grit_w3 = "grit", grit_w4 = "grit" }
Profile.LEGACY_COURSES = { grit = "grit_w1" }
Profile.RIBBONS = { bronze = true, silver = true, gold = true }
Profile.MAX_KEY_LEN = 32
Profile.MAX_EXTRA_KEYS = 16
local RIBBON_RANK = { bronze = 1, silver = 2, gold = 3 }

local function cleanBest(b: any): { score: number, seconds: number }?
	local score = typeof(b) == "table" and tonumber(b.score)
	local seconds = typeof(b) == "table" and tonumber(b.seconds)
	if score and seconds and score == score and seconds == seconds then
		return { score = math.clamp(score, 0, 100), seconds = math.clamp(seconds, 0, 3600) }
	end
	return nil
end

local function betterBest(a: any, b: any?): boolean
	if not b then return true end
	if a.score ~= b.score then return a.score > b.score end
	return a.seconds < b.seconds
end

local function cleanRibbon(r: any): string?
	return if typeof(r) == "string" and Profile.RIBBONS[r] then r else nil
end

local function betterRibbon(a: any, b: any?): boolean
	return RIBBON_RANK[a] > (RIBBON_RANK[b] or 0)
end

local KNOWN: { [string]: boolean } = {}
for _, c in Profile.COURSES do KNOWN[c] = true end
for old in Profile.LEGACY_COURSES do KNOWN[old] = true end

-- One per-course map (ribbons or best runs), repaired. `clean` returns a fresh valid value or nil.
local function repairMap(src: any, clean: (any) -> any?, better: (any, any?) -> boolean): { [string]: any }
	local out = {}
	if typeof(src) ~= "table" then return out end
	for _, c in Profile.COURSES do out[c] = clean(src[c]) end
	-- an old name and its new one are the same course: both get the better of the two
	for old, new in Profile.LEGACY_COURSES do
		local a, b = clean(src[old]), out[new]
		local pick = if a and better(a, b) then a else b
		out[new], out[old] = pick, if pick then clean(pick) else nil
	end
	-- courses this version doesn't know pass through (valid values, short string keys, a few)
	local extra = {}
	for k, v in src do
		if typeof(k) == "string" and not KNOWN[k] and #k >= 1 and #k <= Profile.MAX_KEY_LEN and clean(v) ~= nil then
			table.insert(extra, k)
		end
	end
	table.sort(extra)
	for i = 1, math.min(#extra, Profile.MAX_EXTRA_KEYS) do out[extra[i]] = clean(src[extra[i]]) end
	return out
end

function Profile.repairTraining(h: any)
	h.ribbons = repairMap(h.ribbons, cleanRibbon, betterRibbon)
	h.trainingBest = repairMap(h.trainingBest, cleanBest, betterBest)
end

-- The stall's gold rosettes (D-053): one per stat whose course has a gold ribbon, in stat
-- order. Mud Splash has one rosette for a gold on any of its layouts (T5).
function Profile.rosettes(h: any): { string }
	local golds = {}
	if typeof(h.ribbons) == "table" then
		for course, stat in Profile.COURSE_STAT do
			if h.ribbons[course] == "gold" then golds[stat] = true end
		end
	end
	local out = {}
	for _, stat in Horse.STATS do
		if golds[stat] then table.insert(out, stat) end
	end
	return out
end

-- Load whatever was saved (nil for a new player) and bring it to the current version,
-- repairing anything missing or out of range.
function Profile.migrate(data: any, now: number): Profile
	if typeof(data) ~= "table" then return Profile.new(now) end
	local p = data
	p.version = Profile.VERSION
	p.created = tonumber(p.created) or now
	p.lastSeen = tonumber(p.lastSeen) or now
	p.cash = math.max(0, math.floor(tonumber(p.cash) or Profile.START_CASH))
	local items = {}
	if typeof(p.items) == "table" then
		for _, k in Profile.ITEMS do
			local n = tonumber(p.items[k])
			if n and n > 0 then items[k] = math.floor(n) end
		end
	end
	p.items = items
	local horses = {}
	if typeof(p.horses) == "table" then
		for _, h in p.horses do
			if typeof(h) == "table" and typeof(h.id) == "string" then
				local fixed = Horse.repair(h, now)
				Profile.repairTraining(fixed)
				table.insert(horses, fixed)
			end
		end
	end
	p.horses = horses
	p.stalls = math.clamp(math.floor(tonumber(p.stalls) or Profile.START_STALLS), Profile.START_STALLS, Profile.MAX_STALLS)
	Profile.repairStalls(p)
	Profile.fillStalls(p) -- a stall a load cleared takes the first pasture horse
	if p.activeHorse and not Profile.horse(p, p.activeHorse) then p.activeHorse = nil end
	Profile.fixActive(p)
	p.nextHorseId = math.max(math.floor(tonumber(p.nextHorseId) or 1), #horses + 1)
	p.days = if typeof(p.days) == "table" then p.days else {}
	p.days.played = tonumber(p.days.played) or 0
	p.days.last = tonumber(p.days.last) or -1
	p.totals = if typeof(p.totals) == "table" then p.totals else {}
	for _, k in { "races", "wins", "cashEarned" } do p.totals[k] = tonumber(p.totals[k]) or 0 end
	p.settings = if typeof(p.settings) == "table" then p.settings else {}
	if not table.find({ "Friends", "Club", "Nobody" }, p.settings.visits) then p.settings.visits = "Friends" end
	p.settings.easyRein = p.settings.easyRein == true
	p.settings.shareGhost = p.settings.shareGhost == true
	if typeof(p.settings.smartSteer) ~= "boolean" then p.settings.smartSteer = true end -- on unless turned off
	p.flags = if typeof(p.flags) == "table" then p.flags else {}
	local garden = Profile.emptyGarden()
	if typeof(p.garden) == "table" then
		for i = 1, Profile.BEDS do
			local b = p.garden[i]
			if typeof(b) == "table" and typeof(b.seed) == "string" and (b.seed == "" or Profile.SEEDS[b.seed]) then
				garden[i] = { seed = b.seed, at = tonumber(b.at) or 0 }
			end
		end
	end
	p.garden = garden
	local chores = {}
	if typeof(p.chores) == "table" then
		for k, v in p.chores do
			if tonumber(k) and tonumber(v) then chores[tostring(k)] = tonumber(v) end
		end
	end
	p.chores = chores
	-- Diamonds (D-050): bought or earned, spent only on cosmetics.
	p.diamonds = math.max(0, math.floor(tonumber(p.diamonds) or 0))
	p.style = if typeof(p.style) == "table" then p.style else {}
	p.style.owned = if typeof(p.style.owned) == "table" then p.style.owned else {}
	p.style.equipped = if typeof(p.style.equipped) == "table" then p.style.equipped else {}
	p.receipts = if typeof(p.receipts) == "table" then p.receipts else {}
	Profile.repairVisits(p, now)
	HorseBook.repair(p) -- the Horse Book and personal bests (D-063)
	Profile.repairCareers(p, now)
	return p :: Profile
end

-- Careers and rehoming (D-059): the starter is marked (older saves: the first horse, h1, when the
-- starter was picked); the Hall of Fame list and the horses waiting at the riding school are
-- repaired, and horses whose undo window has closed leave for good.
Profile.MAX_PLAQUES = 50
function Profile.repairCareers(p: any, now: number)
	local hasStarter = false
	for _, h in p.horses do
		if h.origin == "starter" then hasStarter = true end
	end
	if not hasStarter and p.flags and p.flags.starterPicked then
		local h1 = Profile.horse(p, "h1")
		if h1 and h1.origin == nil then h1.origin = "starter" end
	end
	local plaques = {}
	if typeof(p.hallOfFame) == "table" then
		for _, pl in p.hallOfFame do
			if typeof(pl) == "table" and typeof(pl.name) == "string" and #plaques < Profile.MAX_PLAQUES then
				for _, k in { "races", "wins", "places", "cash", "retired" } do pl[k] = tonumber(pl[k]) or 0 end
				pl.coat = if typeof(pl.coat) == "string" then pl.coat else "bay"
				pl.league = if typeof(pl.league) == "string" then pl.league else "Rookie"
				table.insert(plaques, pl)
			end
		end
	end
	p.hallOfFame = plaques
	local waiting = {}
	if typeof(p.rehomed) == "table" then
		for _, e in p.rehomed do
			local expires = typeof(e) == "table" and tonumber(e.expires)
			if expires and now < expires and typeof(e.horse) == "table" and typeof(e.horse.id) == "string"
				and not Profile.horse(p, e.horse.id) and #waiting < Career.cfgRehomeMax() then
				e.horse = Horse.repair(e.horse, now)
				e.horse.stall = nil
				e.cash = math.max(0, math.floor(tonumber(e.cash) or 0))
				e.at = tonumber(e.at) or now
				table.insert(waiting, e)
			end
		end
	end
	p.rehomed = waiting
	p.goodbyeRosettes = math.max(0, math.floor(tonumber(p.goodbyeRosettes) or 0))
end

local function userKey(k: any): boolean
	return typeof(k) == "string" and #k >= 1 and #k <= 20 and string.match(k, "^%d+$") ~= nil
end

local function countMap(src: any, limit: number): { [string]: number }
	local out, n = {}, 0
	if typeof(src) ~= "table" then return out end
	local keys = {}
	for k, v in src do
		if userKey(k) and tonumber(v) and (tonumber(v) :: number) >= 0 then table.insert(keys, k) end
	end
	table.sort(keys)
	for _, k in keys do
		if n >= limit then break end
		out[k] = math.floor(tonumber(src[k]) :: number)
		n += 1
	end
	return out
end

-- Visits (D-060): the visitor's Tour and the owner's post box, repaired; a new day clears
-- today's pats, treats and carrots (stamps stay).
function Profile.repairVisits(p: any, now: number)
	local today = now // 86400
	local t = if typeof(p.tour) == "table" then p.tour else {}
	local tour = Profile.emptyTour(today)
	tour.stamps = countMap(t.stamps, Profile.MAX_TOUR_STAMPS)
	if tonumber(t.day) == today then
		tour.treats = countMap(t.treats, Profile.MAX_TOUR_FRIENDS)
		tour.carrots = countMap(t.carrots, Profile.MAX_TOUR_FRIENDS)
		local n = 0
		if typeof(t.patted) == "table" then
			for k, ids in t.patted do
				if n >= Profile.MAX_TOUR_FRIENDS then break end
				if userKey(k) and typeof(ids) == "table" then
					local set = {}
					for id, v in ids do
						if typeof(id) == "string" and #id <= Profile.MAX_KEY_LEN and v == true then set[id] = true end
					end
					tour.patted[k] = set
					n += 1
				end
			end
		end
	end
	p.tour = tour
	local b = if typeof(p.postBox) == "table" then p.postBox else {}
	local total = math.max(0, math.floor(tonumber(b.total) or 0))
	local todayCount = if tonumber(b.day) == today then math.max(0, math.floor(tonumber(b.today) or 0)) else 0
	p.postBox = { day = today, today = todayCount, total = total }
end

function Profile.tourStampCount(p: any): number
	local n = 0
	if typeof(p.tour) == "table" and typeof(p.tour.stamps) == "table" then
		for _ in p.tour.stamps do n += 1 end
	end
	return n
end

-- Calendar (D-043): counts days played; missing days never resets anything.
-- Returns true the first time it's called on a new day.
function Profile.touchDay(p: Profile, now: number): boolean
	p.lastSeen = now
	local today = Horse.day(now)
	if p.days.last == today then return false end
	p.days.last = today
	p.days.played += 1
	return true
end

-- Wallet ------------------------------------------------------------------------
function Profile.addCash(p: Profile, amount: number)
	assert(amount >= 0, "use spendCash")
	p.cash += math.floor(amount)
	p.totals.cashEarned += math.floor(amount)
end

function Profile.spendCash(p: Profile, amount: number): boolean
	amount = math.floor(amount)
	if amount < 0 or p.cash < amount then return false end
	p.cash -= amount
	return true
end

function Profile.itemCount(p: Profile, item: string): number
	return p.items[item] or 0
end

function Profile.addItem(p: Profile, item: string, n: number)
	assert(table.find(Profile.ITEMS, item), "unknown item " .. item)
	p.items[item] = (p.items[item] or 0) + math.max(0, math.floor(n))
end

function Profile.takeItem(p: Profile, item: string, n: number): boolean
	local have = p.items[item] or 0
	if n <= 0 or have < n then return false end
	p.items[item] = if have - n > 0 then have - n else nil
	return true
end

-- Horses ------------------------------------------------------------------------
function Profile.horse(p: Profile, id: string?): Horse.Horse?
	if not id then return nil end
	for _, h in p.horses do
		if h.id == id then return h end
	end
	return nil
end

function Profile.activeHorse(p: Profile): Horse.Horse?
	return Profile.horse(p, p.activeHorse)
end

-- The horse a ride brings (D-059): a Legend when one is asked for by id (Legends are still
-- ridden for fun from the Hall of Fame paddock), otherwise the active horse.
function Profile.rideHorse(p: Profile, legendId: string?): Horse.Horse?
	local h = if legendId then Profile.horse(p, legendId) else nil
	if h and h.legend ~= nil then return h end
	return Profile.activeHorse(p)
end

function Profile.newHorseId(p: Profile): string
	local id = "h" .. p.nextHorseId
	p.nextHorseId += 1
	return id
end

-- Stalls (D-059, stage 7): each horse stores its own stall (h.stall, 1..stalls), so a horse that
-- leaves (a Legend, or rehomed) never shifts the others. A stall that comes free takes the first
-- pasture horse; a horse with no stall lives in the pasture (it can't race until stalled).
function Profile.stallHorse(p: Profile, k: number): Horse.Horse?
	for _, h in p.horses do
		if h.stall == k then return h end
	end
	return nil
end

function Profile.freeStall(p: Profile): number?
	for k = 1, p.stalls do
		if not Profile.stallHorse(p, k) then return k end
	end
	return nil
end

-- Horses in the pasture (not stalled, not Legends), in the order they came home.
function Profile.pasture(p: Profile): { Horse.Horse }
	local out = {}
	for _, h in p.horses do
		if h.stall == nil and h.legend == nil then table.insert(out, h) end
	end
	return out
end

function Profile.legends(p: Profile): { Horse.Horse }
	local out = {}
	for _, h in p.horses do
		if h.legend ~= nil then table.insert(out, h) end
	end
	return out
end

-- Horses that can race (not Legends).
function Profile.racers(p: Profile): number
	local n = 0
	for _, h in p.horses do
		if h.legend == nil then n += 1 end
	end
	return n
end

function Profile.isStalled(p: Profile, id: string): boolean
	local h = Profile.horse(p, id)
	return h ~= nil and h.stall ~= nil
end

-- Fill every free stall from the pasture (oldest first). Returns the horses moved in.
function Profile.fillStalls(p: Profile): { Horse.Horse }
	local moved = {}
	for _, h in Profile.pasture(p) do
		local k = Profile.freeStall(p)
		if not k then break end
		h.stall = k
		table.insert(moved, h)
	end
	return moved
end

-- The active horse is always a stalled one (or nil when none is).
function Profile.fixActive(p: Profile)
	if p.activeHorse and Profile.isStalled(p, p.activeHorse) then return end
	p.activeHorse = nil
	for k = 1, p.stalls do
		local h = Profile.stallHorse(p, k)
		if h then
			p.activeHorse = h.id
			return
		end
	end
end

function Profile.addHorse(p: Profile, h: Horse.Horse)
	table.insert(p.horses, h)
	h.stall = if h.legend == nil then Profile.freeStall(p) else nil
	if not p.activeHorse and h.stall then p.activeHorse = h.id end
end

-- Take a horse out of the stable list (rehoming): its stall fills from the pasture.
function Profile.removeHorse(p: Profile, id: string): Horse.Horse?
	for i, h in p.horses do
		if h.id == id then
			table.remove(p.horses, i)
			h.stall = nil
			Profile.fillStalls(p)
			Profile.fixActive(p)
			return h
		end
	end
	return nil
end

function Profile.setActive(p: Profile, id: string): boolean
	if not Profile.horse(p, id) or not Profile.isStalled(p, id) then return false end
	p.activeHorse = id
	return true
end

-- Swap a pasture horse into a stall (the stalled horse goes to the pasture). With stalledId nil
-- (or naming no stalled horse) a pasture horse moves into a free stall, if there is one.
function Profile.swapStall(p: Profile, stalledId: string?, pastureId: string): boolean
	local b = Profile.horse(p, pastureId)
	if not b or b.stall ~= nil or b.legend ~= nil then return false end
	local a = stalledId and Profile.horse(p, stalledId)
	if not a or a.stall == nil then
		local k = Profile.freeStall(p)
		if stalledId ~= nil or not k then return false end
		b.stall = k
		Profile.fixActive(p)
		return true
	end
	b.stall, a.stall = a.stall, nil
	if p.activeHorse == stalledId then p.activeHorse = pastureId end
	return true
end

-- Load-time repair of the stalls: an older save had no h.stall (the first `stalls` horses in the
-- list were stalled), so those take stalls in list order once (p.stallMap = 1 after). After that,
-- stalls out of range, shared or on a Legend are cleared; free stalls stay free.
function Profile.repairStalls(p: Profile)
	local pa = p :: any
	if pa.stallMap ~= 1 then
		local k = 0
		for _, h in p.horses do
			h.stall = nil
			if h.legend == nil and k < p.stalls then
				k += 1
				h.stall = k
			end
		end
		pa.stallMap = 1
		return
	end
	local taken = {}
	for _, h in p.horses do
		if h.stall and (h.legend ~= nil or h.stall > p.stalls or taken[h.stall]) then h.stall = nil end
		if h.stall then taken[h.stall] = true end
	end
end

-- Races -------------------------------------------------------------------------
-- Returns the horse's races before and after (career badges, D-059), or nil with no horse.
function Profile.recordRace(p: Profile, horseId: string, place: number, cash: number, points: number, now: number): (number?, number?)
	local h = Profile.horse(p, horseId)
	if cash > 0 then Profile.addCash(p, cash) end
	p.totals.races += 1
	if place == 1 then p.totals.wins += 1 end
	if not h then return nil, nil end
	local before = h.record.races
	Horse.recordRace(h, place, cash, points, now)
	return before, h.record.races
end

-- What the owner's client sees (no Potential unless revealed, nothing internal).
function Profile.view(p: Profile, now: number, energyCfg: Horse.EnergyConfig): { [string]: any }
	local horses = {}
	for _, h in p.horses do
		local v = Horse.view(h, now, energyCfg)
		v.stalled = h.stall ~= nil
		v.career = Career.view(h)
		table.insert(horses, v)
	end
	-- Horses at Sunny Meadow Riding School that can still come back (D-059): no clock, just "days".
	local rehomed = {}
	for _, e in (p :: any).rehomed or {} do
		if now < e.expires then
			table.insert(rehomed, { id = e.horse.id, name = e.horse.name, coat = e.horse.coat, cash = e.cash,
				daysLeft = math.max(1, math.ceil((e.expires - now) / 86400)) })
		end
	end
	return {
		cash = p.cash,
		items = table.clone(p.items),
		horses = horses,
		activeHorse = p.activeHorse,
		stalls = p.stalls,
		daysPlayed = p.days.played,
		totals = table.clone(p.totals),
		settings = table.clone(p.settings),
		flags = table.clone(p.flags),
		garden = (function()
			local g = {}
			for i, b in p.garden do g[i] = { seed = b.seed, at = b.at } end
			return g
		end)(),
		chores = table.clone(p.chores),
		diamonds = p.diamonds or 0,
		tourStamps = Profile.tourStampCount(p),
		postBox = {
			today = if p.postBox and p.postBox.day == now // 86400 then p.postBox.today else 0,
			total = if p.postBox then p.postBox.total else 0,
		},
		style = { owned = table.clone((p.style and p.style.owned) or {}), equipped = table.clone((p.style and p.style.equipped) or {}) },
		rehomed = rehomed,
		goodbyeRosettes = tonumber((p :: any).goodbyeRosettes) or 0,
	}
end

-- The owner's view with every decorator's fields (D-065): each decorator runs in pcall, so one
-- that throws is reported through onError (index, error) and skipped, and the view still goes out.
function Profile.decoratedView(p: Profile, now: number, energyCfg: Horse.EnergyConfig,
	decorators: { (any, any) -> () }, onError: ((number, any) -> ())?): { [string]: any }
	local view = Profile.view(p, now, energyCfg)
	for i, decorate in decorators do
		local ok, err = pcall(decorate, p, view)
		if not ok and onError then onError(i, err) end
	end
	return view
end

return Profile
