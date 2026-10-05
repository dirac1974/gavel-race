--!strict
-- Race steering trip (D-054): lanes from the gate to the far-turn lock, and the trip tau that
-- joins the win-chance exponent there (kappa * R + c + tau). Pure: no Roblox types, so it runs
-- under Lune.
--
-- Mirrors src/trip.py line by line; tests/luau/run_all.luau replays tests/fixtures/trip.json and
-- must agree to 1e-9 (D-012). Mirror rules: lanes visited in index order; every sort uses a
-- total key (offset, then lane position, then index); step, lock and tau use only + - * /,
-- comparisons, min, max and abs; "never" times are -1e9; fixed ticks t = k * dt.
--
-- Coordinates (rail coordinates, D-054 S1): s = feet along the lane-1 path from the gate (the
-- pace is speed * t); off = feet ahead of the pace; x = lane position, 1 (the rail) .. lanes,
-- fractional while gliding. Lanes are indexed 1..n here (0..n-1 in Python); posts and lane
-- positions are 1-based in both.
--
-- The race helpers at the bottom (start, submit, advance, raceTau, frame, cosmetic) are what
-- RaceService calls; they are Luau only.

export type Rng = { NextNumber: (self: any) -> number }

local Trip = {}

local EPS = 1e-9
local LONG_AGO = -1e9
Trip.EPS = EPS

local KINDS = { bot = true, smart = true, manual = true }

local function isLaneIndex(st: any, i: any): boolean
	return type(i) == "number" and i % 1 == 0 and i >= 1 and i <= st.n
end

local function checkLane(st: any, i: any)
	if not isLaneIndex(st, i) then
		error(string.format("lane index %s out of range 1..%d", tostring(i), st.n), 3)
	end
end

-- (inside a live turn?, feet to the next turn start, the far turn at the lock included)
local function turnInfo(geo: any, s: number): (boolean, number)
	local nxt = geo.lockS
	for _, turn in geo.turns do
		local a, b = turn[1], turn[2]
		if a <= s and s < b then return true, 0 end
		if a > s and a < nxt then nxt = a end
	end
	return false, nxt - s
end

-- State ---------------------------------------------------------------------------------------

-- posts[i] = lane i's starting lane position (1..lanes). q = base chances (kept so the call
-- matches trip.new_state). uniforms = two per lane in lane order (rail, lead). kinds[i] = "bot"
-- (Smart Steer with variety, the default), "smart" (a rider with Smart Steer on) or "manual".
-- race = { speed, leadFeetPerShare, lanes, viewEasePerSecond, maxGapFeetPerSecond,
-- catchUpMarginSeconds } (Trip.raceParams builds it from GameConfig).
function Trip.new(posts: { number }, q: { number }, uniforms: { number }, geo: any, cfg: any, kinds: { string }?, race: any): any
	local n = #posts
	local lanes = race.lanes
	if #q ~= n or #uniforms < 2 * n or (kinds ~= nil and #kinds ~= n) then
		error("posts, q, uniforms (two per lane) and kinds must cover every lane", 2)
	end
	for _, p in posts do
		if type(p) ~= "number" or p % 1 ~= 0 or p < 1 or p > lanes then
			error(string.format("post %s out of range 1..%d", tostring(p), lanes), 2)
		end
	end
	if cfg.maxQueued ~= 0 and cfg.maxQueued ~= 1 then
		error("maxQueued is 0 or 1 (one waiting press at most)", 2)
	end
	local st = {
		cfg = cfg, race = race, geo = geo, n = n,
		lanes = lanes, speed = race.speed, lead = race.leadFeetPerShare,
		posts = table.clone(posts),
		x = table.create(n, 0), tgt = table.create(n, 0),
		off = table.create(n, 0), skill = table.create(n, 0), tuck = table.create(n, 0),
		drafting = table.create(n, false), ground = table.create(n, 0), draft = table.create(n, 0),
		want = table.create(n, 0), wantAt = table.create(n, LONG_AGO), queued = table.create(n, 0),
		manualAt = table.create(n, LONG_AGO), lastChange = table.create(n, LONG_AGO),
		smart = table.create(n, false), home = table.create(n, 0), turnLead = table.create(n, 0),
		locked = false,
	}
	for i = 1, n do
		st.x[i] = posts[i]
		st.tgt[i] = posts[i]
	end
	-- After the lock (Luau only; never part of the trip): offsets and lanes on screen, and the
	-- make-room look-ahead (closing at up to twice the gap cap, a glide plus a little must finish
	-- before two horses meet).
	st.view = table.clone(st.off)
	st.shown, st.shownTgt = table.clone(st.x), table.clone(st.tgt)
	st.lookahead = cfg.holdGap + 2 * race.maxGapFeetPerSecond * (cfg.laneSeconds + 0.2)
	local smart, bots = cfg.smart, cfg.bots
	for i = 1, n do
		local uRail, uLead = uniforms[2 * i - 1], uniforms[2 * i]
		local kind = if kinds ~= nil then kinds[i] else "bot"
		if not KINDS[kind] then error("unknown kind " .. tostring(kind), 2) end
		if kind == "bot" then
			st.smart[i] = true
			if uRail < bots.railShare then
				st.home[i] = 1
			elseif uRail >= 1 - bots.wideShare then
				st.home[i] = smart.homeLane + 1
			else
				st.home[i] = smart.homeLane
			end
			st.turnLead[i] = bots.turnLeadMin + (bots.turnLeadMax - bots.turnLeadMin) * uLead
		else
			st.smart[i] = kind == "smart"
			st.home[i] = smart.homeLane
			st.turnLead[i] = smart.turnLeadSeconds
		end
	end
	return st
