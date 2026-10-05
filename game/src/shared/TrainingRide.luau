--!strict
-- TrainingRide (D-053): scores a training ride from the server's own samples of the ride rig
-- (10 Hz on the server clock; the client sends no score). Pure, tested under Lune; the client
-- runs the same tracker on its own position for the lap dots and the glowing next piece.
--   validate        skips stale samples (a frozen replica), drops samples faster than maxSpeed
--                   or longer than maxStep (teleports) and samples off the course; returns the
--                   kept ones and the share dropped for speed or teleports (off-course samples
--                   just don't score and never count toward the floor).
--   crossings       where a path crosses a gate, with direction (+1 forward, -1 backward).
--   tracker / feed  live progress: laps on the oval, the next gymkhana piece, the finish.
--   scoreSpeed      Sprint Lane: 100 × hoops ridden through, in order and forward, / 18.
--   scoreGrit       Mud Splash (any of its layouts): puddles splashed (7.5), logs hopped (12,
--                   clean = airborne), poles passed on the right side (8.5).
--   scoreAccel      Gate Break: three breaks from the practice gate; each scores by reaction
--                   to the bell (100 within fullReact, down to breakFloor at zeroReact).
--   scoreStamina    Hill Climb: 100 × the share of time in Pip's ring after the grace.
--   finalize        the 0.5 floor when enforcing, stars, ribbon (gold also needs par).
-- Samples are { t, x, y, z }: t seconds since GO, y studs above the horse's riding height.
-- A miss never costs anything: a hoop, puddle, log or pole that isn't hit just doesn't count.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")
local TrainingCourses = if script then require(script.Parent.TrainingCourses) :: any else require("./TrainingCourses")
local Training = if script then require(script.Parent.Training) :: any else require("./Training")
local TapTime = if script then require(script.Parent.TapTime) :: any else require("./TapTime")

export type Sample = { t: number, x: number, y: number, z: number, gap: boolean? }
export type Crossing = { i: number, f: number, t: number, dir: number, x: number, y: number, z: number }

local TC = TrainingCourses
local TR = {}

TR.RIBBONS = { "bronze", "silver", "gold" }
TR.RIBBON_RANK = { bronze = 1, silver = 2, gold = 3 }
TR.MIN_FINISH_SHARE = 0.4 -- the gymkhana finish counts only after this share of its ideal time

TR.MAX_STALE = 5          -- an unchanged position this many samples in a row is a real stop
TR.TIMEOUT_SHARE = 0.25   -- a ride that runs out of time counts only past this share of the course

-- The most oval distance the horse could cover between two samples (a bigger jump is clamped).
local function stepLimit(dt: number, cfg: any): number
	return cfg.maxSpeed * math.max(dt, 1 / cfg.sampleHz) * 1.2 + 1
end
TR.stepLimit = stepLimit

-- Is the move from a to b a teleport (longer than maxStep per sample interval)?
local function teleport(a: Sample, b: Sample, cfg: any): boolean
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	return math.sqrt(dx * dx + dy * dy + dz * dz) > cfg.maxStep * math.max(1, (b.t - a.t) * cfg.sampleHz)
end

-- Same position as the previous sample (a replica that didn't update)?
local function same(a: Sample, b: Sample): boolean
	return math.abs(a.x - b.x) < 1e-4 and math.abs(a.z - b.z) < 1e-4 and math.abs(a.y - b.y) < 1e-4
end

-- Could the horse have gone from a to b? (horizontal speed and the teleport step)
local function possible(a: Sample, b: Sample, cfg: any): boolean
	local dt = b.t - a.t
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	local h = math.sqrt(dx * dx + dz * dz)
	return dt > 0 and h / dt <= cfg.maxSpeed and math.sqrt(h * h + dy * dy) <= cfg.maxStep * math.max(1, dt * cfg.sampleHz)
end

-- A network freeze shows the horse standing still for a sample or two and then catching up:
-- an unchanged position right after movement is stale and skipped (neither kept nor counted),
-- so the catch-up is measured from the last real sample over the whole freeze.
-- Kept samples are marked `gap` when the move from the previous kept one is a teleport: no
-- crossing counts across that stretch. A lag-then-burst catch-up (too fast for one sample, but
-- no teleport) is dropped and counted, yet the ride across it still counts.
-- Returns (kept, bad share, counts { bad, stale, off }).
-- The screener judges one sample at a time: "ok" (with the kept copy), "stale", "bad" or
-- "off". validate() runs it over a whole ride; the server runs it live for Gate Break.
function TR.screener(onCourse: ((number, number) -> boolean)?)
	return { onCourse = onCourse, prev = nil :: Sample?, moving = false, staleRun = 0, lastKept = nil :: Sample?,
		dropped = false, n = 0, bad = 0, stale = 0, off = 0 }
end

function TR.screen(sc: any, s: Sample, cfg: any): (string, Sample?)
	sc.n += 1
	local prev = sc.prev
	if prev and sc.moving and sc.staleRun < TR.MAX_STALE and same(prev, s) then
		sc.stale += 1
		sc.staleRun += 1
		return "stale", nil
	end
	sc.staleRun = 0
	local fast = prev ~= nil and not possible(prev, s, cfg)
	local outside = not fast and sc.onCourse ~= nil and not sc.onCourse(s.x, s.z)
	sc.moving = prev ~= nil and not same(prev, s)
	sc.prev = s
	if fast then
		sc.bad += 1
		sc.dropped = true
		return "bad", nil
	elseif outside then
		sc.off += 1
		sc.dropped = true
		return "off", nil
	end
	local gap = sc.dropped and sc.lastKept ~= nil and teleport(sc.lastKept, s, cfg)
	local k = { t = s.t, x = s.x, y = s.y, z = s.z, gap = gap }
	sc.lastKept = k
	sc.dropped = false
	return "ok", k
end

-- The share of judged samples (not stale, not off course) that were too fast or teleported.
function TR.badShare(sc: any): number
	local judged = sc.n - sc.stale - sc.off
	return if judged > 0 then sc.bad / judged else 0
end

function TR.validate(samples: { Sample }, onCourse: ((number, number) -> boolean)?, cfg: any): ({ Sample }, number, any)
	local kept: { Sample } = {}
	local sc = TR.screener(onCourse)
	for _, s in samples do
		local kind, k = TR.screen(sc, s, cfg)
		if kind == "ok" then table.insert(kept, k :: Sample) end
	end
	return kept, TR.badShare(sc), { bad = sc.bad, stale = sc.stale, off = sc.off }
end

local function crossing(p: Sample, q: Sample, g: any): (number, number)
	local sp = (p.x - g.ax) * g.nx + (p.z - g.az) * g.nz
	local sq = (q.x - g.ax) * g.nx + (q.z - g.az) * g.nz
	local dir = 0
	if sp < 0 and sq >= 0 then dir = 1 elseif sp >= 0 and sq < 0 then dir = -1 end
	if dir == 0 then return 0, 0 end
	local f = sp / (sp - sq)
	local gx, gz = g.bx - g.ax, g.bz - g.az
	local cx, cz = p.x + (q.x - p.x) * f, p.z + (q.z - p.z) * f
	local u = ((cx - g.ax) * gx + (cz - g.az) * gz) / (gx * gx + gz * gz)
	if u < 0 or u > 1 then return 0, 0 end
	return dir, f
end

-- Every crossing of gate g by the path through `samples` (segments after a dropped sample are
-- skipped: the horse can't be trusted to have ridden them).
function TR.crossings(samples: { Sample }, g: any): { Crossing }
	local out: { Crossing } = {}
	for i = 2, #samples do
		local p, q = samples[i - 1], samples[i]
		if q.gap then continue end
		local dir, f = crossing(p, q, g)
		if dir ~= 0 then
			table.insert(out, { i = i, f = f, t = p.t + (q.t - p.t) * f, dir = dir,
				x = p.x + (q.x - p.x) * f, y = p.y + (q.y - p.y) * f, z = p.z + (q.z - p.z) * f })
		end
	end
	return out
end

-- Oval progress ------------------------------------------------------------------------------
-- Progress round the oval from the start, shared by the live tracker and scoreSpeed. A jump
-- bigger than the horse could make is clamped, not thrown away, and every hoop ridden through
-- puts progress back exactly on that hoop, so a freeze or a dropped sample costs at most a
-- few studs until the next hoop. A forward crossing counts for the hoop whose place in the
-- ride matches the progress, so reversed, repeated or out-of-order crossings don't count.
local hoopsByPost: { [number]: { any } } = {}
for _, hp in TC.courses.speed.hoops do
	hoopsByPost[hp.post] = hoopsByPost[hp.post] or {}
	table.insert(hoopsByPost[hp.post], hp)
end
local HOOP_TOL = TC.LAP / (2 * #TC.courses.speed.posts)

local function matchHoop(post: number, at: number): any?
	local best, bestErr = nil, HOOP_TOL
	for _, hp in hoopsByPost[post] or {} do
		local err = math.abs(at - hp.s)
		if err <= bestErr then best, bestErr = hp, err end
	end
	return best
end

local function ovalStep(st: any, prev: Sample?, s: Sample, cfg: any)
	local c = TC.courses[st.key]
	local d = TC.ovalProject(s.x, s.z)
	local delta = TC.wrap(d - st.lastD)
	st.lastD = d
	local lim = stepLimit(if prev then s.t - prev.t else 1 / cfg.sampleHz, cfg)
	delta = math.clamp(delta, -lim, lim)
	local before = st.progress
	st.progress += delta
	if prev and not s.gap and c.posts then
		for _, post in c.posts do
			local dir, f = crossing(prev, s, post.gate)
			if dir > 0 then
				local at = before + delta * f
				local hp = matchHoop(post.index, at)
				if hp then
					st.hit[hp.index] = true
					st.progress += hp.s - at -- re-sync to the hoop
				end
			end
		end
	end
	if not st.finishT and st.progress >= c.finish then
		local moved = st.progress - before
		local f = if moved > 0 then math.clamp((c.finish - before) / moved, 0, 1) else 1
		st.finishT = if prev then prev.t + (s.t - prev.t) * f else s.t
	end
end

-- Latency allowances (capped like race taps, D-021). `ping` is Player:GetNetworkPing(), a
-- round trip. Gate Break: the bell goes out and the go comes back, so the whole round trip.
-- Hill Climb: the rider's screen runs Pip on the server's clock, and the server sees the rider
-- one trip late, so one way.
function TR.bellAllowance(ping: number): number
	return TapTime.rewindAllowance(2 * ping, GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
end

function TR.lagAllowance(ping: number): number
	return TapTime.rewindAllowance(ping, GameConfig.tapJitterMarginSeconds, GameConfig.maxTapRewindSeconds)
end

-- Seconds into the ride on any machine: the server's clock (workspace:GetServerTimeNow()) minus
-- the server's go time from TrainBegin. The rider's screen runs Pip and the countdown on this,
-- so a slow countdown loop or a late message never makes Pip late.
function TR.rideClock(serverNow: number, goAtServer: number): number
	return serverNow - goAtServer
end

-- Live tracker ------------------------------------------------------------------------------
-- opts (Gate Break): { seed, allowance, allowances }. The seed is the server's own bell seed,
-- never sent to the client. allowances[n] (set by the server when the n-th bell rings, from
-- the ping then) wins over the single `allowance`.
function TR.tracker(key: string, opts: any?)
	local c = TC.courses[key]
	local o = opts or {}
	return { key = key, progress = 0, lastD = c.startD or 0, last = nil :: Sample?, next = 1, finished = false, hit = {},
		finishT = nil :: number?, minFinish = if c.kind == "arena" then TR.MIN_FINISH_SHARE * TC.idealSeconds(key) else 0,
		-- Gate Break
		seed = o.seed or 1, allowance = o.allowance or 0, allowances = o.allowances or {}, phase = "settle", breakNo = 1,
		attempt = 1, arms = 0, armT = nil :: number?, settleSince = nil :: number?, bellT = nil :: number?, results = {}, events = {} }
end

-- Gate Break --------------------------------------------------------------------------------
-- Each break: stand still in the stall (settle) -> "Ready" (armed) -> the bell -> go -> the
-- flag 120 studs on. Moving goStuds or leaving the stall before the bell is an early go: the
-- break runs once more ("Wait for the bell!"), and an early go on the rerun scores breakFloor.
-- A go counts from inside the stall only, because only a horse settled in the stall is armed.
-- Reaction = when the horse started - the bell - the latency allowance. The start is worked
-- back from how far the horse is from where it was readied, at a gallop, and can't be before
-- the break was readied (a frozen replica at a standing start looks like standing still, so
-- the previous sample is no bound; a teleport only makes the start look earlier, i.e. early). The tracker queues events for the
-- server to send: { kind = "armed" | "early" | "go" | "flag", ... }; the bell time is never in
-- them.
TR.DASH_SETTLE = 1.5 -- after a go, standing in the stall this long also ends the break

function TR.breakScore(reaction: number, cfg: any): number
	local ac = cfg.accel
	if reaction <= ac.fullReact then return 100 end
	if reaction >= ac.zeroReact then return ac.breakFloor end
	return 100 - (100 - ac.breakFloor) * (reaction - ac.fullReact) / (ac.zeroReact - ac.fullReact)
end

local function event(tr: any, kind: string, data: any?)
	local e = data or {}
	e.kind, e.breakNo = kind, tr.breakNo
	table.insert(tr.events, e)
end

local function endBreak(tr: any, t: number, cfg: any)
	event(tr, "flag", { last = tr.breakNo >= cfg.accel.breaks })
	tr.breakNo += 1
	tr.attempt, tr.bellT, tr.settleSince = 1, nil, nil
	if tr.breakNo > cfg.accel.breaks then
		tr.finished, tr.finishT, tr.phase = true, t, "done"
	else
		tr.phase = "settle"
	end
end

local function feedAccel(tr: any, prev: Sample?, s: Sample, cfg: any)
	local c = TC.courses.accel
	local ac = cfg.accel
	local inBox = TC.inRect(c.stall, s.x, s.z)
	local moved, dt = 0, 0
	if prev then
		moved = math.sqrt((s.x - prev.x) ^ 2 + (s.z - prev.z) ^ 2)
		dt = s.t - prev.t
	end
	local slow = dt <= 0 or moved / dt < 3
	-- how far from where the break was readied, and when the horse set off from there
	local away = if tr.spot then math.sqrt((s.x - tr.spot.x) ^ 2 + (s.z - tr.spot.z) ^ 2) else moved
	local function goTime(): number
		return math.clamp(s.t - away / cfg.gallop, tr.armT or s.t, s.t)
	end
	local function gone(): boolean
		return away >= ac.goStuds or not inBox
	end
	if tr.phase == "settle" or tr.phase == "dash" then
		if tr.phase == "dash" and prev and not s.gap then
			local dir, f = crossing(prev, s, c.flag)
			if dir > 0 then return endBreak(tr, prev.t + (s.t - prev.t) * f, cfg) end
		end
		if inBox and slow then
			tr.settleSince = tr.settleSince or (if prev then prev.t else s.t)
			local need = if tr.phase == "dash" then TR.DASH_SETTLE else ac.settleSeconds
			if s.t - tr.settleSince >= need then
				if tr.phase == "dash" then
					endBreak(tr, s.t, cfg) -- came back without the flag: the break still counts
					if tr.finished then return end
					tr.settleSince = s.t - ac.settleSeconds -- already settled
				end
				tr.arms += 1
				tr.armT, tr.spot = s.t, { x = s.x, z = s.z }
				tr.bellT = s.t + TC.bellDelay(tr.seed, tr.arms)
				tr.phase = "armed"
				event(tr, "armed", { attempt = tr.attempt })
			end
		else
			tr.settleSince = nil
		end
	elseif tr.phase == "armed" or tr.phase == "go" then
		if gone() then
			local goT = goTime()
			if goT < (tr.bellT :: number) then
				if tr.attempt == 1 then
					event(tr, "early", { rerun = true })
					tr.attempt, tr.phase, tr.bellT, tr.settleSince = 2, "settle", nil, nil
				else
					tr.results[tr.breakNo] = { score = ac.breakFloor, early = true, wait = (tr.bellT :: number) - (tr.armT :: number) }
					event(tr, "early", { rerun = false, score = ac.breakFloor })
					tr.phase = "dash"
				end
			else
				local allowance = tr.allowances[tr.arms] or tr.allowance
				local reaction = math.max(0, goT - (tr.bellT :: number) - allowance)
				local score = TR.breakScore(reaction, cfg)
				tr.results[tr.breakNo] = { score = score, reaction = reaction, wait = (tr.bellT :: number) - (tr.armT :: number) }
				event(tr, "go", { score = score, reaction = reaction })
				tr.phase, tr.settleSince = "dash", nil
			end
		elseif s.t >= (tr.bellT :: number) then
			tr.phase = "go" -- the bell has rung; waiting for the horse to go
		end
	end
end

-- Feed one sample; returns true once the course is finished. A sample at exactly the last
-- position (a frozen replica, or standing still) is skipped, so the catch-up after a freeze
-- is measured over the whole freeze.
function TR.feed(tr: any, s: Sample, cfg: any): boolean
	local c = TC.courses[tr.key]
	local prev = tr.last
	if tr.finished then return true end
	-- (Gate Break is fed screened samples, which skip frozen ones already and keep a horse
	-- that really stands still: it needs those to settle in the stall.)
	if prev and c.kind ~= "gate" and same(prev, s) then return false end
	tr.last = s
	if c.kind == "gate" then
		feedAccel(tr, prev, s, cfg)
	elseif c.kind == "oval" then
		if c.posts then
			ovalStep(tr, prev, s, cfg)
		else -- Hill Climb (T3): progress only
			local d = TC.ovalProject(s.x, s.z)
			local lim = stepLimit(if prev then s.t - prev.t else 1 / cfg.sampleHz, cfg)
			tr.progress += math.clamp(TC.wrap(d - tr.lastD), -lim, lim)
			tr.lastD = d
			if tr.progress >= c.finish then tr.finishT = s.t end
		end
		if tr.finishT then tr.finished = true end
	elseif c.kind == "arena" and prev then
		for j = tr.next, #c.elements do
			if crossing(prev, s, c.elements[j].pass) > 0 then tr.next = j + 1 end -- passing a piece moves the glow on
		end
		local dir, f = crossing(prev, s, c.finish)
		if dir > 0 and s.t >= tr.minFinish then
			tr.finished = true
			tr.finishT = prev.t + (s.t - prev.t) * f
		end
	end
	return tr.finished
end

-- Sprint Lane: the next hoop to ride through (nil after the last), and laps done.
function TR.nextHoop(tr: any): any?
	for _, hp in TC.courses.speed.hoops do
		if hp.s > tr.progress then return hp end
	end
	return nil
end

function TR.laps(tr: any): number
	local c = TC.courses[tr.key]
	if tr.finished then return c.laps or 0 end
	return math.clamp(math.floor(tr.progress / TC.LAP), 0, c.laps or 0)
end

-- How much of the course the tracker has been round (0..1).
function TR.progressShare(tr: any): number
	local c = TC.courses[tr.key]
	if tr.finished then return 1 end
	if c.kind == "arena" then return math.clamp((tr.next - 1) / #c.elements, 0, 1) end
	if c.kind == "gate" then return math.clamp((tr.breakNo - 1) / TR.config.accel.breaks, 0, 1) end
	return math.clamp(tr.progress / c.finish, 0, 1)
end

-- Scoring ---------------------------------------------------------------------------------
function TR.scoreSpeed(kept: { Sample }, cfg: any): (number, any)
	local c = TC.courses.speed
	local st = TR.tracker("speed")
	local prev: Sample? = nil
	for _, s in kept do
		ovalStep(st, prev, s, cfg)
		prev = s
	end
	local n = 0
	for _ in st.hit do n += 1 end
	return 100 * n / #c.hoops, { hoops = n, of = #c.hoops, hit = st.hit, finishT = st.finishT, progress = st.progress }
end

-- A log is cleared when the horse is airborne over it: at the crossing, or in a sample within
-- logWindow studs of the log and half a second of the crossing.
function TR.cleared(kept: { Sample }, x: Crossing, e: any, g: any): boolean
	if x.y >= g.airborne then return true end
	local nx, nz = e.gate.nx, e.gate.nz
	for _, s in kept do
		if math.abs(s.t - x.t) <= 0.5 and s.y >= g.airborne then
			local along = (s.x - e.x) * nx + (s.z - e.z) * nz
			local across = math.abs((s.x - e.x) * -nz + (s.z - e.z) * nx)
			if math.abs(along) <= g.logWindow and across <= TC.LOG_HALF + 1 then return true end
		end
	end
	return false
end

function TR.scoreGrit(kept: { Sample }, cfg: any, key: string): (number, any)
	local c = TC.courses[key]
	local g = cfg.grit
	local counts = { mud = 0, log = 0, pole = 0 }
	local got = {}
	for _, e in c.elements do
		local ok = false
		if e.kind == "mud" then
			for _, s in kept do
				if TC.inRect(e.rect, s.x, s.z) then
					ok = true
					break
				end
			end
		else
			for _, x in TR.crossings(kept, e.gate) do
				if x.dir > 0 and (e.kind == "pole" or TR.cleared(kept, x, e, g)) then
					ok = true
					break
				end
			end
		end
		if ok then
			got[e.name] = true
			counts[e.kind] += 1
		end
	end
	local finishT: number? = nil
	local minT = TR.MIN_FINISH_SHARE * TC.idealSeconds(key)
	for _, x in TR.crossings(kept, c.finish) do
		if x.dir > 0 and x.t >= minT then
			finishT = x.t
			break
		end
	end
	local raw = counts.mud * g.points.mud + counts.log * g.points.log + counts.pole * g.points.pole
	return math.min(100, raw), { mud = counts.mud, logs = counts.log, poles = counts.pole, got = got, finishT = finishT }
end

function TR.stars(score: number, cfg: any): number
	return 1 + (if score >= cfg.stars[1] then 1 else 0) + (if score >= cfg.stars[2] then 1 else 0)
end

-- Score, stars and ribbon. More than maxBadShare of samples dropped scores at the floor (score
-- 0 = quality 0.5) only when enforceFloor is on; otherwise it's flagged for the logs only.
-- The end card looks the same either way.
function TR.finalize(raw: number, badShare: number, seconds: number?, ideal: number, cfg: any)
	local flagged = badShare > cfg.maxBadShare
	local floored = flagged and cfg.enforceFloor == true
	local score = if floored then 0 else math.clamp(raw, 0, 100)
	score = math.floor(score * 10 + 0.5) / 10
	local par = ideal * cfg.parFactor
	local underPar = seconds ~= nil and seconds <= par
	local ribbon = "bronze" -- finishing earns bronze
	if score >= cfg.ribbons.silver then ribbon = "silver" end
	if score >= cfg.ribbons.gold and underPar then ribbon = "gold" end
	return { score = score, raw = raw, stars = TR.stars(score, cfg), ribbon = ribbon, flagged = flagged, floored = floored,
		badShare = badShare, seconds = seconds or 0, par = par, underPar = underPar }
end

-- Gate Break from a ride's kept samples (the server's live tracker sees the same ones).
-- `allowance` is one number or a table by bell (the n-th bell's allowance at [n]).
function TR.scoreAccel(kept: { Sample }, seed: number, allowance: any, cfg: any): (number, any)
	local tr = TR.tracker("accel", { seed = seed, allowance = if typeof(allowance) == "number" then allowance else 0,
		allowances = if typeof(allowance) == "table" then allowance else nil })
	for _, s in kept do TR.feed(tr, s, cfg) end
	local total, scored, quick = 0, 0, 0
	for b = 1, cfg.accel.breaks do
		local r = tr.results[b]
		if r then
			total += r.score
			scored += 1
			if r.score >= 90 then quick += 1 end
		end
	end
	return total / cfg.accel.breaks, { breaks = tr.results, scored = scored, quick = quick, finishT = tr.finishT }
end

-- Gate Break's ideal time for this ride: the bell waits it really had (the average for a break
-- that didn't happen), so gold never depends on bell luck.
function TR.accelIdeal(results: any, cfg: any): number
	local ac = cfg.accel
	local base = TC.idealSeconds("accel")
	local mean = (ac.bellMin + ac.bellMax) / 2
	for b = 1, ac.breaks do
		local r = results[b]
		if r and r.wait then base += r.wait - mean end
	end
	return base
end

-- Hill Climb: is the horse in Pip's ring at t? The ring runs ringNear..ringFar studs behind
-- Pip round the oval, ringHalfWidth either side of Pip's line. `lag` (the player's latency,
-- capped) is how far behind the server's clock the rider's screen shows Pip.
function TR.inRing(seed: number, t: number, x: number, z: number, lag: number, cfg: any): (boolean, number)
	local st = cfg.stamina
	local pony = TC.ponyAt(seed, t - lag)
	local d, lat = TC.ovalProject(x, z)
	local behind = TC.wrap(pony.d - d)
	return behind >= st.ringNear and behind <= st.ringFar and math.abs(lat - pony.lateral) <= st.ringHalfWidth, behind
end

-- `kept` must include off-course samples (TR.run validates Hill Climb without a course
-- check): time away from the track is time out of the ring, not time that doesn't count.
function TR.scoreStamina(kept: { Sample }, seed: number, lag: number, cfg: any): (number, any)
	local endT = TC.idealSeconds("stamina", seed)
	local n, inside = 0, 0
	for _, s in kept do
		if s.t >= cfg.stamina.grace and s.t <= endT then
			n += 1
			if TR.inRing(seed, s.t, s.x, s.z, lag, cfg) then inside += 1 end
		end
	end
	local share = if n > 0 then inside / n else 0
	return 100 * share, { share = share, samples = n, inRing = inside, finishT = endT }
end

-- The samples a ride is scored on (the same checks TR.run makes), e.g. for its ghost.
function TR.keptSamples(key: string, samples: { Sample }, cfg: any): { Sample }
	local onCourse = if key == "stamina" then nil else function(x: number, z: number): boolean return TC.onCourse(key, x, z) end
	return (TR.validate(samples, onCourse, cfg))
end

-- Validate, score and finalize a whole ride. `seconds` is the ride time the server measured
-- (its tracker's finish, or the time when the ride ran out).
-- opts: Gate Break { bellSeed, allowance (or allowances by bell) }, Hill Climb { seed, lag }.
function TR.run(key: string, samples: { Sample }, cfg: any, seconds: number?, opts: any?)
	local o = opts or {}
	-- Hill Climb keeps off-course samples: they count as out of Pip's ring
	local onCourse = if key == "stamina" then nil else function(x: number, z: number): boolean return TC.onCourse(key, x, z) end
	local kept, bad, counts = TR.validate(samples, onCourse, cfg)
	local c = TC.courses[key]
	local raw, detail
	if key == "speed" then
		raw, detail = TR.scoreSpeed(kept, cfg)
	elseif c and c.kind == "arena" then
		raw, detail = TR.scoreGrit(kept, cfg, key)
	elseif key == "accel" then
		raw, detail = TR.scoreAccel(kept, o.bellSeed or 1, o.allowances or o.allowance or 0, cfg)
	elseif key == "stamina" then
		raw, detail = TR.scoreStamina(kept, o.seed or 1, o.lag or 0, cfg)
	else
		return nil
	end
	local secs = seconds or detail.finishT or (if #samples > 0 then samples[#samples].t else 0)
	local ideal = if key == "accel" then TR.accelIdeal(detail.breaks, cfg) else TC.idealSeconds(key)
	local res = TR.finalize(raw, bad, secs, ideal, cfg)
	res.detail, res.course, res.kept, res.counts = detail, key, #kept, counts
	res.scored = if key == "speed" then detail.hoops
		elseif c.kind == "arena" then detail.mud + detail.logs + detail.poles
		elseif key == "accel" then detail.scored
		else detail.inRing
	return res
end

-- A ride that ran out of time counts only with real riding in it: something scored, or more
-- than TIMEOUT_SHARE of the course ridden. Otherwise it ends kindly with no gain.
function TR.timeoutCounts(result: any, tr: any): boolean
	return result ~= nil and ((result.scored or 0) > 0 or TR.progressShare(tr) > TR.TIMEOUT_SHARE)
end

-- Session limits: at least sessionGapSeconds apart and at most maxSessionsPerHour. `history`
-- holds session start times (it is pruned here); the caller adds `now` when a session starts.
function TR.rateCheck(history: { number }, now: number, cfg: any): (boolean, string?)
	local i = 1
	while i <= #history do
		if now - history[i] >= 3600 then table.remove(history, i) else i += 1 end
	end
	if #history > 0 and now - history[#history] < cfg.sessionGapSeconds then return false, "gap" end
	if #history >= cfg.maxSessionsPerHour then return false, "hour" end
	return true, nil
end

-- Gain through the D-040 formula and weekly cap (quality = 0.5 + 0.5 × score / 100). After
-- the cap, or at Potential, nothing changes and `capped` says why ("week" or "full").
function TR.applyGain(h: any, stat: string, score: number, now: number)
	Training.repair(h)
	local before = h.stats[stat] or 0
	if not Training.ready(h, now) then
		return { gained = 0, before = before, after = before, capped = "week", rested = false }
	end
	if (h.potential[stat] or 0) - before < Training.MIN_GAIN then
		return { gained = 0, before = before, after = before, capped = "full", rested = false }
	end
	local rested = Training.isRested(h, now)
	local ok, g = Training.train(h, stat, score, now)
	return { gained = if ok then g else 0, before = before, after = h.stats[stat], capped = nil, rested = ok and rested }
end

-- Keep the best ribbon and the best run (score, then time) per course on the horse.
-- Returns (new ribbon, new best).
function TR.record(h: any, key: string, result: any): (boolean, boolean)
	if typeof(h.ribbons) ~= "table" then h.ribbons = {} end
	if typeof(h.trainingBest) ~= "table" then h.trainingBest = {} end
	local newRibbon = (TR.RIBBON_RANK[result.ribbon] or 0) > (TR.RIBBON_RANK[h.ribbons[key]] or 0)
	if newRibbon then h.ribbons[key] = result.ribbon end
	local best = h.trainingBest[key]
	local secs = math.floor((result.seconds or 0) * 10 + 0.5) / 10
	local newBest = best == nil or result.score > best.score or (result.score == best.score and secs < best.seconds)
	if newBest then h.trainingBest[key] = { score = result.score, seconds = secs } end
	return newRibbon, newBest
end

-- Quick train (the 10-second games) keeps a client score until T4; its quality is capped.
function TR.quickScore(score: number, cfg: any): number
	return math.min(math.clamp(score, 0, 100), (cfg.quickQualityCap - 0.5) * 200)
end

TR.config = GameConfig.training
return TR
