--!strict
-- Stable Star goals and the Rosette Wall (D-062, stage 8 of docs/plans/horse-life-and-retention.md).
-- Pure rules on a Profile, tested under Lune.
--   Stable Star goal cards are private: care, collection and skill goals. Each finished goal hangs
--   a rosette in its kind's colour on the stable's Rosette Wall. No goal ever needs a win or a
--   place in a race (no luck tasks, D-043): they count care, things found for the Horse Book, and
--   how you ride (Great taps, Great Final Bursts, training golds).
--   The wall also shows a rosette in a league's colour for the first win in that league (any of
--   your horses), the Cups won (the Horse Book's Cup page) and Legend plaques. No number, no
--   ranking; visitors see the wall, never the cards.
-- p.stableStar = { counts = { [event] = n }, done = { [goalId] = true }, firsts = { [league] = true } }
-- What's earned stays earned: selling, rehoming or retiring a horse never takes a rosette down.

local StableStar = {}

export type Goal = {
	id: string, kind: string, text: string, icon: string, emoji: string, target: number,
	event: string?, book: string?,
}

StableStar.KINDS = { "care", "collection", "skill" }
-- Rosette colours, set in code (no retextures): goals by kind, first wins by league (the same
-- colours as Ui.leagueColors, the race cards' colours, D-064).
StableStar.KIND_HEX = { care = "FF8FB8", collection = "56B4E9", skill = "FF9F1C" }
StableStar.LEAGUE_HEX = { Rookie = "9EDB86", Bronze = "E8B48A", Silver = "D5DCE6", Gold = "FFE08A", Champion = "B9B9F0" }
StableStar.LEAGUES = { "Rookie", "Bronze", "Silver", "Gold", "Champion" }
StableStar.KIND_WORD = { care = "Care", collection = "Collect", skill = "Riding" }
StableStar.MAX_WALL = 36 -- 6 × 6: room for every Cup, plaque, first win and goal (31)
StableStar.MAX_PLAQUES = 4

-- In order within each kind: the card shows the first one not yet done.
StableStar.GOALS = {
	{ id = "care_groom10", kind = "care", event = "groom", target = 10, text = "Brush your horses 10 times", icon = "brush", emoji = "🪮" },
	{ id = "care_feed15", kind = "care", event = "feed", target = 15, text = "Feed your horses 15 times", icon = "hay", emoji = "🌾" },
	{ id = "care_spa3", kind = "care", event = "spa", target = 3, text = "Give 3 Spa Days", icon = "brush", emoji = "🛁" },
	{ id = "care_treat25", kind = "care", event = "treat", target = 25, text = "Give 25 treats", icon = "carrot", emoji = "🥕" },
	{ id = "care_pet50", kind = "care", event = "pet", target = 50, text = "Pet your horses 50 times", icon = "heart", emoji = "❤️" },
	{ id = "care_groom60", kind = "care", event = "groom", target = 60, text = "Brush your horses 60 times", icon = "brush", emoji = "🪮" },

	{ id = "col_coats2", kind = "collection", book = "coats", target = 2, text = "Find 2 coats for your Horse Book", icon = "", emoji = "📖" },
	{ id = "col_courses4", kind = "collection", book = "courses", target = 4, text = "Try 4 tracks and courses", icon = "map", emoji = "🗺️" },
	{ id = "col_harvest10", kind = "collection", event = "harvest", target = 10, text = "Pick 10 crops", icon = "carrot", emoji = "🥕" },
	{ id = "col_passport3", kind = "collection", book = "passport", target = 3, text = "Get 3 Health Passport stamps", icon = "stethoscope", emoji = "🩺" },
	{ id = "col_coats5", kind = "collection", book = "coats", target = 5, text = "Find 5 coats for your Horse Book", icon = "", emoji = "📖" },
	{ id = "col_courses6", kind = "collection", book = "courses", target = 6, text = "Try all 6 tracks and courses", icon = "map", emoji = "🗺️" },

	{ id = "skill_great3", kind = "skill", event = "great_race", target = 3, text = "3 races with Great taps", icon = "label_perfect", emoji = "✨" },
	{ id = "skill_burst3", kind = "skill", event = "burst_great", target = 3, text = "Hit 3 Great Final Bursts", icon = "label_perfect", emoji = "✨" },
	{ id = "skill_gold1", kind = "skill", book = "rosettes", target = 1, text = "Earn a gold in training", icon = "rosette", emoji = "🎯" },
	{ id = "skill_great15", kind = "skill", event = "great_race", target = 15, text = "15 races with Great taps", icon = "label_perfect", emoji = "✨" },
	{ id = "skill_burst12", kind = "skill", event = "burst_great", target = 12, text = "Hit 12 Great Final Bursts", icon = "label_perfect", emoji = "✨" },
	{ id = "skill_gold4", kind = "skill", book = "rosettes", target = 4, text = "Earn all 4 training golds", icon = "rosette", emoji = "🎯" },
} :: { Goal }

local byId: { [string]: Goal } = {}
local COUNTED: { [string]: boolean } = {}
for _, g in StableStar.GOALS do
	byId[g.id] = g
	if g.event then COUNTED[g.event] = true end
end
StableStar.COUNTED = COUNTED

function StableStar.goal(id: string): Goal?
	return byId[id]
end

local function saneCount(v: any): number?
	local n = tonumber(v)
	if not n or n ~= n then return nil end
	return math.clamp(math.floor(n), 0, 1e7)
end

-- Bring p.stableStar to a clean shape (older saves have none).
function StableStar.repair(p: any)
	local src = if typeof(p.stableStar) == "table" then p.stableStar else {}
	local out = { counts = {}, done = {}, firsts = {} }
	if typeof(src.counts) == "table" then
		for e, v in src.counts do
			local n = saneCount(v)
			if COUNTED[e] and n then out.counts[e] = n end
		end
	end
	if typeof(src.done) == "table" then
		for id, v in src.done do
			-- unknown ids (a newer build's, during a rolling update) pass through if they look sane
			if v == true and typeof(id) == "string" and #id >= 1 and #id <= 32 then out.done[id] = true end
		end
	end
	if typeof(src.firsts) == "table" then
		for lg, v in src.firsts do
			if v == true and table.find(StableStar.LEAGUES, lg) then out.firsts[lg] = true end
		end
	end
	p.stableStar = out
end

local function ensure(p: any)
	local s = p.stableStar
	if typeof(s) ~= "table" or typeof(s.counts) ~= "table" or typeof(s.done) ~= "table" or typeof(s.firsts) ~= "table" then
		StableStar.repair(p)
	end
end

local function bookCount(p: any, section: string): number
	local set = typeof(p.book) == "table" and p.book[section]
	local n = 0
	if typeof(set) == "table" then
		for _, v in set do
			if v == true then n += 1 end
		end
	end
	return n
end

-- How far along a goal is (capped at its target).
function StableStar.progress(p: any, g: Goal): number
	ensure(p)
	local n = if g.event then p.stableStar.counts[g.event] or 0 elseif g.book then bookCount(p, g.book) else 0
	return math.min(g.target, n)
end

-- Mark every goal that has reached its target. Returns the goals that just finished.
function StableStar.check(p: any): { Goal }
	ensure(p)
	local finished = {}
	for _, g in StableStar.GOALS do
		if not p.stableStar.done[g.id] and StableStar.progress(p, g) >= g.target then
			p.stableStar.done[g.id] = true
			table.insert(finished, g)
		end
	end
	return finished
end

-- Count an event (the same names as the Stable Board jobs, plus great_race: a race with at least
-- one Great or Perfect tap). Returns the goals that just finished (each hangs a rosette).
function StableStar.record(p: any, event: string, n: number?): { Goal }
	ensure(p)
	local k = math.floor(tonumber(n) or 1)
	if COUNTED[event] and k > 0 then
		p.stableStar.counts[event] = math.min(1e7, (p.stableStar.counts[event] or 0) + k)
	end
	return StableStar.check(p)
end

-- The first win in a league by any of your horses: a rosette in that league's colour. Returns
-- true when it is new to the wall.
function StableStar.firstWin(p: any, league: string): boolean
	ensure(p)
	if not table.find(StableStar.LEAGUES, league) or p.stableStar.firsts[league] then return false end
	p.stableStar.firsts[league] = true
	return true
end

-- The goal cards: the next goal of each kind not yet done (a kind with all done shows none).
function StableStar.cards(p: any): { { [string]: any } }
	ensure(p)
	local out = {}
	for _, kind in StableStar.KINDS do
		for _, g in StableStar.GOALS do
			if g.kind == kind and not p.stableStar.done[g.id] then
				table.insert(out, {
					id = g.id, kind = kind, kindWord = StableStar.KIND_WORD[kind], text = g.text, icon = g.icon, emoji = g.emoji,
					progress = StableStar.progress(p, g), target = g.target, color = StableStar.KIND_HEX[kind],
				})
				break
			end
		end
	end
	return out
end

-- What hangs on the wall, in order: Cups, Legend plaques, first-win rosettes, goal rosettes
-- (in the goals' order). At most MAX_WALL items. Each: { kind, id, hex, label }.
function StableStar.wall(p: any): { { kind: string, id: string, hex: string, label: string } }
	ensure(p)
	local out = {}
	local function add(kind: string, id: string, hex: string, label: string)
		if #out < StableStar.MAX_WALL then table.insert(out, { kind = kind, id = id, hex = hex, label = label }) end
	end
	local cups = typeof(p.book) == "table" and p.book.cups
	for _, lg in StableStar.LEAGUES do
		if typeof(cups) == "table" and cups[lg] == true then add("cup", lg, StableStar.LEAGUE_HEX[lg], lg .. " Cup") end
	end
	-- Legend plaques (D-059): the Hall of Fame plaques, newest first (Leagues.retire adds one for
	-- every Legend, `legend = true`, and kept older retirements).
	local plaques = 0
	for _, e in (if typeof(p.hallOfFame) == "table" then p.hallOfFame else {}) do
		if plaques < StableStar.MAX_PLAQUES and typeof(e) == "table" and typeof(e.name) == "string" then
			plaques += 1
			add("plaque", "hof" .. plaques, "FFD23F", e.name)
		end
	end
	for _, lg in StableStar.LEAGUES do
		if p.stableStar.firsts[lg] then add("first", lg, StableStar.LEAGUE_HEX[lg], "First " .. lg .. " win") end
	end
	for _, g in StableStar.GOALS do
		if p.stableStar.done[g.id] then add("goal", g.id, StableStar.KIND_HEX[g.kind], g.text) end
	end
	return out
end

-- A short key of what's on the wall, so the barn is rebuilt only when it changes.
function StableStar.wallKey(p: any): string
	local bits = {}
	for _, it in StableStar.wall(p) do table.insert(bits, it.kind .. ":" .. it.id .. ":" .. it.label) end
	return table.concat(bits, ",")
end

-- The owner's view: the goal cards and how many rosettes hang on the wall.
function StableStar.view(p: any): { [string]: any }
	local done = 0
	ensure(p)
	for _, g in StableStar.GOALS do
		if p.stableStar.done[g.id] then done += 1 end
	end
	return { cards = StableStar.cards(p), wall = #StableStar.wall(p), done = done, total = #StableStar.GOALS }
end

return StableStar
