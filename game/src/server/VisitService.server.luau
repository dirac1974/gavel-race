--!nonstrict
-- VisitService (D-079): visiting other stables, the parts anyone let in may do.
--   VisitHello (client -> server: ownerUserId, kind, arg): "pat" a horse in the barn (arg = horse id;
--   no bond, a nuzzle), "cheer" (arg = one of Visits.CHEERS; the owner gets an anonymous toast) or
--   "stop" (arg = a tour stop id; the server checks you stand there). Every call is checked again:
--   the permission matrix through VisitAccess.check (friends, or anyone at an Everyone here barn;
--   Nobody and a closed gate block all), standing at the barn, not racing, and a gap per visitor
--   (visit.helloGapSeconds). Treats and the post box stay friends-only (CareService, StableService).
--   VisitArrive (server -> the visitor): once a second the server sees who stands in someone else's
--   barn and is let in; walking in (or arriving at the gate by the Map) sends the barn's owner id,
--   display name, plot, whether you're friends, and today's tour stops (nil when you leave). The
--   client shows the banner and the walkaround (VisitTour.client).
--   VisitTour (server -> the visitor): ownerUserId, the stops seen today, true when the Tour pin was
--   just earned (once ever per barn, the D-060 Tour stamps), and true when no more barns can be
--   toured today (the client stops trying). The 4th stop is the Legend paddock when the owner has a
--   Legend, else their garden (Visits.stopsFor; the arrival says which).
--   VisitCheer (server -> the visitor, and the owner when standing in their own yard): the barn's
--   plot and the cheer id, for the floating emoji (no name).
--   Walking back into the same barn within visit.arriveRepeatSeconds sends quiet = true: no second
--   bell or banner (code review N1).
--   Nothing here takes, moves or writes anything in the owner's stable; there is no text.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visits = require(Shared:WaitForChild("Visits"))
local Profile = require(Shared:WaitForChild("Profile"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local VisitAccess = require(script.Parent:WaitForChild("VisitAccess"))

local VisitHello = Profiles.remote("VisitHello")   -- client -> server: ownerUserId, "pat"|"cheer"|"stop", arg
local VisitArrive = Profiles.remote("VisitArrive") -- server -> the visitor: { ownerId, name, plot, friend, done, pinned } or nil
local VisitTour = Profiles.remote("VisitTour")     -- server -> the visitor: ownerUserId, stops seen today, pin earned now, full
local VisitCheer = Profiles.remote("VisitCheer")   -- server -> the visitor (and the owner at home): plot, cheer id
local CareFx = Profiles.remote("CareFx")           -- server -> all: plot, horseId, kind (the pat's hearts)

local CFG = GameConfig.visit
local ACTION = { pat = "pat", cheer = "cheer", stop = "look" } -- VisitHello kind -> Visits.FRIEND_MAY action

local lastHello: { [Player]: number } = {}
local lastOwnerCheer: { [Player]: number } = {}
local at: { [Player]: number } = {} -- visitor -> the owner whose barn they stand in
local arrivedAt: { [Player]: { [number]: number } } = {} -- visitor -> owner -> os.clock() of the last banner

local function hasLegend(odata): boolean
	return #Profile.legends(odata) > 0
end

local function stopPoint(i: number, stopId: string): (number?, number?)
	if not table.find(Visits.ALL_STOPS, stopId) then return nil, nil end
	for _, s in CFG.tourStops do
		if s.id == stopId then return WorldLayout.plotPoint(i, s.inward, s.across) end
	end
	return nil, nil
end

local function pinned(vdata, ownerId: number): boolean
	return typeof(vdata.tour) == "table" and typeof(vdata.tour.stamps) == "table" and vdata.tour.stamps[tostring(ownerId)] ~= nil
end

VisitHello.OnServerEvent:Connect(function(player: Player, ownerId: any, kind: any, arg: any)
	if not CFG.enabled or typeof(kind) ~= "string" or not ACTION[kind] then return end
	if (lastHello[player] or 0) > os.clock() - CFG.helloGapSeconds then return end
	lastHello[player] = os.clock()
	if player:GetAttribute("Racing") then return end
	local owner = VisitAccess.owner(ownerId)
	local ok, why = VisitAccess.check(player, owner, ACTION[kind])
	if not ok then
		if why == "closed" then Profiles.notify(player, "The gate is closed right now", "heart") end
		return
	end
	if not VisitAccess.near(player, owner) then return end
	local vdata, odata = Profiles.get(player), Profiles.get(owner)
	if not vdata or not odata then return end
	local now = os.time()
	if kind == "pat" then
		if typeof(arg) ~= "string" then return end
		local ids = VisitAccess.barnHorses(owner, odata)
		local h = table.find(ids, arg) and Profile.horse(odata, arg)
		if not h then return end
		Profiles.notify(player, h.name .. " nuzzles you!", "heart") -- a pat never gives bond
		CareFx:FireAllClients(owner:GetAttribute("PlotIndex"), arg, "pet")
	elseif kind == "cheer" then
		local done, res = Visits.cheer(vdata, owner.UserId, arg, now, CFG)
		if not done then
			if res.reason == "used" then Profiles.notify(player, "You cheered here today. Thank you!", "heart") end
			return
		end
		Profiles.changed(player)
		Profiles.notify(player, "Cheer sent! " .. res.icon, "heart")
		local plot = owner:GetAttribute("PlotIndex")
		VisitCheer:FireClient(player, plot, arg)
		-- The owner sees a cheer with no name, at most once per ownerCheerGapSeconds (and the emoji over
		-- their barn door when they're home).
		if (lastOwnerCheer[owner] or 0) <= os.clock() - CFG.ownerCheerGapSeconds then
			lastOwnerCheer[owner] = os.clock()
			Profiles.notify(owner, "A visitor cheered! " .. res.icon, "heart")
			local opos = VisitAccess.position(owner)
			if opos and plot and Visits.inside(WorldLayout.plotRect(plot), opos.X, opos.Z) then VisitCheer:FireClient(owner, plot, arg) end
		end
	else
		local i = owner:GetAttribute("PlotIndex")
		local x, z = stopPoint(i, arg)
		local pos = VisitAccess.position(player)
		if not x or not pos or Vector3.new(pos.X - x, 0, pos.Z - (z :: number)).Magnitude > CFG.stopStuds then return end
		local legend = hasLegend(odata)
		local done, res = Visits.stop(vdata, owner.UserId, arg, now, legend)
		if not done then
			if res.reason == "full" then VisitTour:FireClient(player, owner.UserId, {}, false, true) end -- stop trying (N2)
			return
		end
		if res.fresh or res.pin then Profiles.changed(player) end
		VisitTour:FireClient(player, owner.UserId, Visits.stopsToday(vdata, owner.UserId, now, legend), res.pin == true)
		if res.pin then Profiles.notify(player, "📍 Tour pin! You toured " .. owner.DisplayName .. "'s barn", "heart") end
	end
end)

-- Who stands in whose barn, let in: the banner and the walkaround start when this changes.
local function arrivals()
	local owners: { [number]: Player } = {}
	for _, p in Players:GetPlayers() do
		local k = p:GetAttribute("PlotIndex")
		if typeof(k) == "number" then owners[k] = p end
	end
	for _, visitor in Players:GetPlayers() do
		local pos = VisitAccess.position(visitor)
		local here: Player? = nil
		local plot: number? = nil
		if pos and not visitor:GetAttribute("Racing") then
			for k, owner in owners do
				if owner ~= visitor and Visits.inside(WorldLayout.plotRect(k), pos.X, pos.Z) then
					if VisitAccess.check(visitor, owner, "enter") then here, plot = owner, k end
					break
				end
			end
		end
		local uid = here and here.UserId
		if at[visitor] ~= uid then
			at[visitor] = uid
			if here then
				local vdata, odata = Profiles.get(visitor), Profiles.get(here)
				local now = os.time()
				local legend = odata ~= nil and hasLegend(odata)
				local seen = arrivedAt[visitor] or {}
				arrivedAt[visitor] = seen
				local quiet = (seen[here.UserId] or -math.huge) > os.clock() - CFG.arriveRepeatSeconds
				if not quiet then seen[here.UserId] = os.clock() end
				VisitArrive:FireClient(visitor, {
					ownerId = here.UserId,
					name = here.DisplayName,
					plot = plot,
					friend = VisitAccess.friends(visitor, here),
					legend = legend,
					done = if vdata then Visits.stopsToday(vdata, here.UserId, now, legend) else {},
					pinned = vdata ~= nil and pinned(vdata, here.UserId),
					quiet = quiet,
				})
			else
				VisitArrive:FireClient(visitor, nil)
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(CFG.arriveCheckSeconds)
		if CFG.enabled then
			local ok, err = pcall(arrivals)
			if not ok then warn("[VisitService] arrivals: " .. tostring(err)) end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastHello[player], lastOwnerCheer[player], at[player], arrivedAt[player] = nil, nil, nil, nil
end)
