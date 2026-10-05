--!strict
-- Training and the vet (D-039, D-040). Pure rules on horse records, tested under Lune.
-- Training: one mini-game per stat at the Training Paddock. A session gains in proportion
-- to the room left below the horse's Potential, so a stat slows down as it nears its cap:
--   gain = K × (Potential − stat) × (0.5 + 0.5 × score / 100), × 1.5 if the horse is rested
-- (no session for RESTED_SECONDS, offline counts), never more than the weekly cap per horse.
-- The cap is the real limit (scores come from the client), reachable in about 3 sessions.
-- "Training moves you up leagues; riding wins races."
-- Vet (wellness clinic): a heartbeat check-up gives +1 bond once a day and the next Health
-- Passport stamp on a new day. Nothing makes a horse ill and nothing is for sale.

local Training = {}

Training.STATS = { "speed", "accel", "stamina", "grit" }
Training.GAMES = {
	speed = { name = "Sprint Lane", label = "Speed", emoji = "💨" },
	accel = { name = "Gate Break", label = "Acceleration", emoji = "🚦" },
	stamina = { name = "Hill Climb", label = "Stamina", emoji = "⛰️" },
	grit = { name = "Mud Splash", label = "Grit", emoji = "💦" },
}
Training.K = 0.12
Training.WEEKLY_CAP = 6          -- stat points per horse per week
Training.RESTED_SECONDS = 3 * 60 * 60
Training.RESTED_BONUS = 1.5
Training.MIN_GAIN = 0.1

Training.STAMPS = { "checkup", "potential", "teeth", "farrier", "vaccine" }
Training.STAMP_LABELS = {
	checkup = "First check-up", potential = "Potential revealed", teeth = "Shiny teeth",
	farrier = "New horseshoes", vaccine = "Vaccinations",
}

local function week(now: number): number
	return (now // 86400 + 3) // 7
end
Training.week = week

local function ensure(h: any)
	if typeof(h.training) ~= "table" then h.training = { week = -1, gained = 0, lastAt = 0 } end
	h.training.week = tonumber(h.training.week) or -1
	h.training.gained = tonumber(h.training.gained) or 0
	h.training.lastAt = tonumber(h.training.lastAt) or 0
	h.vetDay = tonumber(h.vetDay) or -1
	h.stamps = h.stamps or {}
end
Training.repair = ensure

local function gainedThisWeek(h: any, now: number): number
	ensure(h)
	return if h.training.week == week(now) then h.training.gained else 0
end
Training.gainedThisWeek = gainedThisWeek

function Training.isRested(h: any, now: number): boolean
	ensure(h)
	return now - h.training.lastAt >= Training.RESTED_SECONDS
end

-- Can this horse still train this week?
function Training.ready(h: any, now: number): boolean
	return gainedThisWeek(h, now) < Training.WEEKLY_CAP - 1e-9
end

-- Points this session would add (before rounding), within the cap.
function Training.gain(h: any, stat: string, score: number, now: number): number
	if not Training.GAMES[stat] then return 0 end
	local room = math.max(0, (h.potential[stat] or 0) - (h.stats[stat] or 0))
	local quality = 0.5 + 0.5 * math.clamp(score, 0, 100) / 100
	local g = Training.K * room * quality * (if Training.isRested(h, now) then Training.RESTED_BONUS else 1)
	g = math.min(g, room, Training.WEEKLY_CAP - gainedThisWeek(h, now))
	return math.max(0, g)
end

-- Run a session. Returns (ok, gained rounded to 0.1, message).
function Training.train(h: any, stat: string, score: number, now: number): (boolean, number, string)
	ensure(h)
	local game = Training.GAMES[stat]
	if not game then return false, 0, "Pick something to practise" end
	if typeof(score) ~= "number" or score ~= score then return false, 0, "Try that again" end
	if not Training.ready(h, now) then return false, 0, h.name .. " has trained enough this week. Races still help!" end
	local room = (h.potential[stat] or 0) - (h.stats[stat] or 0)
	if room < Training.MIN_GAIN then return false, 0, h.name .. "'s " .. game.label .. " is as high as it goes. Try another!" end
	local rested = Training.isRested(h, now)
	local g = math.floor(Training.gain(h, stat, score, now) * 10 + 0.5) / 10
	g = math.max(g, Training.MIN_GAIN)
	g = math.min(g, math.floor(room * 10) / 10, Training.WEEKLY_CAP - gainedThisWeek(h, now))
	if h.training.week ~= week(now) then h.training.week, h.training.gained = week(now), 0 end
	h.stats[stat] = math.floor((h.stats[stat] + g) * 10 + 0.5) / 10
	h.training.gained += g
	h.training.lastAt = now
	local msg = string.format("+%.1f %s!%s", g, game.label, if rested then " Rested bonus ✨" else "")
	return true, g, msg
end

-- Vet check-up: +1 bond once a day; the next stamp on a new day. Returns (ok, message, stamp?).
function Training.checkup(h: any, score: number, now: number): (boolean, string, string?)
	ensure(h)
	local today = now // 86400
	if h.vetDay == today then return true, h.name .. " is healthy and happy! See you tomorrow", nil end
	h.vetDay = today
	h.bond = math.clamp((h.bond or 0) + 1, 0, 100)
	local stamp = nil
	for _, s in Training.STAMPS do
		if not h.stamps[s] then
			stamp = s
			break
		end
	end
	if stamp then h.stamps[stamp] = true end
	local good = if score >= 70 then "Great listening! " else ""
	if stamp then
		return true, good .. "New Health Passport stamp: " .. Training.STAMP_LABELS[stamp] .. "!", stamp
	end
	return true, good .. h.name .. " is healthy and happy! +1 bond", nil
end

return Training
