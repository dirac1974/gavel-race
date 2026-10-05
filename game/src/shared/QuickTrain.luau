--!strict
-- QuickTrain (D-053, T4): the four 10-second training games ("Quick train"), as pure functions
-- of a server seed and the player's tap times, so the server scores them (the client sends
-- tap times, never a score) and the client's screen and labels use exactly the same rules.
-- Times are seconds from the game's start (the server's start time + lead).
--   speed    Sprint Lane: a runner bounces along a lane, faster each round; tap in the glowing
--            zone, 5 rounds (a round with no tap for ROUND_MAX seconds counts 0).
--   accel    Gate Break: wait for green, then tap; tapping on red counts 0 ("Too soon!");
--            3 rounds (no tap within GREEN_MAX of green counts 0 too).
--   stamina  Hill Climb: hold to climb, let go to slide, stay in the moving green band for 8 s
--            (simulated in fixed 1/60 s steps from the hold and release times).
--   grit     Mud Splash: tap as each of 8 puddles reaches the hoof; a tap with no puddle near
--            costs STRAY points, so tapping as fast as you can doesn't pay.
-- events: { { t = seconds, kind = "tap" | "down" | "up" } }, in time order.
-- play(stat, seed, events, now) -> { done, endT, score, taps = { per event: score or nil } }

local QuickTrain = {}

QuickTrain.STATS = { "speed", "accel", "stamina", "grit" }
QuickTrain.LEAD = 1.0          -- seconds from the server's start message to the game's start
QuickTrain.MAX_GAME = 40       -- a game never runs longer than this
QuickTrain.SETTLE = 0.35       -- the server scores this long after the game ends (late taps)
QuickTrain.MAX_EVENTS = 80

local function lcg(x: number): number
	return (x * 16807) % 2147483647
end

-- A deterministic number in [0, 1) for (seed, n).
function QuickTrain.unit(seed: number, n: number): number
	local x = ((math.floor(math.abs(seed)) + n * 104729) % 2147483646) + 1
	for _ = 1, 3 do x = lcg(x) end
	return x / 2147483647
end

local function taps(events: { any }): { any }
	local out = {}
	for i, e in events do
		if e.kind == "tap" then table.insert(out, { t = e.t, i = i }) end
	end
	return out
end

-- Sprint Lane ---------------------------------------------------------------------------------
local SPEED = { rounds = 5, half = 0.06, lock = 0.25, roundMax = 6 }
QuickTrain.SPEED = SPEED

function QuickTrain.speedCenter(seed: number, r: number): number
	return 0.15 + 0.7 * QuickTrain.unit(seed, r)
end

function QuickTrain.speedPace(r: number): number
	return 0.55 + r * 0.1 -- lane widths per second
end

local function triangle(d: number): number
	local m = d % 2
	return if m <= 1 then m else 2 - m
end

function QuickTrain.speedTapScore(x: number, center: number): number
	local err = math.abs(x - center) / SPEED.half
	if err <= 1 then return 100 - err * 15 end
	return math.clamp(100 * (1 - (err - 1) * 0.5 - 0.2), 0, 100)
end

-- Round starts and the runner's travelled distance follow the taps.
local function speedPlay(seed: number, events: { any }, now: number)
	local list = taps(events)
	local res = { done = false, endT = nil :: number?, score = 0, taps = {}, round = 1, roundStart = 0, dist0 = 0 }
	local total = 0
	local start, dist0, k = 0, 0, 1
	for r = 1, SPEED.rounds do
		local pace = QuickTrain.speedPace(r)
		res.round, res.roundStart, res.dist0 = r, start, dist0
		while k <= #list and list[k].t < start do k += 1 end -- taps in the lockout don't count
		local tap = list[k]
		if tap and tap.t <= start + SPEED.roundMax then
			local x = triangle(dist0 + pace * (tap.t - start))
			local s = QuickTrain.speedTapScore(x, QuickTrain.speedCenter(seed, r))
			res.taps[tap.i] = s
			total += s
			k += 1
			dist0 += pace * (tap.t + SPEED.lock - start)
			start = tap.t + SPEED.lock
		elseif now >= start + SPEED.roundMax then
			dist0 += pace * SPEED.roundMax
			start += SPEED.roundMax -- a round with no tap counts 0
		else
			return res
		end
	end
	res.done, res.endT, res.score = true, start, total / SPEED.rounds
	return res
