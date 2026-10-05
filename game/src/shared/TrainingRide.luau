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
--   scoreGrit       Mud Splash: puddles splashed (7.5), logs hopped (12, clean = airborne),
--                   poles passed on the right side (8.5).
--   finalize        the 0.5 floor when enforcing, stars, ribbon (gold also needs par).
-- Samples are { t, x, y, z }: t seconds since GO, y studs above the horse's riding height.
-- A miss never costs anything: a hoop, puddle, log or pole that isn't hit just doesn't count.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")
local TrainingCourses = if script then require(script.Parent.TrainingCourses) :: any else require("./TrainingCourses")
local Training = if script then require(script.Parent.Training) :: any else require("./Training")

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
function TR.validate(samples: { Sample }, onCourse: ((number, number) -> boolean)?, cfg: any): ({ Sample }, number, any)
	local kept: { Sample } = {}
	local bad, stale, off = 0, 0, 0
	local prev: Sample? = nil
	local moving = false
	local staleRun = 0
	local lastKept: Sample? = nil
	local dropped = false
	for _, s in samples do
		if prev and moving and staleRun < TR.MAX_STALE and same(prev :: Sample, s) then
			stale += 1
			staleRun += 1
			continue
		end
		staleRun = 0
		local fast = prev ~= nil and not possible(prev :: Sample, s, cfg)
		local outside = not fast and onCourse ~= nil and not onCourse(s.x, s.z)
		if fast then
			bad += 1
			dropped = true
		elseif outside then
			off += 1
			dropped = true
		else
			local gap = dropped and lastKept ~= nil and teleport(lastKept :: Sample, s, cfg)
			local k = { t = s.t, x = s.x, y = s.y, z = s.z, gap = gap }
			table.insert(kept, k)
			lastKept = k
			dropped = false
		end
		moving = prev ~= nil and not same(prev :: Sample, s)
		prev = s
	end
	local judged = #samples - stale - off
	return kept, if judged > 0 then bad / judged else 0, { bad = bad, stale = stale, off = off }
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

-- Live tracker ------------------------------------------------------------------------------
function TR.tracker(key: string)
	local c = TC.courses[key]
	return { key = key, progress = 0, lastD = c.startD or 0, last = nil :: Sample?, next = 1, finished = false, hit = {},
		finishT = nil :: number?, minFinish = if c.kind == "arena" then TR.MIN_FINISH_SHARE * TC.idealSeconds(key) else 0 }
end

-- Feed one sample; returns true once the course is finished. A sample at exactly the last
-- position (a frozen replica, or standing still) is skipped, so the catch-up after a freeze
-- is measured over the whole freeze.
function TR.feed(tr: any, s: Sample, cfg: any): boolean
	local c = TC.courses[tr.key]
	local prev = tr.last
	if tr.finished then return true end
	if prev and same(prev, s) then return false end
	tr.last = s
	if c.kind == "oval" then
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

function TR.scoreGrit(kept: { Sample }, cfg: any): (number, any)
	local c = TC.courses.grit
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
	local minT = TR.MIN_FINISH_SHARE * TC.idealSeconds("grit")
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

-- Validate, score and finalize a whole ride. `seconds` is the ride time the server measured
-- (its tracker's finish, or the time when the ride ran out).
function TR.run(key: string, samples: { Sample }, cfg: any, seconds: number?)
	local kept, bad, counts = TR.validate(samples, function(x: number, z: number): boolean return TC.onCourse(key, x, z) end, cfg)
	local raw, detail
	if key == "speed" then
		raw, detail = TR.scoreSpeed(kept, cfg)
	elseif key == "grit" then
		raw, detail = TR.scoreGrit(kept, cfg)
	else
		return nil
	end
	local secs = seconds or detail.finishT or (if #samples > 0 then samples[#samples].t else 0)
	local res = TR.finalize(raw, bad, secs, TC.idealSeconds(key), cfg)
	res.detail, res.course, res.kept, res.counts = detail, key, #kept, counts
	res.scored = if key == "speed" then detail.hoops else detail.mud + detail.logs + detail.poles
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
