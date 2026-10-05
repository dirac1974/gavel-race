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
	check(p.cash == Profile.START_CASH and Profile.itemCount(p, "hay") == 10 and Profile.itemCount(p, "seed_carrot") == 2 and #p.horses == 0, "new profile")
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
	local _, _, counted3 = Care.pet(cp, ch, T0 + 86400 + 120)
	check(counted3 == false, "only the first pets of the day count toward jobs")

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
	cp.items.carrot, cp.items.oats = 8, 2
	local cashS = cp.cash
	check(Care.sellAll(cp, 5) and cp.items.carrot == 5 and cp.items.oats == 2 and cp.cash == cashS + 3, "sell all keeps 5 of each")
	check(not Care.sellAll(cp, 5), "nothing left to sell")
	local bad = Profile.migrate({ garden = { { seed = "seed_moon", at = 5 }, { seed = "seed_oats", at = 7 } } }, T0)
	check(bad.garden[1].seed == "" and bad.garden[2].seed == "seed_oats", "unknown seeds are cleared on load")

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
	-- A server whose clock is behind can't roll the jobs back.
	local before2 = jp.jobs.daily[1].id
	Jobs.refresh(jp, 12345, T0)
	check(jp.jobs.daily[1].id == before2 and jp.jobs.daily[1].claimed, "jobs only roll forward")
	-- Claim all in one set.
	local wk = jp.jobs.weekly
	for i = 1, 2 do
		local d = Jobs.def(wk[i].id)
		Jobs.record(jp, 12345, d.event, d.target, T0 + 86400)
	end
	check(Jobs.claimAllIn(jp, 12345, "weekly", T0 + 86400) >= 2, "claim all in a set")
	local jv = Jobs.view(jp)
	check(#jv.daily == 3 and jv.daily[1].text ~= nil and jv.rerollUsed, "jobs view for the board")

	-- Advice: facts, never guilt.
	local tipA = Advice.forHorse({ name = "Comet", fed = false, groomed = false, resting = false, stats = {} }, { garden = {} }, T0)
	check(tipA.go == "stable" and string.find(tipA.next, "hay") ~= nil, "unfed: a meal is next")
	local tipB = Advice.forHorse({ name = "Comet", fed = true, groomed = true, resting = false, stats = {} }, { garden = {} }, T0)
	check(tipB.go == "raceBoard", "cared for and rested: race next")
	local tipS = Advice.forHorse({ name = "Comet", league = "Rookie", fed = true, groomed = true, resting = false, stakesOpen = true, stats = {} }, { garden = {} }, T0)
	check(string.find(tipS.next, "Stakes") ~= nil and tipS.go == "raceBoard", "Stakes open: win it to move up")
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

	-- Training and the vet (Stage 6) ------------------------------------------------------
	local Training = require("../../game/src/shared/Training")
	local th = Horse.starter("h7", "Clover", "bay", rng, T0)
	th.potential.speed = 85
	local okT, g1, msgT = Training.train(th, "speed", 100, T0)
	-- never trained = rested: 0.12 × 40 × 1.0 × 1.5 = 7.2, capped at 6 for the week
	check(okT and close(g1, 6, 1e-9) and close(th.stats.speed, 51, 1e-9) and string.find(msgT, "Rested") ~= nil, "first session: rested bonus, weekly cap")
	check(not Training.train(th, "accel", 100, T0 + 60), "weekly cap stops more training")
	check(not Training.ready(th, T0 + 60) and Training.ready(th, T0 + 8 * 86400), "cap resets next week")
	local th2 = Horse.starter("h8", "Daisy", "grey", rng, T0)
	th2.potential.stamina = 75
	local _, ga = Training.train(th2, "stamina", 0, T0)                    -- rested, poor score: 0.12 × 30 × 0.5 × 1.5 = 2.7
	local _, gb = Training.train(th2, "stamina", 100, T0 + 600)            -- not rested: 0.12 × 27.3 × 1.0 = 3.276 → capped at 3.3 (6 − 2.7)
	check(close(ga, 2.7, 1e-9) and close(gb, 3.3, 1e-9), "gain follows room left, score and rest; cap total")
	local th3 = Horse.starter("h9", "Pebble", "black", rng, T0)
	th3.potential.grit = th3.stats.grit
	check(not Training.train(th3, "grit", 100, T0), "no training past Potential")
	check(not Training.train(th3, "luck", 100, T0) and not Training.train(th3, "speed", 0 / 0, T0), "only real stats and scores")
	-- gains slow near Potential
	local near = Horse.starter("h10", "Sunny", "palomino", rng, T0)
	near.potential.accel, near.stats.accel = 80, 78
	local _, gn = Training.train(near, "accel", 100, T0)
	check(gn <= 2 and near.stats.accel <= 80, "never above Potential")
	-- vet
	local vh = Horse.starter("h11", "Biscuit", "bay", rng, T0)
	local okV, msgV, stamp = Training.checkup(vh, 80, T0)
	check(okV and stamp == "checkup" and vh.bond == 1 and string.find(msgV, "stamp") ~= nil, "first check-up: stamp and bond")
	local _, _, stamp2 = Training.checkup(vh, 80, T0 + 60)
	check(stamp2 == nil and vh.bond == 1, "one check-up a day counts")
	local _, _, stamp3 = Training.checkup(vh, 20, T0 + 86400)
	check(stamp3 == "potential" and vh.stamps.potential and Horse.view(vh, T0 + 86400, E).potential ~= nil, "second visit reveals Potential")

	-- Two courses (Stage 4) -------------------------------------------------------------
	local dirtCfg, turfCfg = TrackLayout.churchill, TrackLayout.churchillTurf
	local _, _, dz = TrackLayout.finishLine(dirtCfg)
	local _, _, tz = TrackLayout.finishLine(turfCfg)
	check(close(dz, tz, 1e-9), "both courses finish on the same line")
	check(TrackLayout.outerRadius(turfCfg) < dirtCfg.railRadius - 10, "turf course sits inside the dirt rail")
	local okLen = true
	for _, d in { "Sprint", "Mile", "Classic", "Marathon" } do
		local plan = TrackLayout.plan(turfCfg, TrackLayout.distances[d])
		if math.abs(plan.lengths[1] - TrackLayout.distances[d]) > 800 then okLen = false end -- gates snap forward to a straight
		for i = 2, 8 do
			if plan.lengths[i] < plan.lengths[1] - 1 then okLen = false end -- outer lanes run at least as far
		end
	end
	check(okLen, "turf races run about their distance in every lane")
	check(TrackLayout.courses.dirt == dirtCfg and TrackLayout.courses.turf == turfCfg, "course table")

	-- Spectators (Stage 7) -------------------------------------------------------------
	local Fans = require("../../game/src/shared/Fans")
	check(Fans.raceXp({ 100, 100, 100, 100 }, true, 0) == Fans.XP_PER_RACE, "fan XP capped per race")
	check(Fans.raceXp({ 85, 62, 10 }, false, 0) == 3, "Great 2 + Good 1")
	check(Fans.raceXp({ 100, 100 }, true, 95) == 5, "daily cap")
	check(Fans.level(0) == 1 and Fans.level(250) == 3, "fan levels every 100 XP")
	local beats = {}
	for k = 1, 60 do beats[k] = k * 0.55 end
	local perfect = table.clone(beats)
	check(close(Fans.clapScore(beats, perfect), 100, 1e-9), "perfect claps score 100")
	local mash = {}
	for k = 1, 400 do mash[k] = k * 0.08 end
	check(Fans.clapScore(beats, mash) == 0, "mashing scores 0")
	local human = {}
	local hr = makeRng(5)
	for k, b in beats do human[k] = b + (hr:NextNumber() - 0.5) * 0.08 end
	local hs = Fans.clapScore(beats, human)
	check(hs > 40 and hs < 90 and not Fans.flagged(beats, human), "a human fan scores well and isn't flagged")
	check(Fans.flagged(beats, perfect), "perfectly steady claps are flagged")
	check(close(Fans.crowd({ 100 }), 1, 1e-9) and close(Fans.crowd({ 50, 50, 50 }), 0.625, 1e-9) and close(Fans.crowd({}), 0, 1e-9),
		"crowd: best fan full, assists small")
	check(Fans.crowd({ 60, 40 }) >= Fans.crowd({ 60 }) and Fans.crowd({ 60, 40, 30, 90 }) == Fans.crowd({ 90, 60, 40 }),
		"another fan never lowers the crowd; the fourth adds nothing")
	check(close(Fans.boost(1), 0.03, 1e-12), "full crowd boost")
	local fb = Fans.beats(makeRng(9), 10, 30, 0.55, 0.03)
	local okBeats = #fb > 30
	for k = 2, #fb do
		local g = fb[k] - fb[k - 1]
		if g < 0.55 * 0.85 - 1e-9 or g > 0.55 * 1.15 + 1e-9 then okBeats = false end
	end
	check(okBeats, "clap beats drift within ±15%")
	local entries = {
		{ id = "a", name = "A", score = 80, flagged = false }, { id = "b", name = "B", score = 95, flagged = true },
		{ id = "c", name = "C", score = 60, flagged = false }, { id = "d", name = "D", score = 0, flagged = false },
	}
	local top = Fans.topFans(entries)
	check(#top == 2 and top[1].id == "a" and Fans.rankOf(entries, "c") == 2 and Fans.rankOf(entries, "d") == nil
		and Fans.rankOf(entries, "b") == 1, "top fans skip flagged and zero; flagged fans still see their own rank")

	-- More horses (Stage 8) ---------------------------------------------------------------
	local Market = require("../../game/src/shared/Market")
	local stockA, stockB = Market.stock(T0), Market.stock(T0 + 3600)
	check(#stockA == Market.STOCK_SIZE and stockA[1].id == stockB[1].id and stockA[1].price == stockB[1].price, "same stock all week, every server")
	local nextWeek = Market.stock(T0 + 7 * 86400)
	check(nextWeek[1].id ~= stockA[1].id, "new stock next week")
	local priced = true
	for _, l in stockA do
		if l.price < 250 or l.stars < 1 or l.stars > 3 or not table.find(Market.MARKET_COATS, l.coat) then priced = false end
		for _, k in Horse.STATS do if l.potential[k] < l.stats[k] then priced = false end end
	end
	check(priced, "listings are sane")
	local cheap = { stats = { speed = 40, accel = 40, stamina = 40, grit = 40 }, potential = { speed = 66, accel = 66, stamina = 66, grit = 66 } }
	local fancy = { stats = { speed = 40, accel = 40, stamina = 40, grit = 40 }, potential = { speed = 92, accel = 92, stamina = 92, grit = 92 } }
	check(Market.price(fancy) > Market.price(cheap) * 2 and Market.stars(fancy.potential) == 3 and Market.stars(cheap.potential) == 1, "price and stars follow bloodline")
	check(Market.viewListing(stockA[1], false).potential == nil, "listing hides Potential numbers")
	local mp = Profile.new(T0)
	Profile.addHorse(mp, Horse.starter(Profile.newHorseId(mp), "Lucky", "bay", rng, T0))
	Profile.addHorse(mp, Horse.starter(Profile.newHorseId(mp), "Pip", "grey", rng, T0))
	mp.cash = 100000
	local l1 = stockA[1]
	local okB, msgB, hb = Market.buy(mp, l1.id, T0)
	check(okB and hb and #mp.horses == 3 and mp.cash == 100000 - l1.price and string.find(msgB, "pasture") ~= nil, "buy: pays, goes to the pasture when stalls are full")
	check(not Market.buy(mp, l1.id, T0), "each listing once per player")
	check(not Market.buy(mp, "m1_1", T0), "old listings can't be bought")
	mp.cash = 0
	check(not Market.buy(mp, stockA[2].id, T0) and #mp.horses == 3, "can't buy without the cash")
	-- stalls
	mp.cash = 300
	check(Market.nextStallPrice(mp) == 300 and Market.buyStall(mp) and mp.stalls == 3 and mp.cash == 0, "third stall")
	check(Profile.isStalled(mp, hb.id), "the pasture horse now has a stall")
	mp.cash = 100000
	for _ = 1, 3 do Market.buyStall(mp) end
	check(mp.stalls == 6 and not Market.buyStall(mp), "six stalls at most")
	-- taming
	local tp = Profile.new(T0)
	tp.items.carrot = nil
	check(not Market.canTame(tp, T0), "need a treat to tame")
	tp.items.apple = 2
	local okT2, _, th2 = Market.tame(tp, "appaloosa", makeRng(4), T0)
	check(okT2 and th2.coat == "appaloosa" and tp.items.apple == 1 and #tp.horses == 1, "taming uses a treat, keeps the wild coat")
	check(not Market.tame(tp, "dun", makeRng(5), T0 + 60), "one new friend a day")
	check(Market.tame(tp, "zebra", makeRng(6), T0 + 86400), "tomorrow again (unknown coats become a wild one)")
	check(table.find(Market.WILD_COATS, tp.horses[2].coat) ~= nil, "wild coats only")
	-- full stable
	local fp = Profile.new(T0)
	for k = 1, Market.MAX_HORSES do Profile.addHorse(fp, Horse.starter(Profile.newHorseId(fp), "H" .. k, "bay", rng, T0)) end
	fp.items.treat = 3
	fp.cash = 100000
	check(not Market.canTame(fp, T0) and not Market.buy(fp, stockA[3].id, T0), "stable full at 20 horses")
	check(Market.rename(fp, fp.horses[1].id, "Sunny", "Moon") and fp.horses[1].name == "Sunny Moon" and not Market.rename(fp, fp.horses[1].id, "Bad", nil),
		"rename with word chips only")

	-- Leagues (Stage 9) ---------------------------------------------------------------------
	local Leagues = require("../../game/src/shared/Leagues")
	check(Leagues.UNLOCK.Rookie == GameConfig.stakesUnlockPoints.Rookie and Leagues.UNLOCK.Gold == GameConfig.stakesUnlockPoints.Gold,
		"Stakes thresholds match D-013")
	local lh = Horse.starter("h30", "Rocket", "bay", rng, T0)
	check(Leagues.pointsToStakes(lh) == 100 and not Leagues.stakesOpen(lh, 50), "Stakes closed at first")
	check(Leagues.canEnter(lh, { league = "Rookie" }, 50) and not Leagues.canEnter(lh, { league = "Bronze" }, 50), "own league only")
	check(not Leagues.canEnter(lh, { league = "Rookie", stakes = true }, 50), "no Stakes before the points")
	lh.points = 100
	check(Leagues.stakesOpen(lh, 50) and Leagues.canEnter(lh, { league = "Rookie", stakes = true }, 50), "Stakes open at 100 points")
	local strong = Horse.starter("h31", "Mighty", "grey", rng, T0)
	check(Leagues.stakesOpen(strong, 60) and not Leagues.canEnter(strong, { league = "Rookie" }, 60)
		and Leagues.canEnter(strong, { league = "Rookie", practice = true }, 60), "over-strong: Stakes open, regular closed, Practice open")
	check(Leagues.promote(lh) == "Bronze" and lh.league == "Bronze" and lh.points == 0, "a Stakes win promotes and resets points")
	local champ = Horse.starter("h32", "Star", "black", rng, T0)
	champ.league = "Champion"
	check(Leagues.promote(champ) == nil and not Leagues.stakesOpen(champ, 99) and Leagues.pointsToStakes(champ) == nil, "Champion is the top")
	local rp = Profile.new(T0)
	local r1 = Horse.starter(Profile.newHorseId(rp), "Old Timer", "bay", rng, T0)
	local r2 = Horse.starter(Profile.newHorseId(rp), "Young One", "grey", rng, T0)
	Profile.addHorse(rp, r1)
	Profile.addHorse(rp, r2)
	r1.record.races, r1.record.wins = 40, 9
	local plaque = Leagues.retire(rp, r1.id, T0)
	check(plaque and plaque.wins == 9 and #rp.horses == 1 and rp.activeHorse == r2.id and rp.hallOfFame[1].name == "Old Timer",
		"retiring keeps a Hall of Fame plaque")
	check(Leagues.retire(rp, "nope", T0) == nil, "only your horses retire")
end
