--!strict
-- Your own lane on your screen while you steer (D-054 S3): a press starts your horse over at once,
-- before the server's answer arrives (a round trip plus up to one 0.1 s tick). Pure, so the
-- overlap simulation (tests/luau/race_overlap.luau) runs the same rules as RaceView.
--
-- The server tells each rider about their own lane (SteerLane, on change): tgt = the lane it is in
-- or gliding to (a lane the server has taken, so it had room), dest = where it ends once every
-- waiting press is done (Trip.laneAfter), ack = the last press (seq) the server has answered.
-- * A press draws one lane, and only from a resting server lane (tgt = dest and not gliding) that
--   has answered every earlier press (ack = seq - 1, so what it says is current): that is the move
--   the server makes on its next tick if the lane has room. A press while the server is busy
--   (gliding, waiting for room, a press queued, or an earlier press still unanswered) draws
--   nothing: it waits for the server, as the server makes it wait.
-- * Only into a lane with room by the server's lanes (Trip's rule: clearFeet ahead, holdGap
--   behind), checked again every frame, and only AHEAD of a lane over until the server answers: a
--   move the server refuses (it may have let another horse into that lane meanwhile) then never
--   comes within half a lane of a horse there. On a usual connection the answer comes first.
-- * The prediction ends when the server has answered that press (ack), when the server's lane
--   hasn't come any closer to it for SECONDS, or at the lock. Your horse then follows the server:
--   its tgt before the lock, the lanes everyone sees after it.
-- * With the eased glide (D-057, cfg.glide = "eased", the game since N3) nothing is predicted:
--   the slide starts with the server's lane (the S-curve covers 0.05 lane in its first 0.15 s, so
--   a round trip hides in the ease-in) and your horse is drawn where everyone sees it, so a
--   refused press never snaps back. The instant answer is the look cue instead (look, lookDir):
--   a press into a lane with room by the lanes on your screen turns your horse's body 3 degrees
--   toward it at once (SteerPose); the cue holds until your horse starts over on your screen, and
--   ends when the server's answer shows the press waits (no move toward it), at the lock, or after
--   SECONDS. A press the server will ignore or hold shows no cue, so mashing stays calm: the same
--   way within pressBounceSeconds of the last cue, against a glide under way, the other way within
--   reverseGapSeconds of landing or (a second reversal within weaveWindowSeconds) weaveGapSeconds,
--   the other way while a cue is held (the cue never swings from side to side), and any press while
--   your horse steadies after a brush (D-057 N5: steadyUntil, the server answers "steady"). Landings and
--   reversals are read off your horse as drawn (lookDir watches it every frame), so the client's
--   gaps end a little after the server's, never before. With D-054's linear glide (the switch-back)
--   the prediction above runs as before.

export type Server = { tgt: number, dest: number, ack: number }
export type View = {
	me: number,          -- your lane index
	lanes: number,       -- lanes on the track
	x: { number },       -- the server's lanes (latest RaceOffsets), every horse
	off: { number },     -- offsets as drawn (feet ahead of the pace), every horse
	srv: Server?,        -- your own lane from the server (SteerLane), once one has arrived
	cfg: any,            -- GameConfig.steering
	steadyUntil: number?, -- (D-057 N5) your horse steadies after your brush until this (the same clock as `now`)
}

local SteerPredict = {}

SteerPredict.SECONDS = 1.5 -- a prediction the server's lane hasn't moved toward for this long ends
SteerPredict.AHEAD = 0.45  -- how far over (lanes) a prediction goes before the server answers

SteerPredict.LOOK_STARTED = 0.05 -- (eased) your horse has started over once drawn this far (lanes) toward the press

-- state.pred = { draw, from, seq, at, best, bestAt } while a press is drawn; timeouts = how many
-- ended by time; longest = the longest a prediction was drawn (s). (eased) state.look = { dir, seq,
-- at, x0, from, moving } while the look cue holds; looks = how many presses showed it; lastLook =
-- { dir, at } of the last cue; seen = your horse as drawn { x, dir (its last move), moving,
-- landedAt, revAt (its last reversal) }.
function SteerPredict.new(): any
	return { pred = nil, timeouts = 0, longest = 0, look = nil, looks = 0, lastLook = nil, seen = nil }
end

-- `lane` has room for your horse by the server's lanes: nobody there within clearFeet ahead or
-- holdGap behind.
function SteerPredict.room(view: View, lane: number): boolean
	local cfg, me = view.cfg, view.me
	for j = 1, #view.x do
		if j ~= me and math.abs(view.x[j] - lane) < cfg.laneBand then
			local ahead = view.off[j] - view.off[me]
			if ahead < cfg.clearFeet and ahead > -cfg.holdGap then return false end
		end
	end
	return true
end

