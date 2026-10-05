--!strict
-- Tests for the world modules: Horse, Profile, NameGen (Stage 1).
local Horse = require("../../game/src/shared/Horse")
local Profile = require("../../game/src/shared/Profile")
local NameGen = require("../../game/src/shared/NameGen")
local RaceRating = require("../../game/src/shared/RaceRating")
local GameConfig = require("../../game/src/shared/GameConfig")

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
end
