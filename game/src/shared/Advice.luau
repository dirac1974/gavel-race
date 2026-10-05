--!strict
-- Advice (D-043): what the Stable Board says about each horse. One true fact about the horse
-- right now, and one next step with where to GO. Facts about the horse only; never guilt
-- ("Comet misses you", "Comet is hungry" are never written). Pure, works on the client's
-- profile view, tested under Lune.

local Care = if script then require(script.Parent.Care) :: any else require("./Care")

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
	elseif h.trainingReady then
		local stat = Advice.trainNext(h)
		return { emoji = "⭐", fact = fact, next = if stat then "Next: train " .. STAT_LABEL[stat] else "Next: a training session", go = "paddock" }
	elseif not h.resting then
		return { emoji = "🏁", fact = fact, next = "Next: ride in a race!", go = "raceBoard" }
	end
	-- Garden ready?
	for _, b in profile.garden or {} do
		if b.seed ~= "" and (b.ready or Care.cropProgress(b, now) >= 1) then
			return { emoji = "🥕", fact = fact, next = "Next: crops are ready to pick", go = "stable" }
		end
	end
	return { emoji = "😴", fact = fact, next = "Resting. Try a ride on the Trail!", go = "trailGate" }
end

return Advice
