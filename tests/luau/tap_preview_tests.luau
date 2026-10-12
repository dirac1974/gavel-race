--!strict
-- The draw-only pre-lock preview (D-071, TapPreview; docs/reviews/aaa-2026-10-11/tapgap-plan.md).
-- (a) 200 seeded races with the layer on and off decide the same race: Trip's offsets, lanes and
--     targets every tick, the live chances every tick and at each close, tau, the order, the prizes
--     and the sent lanes. (b) Shuffling the secret luck leaves every drawn offset before the lock
--     unchanged, and TapPreview never reads luck. (c) The layer's limits hold through every close and
--     the lock. (d) The Rookie Mile switch rider gains ground within 2 s and 5 s where the field leaves
--     room; a rider at the field's average and a masher don't move up; a masher never gets the
--     message. (e) Steering off: the order on screen at the last tap is the result. (f) Trust: the
--     horse drawn 1st at the lock finishes 4th or worse at most 3 points more often. (g) step
--     allocates nothing. tap_preview_report.luau runs the overlap report's 3,840 races.
local fs = require("@lune/fs")
local GameConfig = require("../../game/src/shared/GameConfig")
local TapPreview = require("../../game/src/shared/TapPreview")
local PacePreview = require("../../game/src/shared/PacePreview")
local RaceSession = require("../../game/src/shared/RaceSession")
local RaceMath = require("../../src/RaceMath")
local ThemePack = require("../../game/src/shared/ThemePack")
local BurstMeter = require("../../game/src/shared/BurstMeter")
local PaceMeter = require("../../game/src/shared/PaceMeter")
local RaceShape = require("../../game/src/shared/RaceShape")
local TrackLayout = require("../../game/src/shared/TrackLayout")
local Trip = require("../../game/src/shared/Trip")
local simulate = require("./race_overlap")

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
	local TP = GameConfig.tapPreview
	local STEER = GameConfig.steering
	check(TP.enabled == true and TP.capFeet == 12 and TP.maxSpeed == 10 and TP.maxAccel == 20 and TP.laneGapFeet == 10
		and TP.fadeSeconds == 1 and TP.messageFeet == 8 and TP.messageEverySeconds == 4,
		"tapPreview: 12 ft cap, 10 ft/s, 20 ft/s^2, 10 ft lane gap, 1 s fade, message every 4 s on 8 ft")
	check(TP.maxSpeed <= GameConfig.raceView.maxGapFeetPerSecond and TP.laneGapFeet == STEER.holdGap
		and TP.pullPerSecond <= STEER.holdPullPerSecond and TP.joinClearFeet == STEER.clearFeet and TP.hardGapFeet > 6,
		"tapPreview's limits are the race view's and Trip's own (and the hard gap stays clear of a 6 ft overlap)")

	-- Synthetic: off, and on with no preview, the drawn offsets are Trip's exactly.
	do
		local n = 8
		local rng = makeRng(99)
		local base, x, tgt = table.create(n, 0), table.create(n, 0), table.create(n, 0)
		for i = 1, n do x[i], tgt[i] = 1 + (i - 1) % 3, 1 + (i - 1) % 3 end
		local offCfg = table.clone(TP)
		offCfg.enabled = false
		local layerOff = TapPreview.new(n, offCfg, 320, 8, STEER.laneBand)
		local layerOn = TapPreview.new(n, TP, 320, 8, STEER.laneBand)
		local exact = true
		for k = 1, 400 do
			for i = 1, n do base[i] = 30 * math.sin(k / 40 + i) + 10 * rng:NextNumber() - 10 * i end
			local a = TapPreview.step(layerOff, base, x, tgt, k / 10, false)
			local b = TapPreview.step(layerOn, base, x, tgt, k / 10, false)
			for i = 1, n do
				if a[i] ~= base[i] or b[i] ~= base[i] then exact = false end
			end
		end
		check(exact, "with the layer off, or on with no preview, the drawn offsets are Trip's exactly")
		check(TapPreview.message(layerOff, 1, 50) == nil and TapPreview.message(layerOn, 1, 50) == nil, "no preview, no message")
	end

	-- (a), (c), (f): 200 races (25 per course and distance), layer on and off from the same seed.
	local profiles = { "perfect", "average", "masher", "streaky" }
	local races, same, sameOrder = 0, 0, 0
	local overlaps, jerks, own, orderBad, residual, freeSpeed, freeAccel, backMax, lockGone = 0, 0, 0, 0, 0, 0, 0, 0, 0
	local mashMessages, lossMessages, msgGap, messages, otherKeys = 0, 0, math.huge, 0, 0
	local trust = { on = { first = 0, fourth = 0 }, off = { first = 0, fourth = 0 } }
	for _, course in { "dirt", "turf" } do
		for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
			for r = 1, 25 do
				local seed = 4001 + 37 * r
				local on = simulate(course, distance, seed, nil, { d057 = true, taps = profiles, tapPreview = true, digest = true, nudgeFallCap = true })
				local off = simulate(course, distance, seed, nil, { d057 = true, taps = profiles, digest = true, nudgeFallCap = true })
				races += 1
				if on.digest ~= nil and on.digest == off.digest then same += 1 end
				local ordered = true
				for p = 1, #on.result do
					if on.result[p] ~= off.result[p] then ordered = false end
				end
				if ordered then sameOrder += 1 end
				local s = on.tp :: any
				overlaps += on.before + on.after
				jerks += on.jerks + on.jerksBefore
				own += s.ownOverlaps
				if not on.orderOk or not on.crossOrderOk then orderBad += 1 end
				residual = math.max(residual, s.residualMax)
				freeSpeed = math.max(freeSpeed, s.freeSpeedMax)
				freeAccel = math.max(freeAccel, s.freeAccelMax)
				backMax = math.max(backMax, s.drawnBackMax)
				lockGone = math.max(lockGone, s.lockResidualSeconds)
				mashMessages += s.messages.masher or 0
				lossMessages += s.messageLoss
				msgGap = math.min(msgGap, s.messageGapMin)
				for _, v in s.messages do messages += v end
				for key in s.messageKeys do if key ~= "up" then otherKeys += 1 end end
				for mode, st in { on = s, off = off.tp :: any } do
					if st.firstDrawn > 0 then
						trust[mode].first += 1
						if st.firstDrawnPlace >= 4 then trust[mode].fourth += 1 end
					end
				end
			end
		end
	end
	check(races == 200 and same == 200, `(a) on and off decide the same race (Trip every tick, live, tau, order, prizes, sent lanes): {same}/{races}`)
	check(sameOrder == 200, `(a) the same finish order: {sameOrder}/{races}`)
	check(overlaps == 0 and own == 0, `(c) no horse drawn through another with the layer on: shared {overlaps} frames, own screens with the tap nudge {own}`)
	check(jerks == 0 and backMax <= TP.pullPerSecond + 1e-6, `(c) no horse drawn falling back faster than 20 ft/s ({jerks} frames; fastest {backMax} ft/s)`)
	check(orderBad == 0, `(c) the order across the line is still the result ({orderBad} races off)`)
	check(residual <= TP.capFeet + 1e-9, `(c) the drawn lead over Trip stays within capFeet ({residual})`)
	-- (+0.25 ft/s^2: the step that settles a residual exactly on its goal moves it under 1e-3 ft)
	check(freeSpeed <= TP.maxSpeed + 1e-6 and freeAccel <= TP.maxAccel + 0.25,
		`(c) away from lane room the residual keeps maxSpeed and maxAccel ({freeSpeed} ft/s, {freeAccel} ft/s^2)`)
	-- After the lock: held for fadeSeconds while the shown offsets catch up, then eased out at the limits.
	local fadeBound = TP.fadeSeconds + TP.capFeet / TP.pullBackFeetPerSecond + TP.pullBackFeetPerSecond / TP.maxAccel + 0.1
	check(lockGone <= fadeBound, `(c) the residual is gone {lockGone} s after the lock (at most {fadeBound})`)
	check(messages > 0 and mashMessages == 0 and lossMessages == 0 and msgGap >= TP.messageEverySeconds - 1e-9,
		`messages: {messages}, none for a masher ({mashMessages}) or on a loss ({lossMessages}), at least {msgGap} s apart`)
	check(otherKeys == 0, `messages: every one is "up", even drawn 1st ({otherKeys} others)`)
	local function pct(t: any): number return 100 * t.fourth / math.max(t.first, 1) end
	check(pct(trust.on) - pct(trust.off) <= 3, string.format("(f) drawn 1st at the lock, finished 4th or worse: on %.1f%%, off %.1f%%",
		pct(trust.on), pct(trust.off)))

	-- (b) A different secret luck leaves every drawn offset before the lock as it was.
	do
		local equal, races2 = true, 0
		for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
			for r = 1, 3 do
				local seed = 6101 + 13 * r
				local a = simulate("dirt", distance, seed, nil, { d057 = true, taps = profiles, tapPreview = true, permuteLuck = 11 })
				local b = simulate("dirt", distance, seed, nil, { d057 = true, taps = profiles, tapPreview = true, permuteLuck = 977 })
				races2 += 1
				local da, db = (a.tp :: any).drawnBeforeLock, (b.tp :: any).drawnBeforeLock
				if #da ~= #db or #da == 0 then equal = false end
				for k = 1, math.min(#da, #db) do
					for i = 1, #da[k] do
						if da[k][i] ~= db[k][i] then equal = false end
					end
				end
			end
		end
		check(equal, `(b) shuffled luck: every drawn offset before the lock is the same ({races2} race pairs)`)
		local src = fs.readFile("game/src/shared/TapPreview.luau")
		local code = string.gsub(src, "%-%-[^\n]*", "")
		check(not string.find(code, "luck", 1, true), "(b) TapPreview's code never mentions luck")
	end

	-- (d) Rookie Mile, bots tapping 60, equal horses: a rider at 60 who taps every pass Perfect from
	-- 15 s gains 4 ft within 2 s of the 3rd Perfect and 8 ft within 5 s where the field leaves room
	-- (the layer never draws a horse through the one ahead in its lane); at 60 throughout or mashing
	-- it never moves up more than 2 ft; a masher never sees the message.
	do
		local cfg = table.clone(GameConfig)
		cfg.botPaceMean, cfg.botPaceSd = 60, 0
		cfg.steering = Trip.d057Config(GameConfig.steering)
		local free, ok2, ok5, boxed, all = 0, 0, 0, 0, 0
		local min2, min5 = math.huge, math.huge
		local avgMax, mashMax, mashMsg = -math.huge, -math.huge, 0
		for _, course in { "dirt", "turf" } do
			for seed = 1, 15 do
				local s = simulate(course, "Mile", seed * 101 + 7, cfg,
					{ league = "Rookie", equal = true, taps = { "switch" }, styles = { "still" }, tapPreview = true })
				local tp = s.tp :: any
				local k, t3 = 0, 0
				for _, t in tp.taps.rider1 do
					if t >= 15 then
						k += 1
						if k == 3 then
							t3 = t
							break
						end
					end
				end
				local g2, g5, held = -math.huge, -math.huge, false
				for _, row in tp.series do
					if row[1] > t3 and row[1] <= t3 + 5 + 1e-9 then
						g5 = math.max(g5, row[2])
						if row[1] <= t3 + 2 + 1e-9 then g2 = math.max(g2, row[2]) end
						if row[3] >= 1 then held = true end -- (TapPreview.held: lane room held it back 1 ft or more)
					end
				end
				all += 1
				if held then
					boxed += 1
				else
					free += 1
					if g2 >= 4 then ok2 += 1 end
					if g5 >= 8 then ok5 += 1 end
					min2, min5 = math.min(min2, g2), math.min(min5, g5)
				end
				local avg = simulate(course, "Mile", seed * 101 + 7, cfg,
					{ league = "Rookie", equal = true, taps = { "fixed60" }, styles = { "still" }, tapPreview = true })
				avgMax = math.max(avgMax, (avg.tp :: any).gainMax.fixed60)
				local mash = simulate(course, "Mile", seed * 101 + 7, cfg,
					{ league = "Rookie", equal = true, taps = { "masher" }, styles = { "still" }, tapPreview = true })
				mashMax = math.max(mashMax, (mash.tp :: any).gainMax.masher)
				mashMsg += (mash.tp :: any).messages.masher or 0
			end
		end
		check(free >= 5 and ok2 == free and ok5 == free, string.format(
			"(d) with room, the switch rider gains >= 4 ft within 2 s (%d/%d, least %.2f) and >= 8 ft within 5 s (%d/%d, least %.2f); boxed in %d/%d",
			ok2, free, min2, ok5, free, min5, boxed, all))
		check(avgMax <= 2 and mashMax <= 2 and mashMsg == 0, string.format(
			"(d) a rider at 60 moves up at most %.2f ft, a masher %.2f ft (both <= 2), and a masher never sees the message (%d)", avgMax, mashMax, mashMsg))
	end

	-- Pull-back: a steady rider (every pass Perfect, or every pass 60) is never drawn falling back more
	-- than 2 ft beyond Trip's own fall in the 3 s after a checkpoint closes or the lock, unless lane
	-- room moved it (a horse cutting in).
	do
		local cfg = table.clone(GameConfig)
		cfg.steering = Trip.d057Config(GameConfig.steering)
		local worst, worstKey = 0, ""
		for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
			for r = 1, 4 do
				local s = simulate("turf", distance, 7301 + 29 * r, cfg, { taps = { "perfect", "fixed60" }, tapPreview = true })
				for key, v in (s.tp :: any).extraDrop do
					if not string.find(key, "(room)", 1, true) and v > worst then worst, worstKey = v, key end
				end
			end
		end
		check(worst <= 2, string.format("steady riders pulled back at most %.2f ft beyond Trip at a close or the lock (%s)", worst, worstKey))
	end

	-- (e) Steering off: the shown chances preview at every pass end (PacePreview.beforeLock, the
	-- stretch drive's own), so at the last tap the order on screen (luck blended in fully) is the result.
	do
		check(PacePreview.beforeLock(TP, false, 1, 0, false) and not PacePreview.beforeLock(TP, true, 1, 0, false)
			and not PacePreview.beforeLock(TP, false, 4, 3, true) and not PacePreview.beforeLock(TP, false, 2, 0, false),
			"beforeLock: steering off only, the open checkpoint only, never the stretch drive")
		local offCfg = table.clone(TP)
		offCfg.enabled = false
		check(not PacePreview.beforeLock(offCfg, false, 1, 0, false), "beforeLock: off with the layer")
		local matched, total = 0, 0
		for _, distance in { "Sprint", "Mile", "Classic" } do
			for r = 1, 10 do
				local rng = makeRng(8100 + 61 * r)
				local tapRng = makeRng(17 * r + 3)
				local cfg = GameConfig
				local humans = {
					{ id = "a", name = "A", rating = 50, isBot = false },
					{ id = "b", name = "B", rating = 50, isBot = false },
				}
				local deps = { RaceMath = RaceMath, BurstMeter = BurstMeter, PaceMeter = PaceMeter, RaceShape = RaceShape }
				local lanes = RaceSession.fillWithBots(humans, cfg.lanes, cfg, ThemePack, rng)
				local session = RaceSession.new({ deps = deps, config = cfg, leagueName = "Silver", lanes = lanes, rng = rng })
				local league = cfg.leagues.Silver
				local track = TrackLayout.courses.dirt
				local plan = TrackLayout.plan(track, TrackLayout.distances[distance])
				local speed = cfg.raceSpeedStudsPerSecond
				local tFinish = plan.lengths[1] / speed
				local tTop = tFinish - track.finishFromTop / speed
				local burstOpen = tTop + cfg.burstAfterTurnSeconds
				local burstClose = burstOpen + league.windowSeconds
				local preEnd = burstOpen - cfg.burstLeadSeconds
				local postStart = burstClose + cfg.stretchGapSeconds
				local postEnd = tFinish - cfg.finishMarginSeconds
				local mid = preEnd / 2
				local longest = league.sweepSeconds / 2 * (1 + cfg.pace.speedDrift)
				session:paceSchedule({ { 0, preEnd - longest }, { postStart, postEnd - postStart - longest } },
					{ { 0, mid }, { mid, preEnd }, { postStart, postEnd } })
				session:assignPosts(RaceSession.postOrder(cfg, #session.lanes, rng))
				local taps: { [string]: { number } } = { a = {}, b = {} }
				for k, p in session.passes do
					table.insert(taps.a, PaceMeter.idealTime(p) + 0.05 * (p.t1 - p.t0) * tapRng:NextNumber())
					if math.floor((k - 1) / 5) % 2 == 0 then table.insert(taps.b, PaceMeter.idealTime(p)) end
				end
				local closes = { mid + 0.35, preEnd + 0.35, burstClose + 0.35, postEnd + 0.35 }
				local shown = table.clone(session.live)
				local events = {}
				for _, p in session.passes do table.insert(events, { p.t1, "pass" }) end
				for seg, t in closes do table.insert(events, { t, "close", seg }) end
				table.sort(events, function(x: any, y: any): boolean return x[1] < y[1] end)
				local atLastTap = nil
				for _, ev in events do
					if atLastTap == nil and ev[1] > postEnd then atLastTap = table.clone(shown) end
					local open = session.closed + 1
					if ev[2] == "pass" and open <= #cfg.segments and cfg.segments[open] == "pace" then
						local stretch = open > 1 and cfg.segments[open - 1] == "burst"
						if stretch or PacePreview.beforeLock(TP, false, open, session.closed, stretch) then
							local done = {}
							for _, q in session:pacePasses(open) do
								if q.t1 <= ev[1] + 1e-9 then table.insert(done, q) end
							end
							if #done > 0 then
								local partial = {}
								for i, l in session.lanes do
									if not l.isBot then partial[i] = (PaceMeter.score(done, taps[l.id], cfg.pace.bounceSeconds)) end
								end
								shown = session:previewLive(open, partial)
							end
						end
					elseif ev[2] == "close" then
						for _, l in session.lanes do
							if not l.isBot then
								if cfg.segments[ev[3]] == "pace" then
									session:scorePace(l.id, ev[3], taps[l.id])
								else
									l.scores[ev[3]] = 70
								end
							end
						end
						shown = session:closeSegment(ev[3])
					end
				end
				local screen = session:displayOffsets(atLastTap or shown, 1, cfg.raceShape)
				local drawnOrder = table.create(#screen)
				for i = 1, #screen do drawnOrder[i] = i end
				table.sort(drawnOrder, function(x: number, y: number): boolean
					if screen[x] ~= screen[y] then return screen[x] > screen[y] end
					return x < y
				end)
				local result = session:finish().order
				local ok = true
				for p = 1, #result do
					if drawnOrder[p] ~= result[p] then ok = false end
				end
				total += 1
				if ok then matched += 1 end
			end
		end
		check(matched == total, `(e) steering off: the order on screen at the last tap is the result ({matched}/{total})`)
	end

	-- (g) step allocates nothing: no table constructor, table library call, closure or string
	-- building in its body; and running it a few thousand times leaves the heap where it was.
	do
		local src = fs.readFile("game/src/shared/TapPreview.luau")
		local from = string.find(src, "function TapPreview.step", 1, true) :: number
		local bodyStart = (string.find(src, "\n", from, true) :: number) + 1
		local bodyEnd = string.find(src, "\nend\r?\n", bodyStart) :: number
		local body = string.gsub(string.sub(src, bodyStart, bodyEnd), "%-%-[^\n]*", "")
		local found = string.find(body, "{", 1, true) or string.find(body, "table.", 1, true)
			or string.find(body, "function", 1, true) or string.find(body, "..", 1, true) or string.find(body, "string.", 1, true)
		check(#body > 500 and not found, "(g) TapPreview.step's body builds no table, closure or string")
		local n = 8
		local state = TapPreview.new(n, TP, 320, 8, STEER.laneBand)
		local base, x, tgt = table.create(n, 0), table.create(n, 0), table.create(n, 0)
		local pv, live = table.create(n, 0.125), table.create(n, 0.125)
		for i = 1, n do
			x[i], tgt[i] = 1 + (i - 1) % 3, 1 + (i - 1) % 3
			pv[i] = 0.125 + 0.01 * (i - 4.5)
		end
		TapPreview.setPreview(state, live, pv, 6)
		for k = 1, 50 do TapPreview.step(state, base, x, tgt, k / 10, false) end
		local before = collectgarbage("count")
		for k = 51, 5050 do
			for i = 1, n do base[i] = 10 * math.sin(k / 30 + i) end
			TapPreview.step(state, base, x, tgt, k / 10, k > 3000)
		end
		local grown = collectgarbage("count") - before
		check(grown < 1, `(g) 5,000 steps grow the heap by {grown} KB (< 1)`)
	end

	-- (D-071 rulings) TapPreview.held: how far lane room keeps a rider behind its goal. A rider with
	-- 12 ft of taps to show, sitting 10 ft behind a horse in its lane, is held by about 12 ft; with the
	-- lane clear, or after the lock, held is 0. The cue: pressure at minFeet for minSeconds, the chip
	-- at chipMinFeet for chipMinSeconds ("gap" with a side free, at most every chipEverySeconds;
	-- "taps" once a race for Smart Steer), never after the lock; stepCue allocates nothing.
	do
		local n = 2
		local function run(sameLane: boolean, lockAt: number): (number, number)
			local st = TapPreview.new(n, TP, 320, 8, STEER.laneBand)
			TapPreview.setRider(st, 1, false)
			TapPreview.setRider(st, 2, true)
			local base = { 0, -10 }
			local x = { 2, if sameLane then 2 else 4 }
			TapPreview.setPreview(st, { 0.5, 0.5 }, { 0.47, 0.53 }, 40) -- lane 2's taps: 320 * 1.2 * 0.03 * 40/42 = 11 ft
			local heldBefore, heldAfter = 0, 0
			for k = 1, 60 do
				local t = 10 + k / 10
				TapPreview.step(st, base, x, x, t, t >= lockAt)
				if t < lockAt then heldBefore = TapPreview.held(st, 2) else heldAfter = math.max(heldAfter, TapPreview.held(st, 2)) end
			end
			return heldBefore, heldAfter
		end
		local boxedHeld = run(true, math.huge)
		local clearHeld = run(false, math.huge)
		local _, afterLock = run(true, 13)
		check(boxedHeld > 10 and boxedHeld < 12, `held: boxed behind a horse in its lane, held {boxedHeld} ft (about its 11 ft goal)`)
		check(clearHeld == 0 and afterLock == 0, `held: 0 with the lane clear ({clearHeld}) and after the lock ({afterLock})`)
		check(TapPreview.held(TapPreview.new(3, TP, 320, 8, STEER.laneBand), 2) == 0, "held: 0 before any step")

		local HC = TP.heldCue
		check(HC.minFeet == 4 and HC.minSeconds == 1 and HC.chipMinFeet == 6 and HC.chipMinSeconds == 1.5 and HC.chipEverySeconds == 10,
			"heldCue: 4 ft for 1 s, chip 6 ft for 1.5 s, at most every 10 s")
		local cue = TapPreview.newCue()
		local firstPressure, gapChips, chipTimes = nil, 0, {}
		for k = 1, 300 do -- 5 s held 7 ft, then 1 s clear, then held again; a side has room; buttons
			local t = k / 60
			local held = if t > 5 and t <= 6 then 0 else 7
			local pressure, chip = TapPreview.stepCue(cue, TP, held, 1 / 60, t, false, false, true)
			if pressure and not firstPressure then firstPressure = t end
			if chip == "gap" then
				gapChips += 1
				table.insert(chipTimes, t)
			end
		end
		check(firstPressure ~= nil and math.abs((firstPressure :: number) - 1) < 0.05, `cue: pressure after 1 s held ({firstPressure})`)
		check(gapChips == 1 and math.abs(chipTimes[1] - 1.5) < 0.05, `cue: "Find a gap!" once, after 1.5 s at 6 ft, not again within 10 s ({gapChips})`)
		local quiet = TapPreview.newCue()
		local small, noRoom, locked = false, false, false
		for k = 1, 300 do
			local t = k / 60
			local p1, c1 = TapPreview.stepCue(quiet, TP, 3.9, 1 / 60, t, false, false, true)
			if p1 or c1 then small = true end
		end
		local blocked = TapPreview.newCue()
		for k = 1, 300 do
			local _, c2 = TapPreview.stepCue(blocked, TP, 9, 1 / 60, k / 60, false, false, false)
			if c2 then noRoom = true end
		end
		local after = TapPreview.newCue()
		for k = 1, 300 do
			local p3, c3 = TapPreview.stepCue(after, TP, 9, 1 / 60, k / 60, true, false, true)
			if p3 or c3 then locked = true end
		end
		check(not small and not noRoom and not locked, "cue: nothing under 4 ft, no gap chip without a side free, nothing after the lock")
		local smart = TapPreview.newCue()
		local tapsChips, gapForSmart = 0, 0
		for k = 1, 1800 do
			local _, c = TapPreview.stepCue(smart, TP, 9, 1 / 60, k / 60, false, true, true)
			if c == "taps" then tapsChips += 1 end
			if c == "gap" then gapForSmart += 1 end
		end
		check(gapForSmart == 0, `cue: riders without buttons never get the gap chip ({gapForSmart})`)
		check(tapsChips == 1, `cue: "Your taps still count!" once a race for riders without buttons ({tapsChips})`)

		-- (review N6) heldSendDue: rounded to 0.1 ft; a 1 ft change at least 0.5 s apart; a resend each
		-- second while held; dropping to 0 or crossing 4 or 6 ft goes at once; allocates nothing.
		local hs = TapPreview.newHeldSend()
		local function due(held: number, t: number): boolean return TapPreview.heldSendDue(hs, held, t, TP) end
		local okSend = not due(0, 0) and not due(0.04, 0.1)                        -- 0 (rounded) is never news
		okSend = okSend and due(2.04, 0.2) and hs.last == 2 and hs.lastT == 0.2     -- first value, rounded
		okSend = okSend and not due(3.5, 0.4)                                       -- 1 ft+ but under 0.5 s
		okSend = okSend and due(3.5, 0.7) and hs.last == 3.5                        -- 1 ft+, 0.5 s on
		okSend = okSend and due(4.1, 0.75) and hs.last == 4.1                       -- crosses 4 ft: at once
		okSend = okSend and not due(4.6, 1.3) and not due(4.6, 1.74)                -- under 1 ft, under 1 s
		okSend = okSend and due(4.6, 1.75)                                          -- resend after 1 s
		okSend = okSend and due(6.0, 1.8) and due(5.9, 1.85)                        -- 6 ft crossed up, then down
		okSend = okSend and due(0, 1.86) and hs.last == 0                           -- drop to 0: at once
		okSend = okSend and not due(0, 5)                                           -- no resend at 0
		check(okSend, "heldSendDue: rounding, 1 ft at 0.5 s, 1 s resend, 0 and the 4 and 6 ft crossings at once")
		local srcSend = fs.readFile("game/src/shared/TapPreview.luau")
		local fromSend = string.find(srcSend, "function TapPreview.heldSendDue", 1, true) :: number
		local startSend = (string.find(srcSend, "\n", fromSend, true) :: number) + 1
		local endSend = string.find(srcSend, "\nend\r?\n", startSend) :: number
		local bodySend = string.gsub(string.sub(srcSend, startSend, endSend), "%-%-[^\n]*", "")
		check(#bodySend > 200 and not string.find(bodySend, "{", 1, true) and not string.find(bodySend, "table.", 1, true),
			"heldSendDue allocates nothing")

		-- (systems review) The message is only ever "up", and no key or words say away, lead or win.
		local words = true
		for key, text in TapPreview.MESSAGES do
			for _, w in { "away", "lead", "win" } do
				if string.find(string.lower(key .. " " .. text), w, 1, true) then words = false end
			end
		end
		check(words and TapPreview.MESSAGES.up ~= nil, "messages: no key or words with away, lead or win")
		local src = fs.readFile("game/src/shared/TapPreview.luau")
		local from = string.find(src, "function TapPreview.stepCue", 1, true) :: number
		local bodyStart = (string.find(src, "\n", from, true) :: number) + 1
		local bodyEnd = string.find(src, "\nend\r?\n", bodyStart) :: number
		local body = string.gsub(string.sub(src, bodyStart, bodyEnd), "%-%-[^\n]*", "")
		local found = string.find(body, "{", 1, true) or string.find(body, "table.", 1, true) or string.find(body, "function", 1, true)
		check(#body > 300 and not found, "stepCue allocates nothing")
	end
end