end

-- Where the runner is at t (0..1 along the lane) and the round's zone, for the screen.
function QuickTrain.speedView(seed: number, events: { any }, t: number): (number, number, number)
	local res = speedPlay(seed, events, t)
	local r = math.min(res.round, SPEED.rounds)
	local x = triangle(res.dist0 + QuickTrain.speedPace(r) * math.max(0, t - res.roundStart))
	return x, QuickTrain.speedCenter(seed, r), r
end

-- Gate Break ---------------------------------------------------------------------------------
local ACCEL = { rounds = 3, earlyPause = 0.8, nextPause = 0.9, greenMax = 4 }
QuickTrain.ACCEL = ACCEL

function QuickTrain.accelDelay(seed: number, r: number): number
	return 1.2 + 1.8 * QuickTrain.unit(seed, 10 + r)
end

function QuickTrain.accelTapScore(rt: number): number
	return math.clamp(100 - (rt - 0.22) / (0.8 - 0.22) * 70, 30, 100)
end

local function accelPlay(seed: number, events: { any }, now: number)
	local list = taps(events)
	local res = { done = false, endT = nil :: number?, score = 0, taps = {}, round = 1, roundStart = 0, greenAt = 0 }
	local total, start, k = 0, 0, 1
	for r = 1, ACCEL.rounds do
		local green = start + QuickTrain.accelDelay(seed, r)
		res.round, res.roundStart, res.greenAt = r, start, green
		while k <= #list and list[k].t < start do k += 1 end -- taps between rounds don't count
		local tap = list[k]
		if tap and tap.t < green then
			res.taps[tap.i] = 0 -- too soon: that round counts 0
			k += 1
			start = tap.t + ACCEL.earlyPause
		elseif tap and tap.t <= green + ACCEL.greenMax then
			local s = QuickTrain.accelTapScore(tap.t - green)
			res.taps[tap.i] = s
			total += s
			k += 1
			start = tap.t + ACCEL.nextPause
		elseif now >= green + ACCEL.greenMax then
			start = green + ACCEL.greenMax + ACCEL.nextPause -- no tap: that round counts 0
		else
			return res
		end
	end
	res.done, res.endT, res.score = true, start, total / ACCEL.rounds
	return res
end

-- Light state at t: round, green?
function QuickTrain.accelView(seed: number, events: { any }, t: number): (number, boolean, boolean)
	local res = accelPlay(seed, events, t)
	return res.round, t >= res.greenAt, res.done
end

-- Hill Climb ---------------------------------------------------------------------------------
local STAMINA = { duration = 8, dt = 1 / 60, band = 0.13, up = 1.6, down = 1.4, vmax = 0.9 }
QuickTrain.STAMINA = STAMINA

function QuickTrain.bandAt(seed: number, t: number): number
	local p1, p2 = QuickTrain.unit(seed, 21) * 2 * math.pi, QuickTrain.unit(seed, 22) * 2 * math.pi
	return 0.5 + 0.3 * math.sin(t * 0.9 + p1) * math.sin(t * 0.37 + 1 + p2)
end

