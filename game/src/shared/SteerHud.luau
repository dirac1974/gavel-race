--!strict
-- SteerHud (D-057 N4): what the ◀ In / Out ▶ buttons show, from the server's word on your own lane
-- (SteerLane, built by Trip.riderLane). Pure, so Lune tests every case; RaceController paints it.
-- * Grey (with a small horse icon): Out ▶ while a horse leaves no room outside; ◀ In only when
--   tuck-back can't help either ("blocked": D-057's "trapped", about 1% of race time). Never when
--   tuck-back can still slot you in ("tuck"): that press works at once. Never at the rail or the
--   outer edge ("edge"): no horse is there, and a grey arrow with a horse icon would be wrong. A
--   grey arrow still takes presses. No buzz, no red.
-- * Wait ring: while a press waits for room, on its arrow: lit for an inward press (it waits until
--   a gap or a tuck slot comes), filling over gapWaitSeconds for an outward one (then it drops).
-- * Wobble: when a waiting press drops without moving (an outward press after gapWaitSeconds), its
--   arrow wobbles gently (RaceController: ±wobbleDeg over wobbleSeconds, none under Reduced Motion).
-- * "Gap!": when a press that waited at least gapChipAfterWait starts its move.
-- Only riders with the buttons hear SteerLane; with shown = false (spectators, a rider's first
-- races) nothing shows. Arrow tables are filled in place (no allocation per frame).

export type Lane = { tgt: number, dest: number, ack: number, wait: number, waitAt: number, tucking: boolean,
	inSide: string, outSide: string }
export type Arrow = { grey: boolean, ring: number } -- ring: -1 none, else the fill 0..1 (1 = lit)
export type Hud = { inArrow: Arrow, outArrow: Arrow, seen: boolean, tgt: number, wait: number, waitAt: number }

local SteerHud = {}

function SteerHud.new(): Hud
	return { inArrow = { grey = false, ring = -1 }, outArrow = { grey = false, ring = -1 }, seen = false, tgt = 0, wait = 0, waitAt = 0 }
end

-- The wait limit for a press in direction d (0 = it waits until room).
local function limit(steer: any, d: number): number
	return if d < 0 then steer.gapWaitInSeconds else steer.gapWaitSeconds
end

-- Both arrows now. lane = the latest SteerLane (nil before one arrives), now = race time (the
-- clock lane.waitAt is in), steer = GameConfig.steering, hud = GameConfig.steerHud.
function SteerHud.arrows(h: Hud, lane: Lane?, now: number, steer: any, hudCfg: any, shown: boolean): (Arrow, Arrow)
	local inA, outA = h.inArrow, h.outArrow
	inA.grey, inA.ring, outA.grey, outA.ring = false, -1, false, -1
	if not shown or lane == nil then return inA, outA end
	if hudCfg.greyArrows then
		inA.grey = lane.inSide == "blocked"
		outA.grey = lane.outSide == "blocked"
	end
	if hudCfg.waitRing and lane.wait ~= 0 then
		local lim = limit(steer, lane.wait)
		local fill = if lim > 0 then math.clamp((now - lane.waitAt) / lim, 0, 1) else 1
		if lane.wait < 0 then inA.ring = fill else outA.ring = fill end
	end
	return inA, outA
end

-- A new SteerLane message at race time `now`: returns the arrow to wobble (-1 In, 1 Out, 0 none)
-- and whether to say "Gap!". pressDir / pressAt = your last press (race time): a wait that ends
-- because you pressed the other way was cancelled by you, not dropped, and doesn't wobble.
function SteerHud.message(h: Hud, lane: Lane, now: number, steer: any, hudCfg: any, pressDir: number?, pressAt: number?): (number, boolean)
	local wobble, gap = 0, false
	if h.seen and h.wait ~= 0 and lane.wait == 0 then
		local waited = now - h.waitAt
		if (lane.tgt - h.tgt) * h.wait > 0 then
			gap = waited >= hudCfg.gapChipAfterWait -- the wait ended in the move
		else
			local lim = limit(steer, h.wait)
			local cancelled = pressDir == -h.wait and (pressAt or -math.huge) >= h.waitAt
			if lim > 0 and waited >= lim - 0.2 and not cancelled then wobble = h.wait end -- dropped by the server
		end
	end
	h.seen, h.tgt, h.wait, h.waitAt = true, lane.tgt, lane.wait, lane.waitAt
	return wobble, gap
end

return SteerHud
