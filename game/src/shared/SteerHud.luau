--!strict
-- SteerHud (D-057 N4): what the ◀ In / Out ▶ buttons show, from the server's word on your own lane
-- (SteerLane, built by Trip.riderLane). Pure, so Lune tests every case; RaceController paints it.
-- * Grey (with a small horse icon): Out ▶ while a horse leaves no room outside; ◀ In only when
--   tuck-back can't help either ("blocked": D-057's "trapped", about 1% of race time). Never when
--   tuck-back can still slot you in ("tuck"): that press works at once. Never at the rail or the
--   outer edge ("edge"): no horse is there, and a grey arrow with a horse icon would be wrong. A
--   grey arrow still takes presses. No buzz, no red. An arrow greys only once its side has been
--   blocked for greyAfterSeconds on this screen (a horse sweeping past for a tick never blinks it;
--   about the playback's lead on the drawn horses), and comes back the moment there's room.
-- * Wait ring: while a press waits for room, on its arrow: lit for an inward press (it waits until
--   a gap or a tuck slot comes), filling over the outward wait for an outward one (then it drops).
-- * Wobble: when a waiting press drops without moving (an outward press at the end of its wait), its
--   arrow wobbles gently (RaceController: ±wobbleDeg over wobbleSeconds, none under Reduced Motion).
--   A brush also clears the mover's waiting press (D-057 N5); that never wobbles (brushAt).
-- * "Gap!": when a press that waited at least gapChipAfterWait for room starts its move, unless the
--   wait saw a tuck-back ("Tucked in!" says that one, and two chips would crowd).
-- Every wait is timed by the server's clock (SteerLane's t and waitAt, race time), never by when a
-- message arrived. Only riders with the buttons hear SteerLane; with shown = false (spectators, a
-- rider's first races) nothing shows. Arrow tables are filled in place (no allocation per frame).

export type Lane = { tgt: number, dest: number, ack: number, wait: number, waitAt: number, tucking: boolean,
	inSide: string, outSide: string, t: number }
export type Arrow = { grey: boolean, ring: number } -- ring: -1 none, else the fill 0..1 (1 = lit)
export type Hud = { inArrow: Arrow, outArrow: Arrow, inSince: number?, outSince: number?, seen: boolean,
	tgt: number, wait: number, waitAt: number, sawTuck: boolean }

local SteerHud = {}

function SteerHud.new(): Hud
	return { inArrow = { grey = false, ring = -1 }, outArrow = { grey = false, ring = -1 }, inSince = nil, outSince = nil,
		seen = false, tgt = 0, wait = 0, waitAt = 0, sawTuck = false }
end

-- How long a press in direction d waits for room before it drops (0 = until room): D-057's waits,
-- or D-054's outward wait with the switch-back (blockedPress = "d054").
function SteerHud.waitLimit(steer: any, d: number): number
	if steer.blockedPress == "wait" then
		return if d < 0 then steer.gapWaitInSeconds else steer.gapWaitSeconds
	end
	return if d < 0 then 0 else steer.outwardWaitSeconds
end

-- Both arrows now (called every frame). lane = the latest SteerLane (nil before one arrives), now =
-- race time on this screen (the server's clock estimate), steer = GameConfig.steering, hudCfg =
-- GameConfig.steerHud.
function SteerHud.arrows(h: Hud, lane: Lane?, now: number, steer: any, hudCfg: any, shown: boolean): (Arrow, Arrow)
	local inA, outA = h.inArrow, h.outArrow
	inA.grey, inA.ring, outA.grey, outA.ring = false, -1, false, -1
	if not shown or lane == nil then
		h.inSince, h.outSince = nil, nil
		return inA, outA
	end
	if lane.inSide == "blocked" then h.inSince = h.inSince or now else h.inSince = nil end
	if lane.outSide == "blocked" then h.outSince = h.outSince or now else h.outSince = nil end
	if hudCfg.greyArrows then
		local hold = hudCfg.greyAfterSeconds
		inA.grey = h.inSince ~= nil and now - (h.inSince :: number) >= hold - 1e-9
		outA.grey = h.outSince ~= nil and now - (h.outSince :: number) >= hold - 1e-9
	end
	if hudCfg.waitRing and lane.wait ~= 0 then
		local lim = SteerHud.waitLimit(steer, lane.wait)
		local fill = if lim > 0 then math.clamp((now - lane.waitAt) / lim, 0, 1) else 1
		if lane.wait < 0 then inA.ring = fill else outA.ring = fill end
	end
	return inA, outA
end

-- A new SteerLane message: returns the arrow to wobble (-1 In, 1 Out, 0 none) and whether to say
-- "Gap!". Waits are measured on the server's clock (lane.t, the message's state time, against the
-- wait's start). pressDir / pressAt = your last press (race time): a wait that ends because you
-- pressed the other way was cancelled by you, not dropped, and doesn't wobble. brushAt = your last
-- brush (race time, SteerBrush): a wait it cleared doesn't wobble either.
function SteerHud.message(h: Hud, lane: Lane, steer: any, hudCfg: any, pressDir: number?, pressAt: number?,
	brushAt: number?): (number, boolean)
	local wobble, gap = 0, false
	if h.seen and h.wait ~= 0 and lane.wait == 0 then
		local waited = lane.t - h.waitAt
		if (lane.tgt - h.tgt) * h.wait > 0 then
			gap = waited >= hudCfg.gapChipAfterWait - 1e-9 and not h.sawTuck -- the wait ended in the move
		else
			local lim = SteerHud.waitLimit(steer, h.wait)
			local cancelled = (pressDir == -h.wait and (pressAt or -math.huge) >= h.waitAt)
				or (brushAt or -math.huge) >= h.waitAt - 1e-9 -- (or a brush cleared it)
			if lim > 0 and waited >= lim - 1e-6 and not cancelled then wobble = h.wait end -- dropped by the server
		end
	end
	if lane.wait ~= 0 and lane.wait ~= h.wait then
		h.sawTuck = lane.tucking -- a new wait
	elseif lane.wait ~= 0 then
		h.sawTuck = h.sawTuck or lane.tucking
	else
		h.sawTuck = false
	end
	h.seen, h.tgt, h.wait, h.waitAt = true, lane.tgt, lane.wait, lane.waitAt
	return wobble, gap
end

return SteerHud
