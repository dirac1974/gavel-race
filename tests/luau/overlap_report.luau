--!strict
-- Overlap report (D-054 S2): how often horses overlap on screen, before the far-turn lock, in the
-- first 5 s after it, and from the lock to the line. Run: lune run tests/luau/overlap_report [races]
local process = require("@lune/process")
local simulate = require("./race_overlap")

local races = tonumber(process.args[1]) or 120
local totals = { races = 0, before = 0, first5 = 0, after = 0, frames = 0, beforeFrames = 0, first5Frames = 0, afterFrames = 0, lastTwo = 0, lastTwoFrames = 0, orderBad = 0 }
for _, course in { "dirt", "turf" } do
	for _, distance in { "Sprint", "Mile", "Classic", "Marathon" } do
		local cell = { before = 0, first5 = 0, after = 0 }
		for seed = 1, races do
			local s = simulate(course, distance, seed * 7919 + 3)
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
