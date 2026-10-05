--!strict
-- Tests for the pure game modules: BurstMeter, TapTime, Stride, Integrity, RaceSession.
local RaceMath = require("../../src/RaceMath")
local GameConfig = require("../../game/src/shared/GameConfig")
local ThemePack = require("../../game/src/shared/ThemePack")
local BurstMeter = require("../../game/src/shared/BurstMeter")
local TapTime = require("../../game/src/shared/TapTime")
local Stride = require("../../game/src/shared/Stride")
local Integrity = require("../../game/src/shared/Integrity")
local RaceSession = require("../../game/src/shared/RaceSession")

local function makeRng(seed0: number)
	local seed = seed0
	return {
		NextNumber = function(_self): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
end

return function(check: (boolean, string) -> (), close: (number, number, number) -> boolean)
	-- BurstMeter -------------------------------------------------------------
	local sweep = 2.0
	check(close(BurstMeter.position(0, sweep), -1, 1e-12), "meter starts at -1 with no phase")
	check(close(BurstMeter.position(sweep / 4, sweep), 0, 1e-12), "meter at center after a quarter sweep")
	check(close(BurstMeter.position(sweep / 2, sweep), 1, 1e-12), "meter at +1 after half a sweep")
	check(close(BurstMeter.position(sweep * 3.25, sweep), 0, 1e-9), "meter is periodic")
	check(close(BurstMeter.position(0, sweep, 0.25), 0, 1e-12), "phase 0.25 starts at the center")
	check(close(BurstMeter.position(0.5, sweep, 0.25), BurstMeter.position(1.0, sweep), 1e-12), "phase shifts time")

	local fixed = { sweepSeconds = sweep, targetDrift = 0, twoTargets = false }
	check(close(BurstMeter.score(sweep / 4, fixed), 100, 1e-9), "perfect tap scores 100")
	check(close(BurstMeter.score(0, fixed), 0, 1e-9), "edge tap scores 0")

	local function averageRandomTap(spec): number
		local n, sum = 20000, 0
		for k = 0, n - 1 do sum += BurstMeter.score((k + 0.5) / n * sweep, spec) end
		return sum / n
	end
	check(close(averageRandomTap(fixed), 50, 0.05), "random tap averages 50 (fixed target)")
	local two = { sweepSeconds = sweep, targetDrift = 0, twoTargets = true }
	check(close(averageRandomTap(two), 50, 0.05), "random tap averages 50 (two targets)")
	check(close(BurstMeter.score(sweep / 8, two), 100, 1e-9), "two-target perfect tap at -0.5")
	for k = 0, 100 do
		local c = BurstMeter.targetCenter(k * 0.37, { sweepSeconds = sweep, targetDrift = 0.3, twoTargets = false })
		check(math.abs(c) <= 0.3 + 1e-12, "drifting target stays within drift")
	end

	-- D-022 random start: a fixed-delay macro scores no better than random tapping
	-- (~50) at any delay, in every league.
	local rng = makeRng(99)
	for _, leagueName in GameConfig.leagueOrder do
		local league = GameConfig.leagues[leagueName]
		local phases = {}
		for i = 1, 3000 do phases[i] = BurstMeter.randomPhase(rng) end
		local best = 0
		for d = 0.05, league.windowSeconds, 0.05 do
			local sum = 0
			for _, ph in phases do
				sum += BurstMeter.score(d, { sweepSeconds = league.sweepSeconds, targetDrift = league.targetDrift,
					twoTargets = league.twoTargetFinal, phase = ph })
			end
			best = math.max(best, sum / #phases)
		end
		check(best < 54, leagueName .. ": best fixed-delay macro is no better than random tapping")
	end

	-- TapTime (D-021) ---------------------------------------------------------
	check(TapTime.resolve(10.0, 10.2, 9, 12, 0.3) == 10.0, "plausible claimed time is used")
	check(TapTime.resolve(9.5, 10.2, 9, 12, 0.3) == 10.2, "stale claim falls back to arrival")
	check(TapTime.resolve(10.5, 10.2, 9, 12, 0.3) == 10.2, "future claim falls back to arrival")
	check(TapTime.resolve(12.1, 12.2, 9, 12, 0.3) == nil, "tap after the window is rejected")
	check(close(TapTime.rewindAllowance(0.1, 0.05, 0.3), 0.1, 1e-12), "allowance = one-way latency + margin")
	check(close(TapTime.rewindAllowance(0, 0.05, 0.3), 0.05, 1e-12), "zero ping (Studio) leaves just the margin")
	check(close(TapTime.rewindAllowance(-1, 0.05, 0.3), 0.05, 1e-12), "negative ping treated as zero")
	check(close(TapTime.rewindAllowance(2.0, 0.05, 0.3), 0.3, 1e-12), "allowance is capped")
	local lowPing = TapTime.rewindAllowance(0.03, 0.05, 0.3) -- 65 ms
	check(TapTime.resolve(10.2, 10.25, 9, 12, lowPing) == 10.2, "honest claim inside the allowance is used")
	check(TapTime.resolve(10.0, 10.25, 9, 12, lowPing) == 10.25, "claim 250 ms back is refused on a 30 ms ping")
	local rookie = { sweepSeconds = 2.4, targetDrift = 0, twoTargets = false }
	local center = 2.4 / 4
	local t = TapTime.resolve(center, center + 0.25, 0, 4, lowPing) :: number
	check(BurstMeter.score(t, rookie) < 60, "rewind exploit no longer scores a perfect tap")

	-- Stride (most coverage is the Python parity in run_all) ---------------------
	local strideSpec = { beats = 8, intervalLo = 0.6, intervalHi = 0.6, drift = 0, leadChange = false, half = 0.08 }
	local beats = Stride.schedule(makeRng(5), 10, strideSpec)
	check(#beats == 8 and close(beats[1], 10, 1e-12) and close(beats[8], 14.2, 1e-9), "steady Rookie schedule")
	check(close(Stride.score(beats, beats, 0.08), 100, 1e-9), "taps on every beat score 100")
	check(Stride.score(beats, {}, 0.08) == 0, "no taps score 0")
	local mash = {}
	for k = 0, 100 do table.insert(mash, 10 + k * 0.045) end
	check(Stride.score(beats, mash, 0.08) == 0, "mashing scores 0")
	check(Stride.tapLabel(0.005, 0.08, GameConfig.strideLabels) == "Perfect", "5 ms is Perfect")
	check(Stride.tapLabel(0.06, 0.08, GameConfig.strideLabels) == "Good", "60 ms is Good")
	check(Stride.tapLabel(0.2, 0.08, GameConfig.strideLabels) == "Off beat", "200 ms is off beat")
	local k, err = Stride.nearest(beats, 10.62)
	check(k == 2 and close(err, 0.02, 1e-9), "nearest beat and signed error")

	-- Integrity (D-022) ---------------------------------------------------------
	local icfg = table.clone(GameConfig.integrity)
	local function botErrors(seed: number, count: number, sd: number): { number }
		local r, out = makeRng(seed), {}
		for _ = 1, count do
			local u1, u2 = math.max(r:NextNumber(), 1e-12), r:NextNumber()
			table.insert(out, sd * math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2))
		end
		return out
	end
	local tr = Integrity.new()
	for race = 1, 15 do Integrity.addRace(tr, botErrors(race, 21, 0.005), 24, 100) end
	check(Integrity.spread(tr) < 0.012, "bot-like gap errors have a tiny spread")
	check(not Integrity.isSuspicious(tr, icfg), "one day of evidence is not enough")
	Integrity.addRace(tr, botErrors(77, 21, 0.005), 24, 101)
	check(Integrity.isSuspicious(tr, icfg), "bot-like spread over 300+ beats, 5+ races, 2 days is suspicious")
	check(Integrity.check(tr, 101, icfg), "check records a strike")
	check(tr.beats == 0 and tr.n == 0 and #tr.strikes == 1, "a strike starts a fresh evidence window")
	check(not Integrity.check(tr, 101, icfg), "no second strike without new evidence")

	local human = Integrity.new()
	for race = 1, 30 do Integrity.addRace(human, botErrors(200 + race, 21, 0.045), 24, 100 + race % 3) end
	check(not Integrity.isSuspicious(human, icfg), "human-like spread is never suspicious")

	tr.strikes = { 0, 50, 100 }
	check(Integrity.activeStrikes(tr, 120, icfg) == 2, "strikes older than 90 days expire")
	check(Integrity.action(0, icfg) == "none", "no strikes, no action")
	check(Integrity.action(3, icfg) == "log", "log-only mode never acts")
	icfg.logOnly = false
	check(Integrity.action(1, icfg) == "log", "first strike is logged only")
	check(Integrity.action(2, icfg) == "warn", "second strike warns")
	check(Integrity.action(3, icfg) == "review", "third strike goes to review")

	-- RaceSession ------------------------------------------------------------
	local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, Stride = Stride }
	local humans = {
		{ id = "1", name = "Ava", rating = 60, isBot = false },
		{ id = "2", name = "Ben", rating = 55, isBot = false },
	}
	local field = RaceSession.fillWithBots(humans, 8, GameConfig, ThemePack, makeRng(1))
	check(#field == 8, "lobby fills to 8")
	local bots = 0
	for _, l in field do
		if l.isBot then
			bots += 1
			check(math.abs(l.rating - 57.5) <= GameConfig.botRatingSpread + 2.5, "bot rated near human median")
		end
	end
	check(bots == 6, "six bots added")

	local function perfectBurstTime(spec): number
		-- fixed center target: position 0 when (t / sweep + phase) % 1 == 0.25
		return ((0.25 - spec.phase) % 1) * spec.sweepSeconds
	end

	local function newSession(seed: number)
		return RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Bronze", lanes = field, rng = makeRng(seed) })
	end

	local function runRace(seed: number, perfect: boolean, benDrops: boolean, avaAverageOnly: boolean?)
		local s = newSession(seed)
		if avaAverageOnly then s:setAverageOnly("1", true) end
		for seg, kind in GameConfig.segments do
			if kind == "stride" then
				local b = s:openStretch(seg, 10 * seg)
				if perfect then s:scoreStretch("1", seg, b) end
			else
				local spec = s:burstSpec()
				if perfect then s:submitBurst("1", seg, perfectBurstTime(spec)) end
			end
			if benDrops and seg == 2 then s:dropSegment("2", seg) end
			s:closeSegment(seg)
		end
		return s, s:finish()
	end

	local s0 = newSession(3)
	local qsum = 0
	for _, v in s0.q do qsum += v end
	check(close(qsum, 1, 1e-12), "base chances sum to 1")
	check(s0:segmentCount() == 4 and s0:kind(4) == "burst", "three stretches then the burst")
	check(not pcall(function() s0:openStretch(2, 0) end), "stretches open in order")
	local b1 = s0:openStretch(1, 5)
	check(#b1 == GameConfig.stride.beats, "stretch has the configured beat count")
	check(not pcall(function() s0:openStretch(1, 5) end), "a stretch opens once")
	local res = s0:scoreStretch("1", 1, b1)
	check(res ~= nil and close((res :: any).score, 100, 1e-9) and (res :: any).matched == #b1, "perfect stretch recorded")
	check(s0:scoreStretch("1", 1, b1) == nil, "a stretch is scored once per rider")
	check(s0:scoreStretch("bot:1", 1, b1) == nil, "bots can't tap")
	check(s0:submitBurst("1", 1, 0.5) == nil, "no burst tap during a stretch")
	check(not pcall(function() s0:closeSegment(2) end), "segments close in order")

	-- Burst counts double: stretches all missed, perfect burst -> S = 200 / 5 = 40.
	local sw = newSession(4)
	for seg, kind in GameConfig.segments do
		if kind == "stride" then
			sw:openStretch(seg, 10 * seg)
		else
			local spec = sw:burstSpec()
			check(sw:burstSpec() == spec, "burst spec is picked once and shared")
			check(close(sw:submitBurst("1", seg, perfectBurstTime(spec)) :: number, 100, 1e-6), "perfect burst tap")
			check(sw:submitBurst("1", seg, 0.1) == nil, "one burst tap per rider")
		end
		sw:closeSegment(seg)
	end
	check(close(sw:scoresSoFar()[1], 40, 1e-6), "Final Burst counts double")

	-- A perfect rider ends with a higher live chance than a rider who misses.
	local sPerfect = select(1, runRace(11, true, false))
	local sMiss = select(1, runRace(11, false, false))
	check(sPerfect.live[1] > sMiss.live[1], "perfect taps beat missed taps")

	-- D-022 flag 2: average-only lanes score the segment average, not their taps.
	local sAvg = select(1, runRace(11, true, false, true))
	check((sAvg.lanes[1].scores[1] :: number) < 100, "average-only rider doesn't keep a perfect stretch")
	check(sAvg.live[1] < sPerfect.live[1], "average-only removes the edge")

	-- Prize rules over many races.
	local B = GameConfig.leagues.Bronze.B
	for seed = 1, 200 do
		local sess, result = runRace(seed, true, true)
		local livesum = 0
		for _, v in sess.live do livesum += v end
		check(close(livesum, 1, 1e-12), "live chances sum to 1")
		check(sess.lanes[2].scores[2] ~= nil and (sess.lanes[2].scores[2] :: number) >= 0, "dropped segment scored at average")
		for _, p in result.prizes do
			if p.isBot then
				check(p.cash == 0, "bots are never paid")
			elseif p.place == 1 then
				check(p.cash == sess.purses[sess:laneIndex(p.id) :: number], "winner gets locked purse")
			elseif p.place <= 4 then
				check(p.cash == math.floor(B * GameConfig.placePrizes[p.place - 1] + 0.5), "place prize")
			else
				check(p.cash == 0, "5th and below win no cash")
			end
			check(p.leaguePoints == (GameConfig.leaguePoints[p.place] or GameConfig.finishPoints), "league points")
		end
	end

	-- Determinism: same seed, same result.
	local _, r1 = runRace(42, true, false)
	local _, r2 = runRace(42, true, false)
	for i = 1, 8 do check(r1.order[i] == r2.order[i], "same seed gives same finish") end
end
