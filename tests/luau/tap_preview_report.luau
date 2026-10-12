--!strict
-- Tap preview report (D-071): whole races with D-057 in full and four riders tapping the slider
-- (perfect, average, masher, streaky), each with its own screen's 5 ft tap nudge drawn on top,
-- run twice from the same seed: with the draw-only preview layer (TapPreview) and without it.
-- Run: lune run tests/luau/tap_preview_report [races per course and distance, default 480]
-- Exits 1 on an overlap on any screen, a horse drawn falling back faster than 20 ft/s (own screens:
-- more than with the layer off, whose count is the D-066 nudge's own), the order across the line
-- differing from the result, a message on a loss or for a masher, a residual over capFeet, a Perfect
-- rider pulled back beyond Trip at a close or the lock (no lane room involved) more than 3 ft at the
-- 99th percentile or 4 ft at most, or P(drawn 1st at the lock, finished 4th or worse) rising more
-- than 3 points.
local process = require("@lune/process")
local GameConfig = require("../../game/src/shared/GameConfig")
local simulate = require("./race_overlap")

local races = 480
local nudgeFallCap = true -- the own screen's nudge as RaceView draws it with D-071 (RaceFx.stepNudge's baseFall); "nudgeAsIs" = before
for _, arg in process.args do
	if tonumber(arg) then races = tonumber(arg) :: number end
	if arg == "nudgeAsIs" then nudgeFallCap = false end
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

local problems = {}
if agg.overlaps + agg.own > 0 then table.insert(problems, "overlapping horses") end
if agg.jerks > 0 then table.insert(problems, "a horse drawn falling back faster than 20 ft/s") end
-- (own screens: the tap nudge's own fall, RaceView's since D-066, is the layer-off number; the layer must not add to it)
if agg.ownJerks > (agg.offOwnJerks or 0) * 1.05 + 5 then table.insert(problems, "the layer adds own-screen jerks") end
if agg.orderBad > (agg.offOrderBad or 0) or agg.crossBad > (agg.offCrossBad or 0) then
	table.insert(problems, "the layer changes the order across the line")
end
if agg.residualMax > TP.capFeet + 1e-6 then table.insert(problems, "residual over capFeet") end
if agg.messageLoss > 0 or (messages.masher or 0) > 0 then table.insert(problems, "a message on a loss or for a masher") end
-- Pull-back (a Perfect rider, no lane room involved): the plan's 2 ft, held by the 99th percentile;
-- the rare rest (the field's own checkpoint scores arriving at a close or the lock) at most 4 ft.
for _, key in { "perfect:close", "perfect:lock" } do
	local list = dropsByKey[key] or {}
	if quantile(list, 0.99) > 3 or (extraDrop[key] or 0) > 4 then
		table.insert(problems, string.format("a Perfect rider pulled back too far (%s: 99%% %.2f ft, most %.2f ft)", key, quantile(list, 0.99), extraDrop[key] or 0))
	end
end
if pct(trust.on) - pct(trust.off) > 3 then table.insert(problems, "trust row rose more than 3 points") end
if #problems > 0 then
	print("FAIL: " .. table.concat(problems, "; "))
	process.exit(1)
end
print("PASS")