end

-- Settings toggle, or a disconnect (on = true).
function Trip.setSmart(st: any, i: number, on: boolean)
	checkLane(st, i)
	st.smart[i] = on
end

-- Rider input ---------------------------------------------------------------------------------

-- A rider's lane-change request: "accepted" (starts this tick if clear), "queued", "cancelled"
-- (the opposite of a press still waiting), or a refusal: "locked", "invalid", "bounds", "rate".
-- Every press but a locked or invalid one pauses Smart Steer for resumeSeconds.
function Trip.acceptIntent(st: any, i: number, d: any, t: number): string
	checkLane(st, i)
	local cfg = st.cfg
	if st.locked then return "locked" end
	if d ~= 1 and d ~= -1 then return "invalid" end
	st.manualAt[i] = t
	local last = if st.queued[i] ~= 0 then st.queued[i] else st.want[i]
	if last ~= 0 and last ~= d then
		if st.queued[i] ~= 0 then
			st.queued[i] = 0
		else
			st.want[i] = 0
		end
		return "cancelled"
	end
	local after = st.tgt[i] + st.want[i] + st.queued[i]
	if after + d < 1 or after + d > st.lanes then return "bounds" end
	local idle = st.want[i] == 0 and st.x[i] == st.tgt[i] and t - st.lastChange[i] >= cfg.minRequestGap - EPS
	if idle then
		st.want[i] = d
		st.wantAt[i] = t
		return "accepted"
	end
	if st.queued[i] == 0 and cfg.maxQueued >= 1 then
		st.queued[i] = d
		return "queued"
	end
	return "rate"
end

-- The lane the rider ends up in once every waiting press is done.
function Trip.laneAfter(st: any, i: number): number
	checkLane(st, i)
	return st.tgt[i] + st.want[i] + st.queued[i]
end

-- One tick ------------------------------------------------------------------------------------

-- Leader first (largest offset), then the inside horse, then the lower index.
local function order(st: any): { number }
	local off, x = st.off, st.x
	local out = table.create(st.n)
	for i = 1, st.n do out[i] = i end
	table.sort(out, function(a: number, b: number): boolean
		if off[a] ~= off[b] then return off[a] > off[b] end
		if x[a] ~= x[b] then return x[a] < x[b] end
		return a < b
	end)
	return out
end

-- A horse may not sit closer than holdGap behind a horse sharing its lane.
local function hold(st: any, ord: { number })
	local band, gap = st.cfg.laneBand, st.cfg.holdGap
	local off, x = st.off, st.x
	for a = 1, st.n do
		local i = ord[a]
		for b = 1, a - 1 do
			local j = ord[b]
			if math.abs(x[i] - x[j]) < band and off[j] - off[i] < gap then
				off[i] = off[j] - gap
			end
		end
	end
end

