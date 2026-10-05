--!strict
-- Care, food, garden, chores and the Feed & Seed (D-038). Pure rules on a Profile, so they
-- run under Lune; CareService checks who and where, then calls these.
--   Feed (hay or grain) and groom each fill half of today's care (Horse.tend: +5% Rating at
--   full care until rollover, never below baseline, +1 Energy every 2 h).
--   Treats (carrot, apple, oats, sugar cube) and petting add bond; a few treats a day count.
--   Garden beds grow while you're away, never wither, and wait until harvested.
--   Chores (muck out a stall) always pay hay, so nobody is ever stuck without food.
-- Every function returns (ok, message) where message is a short friendly line for a toast.

local Horse = if script then require(script.Parent.Horse) :: any else require("./Horse")
local Profile = if script then require(script.Parent.Profile) :: any else require("./Profile")

local Care = {}

Care.FEEDS = { hay = { bond = 0 }, grain = { bond = 1 } }
Care.TREATS = { carrot = 2, apple = 2, oats = 2, treat = 3 } -- bond per treat
Care.TREATS_PER_DAY = 3
Care.PET_BOND = 1
Care.SEEDS = {
	seed_carrot = { crop = "carrot", seconds = 60 * 60, yield = 3, label = "Carrots" },
	seed_apple = { crop = "apple", seconds = 4 * 60 * 60, yield = 4, label = "Apples" },
	seed_oats = { crop = "oats", seconds = 8 * 60 * 60, yield = 5, label = "Oats" },
}
Care.BEDS = 3
-- Feed & Seed prices in Green Cash (a Rookie race pays about 26 on average).
Care.SHOP = {
	{ item = "hay", price = 2, label = "Hay" },
	{ item = "grain", price = 5, label = "Grain" },
	{ item = "treat", price = 6, label = "Sugar cube" },
	{ item = "seed_carrot", price = 3, label = "Carrot seeds" },
	{ item = "seed_apple", price = 8, label = "Apple seeds" },
	{ item = "seed_oats", price = 6, label = "Oat seeds" },
}
Care.SELL = { carrot = 1, apple = 2, oats = 2 }
Care.CHORE = { cooldownSeconds = 4 * 60 * 60, hay = 1, cash = 2 }
Care.MAX_BUY = 20

local function today(now: number): number
	return now // 86400
end

local function priceOf(item: string): number?
	for _, row in Care.SHOP do
		if row.item == item then return row.price end
	end
	return nil
end
Care.priceOf = priceOf

-- Horses --------------------------------------------------------------------------
function Care.feed(p: any, h: any, item: string, now: number, energyCfg: any): (boolean, string)
	local food = Care.FEEDS[item]
	if not food then return false, "Horses eat hay or grain at mealtime" end
	if h.care.day == today(now) and h.care.fed then return false, h.name .. " has had a meal today" end
	if not Profile.takeItem(p, item, 1) then
		return false, if item == "hay" then "Out of hay! Muck out a stall or visit Feed & Seed" else "No grain left"
	end
	local _, topUp = Horse.tend(h, "feed", now, energyCfg, energyCfg.careTopUps)
	if food.bond > 0 then Horse.addBond(h, food.bond) end
	return true, h.name .. " munched happily!" .. (if topUp then " +1 Energy" else "")
end

function Care.groom(p: any, h: any, now: number, energyCfg: any): (boolean, string)
	if h.care.day == today(now) and h.care.groomed then return false, h.name .. " is already shiny today" end
	local _, topUp = Horse.tend(h, "groom", now, energyCfg, energyCfg.careTopUps)
	return true, h.name .. " is all shiny!" .. (if topUp then " +1 Energy" else "")
end

local function rollDaily(h: any, now: number)
	local d = today(now)
	if h.daily == nil or h.daily.day ~= d then h.daily = { day = d, treats = 0, petted = false } end
end

function Care.treat(p: any, h: any, item: string, now: number): (boolean, string)
	local bond = Care.TREATS[item]
	if not bond then return false, "That's not a treat" end
	rollDaily(h, now)
	if h.daily.treats >= Care.TREATS_PER_DAY then return false, h.name .. " is full of treats today" end
	if not Profile.takeItem(p, item, 1) then return false, "You don't have any" end
	h.daily.treats += 1
	Horse.addBond(h, bond)
	return true, h.name .. " loved that! +" .. bond .. " bond"
