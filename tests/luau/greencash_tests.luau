--!strict
-- Green Cash sink, game half (D-070, provisional): Barn Builder. Green Cash only, never Diamonds;
-- one currency per shop (both ways); nothing random, nothing a trophy, nothing the yard already has
-- for free (variants only); every piece has a fixed spot; BuyCash checks the item, its tier, the
-- Green Cash and ownership, and a return works within the day only; the tier high-water mark never
-- goes down; the "You can build" pill stays out of the race loop and the tour.
local fs = require("@lune/fs")
local Profile = require("../../game/src/shared/Profile")
local Horse = require("../../game/src/shared/Horse")
local Style = require("../../game/src/shared/Style")
local BarnCatalog = require("../../game/src/shared/BarnCatalog")
local Advice = require("../../game/src/shared/Advice")
local Leagues = require("../../game/src/shared/Leagues")
local Visits = require("../../game/src/shared/Visits")
local Words = require("../../game/src/shared/Words")
local GameConfig = require("../../game/src/shared/GameConfig")
local WorldLayout = require("../../game/src/shared/WorldLayout")

local DAY = 86400
local T0 = 20000 * DAY + 3600

local function horse(id: string, league: string)
	local h = Horse.new(id, "Comet", "bay", { speed = 50, accel = 50, stamina = 50, grit = 50 },
		{ speed = 80, accel = 80, stamina = 80, grit = 80 }, T0)
	h.league = league
	return h
end

-- Code without its comments (a `--` outside a string starts one).
local function code(src: string): string
	local out = {}
	for _, line in string.split(src, "\n") do
		local inStr: string? = nil
		local cut = #line
		local i = 1
		while i <= #line do
			local c = string.sub(line, i, i)
			if inStr then
				if c == "\\" then i += 1 elseif c == inStr then inStr = nil end
			elseif c == '"' or c == "'" or c == "`" then
				inStr = c
			elseif c == "-" and string.sub(line, i + 1, i + 1) == "-" then
				cut = i - 1
				break
			end
			i += 1
		end
		table.insert(out, string.sub(line, 1, cut))
	end
	return table.concat(out, "\n")
end