-- A press (dir -1 in, 1 out; seq as sent). Returns true if your horse starts over now.
function SteerPredict.press(state: any, view: View, dir: number, seq: number, now: number): boolean
	local srv = view.srv
	if view.cfg.glide == "eased" then return false end -- D-057: the server's lane only
	if state.pred ~= nil or srv == nil then return false end
	local x = view.x[view.me]
	if srv.ack < seq - 1 then return false end -- an earlier press is still on its way: srv is stale
	if srv.dest ~= srv.tgt or math.abs(x - srv.tgt) > 0.01 then return false end -- busy: the server queues it
	local lane = srv.tgt + dir
	if lane < 1 or lane > view.lanes or not SteerPredict.room(view, lane) then return false end
	state.pred = { draw = lane, from = srv.tgt, seq = seq, at = now, best = math.abs(x - lane), bestAt = now }
	return true
end

-- (eased) Your horse as drawn, every frame: when a move starts (and whether it reverses the last
-- one) and when it lands.
local function watch(state: any, view: View, now: number)
	local x = view.x[view.me]
	local seen = state.seen
	if seen == nil then
		state.seen = { x = x, dir = 0, moving = false, landedAt = -math.huge, revAt = -math.huge }
		return
	end
	local dx = x - seen.x
	seen.x = x
	if math.abs(dx) > 1e-9 then
		if not seen.moving then
			local d = if dx > 0 then 1 else -1
			if seen.dir ~= 0 and d ~= seen.dir then seen.revAt = now end
			seen.dir, seen.moving = d, true
		end
	elseif seen.moving then
		seen.moving, seen.landedAt = false, now
	end
end

-- (eased) A press: shows the look cue (returns true) when the lane it asks for is on the track and
-- has room by the lanes on your screen, and the server will act on it (see the header). view.x =
-- the lanes as drawn.
function SteerPredict.look(state: any, view: View, dir: number, seq: number, now: number): boolean
	local cfg = view.cfg
	local x = view.x[view.me]
	local srv = view.srv
	local from = if srv ~= nil then (srv :: Server).tgt else math.floor(x + 0.5)
	local lane = from + dir
	if lane < 1 or lane > view.lanes or not SteerPredict.room(view, lane) then return false end
	if view.steadyUntil ~= nil and now < view.steadyUntil then return false end -- steadying after a brush
	if state.look ~= nil and state.look.dir ~= dir then return false end -- never swing a held cue round
	local last = state.lastLook
	if last ~= nil and last.dir == dir and now - last.at < cfg.pressBounceSeconds then return false end -- a bounce
	local seen = state.seen
	if seen ~= nil then
		-- a glide under way (as drawn, or still to come from the server's answer)
		local busy = if seen.moving then seen.dir else 0
		if busy == 0 and srv ~= nil and math.abs(srv.dest - x) > 0.01 then busy = if srv.dest > x then 1 else -1 end
		if busy ~= 0 and dir ~= busy then return false end
		if busy == 0 and seen.dir ~= 0 and dir ~= seen.dir then -- a reversal: the gaps after landing
			local gap = cfg.reverseGapSeconds
			if cfg.weaveGapSeconds > gap and now - seen.revAt < cfg.weaveWindowSeconds then gap = cfg.weaveGapSeconds end
			if now - seen.landedAt < gap then return false end
		end
	end
	state.look = { dir = dir, seq = seq, at = now, x0 = x, from = from, moving = nil }
	state.lastLook = { dir = dir, at = now }
	state.looks += 1
	return true
end

-- (eased) The look cue's direction this frame (-1, 1), or 0 once it is over: the server answered
-- the press without moving toward it (the press waits), or your horse has started over on your
-- screen (the drift takes over), or the lock, or SECONDS without an answer.
function SteerPredict.lookDir(state: any, view: View, now: number, locked: boolean): number
	watch(state, view, now)
	local look = state.look
	if look == nil then return 0 end
	if locked or now - look.at > SteerPredict.SECONDS then
		state.look = nil
		return 0
	end
	if (view.x[view.me] - look.x0) * look.dir >= SteerPredict.LOOK_STARTED then
		state.look = nil -- started over on your screen
		return 0
	end
	local srv = view.srv
	if srv ~= nil and srv.ack >= look.seq then
		if look.moving == nil then look.moving = (srv.tgt - look.from) * look.dir > 0 end
		if not look.moving then
			state.look = nil -- answered, and it waits: relax
			return 0
		end
	end
	return look.dir
end

-- The lane to glide your own horse toward this frame.
function SteerPredict.laneTo(state: any, view: View, now: number, locked: boolean): number
	local srv, x = view.srv, view.x[view.me]
	if view.cfg.glide == "eased" then return x end -- D-057: drawn where everyone sees it
	local pred = state.pred
	if pred then
		local gap = math.abs(x - pred.draw)
		if gap < pred.best - 0.005 then pred.best, pred.bestAt = gap, now end
		local timedOut = now - pred.bestAt > SteerPredict.SECONDS
		if locked or (srv ~= nil and srv.ack >= pred.seq) or timedOut or not SteerPredict.room(view, pred.draw) then
			if timedOut and not locked then state.timeouts += 1 end
			state.longest = math.max(state.longest, now - pred.at)
			state.pred = nil
		else
			return pred.from + (pred.draw - pred.from) * SteerPredict.AHEAD
		end
	end
	if srv ~= nil and not locked then return srv.tgt end
	return x
end

return SteerPredict
