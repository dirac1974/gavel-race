--!strict
-- RaceFx (D-066, AAA Phase 1): the pure maths behind what a tap looks and sounds like on your own
-- screen (GameConfig.raceFx): the tap tick's pitch, the tap nudge's speed and room, the surge, and
-- the camera kicks with their one budget. Drawn or heard only: nothing here reads or changes a
-- score, the order or the trip. RaceView and RaceController use it; tests/luau/race_fx_tests.luau
-- checks the caps. AAA Phase 2 (D-067) adds the finish moment's maths (gallop-out, orbit, when the
-- card shows) and first-race coaching, all drawn only too.

local RaceFx = {}

-- The tap tick's playback speed for a pace tap with this score label (GameConfig.labelFor): one
-- clear step per label, low for a Miss or Okay, brightest for a Perfect (0.9 to 1.3 by default).
function RaceFx.tickSpeed(label: string, fx: any): number
	return fx.tickSpeeds[label] or fx.tickSpeeds.Miss or 1
end

-- A surge on a streak (D-066): the `streak`-th Great-or-better pace tap in a row surges when it is
-- a whole multiple of surgeOnGreatStreak (a Perfect always surges, apart from this).
function RaceFx.streakSurges(streak: number, fx: any): boolean
	local every = fx.surgeOnGreatStreak or 0
	return every > 0 and streak > 0 and streak % every == 0
end

-- How far your horse can be nudged ahead before it comes within `clearFeet` of a horse ahead of
-- it in its lane (lane positions within `laneBand`). `ahead[i]` is each horse's drawn feet ahead
-- of the pace, `lanes[i]` its lane position. math.huge when no horse is ahead in your lane.
function RaceFx.nudgeRoom(me: number, ahead: { number }, lanes: { number }, laneBand: number, clearFeet: number): number
	local mine, x = ahead[me], lanes[me]
	if mine == nil or x == nil then return 0 end
	local room = math.huge
	for j, feet in ahead do
		local xj = lanes[j]
		if j ~= me and xj ~= nil and math.abs(xj - x) < laneBand and feet >= mine then
			room = math.min(room, feet - mine - clearFeet)
		end
	end
	return math.max(0, room)
end

-- One frame of the drawn nudge: toward `goal` (the nudge curve now) but never past `room`, at most
-- nudgeFeetPerSecond, never below 0. When a horse cuts in ahead and `room` falls under the drawn
-- nudge, the nudge eases back at the same rate; only if it would still be more than
-- nudgeSlackFeet past `room` is it pulled in at once (clearFeet less the slack still leaves a gap
-- between two horses, so one is never drawn through another).
function RaceFx.stepNudge(drawn: number, goal: number, room: number, dt: number, fx: any): number
	local step = fx.nudgeFeetPerSecond * math.max(0, dt)
	local limit = math.max(0, room)
	local nextFeet = drawn + math.clamp(math.min(goal, limit) - drawn, -step, step)
	return math.clamp(nextFeet, 0, limit + (fx.nudgeSlackFeet or 0))
end

-- The surge (a Perfect pace tap): 0..1 over surgeSeconds, up and back down, 0 outside.
function RaceFx.surge(age: number, fx: any): number
	if age < 0 or age >= fx.surgeSeconds then return 0 end
	return math.sin(math.pi * age / fx.surgeSeconds)
end

-- Camera kicks (one owner: RaceController). A kick widens the view by `deg`, rising over
-- fovRiseSeconds and easing back over `fall` seconds.
function RaceFx.kickAt(age: number, deg: number, fall: number, fx: any): number
	if age < 0 then return 0 end
	local rise = fx.fovRiseSeconds
	if age < rise then return deg * age / rise end
	local v = deg * math.exp(-(age - rise) / fall)
	return if v < 0.01 then 0 else v
end

-- A new Perfect-tap kick: at most one every perfectFovEverySeconds (the burst's kick doesn't count).
function RaceFx.canKickPerfect(lastAt: number, now: number, fx: any): boolean
	return now - lastAt >= fx.perfectFovEverySeconds
end

-- The view's widening now from every running kick ({ at, deg, fall }), at most fovMaxDeg;
-- finished kicks are dropped from the list.
function RaceFx.fov(kicks: { { at: number, deg: number, fall: number } }, now: number, fx: any): number
	local sum = 0
	for k = #kicks, 1, -1 do
		local kick = kicks[k]
		local age = now - kick.at
		local v = RaceFx.kickAt(age, kick.deg, kick.fall, fx)
		if v == 0 and age > fx.fovRiseSeconds then
			table.remove(kicks, k)
		else
			sum += v
		end
	end
	return math.clamp(sum, 0, fx.fovMaxDeg)
end

-- The finish moment (AAA Phase 2, D-067, GameConfig.finish) -------------------------------------

-- How far past the line (a fraction of this race's lane-1 length) the horses gallop out and ease
-- down: the same distance in every race, so a long race doesn't drift on for longer.
function RaceFx.pastLine(len1: number, fin: any): number
	if not fin or not fin.gallopOutFeet or len1 <= 0 then return 0.012 end
	return fin.gallopOutFeet / len1
end

-- The camera's arc from behind your horse to the side view: angle (radians, around the up axis),
-- horizontal radius and height, eased in and out over f = 0..1, the short way round.
function RaceFx.orbit(a0: number, r0: number, h0: number, a1: number, r1: number, h1: number, f: number): (number, number, number)
	local x = math.clamp(f, 0, 1)
	local e = x * x * (3 - 2 * x)
	local d = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
	return a0 + d * e, r0 + (r1 - r0) * e, h0 + (h1 - h0) * e
end

-- When the card shows (seconds on one clock): after the orbit (or the Reduced Motion fade) from
-- your horse's crossing, but never later than cardWithinSeconds after the leader's.
function RaceFx.cardAt(crossAt: number, leaderAt: number, fin: any, still: boolean): number
	local run = if still or not fin.orbit then fin.fadeSeconds else math.min(fin.orbitSeconds, 2.5)
	return math.min(crossAt + run, leaderAt + fin.cardWithinSeconds)
end

-- The chance arrow (D-067, the gameplay consult): a checkpoint closing shows it on any real change
-- (over 0.003); a preview shows it only with hud.arrowOnPreview, on a change over
-- arrowPreviewMinChange and at least arrowPreviewEverySeconds after the last arrow.
function RaceFx.arrowShows(change: number, preview: boolean, sinceLast: number, hud: any): boolean
	if change ~= change then return false end
	if not preview then return math.abs(change) > 0.003 end
	if not hud or hud.arrowOnPreview ~= true then return false end
	return math.abs(change) > (hud.arrowPreviewMinChange or 0.01) and sinceLast >= (hud.arrowPreviewEverySeconds or 3)
end

-- First-race coaching (D-067): is this race coached (the player's finished races before it)?
function RaceFx.coached(racesBefore: number?, fx: any): boolean
	return (fx.coachRaces or 0) > 0 and (tonumber(racesBefore) or 0) < fx.coachRaces
end

return RaceFx
