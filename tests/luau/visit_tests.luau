--!strict
-- Stage 5 of docs/plans/horse-life-and-retention.md (D-060, D-042): visiting friends' barns.
-- Only friends are listed, pats give a Tour stamp and no bond, one treat a day, visitor bond
-- capped per horse per day, nothing else on another plot, and a closed gate walks visitors out.
-- D-079: the permission matrix (owner setting × friend or not × action), barns open to everyone,
-- the 4-stop walkaround and its Tour pin, cheers, the one-time ask, and the server checks.
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

	-- Pats: never bond, and (D-079, code review N3) never a Tour pin: the pin is the walkaround's ---
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
		check(ok and res.left == 0 and res.stamp == false, "patting every horse no longer earns a pin (D-079)")
		check(Profile.tourStampCount(v) == 0, "no pin from pats")
		for _, h in o.horses do check(h.bond == 0, "no bond on any horse from pats") end
		ok, res = Visits.pat(v, 42, barn[1], barn, NOW + DAY)
		ok, res = Visits.pat(v, 42, barn[2], barn, NOW + DAY)
		check(ok and not res.stamp and res.already == false and Profile.tourStampCount(v) == 0, "still no pin from pats")
		ok = Visits.pat(v, 42, "h3", barn, NOW)
		check(not ok, "a pasture horse isn't in the barn to pat")
		ok = Visits.pat(v, 42, "nope", barn, NOW)
		check(not ok, "a made-up horse can't be patted")
		Visits.pat(v, 43, "a1", { "a1" }, NOW)
		check(Profile.tourStampCount(v) == 0, "a second barn's pats: no pin either")
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
		for _, id in Visits.stopsFor(false) do Visits.stop(p, 42, id, NOW, false) end
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

	-- D-079: visiting other stables ------------------------------------------------------------
	-- The permission matrix: owner setting × friend or not × action, then the gate and PolicyService.
	do
		local ACTIONS = { "enter", "look", "pat", "cheer", "treat", "post" }
		local STRANGER = { enter = true, look = true, pat = true, cheer = true, treat = false, post = false }
		local expect = {
			-- setting -> { friend = allowed?, stranger = allowed? } per action
			Friends = { friend = function(_a) return true end, stranger = function(_a) return false end },
			Everyone = { friend = function(_a) return true end, stranger = function(a) return STRANGER[a] end },
			Nobody = { friend = function(_a) return false end, stranger = function(_a) return false end },
		}
		local cells = 0
		for setting, row in expect do
			for _, friend in { true, false } do
				for _, a in ACTIONS do
					local want = if friend then row.friend(a) else row.stranger(a)
					local ok = Visits.canVisit({ friends = friend, visits = setting, action = a })
					check(ok == want, `matrix: {setting} × {if friend then "friend" else "stranger"} × {a} = {tostring(want)}`)
					check(Visits.may(setting, friend, a) == want, `Visits.may agrees: {setting} × {tostring(friend)} × {a}`)
					-- the owner's one-tap gate shuts everyone out of everything, in every setting
					check(not Visits.canVisit({ friends = friend, visits = setting, action = a, gateClosed = true }),
						`a closed gate blocks {setting} × {tostring(friend)} × {a}`)
					cells += 1
				end
			end
		end
		check(cells == 36, "the matrix covers 3 settings × 2 × 6 actions")
		-- Old saves and unknown values read as Friends.
		for _, v in { "Club", nil, "junk", 7, "everyone", "" } do
			check(Visits.setting(v) == "Friends", `"{tostring(v)}" reads as Friends`)
			check(not Visits.canVisit({ friends = false, visits = v, action = "pat" }), `a stranger can't pat at "{tostring(v)}"`)
			check(Visits.canVisit({ friends = true, visits = v, action = "treat" }), `a friend can treat at "{tostring(v)}"`)
		end
		check(Visits.setting("Everyone") == "Everyone" and Visits.setting("Nobody") == "Nobody", "Everyone and Nobody read as themselves")
		-- No action named = the friends-only check (CareService's VisitCare, written before D-079).
		check(not Visits.canVisit({ friends = false, visits = "Everyone" }), "no action: a stranger is refused even at Everyone")
		check(Visits.canVisit({ friends = true, visits = "Everyone" }), "no action: a friend is let in")
		-- Anything not on the list is refused for everyone.
		for _, a in { "feed", "groom", "take", "move", "write", "buy", "sell", "ride", 1, true } do
			check(not Visits.canVisit({ friends = true, visits = "Everyone", action = a :: any }), `nobody may {tostring(a)}`)
			check(not Visits.may("Everyone", false, a) and not Visits.may("Everyone", true, a), `may: nobody may {tostring(a)}`)
		end
		-- PolicyService unread (fail closed): strangers out, friends unaffected.
		check(not Visits.canVisit({ friends = false, visits = "Everyone", action = "pat", strangersOk = false }), "policy unread: no stranger pat")
		check(Visits.canVisit({ friends = true, visits = "Everyone", action = "treat", strangersOk = false }), "policy unread: friends still visit")
		-- GameConfig.visit.everyone off: Everyone reads as Friends.
		check(not Visits.canVisit({ friends = false, visits = "Everyone", action = "enter", everyone = false }), "everyone off: strangers out")
		local _, why = Visits.canVisit({ friends = false, visits = "Everyone", action = "treat" })
		check(why == "friends", "a stranger's treat is refused as friends-only")
		_, why = Visits.canVisit({ friends = true, visits = "Nobody", action = "enter" })
		check(why == "private", "Nobody blocks a friend's entry")
		check(CFG.everyone == true and CFG.askOnce == true, "Everyone here and the one-time ask are on (D-079)")
	end

	-- The barns list: friends plus every barn open to everyone, friends labelled ------------
	do
		local friends = { [2] = true, [6] = true }
		local function isFriend(a: number, b: number): boolean return a == 1 and friends[b] == true end
		local owners = {
			{ userId = 2, name = "Zed", visits = "Friends", hasBarn = true },                  -- friend
			{ userId = 3, name = "Amy", visits = "Everyone", hasBarn = true },                 -- stranger, open
			{ userId = 4, name = "Cal", visits = "Friends", hasBarn = true },                  -- stranger, friends only
			{ userId = 5, name = "Dee", visits = "Nobody", hasBarn = true },                   -- stranger, Nobody
			{ userId = 6, name = "Bo", visits = "Nobody", hasBarn = true },                    -- friend, Nobody
			{ userId = 7, name = "Eve", visits = "Everyone", gateClosed = true, hasBarn = true }, -- stranger, gate closed
			{ userId = 8, name = "Fin", visits = "Everyone", hasBarn = true, policyOk = false }, -- stranger, policy unread
			{ userId = 9, name = "Abe", visits = "Everyone", hasBarn = false },                -- no barn yet
		}
		local list = Visits.list(1, owners, isFriend, CFG)
		local seen = {}
		for _, f in list do seen[f.userId] = f end
		check(seen[2] ~= nil and seen[2].friend == true, "a friend's barn is listed and marked a friend")
		check(seen[3] ~= nil and seen[3].friend == false and not seen[3].closed, "a stranger's Everyone barn is listed, not a friend")
		check(seen[4] == nil and seen[5] == nil and seen[6] == nil, "Friends-only and Nobody barns of others aren't listed")
		check(seen[7] == nil, "a stranger's closed gate isn't listed")
		check(seen[8] == nil and seen[9] == nil, "no policy answer or no barn: not listed")
		check(#list == 2 and list[1].userId == 2 and list[2].userId == 3, "friends first, then open barns")
		check(#Visits.list(1, owners, isFriend, CFG, false) == 1, "the viewer's policy unread: friends only")
		for _, f in list do
			local n = 0
			for _ in f do n += 1 end
			check(n == 5 and f.count == nil and f.likes == nil and f.rank == nil, "a row is id, name, closed, fresh, friend: no counts or likes")
		end
		local off = table.clone(CFG)
		off.everyone = false
		check(#Visits.list(1, owners, isFriend, off) == 1, "everyone off: only friends")
	end

	-- The 4-stop walkaround: a Tour pin once per barn ---------------------------------------
	do
		local v = Profile.new(NOW)
		check(#Visits.STOPS == 4 and #CFG.tourStops == 5, "4 tour stops (the 4th: paddock or garden)")
		for k, s in CFG.tourStops do check(s.id == Visits.ALL_STOPS[k], `stop {k} is {Visits.ALL_STOPS[k]}`) end
		check(table.concat(Visits.stopsFor(true), ",") == "wall,horses,decor,paddock", "with a Legend: the Legend paddock")
		check(table.concat(Visits.stopsFor(false), ",") == "wall,horses,decor,garden", "no Legend: their garden instead")
		check(Visits.STOP_NAMES.decor == "Their yard" and Visits.STOP_NAMES.garden == "Their garden", "stop names for a visitor")
		check(not (Visits.stop(v, 42, "paddock", NOW, false)), "no Legend: the paddock isn't a stop")
		check(not (Visits.stop(v, 42, "garden", NOW, true)), "with a Legend: the garden isn't a stop")
		local g = Profile.new(NOW)
		for _, id in Visits.stopsFor(false) do Visits.stop(g, 77, id, NOW, false) end
		check(Profile.tourStampCount(g) == 1, "no Legend: the garden route earns the pin")
		local ok, res = Visits.stop(v, 42, "wall", NOW, true)
		check(ok and res.done == 1 and res.left == 3 and not res.pin and res.fresh, "first stop: 3 to go")
		ok, res = Visits.stop(v, 42, "wall", NOW + 1, true)
		check(ok and res.done == 1 and not res.fresh, "the same stop twice counts once")
		check(not (Visits.stop(v, 42, "kitchen", NOW)) and not (Visits.stop(v, 42, nil, NOW)), "a made-up stop is refused")
		Visits.stop(v, 42, "horses", NOW, true)
		Visits.stop(v, 42, "decor", NOW, true)
		check(table.concat(Visits.stopsToday(v, 42, NOW, true), ",") == "wall,horses,decor", "today's stops in tour order")
		ok, res = Visits.stop(v, 42, "paddock", NOW, true)
		check(ok and res.done == 4 and res.pin == true, "all 4 stops: the Tour pin")
		check(Profile.tourStampCount(v) == 1, "one pin (a D-060 Tour stamp)")
		for _, id in Visits.STOPS do Visits.stop(v, 42, id, NOW + DAY, true) end
		check(Profile.tourStampCount(v) == 1 and #Visits.stopsToday(v, 42, NOW + DAY, true) == 4, "the next day: stops again, no second pin")
		check(#Visits.stopsToday(v, 42, NOW + 2 * DAY, true) == 0, "stops start fresh each day")
		for _, id in Visits.STOPS do Visits.stop(v, 43, id, NOW, true) end
		check(Profile.tourStampCount(v) == 2, "a second barn, a second pin")
		local w = Profile.new(NOW)
		Visits.stop(w, 42, "wall", NOW, false)
		Visits.stop(w, 42, "garden", NOW, false)
		local saved = Profile.migrate(w, NOW + 10)
		check(table.concat(Visits.stopsToday(saved, 42, NOW + 10, false), ",") == "wall,garden", "a save keeps today's stops")
		local busy = Profile.new(NOW)
		for k = 1, Profile.MAX_TOUR_FRIENDS do Visits.stop(busy, 1000 + k, "wall", NOW, false) end
		local okFull, resFull = Visits.stop(busy, 9999, "wall", NOW, false)
		check(not okFull and resFull.reason == "full", "too many barns today: refused, so the client backs off (N2)")
		local junk = Profile.migrate({ tour = { day = NOW // DAY, stops = { ["42"] = { wall = true, bogus = true, horses = "x" }, bad = {} } } }, NOW)
		check(table.concat(Visits.stopsToday(junk, 42, NOW), ",") == "wall", "junk stops are repaired")
		-- Every stop stands inside every plot, and the client's arrive radius is inside the server's.
		for i = 1, WorldLayout.PLOT_COUNT do
			local r = WorldLayout.plotRect(i)
			for _, s in CFG.tourStops do
				local x, z = WorldLayout.plotPoint(i, s.inward, s.across)
				check(Visits.inside(r, x, z), `plot {i}: stop {s.id} is inside the plot`)
				local lx, lz = WorldLayout.plotPoint(i, s.lookIn, s.lookAcross)
				check(Visits.inside(r, lx, lz), `plot {i}: stop {s.id}'s featured spot is inside the plot`)
			end
		end
		check(CFG.stopArriveStuds < CFG.stopStuds, "the client sends a stop well inside the server's radius")
	end

	-- Cheers: 4 presets, a few a day per barn, no names ---------------------------------------
	do
		local v = Profile.new(NOW)
		check(#Visits.CHEERS == 4, "4 preset cheers")
		for _, k in Visits.CHEERS do check(Visits.CHEER_ICONS[k] ~= nil, `cheer {k} has an icon`) end
		local ok, res = Visits.cheer(v, 42, "clap", NOW, CFG)
		check(ok and res.icon == "👏" and res.name == nil, "a cheer carries an icon, never a name")
		check(not (Visits.cheer(v, 42, "hello there", NOW, CFG)) and not (Visits.cheer(v, 42, nil, NOW, CFG)), "no free text cheers")
		for _ = 2, CFG.cheersPerBarnPerDay do check((Visits.cheer(v, 42, "yay", NOW, CFG)), "more cheers up to the cap") end
		ok, res = Visits.cheer(v, 42, "love", NOW, CFG)
		check(not ok and res.reason == "used", "the daily cheer cap per barn")
		check((Visits.cheer(v, 43, "love", NOW, CFG)), "another barn can still be cheered")
		check((Visits.cheer(v, 42, "love", NOW + DAY, CFG)), "a new day, new cheers")
	end

	-- Settings: three choices, old values kept, the one-time ask ------------------------------
	do
		local club = Profile.migrate({ settings = { visits = "Club" } }, NOW)
		check(club.settings.visits == "Club" and Visits.setting(club.settings.visits) == "Friends", "an old Club save stays and reads as Friends")
		check(Profile.migrate({ settings = { visits = "Everyone" } }, NOW).settings.visits == "Everyone", "Everyone is saved")
		check(Profile.migrate({ settings = { visits = "Public" } }, NOW).settings.visits == "Friends", "an unknown value becomes Friends")
		check(Profile.new(NOW).settings.visits == "Friends", "new players start on Friends")
		local asked = Profile.migrate({ settings = { visits = "Friends", visitAsked = true } }, NOW)
		check(asked.settings.visitAsked == true and Profile.migrate({}, NOW).settings.visitAsked == nil, "visitAsked is kept, else unset")
		check(Profile.view(asked, NOW, GameConfig.energy).settings.visitAsked == true, "the client sees that it was asked")
		local ss = fs.readFile("game/src/server/SettingsService.server.luau")
		check(string.find(ss, "Friends = true, Everyone = true, Nobody = true", 1, true) ~= nil, "SettingsService takes the three values")
		check(string.find(ss, 'key == "visitAsk"', 1, true) ~= nil and string.find(ss, 'if data.settings.visits ~= "Nobody" then', 1, true) ~= nil
			and string.find(ss, "if data.settings.visitAsked then return end", 1, true) ~= nil, "the ask is once, and never overrides Nobody")
	end

	-- Ask to leave, the client's view, PolicyService, feel numbers (phase 5 review fixes) -------------
	do
		local _, why = Visits.canVisit({ friends = true, visits = "Everyone", action = "enter", askedOut = true })
		check(why == "asked", "asked to leave: refused (friends too), walked out by the sweep")
		check(not Visits.canVisit({ friends = false, visits = "Everyone", action = "pat", askedOut = true }), "asked to leave: no pat")
		local function seen(over: { [string]: any }): any
			local v = { visits = "Everyone", gateClosed = false, friend = false, strangersOk = true, askedOutOf = nil, askedOutUntil = nil,
				ownerId = 5, serverNow = 100 }
			for k, x in over do v[k] = x end
			return v
		end
		check(Visits.clientMay(seen({}), "enter") and Visits.clientMay(seen({}), "pat"), "client: a stranger may enter and pat at Everyone")
		check(not Visits.clientMay(seen({}), "treat"), "client: no Treat prompt for a stranger")
		check(not Visits.clientMay(seen({ strangersOk = false }), "enter") and not Visits.clientMay(seen({ strangersOk = "unread" }), "enter"),
			"client: no PolicyService yes, solid walls (no bounce loop, S2)")
		check(Visits.clientMay(seen({ strangersOk = false, friend = true, visits = "Friends" }), "treat"), "client: friends don't need it")
		check(not Visits.clientMay(seen({ askedOutOf = 5, askedOutUntil = 150 }), "enter"), "client: asked out, walls solid")
		check(Visits.clientMay(seen({ askedOutOf = 5, askedOutUntil = 90 }), "enter") and Visits.clientMay(seen({ askedOutOf = 6, askedOutUntil = 150 }), "enter"),
			"client: the ask runs out, and is for that barn only")
		check(not Visits.clientMay(seen({ gateClosed = true, friend = true }), "enter") and not Visits.clientMay(seen({ visits = "Nobody", friend = true }), "enter"),
			"client: gate and Nobody")
		check(CFG.askLeaveSeconds > 0 and CFG.policyRetrySeconds > 0 and CFG.arriveRepeatSeconds > 0, "the new timings are in GameConfig")
		check(CFG.stopFx.sparkles == 12 and CFG.stopFx.highlightSeconds == 1.2 and CFG.stopFx.color == "FFD23F", "stop sparkle and outline (feel)")
		check(CFG.cheerFx.px == 64 and CFG.cheerFx.riseStuds == 3 and CFG.cheerFx.seconds == 1.2 and CFG.cheerFx.volume == 0.4
			and CFG.cheerFx.yaySpeed == 1.2, "cheer float (feel)")
		local access = fs.readFile("game/src/server/VisitAccess.luau")
		local function has(src: string, x: string): boolean return string.find(src, x, 1, true) ~= nil end
		check(has(access, "info.IsContentSharingAllowed == true and info.IsSubjectToChinaPolicies == false")
			and has(access, "https://create.roblox.com/docs/reference/engine/classes/PolicyService"), "the PolicyService rule reads real fields, documented")
		check(has(access, 'player:SetAttribute("VisitStrangersOk"') and has(access, "policyRetrySeconds"), "published, one retry")
		check(has(access, 'if s == "Everyone" and not VisitAccess.policyOk(owner) then return "Friends" end'), "the shell shows Friends when the owner can't host strangers")
		local stable = fs.readFile("game/src/server/StableService.server.luau")
		check(has(stable, "AskToLeave.OnServerEvent") and has(stable, "if not i then return end") and has(stable, "Visits.inside(WorldLayout.plotRect(i), pos.X, pos.Z)")
			and has(stable, 'Profiles.notify(visitor, "Time to head home!"'), "Ask to leave: owner only, visitor in the yard, kind words")
		check(has(stable, 'why == "asked"'), "the sweep walks out an asked visitor")
		local Words = require("../../game/src/shared/Words")
		check(Words.toastOk("Time to head home!"), "the ask-to-leave line passes the copy rules")
		local vt = fs.readFile("game/src/client/VisitTour.client.luau")
		check(has(vt, 'Instance.new("Highlight")') and has(vt, "e:Emit(FX.sparkles)") and has(vt, 'Sound.play("clap", CH.volume)')
			and has(vt, 'Sound.play("tap_good", CH.volume, nil, CH.yaySpeed)') and has(vt, "info.quiet ~= true"), "feel: outline, sparkle, cheer sounds, quiet re-arrival")
		local wc = fs.readFile("game/src/client/WorldClient.client.luau")
		check(has(wc, '"Not now"') and has(wc, '"Who can come to your barn?"') and not has(wc, "faces.Visible = not ask.Visible"),
			"the ask has Not now and never hides the list")
	end

	-- The server checks every visit remote (source checks) ------------------------------------
	do
		local vs = fs.readFile("game/src/server/VisitService.server.luau")
		local function has(src: string, s: string): boolean return string.find(src, s, 1, true) ~= nil end
		check(has(vs, "VisitAccess.check(player, owner, ACTION[kind])") and has(vs, "VisitAccess.near(player, owner)")
			and has(vs, "CFG.helloGapSeconds") and has(vs, 'GetAttribute("Racing")'), "VisitHello: matrix, place, gap, not racing")
		check(has(vs, "> CFG.stopStuds then return end"), "a tour stop needs you to stand there")
		check(has(vs, 'Profiles.notify(owner, "A visitor cheered! " .. res.icon'), "the owner's cheer toast has no name")
		check(has(vs, "CFG.ownerCheerGapSeconds"), "the owner's cheer toasts are spaced out")
		check(not has(vs, "TextBox") and not has(vs, "FilterStringAsync"), "no text anywhere in visiting")
		local stable = fs.readFile("game/src/server/StableService.server.luau")
		check(has(stable, 'VisitAccess.check(player, owner, "enter")') and has(stable, 'VisitAccess.check(player, owner, "post")')
			and has(stable, 'VisitAccess.check(visitor, owner, "enter")'), "StableService names each action: travel, post box, sweep")
		check(has(stable, "local x, z, lx, lz = WorldLayout.gateArrival(i)\n\tarriveAt(player, x, z, lx, lz)")
			or has(stable, "local x, z, lx, lz = WorldLayout.gateArrival(i)\r\n\tarriveAt(player, x, z, lx, lz)"), "the Map trip lands at the gate, outside")
		check(has(stable, "VisitAccess.policyOk(player)"), "the list asks PolicyService for strangers")
		local care = fs.readFile("game/src/server/CareService.server.luau")
		check(has(care, "VisitAccess.check(player, owner)\n") or has(care, "VisitAccess.check(player, owner)\r\n"),
			"VisitCare (treats) keeps the friends-only check")
		local access = fs.readFile("game/src/server/VisitAccess.luau")
		check(has(access, "GetPolicyInfoForPlayerAsync") and has(access, "strangersOk = VisitAccess.policyOk(visitor) and VisitAccess.policyOk(owner)"),
			"strangers need PolicyService read for both players")
		local vc = fs.readFile("game/src/client/VisitClient.client.luau")
		check(has(vc, "letIn(plot, pr[3])") and has(vc, '{ treat, d, "treat" }') and has(vc, '{ post, nil, "post" }'),
			"the Treat and post box prompts follow the matrix (friends only)")
		local wc = fs.readFile("game/src/client/WorldClient.client.luau")
		check(has(wc, "if f.friend == true then") and has(wc, '"👫 Friend ▶"'), "the barns list labels friends; strangers show a barn, not a face")
		check(has(wc, '"Let other riders visit?"') and has(wc, '"visitAsk"'), "the one-time ask")
		local vt = fs.readFile("game/src/client/VisitTour.client.luau")
		check(has(vt, '"Welcome to " .. name .. "\'s barn!"') and has(vt, 'Sound.play("gate_bell"') and has(vt, 'Sound.play("job_done")')
			and has(vt, 'Sound.play("tap_ok")'), "the banner and existing SoundSheet clips")
		local Words = require("../../game/src/shared/Words")
		for _, line in { "Welcome to Mia's barn!", "Let other riders visit?", "Look! Rosette Wall", "No open barns yet",
			"Cheer sent! 👏", "A visitor cheered! 👏" } do
			local n = 0
			for _ in string.gmatch(line, "%S+") do n += 1 end
			check(n <= 6 and Words.toastOk(line), `"{line}" is 6 words or fewer`)
		end
		for _, id in Visits.STOPS do
			local n = 0
			for _ in string.gmatch("Look! " .. Visits.STOP_NAMES[id], "%S+") do n += 1 end
			check(n <= 6, `the {id} stop's line is short`)
		end
		local run = fs.readFile("tests/luau/run_all.luau")
		check(has(run, 'require("./visit_tests")'), "visit tests are registered")
	end
end
