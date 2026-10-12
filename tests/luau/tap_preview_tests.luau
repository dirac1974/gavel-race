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
	local mashMessages, lossMessages, msgGap, messages = 0, 0, math.huge, 0
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
	local fadeBound = TP.fadeSeconds + TP.capFeet / TP.maxSpeed + TP.maxSpeed / TP.maxAccel + 0.1
	check(lockGone <= fadeBound, `(c) the residual is gone {lockGone} s after the lock (at most {fadeBound})`)
	check(messages > 0 and mashMessages == 0 and lossMessages == 0 and msgGap >= TP.messageEverySeconds - 1e-9,
		`messages: {messages}, none for a masher ({mashMessages}) or on a loss ({lossMessages}), at least {msgGap} s apart`)
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
						if row[3] then held = true end
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
end
