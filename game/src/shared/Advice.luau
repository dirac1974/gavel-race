--!strict
-- Advice (D-043): what the Stable Board says about each horse. One true fact about the horse
-- right now, and one next step with where to GO. Facts about the horse only; never guilt
-- ("Comet misses you", "Comet is hungry" are never written). Pure, works on the client's
-- profile view, tested under Lune.

local Care = if script then require(script.Parent.Care) :: any else require("./Care")
local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")

local Advice = {}

export type Tip = { emoji: string, fact: string, next: string, go: string? }

local STAT_LABEL = { speed = "Speed", accel = "Acceleration", stamina = "Stamina", grit = "Grit" }

-- The stat with the most room to grow (Potential − stat), when Potential is known; else nil.
function Advice.trainNext(h: any): string?
	if not h.potential then return nil end
	local best, room = nil, 0
	for _, k in { "speed", "accel", "stamina", "grit" } do
		local r = (h.potential[k] or 0) - (h.stats[k] or 0)
		if r > room then best, room = k, r end
	end
	return best
end

function Advice.forHorse(h: any, profile: any, now: number): Tip
	local name = h.name
	-- Facts first: what's true right now.
	local fact
	-- "napping" only when it's true (D-058): the view's resting means 0 Energy, not "a bit tired".
	if h.resting then
		fact = name .. " is napping in the straw"
	elseif h.fed and h.groomed then
		fact = name .. " is fed, shiny and ready to race"
	else
		fact = name .. " is rested and ready to race"
	end
	-- One next step, the most useful first.
	if not h.fed then
		return { emoji = "🌾", fact = fact, next = "Next: a meal of hay", go = "stable" }
	elseif not h.groomed then
		return { emoji = "🪮", fact = fact, next = "Next: a good brushing", go = "stable" }
	elseif h.resting and GameConfig.spa.enabled and (h.spaToday or 0) < GameConfig.spa.perDay then
		-- D-058: a napping horse's free Spa Day (+1 Energy), while it's open today
		return { emoji = "🛁", fact = fact, next = "Next: a Spa Day at the Vet", go = "vet" }
	elseif h.cupOpen and not h.resting then
		return { emoji = "🏆", fact = fact, next = "Next: win the " .. (h.league or "Rookie") .. " Cup to move up!", go = "raceBoard" }
	elseif h.trainingReady then
		local stat = Advice.trainNext(h)
		return { emoji = "🎯", fact = fact, next = if stat then "Next: train " .. STAT_LABEL[stat] else "Next: a training session", go = "paddock" }
	elseif not h.resting then
		return { emoji = "🏁", fact = fact, next = "Next: ride in a race!", go = "raceBoard" }
	end
	-- Garden ready?
	for _, b in profile.garden or {} do
		if b.seed ~= "" and (b.ready or Care.cropProgress(b, now) >= 1) then
			return { emoji = "🥕", fact = fact, next = "Next: crops are ready to pick", go = "stable" }
		end
	end
	return { emoji = "😴", fact = fact, next = "Napping. Try a ride on the Trail!", go = "trailGate" }
end

-- The "Next thing" pill (D-064, stage 3): one thing to do at a time, in a few plain words, with
-- where GO takes you. `go` is a Stable Board place ("stable", "paddock", "trailGate", "vet",
-- "track"), "race" (the RACE! button), "board" (open the Stable Board), "starter" (pick a first
-- horse) or nil (nothing to do: no GO). `key` changes when the suggestion does (Pip's hint).
export type Next = { key: string, emoji: string, icon: string, text: string, go: string? }

local SHORT_STAT = { speed = "Speed", accel = "Start", stamina = "Stamina", grit = "Grit" }

local function activeHorse(profile: any): any
	local first = nil
	for _, h in profile.horses or {} do
		if h.id == profile.activeHorse then return h end
		if not first and h.stalled ~= false then first = h end
	end
	return first
end

local function jobReady(j: any): boolean
	return not j.claimed and (j.progress or 0) >= (j.target or 1)
end

function Advice.nextThing(profile: any, now: number): Next
	local h = profile and activeHorse(profile)
	if not h then
		return { key = "starter", emoji = "🐴", icon = "heart", text = "Pick your first horse!", go = "starter" }
	end
	local name = h.name or "your horse"
	local jobs = profile.jobs or {}
	for _, set in { jobs.daily or {}, jobs.weekly or {}, jobs.monthly or {} } do
		for _, j in set do
			if jobReady(j) then return { key = "claim", emoji = "🎁", icon = "gift", text = "Get your job prize!", go = "board" } end
		end
	end
	if not h.fed then
		return { key = "feed:" .. tostring(h.id), emoji = "🌾", icon = "hay", text = "Feed " .. name .. " some hay", go = "stable" }
	end
	if not h.groomed then
		return { key = "groom:" .. tostring(h.id), emoji = "🪮", icon = "brush", text = "Brush " .. name, go = "stable" }
	end
	if h.cupOpen and not h.resting then
		return { key = "cup:" .. tostring(h.id), emoji = "🏆", icon = "trophy", text = "Win the Cup with " .. name .. "!", go = "race" }
	end
	for i, j in jobs.daily or {} do
		if not j.claimed then
			local go = if j.go == "raceBoard" then "race" else j.go
			return { key = "job:" .. tostring(j.id or i), emoji = "📋", icon = j.icon or "clipboard", text = j.text, go = go }
		end
	end
	if h.trainingReady then
		local stat = Advice.trainNext(h)
		return { key = "train:" .. tostring(h.id), emoji = "🎯", icon = "stat_" .. (stat or "speed"),
			text = if stat then "Train " .. name .. "'s " .. SHORT_STAT[stat] else "Train " .. name, go = "paddock" }
	end
	if not h.resting then
		return { key = "race:" .. tostring(h.id), emoji = "🏁", icon = "flag_ready", text = "Race with " .. name .. "!", go = "race" }
	end
	for _, b in profile.garden or {} do
		if b.seed ~= "" and (b.ready or Care.cropProgress(b, now) >= 1) then
			return { key = "crops", emoji = "🥕", icon = "carrot", text = "Pick your crops", go = "stable" }
		end
	end
	-- Every horse napping (D-058's words): nothing to do, so no GO.
	return { key = "nap", emoji = "😴", icon = "zzz_resting", text = "Great day! " .. name .. "'s dreaming of tomorrow.", go = nil }
end

-- Pip's hint (stage 3): the same suggestion has been up for pipHintSeconds and you haven't moved
-- in that time (lastMovedAt: when you last moved more than stillStuds). Once per suggestion.
function Advice.pipHintDue(shownAt: number, lastMovedAt: number, hinted: boolean, now: number, cfg: { pipHintSeconds: number }): boolean
	if hinted then return false end
	return now - math.max(shownAt, lastMovedAt) >= cfg.pipHintSeconds
end

Advice.PIP_HINT = "Pip says: tap GO and follow me!"

return Advice
