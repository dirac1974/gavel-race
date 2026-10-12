--!strict
-- Visible progress (fun-and-return phase 2, D-076): the class path, its next goal, the Cup bar as a
-- fill (never a number), the ceremony lines, and the wiring (horse card, results card, RaceService,
-- the class-up ceremony). No banned word anywhere in the path's words (hard rule 1).
local fs = require("@lune/fs")
local ClassPath = require("../../game/src/shared/ClassPath")
local Leagues = require("../../game/src/shared/Leagues")
local GameConfig = require("../../game/src/shared/GameConfig")
local Words = require("../../game/src/shared/Words")

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local function horse(league: string, wins: number, points: number): any
		return { league = league, points = points, leagueWins = { [league] = wins }, record = { wins = wins } }
	end
	-- the steps, in order
	check(table.concat(ClassPath.STEPS, ",") == "FirstWin,RisingStar,Open,Top,Cup", "path: First Win, Rising Star, Open, Top Horse, Cup")
	local rising, star = Leagues.RISING_STAR_BELOW, GameConfig.classes.topWins
	check(star > rising, "the Top Horse step comes after Open")
	local v0 = ClassPath.view(horse("Bronze", 0, 0), false)
	check(v0.at == 1 and v0.next == "Next: win a race!", "no wins: First Win, go for a win")
	local v1 = ClassPath.view(horse("Bronze", 1, 0), false)
	check(v1.at == 2 and v1.next == "🎽 Open: " .. (rising - 1) .. " more wins", "one win: Rising Star, Open next: " .. tostring(v1.next))
	local v3 = ClassPath.view(horse("Bronze", rising, 0), false)
	check(v3.at == 3 and v3.next == string.format("💐 Top Horse: %d more wins", star - rising), "Open: the next goal names Top Horse: " .. tostring(v3.next))
	local v4 = ClassPath.view(horse("Bronze", star - 1, 0), false)
	check(v4.next == "💐 Top Horse: 1 more win", "one more win (singular)")
	local v5 = ClassPath.view(horse("Bronze", star, 0), false)
	check(v5.at == 4 and v5.step == "Top" and v5.next == "Next: fill the 🏆 Cup bar", "Top Horse reached: fill the Cup bar")
	local vc = ClassPath.view(horse("Bronze", 0, 250), true)
	check(vc.at == 5 and vc.cupOpen and vc.next == "Win the Cup to move up!", "Cup open: the last step")
	-- the top league has no Cup
	local champ = ClassPath.view(horse("Champion", star + 3, 999), true)
	check(#champ.steps == 4 and champ.at == 4 and champ.cupFill == nil and not champ.cupOpen and champ.next == nil, "Champion: no Cup step, no bar")
	-- the Cup bar is a fill 0..1 of the league's Cup points
	local need = GameConfig.stakesUnlockPoints.Bronze -- policy-ok (the existing config key)
	check(close(ClassPath.view(horse("Bronze", 2, need / 2), false).cupFill, 0.5, 1e-9), "half the points: half the bar")
	check(ClassPath.cupFill("Bronze", need * 3) == 1 and ClassPath.cupFill("Bronze", -5) == 0, "the bar is clamped 0..1")
	check(ClassPath.cupFill("Champion", 10) == nil, "no bar in the top league")
	-- rises and ceremony lines: short, no banned word, no numbers of points
	check(ClassPath.rose(1, 2) and not ClassPath.rose(2, 2) and not ClassPath.rose(nil, 3), "a rise is a step up seen this session")
	for _, step in ClassPath.STEPS do
		local l = ClassPath.ceremonyLine("Comet", step)
		check(Words.toastOk(l, 6), "ceremony line short and kind: " .. l)
		check(Words.banned(ClassPath.label(step)) == nil, "step word allowed: " .. ClassPath.label(step))
	end
	for _, v in { v0, v1, v3, v4, v5, vc } do
		check(v.next == nil or (Words.count(v.next) <= 6 and Words.banned(v.next) == nil), "next goal at most 6 words: " .. tostring(v.next))
	end
	check(ClassPath.ceremonyLine("Comet", "Top") == "💐 Comet is a Top Horse!", "until named races: 💐 Comet is a Top Horse!")
	GameConfig.classes.starIsRace = true
	check(ClassPath.label("Top") == "💐 Big Race" and ClassPath.view(horse("Bronze", rising, 0), false).next == string.format("💐 Big Race: %d more wins", star - rising),
		"classes.starIsRace = true: the step is Big Race")
	GameConfig.classes.starIsRace = false
	for _, step in ClassPath.STEPS do
		check(step == "RisingStar" or string.find(ClassPath.label(step), "Star", 1, true) == nil, "no Star in the Top Horse step")
	end
	check(GameConfig.cupBar.enabled and GameConfig.cupBar.ticksMax <= 10 and GameConfig.classUp.seconds <= 4, "config: ticks <= 10, ceremony <= 4 s")
	-- wiring
	local horses = fs.readFile("game/src/client/HorsesClient.client.luau")
	check(string.find(horses, "progressRows(card, h)", 1, true) ~= nil and string.find(horses, "h.classPath", 1, true) ~= nil, "the horse card draws the path and Cup bar")
	local card = fs.readFile("game/src/client/ResultsCard.luau")
	check(string.find(card, "🏆 Cup +%d", 1, true) ~= nil and string.find(card, "function Card.setCup", 1, true) ~= nil, "the results card says 🏆 Cup +6 with a bar")
	check(string.find(card, "%f[%a]pts%f[%A]") == nil, "no \"pts\" on the results card (D-064)")
	local rc = fs.readFile("game/src/client/RaceController.client.luau")
	check(string.find(rc, "Card.setCup(mine)", 1, true) ~= nil, "RaceController fills the Cup row from your summary row")
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	check(string.find(rs, "row.cupFrom, row.cupTo", 1, true) ~= nil and string.find(rs, "hv.classPath = ClassPath.view", 1, true) ~= nil,
		"RaceService sends the path and the Cup bar")
	local cu = fs.readFile("game/src/client/ClassUp.client.luau")
	check(string.find(cu, "resultsOpen", 1, true) ~= nil and string.find(cu, "InLine", 1, true) ~= nil, "the ceremony never plays racing, in line or on the results card")
	check(string.find(cu, "math.min(4", 1, true) ~= nil and string.find(cu, "any tap skips", 1, true) ~= nil, "the ceremony is at most 4 s and skippable")
	check(string.find(cu, "PressRace", 1, true) == nil and string.find(cu, "againBtn", 1, true) == nil, "the ceremony never touches Race again")
end
