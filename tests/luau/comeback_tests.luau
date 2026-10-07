--!strict
-- Stage 6 of docs/plans/horse-life-and-retention.md (D-063): reasons to come back. Monthly stamps
-- pay out the month's saddle cloth (once, never sold), the Welcome Back Hay Bale is flat (the same
-- after 3 or 30 days away, never on two days in a row, no streak), personal bests change only on
-- improvement, the Horse Book lists every coat in MeshAssets and keeps what's earned, the tour's
-- first GO races, and no new copy pressures or guilts a kid.
local fs = require("@lune/fs")
local Profile = require("../../game/src/shared/Profile")
local Horse = require("../../game/src/shared/Horse")
local Jobs = require("../../game/src/shared/Jobs")
local Style = require("../../game/src/shared/Style")
local HorseBook = require("../../game/src/shared/HorseBook")
local WelcomeBack = require("../../game/src/shared/WelcomeBack")
local Leagues = require("../../game/src/shared/Leagues")
local Training = require("../../game/src/shared/Training")
local Spa = require("../../game/src/shared/Spa")
local Tour = require("../../game/src/shared/Tour")
local MeshAssets = require("../../game/src/shared/MeshAssets")
local ModelSpecs = require("../../game/src/shared/ModelSpecs")
local GameConfig = require("../../game/src/shared/GameConfig")

local DAY = 86400
local T0 = 20000 * DAY + 3600 -- 2024-10-04 01:00 UTC
local USER = 4242

local function horse(id: string, coat: string, now: number)
	return Horse.new(id, "Comet", coat, { speed = 50, accel = 50, stamina = 50, grit = 50 },
		{ speed = 80, accel = 80, stamina = 80, grit = 80 }, now)
end

local function finishMonthly(p: any, n: number)
	for k = 1, n do
		local j = p.jobs.monthly[k]
		j.progress = (Jobs.def(j.id) :: any).target
	end
end

