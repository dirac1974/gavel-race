--!strict
-- Tests for the pure game modules: GavelMeter and RaceSession.
local RaceMath = require("../../src/RaceMath")
local GameConfig = require("../../game/src/shared/GameConfig")
local ThemePack = require("../../game/src/shared/ThemePack")
local GavelMeter = require("../../game/src/shared/GavelMeter")
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
	-- GavelMeter -----------------------------------------------------------
	local sweep = 2.0
	check(close(GavelMeter.position(0, sweep), -1, 1e-12), "meter starts at -1")
	check(close(GavelMeter.position(sweep / 4, sweep), 0, 1e-12), "meter at center after a quarter sweep")
	check(close(GavelMeter.position(sweep / 2, sweep), 1, 1e-12), "meter at +1 after half a sweep")
	check(close(GavelMeter.position(sweep * 3.25, sweep), 0, 1e-9), "meter is periodic")

	local fixed = { sweepSeconds = sweep, targetDrift = 0, twoTargets = false }
	check(close(GavelMeter.score(sweep / 4, fixed), 100, 1e-9), "perfect tap scores 100")
	check(close(GavelMeter.score(0, fixed), 0, 1e-9), "edge tap scores 0")

	local function averageRandomTap(spec): number
		local n, sum = 20000, 0
		for k = 0, n - 1 do sum += GavelMeter.score((k + 0.5) / n * sweep, spec) end
		return sum / n
	end
	check(close(averageRandomTap(fixed), 50, 0.05), "random tap averages 50 (fixed target)")
	local two = { sweepSeconds = sweep, targetDrift = 0, twoTargets = true }
	check(close(averageRandomTap(two), 50, 0.05), "random tap averages 50 (two targets)")
	check(close(GavelMeter.score(sweep / 8, two), 100, 1e-9), "two-target perfect tap at -0.5")
	for k = 0, 100 do
		local c = GavelMeter.targetCenter(k * 0.37, { sweepSeconds = sweep, targetDrift = 0.3, twoTargets = false })
		check(math.abs(c) <= 0.3 + 1e-12, "drifting target stays within drift")
	end

	check(GavelMeter.resolveTapTime(10.0, 10.2, 9, 12, 0.3) == 10.0, "plausible claimed time is used")
	check(GavelMeter.resolveTapTime(9.5, 10.2, 9, 12, 0.3) == 10.2, "stale claim falls back to arrival")
	check(GavelMeter.resolveTapTime(10.5, 10.2, 9, 12, 0.3) == 10.2, "future claim falls back to arrival")
	check(GavelMeter.resolveTapTime(12.1, 12.2, 9, 12, 0.3) == nil, "tap after the window is rejected")

	-- D-021: the allowance follows measured latency, not a flat 0.3 s
	check(close(GavelMeter.rewindAllowance(0.1, 0.05, 0.3), 0.1, 1e-12), "allowance = one-way latency + margin")
	check(close(GavelMeter.rewindAllowance(0, 0.05, 0.3), 0.05, 1e-12), "zero ping (Studio) leaves just the margin")
	check(close(GavelMeter.rewindAllowance(-1, 0.05, 0.3), 0.05, 1e-12), "negative ping treated as zero")
	check(close(GavelMeter.rewindAllowance(2.0, 0.05, 0.3), 0.3, 1e-12), "allowance is capped")
	local lowPing = GavelMeter.rewindAllowance(0.03, 0.05, 0.3) -- 65 ms
	check(GavelMeter.resolveTapTime(10.2, 10.25, 9, 12, lowPing) == 10.2, "honest claim inside the allowance is used")
	check(GavelMeter.resolveTapTime(10.0, 10.25, 9, 12, lowPing) == 10.25, "claim 250 ms back is refused on a 30 ms ping")

	-- The old exploit: wait until the marker passes the center, then claim that moment.
	-- With a 65 ms allowance, a tap sent 250 ms after center is scored where the marker is.
	local rookie = { sweepSeconds = 2.4, targetDrift = 0, twoTargets = false }
	local center = 2.4 / 4
	local sent = center + 0.25
	local t = GavelMeter.resolveTapTime(center, sent, 0, 4, lowPing) :: number
	check(GavelMeter.score(t, rookie) < 60, "rewind exploit no longer scores a perfect tap")
	local tOld = GavelMeter.resolveTapTime(center, sent, 0, 4, 0.3) :: number
	check(close(GavelMeter.score(tOld, rookie), 100, 1e-9), "flat 0.3 s allowance would have scored 100 (documents the hole)")

	-- RaceSession ----------------------------------------------------------
	local deps = { RaceMath = RaceMath, GavelMeter = GavelMeter }
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

	local function runRace(seed: number, avaTap: number?, benDrops: boolean)
		local s = RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Bronze", lanes = field, rng = makeRng(seed) })
		for w = 1, GameConfig.windowsPerRace do
			if avaTap then s:submitTap("1", w, avaTap) end
			if benDrops and w == 2 then s:dropWindow("2", w) end
			s:closeWindow(w)
		end
		return s, s:finish()
	end

	local s0 = RaceSession.new({ deps = deps, config = GameConfig, leagueName = "Bronze", lanes = field, rng = makeRng(3) })
	local qsum = 0
	for _, v in s0.q do qsum += v end
	check(close(qsum, 1, 1e-12), "base chances sum to 1")
	local spec1 = s0:meterSpec(1)
	local perfectT = spec1.sweepSeconds / 4
	check(s0:submitTap("1", 2, perfectT) == nil, "tap for a future window is rejected")
	check(close(s0:submitTap("1", 1, perfectT) :: number, 100, 1e-9), "perfect tap recorded")
	check(s0:submitTap("1", 1, perfectT) == nil, "second tap in a window is rejected")
	check(s0:submitTap("bot:1", 1, perfectT) == nil, "bots can't tap")
	check(not pcall(function() s0:closeWindow(2) end), "windows must close in order")

	-- A perfect rider ends with a higher live chance than a rider who misses.
	local sPerfect = select(1, runRace(11, perfectT, false))
	local sMiss = select(1, runRace(11, nil, false))
	check(sPerfect.live[1] > sMiss.live[1], "perfect taps beat missed taps")

	-- Prize rules over many races.
	local B = GameConfig.leagues.Bronze.B
	for seed = 1, 200 do
		local sess, result = runRace(seed, perfectT, true)
		local livesum = 0
		for _, v in sess.live do livesum += v end
		check(close(livesum, 1, 1e-12), "live chances sum to 1")
		check(sess.lanes[2].scores[2] ~= nil and sess.lanes[2].scores[2] >= 0, "dropped window scored at average")
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
	local _, r1 = runRace(42, perfectT, false)
	local _, r2 = runRace(42, perfectT, false)
	for i = 1, 8 do check(r1.order[i] == r2.order[i], "same seed gives same finish") end
end