end

function Care.pet(p: any, h: any, now: number): (boolean, string)
	rollDaily(h, now)
	if h.daily.petted then return true, h.name .. " nuzzles you" end -- always nice, bond once a day
	h.daily.petted = true
	Horse.addBond(h, Care.PET_BOND)
	return true, h.name .. " nuzzles you! +1 bond"
end

-- Garden --------------------------------------------------------------------------
local function bed(p: any, i: number): any
	if typeof(i) ~= "number" or i < 1 or i > Care.BEDS or i ~= math.floor(i) then return nil end
	return p.garden[i]
end

function Care.cropProgress(b: any, now: number): number
	local seed = Care.SEEDS[b.seed]
	if not seed then return 0 end
	return math.clamp((now - b.at) / seed.seconds, 0, 1)
end

function Care.plant(p: any, i: number, seedItem: string, now: number): (boolean, string)
	local b = bed(p, i)
	if not b then return false, "No such bed" end
	if b.seed ~= "" then return false, "Something's already growing here" end
	local seed = Care.SEEDS[seedItem]
	if not seed then return false, "Plant seeds here" end
	if not Profile.takeItem(p, seedItem, 1) then return false, "You need seeds from Feed & Seed first" end
	b.seed, b.at = seedItem, now
	return true, seed.label .. " planted! They grow while you're away"
end

function Care.harvest(p: any, i: number, now: number): (boolean, string)
	local b = bed(p, i)
	if not b or b.seed == "" then return false, "Nothing growing here" end
	if Care.cropProgress(b, now) < 1 then return false, "Not ready yet" end
	local seed = Care.SEEDS[b.seed]
	Profile.addItem(p, seed.crop, seed.yield)
	b.seed, b.at = "", 0
	return true, string.format("Picked %d %s!", seed.yield, seed.label:lower())
end

-- Chores --------------------------------------------------------------------------
function Care.chore(p: any, stall: number, now: number): (boolean, string)
	if typeof(stall) ~= "number" or stall < 1 or stall > p.stalls or stall ~= math.floor(stall) then return false, "No such stall" end
	local key = tostring(stall)
	local last = p.chores[key] or 0
	if now - last < Care.CHORE.cooldownSeconds then return false, "This stall is already sparkling clean" end
	p.chores[key] = now
	Profile.addItem(p, "hay", Care.CHORE.hay)
	Profile.addCash(p, Care.CHORE.cash)
	return true, string.format("Stall mucked out! +%d hay, +%d Green Cash", Care.CHORE.hay, Care.CHORE.cash)
end

-- Feed & Seed ---------------------------------------------------------------------
function Care.buy(p: any, item: string, qty: number): (boolean, string)
	local price = priceOf(item)
	if not price then return false, "Not for sale" end
	if typeof(qty) ~= "number" or qty < 1 or qty > Care.MAX_BUY or qty ~= math.floor(qty) then return false, "How many?" end
	if not Profile.spendCash(p, price * qty) then return false, "Not enough Green Cash yet. Races and chores earn more!" end
	Profile.addItem(p, item, qty)
	return true, string.format("Bought %d!", qty)
end

function Care.sell(p: any, item: string, qty: number): (boolean, string)
	local price = Care.SELL[item]
	if not price then return false, "Feed & Seed buys carrots, apples and oats" end
	if typeof(qty) ~= "number" or qty < 1 or qty ~= math.floor(qty) then return false, "How many?" end
	if not Profile.takeItem(p, item, qty) then return false, "You don't have that many" end
	Profile.addCash(p, price * qty)
	return true, string.format("Sold for %d Green Cash", price * qty)
end

-- Sell every crop above `keep` of each in one go.
function Care.sellAll(p: any, keep: number): (boolean, string)
	if typeof(keep) ~= "number" or keep < 0 or keep ~= math.floor(keep) then return false, "How many?" end
	local total = 0
	for item, price in Care.SELL do
		local extra = Profile.itemCount(p, item) - keep
		if extra > 0 and Profile.takeItem(p, item, extra) then total += price * extra end
	end
	if total == 0 then return false, string.format("Nothing to sell (you keep %d of each for treats)", keep) end
	Profile.addCash(p, total)
	return true, string.format("Sold for %d Green Cash", total)
end

return Care
