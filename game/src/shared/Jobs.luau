--!strict
-- Stable Board jobs (D-043): 3 daily, 5 weekly and 5 monthly jobs. Pure rules on a Profile.
--   Jobs count effort, never wins: care, riding, good taps, garden, chores, exploring,
--   cheering. They never ask for spending, inviting friends or hours played.
--   Each set is picked from the pool with a seed of (player, day/week/month), so it's stable
--   across servers and rejoins. One free reroll of a daily job per day.
--   Finished jobs show a Claim button; anything finished but unclaimed is claimed for you when
--   the set rolls over, so nothing is ever lost. No streaks, no countdowns.
--   Rewards: hay, seeds, treats, small Green Cash (daily total about 10% of a day's races) and
--   monthly stamps toward the month's cosmetic. Never League Points, Energy or win chance.

local Profile = if script then require(script.Parent.Profile) :: any else require("./Profile")

local Jobs = {}

export type Reward = { cash: number?, items: { [string]: number }?, stamps: number? }
export type Def = { id: string, event: string, target: number, text: string, icon: string, go: string?, reward: Reward }
export type Job = { id: string, progress: number, claimed: boolean }

Jobs.DAILY = {
	{ id = "d_feed", event = "feed", target = 1, text = "Feed a horse", icon = "hay", go = "stable", reward = { cash = 4, items = { hay = 2 } } },
	{ id = "d_groom", event = "groom", target = 1, text = "Brush a horse until it shines", icon = "brush", go = "stable", reward = { cash = 4, items = { treat = 1 } } },
	{ id = "d_pet", event = "pet", target = 2, text = "Pet your horses 2 times", icon = "heart", go = "stable", reward = { cash = 3, items = { carrot = 2 } } },
	{ id = "d_race1", event = "race", target = 1, text = "Ride in a race", icon = "flag_ready", go = "raceBoard", reward = { cash = 6, items = { hay = 2 } } },
	{ id = "d_race3", event = "race", target = 3, text = "Ride in 3 races", icon = "flag_ready", go = "raceBoard", reward = { cash = 10, items = { seed_carrot = 2 } } },
	{ id = "d_great5", event = "great_tap", target = 5, text = "Land 5 Great or Perfect taps", icon = "care_star", go = "raceBoard", reward = { cash = 6, items = { treat = 1 } } },
	{ id = "d_burst", event = "burst_great", target = 1, text = "Hit a Great Final Burst", icon = "care_star", go = "raceBoard", reward = { cash = 6, items = { grain = 1 } } },
	{ id = "d_plant", event = "plant", target = 1, text = "Plant a seed", icon = "seed_carrot", go = "stable", reward = { cash = 3, items = { seed_oats = 1 } } },
	{ id = "d_harvest", event = "harvest", target = 1, text = "Pick a crop", icon = "carrot", go = "stable", reward = { cash = 4, items = { seed_carrot = 1 } } },
	{ id = "d_chore", event = "chore", target = 1, text = "Muck out a stall", icon = "hay", go = "stable", reward = { cash = 3, items = { hay = 2 } } },
	{ id = "d_treat", event = "treat", target = 2, text = "Give 2 treats", icon = "carrot", go = "stable", reward = { cash = 3, items = { apple = 1 } } },
	{ id = "d_ride", event = "ride", target = 1, text = "Go for a ride on your horse", icon = "hoofprint", go = "stable", reward = { cash = 3, items = { carrot = 1 } } },
	{ id = "d_trail", event = "visit_trail", target = 1, text = "Visit the flower meadow on the Trail", icon = "map_trail", go = "trailGate", reward = { cash = 4, items = { apple = 1 } } },
	{ id = "d_train", event = "train", target = 1, text = "Do a training session", icon = "stat_speed", go = "paddock", reward = { cash = 4, items = { grain = 1 } } },
	{ id = "d_vet", event = "checkup", target = 1, text = "Take a horse for a check-up", icon = "stethoscope", go = "vet", reward = { cash = 3, items = { treat = 1 } } },
} :: { Def }

Jobs.WEEKLY = {
	{ id = "w_race10", event = "race", target = 10, text = "Ride in 10 races", icon = "flag_ready", go = "raceBoard", reward = { cash = 30, items = { treat = 3 } } },
	{ id = "w_great40", event = "great_tap", target = 40, text = "Land 40 Great or Perfect taps", icon = "care_star", go = "raceBoard", reward = { cash = 25, items = { grain = 3 } } },
	{ id = "w_care10", event = "feed", target = 7, text = "Feed horses 7 times", icon = "hay", go = "stable", reward = { cash = 20, items = { seed_apple = 2 } } },
	{ id = "w_groom7", event = "groom", target = 7, text = "Brush horses 7 times", icon = "brush", go = "stable", reward = { cash = 20, items = { treat = 2 } } },
	{ id = "w_harvest5", event = "harvest", target = 5, text = "Pick 5 crops", icon = "carrot", go = "stable", reward = { cash = 20, items = { seed_oats = 3 } } },
	{ id = "w_chore6", event = "chore", target = 6, text = "Muck out 6 stalls", icon = "hay", go = "stable", reward = { cash = 15, items = { hay = 10 } } },
	{ id = "w_burst3", event = "burst_great", target = 3, text = "Hit 3 Great Final Bursts", icon = "care_star", go = "raceBoard", reward = { cash = 25, items = { treat = 2 } } },
	{ id = "w_days3", event = "day", target = 3, text = "Visit your stable on 3 days", icon = "map_stable", go = "stable", reward = { cash = 20, items = { apple = 3 } } },
	{ id = "w_train4", event = "train", target = 4, text = "Do 4 training sessions", icon = "stat_stamina", go = "paddock", reward = { cash = 25, items = { grain = 3 } } },
	{ id = "w_vet3", event = "checkup", target = 3, text = "Collect 3 vet check-ups", icon = "stethoscope", go = "vet", reward = { cash = 15, items = { treat = 2 } } },
} :: { Def }

Jobs.MONTHLY = {
	{ id = "m_race40", event = "race", target = 40, text = "Ride in 40 races", icon = "flag_ready", go = "raceBoard", reward = { stamps = 2, items = { treat = 5 } } },
	{ id = "m_great150", event = "great_tap", target = 150, text = "Land 150 Great or Perfect taps", icon = "care_star", go = "raceBoard", reward = { stamps = 2, items = { grain = 5 } } },
	{ id = "m_harvest20", event = "harvest", target = 20, text = "Pick 20 crops", icon = "carrot", go = "stable", reward = { stamps = 1, items = { seed_apple = 4 } } },
	{ id = "m_bond", event = "pet", target = 20, text = "Pet your horses 20 times", icon = "heart", go = "stable", reward = { stamps = 1, items = { treat = 4 } } },
	{ id = "m_days10", event = "day", target = 10, text = "Visit your stable on 10 days", icon = "map_stable", go = "stable", reward = { stamps = 2, items = { hay = 20 } } },
	{ id = "m_trail5", event = "visit_trail", target = 5, text = "Visit the flower meadow 5 times", icon = "map_trail", go = "trailGate", reward = { stamps = 1, items = { apple = 5 } } },
} :: { Def }

Jobs.COUNTS = { daily = 3, weekly = 5, monthly = 5 }
Jobs.STAMPS_FOR_COSMETIC = 8

local POOLS = { daily = Jobs.DAILY, weekly = Jobs.WEEKLY, monthly = Jobs.MONTHLY }
local byId: { [string]: Def } = {}
for _, pool in POOLS do
	for _, d in pool do byId[d.id] = d end
end

function Jobs.def(id: string): Def?
	return byId[id]
end

-- Period keys: whole UTC days, weeks (from Monday) and months.
function Jobs.periods(now: number): { daily: number, weekly: number, monthly: number }
	local d = now // 86400
	local t = os.date("!*t", now) :: any
	return { daily = d, weekly = (d + 3) // 7, monthly = t.year * 12 + t.month }
end

-- A small seeded generator (same picks on every server).
local function lcg(seed: number)
	local s = seed % 2147483647
	if s <= 0 then s += 2147483646 end
	return function(n: number): number
		s = (s * 48271) % 2147483647
		return 1 + (s % n)
	end
end

function Jobs.pick(kind: string, userId: number, period: number, exclude: { [string]: boolean }?): { string }
	local pool = POOLS[kind]
	local rand = lcg(userId * 131 + period * 7919 + #kind)
	local ids = {}
	local avail = {}
	for _, d in pool do
		if not (exclude and exclude[d.id]) then table.insert(avail, d.id) end
	end
	local events: { [string]: boolean } = {}
	while #ids < Jobs.COUNTS[kind] and #avail > 0 do
		local k = rand(#avail)
		local id = table.remove(avail, k) :: string
		local ev = byId[id].event
		-- Prefer different kinds of job in one set (two race jobs at once feels samey).
		if not events[ev] or #avail < Jobs.COUNTS[kind] - #ids then
			events[ev] = true
			table.insert(ids, id)
		end
	end
	return ids
end

local function newSet(ids: { string }): { Job }
	local out = {}
	for _, id in ids do table.insert(out, { id = id, progress = 0, claimed = false }) end
	return out
end

local function grant(p: any, reward: Reward)
	if reward.cash and reward.cash > 0 then Profile.addCash(p, reward.cash) end
	for item, n in reward.items or {} do Profile.addItem(p, item, n) end
	if reward.stamps then p.jobs.stamps += reward.stamps end
end

-- Claim every finished, unclaimed job in a set (used at rollover).
local function claimAll(p: any, set: { Job }): number
	local n = 0
	for _, j in set do
		local d = byId[j.id]
		if d and not j.claimed and j.progress >= d.target then
			j.claimed = true
			grant(p, d.reward)
			n += 1
		end
	end
	return n
end

-- Make sure the profile has current sets; roll over (auto-claiming) when a period changes.
-- Returns how many jobs were auto-claimed.
function Jobs.refresh(p: any, userId: number, now: number): number
	local per = Jobs.periods(now)
	if typeof(p.jobs) ~= "table" then
		p.jobs = { stamps = 0, rerollDay = -1 }
	end
	local J = p.jobs
	J.stamps = tonumber(J.stamps) or 0
	J.rerollDay = tonumber(J.rerollDay) or -1
	local auto = 0
	for kind in POOLS do
		local key = kind .. "Period"
		if J[key] ~= per[kind] or typeof(J[kind]) ~= "table" then
			if typeof(J[kind]) == "table" then auto += claimAll(p, J[kind]) end
			J[key] = per[kind]
			J[kind] = newSet(Jobs.pick(kind, userId, per[kind]))
		end
	end
	return auto
end

-- Count an event (e.g. "feed", n = 1). Returns the defs of jobs that just finished.
function Jobs.record(p: any, userId: number, event: string, n: number, now: number): { Def }
	Jobs.refresh(p, userId, now)
	local finished = {}
	for kind in POOLS do
		for _, j in p.jobs[kind] do
			local d = byId[j.id]
			if d and d.event == event and j.progress < d.target then
				j.progress = math.min(d.target, j.progress + n)
				if j.progress >= d.target then table.insert(finished, d) end
			end
		end
	end
	return finished
end

function Jobs.claim(p: any, userId: number, kind: string, index: number, now: number): (boolean, Def?)
	Jobs.refresh(p, userId, now)
	local set = POOLS[kind] and p.jobs[kind]
	local j = set and set[index]
	local d = j and byId[j.id]
	if not d or j.claimed or j.progress < d.target then return false, nil end
	j.claimed = true
	grant(p, d.reward)
	return true, d
end

-- Swap one unfinished daily job for a new one, once a day (free).
function Jobs.reroll(p: any, userId: number, index: number, now: number): boolean
	Jobs.refresh(p, userId, now)
	local per = Jobs.periods(now)
	if p.jobs.rerollDay == per.daily then return false end
	local set = p.jobs.daily
	local j = set[index]
	if not j or j.claimed or j.progress >= (byId[j.id] :: Def).target then return false end
	local exclude = {}
	for _, other in set do exclude[other.id] = true end
	local fresh = Jobs.pick("daily", userId, per.daily * 31 + index, exclude)
	if #fresh == 0 then return false end
	set[index] = { id = fresh[1], progress = 0, claimed = false }
	p.jobs.rerollDay = per.daily
	return true
end

-- Are all of today's jobs claimed? ("All done today!")
function Jobs.allDoneToday(p: any): boolean
	if typeof(p.jobs) ~= "table" or typeof(p.jobs.daily) ~= "table" then return false end
	for _, j in p.jobs.daily do
		if not j.claimed then return false end
	end
	return true
end

-- What the client sees.
function Jobs.view(p: any): { [string]: any }
	local out = { stamps = p.jobs and p.jobs.stamps or 0, rerollUsed = false }
	if typeof(p.jobs) ~= "table" then return out end
	out.rerollUsed = p.jobs.rerollDay == p.jobs.dailyPeriod
	for kind in POOLS do
		local list = {}
		for _, j in p.jobs[kind] or {} do
			local d = byId[j.id]
			if d then
				table.insert(list, { id = j.id, text = d.text, icon = d.icon, go = d.go, target = d.target, progress = j.progress,
					claimed = j.claimed, reward = d.reward })
			end
		end
		out[kind] = list
	end
	return out
end

return Jobs
