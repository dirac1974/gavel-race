--!strict
-- Tests for the world modules: Horse, Profile, NameGen (Stage 1), WorldLayout (Stage 2).
local Horse = require("../../game/src/shared/Horse")
local Profile = require("../../game/src/shared/Profile")
local NameGen = require("../../game/src/shared/NameGen")
local RaceRating = require("../../game/src/shared/RaceRating")
local GameConfig = require("../../game/src/shared/GameConfig")
local WorldLayout = require("../../game/src/shared/WorldLayout")
local TrackLayout = require("../../game/src/shared/TrackLayout")

local function makeRng(seed0: number)
	local seed = seed0
	local function nextNumber(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	return {
		NextNumber = function(_self): number return nextNumber() end,
		NextInteger = function(_self, lo: number, hi: number): number
			return lo + math.floor(nextNumber() * (hi - lo + 1))
		end,
	}
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local E = GameConfig.energy
	local T0 = 20000 * 86400 + 3600 -- a fixed day, 01:00 UTC

	-- Horse: starters --------------------------------------------------------------
	local rng = makeRng(7)
	local a = Horse.starter("h1", "Lucky Star", "bay", rng, T0)
	local b = Horse.starter("h2", "Comet", "grey", rng, T0)
	local equal = true
	for _, k in Horse.STATS do
		if a.stats[k] ~= Horse.STARTER_STAT or b.stats[k] ~= Horse.STARTER_STAT then equal = false end
		if a.potential[k] < 70 or a.potential[k] > 85 then equal = false end
	end
	check(equal, "starters have equal stats and Potential 70-85")
	check(#Horse.STARTERS == 3 and a.energy == E.maxPerRacer and a.league == "Rookie", "three starters, full energy, Rookie")

	-- Energy: spend, regen while away, cap ---------------------------------------------
	local h = Horse.starter("h3", "Pepper", "black", rng, T0)
	check(Horse.spendEnergy(h, 1, T0, E) and h.energy == 4, "spend 1 energy")
	check(Horse.syncEnergy(h, T0 + E.regenSeconds - 1, E) == 4, "no regen before the interval")
	check(Horse.syncEnergy(h, T0 + E.regenSeconds, E) == 5, "+1 after the interval")
	check(Horse.nextEnergyIn(h, T0 + E.regenSeconds, E) == 0, "full: nothing to wait for")
	for _ = 1, 5 do Horse.spendEnergy(h, 1, T0 + 100, E) end
	check(h.energy == 0 and not Horse.spendEnergy(h, 1, T0 + 100, E), "can't spend below zero")
	check(Horse.syncEnergy(h, T0 + 100 + 2 * E.regenSeconds + 10, E) == 2, "regen counts while away")
	check(Horse.nextEnergyIn(h, T0 + 100 + 2 * E.regenSeconds + 10, E) == E.regenSeconds - 10, "partial interval carries over")
	check(Horse.syncEnergy(h, T0 + 100 + 50 * E.regenSeconds, E) == E.maxPerRacer, "regen stops at the cap")

	-- Care: half each, resets to baseline next day, top-ups on cooldown --------------------
	local c = Horse.starter("h4", "Maple", "chestnut", rng, T0)
	c.energy = 3
	check(Horse.care(c, T0) == 0, "no care yet")
	local first, topUp = Horse.tend(c, "feed", T0, E, E.careTopUps)
	check(first and topUp and close(Horse.care(c, T0), 0.5, 1e-12) and c.energy == 4, "feeding fills half and tops up energy")
	first, topUp = Horse.tend(c, "feed", T0 + 60, E, E.careTopUps)
	check(not first and not topUp and c.energy == 4, "feeding again: no extra care, top-up on cooldown")
	Horse.tend(c, "groom", T0 + 60, E, E.careTopUps)
	check(close(Horse.care(c, T0 + 60), 1, 1e-12) and c.bond == 2, "full care after grooming; bond +1 each")
	check(Horse.care(c, T0 + 86400) == 0, "care back to baseline the next day, never below")
	first, topUp = Horse.tend(c, "feed", T0 + 86400, E, E.careTopUps)
	check(first, "can feed again on a new day")

	-- Rating: care and bond help, matching RaceRating ------------------------------------
	local cond = { distance = "Mile", surface = "Dirt", weather = "Sunny" }
	local r0 = Horse.rating(a, cond, T0, RaceRating)
	check(close(r0, RaceRating.rating(a.stats, cond, 0, 0, "Stalker", 0), 1e-9), "rating matches RaceRating")
	Horse.tend(a, "feed", T0, E, E.careTopUps)
	Horse.tend(a, "groom", T0, E, E.careTopUps)
	check(Horse.rating(a, cond, T0, RaceRating) > r0, "full care raises the rating")

	-- Records ------------------------------------------------------------------------
	Horse.recordRace(b, 1, 20, 10, T0)
	Horse.recordRace(b, 5, 0, 1, T0)
	check(b.record.races == 2 and b.record.wins == 1 and b.record.places == 1 and b.points == 11 and b.record.cash == 20,
		"race record")

	-- View hides Potential until revealed ------------------------------------------------
	local v = Horse.view(b, T0, E)
	check(v.potential == nil and v.stats.speed == Horse.STARTER_STAT, "Potential hidden")
	b.stamps.potential = true
	check(Horse.view(b, T0, E).potential ~= nil, "Potential shown after the vet stamp")

	-- Repair ---------------------------------------------------------------------------
	local fixed = Horse.repair({ id = "h9", coat = "zebra", stats = { speed = 300 }, energy = 99 }, T0)
	check(fixed.coat == "bay" and fixed.stats.speed == 100 and fixed.energy == 5 and fixed.name == "Comet"
		and fixed.potential.speed >= fixed.stats.speed, "repair clamps and fills a bad record")

	-- Profile ------------------------------------------------------------------------
	local p = Profile.new(T0)
	check(p.cash == Profile.START_CASH and Profile.itemCount(p, "hay") == 10 and #p.horses == 0, "new profile")
	check(Profile.touchDay(p, T0) and not Profile.touchDay(p, T0 + 60) and p.days.played == 1, "first visit of the day counts once")
	check(Profile.touchDay(p, T0 + 3 * 86400) and p.days.played == 2, "a missed day never resets the count")
	check(Profile.spendCash(p, 20) and p.cash == 30 and not Profile.spendCash(p, 31) and p.cash == 30, "can't overspend")
	check(not Profile.spendCash(p, -5), "no negative spends")
	check(Profile.takeItem(p, "carrot", 3) and p.items.carrot == nil and not Profile.takeItem(p, "carrot", 1), "items run out cleanly")
	Profile.addItem(p, "seed_oats", 2)
	check(Profile.itemCount(p, "seed_oats") == 2, "add items")

	local h1 = Horse.starter(Profile.newHorseId(p), "Lucky Star", "bay", rng, T0)
	Profile.addHorse(p, h1)
	check(p.activeHorse == "h1" and Profile.activeHorse(p) == h1, "first horse becomes active")
	local h2 = Horse.starter(Profile.newHorseId(p), "Comet", "grey", rng, T0)
	local h3 = Horse.starter(Profile.newHorseId(p), "Pepper", "black", rng, T0)
	Profile.addHorse(p, h2)
	Profile.addHorse(p, h3)
	check(Profile.isStalled(p, "h2") and not Profile.isStalled(p, "h3"), "third horse goes to the pasture")
	check(not Profile.setActive(p, "h3"), "pasture horses can't be active")
	check(Profile.swapStall(p, "h1", "h3") and p.activeHorse == "h3" and Profile.isStalled(p, "h3"), "swap a pasture horse in")

	Profile.recordRace(p, "h3", 1, 24, 10, T0)
	check(p.cash == 30 + 24 and p.totals.wins == 1 and h3.record.wins == 1, "race pays into the profile")

	local view = Profile.view(p, T0, E)
	check(#view.horses == 3 and view.horses[3].stalled == false and view.horses[1].potential == nil, "profile view")

	-- Migration: nil, junk, and an old record ------------------------------------------
	check(Profile.migrate(nil, T0).cash == Profile.START_CASH, "new player")
	local junk = Profile.migrate({ cash = -40, items = { hay = "5", diamond = 9 }, horses = { 5, { id = "h1" } }, stalls = 99 }, T0)
	check(junk.cash == 0 and junk.items.hay == 5 and junk.items.diamond == nil and #junk.horses == 1
		and junk.activeHorse == "h1" and junk.stalls == Profile.MAX_STALLS and junk.nextHorseId == 2, "migrate repairs junk")
	local round = Profile.migrate(p, T0)
	check(#round.horses == 3 and round.activeHorse == "h3", "migrate keeps a good profile")

	-- Names ------------------------------------------------------------------------
	check(NameGen.build("Lucky", "Star") == "Lucky Star" and NameGen.build(nil, "Star") == "Star", "names from chips")
	check(NameGen.build("Lucky", "Bad") == nil and NameGen.build("Nope", nil) == nil and NameGen.build(nil, nil) == nil,
		"only listed words")
	local f, s = NameGen.offer(makeRng(3), 6)
	local distinct = #f == 6 and #s == 6
	for i = 1, #f do
		for j = i + 1, #f do if f[i] == f[j] then distinct = false end end
	end
	check(distinct, "offer gives distinct chips")

	-- WorldLayout (Stage 2) ----------------------------------------------------------
	local W = WorldLayout
	local street = { W.STREET_X0, W.STREET_Z - W.STREET_WIDTH / 2, W.STREET_X1, W.STREET_Z + W.STREET_WIDTH / 2 }
	local lane = { W.LANE_X - W.LANE_WIDTH / 2, W.LANE_Z0, W.LANE_X + W.LANE_WIDTH / 2, W.LANE_Z1 }
	-- Everything on the grandstand side stays clear of the racecourse and grandstand (x < 640).
	local course = { -1000, -2000, 640, 2000 }
	local plotsOk = true
	for i = 1, W.PLOT_COUNT do
		local r = W.plotRect(i)
		if not W.inBounds(r) or W.overlaps(r, street) or W.overlaps(r, lane) or W.overlaps(r, course) then plotsOk = false end
		for j = i + 1, W.PLOT_COUNT do
			if W.overlaps(r, W.plotRect(j)) then plotsOk = false end
		end
		for key in W.places do
			local pr = W.placeRect(key)
			if pr and W.overlaps(r, pr) then plotsOk = false end
		end
		-- the plot's front edge touches the lane
		local p = W.plot(i)
		if math.abs(math.abs(p.x - W.LANE_X) - W.LANE_WIDTH / 2) > 1e-9 then plotsOk = false end
	end
	check(plotsOk, "20 plots in bounds, on the lane, clear of streets, buildings and each other")
	local placesOk = true
	local keys = {}
	for key in W.places do table.insert(keys, key) end
	for a = 1, #keys do
		local ra = W.placeRect(keys[a])
		if ra then
			if not W.inBounds(ra) or W.overlaps(ra, street) or W.overlaps(ra, course) then placesOk = false end
			for b = a + 1, #keys do
				local rb = W.placeRect(keys[b])
				if rb and W.overlaps(ra, rb) then placesOk = false end
			end
		end
	end
	check(placesOk, "Fair Street buildings clear of the street, the course and each other")
	-- The tunnel lines up with the grandstand: the street meets the stand's back wall.
	local cfg = TrackLayout.churchill
	local _, _, lineZ = TrackLayout.finishLine(cfg)
	check(W.STREET_Z > lineZ - 300 and W.STREET_Z < lineZ + 600, "Fair Street meets the grandstand")
	-- Every map destination has an arrival point in bounds; the stable needs a plot.
	local arriveOk = true
	for _, dest in W.MAP do
		local x, z = W.arrival(dest, 3)
		if x < W.BOUNDS.x0 or x > W.BOUNDS.x1 or z < W.BOUNDS.z0 or z > W.BOUNDS.z1 then arriveOk = false end
		if not W.MAP_LABELS[dest] or not W.MAP_EMOJI[dest] then arriveOk = false end
	end
	local sx, sz = W.arrival("stable", 3)
	local r3 = W.plotRect(3)
	check(arriveOk and sx >= r3[1] and sx <= r3[3] and sz >= r3[2] and sz <= r3[4], "map arrivals, stable arrival inside your plot")
	-- Within about a 20-second gallop (48 studs/s) of the grandstand tunnel.
	local far = 0
	for i = 1, W.PLOT_COUNT do
		local p = W.plot(i)
		far = math.max(far, math.sqrt((p.x - W.STREET_X0) ^ 2 + (p.z - W.STREET_Z) ^ 2))
	end
	check(far / 48 <= 20, "every plot within a 20 s gallop of the grandstand")

	-- Care (Stage 3) -------------------------------------------------------------------
	local Care = require("../../game/src/shared/Care")
	local cp = Profile.new(T0)
	local ch = Horse.starter(Profile.newHorseId(cp), "Biscuit", "bay", rng, T0)
	Profile.addHorse(cp, ch)
	ch.energy = 3
	local ok, msg = Care.feed(cp, ch, "hay", T0, E)
	check(ok and cp.items.hay == 9 and ch.care.fed and ch.energy == 4 and string.find(msg, "Energy") ~= nil, "feeding uses hay, fills care, tops up energy")
	ok = Care.feed(cp, ch, "hay", T0 + 10, E)
	check(not ok and cp.items.hay == 9, "one meal a day, no hay wasted")
	ok = Care.feed(cp, ch, "carrot", T0 + 86400, E)
	check(not ok, "carrots are treats, not meals")
	cp.items.hay = nil
	ok, msg = Care.feed(cp, ch, "hay", T0 + 86400, E)
	check(not ok and string.find(msg, "Muck out") ~= nil, "out of hay points to chores")
	ok = Care.groom(cp, ch, T0, E)
	check(ok and ch.care.groomed and not Care.groom(cp, ch, T0 + 5, E), "groom once a day")

	-- Treats: bond, a few a day.
	cp.items.carrot = 10
	local bond0 = ch.bond
	for _ = 1, Care.TREATS_PER_DAY do Care.treat(cp, ch, "carrot", T0) end
	check(ch.bond == bond0 + 2 * Care.TREATS_PER_DAY and cp.items.carrot == 10 - Care.TREATS_PER_DAY, "treats add bond")
	ok = Care.treat(cp, ch, "carrot", T0 + 60)
	check(not ok and cp.items.carrot == 10 - Care.TREATS_PER_DAY, "treat limit per day keeps carrots")
	check(Care.treat(cp, ch, "carrot", T0 + 86400), "treats again tomorrow")
	check(not Care.treat(cp, ch, "hay", T0 + 86400), "hay isn't a treat")
	local b1 = ch.bond
	Care.pet(cp, ch, T0 + 86400)
	local ok2 = Care.pet(cp, ch, T0 + 86400 + 60)
	check(ch.bond == b1 + 1 and ok2, "petting: bond once a day, always allowed")

	-- Garden: plant, grow offline, harvest, never wither.
	cp.items.seed_carrot = 1
	check(Care.plant(cp, 1, "seed_carrot", T0) and cp.items.seed_carrot == nil, "plant uses a seed")
	check(not Care.plant(cp, 1, "seed_carrot", T0), "one crop per bed")
	check(not Care.plant(cp, 4, "seed_carrot", T0) and not Care.plant(cp, 1.5, "seed_carrot", T0), "only beds 1-3")
	check(not Care.harvest(cp, 1, T0 + 60), "not ready early")
	check(close(Care.cropProgress(cp.garden[1], T0 + 1800), 0.5, 1e-9), "half grown at half time")
	local carrots = cp.items.carrot or 0
	check(Care.harvest(cp, 1, T0 + 10 * 86400) and cp.items.carrot == carrots + 3 and cp.garden[1].seed == "", "harvest days later: never withers")
	check(not Care.plant(cp, 2, "seed_apple", T0), "need the seed")

	-- Chores: always hay, cooldown per stall.
	local hay0, cash0 = cp.items.hay or 0, cp.cash
	check(Care.chore(cp, 1, T0) and cp.items.hay == hay0 + 1 and cp.cash == cash0 + 2, "chore pays hay and cash")
	check(not Care.chore(cp, 1, T0 + 60), "stall stays clean for a while")
	check(Care.chore(cp, 2, T0 + 60), "other stall is fine")
	check(not Care.chore(cp, 3, T0) and not Care.chore(cp, 0, T0), "only your stalls")
	check(Care.chore(cp, 1, T0 + Care.CHORE.cooldownSeconds), "clean again later")

	-- Shop: buy within cash, sell crops only.
	cp.cash = 20
	check(Care.buy(cp, "hay", 5) and cp.cash == 10, "buy hay")
	check(not Care.buy(cp, "grain", 5) and cp.cash == 10, "can't overspend")
	check(not Care.buy(cp, "diamond", 1) and not Care.buy(cp, "hay", 0) and not Care.buy(cp, "hay", 2.5) and not Care.buy(cp, "hay", 999),
		"only listed items, sane amounts")
	cp.items.apple = 3
	check(Care.sell(cp, "apple", 3) and cp.cash == 16 and cp.items.apple == nil, "sell apples")
	check(not Care.sell(cp, "hay", 1), "hay isn't bought back")

	-- Garden and chores survive migration.
	cp.garden[2] = { seed = "seed_oats", at = T0 }
	local mig = Profile.migrate(cp, T0)
	check(mig.garden[2].seed == "seed_oats" and #mig.garden == Profile.BEDS and mig.chores["1"] ~= nil, "garden and chores saved")
	check(#Profile.migrate(nil, T0).garden == Profile.BEDS, "new profile has empty beds")

	-- Jobs (Stage 5) --------------------------------------------------------------------
	local Jobs = require("../../game/src/shared/Jobs")
	local Advice = require("../../game/src/shared/Advice")
	local PaceMeter = require("../../game/src/shared/PaceMeter")
	local jp = Profile.new(T0)
	Jobs.refresh(jp, 12345, T0)
	check(#jp.jobs.daily == 3 and #jp.jobs.weekly == 5 and #jp.jobs.monthly == 5, "3 daily, 5 weekly, 5 monthly")
	local again = Profile.new(T0)
	Jobs.refresh(again, 12345, T0 + 3600)
	local same = true
	for i = 1, 3 do if again.jobs.daily[i].id ~= jp.jobs.daily[i].id then same = false end end
	check(same, "same jobs on any server the same day")
	local noWin, noSpend = true, true
	for _, pool in { Jobs.DAILY, Jobs.WEEKLY, Jobs.MONTHLY } do
		for _, d in pool do
			if string.find(string.lower(d.text), "win") then noWin = false end
			if d.event == "buy" or d.event == "spend" or d.event == "invite" then noSpend = false end
			if d.reward.items then
				for item in d.reward.items do if not table.find(Profile.ITEMS, item) then noSpend = false end end
			end
		end
	end
	check(noWin and noSpend, "no win, spend or invite jobs; rewards are real items")
	local dailyCash = 0
	for _, d in Jobs.DAILY do dailyCash = math.max(dailyCash, d.reward.cash or 0) end
	check(dailyCash * 3 <= 30, "daily job cash stays small (about 10% of a day's races)")
	-- Progress, claim, rollover auto-claim.
	local first = jp.jobs.daily[1]
	local def = Jobs.def(first.id)
	local finished = Jobs.record(jp, 12345, def.event, def.target, T0)
	local found = false
	for _, d in finished do if d.id == first.id then found = true end end
	check(found and first.progress == def.target, "recording finishes a job")
	Jobs.record(jp, 12345, def.event, 50, T0)
	check(first.progress == def.target, "progress caps at the target")
	local cashBefore = jp.cash
	check(Jobs.claim(jp, 12345, "daily", 1, T0) and jp.cash == cashBefore + (def.reward.cash or 0), "claim pays the reward")
	check(not Jobs.claim(jp, 12345, "daily", 1, T0), "claim once")
	local second = jp.jobs.daily[2]
	local def2 = Jobs.def(second.id)
	Jobs.record(jp, 12345, def2.event, def2.target, T0)
	local cash2 = jp.cash
	local auto = Jobs.refresh(jp, 12345, T0 + 86400)
	check(auto >= 1 and jp.cash >= cash2 + (def2.reward.cash or 0) and jp.jobs.daily[1].progress == 0, "rollover auto-claims finished jobs")
	-- Reroll once a day, only unfinished jobs.
	local before = jp.jobs.daily[3].id
	check(Jobs.reroll(jp, 12345, 3, T0 + 86400) and jp.jobs.daily[3].id ~= before, "free swap")
	check(not Jobs.reroll(jp, 12345, 2, T0 + 86400), "one swap a day")
	-- All done today.
	for i = 1, 3 do
		local d = Jobs.def(jp.jobs.daily[i].id)
		Jobs.record(jp, 12345, d.event, d.target, T0 + 86400)
		Jobs.claim(jp, 12345, "daily", i, T0 + 86400)
	end
	check(Jobs.allDoneToday(jp), "all done today")
	local jv = Jobs.view(jp)
	check(#jv.daily == 3 and jv.daily[1].text ~= nil and jv.rerollUsed, "jobs view for the board")

	-- Advice: facts, never guilt.
	local tipA = Advice.forHorse({ name = "Comet", fed = false, groomed = false, resting = false, stats = {} }, { garden = {} }, T0)
	check(tipA.go == "stable" and string.find(tipA.next, "hay") ~= nil, "unfed: a meal is next")
	local tipB = Advice.forHorse({ name = "Comet", fed = true, groomed = true, resting = false, stats = {} }, { garden = {} }, T0)
	check(tipB.go == "raceBoard", "cared for and rested: race next")
	local tipC = Advice.forHorse({ name = "Comet", fed = true, groomed = true, resting = true, stats = {} }, { garden = {} }, T0)
	local guilt = false
	for _, tip in { tipA, tipB, tipC } do
		local text = string.lower(tip.fact .. " " .. tip.next)
		for _, w in { "miss", "hungry", "sad", "lonely", "neglect" } do
			if string.find(text, w) then guilt = true end
		end
	end
	check(not guilt and string.find(tipC.fact, "napping") ~= nil, "tips state facts, never guilt")
	check(Advice.trainNext({ stats = { speed = 50, accel = 60, stamina = 40, grit = 70 }, potential = { speed = 80, accel = 70, stamina = 85, grit = 75 } }) == "stamina",
		"train the stat with the most room")

	-- PaceMeter.countAtLeast: single good taps only.
	local passes = { { t0 = 0, t1 = 1, dir = 1, center = 0 }, { t0 = 1, t1 = 2, dir = -1, center = 0 } }
	check(PaceMeter.countAtLeast(passes, { 0.5, 1.5 }, 80) == 2, "two centred taps are Great")
	check(PaceMeter.countAtLeast(passes, { 0.5, 0.51, 1.5 }, 80) == 1, "a doubled pass doesn't count")
	check(PaceMeter.countAtLeast(passes, { 0.05 }, 80) == 0, "an edge tap isn't Great")
end
