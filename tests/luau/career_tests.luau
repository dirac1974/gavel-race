--!strict
-- Stage 7 of docs/plans/horse-life-and-retention.md (D-059): careers, Legend Retirement and
-- Rehoming. No ageing or decline; a badge every 25 races; a Veteran at 100 may become a Legend
-- (keeps its stats, still rideable, frees its stall without shifting the others); rehoming pays
-- half of what was paid (never the market price, never more), undo for 72 h at the same price;
-- the starter, your last racing horse, a Legend and a busy horse stay; buy-and-rehome loops never
-- make Green Cash.
local fs = require("@lune/fs")
local Horse = require("../../game/src/shared/Horse")
local Profile = require("../../game/src/shared/Profile")
local Market = require("../../game/src/shared/Market")
local Leagues = require("../../game/src/shared/Leagues")
local Career = require("../../game/src/shared/Career")
local GameConfig = require("../../game/src/shared/GameConfig")
local Words = require("../../game/src/shared/Words")

local DAY = 86400
local T0 = 20000 * DAY + 3600
local HOUR = 3600
local E = GameConfig.energy

local STATS = { speed = 50, accel = 50, stamina = 50, grit = 50 }
local POT = { speed = 80, accel = 80, stamina = 80, grit = 80 }

local function rngOf(seed: number)
	local s = seed
	return {
		NextInteger = function(_self, lo: number, hi: number): number
			s = (s * 1103515245 + 12345) % 2147483648
			return lo + math.floor((hi - lo + 1) * s / 2147483648)
		end,
	}
end

-- A player with a starter and `n` more horses bought at `price` each.
local function stable(n: number, price: number?)
	local p = Profile.new(T0)
	p.flags.starterPicked = true
	Profile.addHorse(p, Horse.starter(Profile.newHorseId(p), "Comet", "bay", rngOf(3), T0))
	for k = 1, n do
		local h = Horse.new(Profile.newHorseId(p), "Horse" .. k, "grey", STATS, POT, T0)
		h.origin, h.paid = "market", price or 400
		Profile.addHorse(p, h)
	end
	return p
end

local function ids(list: { any }): string
	local out = {}
	for _, h in list do table.insert(out, h.id) end
	return table.concat(out, ",")
end

