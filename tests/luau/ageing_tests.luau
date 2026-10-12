--!strict
-- Ageing (fun-and-return 2026-10-12): Ageing.luau matches src/life_arc.py on the parity table
-- (tests/fixtures/ageing.json, `python tests/test_life_arc.py --write`), and GameConfig.ageing
-- carries the Python values.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Ageing = require("../../game/src/shared/Ageing")
local GameConfig = require("../../game/src/shared/GameConfig")

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local data = serde.decode("json", fs.readFile("tests/fixtures/ageing.json"))
	for name, set in data do
		local cfg = set.cfg
		for _, row in set.rows do
			local r, f = row.races, row.from
			local tag = `ageing {name} races {r} from {f}`
			check(Ageing.stage(r, false, cfg) == row.stage, `{tag} stage {Ageing.stage(r, false, cfg)} vs {row.stage}`)
			check(Ageing.declineSteps(r, f, cfg) == row.steps, `{tag} steps`)
			check(close(Ageing.ratingOffset(r, f, cfg), row.offset, 1e-12), `{tag} offset`)
			check(close(Ageing.racedRating(61.5, r, f, false, cfg), row.raced, 1e-12), `{tag} raced`)
			check(close(Ageing.racedRating(61.5, r, f, true, cfg), row.practice, 1e-12), `{tag} practice`)
			check(Ageing.racesToNextStep(r, f, cfg) == row.next, `{tag} next {Ageing.racesToNextStep(r, f, cfg)} vs {row.next}`)
			check(Ageing.declineWarning(r, f, cfg) == row.warn, `{tag} warn`)
			check(Ageing.veteranSoon(r, cfg) == row.vetSoon, `{tag} veteranSoon`)
			check(close(Ageing.trainMult(r, cfg), row.train, 1e-12), `{tag} train`)
		end
		for i, pk in set.peaks do
			local tag = `ageing {name} peak {i}`
			check(close(Ageing.peakShare(pk.stats, pk.pot), pk.share, 1e-12), `{tag} share`)
			check(Ageing.atPeak(pk.stats, pk.pot, cfg) == pk.atPeak, `{tag} atPeak`)
			check(Ageing.updateDeclineFrom(pk.from, pk.races, pk.stats, pk.pot, cfg) == pk.update, `{tag} declineFrom`)
		end
	end
	local live = data.live.cfg
	for k, v in live do
		check(GameConfig.ageing[k] == v, `GameConfig.ageing.{k} {GameConfig.ageing[k]} vs {v}`)
	end
	-- the default config is GameConfig.ageing
	check(Ageing.stage(29) == "Young" and Ageing.stage(30) == "Prime" and Ageing.stage(350) == "Veteran", "default stages")
	check(Ageing.stage(3, true) == "Legend", "Legend")
	check(GameConfig.career.veteranAt == GameConfig.ageing.veteranAt, "one Veteran: career.veteranAt = ageing.veteranAt")
end
