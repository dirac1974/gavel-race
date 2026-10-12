--!strict
-- Tap preview report (D-071): whole races with D-057 in full and four riders tapping the slider
-- (perfect, average, masher, streaky), each with its own screen's 5 ft tap nudge drawn on top,
-- run twice from the same seed: with the draw-only preview layer (TapPreview) and without it.
-- Run: lune run tests/luau/tap_preview_report [races per course and distance, default 480]
-- Prints one line per gate (D-071 rulings, docs/reviews/aaa-2026-10-11/tapgap-rulings.md) and exits
-- 1 unless every gate passes:
--   shared-screen overlaps 0; shared jerks (falling back faster than 20 ft/s) in at most 3 races and
--   own-screen overlaps (tap nudge on top) in at most 1 race per 3,840 (scaled down, rounded down);
--   own-screen jerks no more than 5% over the layer off (the D-066 nudge's own); the order across the
--   line no worse than with the layer off; no residual over capFeet; no message on a loss or for a
--   masher; a Perfect rider's pull-back beyond Trip at a close or the lock (no lane room involved)
--   99th percentile <= 4 ft and worst <= 8 ft, given back no faster than pullBackFeetPerSecond away
--   from lane room; message keys and words never "away", "lead" or "win"; the residual gone after the lock in median <= 1.5 s,
--   95% <= 2.5 s, worst <= 3.0 s; the trust row (drawn 1st at the lock, finished 4th or worse) up at
--   most 3 points; and in a realistic Rookie Mile run (bots at the anchor ± 6, scores sd 15, riders
--   on equal horses; ruling 2): the boxed share (of the time a rider's taps have heldCue.minFeet to
--   show, how much lane room holds back by that much) <= 55%, the pressure cue in every rider-race
--   held >= 4 ft for 1 s, the gap chip (buttons, a side free) in >= 80% of those held >= 6 ft for
--   1.5 s, no chip for a masher and no chip text with "boxed".
-- Args: [races per course and distance, default 480] [boxed=N Rookie Mile races per course, default
-- 30] [nudgeAsIs].
local process = require("@lune/process")
local GameConfig = require("../../game/src/shared/GameConfig")
local simulate = require("./race_overlap")
local TapPreview = require("../../game/src/shared/TapPreview")

local races = 480
local boxedRaces = 30
local nudgeFallCap = true -- the own screen's nudge as RaceView draws it with D-071 (RaceFx.stepNudge's baseFall); "nudgeAsIs" = before
for _, arg in process.args do
	if tonumber(arg) then races = tonumber(arg) :: number end
	if arg == "nudgeAsIs" then nudgeFallCap = false end
	local b = string.match(arg, "^boxed=(%d+)$")
	if b then boxedRaces = tonumber(b) :: number end
end
local profiles = { "perfect", "average", "masher", "streaky" }
local TP = GameConfig.tapPreview

local agg: any = { races = 0, overlaps = 0, own = 0, jerks = 0, ownJerks = 0, orderBad = 0, crossBad = 0, backMax = 0,
	residualMax = 0, speedMax = 0, accelMax = 0, lockSeconds = 0, residualAtLock = 0, messageLoss = 0, hardClamps = 0,
	drawnBack = 0, minGap = math.huge, accelSide = 0, offOverlaps = 0, offJerks = 0 }
