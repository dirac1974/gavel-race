--!strict
-- Breeding in the game (D-080): the server flow BreedingService runs (confirm, wait, arrive, name, add),
-- permissions, save compatibility, the no-reroll guarantee, the Foal Barn on the Map, the foal's look,
-- the Studio breedReady switch, and the wiring and copy around them.
local fs = require("@lune/fs")
local Breeding = require("../../game/src/shared/Breeding")
local GameConfig = require("../../game/src/shared/GameConfig")
local Horse = require("../../game/src/shared/Horse")
local Profile = require("../../game/src/shared/Profile")
local Market = require("../../game/src/shared/Market")
local NameGen = require("../../game/src/shared/NameGen")
local FindIt = require("../../game/src/shared/FindIt")
local WorldLayout = require("../../game/src/shared/WorldLayout")
local HorseLook = require("../../game/src/shared/HorseLook")
local StudioTest = require("../../game/src/shared/StudioTest")
local Words = require("../../game/src/shared/Words")

local T0 = 1_760_000_000
local DAY = 86400

local function code(path: string): string
	local out = {}
	for _, line in string.split(fs.readFile(path), "\n") do
		local cut = string.find(line, "--", 1, true)
		table.insert(out, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(out, "\n")
end

local function has(src: string, s: string): boolean
	return string.find(src, s, 1, true) ~= nil
end

local function count(src: string, s: string): number
	local n, i = 0, 1
	while true do
		local a, b = string.find(src, s, i, true)
		if not a then return n end
		n += 1
		i = (b :: number) + 1
	end
end

local function rng(values: { number })
	local i = 0
	return { NextNumber = function(_self)
		i += 1
		return values[((i - 1) % #values) + 1]
	end }
end

local function deepCopy(t: any): any
	if typeof(t) ~= "table" then return t end
	local out = {}
	for k, v in t do out[k] = deepCopy(v) end
	return out
end

-- A stable with two parents ready (Comet: Bronze, 40 races; Maple: Rookie, 35 races) and cash.
local function stable(): any
	local p = Profile.new(T0)
	local s = Horse.STARTER_STAT
	local a = Horse.new("h1", "Comet", "bay", { speed = s, accel = s, stamina = s, grit = s }, { speed = 80, accel = 78, stamina = 82, grit = 76 }, T0)
	a.league, a.record.races, a.origin = "Bronze", 40, "starter"
	local b = Horse.new("h2", "Maple", "grey", { speed = s, accel = s, stamina = s, grit = s }, { speed = 75, accel = 77, stamina = 74, grit = 79 }, T0)
	b.record.races, b.origin, b.paid = 35, "market", 600
	Profile.addHorse(p, a)
	Profile.addHorse(p, b)
	p.nextHorseId = 3
	p.cash = 1000
	p.totals.races = 75
	return p
end

-- What BreedingService does on FoalArrive: build with Horse.new, add with Profile.addHorse.
local function arrive(p: any, first: string?, second: string?, now: number): any
	local name = NameGen.build(first, second)
	if not name then return nil end
	local pend = Breeding.pending(p)
	if not pend or not Breeding.ready(pend, Breeding.ownerRaces(p), now) or #p.horses >= Market.MAX_HORSES then return nil end
	local id = Profile.newHorseId(p)
	local rec = Breeding.arrive(p, id, name, now)
	if not rec then return nil end
	local h = Horse.new(id, rec.name, rec.coat, rec.stats, rec.potential, now)
	h.bond, h.origin, h.parents, h.paid = rec.bond, "bred", rec.parents, rec.paid
	Profile.addHorse(p, h)
	return h
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	local B = GameConfig.breeding
	-- Switched on together (D-068, D-080) -------------------------------------------------------------
	check(B.enabled == true and GameConfig.career.suggest == true, "breeding.enabled and career.suggest are on together")
	check(GameConfig.studioTest.breedReady == false, "studioTest.breedReady is off by default")

	-- The flow -----------------------------------------------------------------------------------------
	do
		local p = stable()
		local diamonds = p.diamonds
		check(Breeding.pairBlock(p, "h1", "h2") == nil, "two ready horses, one in Bronze: they can be parents")
		local ok, msg, pend = Breeding.confirm(p, "h1", "h2", T0, rng({ 0.5, 0.2, 0.9, 0.4, 0.3 }))
		check(ok and pend ~= nil, "confirm: " .. msg)
		check(p.cash == 1000 - B.fee.Bronze and p.diamonds == diamonds, "the fee is Green Cash at the higher parent's league; Diamonds untouched")
		check(p.breeding.nextAt == 75 + B.foalEveryRaces and Breeding.nextFoalIn(p) == B.foalEveryRaces, "the stable waits foalEveryRaces owner races (nextAt)")
		local ok2, why2 = Breeding.confirm(p, "h1", "h2", T0, rng({ 0.1 }))
		check(not ok2 and why2 == "A foal is on the way!" and p.cash == 1000 - B.fee.Bronze, "a second confirm is refused and costs nothing")
		check(Market.canAddHorse(p) and #p.horses + #p.breeding.pending == 3, "the foal on the way holds a place in the stable")
		check(arrive(p, "Pebble", nil, T0 + 60) == nil, "not ready straight away")
		p.totals.races += B.foalAfterRaces - 1
		check(arrive(p, "Pebble", nil, T0 + 60) == nil, "one race short: still on the way")
		p.totals.races += 1
		check(arrive(p, "Nope", "Words", T0 + 60) == nil and Breeding.pending(p) ~= nil, "only NameGen words name a foal")
		local stored = deepCopy(Breeding.pending(p))
		local h = arrive(p, "Pebble", "Star", T0 + 60)
		check(h ~= nil and h.name == "Pebble Star" and h.id == "h3", "after foalAfterRaces owner races the foal arrives, named")
		if h then
			check(h.coat == stored.coat and h.potential.speed == stored.potential.speed and h.stats.grit == stored.stats.grit,
				"the foal is exactly the roll stored at confirm")
			check(h.origin == "bred" and h.parents[1] == "h1" and h.parents[2] == "h2" and h.paid == B.fee.Bronze and h.bond == B.bond,
				"origin bred, both parents kept, paid = the fee, starting bond")
			check(h.league == "Rookie" and h.record.races == 0, "a Young Rookie")
			check(Breeding.pending(p) == nil and #p.horses == 3, "it joined the stable; nothing left on the way")
			-- origin and parents survive a save and a load
			local loaded = Profile.migrate(deepCopy(p), T0 + 120)
			local lh = Profile.horse(loaded, "h3") :: any
			check(lh and lh.origin == "bred" and lh.parents and lh.parents[2] == "h2", "Horse.repair keeps origin bred and the parents")
			local v = Horse.view(lh, T0 + 120, GameConfig.energy)
			check(v.origin == "bred" and v.parents and v.parents[1] == "h1", "the owner's view has origin and parents")
			-- selling always loses cash
			check(Market.rehomeValue(lh) == Breeding.sellValue(lh.paid, 0, 0) and Market.rehomeValue(lh) < lh.paid,
				"a bred foal sells like a Market horse, for less than the fee")
		end
		check(arrive(p, "Pebble", nil, T0 + 120) == nil, "no second foal from one confirm")
	end

	-- The next play day ------------------------------------------------------------------------------
	do
		local p = stable()
		Breeding.confirm(p, "h1", "h2", T0, rng({ 0.5 }))
		check(arrive(p, "Comet", nil, T0 + 3600) == nil, "later the same day: still on the way")
		check(arrive(p, "Comet", nil, T0 + DAY) ~= nil, "the next UTC day you play: here")
	end

	-- No profit, every league -------------------------------------------------------------------------
	for league, fee in B.fee do
		local h = { origin = "bred", paid = fee, record = { wins = 1000, cups = 100 } }
		check(Market.rehomeValue(h) < fee, `breed then sell loses cash in {league} ({Market.rehomeValue(h)} < {fee})`)
	end

	-- Permissions -----------------------------------------------------------------------------------
	do
		local p = stable()
		local maple = Profile.horse(p, "h2") :: any
		maple.record.races = B.minParentRaces - 1
		check(Breeding.horseBlock(p, maple) == `Needs {B.minParentRaces} races`, "a Young horse can't be a parent")
		maple.record.races = B.minParentRaces
		maple.lent = T0
		check(Breeding.horseBlock(p, maple) == "Lent", "a lent horse can't be a parent")
		maple.lent = nil
		check(Breeding.pairBlock(p, "h1", "h2", { racing = true }) ~= nil, "not while racing")
		check(Breeding.pairBlock(p, "h1", "h1") ~= nil, "not one horse twice")
		check(Breeding.pairBlock(p, "h1", "zz") ~= nil, "not a horse you don't own")
		local comet = Profile.horse(p, "h1") :: any
		comet.league = "Rookie"
		check(Breeding.pairBlock(p, "h1", "h2") == `One parent needs {B.needLeague}`, "one parent needs Bronze")
		comet.league = "Bronze"
		p.cash = B.fee.Bronze - 1
		local before = deepCopy(p)
		local ok = Breeding.confirm(p, "h1", "h2", T0, rng({ 0.5 }))
		check(not ok and p.cash == before.cash and Breeding.pending(p) == nil and p.breeding.nextAt == nil, "not enough Green Cash: nothing changes")
		p.cash = 5000
		Breeding.confirm(p, "h1", "h2", T0, rng({ 0.5 }))
		p.totals.races += B.foalAfterRaces
		arrive(p, "Comet", nil, T0)
		check(string.find(Breeding.pairBlock(p, "h1", "h2") or "", "Next foal in", 1, true) ~= nil, "the stable-wide wait: \"Next foal in N races\"")
		-- a full stable: the foal waits
		local q = stable()
		Breeding.confirm(q, "h1", "h2", T0, rng({ 0.5 }))
		for k = 3, Market.MAX_HORSES do
			table.insert(q.horses, Horse.new("x" .. k, "Dusty", "bay", { speed = 1, accel = 1, stamina = 1, grit = 1 }, { speed = 60, accel = 60, stamina = 60, grit = 60 }, T0))
		end
		q.totals.races += B.foalAfterRaces
		check(not Market.canAddHorse(q) and arrive(q, "Comet", nil, T0) == nil and Breeding.pending(q) ~= nil, "a full stable: the foal waits, never lost")
	end

	-- Save compatibility and no reroll ---------------------------------------------------------------
	do
		local old = Profile.migrate({ cash = 300, horses = { { id = "h1", name = "Comet", coat = "bay", origin = "starter" } } }, T0)
		check(typeof(old.breeding) == "table" and #old.breeding.pending == 0 and old.breeding.nextAt == nil, "an old save loads with nothing on the way")
		local p = stable()
		Breeding.confirm(p, "h1", "h2", T0, rng({ 0.9, 0.1, 0.6, 0.3, 0.97 }))
		local stored = deepCopy(Breeding.pending(p))
		local nextAt = p.breeding.nextAt
		for _ = 1, 3 do p = Profile.migrate(deepCopy(p), T0 + 30) end
		local again = Breeding.pending(p)
		local same = again ~= nil and again.coat == stored.coat and again.atRaces == stored.atRaces and again.day == stored.day and again.fee == stored.fee
		for _, k in Horse.STATS do
			same = same and again.potential[k] == stored.potential[k] and again.stats[k] == stored.stats[k]
		end
		check(same and p.breeding.nextAt == nextAt, "three loads keep the stored foal and the wait exactly (no reroll)")
		local junk = Profile.migrate({ horses = {}, breeding = { pending = { { parents = { "h1" } }, "x", { coat = "zebra" } }, nextAt = "soon", rest = { h1 = 5 } } }, T0)
		check(#junk.breeding.pending == 0 and junk.breeding.nextAt == nil and junk.breeding.rest == nil, "a broken breeding save is cleaned, never a crash")
		local bad = Profile.migrate({ horses = { { id = "h9", name = "Pip", origin = "bred", parents = { 5, {} } } } }, T0)
		check(bad.horses[1].origin == "bred" and bad.horses[1].parents == nil, "broken parents are dropped, the horse kept")
		check(table.find(Horse.ORIGINS, "bred") ~= nil, "Horse.ORIGINS has bred")
	end

	-- The Foal Barn on the Map ------------------------------------------------------------------------
	do
		check(WorldLayout.MAP[14] == "foalBarn" and WorldLayout.MAP_LABELS.foalBarn == "Foal Barn" and WorldLayout.MAP_EMOJI.foalBarn == "💞",
			"tile 14: 💞 Foal Barn")
		check(#WorldLayout.MAP <= 15 and GameConfig.findIt.map.columns == 5, "still fits the 5 x 3 phone grid")
		check(WorldLayout.isTravelDest("foalBarn") and WorldLayout.placeRect("foalBarn") ~= nil, "a trip with a building")
		check(FindIt.hint("foalBarn", { breeding = {} }) == "Foal soon" and FindIt.hint("foalBarn", { breeding = { ready = true } }) == "Foal here!",
			"hint: Foal soon, then Foal here!")
	end

	-- The foal's look -------------------------------------------------------------------------------
	do
		local F = GameConfig.foalLook
		local f0 = HorseLook.foal({ origin = "bred", record = { races = 0 } })
		check(f0 ~= nil and f0.body == F.body and f0.legY == F.legY and F.body == 0.70 and F.legY == 0.92, "a new foal: body x0.70, legs x0.92")
		local f15 = HorseLook.foal({ origin = "bred", record = { races = 15 } })
		check(f15 ~= nil and f15.body > F.body and f15.body < 1, "growing")
		check(HorseLook.foal({ origin = "bred", record = { races = F.growRaces } }) == nil, "grown up by growRaces")
		check(HorseLook.foal({ origin = "market", record = { races = 0 } }) == nil, "only bred foals")
		local ok = true
		for r = 0, F.growRaces do
			local s = HorseLook.raceScale({ origin = "bred", record = { races = r } })
			if s ~= nil and (s < F.raceMinScale or s >= 1) then ok = false end
			local look = HorseLook.forRace({ origin = "bred", record = { races = r } }, nil)
			if look and look.scale and look.scale < F.raceMinScale then ok = false end
		end
		check(ok and F.raceMinScale == 0.94, "never smaller than 0.94 in races")
	end

	-- Studio breedReady -----------------------------------------------------------------------------
	do
		local p = Profile.new(T0)
		local h = Horse.starter("h1", "Comet", "bay", { NextInteger = function(_s, lo, _hi) return lo end }, T0)
		Profile.addHorse(p, h)
		p.nextHorseId = 2
		local cfg = table.clone(GameConfig.studioTest)
		cfg.breedReady = true
		check(#StudioTest.apply(p, T0, false, Profile.activeHorse, cfg) == 0, "never outside Studio")
		local lines = StudioTest.apply(p, T0, true, Profile.activeHorse, cfg)
		check(#lines > 0 and #p.horses == 2 and Breeding.pairBlock(p, "h1", "h2") == nil, "breedReady: two parents ready in Studio")
		check(p.cash >= B.fee[B.needLeague], "breedReady: the fee in hand")
	end

	-- Wiring and copy ------------------------------------------------------------------------------
	do
		local race = code("game/src/server/RaceService.server.luau")
		check(count(race, "Foals.afterRace(") == 1, "RaceService calls the foal hook once per counted race")
		local svc = code("game/src/server/BreedingService.server.luau") .. code("game/src/server/Foals.luau")
		check(has(svc, "Breeding.confirm(") and has(svc, "Breeding.arrive(") and has(svc, "Profile.addHorse(") and has(svc, "Horse.new("),
			"the server confirms, arrives and adds the foal")
		check(not has(string.lower(svc), "diamond") and not has(svc, "Robux") and not has(svc, "MarketplaceService"), "no Diamonds or Robux anywhere in breeding")
		check(has(svc, "busy(player, 2, \"confirm\")") and has(svc, "busy(player, 2, \"arrive\")"), "confirm and arrive are rate limited")
		local client = code("game/src/client/BreedingClient.client.luau")
		check(has(client, "\"Pick two parents\"") and has(client, "\"Your foal\"") and has(client, "\"Coat chances\""), "two steps and the Coat chances box")
		check(has(client, "\"🔀 New words\"") and has(client, "\"That's the name!\"") and has(client, "NameGen.offer("), "naming copies the Starter's step 2")
		check(has(client, "GoTo.register(\"foalBarn\"") and has(code("game/src/client/GoTo.luau"), "foalBarn = \"foalBarn\""), "GO opens the Foal Barn")
		check(has(client, "F.nickerSpeed") and GameConfig.foalLook.nickerSpeed == 1.45 and GameConfig.foalLook.parentSpeed == 0.9, "the nickers at 1.45 and 0.9")
		check(not has(client, "confetti") and not has(client, "Confetti"), "no confetti at the arrival")
		local copy = fs.readFile("game/src/client/BreedingClient.client.luau") .. fs.readFile("game/src/server/BreedingService.server.luau")
			.. fs.readFile("game/src/server/Foals.luau") .. fs.readFile("game/src/client/FoalLife.client.luau")
		local clean = true
		for str in string.gmatch(copy, "\"([^\"]*)\"") do
			if Words.banned(str) then clean = false end
		end
		check(clean, "no wagering, hurt or birth words in breeding copy")
		check(Words.banned("a new mare") == "mare" and Words.banned("good odds") == "odds", "the copy check knows the breeding words")
		local book = code("game/src/client/HorseBookClient.client.luau")
		check(has(book, "\"Two horses can start a family\"") and has(book, "id = \"family\""), "the Horse Book Family page and its empty state")
		check(has(code("game/src/client/GrownUps.client.luau"), "💞 Foals:"), "the grown-ups page explains breeding")
	end
end