-- Every "..." or '...' literal in a Luau source, outside comments.
local function literals(src: string): { string }
	local out = {}
	for line in string.gmatch(src .. "\n", "([^\n]*)\n") do
		local i, n, quote, buf = 1, #line, nil :: string?, {}
		while i <= n do
			local ch = string.sub(line, i, i)
			if quote then
				if ch == "\\" then
					table.insert(buf, string.sub(line, i, i + 1))
					i += 1
				elseif ch == quote then
					table.insert(out, table.concat(buf))
					quote, buf = nil, {}
				else
					table.insert(buf, ch)
				end
			elseif ch == "-" and string.sub(line, i, i + 1) == "--" then
				break
			elseif ch == "\"" or ch == "'" then
				quote = ch
			end
			i += 1
		end
	end
	return out
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	local CB = GameConfig.comeback
	check(CB ~= nil and CB.welcome.enabled and CB.welcome.awayDays == 3 and CB.studioAwayDays == 0 and CB.studioMonthStamps == 0,
		"comeback config: 3+ days away, Studio pretend values off")

	-- Monthly stamp cloths ---------------------------------------------------------------
	do
		check(Jobs.STAMPS_FOR_COSMETIC == 8, "8 stamps for the month's cloth")
		local every2 = true
		for _, d in Jobs.MONTHLY do
			if d.reward.stamps ~= 2 then every2 = false end
		end
		check(every2, "every monthly job gives 2 stamps")
		check(Jobs.COUNTS.monthly * 2 >= Jobs.STAMPS_FOR_COSMETIC + 2, "a month's set can always reach 8 stamps, with one job to spare")
		for m = 1, 12 do
			local it = Style.monthCloth(m)
			check(it ~= nil and it.slot == "cloth" and it.month == m and not Style.forSale(it) and not Style.isStarter(it),
				`month {m} has its own cloth, never sold, not a free starter`)
		end
		check(Style.monthOfPeriod(2024 * 12 + 12) == 12 and Style.monthOfPeriod(2025 * 12 + 1) == 1, "months from Jobs periods")

		local p = Profile.new(T0)
		Jobs.refresh(p, USER, T0)
		local month = Style.monthOfPeriod(Jobs.periods(T0).monthly)
		local cloth = Style.monthCloth(month) :: any
		check(month == 10 and cloth.id == "cloth_m10", "October's cloth is the Pumpkin cloth")
		check(not Style.owns(p, cloth.id), "the cloth isn't owned at the start")
		p.diamonds = 1000
		local okBuy = Style.buy(p, cloth.id, T0)
		check(not okBuy and p.diamonds == 1000 and not Style.owns(p, cloth.id), "the monthly cloth can't be bought, even with Diamonds")
		check(not (Style.equip(p, cloth.id)), "an unearned cloth can't be worn")
		check(Style.worn(p, "cloth").id == "cloth_plain", "the plain cloth is still the free starter")
		finishMonthly(p, 3)
		for k = 1, 3 do Jobs.claim(p, USER, "monthly", k, T0) end
		check(p.jobs.monthStamps == 6 and not Style.owns(p, cloth.id), "6 stamps: not yet")
		check(Jobs.view(p).monthStamps == 6 and Jobs.view(p).monthCloth == cloth.id and Jobs.view(p).clothEarned == false, "the board shows 6 of 8 and this month's cloth")
		finishMonthly(p, 4)
		Jobs.claim(p, USER, "monthly", 4, T0)
		check(p.jobs.monthStamps == 8 and Style.owns(p, cloth.id), "8 stamps earn the month's cloth")
		check(#(p.jobs.clothDue or {}) == 1 and p.jobs.clothDue[1] == cloth.id, "JobService is told once")
		finishMonthly(p, 5)
		Jobs.claim(p, USER, "monthly", 5, T0)
		check(p.jobs.monthStamps == 10 and #p.jobs.clothDue == 1, "more stamps never earn it twice")
		check(Jobs.view(p).clothEarned == true, "the board shows it earned")
		check(not Style.canReturn(p, cloth.id, T0) and not (Style.giveBack(p, cloth.id, T0)), "an earned cloth can't be returned for Diamonds")
		check(p.diamonds == 1000, "earning a cloth never touches Diamonds")
		check(Style.equip(p, cloth.id) and Style.worn(p, "cloth").id == cloth.id, "the earned cloth can be worn")
		check(Style.unequip(p, cloth.id) and Style.worn(p, "cloth").id == "cloth_plain", "and taken off")
		-- next month: a fresh count, the cloth stays
		local nextMonth = T0 + 40 * DAY
		Jobs.refresh(p, USER, nextMonth)
		check(p.jobs.monthStamps == 0 and Style.owns(p, cloth.id), "a new month starts its own stamps; the cloth stays yours")
		check(Jobs.view(p).monthCloth == "cloth_m11", "November shows the Leaf cloth")
	end

	do -- finished but unclaimed when the month ends: counts for its own month
		local p = Profile.new(T0)
		Jobs.refresh(p, USER, T0)
		finishMonthly(p, 4)
		Jobs.refresh(p, USER, T0 + 40 * DAY)
		check(Style.owns(p, "cloth_m10") and not Style.owns(p, "cloth_m11"), "auto-claimed stamps earn the month they were done in")
		check(p.jobs.monthStamps == 0, "and the new month starts at 0")
		-- the same month a year later: the cloth comes back, nothing doubles
		local p2 = Profile.new(T0)
		Jobs.refresh(p2, USER, T0)
		p2.style.owned["cloth_m10"] = true
		finishMonthly(p2, 4)
		for k = 1, 4 do Jobs.claim(p2, USER, "monthly", k, T0) end
		check(p2.jobs.clothDue == nil, "a cloth you already have isn't given again")
	end

	do -- an older save with no monthStamps counts this month's claimed jobs
		local p = Profile.new(T0)
		Jobs.refresh(p, USER, T0)
		finishMonthly(p, 2)
		Jobs.claim(p, USER, "monthly", 1, T0)
		Jobs.claim(p, USER, "monthly", 2, T0)
		p.jobs.monthStamps = nil
		Jobs.refresh(p, USER, T0)
		check(p.jobs.monthStamps == 4, "older saves: this month's claimed stamps count")
	end

	-- Welcome Back Hay Bale -----------------------------------------------------------------
	do
		local W = CB.welcome
		local function gifted(daysAway: number): ({ [string]: number }?, any)
			local p = Profile.new(T0 - 400 * DAY)
			local now = T0
			local gift = WelcomeBack.onJoin(p, now - daysAway * DAY, now, W)
			return gift, p
		end
		local g2 = gifted(2)
		local g3, p3 = gifted(3)
		local g30, p30 = gifted(30)
		local g365 = gifted(365)
		check(g2 == nil, "2 days away: no gift")
		check(g3 ~= nil and g30 ~= nil and g365 ~= nil, "3, 30 and 365 days away: a gift")
		local same = g3 ~= nil and g30 ~= nil and g365 ~= nil
		for item, n in W.gift do
			if not (g3 and g30 and g365) or g3[item] ~= n or g30[item] ~= n or g365[item] ~= n then same = false end
		end
		check(same, "the gift is the same size after 3, 30 and 365 days (never grows with absence)")
		check(p3.items.hay == Profile.START_ITEMS.hay + W.gift.hay and p30.items.hay == p3.items.hay, "the hay lands in the stable at once")
		check(p3.items.treat == W.gift.treat and p3.items.seed_carrot == Profile.START_ITEMS.seed_carrot + W.gift.seed_carrot, "seeds and a treat too")
		local v = WelcomeBack.view(p3) :: any
		check(v ~= nil and v.gift.hay == W.gift.hay, "the owner's view shows the gift card")
		check(WelcomeBack.seen(p3) and WelcomeBack.view(p3) == nil and not WelcomeBack.seen(p3), "Thanks! closes it once")
		-- never on consecutive days: even a save that says "10 days away" the next day gets nothing
		local p = Profile.new(T0 - 400 * DAY)
		check(WelcomeBack.onJoin(p, T0 - 5 * DAY, T0, W) ~= nil, "a gift today")
		check(WelcomeBack.onJoin(p, T0 - 10 * DAY, T0 + 3600, W) == nil, "never twice a day")
		check(WelcomeBack.onJoin(p, T0 - 10 * DAY, T0 + DAY, W) == nil, "never on the next day")
		check(WelcomeBack.onJoin(p, T0 + DAY, T0 + 5 * DAY, W) ~= nil, "after another 3+ days away, a gift again (same size)")
		-- a player who comes every day never gets one (it isn't a login reward)
		local daily = Profile.new(T0)
		local any = false
		for d = 1, 40 do
			if WelcomeBack.onJoin(daily, T0 + (d - 1) * DAY, T0 + d * DAY, W) then any = true end
		end
		check(not any, "playing every day gives no welcome-back gift (not a login streak)")
		local off = table.clone(W)
		off.enabled = false
		check(WelcomeBack.onJoin(Profile.new(T0 - 400 * DAY), T0 - 9 * DAY, T0, off) == nil, "switched off: no gift")
		check(WelcomeBack.daysAway(T0 - 3 * DAY, T0) == 3 and WelcomeBack.daysAway(T0 + 5, T0) == 0, "whole days away")
		-- junk in a save is repaired
		local junk = Profile.new(T0)
		junk.welcome = { lastDay = "x", pending = "yes", gift = { hay = 2, diamonds = 999 } }
		WelcomeBack.repair(junk)
		check(junk.welcome.lastDay == -1 and junk.welcome.pending == false and junk.welcome.gift.diamonds == nil, "a bad welcome record is repaired")
	end

	-- Personal bests ---------------------------------------------------------------------------
	do
		local p = Profile.new(T0)
		local isNew, prev = HorseBook.recordBest(p, "Mile", 61.4)
		check(not isNew and prev == nil and p.bests.Mile == 61, "the first Mile sets the best quietly")
		isNew, prev = HorseBook.recordBest(p, "Mile", 55)
		check(not isNew and prev == 61 and p.bests.Mile == 61, "a worse ride leaves the best alone")
		isNew = HorseBook.recordBest(p, "Mile", 61.2)
		check(not isNew and p.bests.Mile == 61, "the same score isn't a new best")
		isNew, prev = HorseBook.recordBest(p, "Mile", 77.6)
		check(isNew and prev == 61 and p.bests.Mile == 78, "a better ride is a New best!")
		check(p.bests.Sprint == nil, "each distance has its own best")
		check(not (HorseBook.recordBest(p, "Moon", 99)) and p.bests.Moon == nil, "unknown distances are ignored")
		check(not (HorseBook.recordBest(p, "Sprint", 0 / 0)) and p.bests.Sprint == nil, "NaN is ignored")
		HorseBook.recordBest(p, "Sprint", 250)
		check(p.bests.Sprint == 100, "scores are capped at 100")
		check(HorseBook.stars(85) == 3 and HorseBook.stars(65) == 2 and HorseBook.stars(40) == 1 and HorseBook.stars(39) == 0, "stars as on the results card")
	end

	-- The Horse Book -------------------------------------------------------------------------------
	do
		-- every coat in MeshAssets is in the book
		local inBook = {}
		for _, c in Horse.COATS do inBook[c] = true end
		local all = true
		local n = 0
		for slot in MeshAssets do
			local coat = string.match(slot, "^horse_stand_(.+)$")
			if coat then
				n += 1
				if not inBook[coat] or not HorseBook.COAT_LABELS[coat] then all = false end
			end
		end
		check(n >= 12 and all, "the book lists every coat in MeshAssets, each with a name")
		local cups = {}
		for i = 1, #Leagues.ORDER - 1 do cups[i] = Leagues.ORDER[i] end
		check(table.concat(HorseBook.CUPS, ",") == table.concat(cups, ","), "a Cup page entry for every league with a Cup")
		check(ModelSpecs.welcome_hay_bale ~= nil and ModelSpecs.photo_frame_stand ~= nil, "the new models have sizes")
		check(MeshAssets.welcome_hay_bale ~= nil and MeshAssets.photo_frame_stand ~= nil, "the new models are uploaded")

		local p = Profile.new(T0)
		local h = horse("h1", "palomino", T0)
		h.ribbons = { speed = "gold", grit_w3 = "silver" }
		h.stamps = { checkup = true, [Spa.STAMP] = true, potential = false }
		Profile.addHorse(p, h)
		HorseBook.sync(p)
		check(p.book.coats.palomino and not p.book.coats.bay, "a horse's coat is found")
		check(p.book.rosettes.speed and not p.book.rosettes.grit, "a gold ribbon is a rosette; silver isn't")
		check(p.book.courses.train_speed and p.book.courses.train_grit and not p.book.courses.train_stamina, "ridden training courses are found")
		check(p.book.passport.checkup and p.book.passport.spa and not p.book.passport.potential, "Passport stamps, the Spa Day's too")
		check(HorseBook.record(p, "courses", "dirt") and not HorseBook.record(p, "courses", "dirt"), "a race course is found once")
		check(HorseBook.record(p, "places", "1") and HorseBook.record(p, "cups", "Rookie"), "a win and a Cup")
		check(not HorseBook.record(p, "cups", "Champion") and not HorseBook.record(p, "nope", "x") and not HorseBook.record(p, "coats", "unicorn"),
			"unknown pages and things are ignored")
		-- what's earned stays earned
		table.clear(p.horses)
		HorseBook.sync(p)
		check(p.book.coats.palomino and p.book.passport.spa, "selling or retiring a horse keeps its pages")
		-- the view
		p.style.owned["cloth_m10"] = true
		p.tour.stamps = { ["111"] = 20000, ["222"] = 20005, ["333"] = 20005 }
		HorseBook.recordBest(p, "Classic", 70)
		local v = HorseBook.view(p)
		local byId = {}
		for _, page in v.pages do byId[page.id] = page end
		check(byId.coats and #byId.coats.entries == #Horse.COATS, "Coats page: every coat")
		check(byId.passport and #byId.passport.entries == #Training.STAMPS + 1, "Passport page: every vet stamp and the Spa Day")
		check(byId.cloths and #byId.cloths.entries == 12, "Cloths page: twelve months")
		local earnedCloth = false
		for _, e in byId.cloths.entries do
			if e.id == "cloth_m10" then earnedCloth = e.earned end
		end
		check(earnedCloth, "the earned cloth shows in the book")
		check(byId.rosettes and #byId.rosettes.entries == 3 + #Training.STATS, "Rosettes page: three places and four training golds")
		check(byId.cups and #byId.cups.entries == 4 and byId.courses and #byId.courses.entries == 6, "Cups and Courses pages")
		check(v.tour.count == 3 and v.tour.friends[1] == 222 and v.tour.friends[2] == 333 and v.tour.friends[3] == 111, "Tour stamps, newest first")
		local classic
		for _, b in v.bests do
			if b.distance == "Classic" then classic = b end
		end
		check(#v.bests == 4 and classic and classic.score == 70 and classic.stars == 2, "Bests: four distances with stars")
		check(v.got > 0 and v.got < v.total, "the book counts what's found")
		-- junk in a save is repaired
		local junk = Profile.new(T0)
		junk.book = { coats = { bay = true, unicorn = true, grey = "yes" }, cups = "x" }
		junk.bests = { Mile = "64.9", Moon = 3, Sprint = -5 }
		HorseBook.repair(junk)
		check(junk.book.coats.bay and junk.book.coats.unicorn == nil and junk.book.coats.grey == nil, "a bad book is repaired")
		check(typeof(junk.book.cups) == "table" and junk.bests.Mile == 64 and junk.bests.Moon == nil and junk.bests.Sprint == 0, "bad bests are repaired")
		local migrated = Profile.migrate({ book = { coats = { dun = true } }, bests = { Sprint = 50 } }, T0)
		check(migrated.book.coats.dun and migrated.bests.Sprint == 50, "a save's book survives a load")
	end

	-- First five minutes: the tour's first GO races -------------------------------------------
	check(Tour.STEPS[1].event == "race" and Tour.STEPS[1].go == "race", "the tour's first GO joins a race (D-063)")
	local gu = fs.readFile("game/src/client/GrownUps.client.luau")
	check(string.find(gu, "go == \"race\"", 1, true) ~= nil and string.find(gu, "QuickRace", 1, true) ~= nil, "GO fires the RACE! button's one tap")
	local hud = fs.readFile("game/src/client/Hud.client.luau")
	check(string.find(hud, "localEvent(\"QuickRace\")", 1, true) ~= nil and string.find(hud, "BookSlot", 1, true) ~= nil,
		"the Hud runs the one tap for the tour and moves the Book into ☰ More on phones")

	-- Copy: no pressure, no guilt, no streaks --------------------------------------------------
	do
		local BANNED = { "streak", "missed you", "miss you", "hurry", "last chance", "expire", "only today", "don't lose", "limited",
			"come back tomorrow", "lose your", "ends in", "left today", "forgot", "lonely", "sad" }
		local files = {
			"game/src/shared/HorseBook.luau", "game/src/shared/WelcomeBack.luau",
			"game/src/client/HorseBookClient.client.luau", "game/src/client/ComeBackClient.client.luau",
			"game/src/server/ComeBackService.server.luau",
		}
		local bad = {}
		for _, f in files do
			for _, s in literals(fs.readFile(f)) do
				local low = string.lower(s)
				for _, w in BANNED do
					if string.find(low, w, 1, true) then table.insert(bad, f .. ": " .. s) end
				end
			end
		end
		check(#bad == 0, "no pressure or guilt words in stage 6 copy: " .. table.concat(bad, " | "))
		-- the cloth names and the gift card never show a date or a countdown
		local digits = false
		for m = 1, 12 do
			if string.find((Style.monthCloth(m) :: any).name, "%d") then digits = true end
		end
		check(not digits, "cloth names have no dates")
		local cbc = fs.readFile("game/src/client/ComeBackClient.client.luau")
		check(string.find(cbc, "PromptSaveCapturesToGallery", 1, true) ~= nil and string.find(cbc, "PromptShareCapture", 1, true) ~= nil
			and string.find(cbc, "HttpService", 1, true) == nil, "photos use Roblox's own save and share prompts only")
	end
end
