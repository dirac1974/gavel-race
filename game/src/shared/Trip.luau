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
-- The race helpers at the bottom (start, advance, raceTau, frame, cosmetic) are what
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

-- A race's trip, built after the posts are drawn (lane index = post), or nil when steering is
-- off (GameConfig.steering.enabled = false: today's race exactly, nothing drawn). Draws two
-- uniforms per lane from the race's generator, after every other gate draw. Bots use Smart Steer
-- with variety; riders use Smart Steer (no rider input until S3).
function Trip.start(config: any, session: any, track: any, plan: any, baselineRow: { number }, rng: Rng, TrackLayout: any): any
	local steer = config.steering
	if not steer or not steer.enabled then return nil end
	local n = #session.lanes
	local uniforms = table.create(2 * n)
	for k = 1, 2 * n do uniforms[k] = rng:NextNumber() end
	local posts, kinds = table.create(n), table.create(n)
	for i, lane in session.lanes do
		posts[i] = i
		kinds[i] = if lane.isBot then "bot" else "smart"
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
	return st
end

-- Step every fixed tick due by race time t (seconds since the gate), with the live chances the
-- race shows now; at the lock time, lock. Returns true on the call that locks. Ticks are
-- t = k * dt whatever the server's timing, so a late server catches up with the same steps.
function Trip.advance(st: any, live: { number }, t: number): boolean
	if st.locked then return false end
	while st.tick * st.dt < st.lockT - EPS and st.tick * st.dt <= t + EPS do
		Trip.step(st, live, {}, st.tick * st.dt, st.dt)
		st.tick += 1
	end
	if t >= st.lockT - EPS and not (st.tick * st.dt < st.lockT - EPS) then
		Trip.lock(st)
		st.shown = table.clone(st.x)
		st.shownTgt = table.clone(st.tgt) -- a glide under way at the bell finishes on screen
		return true
	end
	return false
end

-- tau for this race at the lock.
function Trip.raceTau(st: any): { number }
	return Trip.tau(Trip.tripValues(st), st.posts, st.baselineRow, st.cfg)
end

-- After the lock, lanes are cosmetic: they make room so horses passing on screen (the race
-- shape's luck blend) never sit on top of each other. A horse within holdGap behind another in
-- its lane moves to the nearest free lane (outward first); glides as in the race. Never touches
-- the trip or tau. Returns the lanes to show.
function Trip.cosmetic(st: any, offsets: { number }, dt: number): { number }
	local cfg, n = st.cfg, st.n
	local band, gap = cfg.laneBand, cfg.holdGap
	local x = st.shown
	local tgt = st.shownTgt
	local ord = table.create(n)
	for i = 1, n do ord[i] = i end
	table.sort(ord, function(a: number, b: number): boolean
		if offsets[a] ~= offsets[b] then return offsets[a] > offsets[b] end
		if x[a] ~= x[b] then return x[a] < x[b] end
		return a < b
	end)
	local function free(i: number, lane: number): boolean
		for j = 1, n do
			if j ~= i and (math.abs(x[j] - lane) < band or tgt[j] == lane) and math.abs(offsets[j] - offsets[i]) < gap then
				return false
			end
		end
		return true
	end
	for a = 1, n do
		local i = ord[a]
		if x[i] == tgt[i] then
			local crowded = false
			for b = 1, a - 1 do
				local j = ord[b]
				if math.abs(x[j] - x[i]) < band and offsets[j] - offsets[i] < gap then crowded = true end
			end
			if crowded then
				for k = 1, st.lanes do
					local out, inward = tgt[i] + k, tgt[i] - k
					if out <= st.lanes and free(i, out) then
						tgt[i] = out
						break
					elseif inward >= 1 and free(i, inward) then
						tgt[i] = inward
						break
					end
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

-- What RaceOffsets carries now: before the lock, Trip's offsets and lanes; after it, the race
-- shape's offsets (from live chances and, late on, luck) and the cosmetic lanes. With no trip
-- (steering off) the offsets alone, exactly as before steering (lanes = nil).
function Trip.frame(st: any, session: any, shownLive: { number }, w: number, shapeCfg: any, dt: number): ({ number }, { number }?)
	if st == nil then return session:displayOffsets(shownLive, w, shapeCfg), nil end
	if not st.locked then return table.clone(st.off), table.clone(st.x) end
	local offsets = session:displayOffsets(shownLive, w, shapeCfg)
	return offsets, Trip.cosmetic(st, offsets, dt)
end

return Trip
