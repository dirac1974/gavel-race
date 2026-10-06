--!strict
-- Race steering trip (D-054, D-057): lanes from the gate to the far-turn lock, and the trip tau
-- that joins the win-chance exponent there (kappa * R + c + tau). Pure: no Roblox types, so it
-- runs under Lune.
--
-- Mirrors src/trip.py line by line; tests/luau/trip_tests.luau replays tests/fixtures/trip.json
-- (the game's config) and tests/luau/trip_d057_tests.luau replays tests/fixtures/trip_d057.json
-- (D-057 in full, brushes on, and the switch-back to D-054); both must agree to 1e-9 (D-012). Mirror
-- rules: lanes visited in index order; every sort uses a total key (offset, then lane position,
-- then index); step, lock and tau use only + - * /, comparisons, min, max, abs and sqrt (sqrt is
-- correctly rounded in Luau and CPython alike; only the D-057 eased glide uses it); "never" times
-- are -1e9 (and 1e9 for "no horse alongside"); fixed ticks t = k * dt.
--
-- D-057 (natural steering, boxed in, brushes) sits behind GameConfig.steering keys: N2 ported the
-- rules switched off, N3 switched the motion and press rules on (brushes stay off until N5).
-- Trip.d054Config is the switch-back.
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
local NOT_ALONG = 1e9 -- alongSince when no horse is alongside (D-057 brushes)
Trip.EPS = EPS
Trip.LONG_AGO = LONG_AGO
Trip.NOT_ALONG = NOT_ALONG

-- D-057 on (debate 012; src/trip.py's D057): the switches N3 (motion and presses) flipped in
-- GameConfig.steering, and N5's brushes. Trip.d057Config builds the full D-057 config (brushes on)
-- for the tests and the overlap report; Trip.d054Config the switch-back, every D-057 key at its
-- D-054 value (src/trip.py's D057_OFF).
Trip.D057 = {
	glide = "eased", chainWindow = 0.3, reverseGapSeconds = 0.5, weaveGapSeconds = 2.5,
	pressBounceSeconds = 0.2, glideReserveFeet = 6, blockedPress = "wait", brush = "repeat",
}
Trip.D057_OFF = {
	glide = "linear", laneSpeedMax = 1.5, laneAccel = 4.5, chainWindow = 0, reverseGapSeconds = 0,
	weaveGapSeconds = 0, weaveWindowSeconds = 7, pressBounceSeconds = 0, glideReserveFeet = 0,
	blockedPress = "d054", gapWaitSeconds = 1.5, gapWaitInSeconds = 0, tuckAfterSeconds = 0,
	boxedAheadFeet = 12, brush = "off", brushAlongFeet = 8, brushGraceSeconds = 0.3,
	brushRepeatSeconds = 2, brushPays = "mover", brushCost = 0.002, brushFree = 1, brushMaxCharged = 3,
	brushCheckFeet = 4, brushRecoverPerSecond = 2, steadySeconds = 1,
}

local function copySteering(steering: any): any
	local cfg = table.clone(steering)
	cfg.smart, cfg.bots, cfg.stars = table.clone(steering.smart), table.clone(steering.bots), table.clone(steering.stars)
	return cfg
end

function Trip.d057Config(steering: any): any
	local cfg = copySteering(steering)
	for key, value in Trip.D057 do cfg[key] = value end
	return cfg
end

function Trip.d054Config(steering: any): any
	local cfg = copySteering(steering)
	for key, value in Trip.D057_OFF do cfg[key] = value end
	return cfg
end

local KINDS = { bot = true, smart = true, manual = true }
local GLIDES = { linear = true, eased = true }
local BLOCKED_PRESS = { d054 = true, wait = true }
local BRUSH_RULES = { off = true, ["repeat"] = true }
local BRUSH_PAYS = { mover = true, bumped = true, both = true, none = true }

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

-- How long a free glide of `dist` lanes takes (s), for the make-room look-ahead after the lock
-- (Luau only): laneSeconds a lane (D-054), or the eased S-curve's accelerate-cruise-brake time
-- plus a tick (the discrete curve lands up to a tick later; D-057).
function Trip.glideSeconds(cfg: any, dist: number): number
	if cfg.glide == "eased" then
		local a, v = cfg.laneAccel, cfg.laneSpeedMax
		if dist >= v * v / a then return dist / v + v / a + 0.1 end
		return 2 * math.sqrt(dist / a) + 0.1
	end
	return dist * cfg.laneSeconds
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
	if not GLIDES[cfg.glide] or not BLOCKED_PRESS[cfg.blockedPress] or not BRUSH_RULES[cfg.brush] or not BRUSH_PAYS[cfg.brushPays] then
		error("unknown glide, blockedPress, brush or brushPays", 2)
	end
	if cfg.glide == "eased" and (cfg.laneAccel <= 0 or cfg.laneSpeedMax <= 0) then
		error("an eased glide needs laneAccel > 0 and laneSpeedMax > 0", 2)
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
		-- D-057
		v = table.create(n, 0),                    -- sideways speed, lanes/s (eased glide)
		lastDir = table.create(n, 0),              -- direction of the last lane change started
		arrivedAt = table.create(n, LONG_AGO),     -- when the last glide landed
		lastRevAt = table.create(n, LONG_AGO),     -- when the last change opposite to the one before started
		brushes = table.create(n, 0),              -- brushes this horse started (charged or not)
		charged = table.create(n, 0),              -- brushes this horse pays for (brushCharge caps the cost)
		check = table.create(n, 0),                -- feet below the skill target after a brush (steadying)
		steadyUntil = table.create(n, LONG_AGO),
		alongSince = table.create(n),              -- { inside, outside }: since when a horse is alongside
		smartBlockAt = table.create(n, LONG_AGO),  -- since when Smart Steer's move has met no room, unbroken
		lastPressAt = table.create(n, LONG_AGO),   -- the last counted press (not a bounce)...
		lastPressDir = table.create(n, 0),         -- ...and its direction
		firstPressAt = table.create(n, LONG_AGO),  -- when the press now waiting was made
		tucking = table.create(n, false),          -- a tuck-back is under way this tick (SteerLane, N4)
		events = {},                               -- { t, "brush", mover, other, dir }, in order
	}
	for i = 1, n do
		st.x[i] = posts[i]
		st.tgt[i] = posts[i]
		st.alongSince[i] = { NOT_ALONG, NOT_ALONG }
	end
	-- After the lock (Luau only; never part of the trip): offsets, lanes and sideways speeds on
	-- screen, and the make-room look-ahead (closing at up to twice the gap cap, a glide plus a
	-- little must finish before two horses meet).
	st.view = table.clone(st.off)
	st.shown, st.shownTgt, st.shownV = table.clone(st.x), table.clone(st.tgt), table.create(n, 0)
	-- (eased) the after-lock lanes' own reverse and weave gaps (Trip.cosmetic), carried on from
	-- the trip at the bell: the last move's direction, when it last turned, when it landed.
	st.shownDir, st.shownRevAt, st.shownArrived = table.create(n, 0), table.create(n, LONG_AGO), table.create(n, LONG_AGO)
	st.lookahead = cfg.holdGap + 2 * race.maxGapFeetPerSecond * (Trip.glideSeconds(cfg, 1) + 0.2)
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

local brushTarget: (st: any, i: number, d: number, t: number) -> number
local brush: (st: any, i: number, j: number, d: number, t: number) -> ()

-- A rider's lane-change request: "accepted" (starts this tick if clear), "queued", "cancelled"
-- (the opposite of a press still waiting), or a refusal: "locked", "invalid", "bounds", "rate".
-- Every press but a locked, invalid or bounced one pauses Smart Steer for resumeSeconds.
-- D-057 answers (never with the D-054 config): "bounce" (the same way within pressBounceSeconds of
-- the last counted press: nothing happens, Smart Steer isn't paused again), "steady" (steadying
-- after a brush), "brush" (brushTarget). A change the other way waits in the queue while the horse
-- glides and for its reverse gap after landing (Trip.reverseGap).
function Trip.acceptIntent(st: any, i: number, d: any, t: number): string
	checkLane(st, i)
	local cfg = st.cfg
	if st.locked then return "locked" end
	if d ~= 1 and d ~= -1 then return "invalid" end
	if d == st.lastPressDir[i] and t - st.lastPressAt[i] < cfg.pressBounceSeconds - EPS then return "bounce" end
	st.lastPressAt[i] = t
	st.lastPressDir[i] = d
	st.manualAt[i] = t
	if t < st.steadyUntil[i] - EPS then return "steady" end
	local other = brushTarget(st, i, d, t)
	if other >= 1 then
		brush(st, i, other, d, t)
		return "brush"
	end
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
	local rgap = Trip.reverseGap(st, i, t)
	local reversing = rgap > 0 and st.lastDir[i] ~= 0 and d ~= st.lastDir[i]
		and (st.x[i] ~= st.tgt[i] or t - st.arrivedAt[i] < rgap - EPS)
	local idle = st.want[i] == 0 and st.x[i] == st.tgt[i] and t - st.lastChange[i] >= cfg.minRequestGap - EPS
		and not reversing
	if idle then
		st.want[i] = d
		st.wantAt[i] = t
		st.firstPressAt[i] = t
		return "accepted"
	end
	if st.queued[i] == 0 and cfg.maxQueued >= 1 then
		if st.want[i] == 0 then
			st.firstPressAt[i] = t -- the first press waiting (behind a glide or a reverse gap)
		end
		st.queued[i] = d
		return "queued"
	end
	return "rate"
end

-- D-057: how long a horse runs straight after landing before a change opposite to its last one:
-- reverseGapSeconds, or weaveGapSeconds for a second reversal within weaveWindowSeconds of the last.
-- 0 with the D-054 config.
function Trip.reverseGap(st: any, i: number, t: number): number
	local cfg = st.cfg
	local g = cfg.reverseGapSeconds
	if cfg.weaveGapSeconds > g and t - st.lastRevAt[i] < cfg.weaveWindowSeconds - EPS then
		g = cfg.weaveGapSeconds
	end
	return g
end

-- A change in direction d must still wait for the reverse gap.
local function reverseWait(st: any, i: number, d: number, t: number): boolean
	local g = Trip.reverseGap(st, i, t)
	return g > 0 and st.lastDir[i] ~= 0 and d ~= st.lastDir[i] and t - st.arrivedAt[i] < g - EPS
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

-- A horse may not sit closer than holdGap behind a horse sharing its lane. It settles back no
-- faster than holdPullPerSecond, counted from where it was at the start of the tick (prev): a horse
-- arriving in a lane a little close (a lane change needs clearFeet ahead, a hold keeps holdGap)
-- eases into its place over a few ticks instead of hopping back on screen. Following a horse never
-- needs more: a follower moves back with the horse ahead, at most maxGapFeetPerSecond.
local function hold(st: any, ord: { number }, prev: { number }, dt: number)
	local band, gap = st.cfg.laneBand, st.cfg.holdGap
	local pull = st.cfg.holdPullPerSecond * dt
	local off, x = st.off, st.x
	for a = 1, st.n do
		local i = ord[a]
		for b = 1, a - 1 do
			local j = ord[b]
			if math.abs(x[i] - x[j]) < band and off[j] - off[i] < gap then
				off[i] = math.max(off[j] - gap, math.min(off[i], prev[i] - pull))
			end
		end
	end
end

-- Where horse i could enter `lane`, and whether it is blocked now. A horse in that lane (or
-- gliding into it) blocks when it is less than clearFeet ahead or less than holdGap behind, so
-- the mover never pushes the horse behind it. A horse gliding into the lane keeps
-- glideReserveFeet more room on both sides (D-057; 0 = D-054). The slot is the mover's own offset
-- when nothing blocks, else holdGap behind the rearmost blocker, repeated down a line of horses.
local function slot(st: any, i: number, lane: number): (number, boolean)
	local band, clear, gap = st.cfg.laneBand, st.cfg.clearFeet, st.cfg.holdGap
	local reserve = st.cfg.glideReserveFeet
	local p = st.off[i]
	local blocked = false
	for _ = 1, st.n do
		local lowest = 0
		local found = false
		for j = 1, st.n do
			if j ~= i and (math.abs(st.x[j] - lane) < band or st.tgt[j] == lane) then
				local a = st.off[j] - p
				local cj, gj = clear, gap
				if reserve > 0 and st.tgt[j] == lane and st.x[j] ~= lane then
					cj, gj = clear + reserve, gap + reserve
				end
				if a < cj and a > -gj then
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

-- Boxed in (D-057) ----------------------------------------------------------------------------

-- Room on side d (-1 in, +1 out) by Trip's clearance rule (the glide reserve included): "free" (a
-- press moves now), "tuck" (no room, but an inward press can ease back to a slot within tuckBackMax
-- and slip in behind: the "can tuck-back help" flag) or "blocked" (the rail or the outer edge, or no
-- room and no tuck slot). N4's arrows: Out greys while not "free"; In greys only when "blocked".
function Trip.sideState(st: any, i: number, d: number): string
	checkLane(st, i)
	local lane = st.tgt[i] + d
	if lane < 1 or lane > st.lanes then return "blocked" end
	local p, blocked = slot(st, i, lane)
	if not blocked then return "free" end
	if d < 0 and st.off[i] - p <= st.cfg.tuckBackMax + EPS then return "tuck" end
	return "blocked"
end

-- A horse within `feet` ahead of horse i in its lane (by lane position).
function Trip.horseAhead(st: any, i: number, feet: number): boolean
	checkLane(st, i)
	local band = st.cfg.laneBand
	for j = 1, st.n do
		if j ~= i and math.abs(st.x[j] - st.x[i]) < band then
			local a = st.off[j] - st.off[i]
			if a > 0 and a <= feet then return true end
		end
	end
	return false
end

-- Boxed in: no room on either side and a horse within boxedAheadFeet ahead in your lane. Costs
-- nothing (no boxed-in penalty); the sims and N4's chips read it.
function Trip.boxedIn(st: any, i: number): boolean
	if not Trip.horseAhead(st, i, st.cfg.boxedAheadFeet) then return false end
	return Trip.sideState(st, i, -1) ~= "free" and Trip.sideState(st, i, 1) ~= "free"
end

-- Off the rail, no room inside and no tuck slot within tuckBackMax: what D-057 calls "trapped" for
-- the grey In arrow (boxed or not). An inward press then waits for room.
function Trip.noTuckInside(st: any, i: number): boolean
	return st.tgt[i] > 1 and Trip.sideState(st, i, -1) == "blocked"
end

-- Boxed in and noTuckInside: debate 012's "trapped" measure.
function Trip.boxedNoTuck(st: any, i: number): boolean
	return Trip.boxedIn(st, i) and Trip.noTuckInside(st, i)
end

-- Lane changes ---------------------------------------------------------------------------------

-- D-057 blockedPress = "wait": inward, the horse steadies back to the slot behind the horses
-- alongside (tuck-back, after tuckAfterSeconds) when it is within tuckBackMax; otherwise the press
-- waits for room (gapWaitInSeconds, 0 = until room). Outward, it waits gapWaitSeconds (0 = until
-- room), then drops quietly. Smart Steer never drops; smartBlockAt is its clock.
local function waitForRoom(st: any, i: number, d: number, t: number, p: number, tucking: { boolean }, manual: boolean)
	local cfg = st.cfg
	local since
	if manual then
		since = st.wantAt[i]
	else
		if st.smartBlockAt[i] == LONG_AGO then st.smartBlockAt[i] = t end
		since = st.smartBlockAt[i]
	end
	local canTuck = d < 0 and st.off[i] - p <= cfg.tuckBackMax + EPS
	if canTuck then
		if t - since >= cfg.tuckAfterSeconds - EPS then
			st.tuck[i] = math.max(0, st.skill[i] - p)
			tucking[i] = true
		end
	elseif manual then
		local limit = if d < 0 then cfg.gapWaitInSeconds else cfg.gapWaitSeconds
		if limit > 0 and t - since >= limit - EPS then
			st.want[i] = 0 -- no room came: the press drops
		end
	end
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
		if st.lastDir[i] ~= 0 and d ~= st.lastDir[i] then st.lastRevAt[i] = t end
		st.lastDir[i] = d
		st.smartBlockAt[i] = LONG_AGO
		if manual then st.want[i] = 0 end
		return true
	end
	if cfg.blockedPress == "wait" then
		waitForRoom(st, i, d, t, p, tucking, manual)
		return false
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

-- Brushes (D-057) ----------------------------------------------------------------------------

-- The horse alongside horse i in the next lane on side d (in it by laneBand or gliding into it,
-- within brushAlongFeet lengthwise), or 0: the nearest, ties to the lower index. The rail and the
-- outer edge are not horses.
local function alongside(st: any, i: number, d: number): number
	local lane = st.tgt[i] + d
	if lane < 1 or lane > st.lanes then return 0 end
	local band, along = st.cfg.laneBand, st.cfg.brushAlongFeet
	local best, bestGap = 0, 0
	for j = 1, st.n do
		if j ~= i and (math.abs(st.x[j] - lane) < band or st.tgt[j] == lane) then
			local g = math.abs(st.off[j] - st.off[i])
			if g < along and (best < 1 or g < bestGap) then
				best, bestGap = j, g
			end
		end
	end
	return best
end

-- Since when each horse has had a horse alongside on each side (after the first hold).
local function trackAlongside(st: any, t: number)
	for i = 1, st.n do
		for side = 1, 2 do
			local j = alongside(st, i, if side == 1 then -1 else 1)
			if j < 1 then
				st.alongSince[i][side] = NOT_ALONG
			elseif st.alongSince[i][side] == NOT_ALONG then
				st.alongSince[i][side] = t
			end
		end
	end
end

-- The horse a press by rider i in direction d brushes, or 0. A brush needs all of: brush =
-- "repeat"; fewer than brushFree + brushMaxCharged brushes so far; the mover at rest; its first
-- press the same way still waiting (want == d), made at most brushRepeatSeconds ago; a horse
-- alongside on that side for at least brushGraceSeconds; and no tuck-back possible (outward, or
-- inward with no slot within tuckBackMax, and not tucking already). So a first press never
-- brushes, Smart Steer and bots (who never press) never brush, and nothing brushes after the lock
-- (acceptIntent refuses first).
brushTarget = function(st: any, i: number, d: number, t: number): number
	local cfg = st.cfg
	if cfg.brush == "off" then return 0 end
	if st.brushes[i] >= cfg.brushFree + cfg.brushMaxCharged then return 0 end
	if st.x[i] ~= st.tgt[i] or st.want[i] ~= d then return 0 end
	if cfg.brushRepeatSeconds > 0 and t - st.firstPressAt[i] > cfg.brushRepeatSeconds + EPS then return 0 end
	local side = if d < 0 then 1 else 2
	local j = alongside(st, i, d)
	if j < 1 or t - st.alongSince[i][side] < cfg.brushGraceSeconds - EPS then return 0 end
	if st.tuck[i] > 0 then return 0 end
	if d < 0 then
		local p = slot(st, i, st.tgt[i] - 1)
		if st.off[i] - p <= cfg.tuckBackMax + EPS then return 0 end
	end
	return j
end

-- Horse i brushes horse j. The mover's waiting presses clear and it can't steer for steadySeconds.
-- Each payer (brushPays: the mover in D-057) is charged and steadies back brushCheckFeet in Trip's
-- offsets.
brush = function(st: any, i: number, j: number, d: number, t: number)
	local cfg = st.cfg
	st.brushes[i] = st.brushes[i] + 1
	st.steadyUntil[i] = t + cfg.steadySeconds
	st.want[i] = 0
	st.queued[i] = 0
	local pays = cfg.brushPays
	if pays == "mover" or pays == "both" then
		st.charged[i] = st.charged[i] + 1
		st.check[i] = st.check[i] + cfg.brushCheckFeet
	end
	if pays == "bumped" or pays == "both" then
		st.charged[j] = st.charged[j] + 1
		st.check[j] = st.check[j] + cfg.brushCheckFeet
	end
	table.insert(st.events, { t, "brush", i, j, d })
end

-- Horse i's brush cost: brushCost per brush it pays for after the first brushFree, at most
-- brushMaxCharged of them. Fixed at the lock (nothing brushes after it).
function Trip.brushCharge(st: any, i: number): number
	checkLane(st, i)
	local cfg = st.cfg
	local charged = math.min(math.max(0, st.charged[i] - cfg.brushFree), cfg.brushMaxCharged)
	return cfg.brushCost * charged
end

function Trip.brushCharges(st: any): { number }
	local out = table.create(st.n)
	for i = 1, st.n do out[i] = Trip.brushCharge(st, i) end
	return out
end

-- The glide --------------------------------------------------------------------------------

-- D-054: one lane per laneSeconds, starting and stopping at once.
local function glideLinear(st: any, t: number, dt: number)
	local glide = dt / st.cfg.laneSeconds
	for i = 1, st.n do
		if st.x[i] ~= st.tgt[i] then
			local diff = st.tgt[i] - st.x[i]
			if math.abs(diff) <= glide + EPS then
				st.x[i] = st.tgt[i]
				st.arrivedAt[i] = t + dt
			elseif diff > 0 then
				st.x[i] = st.x[i] + glide
			else
				st.x[i] = st.x[i] - glide
			end
		end
	end
end

-- One eased step for lane i of (x, tgt, v): sideways speed changes by at most adt a tick, caps at
-- vmax and brakes in time to land; vb is the speed from which steps of adt a tick stop exactly in
-- the distance left. Returns true when the horse lands this step (snapped to its lane). Shared by
-- the trip (glideEased) and the make-room lanes after the lock (Trip.cosmetic).
local function easeStep(x: { number }, tgt: { number }, v: { number }, i: number, dt: number, adt: number, vmax: number): boolean
	local diff = tgt[i] - x[i]
	local dist = math.abs(diff)
	if dist <= EPS then
		x[i] = tgt[i]
		v[i] = 0
		return true
	end
	local sgn = if diff > 0 then 1 else -1
	local vb = adt * (math.sqrt(0.25 + 2 * dist / (adt * dt)) - 0.5)
	local vdes = sgn * math.min(vmax, vb)
	v[i] = v[i] + math.min(adt, math.max(-adt, vdes - v[i]))
	local nx = x[i] + v[i] * dt
	if (nx - tgt[i]) * sgn >= -EPS then
		x[i] = tgt[i]
		v[i] = 0
		return true
	end
	x[i] = nx
	return false
end

-- D-057 S-curve (a chained change only moves tgt further, so the horse keeps its speed).
local function glideEased(st: any, t: number, dt: number)
	local cfg = st.cfg
	local adt = cfg.laneAccel * dt
	local vmax = cfg.laneSpeedMax
	for i = 1, st.n do
		if not (st.x[i] == st.tgt[i] and st.v[i] == 0) then
			if easeStep(st.x, st.tgt, st.v, i, dt, adt, vmax) then st.arrivedAt[i] = t + dt end
		end
	end
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
	local prev = table.clone(st.off) -- where every horse was at the start of the tick (holds settle from here)
	-- 1. Skill targets (gaps ramp in from the gate), minus any tuck-back and brush steadying;
	--    offsets move toward them as the race view moves gaps (eased, capped unless catching up by
	--    the line).
	local ramp = 1
	if cfg.gapRampSeconds > 0 then ramp = math.min(1, t / cfg.gapRampSeconds) end
	local fair = 1 / n
	local k = math.min(1, dt * race.viewEasePerSecond)
	local toLine = st.geo.length / st.speed - t
	local allowed = race.maxGapFeetPerSecond * dt
	local margin = race.catchUpMarginSeconds
	for i = 1, n do
		st.skill[i] = st.lead * (live[i] - fair) * ramp
		local gap = st.skill[i] - st.tuck[i] - st.check[i] - st.off[i]
		local limit
		if toLine <= margin then
			limit = math.huge
		else
			limit = math.max(allowed, math.abs(gap) * dt / (toLine - margin))
		end
		st.off[i] = st.off[i] + math.min(limit, math.max(-limit, gap * k))
	end
	-- 2. Hold: nobody overlaps the horse ahead in its lane. Then who is alongside whom (brushes).
	hold(st, order(st), prev, dt)
	local ord = order(st)
	if cfg.brush ~= "off" then trackAlongside(st, t) end
	-- 3. Lane changes: this tick's requests in arrival order, then everyone else leader first,
	--    then the inside horse. A horse gliding may start a same-way change within chainWindow of
	--    landing (D-057); a change the other way waits for the landing and the reverse gap.
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
	local chain = cfg.chainWindow
	local gapsOn = cfg.reverseGapSeconds > 0 or cfg.weaveGapSeconds > 0
	local smartWaiting = table.create(n, false)
	for a = 1, n do
		local i = ord[a]
		if tried[i] then continue end
		local moving = st.x[i] ~= st.tgt[i]
		local mdir = 0
		if moving then
			if chain <= 0 or math.abs(st.tgt[i] - st.x[i]) > chain + EPS then continue end
			mdir = if st.tgt[i] > st.x[i] then 1 else -1
		end
		if t - st.lastChange[i] < cfg.minRequestGap - EPS then continue end
		if st.want[i] == 0 and st.queued[i] ~= 0 then
			if moving and st.queued[i] ~= mdir then continue end
			st.want[i] = st.queued[i]
			st.wantAt[i] = t
			st.queued[i] = 0
		end
		if st.want[i] ~= 0 then
			local d = st.want[i]
			if moving and d ~= mdir then continue end
			if gapsOn and reverseWait(st, i, d, t) then
				st.wantAt[i] = t -- the wait for room starts once the horse may move
				continue
			end
			tryMove(st, i, d, t, tucking, true)
		elseif st.smart[i] and t - st.manualAt[i] >= resume - EPS and st.tgt[i] > st.home[i] then
			-- Smart Steer: heads in before and through turns, never out, never for a draft.
			if moving and mdir ~= -1 then continue end
			if not (inTurn or toTurn <= st.turnLead[i] * st.speed + EPS) then continue end
			if gapsOn and reverseWait(st, i, -1, t) then continue end
			if not tryMove(st, i, -1, t, tucking, false) then smartWaiting[i] = true end
		end
	end
	-- Smart Steer's wait clock (smartBlockAt, set only by blockedPress "wait") measures one unbroken
	-- wait: a tick on which it didn't try and fail clears it, so a later block starts a fresh wait.
	if cfg.blockedPress == "wait" then
		for i = 1, n do
			if not smartWaiting[i] then st.smartBlockAt[i] = LONG_AGO end
		end
	end
	-- 4. Lateral glide, then hold again so a horse arriving in a lane never overlaps.
	if cfg.glide == "eased" then
		glideEased(st, t, dt)
	else
		glideLinear(st, t, dt)
	end
	hold(st, ord, prev, dt)
	local release = cfg.tuckReleasePerSecond * dt
	for i = 1, n do
		if not tucking[i] and st.tuck[i] > 0 then
			st.tuck[i] = math.max(0, st.tuck[i] - release)
		end
	end
	if cfg.brush ~= "off" then
		local recover = cfg.brushRecoverPerSecond * dt
		for i = 1, n do
			if st.check[i] > 0 then st.check[i] = math.max(0, st.check[i] - recover) end
		end
	end
	st.tucking = tucking
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

-- The far-turn bell: book the far turn from each horse's lane position, freeze the trip. Waiting
-- presses and any steadying after a brush clear; brush charges are fixed.
function Trip.lock(st: any)
	if st.locked then return end
	local g = st.cfg.groundPerLaneTurn
	for i = 1, st.n do
		st.ground[i] = st.ground[i] + g * (st.x[i] - 1)
		st.want[i] = 0
		st.queued[i] = 0
		st.steadyUntil[i] = LONG_AGO
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

-- tau_i = clamp(scale * (trip_i - baseline[post_i] - field mean of the same) - scale * brush_i,
-- floor, ceiling). baseline = the per-post row for this course and distance (TripBaseline). brush
-- = Trip.brushCharges (D-057): the mover's own cost, after the field mean (a brush never moves
-- anyone else's tau) and inside the clamp; nil or zeros change nothing.
function Trip.tau(trip: { number }, posts: { number }, baseline: { number }, cfg: any, brushCost: { number }?): { number }
	local n = #trip
	if #posts ~= n then error("one post per lane", 2) end
	if brushCost ~= nil and #brushCost ~= n then error("one brush charge per lane", 2) end
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
		if brushCost ~= nil then v = v - cfg.scale * brushCost[i] end
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
	st.shownV = table.create(n, 0)   -- their sideways speeds (the eased glide, D-057)
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
	-- For the [Trip] log line (D-057): rider presses the other way held by a reverse or weave gap,
	-- and rider presses that waited for room and dropped (an outward press after gapWaitSeconds).
	st.gapHeld, st.waitDropped = 0, 0
	return st
end

-- What a rider with the buttons hears about their own lane (SteerLane, D-054 S3 and D-057 N4),
-- Luau only (reporting, not the mirrored model): the lane taken (tgt), where it ends once every
-- waiting press is done (dest), the last press answered (ack), a press waiting for room (wait: its
-- direction, 0 if none; waitAt: the race time its wait for room starts), whether a tuck-back is
-- under way (tucking), each side's room (inSide, outSide): "free", "tuck" (inward: no room, but
-- tuck-back finds a slot), "blocked" (a horse is in the way and tuck-back can't help) or "edge"
-- (the rail or the outside: no lane there), and t = the race time the state stands for (the tick
-- count times dt), so the screen times waits by the server's clock, never by arrival.
-- A press held by a reverse or weave gap has its wantAt reset every tick (the model's wait for room
-- starts once the horse may move); waitAt reports when that hold ends instead, so it stays steady
-- (no resend every tick, no flickering ring) and a wait never looks shorter than it was.
-- Fills `out` (no allocation) and returns it.
local function riderSide(st: any, i: number, d: number): string
	local lane = st.tgt[i] + d
	if lane < 1 or lane > st.lanes then return "edge" end
	return Trip.sideState(st, i, d)
end

function Trip.riderLane(st: any, i: number, out: any, t: number): any
	out.tgt, out.dest, out.ack = st.tgt[i], Trip.laneAfter(st, i), if st.ack then st.ack[i] else 0
	local w = st.want[i]
	out.wait = w
	out.waitAt = 0
	if w ~= 0 then
		local at = st.wantAt[i]
		if st.lastDir[i] ~= 0 and w ~= st.lastDir[i] then
			local g = Trip.reverseGap(st, i, t)
			if g > 0 then at = math.max(at, st.arrivedAt[i] + g) end -- (held by the gap until then)
		end
		out.waitAt = at
	end
	out.tucking = st.tucking[i] == true
	out.inSide, out.outSide = riderSide(st, i, -1), riderSide(st, i, 1)
	out.t = t
	return out
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
		local held, wanted, wantTgt, pressed = {}, {}, {}, {}
		for k, p in due do
			local i, d = p[1], p[2]
			local g = Trip.reverseGap(st, i, tt)
			held[k] = g > 0 and st.lastDir[i] ~= 0 and d ~= st.lastDir[i]
				and (st.x[i] ~= st.tgt[i] or tt - st.arrivedAt[i] < g - EPS)
			pressed[i] = true
		end
		for i in st.riderKind or {} do wanted[i], wantTgt[i] = st.want[i], st.tgt[i] end
		local answers = Trip.step(st, live, due, tt, st.dt)
		for k, a in answers do
			st.answers[a] = (st.answers[a] or 0) + 1
			local i = due[k][1]
			st.ack[i] = math.max(st.ack[i], seqs[k])
			if held[k] and a == "queued" then st.gapHeld += 1 end
		end
		for i, w in wanted do
			if w ~= 0 and st.want[i] == 0 and st.tgt[i] == wantTgt[i] and not pressed[i] then st.waitDropped += 1 end
		end
		st.tick += 1
	end
	if t >= st.lockT - EPS and not (st.tick * st.dt < st.lockT - EPS) then
		Trip.lock(st)
		table.clear(st.pending)
		st.shown = table.clone(st.x)
		st.shownTgt = table.clone(st.tgt) -- a glide under way at the bell finishes on screen...
		st.shownV = table.clone(st.v)     -- ...at its speed (the eased glide carries on, D-057)
		st.shownLanded = {}               -- a horse that landed on the last tick rests a tick (Trip.cosmetic)
		st.shownDir = table.clone(st.lastDir)        -- and the reverse and weave gaps carry on
		st.shownRevAt = table.clone(st.lastRevAt)
		st.shownArrived = table.clone(st.arrivedAt)
		for i = 1, st.n do
			if st.arrivedAt[i] >= st.tick * st.dt - 1e-6 then st.shownLanded[i] = true end
		end
		st.view = table.clone(st.off)     -- the screen showed Trip's offsets up to now
		return true
	end
	return false
end

-- tau for this race at the lock, with each mover's brush cost (D-057; all zero while brushes
-- are off). Riders still without buttons ("intro") get 0 after the clamp: they couldn't affect
-- their trip. Everyone else (bots included) keeps theirs.
function Trip.raceTau(st: any): { number }
	local tau = Trip.tau(Trip.tripValues(st), st.posts, st.baselineRow, st.cfg, Trip.brushCharges(st))
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
Trip.halfSteps = true          -- the S4 half-lane step at the finish (tests compare it on and off)

