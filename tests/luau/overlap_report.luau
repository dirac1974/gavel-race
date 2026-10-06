--!strict
-- Overlap report (D-054 S2, S3; D-057 N2, N3): how often horses overlap on screen, before the
-- far-turn lock, in the first 5 s after it, and from the lock to the line.
-- Run: lune run tests/luau/overlap_report [races] [riders=N] [manual] [predict] [latency=S] [jitter=S]
--   [ownStyle=masher] [d057 | d054]
--   The config is GameConfig's (since N3: D-057's motion and press rules, brushes off); d057 turns
--   the brushes on too (Trip.d057Config, N5's preview); d054 is the switch-back (Trip.d054Config).
--   With the eased glide (the game's, and d057) the riders are a masher, a ditherer and a casual
--   rider (riders=N takes the first N; with predict, rider 1 presses from its screen and the three
--   follow); with d054 riders=N lanes press at random (none by default).
--   manual = riders with Smart Steer off; predict = rider 1 presses from its own screen (singles,
--   doubles, mashes, In-then-Out) with `latency` each way (0.1 s by default): with the eased glide a
--   press shows the look cue and the horse is drawn where everyone sees it, with d054 its glide is
--   predicted (SteerPredict); the report then adds that screen's numbers.
--   jitter = up to S s of extra random delay on each message (in order), which the screen's playback
--   by server timestamps absorbs (Playback, N3).
--   ownStyle=masher (with predict): rider 1 mashes at random, 4 presses a second; with the eased
--   glide the report adds how often the look cue swings its body from one side to the other.
--   Every screen draws the timestamped samples played back as RaceView does.
-- With the eased glide the report adds reversals, the drawn sideways acceleration, brushes,
-- boxed-in time, the moves after the lock (late full-lane moves in the last 2 s, late half-lane
-- steps) and the reversals after the lock.
-- Exits 1 if any race overlaps on any screen, draws a horse falling back faster than 20 ft/s,
-- or finishes out of order (the drawn order at the last frame, or the order the horses cross the
-- line on the drawn screen); with the eased glide also if a rider reverses within 3 s of
-- its last reversal, any horse reverses after the lock within 3.5 s of its last reversal, late
-- full-lane moves pass 100 per 960 races (D-054 makes 59-99), or the drawn sideways acceleration
-- passes 31.7 ft/s^2. (Trip's landing tick reaches 30.4 ft/s^2, against D-057's 30; the sent
-- lanes' 0.001-lane rounding adds up to 1.2 more, 0.002 lane over a second difference: 31.6.)
local process = require("@lune/process")
local GameConfig = require("../../game/src/shared/GameConfig")
local simulate = require("./race_overlap")

local races = 120
local opts: { [string]: any } = { manual = false, predict = false }
for _, arg in process.args do
	local key, value = string.match(arg, "^(%w+)=(.+)$")
	if key then
		opts[key] = tonumber(value) or value
	elseif arg == "manual" or arg == "predict" or arg == "d057" or arg == "d054" then
		opts[arg] = true
	elseif tonumber(arg) then
		races = tonumber(arg) :: number
	end
end
local eased = not opts.d054 and (opts.d057 or GameConfig.steering.glide == "eased")
-- D-054: rider 1 presses from its screen (predict) even with no riders asked for.
if opts.predict and not eased and (opts.riders == nil or opts.riders < 1) then opts.riders = 1 end
print(string.format("config: %s; %d races per course and distance%s%s%s",
	if opts.d054 then "D-054 (the switch-back)" elseif opts.d057 then "D-057 in full (Trip.d057Config; the game's config since N5)"
		else "GameConfig (" .. GameConfig.steering.glide .. " glide, brushes " .. GameConfig.steering.brush .. ")",
	races, if opts.predict then string.format(", rider 1 on its own screen at %.2f s each way", opts.latency or 0.1) else "",
	if opts.manual then ", Smart Steer off" else "", if (opts.jitter or 0) > 0 then string.format(", jitter 0-%d ms", math.round(opts.jitter * 1000)) else ""))

local answers, halfStepRaces, jerkRaces, jerkRacesBefore, backBefore, backAfter = {}, 0, 0, 0, 0, 0
local totals = { races = 0, before = 0, first5 = 0, after = 0, frames = 0, beforeFrames = 0, first5Frames = 0, afterFrames = 0, lastTwo = 0, lastTwoFrames = 0, orderBad = 0, crossBad = 0 }
local own = { races = 0, overlapsBefore = 0, overlapsAfter = 0, framesBefore = 0, framesAfter = 0, apartMax = 0, apartAtLock = 0,
	timeouts = 0, longest = 0, presses = 0, predicted = 0, looks = 0, lookMax = 0, cueFlips = 0, cueSeconds = 0, cueExcess = 0 }
local reversals: { [string]: { count: number, seconds: number, minGap: number } } = {}
local accelBefore, accelAfter, brushes, brushRaces, boxedTicks, riderTicks = 0, 0, 0, 0, 0, 0
local brushStyles: { [string]: any }, strangerCharged = {}, 0
local after = { moves = 0, late = 0, lateRaces = 0, lateHalf = 0, reversals = 0, within = 0, minGap = math.huge }
for _, course in { "dirt", "turf" } do
	for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
		local cell = { before = 0, first5 = 0, after = 0 }
		for seed = 1, races do
			local s = simulate(course, distance, seed * 7919 + 3, nil, opts)
			totals.races += 1
			totals.frames += s.frames
			totals.beforeFrames += s.before
			totals.first5Frames += s.first5
			totals.afterFrames += s.after
			if s.before > 0 then cell.before += 1 end
			if s.first5 > 0 then cell.first5 += 1 end
			if s.after > 0 then cell.after += 1 end
			if s.lastTwo > 0 then totals.lastTwo += 1 end
			totals.lastTwoFrames += s.lastTwo
			if not s.orderOk then totals.orderBad += 1 end
			if not s.crossOrderOk then totals.crossBad += 1 end
			if s.halfSteps > 0 then halfStepRaces += 1 end
			if s.jerks > 0 then jerkRaces += 1 end
			if s.jerksBefore > 0 then jerkRacesBefore += 1 end
			backBefore = math.max(backBefore, s.backBefore)
			backAfter = math.max(backAfter, s.backAfter)
			for answer, count in s.answers do answers[answer] = (answers[answer] or 0) + count end
			for styleName, r in s.reversals do
				local a = reversals[styleName] or { count = 0, seconds = 0, minGap = math.huge }
				a.count += r.count
				a.seconds += r.seconds
				a.minGap = math.min(a.minGap, r.minGap)
				reversals[styleName] = a
			end
			accelBefore = math.max(accelBefore, s.accelBefore)
			accelAfter = math.max(accelAfter, s.accelAfter)
			brushes += s.brushes
			if s.brushes > 0 then brushRaces += 1 end
			strangerCharged += s.strangerCharged
			for styleName, b in s.brushStyles do
				local a = brushStyles[styleName] or { riders = 0, brushRaces = 0, chargedRaces = 0, brushes = 0 }
				a.riders += b.riders
				a.brushRaces += b.brushRaces
				a.chargedRaces += b.chargedRaces
				a.brushes += b.brushes
				brushStyles[styleName] = a
			end
			boxedTicks += s.boxedTicks
			riderTicks += s.riderTicks
			after.moves += s.afterMoves
			after.late += s.lateMoves
			if s.lateMoves > 0 then after.lateRaces += 1 end
			after.lateHalf += s.lateHalfSteps
			after.reversals += s.afterReversals
			after.within += s.afterReversalsWithin
			after.minGap = math.min(after.minGap, s.afterMinGap)
			local o = s.own
			if o then
				own.races += 1
				if o.overlapsBefore > 0 then own.overlapsBefore += 1 end
				if o.overlapsAfter > 0 then own.overlapsAfter += 1 end
				own.framesBefore += o.overlapsBefore
				own.framesAfter += o.overlapsAfter
				own.apartMax = math.max(own.apartMax, o.apartMax)
				own.apartAtLock = math.max(own.apartAtLock, o.apartAtLock)
				own.timeouts += o.timeouts
				own.longest = math.max(own.longest, o.longestPrediction)
				own.presses += o.presses
				own.predicted += o.predicted
				own.looks += o.looks
				own.lookMax = math.max(own.lookMax, o.lookMax)
				own.cueFlips += o.cueFlips
				own.cueSeconds += o.cueSeconds
				own.cueExcess = math.max(own.cueExcess, o.cueExcess)
			end
		end
		totals.before += cell.before
		totals.first5 += cell.first5
		totals.after += cell.after
		print(string.format("%-4s %-8s races with an overlap: before the lock %d/%d, first 5 s after %d/%d, lock to line %d/%d",
			course, distance, cell.before, races, cell.first5, races, cell.after, races))
	end
end
print(string.format("all: races with an overlap before the lock %d/%d, first 5 s after %d/%d, lock to line %d/%d; overlapping frames %d / %d / %d of %d",
	totals.before, totals.races, totals.first5, totals.races, totals.after, totals.races,
	totals.beforeFrames, totals.first5Frames, totals.afterFrames, totals.frames))
print(string.format("in the last 2 s (holds let go): %d races, %d frames; order across the line differs from the result in %d/%d races; a half-lane step in %d races",
	totals.lastTwo, totals.lastTwoFrames, totals.orderBad, totals.races, halfStepRaces))
print(string.format("the order the horses cross the line on the drawn screen differs from the result in %d/%d races", totals.crossBad, totals.races))
print(string.format("races where a horse is drawn jerking back (faster than 20 ft/s against the pace): before the lock %d/%d, after it %d/%d; fastest fall back before the lock %.1f ft/s, after it %.1f ft/s",
	jerkRacesBefore, totals.races, jerkRaces, totals.races, backBefore, backAfter))
if next(answers) ~= nil then
	local parts = {}
	for answer, count in answers do table.insert(parts, answer .. " " .. count) end
	table.sort(parts)
	print("riders' presses: " .. table.concat(parts, ", "))
end
if own.races > 0 then
	print(string.format("rider 1's own screen (%.2f s each way): races with its horse overlapping another before the lock %d/%d, after %d/%d (frames %d / %d)",
		opts.latency or 0.1, own.overlapsBefore, own.races, own.overlapsAfter, own.races, own.framesBefore, own.framesAfter))
	if eased then
		print(string.format("  presses %d, %d showed the look cue at once (longest held %.2f s); none drawn ahead of the server (%d)",
			own.presses, own.looks, own.lookMax, own.predicted))
		print(string.format("  the look cue swung the body from one side to the other %.2f times a second; the body turned at most %.1f deg beyond its drift",
			own.cueFlips / math.max(own.cueSeconds, 1e-9), math.deg(own.cueExcess)))
	else
		print(string.format("  presses %d, %d started a glide at once; longest prediction %.2f s, timed out %d; longest drawn apart from the shared view %.2f s; apart 1 s after the lock %.3f lanes",
			own.presses, own.predicted, own.longest, own.timeouts, own.apartMax, own.apartAtLock))
	end
end
if eased then
	local parts = {}
	for styleName, r in reversals do
		table.insert(parts, string.format("%s %.2f a minute (shortest gap %s)", styleName, 60 * r.count / math.max(r.seconds, 1e-9),
			if r.minGap < math.huge then string.format("%.1f s", r.minGap) else "-"))
	end
	table.sort(parts)
	print("D-057 reversals: " .. table.concat(parts, "; "))
	print(string.format("D-057 drawn sideways acceleration, fastest: before the lock %.1f ft/s^2, after it %.1f ft/s^2", accelBefore, accelAfter))
	print(string.format("D-057 brushes: %d in %d/%d races (%.2f a race); riders boxed in %.1f%% of their pre-lock time",
		brushes, brushRaces, totals.races, brushes / totals.races, 100 * boxedTicks / math.max(riderTicks, 1)))
	local bparts = {}
	for styleName, b in brushStyles do
		table.insert(bparts, string.format("%s %.1f%% of races with a brush, %.1f%% charged, %.2f brushes a race", styleName,
			100 * b.brushRaces / math.max(b.riders, 1), 100 * b.chargedRaces / math.max(b.riders, 1), b.brushes / math.max(b.riders, 1)))
	end
	table.sort(bparts)
	if #bparts > 0 then print("D-057 brushes by rider: " .. table.concat(bparts, "; ") .. string.format("; horses charged for a brush they never made %d", strangerCharged)) end
	print(string.format("D-057 after the lock: %d moves; in the last 2 s %d full-lane moves (%d races) and %d half-lane steps; %d reversals, %d within 3.5 s of the last, shortest gap %s",
		after.moves, after.late, after.lateRaces, after.lateHalf, after.reversals, after.within,
		if after.minGap < math.huge then string.format("%.1f s", after.minGap) else "-"))
end
local problems = {}
if totals.beforeFrames + totals.afterFrames > 0 then table.insert(problems, "overlapping horses on the shared screen") end
if own.framesBefore + own.framesAfter > 0 then table.insert(problems, "overlapping horses on rider 1's own screen") end
if jerkRaces + jerkRacesBefore > 0 then table.insert(problems, "a horse drawn falling back faster than 20 ft/s") end
if totals.orderBad > 0 then table.insert(problems, "the order across the line differs from the result") end
if totals.crossBad > 0 then table.insert(problems, "the horses cross the line on screen out of the result's order") end
if eased then
	for styleName, r in reversals do
		if r.minGap < 3 - 1e-9 then table.insert(problems, styleName .. " reverses within 3 s") end
	end
	-- Trip's landing tick reaches 30.4 ft/s^2 (its own sideways speed changes at most 27); the sent
	-- lanes' 0.001-lane rounding adds up to 1.2 (0.002 lane over a second difference): 31.6.
	if math.max(accelBefore, accelAfter) > 31.7 then table.insert(problems, "drawn sideways acceleration over 31.7 ft/s^2") end
	if after.minGap < 3.5 - 1e-6 then table.insert(problems, "a horse reverses after the lock within 3.5 s of its last reversal") end
	if after.late > 100 / 960 * totals.races + 1e-9 then table.insert(problems, "more than 100 late full-lane moves per 960 races") end
	if own.predicted > 0 then table.insert(problems, "rider 1's horse drawn ahead of the server") end
	if strangerCharged > 0 then table.insert(problems, "a horse charged for a brush it never made (only the mover pays)") end
	local casual = brushStyles.casual
	if casual and casual.chargedRaces > 0.05 * casual.riders then table.insert(problems, "casual riders charged for a brush in more than 5% of races") end
	if own.cueSeconds > 0 and own.cueFlips / own.cueSeconds >= 0.5 then table.insert(problems, "the look cue swings the body side to side 0.5 times a second or more") end
	if own.cueExcess > math.rad(3) + 1e-9 then table.insert(problems, "the body turns more than 3 deg beyond its drift") end
end
if #problems > 0 then
	print("FAIL: " .. table.concat(problems, "; "))
	process.exit(1)
end
print("PASS")
