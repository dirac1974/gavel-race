--!strict
-- Stage 4 of docs/plans/horse-life-and-retention.md (D-058): rest cues and the Spa Day. Tired is
-- happy-tired (yawn at 1 Energy, nap at 0); the Spa gives +1 Energy once per horse per server day,
-- never above the cap, and never bond, Rating or win chance; no game text says hurt or sore.
local fs = require("@lune/fs")
local Horse = require("../../game/src/shared/Horse")
local Spa = require("../../game/src/shared/Spa")
local Advice = require("../../game/src/shared/Advice")
local Jobs = require("../../game/src/shared/Jobs")
local RaceRating = require("../../game/src/shared/RaceRating")
local GameConfig = require("../../game/src/shared/GameConfig")
local WorldLayout = require("../../game/src/shared/WorldLayout")

local E = GameConfig.energy
local DAY = 86400
local T0 = 20000 * DAY + 3600 -- 01:00 UTC on a day

local function horse(energy: number, now: number)
	local h = Horse.new("h1", "Comet", "bay", { speed = 55, accel = 50, stamina = 60, grit = 45 },
		{ speed = 80, accel = 75, stamina = 78, grit = 70 }, now)
	h.energy, h.energyAt = energy, now
	h.bond = 37
	h.league = "Bronze"
	return Horse.repair(h, now)
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

