--!strict
-- Find it (fun-and-return phase 1, D-075, provisional): the rules behind the every-place Map, GO
-- (GoTo.luau) and the "New!" first-time pointers. Pure, works on the client's profile view, so Lune
-- tests it. Numbers live in GameConfig.findIt.
--   FindIt.tiles(): the Map's 14 tiles in grid order, with their row and column.
--   FindIt.hint(id, profile): the tile's "what to do here" line, at most map.hintWords words. Facts
--     only: no red, no counts of things owed, no badges (D-043).
--   FindIt.goPlan(place, distance, state): what GO does (walk, teleport, just open, or wait).
--   FindIt.pointerDue(profile, ctx, lastAt, now): the one "New!" pointer to show now, or nil.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")
local WorldLayout = if script then require(script.Parent.WorldLayout) :: any else require("./WorldLayout")
local BarnCatalog = if script then require(script.Parent.BarnCatalog) :: any else require("./BarnCatalog")

local FindIt = {}

local CFG = GameConfig.findIt

-- Map ---------------------------------------------------------------------------------------------
export type Tile = { id: string, label: string, icon: string, emoji: string, row: number, col: number }

function FindIt.tiles(): { Tile }
	local cols = CFG.map.columns
	local out: { Tile } = {}
	for k, id in WorldLayout.MAP do
		table.insert(out, {
			id = id, label = WorldLayout.MAP_LABELS[id], icon = WorldLayout.MAP_ICONS[id] or "", emoji = WorldLayout.MAP_EMOJI[id],
			row = (k - 1) // cols + 1, col = (k - 1) % cols + 1,
		})
	end
	return out
end

