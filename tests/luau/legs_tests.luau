--!strict
-- Legs and the vet (fun-and-return phase 3, D-077): Legs.luau matches src/life_arc.py's vet run
-- (tests/test_life_arc.py test_vet_run, the same cases), the record rules (care once per kind per
-- cooldown, rest, Spa, training and the Cool-down Check reset it, wraps for 3 races), the server turns
-- rated joins away, RACE! becomes VET CHECK, GameConfig.legs mirrors Python, and a lint: no hurt word
-- (hurt, sore, injury, limp, sick) in any string in game code.
local fs = require("@lune/fs")
local Legs = require("../../game/src/shared/Legs")
local Horse = require("../../game/src/shared/Horse")
local Profile = require("../../game/src/shared/Profile")
local Care = require("../../game/src/shared/Care")
local Spa = require("../../game/src/shared/Spa")
local Training = require("../../game/src/shared/Training")
local Advice = require("../../game/src/shared/Advice")
local ResultsText = require("../../game/src/shared/ResultsText")
local GameConfig = require("../../game/src/shared/GameConfig")
local Words = require("../../game/src/shared/Words")

local T0 = 1_760_000_000
local HURT = { "hurt", "hurts", "hurting", "sore", "injury", "injured", "injuries", "limp", "limping", "limps", "sick", "sickness" }

local function luauFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
	return out
end

