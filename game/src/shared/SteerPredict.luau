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
-- * With the eased glide (D-057, cfg.glide = "eased") nothing is predicted: the slide starts with
--   the server's lane (the S-curve covers 0.05 lane in its first 0.15 s, so a round trip hides in
--   the ease-in) and your horse is drawn where everyone sees it, so a refused press never snaps
--   back. N3 adds the instant "look" cue. With D-054's linear glide nothing here changes.

export type Server = { tgt: number, dest: number, ack: number }
export type View = {
	me: number,          -- your lane index
	lanes: number,       -- lanes on the track
	x: { number },       -- the server's lanes (latest RaceOffsets), every horse
	off: { number },     -- offsets as drawn (feet ahead of the pace), every horse
	srv: Server?,        -- your own lane from the server (SteerLane), once one has arrived
	cfg: any,            -- GameConfig.steering
}

local SteerPredict = {}

SteerPredict.SECONDS = 1.5 -- a prediction the server's lane hasn't moved toward for this long ends
SteerPredict.AHEAD = 0.45  -- how far over (lanes) a prediction goes before the server answers

-- state.pred = { draw, from, seq, at, best, bestAt } while a press is drawn; timeouts = how many
-- ended by time; longest = the longest a prediction was drawn (s).
function SteerPredict.new(): any
	return { pred = nil, timeouts = 0, longest = 0 }
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