local function has(src: string, s: string): boolean
	return string.find(src, s, 1, true) ~= nil
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	local GC = GameConfig.greenCash
	check(GC ~= nil and GC.enabled == true and GC.wishChip == true and GC.pillAfterRaceSeconds == 120 and GC.returnHours == 24
		and GC.buildFx == true and GC.newBuildHours == 48, "GameConfig.greenCash has the D-070 keys")

	-- The catalog -------------------------------------------------------------------------------
	local SLOTS = { paint = true, cloth = true, helmet = true, plate = true, doors = true, trim = true, frame = true, fence = true, yard = true }
	local BUILDS = { tree = true, logJump = true, swapTrough = true, swapBarrow = true, swapBucket = true, swapHay = true, swapShoe = true,
		swapPhoto = true, hayloft = true, bunting = true, weathervane = true, gateArch = true }
	local NOT_SOLD = { "trophy", "rosette", "cup", "medal", "ribbon", "random", "mystery", "surprise", "lucky", "luck", "limited", "sale",
		"deal", "offer", "coat", "speed", "energy", "rating", "diamond", "horse " }
	local ids, perTier, swaps = {}, {}, {}
	local catalogOk, notSoldOk, spotOk, idsOk = true, true, true, true
	for _, it in BarnCatalog.ITEMS do
		if ids[it.id] or string.sub(it.id, 1, 3) ~= "bb_" then idsOk = false end
		ids[it.id] = true
		perTier[it.tier] = (perTier[it.tier] or 0) + 1
		if not SLOTS[it.slot] or not BarnCatalog.tierIndex(it.tier) or it.price <= 0 or it.price % 25 ~= 0 or it.emoji == "" then
			catalogOk = false
		end
		if it.slot == "yard" and not (it.build and BUILDS[it.build]) then catalogOk = false end
		local lower = string.lower(it.name)
		for _, w in NOT_SOLD do
			if string.find(lower, w, 1, true) then
				notSoldOk = false
				print("  not sold for 💵: " .. it.name .. " (" .. w .. ")")
			end
		end
		if Words.banned(it.name) then notSoldOk = false end
		-- the icon too (code review B1): nothing that looks like a win, and 🎀 is the monthly stamps
		for _, e in { "🏵", "🎖", "🏅", "🏆", "🥇", "🥈", "🥉", "🎀" } do
			if string.find(it.emoji, e, 1, true) or string.find(it.id, e, 1, true) or string.find(it.name, e, 1, true) then
				notSoldOk = false
				print("  not sold for 💵 (icon): " .. it.id .. " " .. it.emoji)
			end
		end
		local s = it.spot
		if typeof(s) == "table" then
			if not (#s == 2 and s[1] > 0 and s[1] < WorldLayout.PLOT_DEPTH and math.abs(s[2]) < WorldLayout.PLOT_FRONT / 2 - 2) then spotOk = false end
		elseif typeof(s) ~= "string" or BarnCatalog.ANCHORS[s] == nil then
			spotOk = false
		end
		if it.build and string.sub(it.build, 1, 4) == "swap" then
			if swaps[it.build] then catalogOk = false end -- one variant per free prop
			swaps[it.build] = true
		end
	end
	check(idsOk, "Barn Builder ids are unique and start bb_")
	check(catalogOk, "every Barn Builder item has a slot, a tier, a 💵 price in steps of 25 and (yard) a way to build it")
	check(notSoldOk, "never sold for Green Cash: trophies, rosettes, Cups, anything random, coats, stats, Energy")
	check(spotOk, "every Barn Builder item has a fixed spot in the plot or a named anchor")
	for _, tier in BarnCatalog.TIERS do check((perTier[tier] or 0) >= 3, `the {tier} shelf has things on it`) end
	local styleSrc = fs.readFile("game/src/shared/Style.luau")
	check(not has(code(styleSrc), "math.random") and not has(code(fs.readFile("game/src/shared/BarnCatalog.luau")), "random"),
		"nothing in Style or the catalog rolls anything")

	-- Free yard props are sold only as variants; never a Diamond yard piece, never the Fair Street shed.
	local stable = code(fs.readFile("game/src/server/StableService.server.luau"))
	local free = {}
	for slot in string.gmatch(stable, "placeModel%(barn, \"([%w_]+)\"") do free[slot] = true end
	check(free.water_trough and free.hay_bale and free.wheelbarrow and free.feed_bucket and free.horseshoe_decor and free.photo_frame_stand,
		"the lint sees StableService's free yard props")
	local diamondModels = {}
	for _, it in Style.shopItems("tack") do
		if it.model then diamondModels[it.model] = true end
	end
	local dupOk = true
	for _, it in BarnCatalog.ITEMS do
		local isSwap = it.build ~= nil and string.sub(it.build, 1, 4) == "swap"
		if it.model and free[it.model] and not isSwap then dupOk = false end
		if it.model and diamondModels[it.model] then dupOk = false end
		if it.model == "training_shed" then dupOk = false end
	end
	check(dupOk, "Barn Builder never sells a free yard prop again (variants swap in), a Diamond piece or the training shed")
	for build, anchor in { swapTrough = "trough", swapBarrow = "barrow", swapBucket = "bucket", swapHay = "hay", swapShoe = "horseshoe", swapPhoto = "photo" } do
		check(has(stable, "BarnDecor.swapped(data, \"" .. anchor .. "\")"), `StableService leaves out the free {anchor} when {build} is placed`)
	end
	-- Fixed spots keep clear of each other and of the yard's fixed things.
	local taken = {
		{ 22, 18 }, { 2, 20 }, { 2, -20 }, { 16, 32 }, { 36, -16 }, { 76, 16 }, { 12, -28 }, -- Tack & Paint yard
		{ 52, 12 }, { 54, -4 }, { 3, 10 }, { 3, -10 }, { 9, -16 }, { 16, 0 }, -- wall, photo board, post box, bell, board, arrival
		{ 26, -35 }, { 40, -35 }, { 54, -35 }, -- garden beds
	}
	local clear = true
	local mine = {}
	for _, it in BarnCatalog.ITEMS do
		if typeof(it.spot) == "table" then table.insert(mine, it.spot) end
	end
	for k, s in mine do
		for _, t in taken do
			if math.sqrt((s[1] - t[1]) ^ 2 + (s[2] - t[2]) ^ 2) < 8 then clear = false end
		end
		for j = k + 1, #mine do
			if math.sqrt((s[1] - mine[j][1]) ^ 2 + (s[2] - mine[j][2]) ^ 2) < 8 then clear = false end
		end
		-- the Hall of Fame paddock (inward 62..80, across -34..-10) and the barn (inward 88+)
		if (s[1] > 58 and s[1] < 84 and s[2] > -38 and s[2] < -6) or s[1] > 84 then clear = false end
	end
	check(clear, "Barn Builder's own spots keep clear of the yard's fixed things and of each other")

	-- One currency per shop, both ways --------------------------------------------------------------
	local tack, barn = Style.shopItems("tack"), Style.shopItems("barn")
	local sepOk = #tack + #barn == #Style.ITEMS and #barn == #BarnCatalog.ITEMS
	for _, it in tack do
		if Style.isCash(it) or Style.forCash(it) then sepOk = false end
	end
	for _, it in barn do
		if not Style.isCash(it) or Style.forSale(it) or not Style.forCash(it) then sepOk = false end
		if it.fanLevel or it.month or it.set then sepOk = false end
	end
	check(sepOk, "Tack & Paint lists no 💵 item and Barn Builder no 💎 item; no item has both prices")
	for _, it in Style.ITEMS do
		if Style.forSale(it) and Style.forCash(it) then check(false, it.id .. " is for sale in both currencies") end
	end
	local rich = Profile.new(T0)
	rich.diamonds, rich.cash, rich.bestLeague = 100000, 100000, "Champion"
	local okD, _ = Style.buy(rich, "bb_paint_sky", T0)
	check(not okD and rich.diamonds == 100000 and not Style.owns(rich, "bb_paint_sky"), "a Barn Builder item refuses Diamonds")
	local okC, _, whyC = Style.buyCash(rich, "paint_meadow", T0)
	check(not okC and whyC == "missing" and rich.cash == 100000 and not Style.owns(rich, "paint_meadow"), "a Tack & Paint item refuses Green Cash")
	check(not (Style.buyCash(rich, "fan_star", T0)) and not (Style.buyCash(rich, "cloth_m01", T0)), "earned things are never sold for Green Cash")
	local shop = code(fs.readFile("game/src/client/StyleShop.client.luau"))
	check(has(shop, "Style.shopItems(\"tack\")") and not has(shop, "BuyCash") and has(shop, "💎 Tack & Paint looks. 🔨 Barn Builder uses 💵."),
		"Tack & Paint lists its own items only, never builds with Green Cash, and points to Barn Builder")
	local bb = code(fs.readFile("game/src/client/BarnBuilder.client.luau"))
	check(not has(bb, "💎") and not has(bb, "StyleBuy") and not has(bb, "BuyDiamonds") and not has(bb, "diamonds()"),
		"Barn Builder shows no 💎 anywhere and never spends Diamonds")
	check(has(bb, "Ui.fitPanel(panel, W, H, 300, 16, 64)") and has(bb, "C.textGood") and has(bb, "\"🔨 Barn Builder\"")
		and has(bb, "C.cash") and has(bb, "\"💵 \" .. fmt(it.price)"), "Barn Builder: fitPanel at 16 / 64, a 🔨 header on the 💵 band, 💵 on every price")
	check(has(bb, "\"Opens when a horse reaches \" .. tier") and has(bb, "\"↩️ Return\"") and has(bb, "\"Sure? ↩️\"")
		and has(bb, "\"You can return it until tomorrow\"") and has(bb, "\"See it ▶\""), "Barn Builder's words: the next shelf, the two-tap return, See it")
	check(not has(string.lower(bb), "limited") and not has(string.lower(bb), "sale") and not has(string.lower(bb), "deal")
		and not has(bb, "countdown") and not has(bb, "%d:%02d"), "no limited, sale or deal, and no clock")

	-- Buying with Green Cash -------------------------------------------------------------------------
	local p = Profile.new(T0)
	Profile.addHorse(p, horse("h1", "Rookie"))
	p.cash = 1000
	local ok1, msg1, why1 = Style.buyCash(p, "bb_apple_tree_1", T0) -- Bronze shelf, still a Rookie
	check(not ok1 and why1 == "tier" and p.cash == 1000 and not Style.owns(p, "bb_apple_tree_1") and Words.toastOk(msg1),
		"a closed shelf can't be bought from (and says so kindly)")
	p.cash = 299
	local ok2, msg2, why2 = Style.buyCash(p, "bb_paint_cherry", T0)
	check(not ok2 and why2 == "cash" and p.cash == 299 and Words.toastOk(msg2), "not enough Green Cash: nothing changes")
	p.cash = 1000
	local earned = p.totals.cashEarned
	check(Style.setWish(p, "bb_paint_cherry") and p.style.wish == "bb_paint_cherry", "wish set")
	local ok3, msg3 = Style.buyCash(p, "bb_paint_cherry", T0)
	check(ok3 and msg3 == "Cherry barn paint built!" and p.cash == 700 and Style.owns(p, "bb_paint_cherry")
		and Style.worn(p, "paint").id == "bb_paint_cherry" and p.style.paidIn.bb_paint_cherry == "cash" and p.style.builtAt.bb_paint_cherry == T0,
		"building pays its price once, owns it and puts it on the barn")
	check(p.style.wish == nil, "building the wished thing clears the wish")
	check(p.totals.cashEarned == earned, "spending never changes Green Cash earned")
	local ok4, _, why4 = Style.buyCash(p, "bb_paint_cherry", T0)
	check(not ok4 and why4 == "owned" and p.cash == 700, "no double builds")
	local ok5, _, why5 = Style.buyCash(p, "nope", T0)
	check(not ok5 and why5 == "missing", "unknown ids are refused")
	Style.buyCash(p, "bb_trough_painted", T0)
	check(#Style.yard(p) == 1 and Style.yard(p)[1].id == "bb_trough_painted", "a yard piece is placed when built")

	-- Returns: within the day, all the Green Cash back; not after --------------------------------------
	local hour = 3600
	check(Style.canReturn(p, "bb_paint_cherry", T0 + 23 * hour) and not Style.canReturn(p, "bb_paint_cherry", T0 + 24 * hour),
		"a build can be returned for 24 hours (greenCash.returnHours)")
	local okR, msgR = Style.giveBack(p, "bb_paint_cherry", T0 + 2 * hour)
	check(okR and p.cash == 700 and Words.toastOk(msgR), "the return gives all its Green Cash back (1000 - 300 - 300 + 300)")
	check(p.diamonds == 0 and not Style.owns(p, "bb_paint_cherry") and Style.worn(p, "paint").id == "paint_classic"
		and p.totals.cashEarned == earned, "a Green Cash return pays Green Cash, never Diamonds, and isn't counted as earned")
	local okLate = Style.giveBack(p, "bb_trough_painted", T0 + 25 * hour)
	check(not okLate and Style.owns(p, "bb_trough_painted"), "after a day it stays yours")

	-- The tier high-water mark ------------------------------------------------------------------------
	check(table.concat(Profile.LEAGUE_ORDER, ",") == table.concat(Leagues.ORDER, ","), "Profile's league order is Leagues.ORDER")
	local q = Profile.new(T0)
	check(q.bestLeague == "Rookie" and q.style.shelfSeen == "Rookie", "a new stable starts on the Starter shelf")
	local hq = horse("h1", "Rookie")
	Profile.addHorse(q, hq)
	local _, rose0 = Profile.syncBestLeague(q)
	check(not rose0 and q.bestLeague == "Rookie", "nothing new: no new shelf")
	hq.league = "Silver"
	local best1, rose1 = Profile.syncBestLeague(q)
	check(best1 == "Silver" and rose1, "a horse reaching Silver opens the Silver shelf")
	hq.league = "Rookie"
	Profile.removeHorse(q, "h1")
	local best2 = Profile.syncBestLeague(q)
	check(best2 == "Silver", "the high-water mark never goes down (the horse left)")
	local old = Profile.new(T0)
	old.bestLeague, old.style.shelfSeen = nil, nil
	table.insert(old.horses, horse("h1", "Gold"))
	old.hallOfFame = { { name = "Old Timer", league = "Champion" } }
	local m = Profile.migrate(old, T0)
	check(m.bestLeague == "Champion" and m.style.shelfSeen == "Champion", "an older save: Legends' plaques count, and no 'new shelf' for what it had")
	local junk = Profile.new(T0)
	junk.bestLeague, junk.style.wish, junk.style.builtAt = "Platinum", 42, "x"
	local mj = Profile.migrate(junk, T0)
	check(mj.bestLeague == "Rookie" and mj.style.wish == nil and mj.style.builtAt == nil, "junk is cleaned on load")
	local rehome = Profile.new(T0)
	rehome.rehomed = { { horse = horse("h9", "Gold"), expires = T0 + DAY, cash = 0 } }
	check(Profile.syncBestLeague(rehome) == "Gold", "a horse at the riding school still counts")
	local view = Profile.view(m, T0, GameConfig.energy)
	check(view.bestLeague == "Champion" and view.style.shelfSeen == "Champion", "the owner's view carries the shelf")

	-- Shelves: open tiers, then only the next one (greyed, no price), later ones hidden --------------------
	local r = Profile.new(T0)
	local openR, nextR, lockedR = Style.shelf(r)
	local onlyStarter = true
	for _, it in openR do if it.tier ~= "Rookie" then onlyStarter = false end end
	local onlyBronze = #lockedR > 0
	for _, it in lockedR do if it.tier ~= "Bronze" then onlyBronze = false end end
	check(onlyStarter and nextR == "Bronze" and onlyBronze, "a Rookie sees the Starter shelf and the Bronze one greyed; nothing later")
	r.bestLeague = "Gold"
	local openG, nextG, lockedG = Style.shelf(r)
	check(#openG == #BarnCatalog.ITEMS - (perTier.Champion or 0) and nextG == "Champion" and #lockedG == perTier.Champion, "Gold: up to Gold open, Champion greyed")
	r.bestLeague = "Champion"
	local openC, nextC, lockedC = Style.shelf(r)
	check(#openC == #BarnCatalog.ITEMS and nextC == nil and #lockedC == 0, "Champion: everything open")

	-- The wish ------------------------------------------------------------------------------------------
	local w = Profile.new(T0)
	w.cash = 150
	check(not (Style.setWish(w, "bb_apple_tree_1")), "no wish on a closed shelf")
	check(not (Style.setWish(w, "paint_meadow")), "no wish on a Diamond look")
	check(Style.setWish(w, "bb_paint_cherry"), "a wish on an open shelf")
	local wi, fill = Style.wishProgress(w)
	check(wi ~= nil and wi.id == "bb_paint_cherry" and math.abs(fill - 0.5) < 1e-9, "the wish bar is Green Cash over price")
	w.cash = 5000
	local _, full = Style.wishProgress(w)
	check(full == 1, "the bar stops full")
	check(Style.setWish(w, nil) and w.style.wish == nil and Style.wishProgress(w) == nil, "a wish can be cleared")

	-- The "You can build" pill ----------------------------------------------------------------------------
	local k = Profile.new(T0)
	local hk = horse("h1", "Rookie")
	Profile.addHorse(k, hk)
	k.totals.races = 10
	k.cash = 1000
	Style.setWish(k, "bb_paint_mint")
	local function kidView(over: any?)
		local v = Profile.view(k, T0, GameConfig.energy)
		for _, h in v.horses do h.fed, h.groomed = true, true end
		v.jobs = { daily = { { id = "d_x", text = "Pat a horse", progress = 0, target = 1, claimed = false } } }
		for key, val in over or {} do v[key] = val end
		return v
	end
	local calm = { sinceRace = 300, busy = false, resultsOpen = false, raceAgain = false, touring = false }
	local pill = Advice.buildPill(kidView(), calm)
	check(pill ~= nil and pill.key == "build:bb_paint_mint" and pill.text == "You can build the Mint barn paint!" and pill.go == "barnBuilder",
		"affordable wish: the pill says so, GO to Feed & Seed")
	check(Advice.nextThing(kidView(), T0, calm).key == "build:bb_paint_mint", "...and it is the next thing over the day's jobs")
	check(Advice.buildPill(kidView(), nil) == nil and Advice.nextThing(kidView(), T0).key ~= "build:bb_paint_mint", "no context, no pill")
	for name, ctx in {
		busy = { sinceRace = 300, busy = true }, results = { sinceRace = 300, resultsOpen = true }, raceAgain = { sinceRace = 300, raceAgain = true },
		tour = { sinceRace = 300, touring = true }, justRaced = { sinceRace = 119 },
	} do
		check(Advice.buildPill(kidView(), ctx :: any) == nil, `no "You can build" pill: {name}`)
	end
	check(Advice.buildPill(kidView(), { sinceRace = 120 }) ~= nil and Advice.buildPill(kidView(), {}) ~= nil, "after 120 s (or before any race) it may show")
	-- below racing first, job prizes and feeding
	k.totals.races = 0
	check(Advice.nextThing(kidView(), T0, calm).key ~= "build:bb_paint_mint", "racing first comes before the pill")
	k.totals.races = 10
	local prize = kidView()
	prize.jobs.daily[1].progress = 1
	check(Advice.nextThing(prize, T0, calm).key == "claim", "a job prize comes before the pill")
	local hungry = kidView()
	hungry.horses[1].fed = false
	check(string.sub(Advice.nextThing(hungry, T0, calm).key, 1, 5) == "feed:", "feeding comes before the pill")
	k.style.wishTold = "bb_paint_mint"
	check(Advice.buildPill(kidView(), calm) == nil, "once per item")
	k.style.wishTold = nil
	k.cash = 100
	check(Advice.buildPill(kidView(), calm) == nil, "not affordable: no pill")
	k.cash = 1000
	GC.enabled = false
	check(Advice.buildPill(kidView(), calm) == nil, "greenCash.enabled = false: no pill")
	GC.enabled = true
	-- copy: every line built from a catalog name stays short and kind
	local copyOk = true
	for _, it in BarnCatalog.ITEMS do
		for _, line in { "You can build the " .. it.name .. "!", it.name .. " built!", it.name .. " is ready to ride!",
			string.format("%s costs 💵 %d", it.name, it.price), "Returned " .. it.name .. ": +💵 " .. it.price } do
			local okW, why = Words.toastOk(line, GameConfig.ui.toastMaxWords)
			if not okW then
				copyOk = false
				print(`  copy: "{line}" {why}`)
			end
		end
	end
	check(copyOk, "every Barn Builder toast and pill is at most 10 words, no banned word")
	check(Words.toastOk("New shelf at Barn Builder!") and Words.toastOk("Go see it! Follow the hoofprints"), "the shelf note and Go see it")

	-- Friends' barns: ✨ for 48 h after a build, no counts ---------------------------------------------
	local f = Profile.new(T0)
	f.cash, f.bestLeague = 10000, "Bronze"
	Style.buyCash(f, "bb_apple_tree_1", T0)
	check(Style.freshBuildId(f, T0 + 47 * hour, 48) == "bb_apple_tree_1" and Style.freshBuildId(f, T0 + 48 * hour, 48) == nil,
		"a new build is fresh for 48 hours")
	local list = Visits.list(1, { { userId = 2, name = "Ann", visits = "Friends", hasBarn = true, fresh = true },
		{ userId = 3, name = "Bo", visits = "Friends", hasBarn = true } }, function() return true end, GameConfig.visit)
	check(#list == 2 and list[1].fresh == true and list[2].fresh == false and list[1].count == nil, "the Friends' barns list carries ✨ only")
	local wc = code(fs.readFile("game/src/client/WorldClient.client.luau"))
	check(has(wc, "\"✨ \" .. f.name"), "the ✨ sits by the friend's name")

	-- Fix batch (code review, consults) ------------------------------------------------------------------
	local dp = Profile.new(T0)
	dp.diamonds = 500
	Style.buy(dp, "paint_meadow", T0)
	check(dp.style.paidIn.paint_meadow == "diamonds", "a Diamond buy records paidIn")
	dp.style.paidIn.paint_meadow = "diamonds"
	local cashBefore = dp.cash
	Style.giveBack(dp, "paint_meadow", T0 + 60)
	check(dp.diamonds == 500 and dp.cash == cashBefore, "a return trusts paidIn: Diamonds back as Diamonds, never Green Cash")
	local _, eqMsg = Style.equip(Profile.new(T0), "bb_paint_sky")
	check(eqMsg == "Build it at Barn Builder first", "an unbuilt Barn Builder item points to Barn Builder")
	check(has(code(styleSrc), "Profile.spendCash(p, it.price)"), "Style.buyCash pays through Profile.spendCash")
	-- "New shelf" is a one-time pill with GO, same calm rules
	local sp2 = Profile.new(T0)
	Profile.addHorse(sp2, horse("h1", "Bronze"))
	sp2.totals.races = 10
	Profile.syncBestLeague(sp2)
	local function shelfView()
		local v = Profile.view(sp2, T0, GameConfig.energy)
		for _, h in v.horses do h.fed, h.groomed = true, true end
		return v
	end
	local sh = Advice.shelfPill(shelfView(), calm)
	check(sh ~= nil and sh.text == "New shelf at Barn Builder!" and sh.go == "barnBuilder" and Advice.nextThing(shelfView(), T0, calm).key == "shelf:Bronze",
		"after a promotion: the New shelf pill with GO to Feed & Seed")
	check(Advice.shelfPill(shelfView(), { sinceRace = 60 }) == nil and Advice.shelfPill(shelfView(), { sinceRace = 300, resultsOpen = true }) == nil
		and Advice.shelfPill(shelfView(), { sinceRace = 300, touring = true }) == nil and Advice.shelfPill(shelfView(), nil) == nil,
		"the New shelf pill keeps the calm-moment rules")
	sp2.style.shelfSeen = "Bronze"
	check(Advice.shelfPill(shelfView(), calm) == nil, "once only")
	check(has(bb, "BuildFx.inView(focus, 60)") and has(bb, "showMarker(focus)") and has(code(fs.readFile("game/src/client/BuildFx.luau")), "\"✨ Here!\""),
		"the reveal waits until the spot is on screen; ✨ Here! until then")
	check(has(bb, "Ui.fitPanel(panel, W, H, 300, 16, 64)") and has(bb, "Instance.new(\"ScrollingFrame\")"),
		"Barn Builder's band and ✕ stay pinned: only the shelves scroll")
	local decor = code(fs.readFile("game/src/server/BarnDecor.luau"))
	check(has(decor, "tint(arch, Color3.fromHex(\"FBFBF5\")") and has(decor, "Instance.new(\"Beam\")") and has(decor, "\"bunting_strip\""),
		"the gate arch is painted barn white; bunting is Beams with bunting_strip")
	check(has(code(fs.readFile("game/src/client/BuildFx.luau")), "if BuildFx.reducedMotion() then return end"), "sparkles and dust respect Reduced Motion")

	-- The server's BuyCash checks it all again --------------------------------------------------------
	local svc = code(fs.readFile("game/src/server/StyleService.server.luau"))
	check(has(svc, "Profiles.remote(\"BuyCash\")") and has(svc, "Style.buyCash(data, id, os.time())") and has(svc, "cashWindowShut(player)")
		and has(svc, "GC.buyGapSeconds") and has(svc, "Profile.syncBestLeague(data)"), "BuyCash: rate limit, race window, tier sync, then Style.buyCash")
	check(not has(svc, "PromptProductPurchase(player, id") and not has(svc, "cash +=") , "Green Cash is never sold or swapped for Diamonds")
end