-- Simulate up to `upTo` seconds. Returns { y, band, inside, t }.
function QuickTrain.staminaRun(seed: number, events: { any }, upTo: number)
	local y, vy, t, inside = 0.5, 0, 0, 0
	local holding, k = false, 1
	local stop = math.min(upTo, STAMINA.duration)
	local band = QuickTrain.bandAt(seed, 0)
	local n = math.floor(stop / STAMINA.dt + 1e-9)
	for _ = 1, n do
		while k <= #events and events[k].t <= t do
			if events[k].kind == "down" then holding = true elseif events[k].kind == "up" then holding = false end
			k += 1
		end
		t += STAMINA.dt
		band = QuickTrain.bandAt(seed, t)
		vy = math.clamp(vy + (if holding then STAMINA.up else -STAMINA.down) * STAMINA.dt, -STAMINA.vmax, STAMINA.vmax)
		y = math.clamp(y + vy * STAMINA.dt, 0, 1)
		if y == 0 or y == 1 then vy = 0 end
		if math.abs(y - band) <= STAMINA.band then inside += STAMINA.dt end
	end
	return { y = y, band = band, inside = inside, t = t }
end

local function staminaPlay(seed: number, events: { any }, now: number)
	local run = QuickTrain.staminaRun(seed, events, now)
	local done = now >= STAMINA.duration
	return { done = done, endT = if done then STAMINA.duration else nil, taps = {},
		score = math.clamp(run.inside / STAMINA.duration * 110, 0, 100) }
end

-- Mud Splash ---------------------------------------------------------------------------------
local GRIT = { beats = 8, lead = 1, travel = 1.6, window = 0.25, tail = 0.4, stray = 15 }
QuickTrain.GRIT = GRIT

-- When each puddle reaches the hoof.
function QuickTrain.puddles(seed: number): { number }
	local out, at = {}, GRIT.lead + GRIT.travel
	for k = 1, GRIT.beats do
		out[k] = at
		at += 0.7 + 0.1 * QuickTrain.unit(seed, 30 + k)
	end
	return out
end

function QuickTrain.gritTapScore(err: number): number
	return math.clamp(100 - (err - 0.04) / 0.21 * 70, 30, 100)
end

local function gritPlay(seed: number, events: { any }, now: number)
	local times = QuickTrain.puddles(seed)
	local used, total = {}, 0
	local res = { done = false, endT = nil :: number?, score = 0, taps = {}, used = used }
	for _, tap in taps(events) do
		local best, bestErr = nil, math.huge
		for k, at in times do
			if not used[k] and math.abs(tap.t - at) < bestErr then best, bestErr = k, math.abs(tap.t - at) end
		end
		if best and bestErr <= GRIT.window then
			used[best] = true
			local s = QuickTrain.gritTapScore(bestErr)
			res.taps[tap.i] = s
			total += s
		else
			total -= GRIT.stray -- a tap with no puddle near
		end
	end
	local finish = times[GRIT.beats] + GRIT.tail
	res.done = now >= finish
	res.endT = if res.done then finish else nil
	res.score = math.max(0, total / GRIT.beats)
	return res
end

-- Everything -----------------------------------------------------------------------------------
local PLAY = { speed = speedPlay, accel = accelPlay, stamina = staminaPlay, grit = gritPlay }

function QuickTrain.play(stat: string, seed: number, events: { any }, now: number)
	local f = PLAY[stat]
	if not f then return { done = true, endT = 0, score = 0, taps = {} } end
	local res = f(seed, events, now)
	if not res.done and now >= QuickTrain.MAX_GAME then
		res.done, res.endT = true, QuickTrain.MAX_GAME
	end
	return res
end

-- Did the player play at all? (a tap that counted, or a hold in Hill Climb)
function QuickTrain.played(stat: string, events: { any }, res: any): boolean
	for i, e in events do
		if stat == "stamina" then
			if e.kind == "down" then return true end
		elseif res.taps[i] ~= nil then
			return true
		end
	end
	return false
end

-- Insert an event keeping time order (server: resolved tap times can arrive out of order).
function QuickTrain.addEvent(events: { any }, t: number, kind: string): boolean
	if #events >= QuickTrain.MAX_EVENTS then return false end
	local i = #events + 1
	while i > 1 and events[i - 1].t > t do i -= 1 end
	table.insert(events, i, { t = t, kind = kind })
	return true
end

function QuickTrain.label(score: number): string
	return if score >= 90 then "Perfect!" elseif score >= 75 then "Great!" elseif score >= 50 then "Good" else "Okay"
end

return QuickTrain
