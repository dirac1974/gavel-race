--!strict
-- Stage 5 of docs/plans/horse-life-and-retention.md (D-060, D-042): visiting friends' barns.
-- Only friends are listed, pats give a Tour stamp and no bond, one treat a day, visitor bond
-- capped per horse per day, nothing else on another plot, and a closed gate walks visitors out.
local fs = require("@lune/fs")
local Visits = require("../../game/src/shared/Visits")
local Profile = require("../../game/src/shared/Profile")
local Horse = require("../../game/src/shared/Horse")
local GameConfig = require("../../game/src/shared/GameConfig")
local WorldLayout = require("../../game/src/shared/WorldLayout")

local CFG = GameConfig.visit
local NOW = 1_800_000_000 -- a fixed day
local DAY = 86400

local function owner(n: number)
	local p = Profile.new(NOW)
	for k = 1, n do
		local h = Horse.new("h" .. k, "Horse" .. k, "bay", { speed = 50, accel = 50, stamina = 50, grit = 50 },
			{ speed = 80, accel = 80, stamina = 80, grit = 80 }, NOW)
		Profile.addHorse(p, h)
	end
	return p
end

local function ids(p: any): { string }
	local out = {}
	for k = 1, p.stalls do -- stalls stored per horse (D-059)
		local h = Profile.stallHorse(p, k)
		if h then table.insert(out, h.id) end
	end
	return out
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	check(CFG ~= nil and CFG.bondPerHorsePerDay == 1, "GameConfig.visit.bondPerHorsePerDay = 1 (D-060)")

	-- Who is listed -------------------------------------------------------------------
	do
		local friends = { [2] = true, [3] = true, [5] = true, [6] = true }
		local function isFriend(a: number, b: number): boolean
			return a == 1 and friends[b] == true
		end
		local owners = {
			{ userId = 1, name = "Me", visits = "Friends", hasBarn = true },               -- yourself
			{ userId = 2, name = "Zed", visits = "Friends", hasBarn = true },              -- friend
			{ userId = 3, name = "Amy", visits = "Club", hasBarn = true },                 -- Club counts as Friends
			{ userId = 4, name = "Stranger", visits = "Friends", hasBarn = true },         -- not a friend
			{ userId = 5, name = "Priv", visits = "Nobody", hasBarn = true },              -- friend, Nobody
			{ userId = 6, name = "Bo", visits = "Friends", gateClosed = true, hasBarn = true }, -- friend, gate closed
			{ userId = 7, name = "Stranger2", visits = "Friends", gateClosed = true, hasBarn = true },
		}
		local list = Visits.list(1, owners, isFriend, CFG)
		local seen = {}
		for _, f in list do seen[f.userId] = f end
		check(seen[4] == nil and seen[7] == nil, "a non-friend is never listed")
		check(seen[1] == nil, "you aren't on your own list")
		check(seen[5] == nil, "a friend with visits set to Nobody isn't listed")
		check(seen[2] ~= nil and not seen[2].closed and seen[3] ~= nil, "friends who let you in are listed (Club = Friends)")
		check(seen[6] ~= nil and seen[6].closed == true, "a friend's closed gate shows as closed")
		check(#list == 3 and list[1].name == "Amy" and list[2].name == "Bo", "the list is sorted by name")
		-- With nobody a friend, the list is empty (the parent check: two non-friend accounts).
		check(#Visits.list(1, owners, function() return false end, CFG) == 0, "no friends, empty list")
		local many = {}
		for k = 1, 40 do table.insert(many, { userId = 100 + k, name = "F" .. k, visits = "Friends", hasBarn = true }) end
		check(#Visits.list(1, many, function() return true end, CFG) == CFG.listMax, "the list holds at most listMax faces")
		check(#Visits.list(1, { { userId = 2, name = "Zed", visits = "Friends", hasBarn = false } }, isFriend, CFG) == 0,
			"a friend with no barn yet isn't listed")
		local off = table.clone(CFG)
		off.enabled = false
		check(#Visits.list(1, owners, isFriend, off) == 0, "visits switched off: empty list")
		local walk = table.clone(CFG)
		walk.mapList = false
		check(#Visits.list(1, owners, isFriend, walk) == 0, "mapList off: no list (walk Barn Lane only)")
		local ok, why = Visits.canVisit({ friends = false, visits = "Friends" })
		check(not ok and why == "friends", "canVisit refuses a non-friend")
		ok, why = Visits.canVisit({ friends = true, visits = "Friends", same = true })
		check(not ok and why == "self", "canVisit refuses yourself")
	end

	-- Pats: a Tour stamp, never bond ----------------------------------------------------
	do
		local o = owner(3)
		local v = Profile.new(NOW)
		local barn = ids(o)
		check(#barn == 2, "two stalls: two horses in the barn")
		local before = o.horses[1].bond
		local ok, res = Visits.pat(v, 42, barn[1], barn, NOW)
		check(ok and res.left == 1 and not res.stamp, "first pat: one more horse to go")
		check(o.horses[1].bond == before, "a visitor's pat gives no bond")
		ok, res = Visits.pat(v, 42, barn[1], barn, NOW)
		check(ok and res.left == 1 and not res.stamp, "patting the same horse again doesn't count twice")
		ok, res = Visits.pat(v, 42, barn[2], barn, NOW)
		check(ok and res.left == 0 and res.stamp == true, "patting every horse earns the Tour stamp")
		check(Profile.tourStampCount(v) == 1, "one Tour stamp")
		for _, h in o.horses do check(h.bond == 0, "no bond on any horse from pats") end
		ok, res = Visits.pat(v, 42, barn[1], barn, NOW + DAY)
		ok, res = Visits.pat(v, 42, barn[2], barn, NOW + DAY)
		check(ok and not res.stamp and res.already == true and Profile.tourStampCount(v) == 1, "each friend's stamp counts once")
		ok = Visits.pat(v, 42, "h3", barn, NOW)
		check(not ok, "a pasture horse isn't in the barn to pat")
		ok = Visits.pat(v, 42, "nope", barn, NOW)
		check(not ok, "a made-up horse can't be patted")
		Visits.pat(v, 43, "a1", { "a1" }, NOW)
		check(Profile.tourStampCount(v) == 2, "a second friend's barn gives a second stamp")
	end

	-- Treats: one a day per friend, bond inside the cap ----------------------------------
	do
		local o = owner(1)
		local v = Profile.new(NOW)
		local h = o.horses[1]
		local carrots = Profile.itemCount(v, "carrot")
		local ok, res = Visits.treat(v, 42, h, NOW, CFG)
		check(ok and res.bond == 1 and h.bond == 1, "a visitor's treat gives 1 bond")
		check(Profile.itemCount(v, "carrot") == carrots, "the visit treat is free (nothing leaves the bag)")
		ok, res = Visits.treat(v, 42, h, NOW + 60, CFG)
		check(not ok and res.reason == "used", "a second treat the same day is refused")
		ok = Visits.treat(v, 42, h, NOW + 3600, CFG)
		check(not ok, "still refused later that day")
		ok = Visits.treat(v, 42, h, NOW + DAY, CFG)
		check(ok and h.bond == 2, "a new day, a new treat")
	end

	-- Bond from visitors: at most 1 per horse per day, however many visit -----------------
	do
		local o = owner(1)
		local h = o.horses[1]
		local total = 0
		for k = 1, 3 do
			local v = Profile.new(NOW)
			local ok, res = Visits.treat(v, 42, h, NOW + k, CFG)
			check(ok, `visitor {k}'s treat is accepted`)
			total += res.bond
		end
		check(total == 1 and h.bond == 1, "three visitors: bond from visitors ≤ 1 per horse per day")
		local v = Profile.new(NOW)
		Visits.treat(v, 42, h, NOW + DAY, CFG)
		check(h.bond == 2, "the cap opens again the next day")
		h.bond = 100
		local v2 = Profile.new(NOW)
		Visits.treat(v2, 42, h, NOW + 2 * DAY, CFG)
		check(h.bond == 100, "bond never goes over 100")
	end

	-- Post box: one of your carrots, an anonymous count ---------------------------------
	do
		local o = owner(1)
		local v = Profile.new(NOW)
		local mine, theirs = Profile.itemCount(v, "carrot"), Profile.itemCount(o, "carrot")
		local ok, res = Visits.post(v, o, 42, NOW, CFG)
		check(ok and res.today == 1, "a carrot dropped: the owner's count is 1 today")
		check(Profile.itemCount(v, "carrot") == mine - 1 and Profile.itemCount(o, "carrot") == theirs + 1, "the carrot moves to the owner")
		ok, res = Visits.post(v, o, 42, NOW + 5, CFG)
		check(not ok and res.reason == "used", "one carrot a day per friend")
		local empty = Profile.new(NOW)
		empty.items.carrot = nil
		ok, res = Visits.post(empty, o, 42, NOW, CFG)
		check(not ok and res.reason == "none", "no carrot, no drop")
		for _ = 2, CFG.postBoxPerDay do
			local w = Profile.new(NOW)
			check((Visits.post(w, o, 42, NOW, CFG)), "other friends' carrots arrive")
		end
		local late = Profile.new(NOW)
		ok, res = Visits.post(late, o, 42, NOW, CFG)
		check(not ok and res.reason == "full" and Profile.itemCount(late, "carrot") == 3, "a full post box keeps your carrot")
		local view = Profile.view(o, NOW, GameConfig.energy)
		check(view.postBox.today == CFG.postBoxPerDay and view.postBox.total == CFG.postBoxPerDay, "the owner's view has the count")
		check(Profile.view(o, NOW + DAY, GameConfig.energy).postBox.today == 0, "the count starts again the next day")
		ok = Visits.post(Profile.new(NOW), o, 42, NOW + DAY, CFG)
		check(ok and o.postBox.today == 1 and o.postBox.total == CFG.postBoxPerDay + 1, "a new day empties today's box, keeps the total")
	end

	-- Nothing else on another plot ------------------------------------------------------
	do
		for _, a in { "pat", "treat", "post" } do check(Visits.visitorMay(a), `visitors may {a}`) end
		for _, a in { "feed", "groom", "pet", "plant", "harvest", "chore", "buy", "sell", "sellAll", "ride", "retire", 1, nil } do
			check(not Visits.visitorMay(a), `visitors may not {tostring(a)}`)
		end
		local care = fs.readFile("game/src/server/CareService.server.luau")
		-- CareAction, Garden and Chore still use the player's own profile and own plot.
		local function after(marker: string): string
			local i = string.find(care, marker, 1, true)
			return if i then string.sub(care, i, i + 700) else ""
		end
		check(string.find(after("CareAction.OnServerEvent"), "Profile.horse(data, horseId)", 1, true) ~= nil
			and string.find(after("CareAction.OnServerEvent"), "atOwnPlot(player)", 1, true) ~= nil, "CareAction: own horse at own barn")
		check(string.find(after("Garden.OnServerEvent"), "atOwnPlot(player)", 1, true) ~= nil, "Garden: own plot only")
		check(string.find(after("Chore.OnServerEvent"), "atOwnPlot(player)", 1, true) ~= nil, "Chore: own plot only")
		local visit = after("VisitCare.OnServerEvent")
		check(string.find(visit, "Visits.visitorMay(action)", 1, true) ~= nil and string.find(visit, "VisitAccess.check", 1, true) ~= nil
			and string.find(visit, "VisitAccess.near", 1, true) ~= nil, "VisitCare checks the action, the friendship and the place")
	end

	-- The gate --------------------------------------------------------------------------
	do
		local ok, why = Visits.canVisit({ friends = true, visits = "Friends", gateClosed = true })
		check(not ok and why == "closed", "a closed gate lets nobody in")
		ok = Visits.canVisit({ friends = true, visits = "Friends", gateClosed = false })
		check(ok, "an open gate lets friends in")
		for i = 1, WorldLayout.PLOT_COUNT do
			local r = WorldLayout.plotRect(i)
			local x, z, lx, lz = WorldLayout.gateArrival(i)
			check(not Visits.inside(r, x, z), `plot {i}: the gate arrival is outside the plot`)
			check(Visits.inside(r, lx, lz), `plot {i}: arriving visitors face into the plot`)
			check(math.abs(x - WorldLayout.LANE_X) < WorldLayout.LANE_WIDTH / 2, `plot {i}: the gate arrival is on Barn Lane`)
			for j = 1, WorldLayout.PLOT_COUNT do
				if j ~= i then check(not Visits.inside(WorldLayout.plotRect(j), x, z), `plot {i}: the arrival isn't in plot {j}`) end
			end
		end
		local r = WorldLayout.plotRect(3)
		local ix, iz = WorldLayout.plotPoint(3, 40, 5)
		local gx, gz = WorldLayout.plotPoint(3, 2, 0)
		local lx, lz = WorldLayout.gateArrival(3)
		local out = Visits.toWalkOut(r, 10, {
			{ userId = 10, x = ix, z = iz },   -- the owner stays
			{ userId = 11, x = ix, z = iz },   -- a visitor in the yard
			{ userId = 12, x = gx, z = gz },   -- a visitor just inside the gate
			{ userId = 13, x = lx, z = lz },   -- someone on the lane
		})
		table.sort(out)
		check(#out == 2 and out[1] == 11 and out[2] == 12, "closing the gate moves the visitors inside out, not the owner or the lane")
		local stable = fs.readFile("game/src/server/StableService.server.luau")
		check(string.find(stable, "Visits.toWalkOut(rect, owner.UserId, people)", 1, true) ~= nil
			and string.find(stable, "WorldLayout.gateArrival(i)", 1, true) ~= nil, "the sweep walks visitors out to the gate")
		check(string.find(stable, "VisitAccess.setGate(player, not VisitAccess.gateClosed(player))", 1, true) ~= nil,
			"the gate button toggles the owner's own gate")
		local client = fs.readFile("game/src/client/WorldClient.client.luau")
		check(string.find(client, 'plot:GetAttribute("GateClosed")', 1, true) ~= nil, "a closed gate turns the walls solid")
	end

	-- Saved data ------------------------------------------------------------------------
	do
		local p = Profile.new(NOW)
		Visits.pat(p, 42, "a", { "a" }, NOW)
		Visits.treat(p, 42, owner(1).horses[1], NOW, CFG)
		local saved = Profile.migrate(p, NOW + 10)
		check(Profile.tourStampCount(saved) == 1 and saved.tour.treats["42"] == 1, "a save keeps stamps and today's treats")
		local next = Profile.migrate(saved, NOW + DAY)
		check(Profile.tourStampCount(next) == 1 and next.tour.treats["42"] == nil, "a new day keeps stamps, clears treats")
		local junk = Profile.migrate({ tour = { stamps = { ["42"] = 1, bad = 1, [7] = 1, ["9"] = "x" }, day = "?", treats = 5 },
			postBox = { today = -3, total = "x" } }, NOW)
		check(Profile.tourStampCount(junk) == 1 and junk.postBox.today == 0 and junk.postBox.total == 0, "junk is repaired")
		local old = Profile.migrate({ cash = 10 }, NOW)
		check(Profile.tourStampCount(old) == 0 and old.postBox.total == 0, "an old save gets an empty Tour and post box")
		check(Profile.view(p, NOW, GameConfig.energy).tourStamps == 1, "the owner's view has the stamp count")
	end
end