return function(check: (boolean, string) -> (), _close: any)
	-- Careers: badges every 25, a Veteran at 100, no decline --------------------------------
	do
		check(GameConfig.career.badgeEvery == 25 and GameConfig.career.veteranAt == 100, "career config (D-059)")
		check(Career.badges(0) == 0 and Career.badges(24) == 0 and Career.badges(25) == 1 and Career.badges(99) == 3 and Career.badges(100) == 4,
			"a badge every 25 races")
		check(Career.toNextBadge(0) == 25 and Career.toNextBadge(24) == 1 and Career.toNextBadge(25) == 25, "races to the next badge")
		local b, v = Career.crossed(24, 25)
		check(b == 25 and not v, "the 25th race earns the 25-race badge")
		b, v = Career.crossed(25, 26)
		check(b == nil and not v, "no badge in between")
		b, v = Career.crossed(99, 100)
		check(b == 100 and v, "the 100th race: a badge and Veteran")
		b, v = Career.crossed(100, 101)
		check(b == nil and not v, "Veteran only once")
		local h = Horse.new("h9", "Maple", "bay", STATS, POT, T0)
		local before = table.clone(h.stats)
		for k = 1, 150 do
			Horse.recordRace(h, (k % 8) + 1, 0, 0, T0 + k)
		end
		local same = true
		for _, s in Horse.STATS do same = same and h.stats[s] == before[s] end
		check(same and h.record.races == 150, "no ageing: 150 races never lower a stat")
		check(Career.isVeteran(h) and Career.suggestLegend(h), "a Veteran gets the Legend suggestion")
		check(string.find(Career.line(150, 2, false), "Veteran") ~= nil and string.find(Career.line(150, 2, false), "2 Cups") ~= nil,
			"career line: badges, Cups and Veteran")
		check(string.find(Career.line(10, 0, false), "0 badges") ~= nil, "career line for a new horse")
		-- the race hook reports what a race crossed
		local p = stable(1)
		local h2 = p.horses[2]
		h2.record.races = 24
		local r0, r1 = Profile.recordRace(p, h2.id, 4, 0, 0, T0)
		check(r0 == 24 and r1 == 25 and Career.crossed(r0, r1) == 25, "recordRace returns races before and after")
		check(Profile.recordRace(p, "nope", 1, 0, 0, T0) == nil, "no horse, no career")
		for _, t in { Career.badgeToast("Sparkle Comet", 75), Career.veteranToast("Sparkle Comet") } do
			check(Words.count(t) <= GameConfig.ui.toastMaxWords, "career toast short: " .. t)
		end
	end

	-- Legend Retirement --------------------------------------------------------------------
	do
		local p = stable(3)
		p.stalls = 3
		Profile.fillStalls(p)
		local starter, a, b, c = p.horses[1], p.horses[2], p.horses[3], p.horses[4]
		check(starter.stall == 1 and a.stall == 2 and b.stall == 3 and c.stall == nil, "three stalls, one in the pasture")
		a.record.races, a.record.wins, a.record.cups = 120, 30, 2
		a.stats.speed = 77
		check(Leagues.retire(p, b.id, T0) == nil, "not a Veteran yet: no Legend")
		local plaque, why = Leagues.retire(p, a.id, T0)
		check(plaque ~= nil and why == nil and plaque.legend == true and plaque.cups == 2 and plaque.wins == 30, "a Veteran becomes a Legend with a plaque")
		check(Profile.horse(p, a.id) == a and a.legend == T0 and a.stats.speed == 77, "the Legend stays yours and keeps its stats")
		check(a.stall == nil and starter.stall == 1 and b.stall == 3 and c.stall == 2, "its stall goes to the pasture horse; the others never shift")
		check(not Leagues.canEnter(a, { league = a.league }, 50) and not Leagues.canEnter(a, { league = a.league, practice = true }, 50),
			"a Legend doesn't race")
		check(Profile.rideHorse(p, a.id) == a, "a Legend can still be ridden")
		check(Profile.rideHorse(p, b.id) == Profile.activeHorse(p) and Profile.rideHorse(p, nil) == Profile.activeHorse(p),
			"only a Legend is ridden by id; otherwise the active horse")
		check(not Profile.setActive(p, a.id), "a Legend isn't the race horse")
		check(select(2, Leagues.retire(p, a.id, T0)) ~= nil, "a Legend only once")
		check(#Profile.legends(p) == 1 and #Profile.pasture(p) == 0 and Profile.racers(p) == 3, "legends, pasture and racers")
		-- the active horse moves off a new Legend
		p.activeHorse = c.id
		c.record.races = 100
		Leagues.retire(p, c.id, T0)
		check(p.activeHorse ~= c.id and Profile.isStalled(p, p.activeHorse :: string), "the active horse moves to a stalled one")
		-- your last racing horse stays racing
		local q = stable(0)
		q.horses[1].record.races = 200
		local pl, w = Leagues.retire(q, q.horses[1].id, T0)
		check(pl == nil and w ~= nil and q.horses[1].legend == nil, "the last racing horse can't retire")
		-- suggested once
		local r = stable(1)
		r.horses[2].record.races = 100
		check(Career.suggestLegend(r.horses[2]), "suggested at 100")
		check(Leagues.markAsked(r, r.horses[2].id) and not Career.suggestLegend(r.horses[2]), "never suggested twice")
		check(Career.canBeLegend(r.horses[2]), "still a Legend later, from its card")
		-- a Legend survives a save and load
		local saved = Profile.migrate(p, T0 + DAY)
		local la = Profile.horse(saved, a.id)
		check(la ~= nil and la.legend == T0 and la.stall == nil and la.stats.speed == 77, "a Legend loads as a Legend")
		-- busy horses don't retire
		check(Leagues.retireBlock("Comet", "h1", { racingHorse = "h1" }) ~= nil and Leagues.retireBlock("Comet", "h1", { ridingHorse = "h1" }) ~= nil,
			"retire refused while busy (D-065)")
	end

	-- Stalls stored per horse ----------------------------------------------------------------
	do
		-- an older save: the first `stalls` horses in the list were stalled
		local old = { stalls = 2, flags = { starterPicked = true }, horses = {
			{ id = "h1", name = "Comet" }, { id = "h2", name = "Maple" }, { id = "h3", name = "Pip" } }, activeHorse = "h2" }
		local p = Profile.migrate(old, T0)
		check(p.horses[1].stall == 1 and p.horses[2].stall == 2 and p.horses[3].stall == nil and p.activeHorse == "h2", "an older save keeps its stalls")
		check(p.horses[1].origin == "starter" and p.horses[2].origin == nil, "an older save's first horse is the starter")
		-- free stalls stay free across loads after that
		p.horses[1].stall = nil
		p.horses[3].stall = 1
		local again = Profile.migrate(p, T0)
		check(again.horses[3].stall == 1 and again.horses[1].stall == nil and again.horses[2].stall == 2, "stalls load as saved")
		-- junk stalls are cleared
		again.horses[1].stall, again.horses[2].stall = 2, 9
		local fixed = Profile.migrate(again, T0)
		local used = {}
		local dup = false
		for _, h in fixed.horses do
			if h.stall then
				dup = dup or used[h.stall] == true or h.stall > fixed.stalls
				used[h.stall] = true
			end
		end
		check(not dup, "no shared or out-of-range stalls after a load")
		-- swap into a free stall
		local q = stable(2)
		check(q.horses[3].stall == nil, "the third horse is in the pasture")
		q.horses[2].origin = "market"
		local ok = Market.rehome(q, q.horses[2].id, T0, {})
		check(ok and q.horses[2].stall == 2 and q.horses[1].stall == 1, "a rehomed horse's stall goes to the pasture horse")
		local r = stable(2)
		r.horses[2].stall = nil -- an empty stall 2
		check(Profile.swapStall(r, nil, r.horses[2].id) and r.horses[2].stall == 2, "a pasture horse moves into a free stall")
		check(not Profile.swapStall(r, nil, r.horses[3].id), "no free stall: pick one to swap")
		check(Profile.swapStall(r, r.horses[2].id, r.horses[3].id) and r.horses[3].stall == 2 and r.horses[2].stall == nil, "swap keeps the stall number")
	end

	-- Rehoming: price paid, never market, never more ------------------------------------------
	do
		check(GameConfig.rehome.share == 0.5 and GameConfig.rehome.undoHours == 72, "rehome config (D-059)")
		local p = stable(2, 1250)
		p.cash = 0
		local h = p.horses[2]
		for _, s in Horse.STATS do h.stats[s] = 95 end -- trained up: the market would ask far more now
		check(Market.price(h) > 1250 and Market.rehomeValue(h) == 625, "rehome pays half of what was paid, not the market price")
		local earned = p.totals.cashEarned
		local ok, msg, info = Market.rehome(p, h.id, T0, {})
		check(ok and p.cash == 625 and info.cash == 625 and not info.rosette, "rehome pays 625 for a 1250 horse")
		check(p.totals.cashEarned == earned, "rehome cash isn't counted as earned (no job progress)")
		check(string.find(msg, "Sunny Meadow Riding School") ~= nil, "the goodbye says Sunny Meadow Riding School")
		check(Words.count(msg) <= GameConfig.ui.toastMaxWords, "the goodbye toast is short")
		for _, paid in { 0, 1, 7, 10, 999, 1250, 4001 } do
			local x = Horse.new("hx", "X", "bay", STATS, POT, T0)
			x.paid = paid
			check(Market.rehomeValue(x) <= paid and Market.rehomeValue(x) == math.floor(paid / 2), "half and never more: " .. paid)
		end
		local neg = Horse.new("hn", "N", "bay", STATS, POT, T0)
		neg.paid = -500 :: any
		check(Market.rehomeValue(Horse.repair(neg, T0)) == 0, "a junk price pays nothing")
		-- tamed and gifted: 0 and a goodbye rosette, once per horse
		local t = stable(2)
		local tamed = t.horses[2]
		tamed.origin, tamed.paid = "tamed", 0
		local cash0 = t.cash
		local okT, _, infoT = Market.rehome(t, tamed.id, T0, {})
		check(okT and t.cash == cash0 and infoT.rosette and t.goodbyeRosettes == 1, "a tamed horse: 0 and a goodbye rosette")
		Market.undoRehome(t, tamed.id, T0 + HOUR)
		local _, _, infoT2 = Market.rehome(t, tamed.id, T0 + 2 * HOUR, {})
		check(not infoT2.rosette and t.goodbyeRosettes == 1, "one goodbye rosette per horse, whatever the undos")
	end

	-- Undo for 72 h at the same price ------------------------------------------------------------
	do
		local p = stable(2, 800)
		local h = p.horses[3]
		h.name, h.stats.grit, h.bond = "Silver Dash", 71, 44
		local id = h.id
		Market.rehome(p, id, T0, {})
		check(Profile.horse(p, id) == nil and #p.rehomed == 1, "rehomed: gone from the stable, waiting at the school")
		local view = Profile.view(p, T0 + HOUR, E)
		check(#view.rehomed == 1 and view.rehomed[1].daysLeft == 3 and view.rehomed[1].cash == 400, "the view lists it with days left, no clock")
		local cash = p.cash
		local ok, msg, back = Market.undoRehome(p, id, T0 + 71 * HOUR)
		check(ok and back and back.name == "Silver Dash" and back.stats.grit == 71 and back.bond == 44 and back.id == id, "undo within 72 h: same horse, name and stats")
		check(p.cash == cash - 400 and #p.rehomed == 0, "undo costs exactly what the school paid")
		check(Words.count(msg) <= GameConfig.ui.toastMaxWords, "undo toast short")
		-- after 72 h it's gone
		Market.rehome(p, id, T0 + 72 * HOUR, {})
		local okLate = Market.undoRehome(p, id, T0 + 144 * HOUR)
		check(not okLate and Profile.horse(p, id) == nil and #p.rehomed == 0, "after 72 h the horse has settled in for good")
		-- a load drops expired entries too
		Market.rehome(p, p.horses[2].id, T0, {})
		local loaded = Profile.migrate(p, T0 + 73 * HOUR)
		check(#loaded.rehomed == 0, "a load after 72 h keeps nothing")
		local q = stable(2, 600)
		Market.rehome(q, q.horses[2].id, T0, {})
		local loadedQ = Profile.migrate(q, T0 + HOUR)
		check(#loadedQ.rehomed == 1 and loadedQ.rehomed[1].horse.name == "Horse1", "a load inside 72 h keeps it")
		-- undo needs the cash and room
		local r = stable(2, 600)
		local rid = r.horses[2].id
		Market.rehome(r, rid, T0, {})
		r.cash = 299
		check(not Market.undoRehome(r, rid, T0 + HOUR) and #r.rehomed == 1, "undo needs the same Green Cash")
		r.cash = 300
		while #r.horses < Market.MAX_HORSES do Profile.addHorse(r, Horse.new(Profile.newHorseId(r), "F", "bay", STATS, POT, T0)) end
		check(not Market.undoRehome(r, rid, T0 + HOUR), "undo needs room in the stable")
		-- at most maxWaiting wait at the school
		local m = stable(GameConfig.rehome.maxWaiting + 3, 100)
		for k = 2, #m.horses - 1 do Market.rehome(m, m.horses[2].id, T0 + k, {}) end
		check(#m.rehomed == GameConfig.rehome.maxWaiting, "at most maxWaiting can come back")
	end

	-- Who can't be rehomed ------------------------------------------------------------------------
	do
		local p = stable(1)
		local starter, other = p.horses[1], p.horses[2]
		check(Market.rehomeBlock(p, starter.id, {}) ~= nil and not Market.rehome(p, starter.id, T0, {}), "the starter stays")
		local solo = stable(0)
		local alone = Horse.new(Profile.newHorseId(solo), "Solo", "bay", STATS, POT, T0)
		alone.origin, alone.paid = "market", 500
		Profile.addHorse(solo, alone)
		solo.horses[1].record.races = 100
		Leagues.retire(solo, solo.horses[1].id, T0) -- the starter is a Legend, Solo races
		check(Market.rehomeBlock(solo, alone.id, {}) ~= nil, "your last racing horse stays")
		check(Market.rehomeBlock(solo, solo.horses[1].id, {}) ~= nil, "a Legend stays")
		for label, busy in {
			racing = { racing = true }, queued = { inLine = true }, atRaces = { racingHorse = other.id },
			riding = { ridingHorse = other.id }, training = { trainingRide = true, ridingHorse = other.id },
		} do
			local why = Market.rehomeBlock(p, other.id, busy)
			check(why ~= nil and not Market.rehome(p, other.id, T0, busy) and Profile.horse(p, other.id) ~= nil, "busy refused: " .. label)
			check(string.find(why or "", "Rehome") ~= nil or string.find(why or "", "rehome") ~= nil, "busy says rehome: " .. label)
		end
		check(Market.rehomeBlock(p, other.id, { ridingHorse = starter.id }) == nil, "another horse can go while you ride")
		check(Market.rehomeBlock(p, "nope", {}) ~= nil, "only your horses")
		local was = GameConfig.rehome.enabled
		GameConfig.rehome.enabled = false
		check(Market.rehomeBlock(p, other.id, {}) ~= nil, "rehome.enabled = false closes the school")
		GameConfig.rehome.enabled = was
	end

	-- No exploit: buy, rehome and undo loops never make Green Cash ------------------------------
	do
		local p = stable(0)
		p.cash = 100000
		local start = p.cash
		local now = T0
		-- buy every listing this week and rehome each: half back, and a listing never sells twice
		for _, l in Market.stock(now) do
			local ok, _, h = Market.buy(p, l.id, now)
			check(ok and h.paid == l.price, "a bought horse remembers its price")
			Market.rehome(p, h.id, now, {})
			check(not Market.buy(p, l.id, now), "a rehomed listing can't be bought again")
		end
		check(p.cash < start, "buy and rehome always costs")
		-- rehome and undo, over and over, never gains
		local ok, _, h = Market.buy(p, Market.stock(now + 7 * DAY)[1].id, now + 7 * DAY)
		check(ok, "next week's horse")
		local low, high = p.cash, p.cash
		local afterBuy = p.cash
		for k = 1, 50 do
			local t = now + 7 * DAY + k * 60
			Market.rehome(p, h.id, t, {})
			high = math.max(high, p.cash)
			Market.undoRehome(p, h.id, t + 1)
			low = math.min(low, p.cash)
		end
		check(p.cash == afterBuy and high - afterBuy == math.floor(h.paid / 2), "rehome and undo: never more than half back, net zero")
		check(p.totals.cashEarned == 0, "none of it counts as earned")
		-- train, rehome, undo, rehome: still half of what was paid
		for _, s in Horse.STATS do h.stats[s] = 99 end
		local c0 = p.cash
		Market.rehome(p, h.id, now + 8 * DAY, {})
		check(p.cash - c0 == math.floor(h.paid / 2), "training never raises the rehome price")
		-- taming every day and rehoming: nothing
		local tp = stable(1)
		tp.cash = 0
		for d = 0, 9 do
			Profile.addItem(tp, "carrot", 1)
			local okT, _, th = Market.tame(tp, "pinto", rngOf(d + 1), T0 + d * DAY)
			if okT then Market.rehome(tp, th.id, T0 + d * DAY, {}) end
		end
		check(tp.cash == 0, "tamed horses rehome for 0")
	end

	-- Copy: the riding school, never a farm or "sold" (D-059) -----------------------------------
	do
		local files = { "game/src/shared/Market.luau", "game/src/shared/Leagues.luau", "game/src/shared/Career.luau",
			"game/src/client/HorsesClient.client.luau", "game/src/client/RehomeClient.client.luau", "game/src/server/MarketService.server.luau" }
		for _, f in files do
			if fs.isFile(f) then
				for line in string.gmatch(fs.readFile(f) .. "\n", "([^\n]*)\n") do
					local code = string.match(line, "^(.-)%-%-") or line
					for lit in string.gmatch(code, "\"([^\"]*)\"") do
						local low = string.lower(lit)
						for _, w in { "farm", "sold", "sell", "dies", "died", "gone forever" } do
							check(string.find(low, "%f[%a]" .. w .. "%f[%A]") == nil, string.format("%s: no %q in %q", f, w, lit))
						end
					end
				end
			end
		end
	end
end
