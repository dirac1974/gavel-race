--!strict
-- The Horse Book (D-063, stage 6 of docs/plans/horse-life-and-retention.md): a collection of
-- everything a player has found, each a grey silhouette until earned. Pure rules on a Profile,
-- tested under Lune. Pages: coats, rosettes (race places and training golds), courses, Cups,
-- Health Passport stamps (Spa included), Tour stamps (friends' barns, D-060), personal bests per
-- distance, and the monthly stamp cloths.
-- What's earned stays earned (p.book keeps it), so selling or retiring a horse never takes a
-- page away. Personal bests are private: best ride score (0-100, how you rode, ★) per distance;
-- "New best!" only when a ride beats an earlier best. Nothing here is ranked, sold or timed.

local Horse = if script then require(script.Parent.Horse) :: any else require("./Horse")
local Training = if script then require(script.Parent.Training) :: any else require("./Training")
local Spa = if script then require(script.Parent.Spa) :: any else require("./Spa")
local Style = if script then require(script.Parent.Style) :: any else require("./Style")

local HorseBook = {}

export type Entry = { id: string, label: string, emoji: string, earned: boolean }

HorseBook.COAT_LABELS = {
	bay = "Bay", chestnut = "Chestnut", grey = "Dapple grey", black = "Black", palomino = "Palomino",
	pinto = "Pinto", appaloosa = "Appaloosa", buckskin = "Buckskin", dun = "Dun", roan = "Roan",
	white = "White", chestnut_blaze = "Blaze",
}

-- Race places (prize ribbons, D-016) and training gold rosettes, one page.
HorseBook.PLACES = {
	{ id = "1", label = "1st place", emoji = "🥇" },
	{ id = "2", label = "2nd place", emoji = "🥈" },
	{ id = "3", label = "3rd place", emoji = "🥉" },
}
HorseBook.ROSETTE_LABELS = { speed = "Speed gold", accel = "Start gold", stamina = "Hill gold", grit = "Mud gold" }

-- Race tracks and the four training courses.
HorseBook.COURSES = {
	{ id = "dirt", label = "Dirt track", emoji = "🟫" },
	{ id = "turf", label = "Grass track", emoji = "🟩" },
	{ id = "train_speed", label = "Sprint Lane", emoji = "💨" },
	{ id = "train_accel", label = "Gate Break", emoji = "🚦" },
	{ id = "train_stamina", label = "Hill Climb", emoji = "⛰️" },
	{ id = "train_grit", label = "Mud Splash", emoji = "💦" },
}

-- Every league with a Cup (the top league has none).
HorseBook.CUPS = { "Rookie", "Bronze", "Silver", "Gold" }

HorseBook.DISTANCES = { "Sprint", "Mile", "Classic", "Marathon" }
HorseBook.DISTANCE_EMOJI = { Sprint = "🐇", Mile = "🐎", Classic = "🏅", Marathon = "🐢" }

HorseBook.MAX_TOUR_SHOWN = 24

-- The sticky sets in p.book, and which ids each may hold.
local KNOWN: { [string]: { [string]: boolean } } = { coats = {}, places = {}, rosettes = {}, courses = {}, cups = {}, passport = {} }
for _, c in Horse.COATS do KNOWN.coats[c] = true end
for _, e in HorseBook.PLACES do KNOWN.places[e.id] = true end
for _, s in Training.STATS do KNOWN.rosettes[s] = true end
for _, e in HorseBook.COURSES do KNOWN.courses[e.id] = true end
for _, l in HorseBook.CUPS do KNOWN.cups[l] = true end
for _, s in Training.STAMPS do KNOWN.passport[s] = true end
KNOWN.passport[Spa.STAMP] = true
HorseBook.KNOWN = KNOWN

local DIST_KNOWN: { [string]: boolean } = {}
for _, d in HorseBook.DISTANCES do DIST_KNOWN[d] = true end

-- Training course keys (Profile.COURSES and the old "grit") -> the stat whose course it is.
local function courseStat(course: string): string?
	if course == "speed" or course == "accel" or course == "stamina" then return course end
	if course == "grit" or string.sub(course, 1, 6) == "grit_w" then return "grit" end
	return nil
end

-- Bring p.book and p.bests to a clean shape (anything unknown is dropped).
function HorseBook.repair(p: any)
	local src = if typeof(p.book) == "table" then p.book else {}
	local book = {}
	for section, ids in KNOWN do
		local set = {}
		if typeof(src[section]) == "table" then
			for id, v in src[section] do
				if v == true and typeof(id) == "string" and ids[id] then set[id] = true end
			end
		end
		book[section] = set
	end
	p.book = book
	local bests = {}
	if typeof(p.bests) == "table" then
		for d, v in p.bests do
			local n = tonumber(v)
			if typeof(d) == "string" and DIST_KNOWN[d] and n and n == n then bests[d] = math.clamp(math.floor(n), 0, 100) end
		end
	end
	p.bests = bests
end

local function ensure(p: any)
	if typeof(p.book) ~= "table" or typeof(p.bests) ~= "table" then HorseBook.repair(p) end
	for section in KNOWN do
		if typeof(p.book[section]) ~= "table" then p.book[section] = {} end
	end
end

-- Mark something found. Returns true when it is new. Unknown sections or ids are ignored.
function HorseBook.record(p: any, section: string, id: string): boolean
	ensure(p)
	local ids = KNOWN[section]
	if not ids or not ids[id] or p.book[section][id] then return false end
	p.book[section][id] = true
	return true
end

-- Copy what the player's horses have earned into the book (coats, training golds and courses,
-- Health Passport stamps). Safe to call on every sync; it only ever adds.
function HorseBook.sync(p: any)
	ensure(p)
	for _, h in (if typeof(p.horses) == "table" then p.horses else {}) do
		if typeof(h) == "table" then
			if typeof(h.coat) == "string" then HorseBook.record(p, "coats", h.coat) end
			if typeof(h.ribbons) == "table" then
				for course, ribbon in h.ribbons do
					local stat = typeof(course) == "string" and courseStat(course)
					if stat then
						HorseBook.record(p, "courses", "train_" .. stat)
						if ribbon == "gold" then HorseBook.record(p, "rosettes", stat) end
					end
				end
			end
			if typeof(h.stamps) == "table" then
				for s, v in h.stamps do
					if v == true and typeof(s) == "string" then HorseBook.record(p, "passport", s) end
				end
			end
		end
	end
