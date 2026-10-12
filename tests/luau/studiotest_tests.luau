--!strict
-- Studio test block (playtest 2026-10-12): GameConfig.studioTest is all off by default, the Profiles hook
-- is gated on RunService:IsStudio() (a source check), StudioTest.apply does nothing outside Studio, and
-- in Studio it writes the real save fields (races, wins, leagueWins, stats, legs run, points).
local fs = require("@lune/fs")
local GameConfig = require("../../game/src/shared/GameConfig")
local StudioTest = require("../../game/src/shared/StudioTest")
local Ageing = require("../../game/src/shared/Ageing")
local Legs = require("../../game/src/shared/Legs")
local ClassPath = require("../../game/src/shared/ClassPath")

local T0 = 1_760_000_000

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	local st = GameConfig.studioTest
	check(typeof(st) == "table", "GameConfig.studioTest exists")
	check(st.horseRaces == 0 and st.horseWins == 0 and st.nearPotential == false and st.legsRun == 0
		and st.leaguePoints == 0 and st.legsFromRaces == false, "studioTest defaults are all off (0 / false)")
	check(not StudioTest.active(st), "the default block is inactive")
	for _, k in StudioTest.KEYS do check(st[k] ~= nil, "studioTest has " .. k) end

	-- source check: the hook in Profiles only runs under RunService:IsStudio()
	local src = fs.readFile("game/src/server/Profiles.luau")
	local at = string.find(src, "StudioTest.apply", 1, true)
	check(at ~= nil, "Profiles calls StudioTest.apply")
	local gate = string.find(src, "if RunService:IsStudio() then", 1, true)
	check(gate ~= nil and at ~= nil and gate < at and at - gate < 200, "StudioTest.apply sits inside an IsStudio() check")
	check(at ~= nil and string.find(string.sub(src, at, at + 120), "RunService:IsStudio()", 1, true) ~= nil,
		"StudioTest.apply is passed RunService:IsStudio()")
	local n = 0
	for _ in string.gmatch(src, "StudioTest%.apply") do n += 1 end
	check(n == 1, "StudioTest.apply is called once: " .. n)
	for _, path in { "game/src/server", "game/src/client" } do
		for _, name in fs.readDir(path) do
			if name ~= "Profiles.luau" then
				check(string.find(fs.readFile(path .. "/" .. name), "StudioTest", 1, true) == nil, "only Profiles uses StudioTest: " .. name)
			end
		end
	end

	local function horse(): any
		return {
			id = "h1", name = "Pip", league = "Rookie", points = 0, legend = nil,
			stats = { speed = 45, accel = 45, stamina = 45, grit = 45 },
			potential = { speed = 80, accel = 70, stamina = 90, grit = 60 },
			record = { races = 3, wins = 0, places = 0, cash = 0, cups = 0 },
		}
	end
	local function pick(d: any): any return d.h end
	local on = { horseRaces = 400, horseWins = 5, nearPotential = true, legsRun = 5, leaguePoints = 90, legsFromRaces = 0 }
	local savedFrom = GameConfig.legs.fromRaces

	-- outside Studio nothing changes, even with every switch on
	local d0 = { h = horse() }
	check(#StudioTest.apply(d0, T0, false, pick, on) == 0, "not in Studio: no lines")
	check(d0.h.record.races == 3 and d0.h.points == 0 and d0.h.stats.speed == 45 and d0.h.legs == nil, "not in Studio: the save is untouched")
	check(GameConfig.legs.fromRaces == savedFrom, "not in Studio: legs.fromRaces untouched")
	local dOff = { h = horse() }
	check(#StudioTest.apply(dOff, T0, true, pick, st) == 0 and dOff.h.record.races == 3, "in Studio with the defaults: nothing changes")

	-- in Studio: the real fields
	local d = { h = horse() }
	local lines = StudioTest.apply(d, T0, true, pick, on)
	local h = d.h
	check(#lines > 0, "in Studio: it logs")
	check(h.record.races == 400 and h.record.wins == 5 and h.leagueWins.Rookie == 5, "races, wins and leagueWins set")
	check(Ageing.atPeak(h.stats, h.potential), "nearPotential: at peak share")
	check(Ageing.stage(h.record.races, false) == "Veteran" and Ageing.declineFromOf(h) == 400, "Veteran at its peak: declineFrom stored")
	check(GameConfig.legs.fromRaces == 0, "legsFromRaces overrides legs.fromRaces")
	check(Legs.view(h, T0).warn == true and h.legs.raceAt == T0, "legsRun 5: the warning chip (raceAt = now, the rest rule keeps it)")
	check(h.points == 90 and math.abs(ClassPath.cupFill("Rookie", h.points) :: number - 0.9) < 1e-9, "leaguePoints: the Cup bar at 90%")
	check(ClassPath.view(h, false).step == "Top", "5 wins: the Top Horse step")
	local young = { h = horse() }
	StudioTest.apply(young, T0, true, pick, { horseRaces = 345 })
	check(Ageing.view(young.h).toVeteran == 5 and Ageing.declineFromOf(young.h) == nil, "345 races: Veteran in 5, no decline yet")
	local none = StudioTest.apply({}, T0, true, function(_) return nil end, { horseRaces = 10 })
	check(#none == 1 and string.find(none[1], "no active horse", 1, true) ~= nil, "no horse: one clear line, no error")
	GameConfig.legs.fromRaces = savedFrom
end