local trust = { on = { first = 0, fourth = 0 }, off = { first = 0, fourth = 0 } }
local gainMax, gainMin, messages, extraDrop = {}, {}, {}, {}
local lockTimes, dropsByKey: { [string]: { number } } = {}, {}
local function quantile(list: { number }, q: number): number
	if #list == 0 then return 0 end
	local c = table.clone(list)
	table.sort(c)
	return c[math.clamp(math.ceil(q * #c), 1, #c)]
end
for _, course in { "dirt", "turf" } do
	for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
		for r = 1, races do
			local seed = r * 7919 + 3
			local on = simulate(course, distance, seed, nil, { d057 = true, taps = profiles, tapPreview = true, nudgeFallCap = nudgeFallCap })
			local off = simulate(course, distance, seed, nil, { d057 = true, taps = profiles, nudgeFallCap = nudgeFallCap })
			agg.races += 1
			agg.overlaps += on.before + on.after
			if on.jerks + on.jerksBefore > 0 then agg.jerkRaces = (agg.jerkRaces or 0) + 1 end
			if (on.tp :: any).ownOverlaps > 0 then agg.ownRaces = (agg.ownRaces or 0) + 1 end
			agg.offOverlaps += off.before + off.after
			agg.jerks += on.jerks + on.jerksBefore
			agg.offJerks += off.jerks + off.jerksBefore
			agg.offOwn = (agg.offOwn or 0) + (off.tp :: any).ownOverlaps
			agg.offOwnJerks = (agg.offOwnJerks or 0) + (off.tp :: any).ownJerks
			agg.backMax = math.max(agg.backMax, on.backBefore, on.backAfter)
			if not on.orderOk then agg.orderBad += 1 end
			if not on.crossOrderOk then agg.crossBad += 1 end
			if not off.crossOrderOk then agg.offCrossBad = (agg.offCrossBad or 0) + 1 end
			if not off.orderOk then agg.offOrderBad = (agg.offOrderBad or 0) + 1 end
			for _, rv in on.reversals do agg.minGap = math.min(agg.minGap, rv.minGap) end
			agg.accelSide = math.max(agg.accelSide, on.accelBefore, on.accelAfter)
			local s = on.tp :: any
			agg.own += s.ownOverlaps
			agg.ownJerks += s.ownJerks
			agg.residualMax = math.max(agg.residualMax, s.residualMax)
			agg.speedMax = math.max(agg.speedMax, s.residualSpeedMax)
			agg.accelMax = math.max(agg.accelMax, s.residualAccelMax)
			agg.drawnBack = math.max(agg.drawnBack, s.drawnBackMax)
			agg.lockSeconds = math.max(agg.lockSeconds, s.lockResidualSeconds)
			agg.residualAtLock = math.max(agg.residualAtLock, s.residualAtLock)
			agg.messageLoss += s.messageLoss
			agg.hardClamps += s.hardClamps
			agg.pullBackSpeed = math.max(agg.pullBackSpeed or 0, s.pullBackSpeed)
			agg.keys = agg.keys or {}
			for key in s.messageKeys do agg.keys[key] = true end
			agg.freeSpeed = math.max(agg.freeSpeed or 0, s.freeSpeedMax)
			agg.freeAccel = math.max(agg.freeAccel or 0, s.freeAccelMax)
			agg.msgGap = math.min(agg.msgGap or math.huge, s.messageGapMin)
			table.insert(lockTimes, s.lockResidualSeconds)
			for key, v in s.extraDrop do table.insert(dropsByKey[key] or (function() dropsByKey[key] = {} return dropsByKey[key] end)(), v) end
			for p, v in s.gainMax do gainMax[p] = math.max(gainMax[p] or -math.huge, v) end
			for p, v in s.gainMin do gainMin[p] = math.min(gainMin[p] or math.huge, v) end
			for p, v in s.messages do messages[p] = (messages[p] or 0) + v end
			for key, v in s.extraDrop do extraDrop[key] = math.max(extraDrop[key] or 0, v) end
			for mode, st in { on = s, off = off.tp :: any } do
				if st.firstDrawn > 0 then
					trust[mode].first += 1
					if st.firstDrawnPlace >= 4 then trust[mode].fourth += 1 end
				end
			end
		end
	end
end
local function pct(t: any): number return 100 * t.fourth / math.max(t.first, 1) end
print(string.format("races: %d (D-057 in full; riders perfect, average, masher, streaky; layer on vs off from the same seeds)", agg.races))
print(string.format("overlaps: shared screen %d frames (layer off %d), riders' own screens with the tap nudge %d frames", agg.overlaps, agg.offOverlaps, agg.own))
print(string.format("jerks (drawn falling back faster than 20 ft/s): shared %d frames (layer off %d), own screens %d (layer off %d); fastest fall back drawn %.1f ft/s",
	agg.jerks, agg.offJerks, agg.ownJerks, agg.offOwnJerks or 0, agg.backMax))
print(string.format("own screens with the layer off: %d overlapping frames", agg.offOwn or 0))
print(string.format("order across the line differs from the result: last frame %d, crossing %d (layer off: %d, %d)",
	agg.orderBad, agg.crossBad, agg.offOrderBad or 0, agg.offCrossBad or 0))
print(string.format("rider reversals: shortest gap %.1f s; drawn sideways acceleration %.1f ft/s^2", agg.minGap, agg.accelSide))
print(string.format("layer residual (drawn - Trip): at most %.2f ft (cap %d); its speed at most %.2f ft/s, its acceleration at most %.1f ft/s^2 (10 Hz samples); server fall back at most %.1f ft/s",
	agg.residualMax, TP.capFeet, agg.speedMax, agg.accelMax, agg.drawnBack))
print(string.format("away from lane room the residual moves at most %.2f ft/s (maxSpeed %d) and changes speed at most %.1f ft/s^2 (maxAccel %d)",
	agg.freeSpeed or 0, TP.maxSpeed, agg.freeAccel or 0, TP.maxAccel))
print(string.format("lane room moved %d sample-lanes in all; residual at the lock at most %.2f ft, gone after it within %.2f s (median), %.2f s (95%%), %.2f s (most)",
	agg.hardClamps, agg.residualAtLock, quantile(lockTimes, 0.5), quantile(lockTimes, 0.95), agg.lockSeconds))
print(string.format("messages at least %.1f s apart (messageEverySeconds %d)", agg.msgGap or math.huge, TP.messageEverySeconds))
local parts = {}
for p, v in gainMax do table.insert(parts, string.format("%s %+.2f..%+.2f ft", p, gainMin[p], v)) end
table.sort(parts)
print("riders' drawn gain over Trip before the lock (min..max): " .. table.concat(parts, "; "))
parts = {}
for _, p in profiles do table.insert(parts, string.format("%s %d", p, messages[p] or 0)) end
print(string.format("messages (Moving up! / Pulling away!): %s; on a loss %d", table.concat(parts, ", "), agg.messageLoss))
parts = {}
for key, v in extraDrop do table.insert(parts, string.format("%s %.2f", key, v)) end
table.sort(parts)
print("extra pull-back over Trip's own in the 3 s after a close or the lock, most (ft): " .. table.concat(parts, "; "))
parts = {}
for key, list in dropsByKey do
	local over = 0
	for _, v in list do if v > 2 then over += 1 end end
	table.insert(parts, string.format("%s %.2f (99%%), over 2 ft %d/%d", key, quantile(list, 0.99), over, #list))
end
table.sort(parts)
print("  by window: " .. table.concat(parts, "; "))
print(string.format("trust: drawn 1st at the lock and finished 4th or worse: layer on %.2f%% (%d/%d), off %.2f%% (%d/%d), change %+.2f points",
	pct(trust.on), trust.on.fourth, trust.on.first, pct(trust.off), trust.off.fourth, trust.off.first, pct(trust.on) - pct(trust.off)))

-- The realistic Rookie Mile run (riders on equal horses at the anchor): the boxed share and the held
-- cue (TapPreview.stepCue, run per rider as its screen would: pressure, and the chips).
local aimSamples, heldSamples = 0, 0
local cueEligible, cueFired, gapEligible, gapFired, masherChips, boxedText, chipsShown = 0, 0, 0, 0, 0, 0, 0
for _, course in { "dirt", "turf" } do
	for r = 1, boxedRaces do
		local s = simulate(course, "Mile", r * 101 + 7, nil, { d057 = true, league = "Rookie", botAnchor = true,
			riderRating = GameConfig.botRatingAnchor.Rookie, taps = profiles, tapPreview = true })
		local t = s.tp :: any
		aimSamples += t.aimSamples or 0
		heldSamples += t.heldSamples or 0
		for profile, c in t.cues do
			if c.eligible4 then
				cueEligible += 1
				if c.pressure then cueFired += 1 end
			end
			if c.eligibleGap then
				gapEligible += 1
				if c.gap then gapFired += 1 end
			end
			if profile == "masher" then masherChips += c.chips end
			for _, text in c.texts do
				chipsShown += 1
				if string.find(string.lower(text), "boxed", 1, true) then boxedText += 1 end
			end
		end
	end
end
local boxedShare = 100 * heldSamples / math.max(aimSamples, 1)

local allowed = function(per3840: number): number return math.floor(per3840 * agg.races / 3840 + 1e-9) end
local gates = {}
local function gate(name: string, ok: boolean, detail: string)
	table.insert(gates, ok)
	print(string.format("gate %-46s %s  %s", name, if ok then "PASS" else "FAIL", detail))
end
gate("shared-screen overlaps", agg.overlaps == 0, string.format("%d frames", agg.overlaps))
gate("shared jerks", (agg.jerkRaces or 0) <= allowed(3), string.format("%d races (allowed %d)", agg.jerkRaces or 0, allowed(3)))
gate("own-screen overlaps", (agg.ownRaces or 0) <= allowed(1), string.format("%d races (allowed %d)", agg.ownRaces or 0, allowed(1)))
gate("own-screen jerks vs layer off", agg.ownJerks <= (agg.offOwnJerks or 0) * 1.05 + 5,
	string.format("%d frames vs %d", agg.ownJerks, agg.offOwnJerks or 0))
gate("order across the line", agg.orderBad <= (agg.offOrderBad or 0) and agg.crossBad <= (agg.offCrossBad or 0),
	string.format("%d/%d vs layer off %d/%d", agg.orderBad, agg.crossBad, agg.offOrderBad or 0, agg.offCrossBad or 0))
gate("residual within capFeet", agg.residualMax <= TP.capFeet + 1e-6, string.format("%.2f ft", agg.residualMax))
gate("messages: none on a loss, none for a masher", agg.messageLoss == 0 and (messages.masher or 0) == 0,
	string.format("%d, %d", agg.messageLoss, messages.masher or 0))
local drops = {}
for _, key in { "perfect:close", "perfect:lock" } do for _, v in dropsByKey[key] or {} do table.insert(drops, v) end end
gate("pull-back p99 <= 4 ft, worst <= 8 ft", quantile(drops, 0.99) <= 4 and quantile(drops, 1) <= 8,
	string.format("%.2f ft, %.2f ft", quantile(drops, 0.99), quantile(drops, 1)))
gate("pull-back speed <= pullBackFeetPerSecond", (agg.pullBackSpeed or 0) <= TP.pullBackFeetPerSecond + 1e-6,
	string.format("%.2f ft/s (limit %d)", agg.pullBackSpeed or 0, TP.pullBackFeetPerSecond))
local keysOk, keyList = true, {}
for key in agg.keys or {} do
	table.insert(keyList, key)
	local text = string.lower(key .. " " .. (TapPreview.MESSAGES[key] or "?"))
	for _, word in { "away", "lead", "win" } do
		if string.find(text, word, 1, true) then keysOk = false end
	end
	if TapPreview.MESSAGES[key] == nil then keysOk = false end
end
table.sort(keyList)
gate("messages never say away/lead/win", keysOk, "keys: " .. (if #keyList > 0 then table.concat(keyList, ", ") else "none"))
gate("lock fade median/p95/worst <= 1.5/2.5/3.0 s",
	quantile(lockTimes, 0.5) <= 1.5 and quantile(lockTimes, 0.95) <= 2.5 and quantile(lockTimes, 1) <= 3.0,
	string.format("%.2f / %.2f / %.2f s", quantile(lockTimes, 0.5), quantile(lockTimes, 0.95), quantile(lockTimes, 1)))
gate("trust row up <= 3 points", pct(trust.on) - pct(trust.off) <= 3, string.format("%+.2f points", pct(trust.on) - pct(trust.off)))
-- (ruling 2: the 53% boxed share is accepted for this build; the gates hold it and check the cue)
gate("boxed share (Rookie Mile) <= 55%", boxedShare <= 55,
	string.format("%.1f%% of %d samples (%d races)", boxedShare, aimSamples, 2 * boxedRaces))
gate("pressure cue when held >= 4 ft for 1 s: 100%", cueFired == cueEligible,
	string.format("%d of %d rider-races", cueFired, cueEligible))
gate("gap chip when held >= 6 ft 1.5 s + room: >= 80%", gapFired >= 0.8 * gapEligible,
	string.format("%d of %d rider-races (%.0f%%)", gapFired, gapEligible, 100 * gapFired / math.max(gapEligible, 1)))
gate("masher chips 0, no chip says boxed", masherChips == 0 and boxedText == 0,
	string.format("%d, %d of %d chips", masherChips, boxedText, chipsShown))
for _, ok in gates do
	if not ok then
		print("FAIL")
		process.exit(1)
	end
end
print("PASS")