-- Where horse i could enter `lane`, and whether it is blocked now. A horse in that lane (or
-- gliding into it) blocks when it is less than clearFeet ahead or less than holdGap behind, so
-- the mover never pushes the horse behind it. The slot is the mover's own offset when nothing
-- blocks, else holdGap behind the rearmost blocker, repeated down a line of horses.
local function slot(st: any, i: number, lane: number): (number, boolean)
	local band, clear, gap = st.cfg.laneBand, st.cfg.clearFeet, st.cfg.holdGap
	local p = st.off[i]
	local blocked = false
	for _ = 1, st.n do
		local lowest = 0
		local found = false
		for j = 1, st.n do
			if j ~= i and (math.abs(st.x[j] - lane) < band or st.tgt[j] == lane) then
				local a = st.off[j] - p
				if a < clear and a > -gap then
					if not found or st.off[j] < lowest then lowest = st.off[j] end
					found = true
				end
			end
		end
		if not found then break end
		blocked = true
		p = lowest - gap
	end
	return p, blocked
end

local function tryMove(st: any, i: number, d: number, t: number, tucking: { boolean }, manual: boolean): boolean
	local cfg = st.cfg
	local lane = st.tgt[i] + d
	if lane < 1 or lane > st.lanes then
		if manual then st.want[i] = 0 end
		return false
	end
	local p, blocked = slot(st, i, lane)
	if not blocked then
		st.tgt[i] = lane
		st.lastChange[i] = t
		if manual then st.want[i] = 0 end
		return true
	end
	if d < 0 then
		-- Tuck-in: ease back to the slot behind the horses alongside, then move in; only when the
		-- slot is at most tuckBackMax behind, otherwise wait for room.
		if st.off[i] - p <= cfg.tuckBackMax + EPS then
			st.tuck[i] = math.max(0, st.skill[i] - p)
			tucking[i] = true
		end
	elseif manual and t - st.wantAt[i] >= cfg.outwardWaitSeconds - EPS then
		st.want[i] = 0 -- no room outside: the request cancels
	end
	return false
end