-- A horse on screen may not run through the one ahead in its lane: it sits holdGap behind until
-- the make-room lanes let it out (as Trip holds before the lock). A horse taking a half-lane step
-- (S4) is in neither lane once it is more than 0.45 lanes from the other horse: holding it (or its
-- new neighbour) back then would jerk one of them backwards on screen. And a hold never pulls a
-- horse back faster than holdPullPerSecond, as Trip's own holds (S4 review, pre-lock hop fix):
-- following a horse needs no more than that, so only a sudden snap (two horses meeting in a lane
-- closer than holdGap) is spread over a few frames instead of a jerk. before = offsets at the start
-- of this substep of h s.
local function holdView(st: any, before: { number }, h: number)
	local band, gap = st.cfg.laneBand, st.cfg.holdGap
	local view, x, tgt = st.view, st.shown, st.shownTgt
	local pull = st.cfg.holdPullPerSecond * h
	local ord = table.create(st.n)
	for i = 1, st.n do ord[i] = i end
	table.sort(ord, function(a: number, b: number): boolean
		if view[a] ~= view[b] then return view[a] > view[b] end
		if x[a] ~= x[b] then return x[a] < x[b] end
		return a < b
	end)
	local eased = st.cfg.glide == "eased"
	for a = 1, st.n do
		local i = ord[a]
		for b = 1, a - 1 do
			local j = ord[b]
			local apart = math.abs(x[i] - x[j])
			-- (eased: only once the step is done; the S-curve takes its last 0.05 lane slowly, and a
			-- horse closing in meanwhile would still be within half a lane)
			local halfway = (tgt[i] % 1 ~= 0 or tgt[j] % 1 ~= 0) and (if eased then apart >= 0.5 - 1e-9 else apart > 0.45)
			-- (eased) two horses gliding into the same lane share it already: a 1.0 s glide from
			-- either side would otherwise meet before the hold sees them in one lane.
			local shared = apart < band or (eased and tgt[i] == tgt[j] and x[i] ~= x[j])
			if shared and not halfway and view[j] - view[i] < gap then
				view[i] = math.max(view[j] - gap, math.min(view[i], before[i] - pull))
			end
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
		local before = table.clone(st.view)
		for i = 1, st.n do
			local gap = targets[i] - st.view[i]
			local limit = if tl <= margin then math.huge else math.max(allowed, math.abs(gap) * h / (tl - margin))
			st.view[i] += math.clamp(gap * k, -limit, limit)
		end
		left -= h
		tl -= h
		if tl > HOLD_RELEASE_SECONDS then holdView(st, before, h) end
	end
