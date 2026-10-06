--!strict
-- SteerChips (D-057 N4): when the steering chips above the ◀ ▶ buttons may speak. Pure (Lune tests).
-- * "No room yet": a press has waited noRoomChipAfter (1 s) for room with no move and no tuck-back
--   under way; once per wait, at most once per noRoomChipEvery (10 s), and never within chipMinGap
--   (2 s) of another steering chip. Plain words: no blame, no cost, no hurry.
-- * Every other steering chip ("Saved ground!", "Tucked in!", "Gap!", the turn tip, "Lanes
--   locked!") is good news or a one-off, so it always shows; SteerChips.shown records it, so a
--   "No room yet" never crowds it.
-- Times are race time (SteerLane's waitAt clock).

export type Chips = { lastAt: number, noRoomAt: number, noRoomWait: number }

local SteerChips = {}

function SteerChips.new(): Chips
	return { lastAt = -math.huge, noRoomAt = -math.huge, noRoomWait = -math.huge }
end

-- Any steering chip shown at `now`.
function SteerChips.shown(c: Chips, now: number)
	c.lastAt = now
end

-- Whether "No room yet" should show now (and records it if so). lane = the latest SteerLane.
function SteerChips.noRoom(c: Chips, lane: any, now: number, hudCfg: any): boolean
	if lane == nil or lane.wait == 0 or lane.tucking then return false end
	if now - lane.waitAt < hudCfg.noRoomChipAfter then return false end
	if c.noRoomWait == lane.waitAt then return false end -- once per wait
	if now - c.noRoomAt < hudCfg.noRoomChipEvery or now - c.lastAt < hudCfg.chipMinGap then return false end
	c.noRoomAt, c.noRoomWait, c.lastAt = now, lane.waitAt, now
	return true
end

return SteerChips
