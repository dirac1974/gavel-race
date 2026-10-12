--!strict
-- The class path and the Cup bar (fun-and-return phase 2, D-076). Pure, tested under Lune.
--   First Win -> Rising Star -> Open -> Top Horse (Big Race once named races exist, classes.starIsRace) -> Cup, from the horse's wins in its own league
--   (Leagues.wins) and its Cup (Leagues.cupOpen). Labels only: never a queue, never win chance.
--   The next goal names the next step ("💐 Top Horse: 2 more wins"). The step becomes the coming
--   named prestige race (next build).
--   The Cup bar is League Points over the league's Cup points (stakesUnlockPoints), shown as a fill,
--   never a number (D-064). The top league has no Cup: its path ends at Top Horse.

local GameConfig = if script then require(script.Parent.GameConfig) :: any else require("./GameConfig")
local Leagues = if script then require(script.Parent.Leagues) :: any else require("./Leagues")

local ClassPath = {}

ClassPath.STEPS = { "FirstWin", "RisingStar", "Open", "Top", "Cup" }
ClassPath.EMOJI = { FirstWin = "🐣", RisingTop = "🚀", Open = "🎽", Top = "💐", Cup = "🏆" }
ClassPath.WORD = { FirstWin = "First Win", RisingTop = "Rising Star", Open = "Open", Top = "Top Horse", Cup = "Cup" }

local function cfg(): any
	return GameConfig.classes or {}
end

function ClassPath.enabled(): boolean
	return cfg().path ~= false
end

-- The words for a step: "Top Horse" until named races exist (classes.starIsRace), then "Big Race".
function ClassPath.word(step: string): string
	if step == "Top" and cfg().starIsRace then return "Big Race" end
	return ClassPath.WORD[step] or step
end

function ClassPath.label(step: string): string
	return (ClassPath.EMOJI[step] or "") .. " " .. ClassPath.word(step)
end

local function more(n: number, what: string): string
	return string.format("%d more %s", n, if n == 1 then what else what .. "s")
end

-- Fill of the Cup bar 0..1 for `points` in `league`, or nil in the top league (no Cup).
function ClassPath.cupFill(league: string?, points: number?): number?
	local need = Leagues.UNLOCK[league or "Rookie"]
	if not need or need <= 0 then return nil end
	return math.clamp((tonumber(points) or 0) / need, 0, 1)
end

-- The path for a horse record (or a view with league, points and leagueWins).
--   steps: the step ids shown; at: the index reached; next: the next goal's words (nil at the end);
--   cupFill: the Cup bar 0..1 (nil in the top league); cupOpen.
function ClassPath.view(h: any, cupOpen: boolean?): { [string]: any }
	local league = h.league or "Rookie"
	local wins = Leagues.wins(h)[league] or 0
	local hasCup = Leagues.next(league) ~= nil
	local steps = table.clone(ClassPath.STEPS)
	if not hasCup then table.remove(steps) end
	local rising = Leagues.RISING_STAR_BELOW
	local top = math.max(rising + 1, math.floor(tonumber(cfg().topWins) or 5))
	local at
	if cupOpen and hasCup then
		at = 5
	elseif wins >= top then
		at = 4
	elseif wins >= rising then
		at = 3
	elseif wins >= 1 then
		at = 2
	else
		at = 1
	end
	local nextText: string? = nil
	if at == 1 then
		nextText = "Next: win a race!"
	elseif at == 2 then
		nextText = ClassPath.label("Open") .. ": " .. more(rising - wins, "win")
	elseif at == 3 then
		nextText = ClassPath.label("Top") .. ": " .. more(top - wins, "win")
	elseif at == 4 and hasCup then
		nextText = "Next: fill the 🏆 Cup bar"
	elseif at == 5 then
		nextText = "Win the Cup to move up!"
	end
	return {
		steps = steps,
		at = at,
		step = steps[at],
		next = nextText,
		cupFill = ClassPath.cupFill(league, h.points),
		cupOpen = cupOpen == true and hasCup,
	}
end

-- A step that rose (for the class-up ceremony): the new step id when `after` is past `before`.
function ClassPath.rose(before: number?, after: number?): boolean
	return before ~= nil and after ~= nil and after > before
end

function ClassPath.ceremonyLine(name: string, step: string): string
	if step == "Cup" then return "🏆 " .. name .. "'s Cup is open!" end
	if step == "RisingStar" then return "🚀 " .. name .. " is a Rising Star!" end
	if step == "Open" then return "🎽 " .. name .. " is Open class!" end
	if step == "Top" then
		return if cfg().starIsRace then "💐 " .. name .. " is Big Race ready!" else "💐 " .. name .. " is a Top Horse!"
	end
	return "🐣 " .. name .. " is racing!"
end

return ClassPath
