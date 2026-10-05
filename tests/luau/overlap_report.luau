--!strict
-- Overlap report (D-054 S2, S3): how often horses overlap on screen, before the far-turn lock, in the
-- first 5 s after it, and from the lock to the line.
-- Run: lune run tests/luau/overlap_report [races] [riders=N] [manual] [predict] [latency=S]
--   riders = lanes pressing ◀ ▶ at random (S3); manual = with Smart Steer off; predict = rider 1
--   presses from its own screen (singles, doubles, mashes, In-then-Out) with `latency` each way
--   (0.1 s by default), its horse drawn by SteerPredict; the report then adds that screen's numbers.
local process = require("@lune/process")
local simulate = require("./race_overlap")

local races = 120
local opts: { [string]: any } = { riders = 0, manual = false, predict = false }
for _, arg in process.args do
	local key, value = string.match(arg, "^(%w+)=(.+)$")
	if key then
		opts[key] = tonumber(value)
	elseif arg == "manual" or arg == "predict" then
		opts[arg] = true
	elseif tonumber(arg) then
		races = tonumber(arg) :: number
	end
end
if opts.predict and opts.riders < 1 then opts.riders = 1 end

local answers = {}
local totals = { races = 0, before = 0, first5 = 0, after = 0, frames = 0, beforeFrames = 0, first5Frames = 0, afterFrames = 0, lastTwo = 0, lastTwoFrames = 0, orderBad = 0 }
local own = { races = 0, overlapsBefore = 0, overlapsAfter = 0, framesBefore = 0, framesAfter = 0, apartMax = 0, apartAtLock = 0,
	timeouts = 0, longest = 0, presses = 0, predicted = 0 }
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
			for answer, count in s.answers do answers[answer] = (answers[answer] or 0) + count end
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
print(string.format("in the last 2 s (holds let go): %d races, %d frames; order across the line differs from the result in %d/%d races",
	totals.lastTwo, totals.lastTwoFrames, totals.orderBad, totals.races))
if opts.riders > 0 then
	local parts = {}
	for answer, count in answers do table.insert(parts, answer .. " " .. count) end
	table.sort(parts)
	print("riders' presses: " .. table.concat(parts, ", "))
end
if own.races > 0 then
	print(string.format("rider 1's own screen (%.2f s each way): races with its horse overlapping another before the lock %d/%d, after %d/%d (frames %d / %d)",
		opts.latency or 0.1, own.overlapsBefore, own.races, own.overlapsAfter, own.races, own.framesBefore, own.framesAfter))
	print(string.format("  presses %d, %d started a glide at once; longest prediction %.2f s, timed out %d; longest drawn apart from the shared view %.2f s; apart 1 s after the lock %.3f lanes",
		own.presses, own.predicted, own.longest, own.timeouts, own.apartMax, own.apartAtLock))
end
