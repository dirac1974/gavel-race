--!strict
-- Stage 8 of docs/plans/horse-life-and-retention.md (D-062): class badges, first-win points, the
-- Rosette Wall and Stable Star goals. The first-win bonus comes once per horse per league; badges
-- follow the win count in the horse's own league; no goal needs a win or a place (no luck tasks,
-- D-043); what's on the wall stays there.
local Profile = require("../../game/src/shared/Profile")
local Horse = require("../../game/src/shared/Horse")
local Leagues = require("../../game/src/shared/Leagues")
local StableStar = require("../../game/src/shared/StableStar")
local PickerText = require("../../game/src/shared/PickerText")
local HorseBook = require("../../game/src/shared/HorseBook")
local Words = require("../../game/src/shared/Words")
local GameConfig = require("../../game/src/shared/GameConfig")

local DAY = 86400
local T0 = 20000 * DAY + 3600

local function horse(id: string, league: string?)
	local h = Horse.new(id, "Comet", "bay", { speed = 50, accel = 50, stamina = 50, grit = 50 },
		{ speed = 80, accel = 80, stamina = 80, grit = 80 }, T0)
	h.league = league or "Rookie"
	return Horse.repair(h, T0)
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Config ---------------------------------------------------------------------------------
	check(GameConfig.firstWinBonus == 10 and Leagues.FIRST_WIN_BONUS == 10, "firstWinBonus is 10")
	check(GameConfig.stakesUnlockPoints.Silver == 750, "Silver Cup at 750 points (sims/economy.py --silver)")
	check(GameConfig.stakesUnlockPoints.Rookie == 100 and GameConfig.stakesUnlockPoints.Bronze == 110
		and GameConfig.stakesUnlockPoints.Gold == 3000, "other D-013 thresholds unchanged")

	-- Badges by win count in the horse's own league -------------------------------------------
	do
		local h = horse("a")
		check(h.leagueWins == nil, "a new horse has no leagueWins until asked")
		check(Leagues.classOf(h, false) == "FirstWin", "a new horse is First Win")
		check(PickerText.classBadge(Leagues.classOf(h, false)) == "🐣 First Win", "First Win badge words")
		local pts = h.points
		check(Leagues.recordWin(h, "Rookie") == true, "first Rookie win is a first win")
		check(h.points == pts + 10, "first win adds 10 League Points")
		check(Leagues.classOf(h, false) == "RisingStar", "one win: Rising Star")
		check(Leagues.recordWin(h, "Rookie") == false and h.points == pts + 10, "second win: no bonus")
		check(Leagues.classOf(h, false) == "RisingStar", "two wins: still Rising Star")
		Leagues.recordWin(h, "Rookie")
		check(Leagues.classOf(h, false) == "Open", "three wins: Open class")
		check(Leagues.classOf(h, true) == "Cup", "Cup open shows Cup")
		for _, c in Leagues.CLASSES do
			local b = PickerText.classBadge(c)
			check(b ~= "" and Words.count(b) <= 3, "badge has icon + at most 3 words: " .. c)
			check(string.find(b, "★", 1, true) == nil, "badges never use ★ (riding only, D-064): " .. c)
		end
		check(PickerText.classBadge(nil) == "" and PickerText.classBadge("Nope") == "", "unknown class: no badge")

		-- promoted: First Win again in the new league, and a new first-win bonus there
		Leagues.promote(h)
		check(h.league == "Bronze" and h.points == 0, "promoted to Bronze with 0 points")
		check(Leagues.classOf(h, false) == "FirstWin", "First Win again in Bronze")
		check(Leagues.recordWin(h, "Bronze") == true and h.points == 10, "first Bronze win: +10 once")
		check(Leagues.recordWin(h, "Bronze") == false and h.points == 10, "no second Bronze bonus")
		check(h.leagueWins.Rookie == 3 and h.leagueWins.Bronze == 2, "wins kept per league")
		-- no demotion: nothing here ever moves a horse down
		check(Leagues.classOf(h, false) == "RisingStar" and h.league == "Bronze", "badges never demote")
	end

	-- Older saves: lower leagues were left by a Cup win; the own league starts at 0 ----------------
	do
		local h = horse("b", "Silver")
		h.record.wins = 12
		local w = Leagues.wins(h)
		check(w.Rookie == 1 and w.Bronze == 1 and (w.Silver or 0) == 0, "repair: lower leagues 1, own 0")
		check(Leagues.classOf(h, false) == "FirstWin", "an older Silver horse is First Win in Silver")
		check(Leagues.recordWin(h, "Rookie") == false, "no bonus for a league it already won in")
		-- an older Rookie horse: every recorded win was a Rookie win, so no second "first win"
		local r = horse("r", "Rookie")
		r.record.wins = 2
		check(Leagues.wins(r).Rookie == 2 and Leagues.classOf(r, false) == "RisingStar", "repair: a Rookie keeps its wins")
		local rp = r.points
		check(Leagues.recordWin(r, "Rookie") == false and r.points == rp, "no bonus for an older Rookie winner")
		local r0 = horse("r0", "Rookie")
		check(Leagues.wins(r0).Rookie == 0 and Leagues.classOf(r0, false) == "FirstWin", "repair: a Rookie with no wins is First Win")
		h.leagueWins = { Rookie = "2", Moon = 5, Bronze = -3, Silver = 0 / 0 }
		local c = Leagues.wins(h)
		check(c.Rookie == 2 and c.Moon == nil and c.Bronze == 0 and c.Silver == nil, "junk leagueWins cleaned")
	end

	-- Stable Star goals: never a win, a place, a Cup or a promotion (no luck tasks) ------------------
	do
		local luck = { race = true, win = true, place = true, promote = true, cup = true, cheer = true }
		local ids, kinds = {}, {}
		for _, g in StableStar.GOALS do
			check(not ids[g.id], "goal ids unique: " .. g.id)
			ids[g.id] = true
			kinds[g.kind] = (kinds[g.kind] or 0) + 1
			check((g.event ~= nil) ~= (g.book ~= nil), "a goal counts an event or a book page: " .. g.id)
			check(not (g.event and luck[g.event]), "no goal counts a race result: " .. g.id)
			check(g.book ~= "places" and g.book ~= "cups", "no goal needs a place or a Cup: " .. g.id)
			check(g.target >= 1 and #g.id <= 32, "goal target and id: " .. g.id)
			check(Words.count(g.text) <= 8 and Words.banned(g.text) == nil, "goal text short and clean: " .. g.text)
			if g.book then check(HorseBook.KNOWN[g.book] ~= nil, "book goal reads a real page: " .. g.id) end
		end
		check((kinds.care or 0) >= 3 and (kinds.collection or 0) >= 3 and (kinds.skill or 0) >= 3, "care, collection and skill goals")
	end

	-- Counting, finishing, the cards and the wall ------------------------------------------------
	do
		local p = Profile.new(T0)
		check(#StableStar.cards(p) == 3, "three goal cards: one per kind")
		check(#StableStar.wall(p) == 0, "an empty wall to start")
		local before = StableStar.cards(p)[1]
		check(before.id == "care_groom10" and before.progress == 0 and before.target == 10, "first care goal 0/10")
		local done = StableStar.record(p, "groom", 9)
		check(#done == 0 and StableStar.cards(p)[1].progress == 9, "9/10: not done")
		done = StableStar.record(p, "groom", 1)
		check(#done == 1 and done[1].id == "care_groom10", "10/10: done, once")
		check(#StableStar.record(p, "groom", 1) == 0, "never finishes twice")
		check(StableStar.cards(p)[1].id == "care_feed15", "the care card moves to the next goal")
		local wall = StableStar.wall(p)
		check(#wall == 1 and wall[1].kind == "goal" and wall[1].hex == StableStar.KIND_HEX.care, "a care rosette on the wall")
		check(#StableStar.record(p, "nonsense", 5) == 0 and p.stableStar.counts.nonsense == nil, "unknown events ignored")
		check(#StableStar.record(p, "groom", -4) == 0 and p.stableStar.counts.groom == 11, "negative counts ignored")

		-- a collection goal from the Horse Book (coats)
		HorseBook.record(p, "coats", "bay")
		HorseBook.record(p, "coats", "grey")
		done = StableStar.check(p)
		check(#done == 1 and done[1].id == "col_coats2", "two coats in the Horse Book: collection goal done")

		-- first wins: league colour rosettes, once per league per stable
		check(StableStar.firstWin(p, "Rookie") == true and StableStar.firstWin(p, "Rookie") == false, "first Rookie win rosette once")
		check(StableStar.firstWin(p, "Moon") == false, "unknown league: nothing")
		local firsts = 0
		for _, it in StableStar.wall(p) do
			if it.kind == "first" then
				firsts += 1
				check(it.hex == StableStar.LEAGUE_HEX.Rookie, "first-win rosette in the league's colour")
			end
		end
		check(firsts == 1, "one first-win rosette")

		-- Cups and plaques; the wall order is Cups, plaques, firsts, goals
		HorseBook.record(p, "cups", "Rookie")
		p.hallOfFame = { { name = "Old Blaze", league = "Gold" } }
		local w2 = StableStar.wall(p)
		check(w2[1].kind == "cup" and w2[1].hex == StableStar.LEAGUE_HEX.Rookie, "Cup first, on its league colour")
		check(w2[2].kind == "plaque" and w2[2].label == "Old Blaze", "then the Legend plaque")
		check(w2[3].kind == "first" and w2[4].kind == "goal", "then first wins, then goal rosettes")
		local key = StableStar.wallKey(p)
		check(#key > 0 and key == StableStar.wallKey(p), "wall key is stable")

		-- what's earned stays: losing every horse keeps the wall
		p.horses = {}
		check(#StableStar.wall(p) == #w2, "the wall stays when horses leave")
		local v = StableStar.view(p)
		check(v.wall == #w2 and v.done == 2 and v.total == #StableStar.GOALS and #v.cards == 3, "view")

		-- the wall caps at MAX_WALL items
		for _, g in StableStar.GOALS do p.stableStar.done[g.id] = true end
		for _, lg in StableStar.LEAGUES do StableStar.firstWin(p, lg) end
		for _, lg in StableStar.LEAGUES do HorseBook.record(p, "cups", lg) end
		p.hallOfFame = { { name = "A" }, { name = "B" }, { name = "C" }, { name = "D" }, { name = "E" } }
		local full = StableStar.wall(p)
		-- everything that can qualify fits: 4 Cups + 4 plaques + 5 first wins + every goal
		check(#full == 4 + StableStar.MAX_PLAQUES + 5 + #StableStar.GOALS and #full <= StableStar.MAX_WALL,
			"every rosette fits on the wall (" .. #full .. ")")
		check(#StableStar.cards(p) == 0, "every goal done: no cards")
	end

	-- Repair: junk shapes become clean, unknown goal ids from a newer build pass through ------------
	do
		local p = Profile.new(T0)
		p.stableStar = { counts = { groom = "7", spa = 0 / 0, bogus = 3 }, done = { care_groom10 = true, future_goal = true, [5] = true },
			firsts = { Rookie = true, Moon = true } }
		StableStar.repair(p)
		local s = p.stableStar
		check(s.counts.groom == 7 and s.counts.spa == nil and s.counts.bogus == nil, "counts repaired")
		check(s.done.care_groom10 and s.done.future_goal and s.done[5] == nil, "done ids kept if sane")
		check(s.firsts.Rookie and s.firsts.Moon == nil, "firsts repaired")
		p.stableStar = "junk"
		check(#StableStar.cards(p) == 3, "a junk value repairs to empty")
	end

	-- League colours match the race cards (Ui.leagueColors, D-064) -----------------------------------
	do
		local fs = require("@lune/fs")
		local ui = fs.readFile("game/src/client/Ui.luau")
		for lg, hex in StableStar.LEAGUE_HEX do
			check(string.find(ui, lg .. ' = Color3.fromHex("' .. hex .. '")', 1, true) ~= nil, "league colour matches Ui: " .. lg)
		end
	end
end