-- One server tick at race time t (seconds since the gate) lasting dt. intents = this tick's
-- { lane, dir } requests in arrival order; returns acceptIntent's answer for each.
function Trip.step(st: any, live: { number }, intents: { { number } }, t: number, dt: number): { string }
	for _, intent in intents do checkLane(st, intent[1]) end
	if st.locked then
		local out = table.create(#intents)
		for k = 1, #intents do out[k] = "locked" end
		return out
	end
	local cfg, race = st.cfg, st.race
	local n = st.n
	if #live ~= n then error("one live chance per lane", 2) end
	-- 1. Skill targets (gaps ramp in from the gate), minus any tuck-back; offsets move toward
	--    them as the race view moves gaps (eased, capped unless catching up by the line).
	local ramp = 1
	if cfg.gapRampSeconds > 0 then ramp = math.min(1, t / cfg.gapRampSeconds) end
	local fair = 1 / n
	local k = math.min(1, dt * race.viewEasePerSecond)
	local toLine = st.geo.length / st.speed - t
	local allowed = race.maxGapFeetPerSecond * dt
	local margin = race.catchUpMarginSeconds
	for i = 1, n do
		st.skill[i] = st.lead * (live[i] - fair) * ramp
		local gap = st.skill[i] - st.tuck[i] - st.off[i]
		local limit
		if toLine <= margin then
			limit = math.huge
		else
			limit = math.max(allowed, math.abs(gap) * dt / (toLine - margin))
		end
		st.off[i] = st.off[i] + math.min(limit, math.max(-limit, gap * k))
	end
	-- 2. Hold: nobody overlaps the horse ahead in its lane.
	hold(st, order(st))
	local ord = order(st)
	-- 3. Lane changes: this tick's requests in arrival order, then everyone else leader first,
	--    then the inside horse.
	local tried = table.create(n, false)
	local tucking = table.create(n, false)
	local answers = table.create(#intents)
	for _, intent in intents do
		local lane, d = intent[1], intent[2]
		local answer = Trip.acceptIntent(st, lane, d, t)
		table.insert(answers, answer)
		if answer == "accepted" then
			tried[lane] = true
			tryMove(st, lane, st.want[lane], t, tucking, true)
		end
	end
	local s0 = st.speed * t
	local inTurn, toTurn = turnInfo(st.geo, s0)
	local resume = cfg.smart.resumeSeconds
	for a = 1, n do
		local i = ord[a]
		if tried[i] or st.x[i] ~= st.tgt[i] then continue end
		if t - st.lastChange[i] < cfg.minRequestGap - EPS then continue end
		if st.want[i] == 0 and st.queued[i] ~= 0 then
			st.want[i] = st.queued[i]
			st.wantAt[i] = t
			st.queued[i] = 0
		end
		if st.want[i] ~= 0 then
			tryMove(st, i, st.want[i], t, tucking, true)
		elseif st.smart[i] and t - st.manualAt[i] >= resume - EPS and st.tgt[i] > st.home[i] then
			-- Smart Steer: heads in before and through turns, never out, never for a draft.
			if inTurn or toTurn <= st.turnLead[i] * st.speed + EPS then
				tryMove(st, i, -1, t, tucking, false)
			end
		end
	end
	-- 4. Lateral glide, then hold again so a horse arriving in a lane never overlaps.
	local glide = dt / cfg.laneSeconds
	for i = 1, n do
		if st.x[i] ~= st.tgt[i] then
			local diff = st.tgt[i] - st.x[i]
			if math.abs(diff) <= glide + EPS then
				st.x[i] = st.tgt[i]
			elseif diff > 0 then
				st.x[i] = st.x[i] + glide
			else
				st.x[i] = st.x[i] - glide
			end
		end
	end
	hold(st, ord)
	local release = cfg.tuckReleasePerSecond * dt
	for i = 1, n do
		if not tucking[i] and st.tuck[i] > 0 then
			st.tuck[i] = math.max(0, st.tuck[i] - release)
		end
	end
	-- 5. Ground on live turns (per 180 degrees) and the tucked-in draft, before the lock.
	local s1 = st.speed * (t + dt)
	local f = 0
	for _, turn in st.geo.turns do
		local ov = math.min(s1, turn[2]) - math.max(s0, turn[1])
		if ov > 0 then f = f + ov / st.geo.turnLength end
	end
	if f > 0 then
		f = f * cfg.groundPerLaneTurn
		for i = 1, n do
			st.ground[i] = st.ground[i] + f * (st.x[i] - 1)
		end
	end
	local dte = math.min(dt, st.geo.lockS / st.speed - t)
	local band, near, far = cfg.laneBand, cfg.draftNear, cfg.draftFar
	local cap, rate = cfg.draftCap, cfg.draftPerSecond
	for i = 1, n do
		local tucked = false
		if dte > 0 then
			for j = 1, n do
				if j ~= i and math.abs(st.x[j] - st.x[i]) < band then
					local ahead = st.off[j] - st.off[i]
					if ahead >= near and ahead <= far then
						tucked = true
						break
					end
				end
			end
		end
		st.drafting[i] = tucked
		if tucked and st.draft[i] < cap then
			st.draft[i] = math.min(cap, st.draft[i] + rate * dte)
		end
	end
	return answers
end

-- The far-turn bell: book the far turn from each horse's lane position, freeze the trip.
function Trip.lock(st: any)
	if st.locked then return end
	local g = st.cfg.groundPerLaneTurn
	for i = 1, st.n do
		st.ground[i] = st.ground[i] + g * (st.x[i] - 1)
		st.want[i] = 0
		st.queued[i] = 0
	end
	st.locked = true
end

-- Seconds from the gate to the lock (RaceService's tFar - tStart).
function Trip.lockTime(geo: any, race: any): number
	return geo.lockS / race.speed
end

-- Trip and tau -------------------------------------------------------------------------------

-- Each lane's trip: tucked-in draft minus ground lost on turns.
function Trip.tripValues(st: any): { number }
	local cap = st.cfg.draftCap
	local out = table.create(st.n)
	for i = 1, st.n do out[i] = math.min(st.draft[i], cap) - st.ground[i] end
	return out
end

-- tau_i = clamp(scale * (trip_i - baseline[post_i] - field mean of the same), floor, ceiling).
-- baseline = the per-post row for this course and distance (TripBaseline).
function Trip.tau(trip: { number }, posts: { number }, baseline: { number }, cfg: any): { number }
	local n = #trip
	if #posts ~= n then error("one post per lane", 2) end
	for _, p in posts do
		if type(p) ~= "number" or p % 1 ~= 0 or p < 1 or p > #baseline then
			error(string.format("post %s out of range 1..%d", tostring(p), #baseline), 2)
		end
	end
	local out = table.create(n, 0)
	if not cfg.enabled then return out end
	local adj = table.create(n)
	for i = 1, n do adj[i] = trip[i] - baseline[posts[i]] end
	local total = 0
	for i = 1, n do total = total + adj[i] end
	local mean = total / n
	for i = 1, n do
		local v = cfg.scale * (adj[i] - mean)
		out[i] = math.min(cfg.ceiling, math.max(cfg.floor, v))
	end
	return out
end

-- Results line "Good trip": three stars, two, or one (never zero).
function Trip.stars(t: number, cfg: any): number
	if t >= cfg.stars[1] then return 3 end
	if t >= cfg.stars[2] then return 2 end
	return 1
end

-- Race helpers (Luau only; RaceService) ------------------------------------------------------

-- The race numbers Trip reads, from GameConfig.
function Trip.raceParams(config: any): any
	local view = config.raceView
	return {
		speed = config.raceSpeedStudsPerSecond,
		leadFeetPerShare = config.raceShape.leadFeetPerShare,
		lanes = config.lanes,
		viewEasePerSecond = view.easePerSecond,
		maxGapFeetPerSecond = view.maxGapFeetPerSecond,
		catchUpMarginSeconds = view.catchUpMarginSeconds,
	}
end

-- How a rider rides this race (S3). The ◀ ▶ buttons show from their introRaces + 1-th race that
-- counts (data.totals.races, the races before this one; Practice doesn't count), the first time
-- with the ghost-thumb tip (data.flags.steerTip once shown). kind: "intro" (no buttons yet: Smart
-- Steer whatever Settings says, and tau 0, since they can't affect their trip), "smart" (buttons,
-- Smart Steer on) or "manual" (buttons, Smart Steer turned off: lanes change only on presses).
-- A missing profile counts as a first race.
function Trip.riderControls(data: any?, steer: any): { shown: boolean, smart: boolean, tip: boolean, kind: string }
	local races = if data ~= nil and type(data.totals) == "table" then tonumber(data.totals.races) or 0 else 0
	local shown = data ~= nil and races >= steer.introRaces
	local off = shown and type(data.settings) == "table" and data.settings.smartSteer == false
	local kind = if not shown then "intro" elseif off then "manual" else "smart"
	local seen = data ~= nil and type(data.flags) == "table" and data.flags.steerTip == true
	return { shown = shown, smart = kind ~= "manual", tip = shown and not seen, kind = kind }
end

-- A race's trip, built after the posts are drawn (lane index = post), or nil when steering is
-- off (GameConfig.steering.enabled = false: today's race exactly, nothing drawn). Draws two
-- uniforms per lane from the race's generator, after every other gate draw. Bots use Smart Steer
-- with variety. riders = lane id -> Trip.riderControls kind; a rider not listed rides "smart".
function Trip.start(config: any, session: any, track: any, plan: any, baselineRow: { number }, rng: Rng, TrackLayout: any,
	riders: { [string]: string }?): any
	local steer = config.steering
	if not steer or not steer.enabled then return nil end
	local n = #session.lanes
	local uniforms = table.create(2 * n)
	for k = 1, 2 * n do uniforms[k] = rng:NextNumber() end
	local posts, kinds, riderKind = table.create(n), table.create(n), {}
	for i, lane in session.lanes do
		posts[i] = i
		local kind = if lane.isBot then "bot" else (riders and riders[lane.id]) or "smart"
		if not lane.isBot then riderKind[i] = kind end
		kinds[i] = if kind == "intro" then "smart" else kind
	end
	local race = Trip.raceParams(config)
	local geo = TrackLayout.phaseA(track, plan)
	local st = Trip.new(posts, session.q, uniforms, geo, steer, kinds, race)
	st.tick = 0                    -- the next fixed tick to step
	st.dt = 1 / steer.tickHz
	st.lockT = Trip.lockTime(geo, race)
	st.baselineRow = baselineRow
	st.shown = table.clone(st.x)     -- lanes on screen after the lock (cosmetic, see Trip.cosmetic)
	st.shownTgt = table.clone(st.tgt)
	st.view = table.clone(st.off)
	-- Rider requests (S3): waiting for their tick { lane, dir, arrival }, the last seq and recent
	-- arrival times per lane (the spam limit), and the answers given so far (for the race log).
	st.riderKind = riderKind -- lane -> "intro" | "smart" | "manual" (riders only)
	st.pending = {}
	st.seq = table.create(n, -math.huge)
	st.ack = table.create(n, 0) -- the last seq answered per lane (applied on a tick, or dropped as spam)
	st.recent = table.create(n)
	for i = 1, n do st.recent[i] = {} end
	st.requestsPerSecond = steer.requestsPerSecond
	st.answers = {}
	return st
end

-- A SteerRequest from a player (S3), checked as it arrives: the player rides in this race (a
-- rider's lane, never a bot's), it's before the lock, dir is -1 (in) or 1 (out), seq rises, and
-- the rider has sent fewer than requestsPerSecond in the last second (spam is dropped). A request
-- that passes waits for the next fixed tick, which applies the waiting requests in arrival order
-- through Trip.step (acceptIntent: the request gap, the queue, the track's edges; every press
-- there pauses Smart Steer for resumeSeconds). t = race time of arrival; a press before the gate
-- (during the countdown) is refused. Returns "sent", or why not: "notRacing", "locked", "invalid",
-- "early", "spam". The rider's screen learns each answer from st.ack (SteerLane).
function Trip.submit(st: any, session: any, userId: string, d: any, seq: any, t: number): string
	local i = session:laneIndex(userId)
	if i == nil or session.lanes[i].isBot then return "notRacing" end
	if st.locked or t >= st.lockT - EPS then return "locked" end
	if d ~= 1 and d ~= -1 then return "invalid" end
	if type(seq) ~= "number" or seq ~= seq or seq <= st.seq[i] then return "invalid" end
	st.seq[i] = seq
	if t < 0 then
		st.ack[i] = seq
		return "early"
	end
	local recent = st.recent[i]
	while #recent > 0 and t - recent[1] >= 1 do table.remove(recent, 1) end
	if #recent >= st.requestsPerSecond then
		st.ack[i] = seq
		return "spam"
	end
	table.insert(recent, t)
	table.insert(st.pending, { i, d, t, seq })
	return "sent"
end

-- Step every fixed tick due by race time t (seconds since the gate), with the live chances the
-- race shows now; at the lock time, lock. Returns true on the call that locks. Ticks are
-- t = k * dt whatever the server's timing, so a late server catches up with the same steps.
-- Each tick takes the requests that arrived by its time, in arrival order; requests still
-- waiting at the lock are dropped (lanes are locked).
function Trip.advance(st: any, live: { number }, t: number): boolean
	if st.locked then return false end
	while st.tick * st.dt < st.lockT - EPS and st.tick * st.dt <= t + EPS do
		local tt = st.tick * st.dt
		local due, seqs = {}, {}
		while #st.pending > 0 and st.pending[1][3] <= tt + EPS do
			local p = table.remove(st.pending, 1)
			table.insert(due, { p[1], p[2] })
			table.insert(seqs, p[4])
		end
		local answers = Trip.step(st, live, due, tt, st.dt)
		for k, a in answers do
			st.answers[a] = (st.answers[a] or 0) + 1
			local i = due[k][1]
			st.ack[i] = math.max(st.ack[i], seqs[k])
		end
		st.tick += 1
	end
	if t >= st.lockT - EPS and not (st.tick * st.dt < st.lockT - EPS) then
		Trip.lock(st)
		table.clear(st.pending)
		st.shown = table.clone(st.x)
		st.shownTgt = table.clone(st.tgt) -- a glide under way at the bell finishes on screen
		st.view = table.clone(st.off)     -- the screen showed Trip's offsets up to now
		return true
	end
	return false
end

-- tau for this race at the lock. Riders still without buttons ("intro") get 0 after the clamp:
-- they couldn't affect their trip. Everyone else (bots included) keeps theirs.
function Trip.raceTau(st: any): { number }
	local tau = Trip.tau(Trip.tripValues(st), st.posts, st.baselineRow, st.cfg)
	for i, kind in st.riderKind do
		if kind == "intro" then tau[i] = 0 end
	end
	return tau
end

-- After the lock the screen eases each horse toward the race shape's offsets (RaceView: eased at
-- viewEasePerSecond, capped at maxGapFeetPerSecond unless catching up by the line). The server
-- keeps the same eased copy (st.view, carried on from Trip's offsets at the lock, which is what
-- the screen showed then) so the make-room lanes act on what kids actually see. Substeps of
-- 1/60 s follow a 60 fps client closely.
local VIEW_SUBSTEP = 1 / 60
local HOLD_RELEASE_SECONDS = 1 -- holds let go this long before the line, so the order there is the result
local MAKE_WAY_DEPTH = 3       -- how far a boxed-in horse's way out may be cleared (Trip.cosmetic)

-- A horse on screen may not run through the one ahead in its lane: it sits holdGap behind until
-- the make-room lanes let it out (as Trip holds before the lock).
local function holdView(st: any)
	local band, gap = st.cfg.laneBand, st.cfg.holdGap
	local view, x = st.view, st.shown
	local ord = table.create(st.n)
	for i = 1, st.n do ord[i] = i end
	table.sort(ord, function(a: number, b: number): boolean
		if view[a] ~= view[b] then return view[a] > view[b] end
		if x[a] ~= x[b] then return x[a] < x[b] end
		return a < b
	end)
	for a = 1, st.n do
		local i = ord[a]
		for b = 1, a - 1 do
			local j = ord[b]
			if math.abs(x[i] - x[j]) < band and view[j] - view[i] < gap then view[i] = view[j] - gap end
		end
	end
end

function Trip.viewStep(st: any, targets: { number }, dt: number, toLine: number)
	local race = st.race
	local margin = race.catchUpMarginSeconds
	local left, tl = dt, toLine
	while left > 1e-9 do
		local h = math.min(VIEW_SUBSTEP, left)
		local k = math.min(1, h * race.viewEasePerSecond)
		local allowed = race.maxGapFeetPerSecond * h
		for i = 1, st.n do
			local gap = targets[i] - st.view[i]
			local limit = if tl <= margin then math.huge else math.max(allowed, math.abs(gap) * h / (tl - margin))
			st.view[i] += math.clamp(gap * k, -limit, limit)
		end
		left -= h
		tl -= h
		if tl > HOLD_RELEASE_SECONDS then holdView(st) end
	end
end

-- j, ahead of i on screen in i's lane, is in i's way: i is held behind it (closer than holdGap)
-- or closing on it (i's place is not holdGap behind j's) from less than the look-ahead apart.
local function inWay(st: any, i: number, j: number, targets: { number }): boolean
	local d = st.view[j] - st.view[i]
	return d < st.cfg.holdGap or (targets[i] > targets[j] - st.cfg.holdGap and d < st.lookahead)
end

-- After the lock, lanes are cosmetic: they make room so horses passing on screen (the race
-- shape's luck blend) never run through each other. Working on the shown offsets (st.view, held
-- by viewStep), the horse behind on screen in a meeting glides to the nearest free lane it can
-- reach across lanes clear of nearby horses (outward first); boxed in, a horse in its way moves
-- over instead (up to MAKE_WAY_DEPTH deep), else it stays held. Decided again each tick. Never
-- touches the trip or tau. t = race time (seconds since the gate). Returns the lanes to show.
function Trip.cosmetic(st: any, targets: { number }, dt: number, t: number): { number }
	local cfg, n = st.cfg, st.n
	local band = cfg.laneBand
	Trip.viewStep(st, targets, dt, st.geo.length / st.speed - t)
	local view, x, tgt = st.view, st.shown, st.shownTgt
	local ord = table.create(n)
	for i = 1, n do ord[i] = i end
	table.sort(ord, function(a: number, b: number): boolean
		if view[a] ~= view[b] then return view[a] > view[b] end
		if x[a] ~= x[b] then return x[a] < x[b] end
		return a < b
	end)
	local clear = cfg.clearFeet
	local cross = 2 * st.race.maxGapFeetPerSecond * cfg.laneSeconds -- closing while crossing a lane
	local function inLane(j: number, lane: number): boolean
		return math.abs(x[j] - lane) < band or tgt[j] == lane
	end
	-- j stands in i's way in `lane`: alongside (within clearFeet), or ahead and being closed on.
	-- (A horse i will stay behind may be a little under holdGap ahead: the hold eases i back a
	-- foot or two.) A horse behind i there adapts in turn (held, or moving over).
	local function blocks(i: number, j: number, lane: number): boolean
		if j == i or not inLane(j, lane) then return false end
		local d = view[j] - view[i]
		return math.abs(d) < clear or (d > 0 and targets[i] > targets[j] - cfg.holdGap and d < st.lookahead)
	end
	local function free(i: number, lane: number): boolean
		for j = 1, n do
			if blocks(i, j, lane) then return false end
		end
		return true
	end
	-- i can glide across `lane` now: nobody in it near enough to meet i while it crosses.
	local function passable(i: number, lane: number): boolean
		for j = 1, n do
			if j ~= i and inLane(j, lane) and math.abs(view[j] - view[i]) < clear + cross then return false end
		end
		return true
	end
	-- The nearest free lane i can reach across passable lanes, outward first at equal distance.
	local function findLane(i: number): number?
		for dist = 1, st.lanes - 1 do
			for _, dir in { 1, -1 } do
				local lane = tgt[i] + dir * dist
				if lane >= 1 and lane <= st.lanes and free(i, lane) then
					local ok = true
					for m = 1, dist - 1 do
						if not passable(i, tgt[i] + dir * m) then ok = false end
					end
					if ok then return lane end
				end
			end
		end
		return nil
	end
	-- Boxed in: open a way for i by moving one horse over, one move per tick. First the horse it
	-- is catching (to any free lane), then a horse blocking a lane beside i (further away from
	-- i); with depth to spare, a horse blocking that horse's way out, and so on.
	local function clearLane(i: number, catching: number?, depth: number): boolean
		if catching and x[catching] == tgt[catching] then
			local other = findLane(catching)
			if other then
				tgt[catching] = other
				return true
			end
		end
		for _, dir in { 1, -1 } do
			local side = tgt[i] + dir
			if side >= 1 and side <= st.lanes then
				for j = 1, n do
					if x[j] == tgt[j] and blocks(i, j, side) then
						local other = findLane(j)
						if other and (other - side) * dir > 0 then
							tgt[j] = other
							return true
						end
						if depth > 1 and clearLane(j, nil, depth - 1) then return true end
					end
				end
			end
		end
		return false
	end
	for a = 1, n do
		local i = ord[a]
		if x[i] == tgt[i] then
			local blocker = nil
			for b = 1, a - 1 do -- horses ahead on screen (or level and earlier): i gives way
				local j = ord[b]
				if inLane(j, x[i]) and inWay(st, i, j, targets) then blocker = j end
			end
			if blocker then
				local lane = findLane(i)
				if lane then
					tgt[i] = lane
				else
					clearLane(i, blocker, MAKE_WAY_DEPTH) -- if nothing can move, it is held until a lane opens
				end
			end
		end
	end
	local glide = dt / cfg.laneSeconds
	for i = 1, n do
		if x[i] ~= tgt[i] then
			local diff = tgt[i] - x[i]
			if math.abs(diff) <= glide + EPS then
				x[i] = tgt[i]
			else
				x[i] = x[i] + (if diff > 0 then glide else -glide)
			end
		end
	end
	return table.clone(x)
end

-- Lanes as sent: rounded to 0.01 lane (0.06 ft, invisible; smaller packets).
local function sendLanes(x: { number }): { number }
	local out = table.create(#x)
	for i, v in x do out[i] = math.floor(v * 100 + 0.5) / 100 end
	return out
end

-- What RaceOffsets carries now (t = race time), which the screen shows as sent: before the lock,
-- Trip's offsets and lanes; after it, the race shape's offsets (live chances, late on luck) as
-- the screen eases them, held so none runs through another, and the make-room lanes. With no
-- trip (steering off) the race shape's offsets alone, exactly as before steering (lanes = nil).
function Trip.frame(st: any, session: any, shownLive: { number }, w: number, shapeCfg: any, dt: number, t: number): ({ number }, { number }?)
	if st == nil then return session:displayOffsets(shownLive, w, shapeCfg), nil end
	if not st.locked then return table.clone(st.off), sendLanes(st.x) end
	local lanes = Trip.cosmetic(st, session:displayOffsets(shownLive, w, shapeCfg), dt, t)
	return table.clone(st.view), sendLanes(lanes)
end

return Trip