end

-- After the lock, lanes are cosmetic: they make room so horses passing on screen (the race
-- shape's luck blend) never run through each other. Working on the shown offsets (st.view, held
-- by viewStep), the horse behind on screen in a meeting glides to the nearest free lane it can
-- reach across lanes clear of nearby horses (outward first); boxed in, a horse in its way moves
-- over instead (up to MAKE_WAY_DEPTH deep), else it stays held. In the last moments, when holds let
-- go so the order across the line is the result, a horse still boxed in edges half a lane over if
-- nobody is there (S4): it may finish less than a length behind the horse ahead in its lane, and
-- then the two finish staggered instead of through each other. Decided again each tick. Never
-- touches the trip or tau. t = race time (seconds since the gate). Returns the lanes to show.
--
-- With the eased glide (D-057) the after-lock lanes move like the trip's:
-- * the same S-curve (Trip's easeStep on st.shownV), so nothing slides at once;
-- * a horse starts a new move only from rest, never on the tick it lands (it rests a tick:
--   landing and setting straight off the other way drew 47 ft/s^2), and a move the other way
--   waits the trip's reverse gap after landing, or its weave gap for a second reversal within
--   weaveWindowSeconds (st.shownDir / shownRevAt / shownArrived, carried on from the trip at the
--   bell), so no horse zig-zags after the lock either;
-- * planned, not dodged: plan = where each horse is heading by the last tap (the race shape at
--   full luck weight, Trip.frame passes it; re-planned every tick as the live chances move). A
--   horse whose planned place is within holdGap behind, or ahead of, a horse ahead in its lane,
--   within PLAN_SECONDS of closing, moves over now, with one S-curve move, outward first;
-- * in the last moments (the half-lane-step window) a horse still boxed in edges half a lane
--   over before it tries a full lane change, so late conflicts end in a small step, not a swerve;
-- * a horse moving in front of another keeps the glide reserve from it (targets drift while a
--   1.0 s glide is under way).
-- plan is optional (tests may call without it): the current targets then stand in.
local PLAN_SECONDS = 3 -- (eased) look this far ahead for meetings: two horses close at up to 2 * maxGapFeetPerSecond

function Trip.cosmetic(st: any, targets: { number }, dt: number, t: number, plan: { number }?): { number }
	local cfg, n = st.cfg, st.n
	local band = cfg.laneBand
	Trip.viewStep(st, targets, dt, st.geo.length / st.speed - t)
	local view, x, tgt = st.view, st.shown, st.shownTgt
	local eased = cfg.glide == "eased"
	local aim = if eased and plan ~= nil then plan else targets
	local landed = st.shownLanded or {} -- (eased) horses that landed on the last tick rest this one
	st.shownLanded = {}
	-- j may start a move: at rest (and, eased, not just landed).
	local function atRest(j: number): boolean
		return x[j] == tgt[j] and not (eased and landed[j])
	end
	-- (eased) j may start a move in direction dir: the same way as its last move, or the other way
	-- once the reverse gap (or the weave gap, for a second reversal within the window) has passed
	-- since it landed.
	local function mayTurn(j: number, dir: number): boolean
		if not eased or st.shownDir[j] == 0 or dir == st.shownDir[j] then return true end
		local g = cfg.reverseGapSeconds
		if cfg.weaveGapSeconds > g and t - st.shownRevAt[j] < cfg.weaveWindowSeconds - EPS then g = cfg.weaveGapSeconds end
		return t - st.shownArrived[j] >= g - EPS
	end
	local function startMove(j: number, to: number)
		if eased then
			local dir = if to > tgt[j] then 1 else -1
			if st.shownDir[j] ~= 0 and dir ~= st.shownDir[j] then st.shownRevAt[j] = t end
			st.shownDir[j] = dir
		end
		tgt[j] = to
	end
	local ord = table.create(n)
	for i = 1, n do ord[i] = i end
	table.sort(ord, function(a: number, b: number): boolean
		if view[a] ~= view[b] then return view[a] > view[b] end
		if x[a] ~= x[b] then return x[a] < x[b] end
		return a < b
	end)
	local clear = cfg.clearFeet
	local laneTime = Trip.glideSeconds(cfg, 1) -- one lane's glide (laneSeconds, or the eased curve's)
	local cross = 2 * st.race.maxGapFeetPerSecond * laneTime -- closing while crossing a lane
	-- Half-lane steps start this long before the holds let go, so the step is done by then.
	local stepping = Trip.halfSteps and st.geo.length / st.speed - t <= HOLD_RELEASE_SECONDS + laneTime
	-- How far ahead (feet) a meeting counts: the make-room look-ahead, or (eased) PLAN_SECONDS of
	-- closing, whichever is longer.
	local ahead = if eased then math.max(st.lookahead, cfg.holdGap + 2 * st.race.maxGapFeetPerSecond * PLAN_SECONDS) else st.lookahead
	-- j, ahead of i on screen in i's lane, is in i's way: i is held behind it (closer than holdGap)
	-- or will close on it (i's place, or with the eased glide its planned place, is not holdGap
	-- behind j's) from less than the look-ahead apart.
	local margin = if eased then cfg.holdGap + cfg.glideReserveFeet else cfg.holdGap
	local function inWay(i: number, j: number): boolean
		local d = view[j] - view[i]
		return d < cfg.holdGap or (aim[i] > aim[j] - margin and d < ahead)
	end
	-- j is in `lane`: there, heading there, or gliding across it on the way (S4 review: a horse that
	-- moved onto another's path got held back as the other crossed, a jerk on screen).
	local function inLane(j: number, lane: number): boolean
		if math.abs(x[j] - lane) < band or tgt[j] == lane then return true end
		return lane > math.min(x[j], tgt[j]) and lane < math.max(x[j], tgt[j])
	end
	-- j stands in i's way in `lane`: within holdGap ahead or behind, ahead and being closed on by i,
	-- or behind and closing on i (S4 review: closer than holdGap, or with one catching the other,
	-- the hold would pull one of them back when they meet, a jerk on screen). With the eased glide
	-- a horse moving in front of another keeps the glide reserve from it. (Closing is judged on the
	-- targets now, not the plan: a horse that will pass half the field would find no lane free.)
	local reserve = if eased then cfg.glideReserveFeet else 0
	local function blocks(i: number, j: number, lane: number): boolean
		if j == i or not inLane(j, lane) then return false end
		local d = view[j] - view[i]
		local gap = cfg.holdGap
		return math.abs(d) < gap or (d < 0 and -d < gap + reserve)
			or (d > 0 and targets[i] > targets[j] - gap and d < st.lookahead)
			or (d < 0 and targets[j] > targets[i] - gap and -d < st.lookahead)
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
	-- The nearest free lane i can reach across passable lanes, outward first at equal distance
	-- (and, eased, only a way it may turn).
	local function findLane(i: number): number?
		for dist = 1, st.lanes - 1 do
			for _, dir in { 1, -1 } do
				local lane = tgt[i] + dir * dist
				if lane >= 1 and lane <= st.lanes and mayTurn(i, dir) and free(i, lane) then
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
		if catching and atRest(catching) then
			local other = findLane(catching)
			if other then
				startMove(catching, other)
				return true
			end
		end
		for _, dir in { 1, -1 } do
			local side = tgt[i] + dir
			if side >= 1 and side <= st.lanes then
				for j = 1, n do
					if atRest(j) and blocks(i, j, side) then
						local other = findLane(j)
						if other and (other - side) * dir > 0 then
							startMove(j, other)
							return true
						end
						if depth > 1 and clearLane(j, nil, depth - 1) then return true end
					end
				end
			end
		end
		return false
	end
	-- A half-lane step for i (S4): only where no horse near it lengthwise is, or is heading, within
	-- half a lane of the new spot.
	local function halfStep(i: number): boolean
		for _, dir in { 1, -1 } do
			local spot = tgt[i] + 0.5 * dir
			if spot >= 1 and spot <= st.lanes and mayTurn(i, dir) then
				local ok = true
				for j = 1, n do
					if j ~= i and math.abs(view[j] - view[i]) < clear + cross
						and (math.abs(x[j] - spot) < 0.5 or math.abs(tgt[j] - spot) < 0.5) then
						ok = false
					end
				end
				if ok then
					startMove(i, spot)
					st.halfSteps = (st.halfSteps or 0) + 1 -- counted for the overlap report
					return true
				end
			end
		end
		return false
	end
	for a = 1, n do
		local i = ord[a]
		if atRest(i) and tgt[i] % 1 == 0 then -- (a horse already half a lane over stays there)
			local blocker = nil
			for b = 1, a - 1 do -- horses ahead on screen (or level and earlier): i gives way
				local j = ord[b]
				if inLane(j, x[i]) and inWay(i, j) then blocker = j end
			end
			if blocker then
				if eased and stepping and halfStep(i) then
					-- late: a half-lane step first, not a full lane change
				else
					local lane = findLane(i)
					if lane then
						startMove(i, lane)
					elseif not clearLane(i, blocker, MAKE_WAY_DEPTH) and stepping and not eased then
						halfStep(i) -- if nothing can move, it is held until a lane opens (or the holds let go)
					end
				end
			end
		end
	end
	if eased then
		local adt, vmax, v = cfg.laneAccel * dt, cfg.laneSpeedMax, st.shownV
		for i = 1, n do
			if not (x[i] == tgt[i] and v[i] == 0) and easeStep(x, tgt, v, i, dt, adt, vmax) then
				st.shownLanded[i] = true
				st.shownArrived[i] = t + dt
			end
		end
	else
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
	end
	return table.clone(x)
end

-- Lanes as sent: rounded to 0.01 lane (0.06 ft, invisible; smaller packets). With the eased glide
-- (D-057) to 0.001 lane: the screen draws the S-curve from these samples (N3), and 0.01 lane of
-- rounding would add up to 12 ft/s^2 of sideways jitter to it.
local function sendLanes(x: { number }, per: number): { number }
	local out = table.create(#x)
	for i, v in x do out[i] = math.floor(v * per + 0.5) / per end
	return out
end

-- What RaceOffsets carries now (t = race time), which the screen shows as sent: before the lock,
-- Trip's offsets and lanes; after it, the race shape's offsets (live chances, late on luck) as
-- the screen eases them, held so none runs through another, and the make-room lanes. With no
-- trip (steering off) the race shape's offsets alone, exactly as before steering (lanes = nil).
function Trip.frame(st: any, session: any, shownLive: { number }, w: number, shapeCfg: any, dt: number, t: number): ({ number }, { number }?)
	if st == nil then return session:displayOffsets(shownLive, w, shapeCfg), nil end
	local eased = st.cfg.glide == "eased"
	local per = if eased then 1000 else 100
	if not st.locked then return table.clone(st.off), sendLanes(st.x, per) end
	-- (eased) the plan: where each horse is heading by the last tap (full luck weight)
	local plan = if eased then session:displayOffsets(shownLive, 1, shapeCfg) else nil
	local lanes = Trip.cosmetic(st, session:displayOffsets(shownLive, w, shapeCfg), dt, t, plan)
	return table.clone(st.view), sendLanes(lanes, per)
end

return Trip