local BANNED = { "hurt", "sore", "injur", "limp", "sick" }
local function banned(s: string): string?
	local low = string.lower(s)
	for _, w in BANNED do
		if string.find(low, "%f[%a]" .. w) then return w end
	end
	return nil
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Config ---------------------------------------------------------------------------
	local S = GameConfig.spa
	check(S ~= nil and S.enabled == true and S.perDay == 1 and S.energy == 1, "spa config: on, once a day, +1 Energy")
	check(S.muddyLook == false, "the muddy look stays off (D-058 minority view)")
	check(S.minSeconds > 0 and S.minSeconds < 30, "a Spa takes a few seconds, under a minute")
	check(S.lagAllowance >= 0 and S.lagAllowance < S.minSeconds, "the lag allowance leaves a real wait")
	-- the client's three steps can't finish before the server would take them: at 8 taps a second
	local taps = 0
	for _, step in Spa.STEPS do taps += S.taps[step] end
	check(taps >= 9 and taps / 8 < 30, "the Spa's taps fit in under 30 s")
	check(E.yawnAt == 1 and E.restingLabelAt == 0, "yawn at 1 Energy, nap at 0")

	-- +1 Energy once per horse per day ---------------------------------------------------
	do
		local h = horse(2, T0)
		local ok, msg, gained = Spa.give(h, T0, E, S)
		check(ok and gained == 1 and h.energy == 3, "a Spa Day gives +1 Energy")
		check(string.find(msg, "Comet", 1, true) ~= nil and string.find(msg, "+1 Energy", 1, true) ~= nil, "the toast names the horse and the Energy")
		check(Spa.usedToday(h, T0) == 1 and not Spa.open(h, T0, S), "the Spa is used for today")
		local ok2, msg2, g2 = Spa.give(h, T0 + 3600, E, S)
		check(not ok2 and g2 == 0 and h.energy == 3, "a second Spa the same day is refused")
		check(msg2 == "Spa opens again tomorrow" and msg2 == Spa.CLOSED, "it says the Spa opens again tomorrow")
		check(string.find(msg2, "%d") == nil, "no countdown or clock in the closed message")
		check(h.spaDays == 1, "one Spa Day counted")
		-- just before midnight UTC still today; just after is a new day
		local lastSecond = (T0 // DAY + 1) * DAY - 1
		check(not Spa.open(h, lastSecond, S), "closed until the server day turns")
		local tomorrow = lastSecond + 1
		local ok3 = Spa.give(h, tomorrow, E, S)
		check(ok3 and h.spaDays == 2, "the Spa opens again the next server day")
		-- another horse has its own Spa
		local other = horse(1, T0)
		other.id = "h2"
		check(Spa.open(other, T0, S) and (Spa.give(other, T0, E, S)), "each horse has its own Spa Day")
	end

	-- Never above the cap ------------------------------------------------------------------
	do
		local h = horse(E.maxPerRacer, T0)
		local ok, msg, gained = Spa.give(h, T0, E, S)
		check(ok and gained == 0 and h.energy == E.maxPerRacer, "a full horse stays at the cap")
		check(string.find(msg, "full of Energy", 1, true) ~= nil, "a full horse is 'full of Energy'")
		local h4 = horse(E.maxPerRacer - 1, T0)
		Spa.give(h4, T0, E, S)
		check(h4.energy == E.maxPerRacer, "4 + 1 = the cap, no more")
		-- partway to the next regen point: the Spa adds a whole point, still never above the cap
		local h0 = horse(0, T0)
		h0.energyAt = T0 - E.regenSeconds / 2
		Spa.give(h0, T0, E, S)
		check(h0.energy == 1 and h0.energy <= E.maxPerRacer, "+1 from 0 while regenerating")
		-- perDay = 2 (a config flip) allows two, then closes
		local cfg2 = table.clone(S)
		cfg2.perDay = 2
		local h2 = horse(0, T0)
		Spa.give(h2, T0, E, cfg2)
		local okB = Spa.give(h2, T0, E, cfg2)
		local okC = Spa.give(h2, T0, E, cfg2)
		check(okB and not okC and h2.energy == 2, "perDay is honoured")
		local off = table.clone(S)
		off.enabled = false
		local hOff = horse(1, T0)
		check(not (Spa.give(hOff, T0, E, off)) and hOff.energy == 1, "a switched-off Spa gives nothing")
	end

	-- No bond, no Rating, no win chance -------------------------------------------------------
	do
		local h = horse(1, T0)
		h.care = { day = T0 // DAY, fed = true, groomed = false, feedAt = T0, groomAt = 0 }
		local cond = { distance = "Mile", surface = "Dirt", weather = "Sunny" }
		local r0 = Horse.rating(h, cond, T0, RaceRating)
		local bond0, stats0, pot0 = h.bond, table.clone(h.stats), table.clone(h.potential)
		local league0, points0 = h.league, h.points
		local care0 = Horse.care(h, T0)
		Spa.give(h, T0, E, S)
		check(Horse.rating(h, cond, T0, RaceRating) == r0, "Race Rating unchanged by a Spa Day")
		check(h.bond == bond0, "bond unchanged by a Spa Day")
		check(Horse.care(h, T0) == care0 and h.care.groomed == false, "care unchanged (the Spa isn't grooming)")
		local same = true
		for k, v in stats0 do if h.stats[k] ~= v or h.potential[k] ~= pot0[k] then same = false end end
		check(same and h.league == league0 and h.points == points0, "stats, Potential, league and points unchanged")
		check(h.stamps.spa == true, "the Spa Day stamp is in the Health Passport")
		check(h.shine == true, "the shine waits for the next race")
		check(Spa.takeShine(h) == true and h.shine == false, "the shine lasts one race")
		check(Spa.takeShine(h) == false, "and then it's gone")
		-- the Spa stamp is not one the check-up hands out in turn
		local Training = require("../../game/src/shared/Training")
		check(table.find(Training.STAMPS, Spa.STAMP) == nil, "the check-up's stamp order is unchanged")
	end

	-- Rest cues ------------------------------------------------------------------------------
	do
		check(Spa.restPose(0, E) == "nap", "0 Energy: napping in the straw")
		check(Spa.restPose(1, E) == "yawn", "1 Energy: a yawn")
		for e = 2, E.maxPerRacer do check(Spa.restPose(e, E) == nil, e .. " Energy: bright-eyed") end
		local v0 = Horse.view(horse(0, T0), T0, E)
		local v1 = Horse.view(horse(1, T0), T0, E)
		local v3 = Horse.view(horse(3, T0), T0, E)
		check(v0.resting and not v0.yawning and not v0.ready, "the view: napping at 0")
		check(v1.yawning and not v1.resting and v1.ready, "the view: yawning at 1, still Ready")
		check(not v3.yawning and not v3.resting, "the view: neither at 3")
		local hs = horse(1, T0)
		Spa.give(hs, T0, E, S)
		local vs = Horse.view(hs, T0, E)
		check(vs.spaToday == 1 and vs.spaDays == 1 and vs.shine == true, "the view carries today's Spa, the count and the shine")
		check(Horse.view(hs, T0 + DAY, E).spaToday == 0, "spaToday is 0 the next day")
		-- an old save with no Spa fields loads and can have a Spa
		local old = horse(2, T0) :: any
		old.spa, old.spaDays, old.shine = nil, nil, nil
		Horse.repair(old, T0)
		check(old.spa.day == -1 and old.spaDays == 0 and old.shine == false, "repair adds the Spa fields")
		check(Spa.open(old, T0, S), "an old save's horse can have a Spa Day")
		-- every horse napping
		local a, b = horse(0, T0), horse(0, T0)
		check(Spa.allNapping({ a, b }, T0, E), "every horse napping")
		check(not Spa.allNapping({ a, horse(1, T0) }, T0, E), "not every horse napping")
		check(not Spa.allNapping({}, T0, E), "no horses: not napping")
		check(not Spa.allNapping({ a }, T0 + E.regenSeconds, E), "a nap ends as Energy comes back")
		check(Spa.dreamLine("Comet") == "Great day! Comet's dreaming of tomorrow.", "the dream line")
		check(Spa.YAWN == "🥱 Yawn!" and Spa.NAP == "💤 Napping", "one word each for yawning and napping")
	end

	-- Stable Board job and the next step --------------------------------------------------------
	do
		local def = Jobs.def("d_spa")
		check(def ~= nil and def.event == "spa" and def.text == "Give a horse a Spa Day" and def.go == "vet", "the Spa Day job")
		check(def ~= nil and def.reward.cash ~= nil and def.reward.cash <= 4, "a small reward like the check-up's")
		local napper = Horse.view(horse(0, T0), T0, E)
		napper.fed, napper.groomed = true, true
		local tip = Advice.forHorse(napper, { garden = {} }, T0)
		check(tip.go == "vet" and string.find(tip.next, "Spa Day", 1, true) ~= nil, "a napping horse is pointed at the Spa")
		local spaed = horse(0, T0)
		spaed.spa = { day = T0 // DAY, count = 1 }
		local sv = Horse.view(spaed, T0, E)
		sv.fed, sv.groomed = true, true
		check(Advice.forHorse(sv, { garden = {} }, T0).go ~= "vet", "once it's had its Spa, no Spa suggestion")
		local awake = Horse.view(horse(3, T0), T0, E)
		awake.fed, awake.groomed = true, true
		check(Advice.forHorse(awake, { garden = {} }, T0).go ~= "vet", "an awake horse is not sent to the Spa")
	end

	-- Where the wash bay is ------------------------------------------------------------------
	do
		local x, z = WorldLayout.placePoint("vet", WorldLayout.SPA.across, WorldLayout.SPA.out)
		local r = WorldLayout.placeRect("vet") :: { number }
		-- TrainingService takes a Spa within 30 studs of the Vet's rectangle: keep 8 to spare
		check(x >= r[1] - 22 and x <= r[3] + 22 and z >= r[2] - 22 and z <= r[4] + 22, "the wash bay is well within the Vet's reach")
		local sr = WorldLayout.spaRect()
		check(x > sr[1] and x < sr[3] and z > sr[2] and z < sr[4], "the wash bay is in the tree-free rectangle")
		check(x < r[1] - 6 or x > r[3] + 6, "the wash bay stands beside the Vet, not in it")
		local px, pz = WorldLayout.placePoint("vet", 0, 0)
		check(px == WorldLayout.places.vet.x and pz == WorldLayout.places.vet.z, "placePoint(0, 0) is the place's front centre")
	end

	-- Copy: nothing a kid reads says hurt, sore, injury, limp or sick ------------------------------
	do
		local bad = {}
		for _, s in Spa.copy() do
			if banned(s) then table.insert(bad, s) end
		end
		local function scan(dir: string)
			for _, name in fs.readDir(dir) do
				local path = dir .. "/" .. name
				if fs.isDir(path) then
					scan(path)
				elseif string.sub(name, -5) == ".luau" and name ~= "GrownUps.client.luau" then -- (the parents' page says horses never get sick)
					for _, lit in literals(fs.readFile(path)) do
						local w = banned(lit)
						if w then table.insert(bad, name .. ": " .. lit) end
					end
				end
			end
		end
		scan("game/src")
		check(#bad == 0, "no hurt/sore/injury/limp/sick in game text: " .. table.concat(bad, " | "))
		check(banned("Comet is sore") == "sore" and banned("an injured horse") == "injur" and banned("sorely") == "sore",
			"the copy check catches the words")
		check(banned("Comet is soaring") == nil and banned("Tap to rinse") == nil, "and leaves other words alone")
		local lits = literals("local a = \"one\" -- \"two\"\nlocal b = 'three'")
		check(#lits == 2 and lits[1] == "one" and lits[2] == "three", "the literal scanner skips comments")
	end
end
