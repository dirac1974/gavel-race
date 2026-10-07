--!strict
-- Welcome Back Hay Bale (D-063, stage 6 of docs/plans/horse-life-and-retention.md). Pure, tested
-- under Lune. Coming back after comeback.awayDays (3) or more whole days away gives one flat gift
-- of hay, seeds and a treat, and the active horse trots up with it. The gift is the same size
-- however long you were away (never grows with absence: no guilt), it is never a streak or a
-- login calendar, and it never comes on two days in a row. Items are added at once (nothing is
-- lost by leaving); `pending` only shows the gift card until the player taps it.

local Profile = if script then require(script.Parent.Profile) :: any else require("./Profile")

local WelcomeBack = {}

export type Config = { enabled: boolean, awayDays: number, gift: { [string]: number } }

local function repair(p: any)
	local w = if typeof(p.welcome) == "table" then p.welcome else {}
	local gift = {}
	if typeof(w.gift) == "table" then
		for item, n in w.gift do
			if typeof(item) == "string" and table.find(Profile.ITEMS, item) and tonumber(n) then
				gift[item] = math.max(0, math.floor(tonumber(n) :: number))
			end
		end
	end
	p.welcome = { lastDay = tonumber(w.lastDay) or -1, pending = w.pending == true, gift = gift }
end
WelcomeBack.repair = repair

-- Whole days away: today minus the day last seen.
function WelcomeBack.daysAway(lastSeen: number, now: number): number
	return math.max(0, now // 86400 - lastSeen // 86400)
end

-- The player joined. `lastSeen` is the saved time of the last visit (before this join touches
-- it). Returns the gift given, or nil.
function WelcomeBack.onJoin(p: any, lastSeen: number, now: number, cfg: Config): { [string]: number }?
	repair(p)
	if not cfg.enabled then return nil end
	local today = now // 86400
	if WelcomeBack.daysAway(lastSeen, now) < cfg.awayDays then return nil end
	local last = p.welcome.lastDay
	if last >= 0 and today - last < 2 then return nil end -- never on consecutive days (or twice a day)
	local gift = {}
	for item, n in cfg.gift do
		if table.find(Profile.ITEMS, item) and n > 0 then
			Profile.addItem(p, item, n)
			gift[item] = n
		end
	end
	p.welcome.lastDay = today
	p.welcome.pending = true
	p.welcome.gift = gift
	return gift
end

-- The player tapped the gift card.
function WelcomeBack.seen(p: any): boolean
	repair(p)
	if not p.welcome.pending then return false end
	p.welcome.pending = false
	return true
end

-- What the owner's client sees (nil when there's no gift card to show).
function WelcomeBack.view(p: any): { [string]: any }?
	if typeof(p.welcome) ~= "table" or p.welcome.pending ~= true then return nil end
	return { gift = table.clone(p.welcome.gift or {}) }
end

return WelcomeBack
