--!strict
-- Careers (D-059, stage 7). Pure rules on horse records, tested under Lune.
--   No ageing and no decline: a horse only gains. A career badge every career.badgeEvery races
--   (🎖️), a Veteran at career.veteranAt, and then an opt-in Legend Retirement (Leagues.retire),
--   suggested once per horse and never forced.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")

local Career = {}

Career.BADGE, Career.LEGEND, Career.VETERAN = "🎖️", "👑", "🎖️"

local function cfg()
	return GameConfig.career
end

function Career.badges(races: number): number
	return math.max(0, math.floor((tonumber(races) or 0) / cfg().badgeEvery))
end

function Career.isVeteran(h: any): boolean
	return (h.record and h.record.races or 0) >= cfg().veteranAt
end

-- Races to go until the next badge (1..badgeEvery).
function Career.toNextBadge(races: number): number
	local every = cfg().badgeEvery
	return every - (math.max(0, math.floor(races)) % every)
end

-- A race took the horse from `before` to `after` races: the badge it just earned (its number of
-- races, e.g. 25, 50), and whether it just became a Veteran.
function Career.crossed(before: number?, after: number?): (number?, boolean)
	if not cfg().enabled or not before or not after or after <= before then return nil, false end
	local badge = if Career.badges(after) > Career.badges(before) then Career.badges(after) * cfg().badgeEvery else nil
	local veteran = before < cfg().veteranAt and after >= cfg().veteranAt
	return badge, veteran
end

-- The one-time Legend suggestion: a Veteran that isn't a Legend and hasn't been asked.
function Career.suggestLegend(h: any): boolean
	return cfg().enabled and Career.isVeteran(h) and h.legend == nil and h.legendAsked ~= true
end

-- Can this horse take Legend Retirement now (leaving the owner's other duties to Leagues)?
function Career.canBeLegend(h: any): boolean
	if h.legend ~= nil then return false end
	return not cfg().retireNeedsVeteran or Career.isVeteran(h)
end

-- The career row on a horse card: "🎖️ 2 badges · 🏆 1 Cup · Veteran". Short: icons and words.
function Career.line(races: number, cups: number, legend: boolean): string
	local parts = {}
	local b = Career.badges(races)
	table.insert(parts, string.format("%s %d %s", Career.BADGE, b, if b == 1 then "badge" else "badges"))
	if cups > 0 then table.insert(parts, string.format("🏆 %d %s", cups, if cups == 1 then "Cup" else "Cups")) end
	if legend then
		table.insert(parts, Career.LEGEND .. " Legend")
	elseif races >= cfg().veteranAt then
		table.insert(parts, "Veteran")
	end
	return table.concat(parts, " · ")
end

-- What a horse card shows about its career.
function Career.view(h: any): { [string]: any }
	local races = h.record and h.record.races or 0
	return {
		badges = Career.badges(races),
		toNextBadge = Career.toNextBadge(races),
		veteran = Career.isVeteran(h),
		legend = h.legend ~= nil,
		canBeLegend = Career.canBeLegend(h),
		suggestLegend = Career.suggestLegend(h),
		cups = h.record and h.record.cups or 0,
		line = Career.line(races, h.record and h.record.cups or 0, h.legend ~= nil),
	}
end

-- Horses that can wait at the riding school (rehome.maxWaiting), for Profile's load repair.
function Career.cfgRehomeMax(): number
	return GameConfig.rehome.maxWaiting
end

-- Toasts (each at most ui.toastMaxWords words).
function Career.badgeToast(name: string, badgeRaces: number): string
	return string.format("%s %s earned a %d-race badge!", Career.BADGE, name, badgeRaces)
end

function Career.veteranToast(name: string): string
	return string.format("%s %s is a Veteran now! Well done!", Career.VETERAN, name)
end

return Career