end

-- A ride's score at a distance. Returns (new best?, the earlier best or nil). The first ride at a
-- distance sets the best quietly; only beating an earlier best is "New best!".
function HorseBook.recordBest(p: any, distance: string, score: number): (boolean, number?)
	ensure(p)
	if not DIST_KNOWN[distance] or typeof(score) ~= "number" or score ~= score then return false, nil end
	local s = math.clamp(math.floor(score + 0.5), 0, 100)
	local prev = p.bests[distance]
	if prev == nil then
		p.bests[distance] = s
		return false, nil
	end
	if s > prev then
		p.bests[distance] = s
		return true, prev
	end
	return false, prev
end

-- Stars for a ride score, as on the results card (RaceService).
function HorseBook.stars(score: number): number
	return if score >= 85 then 3 elseif score >= 65 then 2 elseif score >= 40 then 1 else 0
end

local function entries(list: { { id: string, label: string, emoji: string } }, set: { [string]: boolean }): { Entry }
	local out = {}
	for _, e in list do table.insert(out, { id = e.id, label = e.label, emoji = e.emoji, earned = set[e.id] == true }) end
	return out
end

-- What the owner's client sees: pages in order, each with its entries.
function HorseBook.view(p: any): { [string]: any }
	ensure(p)
	local B = p.book
	local pages = {}
	local coats = {}
	for _, c in Horse.COATS do
		table.insert(coats, { id = c, label = HorseBook.COAT_LABELS[c] or c, emoji = "🐴", earned = B.coats[c] == true })
	end
	table.insert(pages, { id = "coats", title = "Coats", icon = "🐴", entries = coats })
	local rosettes = entries(HorseBook.PLACES, B.places)
	for _, s in Training.STATS do
		table.insert(rosettes, { id = "gold_" .. s, label = HorseBook.ROSETTE_LABELS[s] or s, emoji = Training.GAMES[s].emoji,
			earned = B.rosettes[s] == true })
	end
	table.insert(pages, { id = "rosettes", title = "Rosettes", icon = "🏵️", entries = rosettes })
	table.insert(pages, { id = "courses", title = "Courses", icon = "🗺️", entries = entries(HorseBook.COURSES, B.courses) })
	local cups = {}
	for _, l in HorseBook.CUPS do
		table.insert(cups, { id = l, label = l .. " Cup", emoji = "🏆", earned = B.cups[l] == true })
	end
	table.insert(pages, { id = "cups", title = "Cups", icon = "🏆", entries = cups })
	local passport = {}
	for _, s in Training.STAMPS do
		table.insert(passport, { id = s, label = Training.STAMP_LABELS[s], emoji = "🩺", earned = B.passport[s] == true })
	end
	table.insert(passport, { id = Spa.STAMP, label = Spa.STAMP_LABEL, emoji = "🫧", earned = B.passport[Spa.STAMP] == true })
	table.insert(pages, { id = "passport", title = "Passport", icon = "🩺", entries = passport })
	local cloths = {}
	local owned = (typeof(p.style) == "table" and typeof(p.style.owned) == "table") and p.style.owned or {}
	for m = 1, 12 do
		local it = Style.monthCloth(m)
		if it then table.insert(cloths, { id = it.id, label = it.name, emoji = it.emoji, earned = owned[it.id] == true }) end
	end
	table.insert(pages, { id = "cloths", title = "Cloths", icon = "🎀", entries = cloths })

	-- Tour stamps (D-060): friends whose barns you toured, newest first, a few shown.
	local tour = {}
	if typeof(p.tour) == "table" and typeof(p.tour.stamps) == "table" then
		for k, d in p.tour.stamps do
			if typeof(k) == "string" and tonumber(k) then table.insert(tour, { user = tonumber(k) :: number, day = tonumber(d) or 0 }) end
		end
	end
	table.sort(tour, function(a, b)
		if a.day ~= b.day then return a.day > b.day end
		return a.user < b.user
	end)
	local friends = {}
	for i = 1, math.min(#tour, HorseBook.MAX_TOUR_SHOWN) do table.insert(friends, tour[i].user) end

	local bests = {}
	for _, d in HorseBook.DISTANCES do
		local s = p.bests[d]
		table.insert(bests, { distance = d, emoji = HorseBook.DISTANCE_EMOJI[d], score = s, stars = if s then HorseBook.stars(s) else nil })
	end

	local got, total = 0, 0
	for _, page in pages do
		for _, e in page.entries do
			total += 1
			if e.earned then got += 1 end
		end
	end
	return { pages = pages, tour = { count = #tour, friends = friends }, bests = bests, got = got, total = total }
end

return HorseBook
