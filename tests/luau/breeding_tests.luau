--!strict
-- Breeding (D-080): Breeding.luau matches src/breeding.py on the parity table
-- (tests/fixtures/breeding.json, `python tests/test_breeding.py --write`), rolls the foal once at
-- confirm, and GameConfig.breeding keeps breed-then-sell a loss.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Breeding = require("../../game/src/shared/Breeding")
local GameConfig = require("../../game/src/shared/GameConfig")

local function listRng(values: { number })
	local i = 0
	return {
		NextNumber = function(_self)
			i += 1
			return values[i]
		end,
	}
end

local function same(a: any, b: any): boolean
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then
		if type(a) == "number" then return math.abs(a - b) <= 1e-12 end
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then return false end
	end
	for k in b do
		if a[k] == nil then return false end
	end
	return true
end

local function horse(i: number, league: string, races: number, pot: any, coat: string, legend: number?, lent: number?, name: string?): any
	return { id = `h{i}`, name = name or `Horse{i}`, league = league, record = { races = races }, potential = pot,
		coat = coat, legend = legend, lent = lent }
end

local function profile(pots: any, kw: any): any
	local pa, pb = pots[1][1], pots[1][2]
	local horses = {
		horse(1, "Bronze", 40, pa, "bay", nil, nil, "Comet"), horse(2, "Rookie", 31, pb, "grey", nil, nil, "Maple"),
		horse(3, "Rookie", 12, pb, "pinto"), horse(4, "Gold", 400, pa, "appaloosa", 1),
		horse(5, "Silver", 80, pb, "dun", nil, 5), horse(6, "Rookie", 50, pa, "white"),
	}
	for k = 0, (kw.extra or 0) - 1 do table.insert(horses, horse(10 + k, "Rookie", 0, pb, "bay")) end
	return { cash = kw.cash or 1000, totals = { races = kw.races or 100 }, horses = horses }
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	local data = serde.decode("json", fs.readFile("tests/fixtures/breeding.json"))
	local cfgs = data.cfgs
	local pots = data.profile.pots

	for i, row in data.pots do
		local cfg = cfgs[row.cfg]
		local pair = pots[row.pair + 1]
		local tag = `breeding pot {i} ({row.cfg} pair {row.pair})`
		local pot = Breeding.foalPotential(pair[1], pair[2], row.legendA, row.legendB, listRng(row.u), cfg)
		check(same(pot, row.pot), `{tag} potential`)
		check(same(Breeding.startStats(pot, cfg), row.start), `{tag} start stats`)
		check(Breeding.familyLevel(pot, cfg) == row.family, `{tag} family`)
		check(same(Breeding.expectedPotential(pair[1], pair[2], row.legendA, row.legendB, cfg), row.expected), `{tag} expected`)
		check(same(Breeding.legacy(pair[1], pair[2], row.legendA, row.legendB), row.legacy), `{tag} legacy`)
	end

	for i, row in data.coats do
		local cfg = cfgs[row.cfg]
		local t = Breeding.coatChances(row.a, row.b, cfg)
		local tag = `breeding coat {row.cfg} {row.a}+{row.b}`
		check(same(t.chances, row.table.chances), `{tag} chances`)
		check(same(t.parents, row.table.parents), `{tag} parents`)
		check(close(t.surprise.chance, row.table.surprise.chance, 1e-12), `{tag} surprise chance`)
		check(same(t.surprise.coats, row.table.surprise.coats), `{tag} surprise coats`)
		local sum = 0
		for _, p in t.chances do sum += p end
		check(close(sum, 1, 1e-12), `{tag} sums to 1`)
		for k, u in data.us do
			check(Breeding.rollCoat(t.chances, u) == row.rolls[k], `{tag} roll u={u}`)
		end
	end

	for _, row in data.fees do
		check(Breeding.fee(row.a, row.b) == row.fee, `breeding fee {row.a}+{row.b}`)
	end
	for _, row in data.sell do
		check(Breeding.sellValue(row.paid, row.wins, row.cups) == row.value, `breeding sell {row.paid} {row.wins} {row.cups}`)
	end
	for _, row in data.scale do
		check(close(Breeding.youngScale(row.races), row.scale, 1e-12), `breeding youngScale {row.races}`)
	end

	-- the action scripts: confirm rolls once, rest and arrival in owner races, every block message
	local on = cfgs.live
	for _, sc in data.scenarios do
		local p = profile(pots, sc.kw)
		for s, step in sc.steps do
			local want = sc.log[s]
			local tag = `breeding scenario {sc.name} step {s} ({step[1]})`
			local kind = step[1]
			if kind == "confirm" then
				local ok, msg, pend = Breeding.confirm(p, step[2], step[3], step[4], listRng(step[5]), nil, on)
				check(ok == want.ok and msg == want.msg, `{tag}: {msg} vs {want.msg}`)
				check(same(pend, want.pending), `{tag} pending`)
				check(p.cash == want.cash, `{tag} cash {p.cash} vs {want.cash}`)
				check(Breeding.restLeft(p, step[2]) == want.restA and Breeding.nextFoalIn(p) == want.restB, `{tag} rest`)
			elseif kind == "ready" then
				local pend = Breeding.pending(p)
				local r = if pend then Breeding.ready(pend, Breeding.ownerRaces(p), step[2], on) else false
				check(r == want.ready, `{tag} ready {r}`)
			elseif kind == "races" then
				p.totals.races += step[2]
			elseif kind == "cash" then
				p.cash += step[2]
			elseif kind == "arrive" then
				check(same(Breeding.arrive(p, "foal1", "Little Star", step[2], on), want.horse), `{tag} horse`)
			elseif kind == "block" then
				check(Breeding.pairBlock(p, step[2], step[3], nil, on) == want.why, `{tag} why {Breeding.pairBlock(p, step[2], step[3], nil, on)} vs {want.why}`)
				check(Breeding.horseBlock(p, Breeding.find(p, step[2]), nil, on) == want.a, `{tag} horse why`)
			elseif kind == "busy" then
				check(Breeding.pairBlock(p, step[2], step[3], step[4], on) == want.why, `{tag} busy why`)
			end
		end
	end

	-- no reroll: a stored foal survives any number of confirms and comes out unchanged
	local p = profile(pots, { cash = 9000 })
	local ok, _, pend = Breeding.confirm(p, "h1", "h2", 0, listRng({ 0.1, 0.2, 0.3, 0.4, 0.95 }), nil, on)
	check(ok, "breeding confirm")
	local stored = serde.decode("json", serde.encode("json", pend))
	for _ = 1, 3 do
		local again = Breeding.confirm(p, "h4", "h6", 0, listRng({ 0.9, 0.9, 0.9, 0.9, 0.0 }), nil, on)
		check(again == false, "breeding: no second roll while a foal is on the way")
	end
	check(same(Breeding.pending(p), stored), "breeding: the stored foal never changes")
	p.totals.races += 8
	local h = Breeding.arrive(p, "f", "F", 0, on)
	check(h ~= nil and same(h.potential, stored.potential) and h.coat == stored.coat, "breeding: arrival reads the stored roll")
	check(Breeding.pending(p) == nil, "breeding: pending cleared")

	-- systems ruling 2: one foal per foalEveryRaces owner races for the whole stable, so a second
	-- pair is refused until then (rotating parents gains nothing)
	do
		local every = on.foalEveryRaces
		local q = profile(pots, { cash = 10000 })
		check((Breeding.confirm(q, "h1", "h2", 0, listRng({ 0.5, 0.5, 0.5, 0.5, 0.5 }), nil, on)), "breeding: first pair")
		q.totals.races += 8
		check(Breeding.arrive(q, "f1", "F", 0, on) ~= nil, "breeding: first foal arrives")
		for extra = 8, every - 1 do
			local ok, why = Breeding.confirm(q, "h4", "h6", 0, listRng({ 0.5, 0.5, 0.5, 0.5, 0.5 }), nil, on)
			check(not ok and string.sub(why, 1, 12) == "Next foal in", `breeding: second pair refused at {extra}: {why}`)
			q.totals.races += 1
		end
		check((Breeding.confirm(q, "h4", "h6", 0, listRng({ 0.5, 0.5, 0.5, 0.5, 0.5 }), nil, on)), "breeding: second pair after the wait")
		check(Breeding.restLeft(q, "h1") == every and Breeding.nextFoalIn(q) == every, "breeding: restLeft is the stable-wide wait")
	end

	-- the live config: on now that BreedingService is wired (D-080), together with career.suggest;
	-- enabled = false still closes it all. Breed-then-sell always loses cash.
	check(GameConfig.breeding.enabled == GameConfig.career.suggest, "GameConfig.breeding.enabled goes with career.suggest")
	local off = table.clone(GameConfig.breeding)
	off.enabled = false
	check(Breeding.pairBlock(profile(pots, {}), "h1", "h2", nil, off) == "The Foal Barn is closed today", "enabled = false is closed")
	for league, fee in GameConfig.breeding.fee do
		check(Breeding.sellValue(fee, 1e6, 1e6) < fee, `breeding: selling a {league} foal returns less than its fee`)
	end
	check(Breeding.fee("Rookie", "Rookie") == nil and Breeding.fee("Bronze", "Rookie") == 400, "default fees")
end
