--!strict
-- TapPreview (D-071, provisional; GameConfig.tapPreview): the draw-only pre-lock preview. From the
-- gate to the far-turn lock a lane's drawn offset leads Trip's by what its taps in the open pace
-- checkpoint have earned so far, so good taps visibly gain ground within a second or two instead
-- of waiting for the checkpoint to close. Drawn only: it reads Trip's offsets and lanes and the
-- preview chances, and writes only its own arrays. Trip, tau, the scores, the live chances, the
-- order, the prizes and the sent lanes are the same with it on or off (tap_preview_tests.luau).
-- It is never given the race's luck, and before the lock the race shape shows none.
--
-- Per lane, the drawn offset is d = base + e, base = Trip's offsets before the lock (st.off) and
-- the shown offsets after it (st.view). The residual e follows a goal:
--   before the lock (riders; bots too with previewBots): lead * leadFeetPerShare * (pv - live) *
--     ramp * n / (n + shrinkPasses), pv = the chances if the open checkpoint closed now with the
--     riders' scores so far and every other lane keeping its pace (RaceSession:previewOwn: skill
--     only, stores nothing; a rider tapping as before, or as the bots' average before the first
--     close, shows nothing, and the bots' own scores wait for the close), n = its passes finished
--     (0 below minPasses), ramp = Trip's gap ramp from the gate;
--   after the lock: 0 (the post-lock PacePreview moves the shown offsets themselves).
-- Handover (a close, and for fadeSeconds after the lock): while the base moves toward d, d holds
-- where it is instead of being pulled back, so nothing drops back as Trip's offsets catch up.
-- Limits: -capBackFeet <= e <= capFeet; e moves at most maxSpeed ft/s and changes speed at most
-- maxAccel ft/s^2, and the drawn horse moves no faster than maxSpeed or Trip's own horse.
-- Lane room, leader first by base (horses whose drawn or target lanes are within steering.laneBand
-- share a lane, so a horse gliding in is cleared before it arrives): laneGapFeet to the horse ahead
-- and behind, never less than the base leaves itself; never inside hardGapFeet once within
-- hardLaneBand lanes; in the next lane, within joinSlackFeet of the base's gap once the two are
-- joinClearFeet apart (Trip's clearance for a lane change), so a glide across has time to clear.
-- Room moves a horse at most pullPerSecond (Trip's hold pull): back from a horse ahead, or a horse
-- drawn behind Trip back up toward it. A horse behind never pushes one ahead past Trip's own.
-- step allocates nothing (tap_preview_tests.luau scans it): every array is made in new.

local TapPreview = {}

export type State = {
	cfg: any, n: number, lead: number, rampSeconds: number, band: number,
	diff: { number }, passes: number, gain: { number },
	e: { number }, u: { number }, d: { number }, pb: { number }, ord: { number },
	started: boolean, locked: boolean, lockAt: number, lastT: number,
	msgLow: { number }, msgAt: { number }, msgReady: boolean, score: { number }, clean: { number },
	on: { boolean }, roomed: { boolean }, slowed: { boolean }, heldFeet: { number }, aimFeet: { number }, upper: { number }, hardClamps: number,
}

-- A preview layer for n lanes. lead = Trip's feet per unit of chance share (st.lead, from
-- raceShape.leadFeetPerShare), rampSeconds = steering.gapRampSeconds, band = steering.laneBand.
function TapPreview.new(n: number, cfg: any, lead: number, rampSeconds: number, band: number): State
	return {
		cfg = cfg, n = n, lead = lead * ((cfg and cfg.lead) or 1), rampSeconds = rampSeconds, band = band,
		diff = table.create(n, 0), passes = 0, gain = table.create(n, 0),
		e = table.create(n, 0), u = table.create(n, 0), d = table.create(n, 0), pb = table.create(n, 0),
		ord = table.create(n, 0),
		started = false, locked = false, lockAt = 0, lastT = 0,
		msgLow = table.create(n, 0), msgAt = table.create(n, -math.huge), msgReady = false, hardClamps = 0, -- lane-room moves so far (reports)
		on = table.create(n, (cfg and cfg.previewBots) ~= false),
		upper = table.create(n, 0),
		slowed = table.create(n, false), -- the drawn speed limit slowed this lane on the last step
		heldFeet = table.create(n, 0), -- how far lane room keeps this lane behind its goal (TapPreview.held)
		aimFeet = table.create(n, 0), -- that goal (feet ahead of Trip, before lane room)
		score = table.create(n, -1), -- each rider's provisional score in the open checkpoint (-1: none yet)
		clean = table.create(n, 0), -- ...and the share of its passes tapped exactly once
		roomed = table.create(n, false), -- lane room held this lane's goal or pulled it back on the last step
	}
end

-- Whether lane i shows its own preview (riders always; bots only with previewBots). Lanes that
-- don't still make room for those that do.
function TapPreview.setRider(state: State, i: number, rider: boolean)
	state.on[i] = rider or state.cfg.previewBots ~= false
end

function TapPreview.enabled(cfg: any): boolean
	return type(cfg) == "table" and cfg.enabled == true
end

-- At a pass end in the open pace checkpoint (before the lock): live = session.live, pv =
-- session:previewOwn(seg, partial) over the passes finished (every other lane keeps its pace:
-- only a rider's own taps move it), passes = how many,
-- partial = the riders' provisional scores (the same table previewLive got), clean = each rider's
-- share of those passes tapped exactly once (PaceMeter.score's third value / passes): a message
-- needs at least messageMinScore and messageMinClean. Copies the numbers; the tables stay the caller's.
function TapPreview.setPreview(state: State, live: { number }, pv: { number }, passes: number,
	partial: { [number]: number }?, clean: { [number]: number }?)
	if state.locked then return end
	for i = 1, state.n do
		state.diff[i] = (pv[i] or 0) - (live[i] or 0)
		state.score[i] = if partial then partial[i] or -1 else -1
		state.clean[i] = if clean then clean[i] or 0 else 0
	end
	state.passes = passes
end

-- A checkpoint closed (call after RaceSession:closeSegment): the new checkpoint starts at n = 0.
-- Trip's offsets now chase the new live chances; the drawn offsets hold until they arrive.
function TapPreview.closed(state: State)
	for i = 1, state.n do
		state.diff[i] = 0
		state.score[i] = -1
		state.clean[i] = 0
	end
	state.passes = 0
end

local function shares(x: { number }, tgt: { number }, i: number, j: number, band: number): boolean
	local xi, xj, ti, tj = x[i], x[j], tgt[i], tgt[j]
	return math.abs(xi - xj) < band or math.abs(xi - tj) < band or math.abs(ti - xj) < band or math.abs(ti - tj) < band
end

-- One server sample at race time t (seconds since the gate). base = the offsets Trip.frame
-- returned (st.off before the lock, st.view after), x / tgt = the lanes they stand in (st.x and
-- st.tgt before the lock, st.shown and st.shownTgt after), locked = st.locked. Returns the drawn
-- offsets to send (state.d: the same table every call, so send or copy it before the next step).
-- With the layer off it returns base's values unchanged.
function TapPreview.step(state: State, base: { number }, x: { number }, tgt: { number }, t: number, locked: boolean): { number }
	local cfg, n = state.cfg, state.n
	local d, e, u, pb, ord = state.d, state.e, state.u, state.pb, state.ord
	if not TapPreview.enabled(cfg) then
		for i = 1, n do d[i] = base[i] end
		return d
	end
	if not state.started then
		state.started = true
		state.lastT = t
		for i = 1, n do
			pb[i], e[i], u[i], d[i] = base[i], 0, 0, base[i]
		end
	end
	if locked and not state.locked then
		state.locked = true
		state.lockAt = t
		for i = 1, n do state.diff[i] = 0 end
		state.passes = 0
	end
	local dt = t - state.lastT
	if dt <= 1e-9 then
		for i = 1, n do d[i] = base[i] + e[i] end
		return d
	end
	state.lastT = t
	local cap, vmax, amax = cfg.capFeet, cfg.maxSpeed, cfg.maxAccel
	local back = cfg.capBackFeet or cap
	local gap, hard, pull = cfg.laneGapFeet, cfg.hardGapFeet or cfg.laneGapFeet, cfg.pullPerSecond or cfg.maxSpeed
	local band = state.band
	local ramp = if state.rampSeconds > 0 then math.clamp(t / state.rampSeconds, 0, 1) else 1
	local k = state.passes
	local shrink = if k >= (cfg.minPasses or 0) and k > 0 then k / (k + (cfg.shrinkPasses or 0)) else 0
	-- After the lock the handover holds for at most fadeSeconds; then the residual eases out.
	local holding = not state.locked or t - state.lockAt < (cfg.fadeSeconds or 1) - 1e-9
	local hardBand = cfg.hardLaneBand or 0.55
	local joinClear, joinSlack = cfg.joinClearFeet or 8, cfg.joinSlackFeet or -4
	-- Leader first by base (insertion sort; ties by lane).
	for i = 1, n do
		local a = i
		while a > 1 do
			local j = ord[a - 1]
			if base[j] > base[i] or (base[j] == base[i] and j < i) then break end
			ord[a] = j
			a -= 1
		end
		ord[a] = i
	end
	for a = 1, n do
		local i = ord[a]
		local bi = base[i]
		local db = bi - pb[i]
		local ei = e[i]
		local g = if state.locked or not state.on[i] then 0 else state.lead * state.diff[i] * ramp * shrink
		state.gain[i] = g
		-- Handover: the base moving toward d holds d where it is (never pulled back meanwhile).
		-- And while Trip's horse itself falls back (or moves up) faster than settleFeetPerSecond, the
		-- residual waits instead of adding to that motion.
		local stay = ei - db
		local moving = (cfg.settleFeetPerSecond or 2) * dt
		if holding and ei > 0 then
			if db > 0 then g = math.max(g, stay) elseif db < -moving then g = math.max(g, ei) end
		elseif holding and ei < 0 then
			if db < 0 then g = math.min(g, stay) elseif db > moving then g = math.min(g, ei) end
		end
		g = math.clamp(g, -back, cap)
		local aim = g -- (the goal before lane room: TapPreview.held measures against it)
		-- Lane room (residual units): never less than the base leaves itself.
		local upper, lower, upperHard = math.huge, -math.huge, math.huge
		for b = 1, a - 1 do
			local j = ord[b]
			local apart = base[j] - bi
			if shares(x, tgt, i, j, band) then
				upper = math.min(upper, d[j] - math.min(gap, apart) - bi)
				if math.abs(x[i] - x[j]) < hardBand then
					upperHard = math.min(upperHard, d[j] - math.min(hard, apart) - bi)
				end
			elseif math.abs(x[i] - x[j]) < 1 + band then
				-- The next lane: Trip lets either horse glide across once they are joinClearFeet apart,
				-- so keep i within joinSlackFeet of where the base puts it then (a lane takes about
				-- 0.5 s to cross half way, and lane room eases a horse back about that far meanwhile).
				local slack = if apart >= joinClear then apart + joinSlack else 2 * joinClear + joinSlack - apart
				upper = math.min(upper, d[j] - bi - apart + slack)
			end
		end
		for b = a + 1, n do
			local j = ord[b]
			if shares(x, tgt, i, j, band) then
				-- (a horse behind counts at least where Trip has it: a horse drawn back never drags the ones behind it)
				lower = math.max(lower, base[j] + math.max(e[j], 0) + math.min(gap, bi - base[j]) - bi)
			end
		end
		-- (a horse behind never pushes this one on past Trip's own horse: it keeps it from falling
		-- back into it, and lifts a horse drawn behind Trip back toward it)
		lower = math.min(lower, math.max(ei, g, 0))
		if lower > upper then lower = upper end
		state.roomed[i] = g > upper or g < lower
		state.upper[i] = upper
		g = math.clamp(g, lower, upper)
		-- Follow the goal within the speed and acceleration limits, braking to stop on it.
		local want = g - ei
		-- (the fastest speed that can still stop on the goal one sample later: v dt + v^2 / 2a = want)
		-- (feel review) The drawn horse falls back on Trip's (a lead given back at a close or the lock, a
		-- preview that came down, a masher's drift) at most pullBackFeetPerSecond; pullPerSecond is only
		-- for clearing a horse that cuts in (lane room, below).
		local vcap = if want < 0 then math.min(vmax, cfg.pullBackFeetPerSecond or vmax) else vmax
		local mag = math.min(vcap, amax * (math.sqrt(dt * dt + 2 * math.abs(want) / amax) - dt))
		local vgoal = if want > 0 then mag elseif want < 0 then -mag else 0
		local un = u[i] + math.clamp(vgoal - u[i], -amax * dt, amax * dt)
		local en = ei + un * dt
		if math.abs(g - en) < 1e-3 and math.abs(un) <= amax * dt then
			en, un = g, 0 -- (settled)
		end
		-- The drawn horse itself moves no faster than maxSpeed, or than Trip's own horse moves.
		local was = pb[i] + ei
		local step = bi + en - was
		local lim, pullStep = vmax * dt, pull * dt
		local hi = math.max(lim, math.min(pullStep, db + lim), db)
		local lo = math.min(-lim, math.max(-pullStep, db - lim), db)
		state.slowed[i] = false
		if step > hi then
			en = was + hi - bi
			state.slowed[i] = true
		elseif step < lo then
			en = was + lo - bi
			state.slowed[i] = true
		end
		-- Lane room at up to pullPerSecond (back from the horse ahead, or a drawn-back horse up from the
		-- one behind), never inside hardGapFeet; then the caps.
		local pushed = false
		if en > upper then
			en = math.max(upper, math.min(en, pb[i] + ei - pull * dt - bi))
			pushed = true
		elseif en < lower then
			en = math.min(lower, math.max(en, pb[i] + ei + pull * dt - bi))
			pushed = true
		end
		if en > upperHard then
			en = upperHard
			pushed = true
		end
		en = math.min(math.clamp(en, -back, cap), upperHard)
		if pushed then
			state.hardClamps += 1
			state.roomed[i] = true
		end
		u[i] = if pushed then 0 else (en - ei) / dt
		state.heldFeet[i] = if state.roomed[i] and not state.locked then math.max(0, aim - en) else 0
		state.aimFeet[i] = aim
		e[i] = en
		d[i] = bi + en
		pb[i] = bi
	end
	-- Each lane's drawn lead over the field's mean, lowest since its last message (TapPreview.message).
	local mean = 0
	for i = 1, n do mean += d[i] end
	mean /= n
	for i = 1, n do
		local lead = d[i] - mean
		if not state.msgReady or lead < state.msgLow[i] then state.msgLow[i] = lead end
	end
	state.msgReady = true
	return d
end

-- The rider's message above their horse (D-071; RaceController shows it as a BillboardGui):
-- "up" ("Giddy-up! Moving up!", TapPreview.MESSAGES) or nil: never anything about leading or
-- winning before the lock (systems review; the one key is "up" even when drawn 1st). Only before
-- the lock, only while the lane's taps are earning ground (its preview goal and drawn lead over
-- Trip both positive) and are good taps (over at least messageMinPasses passes, a provisional score of
-- messageMinScore or more with messageMinClean of them tapped exactly once: a masher's doubled
-- passes never earn one), only when its drawn lead over the field's mean
-- has grown messageFeet since its lowest point after the last message, and at most once every
-- messageEverySeconds. Gains only, never a loss, never a number. Records the message when it
-- returns one.
function TapPreview.message(state: State, i: number, t: number): string?
	local cfg = state.cfg
	if not TapPreview.enabled(cfg) or cfg.messageEnabled == false or state.locked or not state.started then return nil end
	if t - state.msgAt[i] < (cfg.messageEverySeconds or 4) then return nil end
	if state.gain[i] <= 0 or state.e[i] <= 0 or state.score[i] < (cfg.messageMinScore or 60)
		or state.passes < (cfg.messageMinPasses or 6) or state.clean[i] < (cfg.messageMinClean or 0.8) then return nil end
	local d, n = state.d, state.n
	local mean = 0
	for j = 1, n do mean += d[j] end
	mean /= n
	local lead = d[i] - mean
	if lead - state.msgLow[i] < (cfg.messageFeet or 8) then return nil end
	state.msgAt[i] = t
	state.msgLow[i] = lead
	return "up"
end

-- The message's words by key (the client shows them; nothing about leading or winning).
TapPreview.MESSAGES = { up = "Giddy-up! Moving up!" }

-- (D-071 rulings) How far lane room keeps lane i's drawn horse behind where its taps would put it
-- (feet; 0 when nothing holds it, and after the lock). RaceService sends it to the rider (TapHeld).
function TapPreview.held(state: State, i: number): number
	return state.heldFeet[i] or 0
end

-- The held cue (D-071 rulings; tapPreview.heldCue), one per rider, on the rider's own screen.
export type Cue = { over: number, overChip: number, chipAt: number, tapsShown: boolean }

function TapPreview.newCue(): Cue
	return { over = 0, overChip = 0, chipAt = -math.huge, tapsShown = false }
end

-- One frame of the cue: held = the rider's latest TapHeld feet, dt = frame seconds, now = race time,
-- locked = lanes locked, smart = no steering buttons are shown to the rider (Smart Steer rides for
-- them: Trip.riderControls kind "intro"), sideRoom = SteerLane says a side has room. Returns pressure (bob x1.3 and a dust puff
-- a stride: held >= minFeet for minSeconds; the caller skips it under Reduced Motion) and the chip:
-- "gap" ("Room this way! ◀/▶" via TapMessage.chip, riders with the buttons, a side with room, at most every
-- chipEverySeconds), "taps" ("Keep tapping! Room soon.", riders without buttons, once a race) or nil, when
-- held >= chipMinFeet for chipMinSeconds. Never after the lock. Allocates nothing.
function TapPreview.stepCue(cue: Cue, cfg: any, held: number, dt: number, now: number, locked: boolean,
	smart: boolean, sideRoom: boolean): (boolean, string?)
	local hc = cfg and cfg.heldCue
	if not TapPreview.enabled(cfg) or type(hc) ~= "table" or locked then
		cue.over, cue.overChip = 0, 0
		return false, nil
	end
	cue.over = if held >= hc.minFeet then cue.over + dt else 0
	cue.overChip = if held >= hc.chipMinFeet then cue.overChip + dt else 0
	local pressure = cue.over >= hc.minSeconds - 1e-9
	local chip: string? = nil
	if cue.overChip >= hc.chipMinSeconds - 1e-9 then
		if smart then
			if not cue.tapsShown then
				cue.tapsShown = true
				chip = "taps"
			end
		elseif sideRoom and now - cue.chipAt >= hc.chipEverySeconds - 1e-9 then
			cue.chipAt = now
			chip = "gap"
		end
	end
	return pressure, chip
end

-- (review N6) When the server sends a rider's held value (TapHeld). One HeldSend per rider:
-- last = the value last sent (rounded to 0.1 ft: send state.last when due), lastT = when.
export type HeldSend = { last: number, lastT: number }

function TapPreview.newHeldSend(): HeldSend
	return { last = 0, lastT = -math.huge }
end

-- Is a TapHeld send due at race time t for this held value? cfg = GameConfig.tapPreview. The value
-- is rounded to 0.1 ft. Due at once (whatever the gap) when it drops to 0 from above 0, or crosses
-- heldCue.minFeet or heldCue.chipMinFeet either way; otherwise only heldSend.minGapSeconds (0.5)
-- after the last send, and then when it moved heldSend.feet (1) or more, or when it is above 0 and
-- heldSend.resendSeconds (1) have passed (a lost unreliable packet is repaired). When due, records
-- it (state.last, state.lastT). Allocates nothing.
function TapPreview.heldSendDue(state: HeldSend, held: number, t: number, cfg: any): boolean
	local hc, hs = cfg.heldCue, cfg.heldSend
	local v = math.floor(math.max(0, held) * 10 + 0.5) / 10
	local last = state.last
	local due = false
	if v == 0 and last > 0 then
		due = true
	elseif (v >= hc.minFeet) ~= (last >= hc.minFeet) or (v >= hc.chipMinFeet) ~= (last >= hc.chipMinFeet) then
		due = true
	elseif t - state.lastT >= hs.minGapSeconds - 1e-9 then
		due = math.abs(v - last) >= hs.feet - 1e-9 or (v > 0 and t - state.lastT >= hs.resendSeconds - 1e-9)
	end
	if due then
		state.last, state.lastT = v, t
	end
	return due
end

-- The residual still drawn on lane i (feet ahead of the base; 0 with the layer off).
function TapPreview.residual(state: State, i: number): number
	return state.e[i] or 0
end

return TapPreview