-- The Map panel's size (unscaled px) for the grid: (width, height).
function FindIt.panelSize(): (number, number)
	local m = CFG.map
	local rows = math.ceil(#WorldLayout.MAP / m.columns)
	local w = m.columns * m.tileW + (m.columns - 1) * m.gapPx + 2 * 16
	local h = m.headerPx + rows * m.tileH + (rows - 1) * m.gapPx + m.gapPx
	return w, h
end

FindIt.HINTS = {
	stable = "Your barn", track = "Watch races", raceBoard = "Pick races", plaza = "Shops here", feedStore = "Buy food",
	barnBuilder = "Build things", tackShop = "Dress up", vet = "Check-ups", market = "Meet horses", paddock = "Train here",
	trainingGround = "Ride courses", trailGate = "Wild horses", visit = "Look around", -- (D-079: friends' and open barns)
	foalBarn = "Foal soon", -- (D-080) "Foal here!" once a foal is waiting to meet you
}

local function activeHorse(profile: any): any
	local first = nil
	for _, h in (profile and profile.horses) or {} do
		if h.id == profile.activeHorse then return h end
		if not first and h.stalled ~= false then first = h end
	end
	return first
end

function FindIt.hint(id: string, profile: any?): string
	local p = profile or {}
	if id == "stable" then
		local n = #(p.horses or {})
		if n > 1 then return n .. " horses" end
	elseif id == "vet" then
		local h = activeHorse(p)
		if h and h.resting and GameConfig.spa.enabled and (h.spaToday or 0) < GameConfig.spa.perDay then return "Spa today" end
	elseif id == "barnBuilder" then
		local best = BarnCatalog.tierIndex(p.bestLeague)
		local seen = typeof(p.style) == "table" and BarnCatalog.tierIndex(p.style.shelfSeen) or nil
		if best and seen and best > seen then return "New shelf" end
	elseif id == "foalBarn" then
		if typeof(p.breeding) == "table" and p.breeding.ready == true then return "Foal here!" end
	end
	return FindIt.HINTS[id] or ""
end

-- GO ----------------------------------------------------------------------------------------------
-- Places GO can open with no trip (a panel, wherever you are): the Stable Board, the Horse Book, My
-- Horses, the race picker's 🔀 Pick and the barns list.
FindIt.PANELS = { board = true, book = true, horses = true, pick = true, visit = true }

export type GoState = { racing: boolean?, inLine: boolean?, training: boolean? }
export type GoPlan = { how: string, open: boolean, label: string }

-- how: "open" (a panel, no trip), "walk" (hoofprints; open = true opens it on arrival), "teleport"
-- (fade, the Map's trip, then open) or "wait" (riding a race: nothing moves). distance = nil means
-- not known (no character yet): teleport.
function FindIt.goPlan(place: string, distance: number?, s: GoState): GoPlan
	if s.racing then return { how = "wait", open = false, label = "After your race!" } end
	if FindIt.PANELS[place] then return { how = "open", open = true, label = "GO ▶" } end
	if s.inLine or s.training then return { how = "walk", open = false, label = "GO ▶" } end
	if distance ~= nil and distance <= CFG.goTo.walkMaxStuds then return { how = "walk", open = true, label = "GO ▶" } end
	return { how = "teleport", open = true, label = "Take me ▶" }
end

-- "New!" pointers -----------------------------------------------------------------------------------
-- ring: the dock button that glows ("map", "book", "pick", "jobs"); go: a GoTo place.
export type Pointer = { id: string, text: string, go: string, ring: string, races: string?, when: ((any) -> boolean)? }

local function napping(profile: any): boolean
	local h = activeHorse(profile)
	return h ~= nil and h.resting == true and GameConfig.spa.enabled and (h.spaToday or 0) < GameConfig.spa.perDay
end

-- In order: the first unseen one that is relevant shows.
FindIt.POINTERS = {
	{ id = "spa", text = "New! Spa Day at the Vet", go = "vet", ring = "map", when = napping },
	{ id = "pick", text = "New! Pick your own race", go = "pick", ring = "pick", races = "pickRaces" },
	{ id = "book", text = "New! Your Horse Book", go = "book", ring = "book", races = "bookRaces",
		when = function() return GameConfig.comeback.horseBook ~= false end },
	{ id = "train", text = "New! Train your horse", go = "paddock", ring = "map", races = "trainRaces",
		when = function(profile) local h = activeHorse(profile) return h ~= nil and h.trainingReady == true end },
	{ id = "builder", text = "New! Build things for your barn", go = "barnBuilder", ring = "map", races = "builderRaces",
		when = function() return (GameConfig.greenCash or {}).enabled ~= false end },
	{ id = "market", text = "New! Meet horses at Market", go = "market", ring = "map", races = "marketRaces" },
	{ id = "visit", text = "New! Visit other barns", go = "visit", ring = "map", races = "visitRaces",
		when = function() return GameConfig.visit.enabled and GameConfig.visit.mapList end },
} :: { Pointer }

-- Everything the profile may remember as seen (SettingsService takes only these).
FindIt.SEEN_IDS = { howRacing = true }
for _, p in FindIt.POINTERS do FindIt.SEEN_IDS[p.id] = true end

function FindIt.seenKey(id: string): string
	return "seen_" .. id
end

function FindIt.seen(flags: any, id: string): boolean
	return typeof(flags) == "table" and flags[FindIt.seenKey(id)] == true
end

-- ctx = { touring, busy (in line, racing or on a training ride), resultsOpen, sinceRace (seconds since
-- your race ended, nil = none yet) }. lastAt: when the last pointer showed (same clock as now), or nil.
export type PointerCtx = { touring: boolean?, busy: boolean?, resultsOpen: boolean?, sinceRace: number? }

-- The calm-moment gates every pointer passes, on the way in and every time it would show again: not on
-- the tour, not in line, racing or riding, not on the results card, and never within afterRaceSeconds of
-- your race (hard rule 3). A pointer that fails them is dropped unseen (StableBoard).
function FindIt.pointerOk(ctx: PointerCtx): boolean
	if ctx.touring or ctx.busy or ctx.resultsOpen then return false end
	if ctx.sinceRace ~= nil and ctx.sinceRace < CFG.pointers.afterRaceSeconds then return false end
	return true
end

function FindIt.pointerDue(profile: any, ctx: PointerCtx, lastAt: number?, now: number): Pointer?
	local P = CFG.pointers
	if not P.enabled or not profile or #(profile.horses or {}) == 0 then return nil end
	if not FindIt.pointerOk(ctx) then return nil end
	if lastAt ~= nil and now - lastAt < P.gapSeconds then return nil end
	local races = (profile.totals and tonumber(profile.totals.races)) or 0
	for _, p in FindIt.POINTERS do
		if not FindIt.seen(profile.flags, p.id) and races >= (if p.races then P[p.races] else 0)
			and (p.when == nil or (p.when :: (any) -> boolean)(profile)) then
			return p
		end
	end
	return nil
end

-- The gold ring's brightness (0..1) at time t since it started: 1 Hz, never more than 3 flashes a
-- second; Reduced Motion holds it still. Off after ringSeconds.
function FindIt.ringAlpha(t: number, still: boolean): number?
	local P = CFG.pointers
	if t < 0 or t > P.ringSeconds then return nil end
	if still then return 1 end
	return 0.5 + 0.5 * math.cos(2 * math.pi * P.ringHz * t)
end

return FindIt