-- String literals on one line, outside comments.
local function lineStrings(line: string): { string }
	local out = {}
	local i = 1
	while i <= #line do
		local c = string.sub(line, i, i)
		if c == "-" and string.sub(line, i, i + 1) == "--" then break end
		if c == '"' or c == "'" or c == "`" then
			local j = i + 1
			local buf = {}
			while j <= #line do
				local d = string.sub(line, j, j)
				if d == "\\" then
					table.insert(buf, string.sub(line, j + 1, j + 1))
					j += 2
				elseif d == c then
					break
				else
					table.insert(buf, d)
					j += 1
				end
			end
			table.insert(out, table.concat(buf))
			i = j + 1
		else
			i += 1
		end
	end
	return out
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	local L = GameConfig.legs
	-- config mirrors src/life_arc.py LEGS (tests/test_life_arc.py checks the numbers too)
	check(L.runLimit == 6 and L.warnAt == 5 and L.careLowers == 2 and L.fromRaces == 26 and L.restSeconds == 1800, "legs config: 6 / 5 / -2 / from 26 / 30 min")
	check(L.careCooldownSeconds == GameConfig.energy.careCooldownSeconds, "care counts once per kind per energy.careCooldownSeconds")
	check(L.wrapRaces == 3, "wraps for the next 3 races")
	-- parity with life_arc.py test_vet_run
	local run = 0
	for races = 1, 26 do run = Legs.runAfterRace(run, races) end
	check(run == 0, "never in a horse's first 26 races")
	for races = 27, 32 do
		check(not Legs.needsVetRun(run), "no vet before 6 in a row: " .. run)
		run = Legs.runAfterRace(run, races)
	end
	check(run == 6 and Legs.needsVetRun(run) and not Legs.warningRun(run), "6 in a row: vet check")
	check(Legs.warningRun(5) and not Legs.warningRun(4), "the chip at 5")
	local cool = L.careCooldownSeconds
	local r1, c1 = Legs.runAfterCare(5, -1e9, 0)
	local r2, c2 = Legs.runAfterCare(1, -1e9, 0)
	check(r1 == 3 and c1 and r2 == 0 and c2, "care: -2, never below 0")
	local r3, c3 = Legs.runAfterCare(5, 0, cool - 1)
	local r4, c4 = Legs.runAfterCare(5, 0, cool)
	check(r3 == 5 and not c3 and r4 == 3 and c4, "once per kind per cooldown")
	check(Legs.runNow(5, 0, 1799) == 5 and Legs.runNow(5, 0, 1800) == 0, "30 minutes' rest clears it")

	-- on a horse record
	local E = GameConfig.energy
	local h = Horse.new("h2", "Comet", "bay", { speed = 50, accel = 50, stamina = 50, grit = 50 },
		{ speed = 80, accel = 80, stamina = 80, grit = 80 }, T0)
	h.record.races = 40
	check(Legs.view(h, T0).run == 0 and not Legs.needsVet(h, T0), "a new record: fresh legs")
	local t = T0
	for _ = 1, 5 do
		t += 120
		h.record.races += 1
		Legs.afterRace(h, t)
	end
	check(Legs.warning(h, t) and Legs.view(h, t).chip == Legs.CHIP_WARN, "5 in a row: 🧣 Worked hard! Cool-down soon")
	t += 120
	h.record.races += 1
	Legs.afterRace(h, t)
	check(Legs.needsVet(h, t) and Legs.view(h, t).chip == Legs.CHIP_VET, "6 in a row: needs the vet")
	check(not Legs.needsVet(h, t + L.restSeconds), "30 minutes without racing that horse: fresh again")
	-- feed and groom: -2 each, once per kind per cooldown (no spamming past the vet)
	local p = Profile.new(T0)
	p.items.hay = 10
	local hh = Horse.new("h3", "Biscuit", "grey", { speed = 50, accel = 50, stamina = 50, grit = 50 },
		{ speed = 80, accel = 80, stamina = 80, grit = 80 }, T0)
	Legs.ensure(hh).run, hh.legs.raceAt = 6, t
	Care.feed(p, hh, "hay", t, E)
	check(hh.legs.run == 4, "a meal: -2")
	Care.groom(p, hh, t + 1, E)
	check(hh.legs.run == 2, "a brushing: -2")
	check(not Legs.care(hh, "groom", t + 2) and hh.legs.run == 2, "a second brushing inside the cooldown doesn't count")
	-- the Spa, training and the Cool-down Check reset it
	hh.legs.run = 6
	Spa.give(hh, t + 5, E, GameConfig.spa)
	check(hh.legs.run == 0, "a Spa Day: fresh legs")
	hh.legs.run = 6
	local okT = Training.train(hh, "speed", 80, t + 6)
	check(okT and hh.legs.run == 0, "a training session: fresh legs")
	hh.legs.run = 6
	Legs.vetDone(hh, GameConfig.vetCheck.wraps[2])
	check(hh.legs.run == 0 and hh.legs.wraps == 3 and hh.legs.wrap == GameConfig.vetCheck.wraps[2], "the Cool-down Check: fresh, wraps in the colour picked")
	Legs.vetDone(hh, "000000")
	check(hh.legs.wrap == GameConfig.vetCheck.wraps[1], "an unknown colour from a client gets the first wrap colour")
	check(Legs.takeWrap(hh) and Legs.takeWrap(hh) and Legs.takeWrap(hh) and Legs.takeWrap(hh) == nil and Legs.wrapNow(hh) == nil,
		"wraps show for 3 races, then come off")
	-- old saves default safely; junk is cleaned
	local old = Profile.migrate({ horses = { { id = "h1", name = "Old" } } }, T0)
	check(old.horses[1].legs.run == 0 and old.horses[1].legs.wraps == 0, "an old save: fresh legs")
	local junk = Profile.migrate({ horses = { { id = "h1", name = "J", legs = { run = 0 / 0, wraps = "x", wrap = string.rep("a", 40) } } } }, T0)
	check(junk.horses[1].legs.run == 0 and junk.horses[1].legs.wrap == nil, "junk legs repaired")
	-- the view the client reads, and the switch
	local view = Profile.view(old, T0, E)
	check(view.horses[1].legs and view.horses[1].legs.enabled and view.horses[1].legs.limit == 6, "the owner's view carries the Legs row")
	L.enabled = false
	check(not Legs.needsVet(h, t) and not Legs.warning(h, t), "legs.enabled = false: no run, no VET CHECK")
	L.enabled = true

	-- client words: RACE! and Race again say Vet check; Advice goes to the Cool-down Check
	local hv = { id = "h2", name = "Comet", legs = { needsVet = true }, fed = true, groomed = true }
	check(ResultsText.nextKind(hv, E) == "vet" and ResultsText.raceAgainLabel("vet") == "🩺 Vet check", "Race again: 🩺 Vet check")
	local tip = Advice.forHorse(hv, {}, T0)
	check(tip.go == "vetCheck" and Words.banned(tip.fact) == nil, "Advice: GO to the vet check")
	local nxt = Advice.nextThing({ horses = { hv }, activeHorse = "h2", totals = { races = 50 } }, T0)
	check(nxt.go == "vetCheck" and nxt.emoji == "🩺", "the Next-thing pill: Vet check for Comet")
	for _, l in { Legs.CHIP_WARN, Legs.CHIP_VET, Legs.CHIP_FRESH, Legs.RACE_WORD, Legs.REJECT, Legs.vetLine("Comet"), Legs.freshLine("Comet") } do
		check(Words.count(l) <= 6 and Words.banned(l) == nil, "vet copy short and kind: " .. l)
	end
	for _, step in Legs.STEPS do
		local st = Legs.STEP_TEXT[step]
		check(Words.count(st.title) <= 6 and Words.count(st.tap) <= 6, "step copy short: " .. step)
	end

	-- wiring: the server turns rated joins away; Practice stays open; VET CHECK on RACE!
	local rs = fs.readFile("game/src/server/RaceService.server.luau")
	check(string.find(rs, "not card.practice and Legs.needsVet(h, os.time())", 1, true) ~= nil, "rated joins wait for the vet; Practice stays open")
	check(string.find(rs, "why == Legs.REJECT", 1, true) ~= nil, "a rated join is turned away (not quietly turned into Practice)")
	check(string.find(rs, "Legs.afterRace(hp, os.time())", 1, true) ~= nil, "the run grows after counted races only")
	local hud = fs.readFile("game/src/client/Hud.client.luau")
	check(string.find(hud, "vet = \"🩺 VET CHECK\"", 1, true) ~= nil and string.find(hud, "GoTo\")).place(\"vetCheck\")", 1, true) ~= nil,
		"RACE! becomes 🩺 VET CHECK and GOes to the vet")
	local ts = fs.readFile("game/src/server/TrainingService.server.luau")
	check(string.find(ts, "VetCheckDone", 1, true) ~= nil and string.find(ts, "minSeconds - cfg.lagAllowance", 1, true) ~= nil, "the server times the Cool-down Check")
	local pc = fs.readFile("game/src/client/PaddockClient.client.luau")
	check(string.find(pc, "GoTo.register(\"coolDown\"", 1, true) ~= nil, "GO opens the Cool-down Check")
	-- no Diamonds, no Green Cash, no purchase prompt anywhere in the vet work
	for _, path in { "game/src/shared/Legs.luau", "game/src/shared/HorseLook.luau" } do
		local src = fs.readFile(path)
		check(string.find(src, "PromptProductPurchase", 1, true) == nil and string.find(src, "diamonds", 1, true) == nil
			and string.find(src, "spendCash", 1, true) == nil, "no purchase or Diamonds in " .. path)
	end
	local cool00 = string.find(pc, "local function coolDownGame", 1, true)
	local cool01 = if cool00 then string.find(pc, "local function coolDownPick", cool00, true) else nil
	local cool0 = if cool00 and cool01 then string.sub(pc, cool00, cool01) else ""
	check(#cool0 > 0 and string.find(cool0, "Prompt", 1, true) == nil and string.find(cool0, "💎", 1, true) == nil and string.find(cool0, "💵", 1, true) == nil,
		"the Cool-down Check is free: no price, no Diamonds")

	-- the lint: no hurt word in any string in game code (Words.luau lists them on purpose)
	local hurt = {}
	for _, w in HURT do hurt[w] = true end
	local scanned = 0
	for _, path in luauFiles("game/src", {}) do
		if not string.find(path, "Words.luau", 1, true) then
			for n, line in string.split(fs.readFile(path), "\n") do
				for _, str in lineStrings(line) do
					scanned += 1
					for word in string.gmatch(string.lower(str), "%a+") do
						check(not hurt[word], `{path}:{n}: "{word}" in game text`)
					end
				end
			end
		end
	end
	check(scanned > 1000, "the hurt-word lint read the game's strings: " .. scanned)
	for _, w in { "hurt", "sore", "injury", "limp", "sick" } do
		check(table.find(Words.BANNED, w) ~= nil, "Words.BANNED has " .. w .. " (the toast test)")
	end
end
