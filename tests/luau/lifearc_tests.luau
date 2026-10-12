--!strict
-- The life arc (fun-and-return phase 4, D-078): stages and kind notes on the card, the decline wired
-- into RaceService (rated races only, from the stored declineFrom; bestRating untouched), the Young
-- training bonus before the caps, the Veteran look, and the Riding School: Lend (free, back any time,
-- out of the racing roster, never deleted) and Sell (half the price + the record bonus, Market horses
-- only; tamed and gifted 0 with the goodbye rosette; the starter never sells). No "Rehome" in UI text.
local fs = require("@lune/fs")
local Ageing = require("../../game/src/shared/Ageing")
local Horse = require("../../game/src/shared/Horse")
local Profile = require("../../game/src/shared/Profile")
local Market = require("../../game/src/shared/Market")
local Leagues = require("../../game/src/shared/Leagues")
local Training = require("../../game/src/shared/Training")
local HorseLook = require("../../game/src/shared/HorseLook")
local GameConfig = require("../../game/src/shared/GameConfig")
local Words = require("../../game/src/shared/Words")

local T0 = 1_760_000_000
local S = { speed = 50, accel = 50, stamina = 50, grit = 50 }
local P = { speed = 80, accel = 80, stamina = 80, grit = 80 }

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	-- one Veteran (ruling 3)
	check(GameConfig.career.veteranAt == GameConfig.ageing.veteranAt and GameConfig.career.veteranAt == 350, "career.veteranAt = ageing.veteranAt = 350")
	-- the card's stage and notes
	local h = Horse.new("h2", "Comet", "bay", S, P, T0)
	check(Ageing.view(h).stage == "Young" and Ageing.view(h).young, "a new horse is Young")
	h.record.races = 345
	local v = Ageing.view(h)
	check(v.stage == "Prime" and v.toVeteran == 5, "Veteran in 5 races")
	h.record.races = 350
	check(Ageing.note(h) == nil and Ageing.view(h).stage == "Veteran" and not Ageing.view(h).peak, "a Veteran not at its peak: no declineFrom")
	h.stats = table.clone(P)
	check(Ageing.note(h) == 350 and Ageing.view(h).peak, "at its peak: declineFrom stored, 'at full strength'")
	h.stats = table.clone(S)
	check(Ageing.note(h) == 350, "declineFrom never un-sets")
	h.record.races = 395
	check(Ageing.view(h).warning, "the kind warning 10 races before the first step")
	h.record.races = 400
	check(not Ageing.view(h).warning and Ageing.view(h).steps == 1, "the first step, no warning after it")
	h.record.races = 445
	check(not Ageing.view(h).warning, "the warning comes before the first step only")
	local a, b = Ageing.warnLines("Comet")
	for _, l in { a, b, Ageing.peakLine("Comet"), Ageing.WISE_LINE, Ageing.YOUNG_LINE, Ageing.PRACTICE_LINE } do
		check(Words.count(l) <= 6 and Words.banned(l) == nil, "life copy short and kind: " .. l)
	end
	-- saves: old profiles default safely
	local old = Profile.migrate({ horses = { { id = "h1", name = "Old", record = { races = 500 } } } }, T0)
	check(old.horses[1].ageing.declineFrom == nil and old.horses[1].lent == nil, "an old save: no declineFrom, not lent")
	local view = Profile.view(old, T0, GameConfig.energy)
	check(view.horses[1].life.stage == "Veteran" and view.horses[1].life.steps == 0, "the view: Veteran, no decline until its peak is stored")
	-- RaceService: the decline in rated races only, bestRating untouched
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	check(string.find(rs, "rating = Ageing.racedRating(rating, h.record.races, Ageing.declineFromOf(h), card.practice)", 1, true) ~= nil,
		"RaceService races with Ageing.racedRating (never in Practice)")
	check(string.find(rs, "Ageing.note(hp)", 1, true) ~= nil, "declineFrom updated after counted races")
	local best0 = string.find(rs, "local function bestRating", 1, true)
	local best1 = if best0 then string.find(rs, "local function cardsView", best0, true) else nil
	local best = if best0 and best1 then string.sub(rs, best0, best1) else ""
	check(#best > 0 and string.find(best, "Ageing", 1, true) == nil, "bestRating (ceilings) is untouched")
	check(close(Ageing.racedRating(60, 500, 350, true), 60, 1e-12), "Practice: no decline")
	-- Young training: x1.25 before the caps
	local y = Horse.new("h3", "Pip", "grey", S, P, T0)
	local prime = Horse.new("h4", "Max", "grey", S, P, T0)
	prime.record.races = GameConfig.ageing.youngRaces
	y.training = { week = -1, gained = 0, lastAt = T0 }
	prime.training = { week = -1, gained = 0, lastAt = T0 }
	local gy, gp = Training.gain(y, "speed", 50, T0 + 60), Training.gain(prime, "speed", 50, T0 + 60)
	check(close(gy, math.min(gp * GameConfig.ageing.youngTrainMult, Training.WEEKLY_CAP), 1e-9) and gy > gp, "Young trains x1.25")
	y.potential.speed = 51
	check(Training.gain(y, "speed", 100, T0 + 60) <= 1 + 1e-9, "never past Potential")
	-- the Veteran look and the wraps (pure part)
	local vet = Horse.new("h5", "Old", "bay", S, P, T0)
	vet.record.races = 360
	local look = HorseLook.of(vet)
	check(look ~= nil and look.veteran and not look.legend, "a Veteran gets the frosted look")
	check(HorseLook.of(Horse.new("h6", "Kid", "bay", S, P, T0)) == nil, "a young horse: no look")
	GameConfig.horseLook.veteranLook = false
	check(HorseLook.of(vet) == nil, "horseLook.veteranLook = false turns it off")
	GameConfig.horseLook.veteranLook = true
	check(HorseLook.key(look) ~= HorseLook.key(nil), "the barn rebuilds when the look changes")

	-- the Riding School: Sell
	check(GameConfig.sell.recordBonusCap == 100 and GameConfig.sell.recordBonusCap < 125, "sell.recordBonusCap 100 (< 125: a sale never beats the price)")
	local m = Horse.new("hm", "M", "bay", S, P, T0)
	m.origin, m.paid = "market", 400
	m.record.wins, m.record.cups = 30, 2
	check(Market.rehomeValue(m) == 200 + 100, "half the price + the capped record bonus (life_arc.sell_value)")
	m.record.wins, m.record.cups = 3, 0
	check(Market.rehomeValue(m) == 215, "a small record: +5 a win")
	for paid = 250, 5000, 50 do
		local x = Horse.new("hx", "X", "bay", S, P, T0)
		x.origin, x.paid = "market", paid
		x.record.wins, x.record.cups = 999, 9
		check(Market.rehomeValue(x) < paid, "a sale never pays the price back: " .. paid)
	end
	local tamed = Horse.new("ht", "T", "dun", S, P, T0)
	tamed.origin, tamed.paid = "tamed", 0
	tamed.record.wins = 50
	check(Market.rehomeValue(tamed) == 0, "a tamed horse sells for 0 (the goodbye rosette)")
	local gift = Horse.new("hg", "G", "dun", S, P, T0)
	gift.origin, gift.paid = "gift", 300
	check(Market.rehomeValue(gift) == 0, "a gifted horse sells for 0")
	-- Lend: free, back any time, out of the racing roster, never deleted
	local p = Profile.new(T0)
	local starter = Horse.starter("h1", "Star", "bay", { NextInteger = function(_, lo, _hi) return lo end }, T0)
	Profile.addHorse(p, starter)
	local two = Horse.new("h2", "Two", "grey", S, P, T0)
	Profile.addHorse(p, two)
	check(Market.rehomeBlock(p, "h1", {}) ~= nil, "the starter never sells")
	local cash = p.cash
	local ok = Market.lend(p, "h2", T0, {})
	check(ok and two.lent == T0 and two.stall == nil and Profile.horse(p, "h2") ~= nil and p.cash == cash, "lent: free, no stall, still yours")
	check(Profile.racers(p) == 1 and #Profile.lent(p) == 1 and #Profile.pasture(p) == 0, "lent: out of the racing roster and the pasture")
	local okE, why = Leagues.canEnter(two, { league = "Rookie" }, 0)
	check(not okE and string.find(why or "", "Riding School", 1, true) ~= nil, "a lent horse can't race")
	check(not Market.lend(p, "h1", T0, {}), "your last racing horse stays")
	check(Market.lendBlock(p, "h2", {}) ~= nil, "a lent horse can't be lent twice")
	-- (B1) a lent horse never sells from the school: bring it home first (the card shows only 🏠 Home)
	local whySell = Market.rehomeBlock(p, "h2", {}, T0)
	check(whySell == "Bring Two home first!" and not Market.rehome(p, "h2", T0, {}) and Profile.horse(p, "h2") ~= nil,
		"a lent horse is refused a sale: Bring Comet home first!")
	local schoolSrc = fs.readFile("game/src/client/RehomeClient.client.luau")
	check(string.find(schoolSrc, "if not h.lent and not h.rehomeBlock then", 1, true) ~= nil, "Sell is never drawn over 🏠 Home")
	local ms = fs.readFile("game/src/server/MarketService.server.luau")
	check(string.find(ms, "typeof(lend) ~= \"boolean\"", 1, true) ~= nil and string.find(ms, "elseif lend == true then", 1, true) ~= nil,
		"LendHorse only lends on an explicit true")
	local loaded = Profile.migrate(p, T0 + 60)
	check(loaded.horses[2].lent == T0 and loaded.horses[2].stall == nil, "a load keeps it lent and stall-less")
	local okB = Market.takeBack(loaded, "h2")
	check(okB and two.lent == nil and two.stall ~= nil and Profile.racers(loaded) == 2, "back home: a stall and racing again")
	check(not Market.takeBack(loaded, "h2"), "home already")
	check(string.find(Market.lendBlock(p, "h2", { racing = true }) or "", "Lend after your race", 1, true) ~= nil, "never mid-race")
	-- no "Rehome" in UI text (remote names and instance names are code, not text)
	for _, path in { "game/src/client/RehomeClient.client.luau", "game/src/client/HorsesClient.client.luau", "game/src/shared/Market.luau",
		"game/src/shared/Leagues.luau", "game/src/server/MarketService.server.luau", "game/src/client/GrownUps.client.luau" } do
		for n, line in string.split(fs.readFile(path), "\n") do
			local code = string.match(line, "^(.-)%-%-") or line
			for str in string.gmatch(code, "\"([^\"]*)\"") do
				local isName = string.match(str, "^[%w_]+$") ~= nil -- a remote or instance name
				check(isName or string.find(string.lower(str), "rehom", 1, true) == nil, `{path}:{n}: "Rehome" in UI text: {str}`)
			end
		end
	end
	local school = fs.readFile("game/src/client/RehomeClient.client.luau")
	check(string.find(school, "\"🏫 Lend\"", 1, true) ~= nil and string.find(school, "\"💵 Sell\"", 1, true) ~= nil
		and string.find(school, "Sure? 💵", 1, true) ~= nil, "the Riding School card: Lend and Sell, two taps")
	local horses = fs.readFile("game/src/client/HorsesClient.client.luau")
	check(string.find(horses, "career.canBeLegend", 1, true) ~= nil, "the Legend button follows the server's career.veteranAt (350)")
end
