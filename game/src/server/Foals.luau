--!nonstrict
-- Foals (D-080): the server side of breeding that other services call. BreedingService owns the
-- remotes and the Foal Barn; RaceService calls Foals.afterRace once per counted race (one line), and
-- Profiles' Loaded event runs Foals.onLoaded. Rules live in shared/Breeding.luau (never re-rolled here):
--   view(data, busy, now)   the owner's view.breeding (no Potential, no rolled coat before arrival)
--   afterRace(...)          a foal that became ready this race says so after the results; a bred
--                           horse's first counted race sends the one-time "🍼 Comet's foal!" moment
--   onLoaded(player)        a foal waiting (races, or the next play day) says so a little after joining
-- Nothing here is timed for the player: "Arrives in 5 races or tomorrow", never a clock.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Breeding = require(Shared:WaitForChild("Breeding"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local Foals = {}

local FirstRace = Profiles.remote("FoalFirstRace") -- server -> owner: { foal, parent } once, on a bred horse's first counted race

local function cfg(): any
	return GameConfig.breeding
end

local function nameOf(data: any, id: string?): string
	local h = Breeding.find(data, id)
	return if h and typeof(h.name) == "string" then h.name else "Your horse"
end

local function coatOf(data: any, id: string?): string
	local h = Breeding.find(data, id)
	return if h and typeof(h.coat) == "string" then h.coat else "bay"
end

-- Is the stored foal ready to meet you now?
function Foals.ready(data: any, now: number): boolean
	local pend = Breeding.pending(data)
	return pend ~= nil and Breeding.ready(pend, Breeding.ownerRaces(data), now, cfg())
end

-- The stable-wide reason no pair can start a foal now (nil = pick two parents).
function Foals.stableBlock(data: any, busy: any?): string?
	if not cfg().enabled then return "The Foal Barn is closed" end
	local why = Breeding.pairBlock(data, "", "", busy, cfg())
	if why == "Pick two different horses" then return nil end -- (no pair asked yet: only the stable's reasons)
	return why
end

-- view.breeding: what the panel, the Map tile and the Horse Book need.
function Foals.view(data: any, busy: any?, now: number): any
	local c = cfg()
	local pend = Breeding.pending(data)
	local out = { enabled = c.enabled == true, nextFoalIn = Breeding.nextFoalIn(data), horses = {}, family = {} }
	if pend then
		out.pending = {
			parents = { pend.parents[1], pend.parents[2] },
			names = { nameOf(data, pend.parents[1]), nameOf(data, pend.parents[2]) },
			coats = { coatOf(data, pend.parents[1]), coatOf(data, pend.parents[2]) },
			racesLeft = math.max(0, pend.atRaces - Breeding.ownerRaces(data)),
			newDay = c.foalAfterNewDay == true,
		}
		out.ready = Foals.ready(data, now)
		-- the coat was rolled at confirm; the client learns it only when the foal is here to meet (the arrival
		-- scene shows it as simply what the foal is: no reveal, no spin)
		if out.ready then out.pending.coat = pend.coat end
	end
	out.stableBlock = if pend then nil else Foals.stableBlock(data, busy)
	for _, h in data.horses do
		out.horses[h.id] = Breeding.horseBlock(data, h, busy, c) or false -- (Legends can be parents)
	end
	-- the Family page: every bred horse at home, its parents, and the first foal
	local first = nil
	for _, h in data.horses do
		if h.origin == "bred" and typeof(h.parents) == "table" then
			if first == nil or (tonumber(h.born) or 0) < (tonumber(first.born) or 0) then first = h end
		end
	end
	for _, h in data.horses do
		if h.origin == "bred" and typeof(h.parents) == "table" then
			table.insert(out.family, {
				id = h.id, name = h.name, coat = h.coat, first = h == first,
				parents = { { name = nameOf(data, h.parents[1]), coat = coatOf(data, h.parents[1]) },
					{ name = nameOf(data, h.parents[2]), coat = coatOf(data, h.parents[2]) } },
			})
		end
	end
	return out
end

local told: { [Player]: string } = {} -- the foal already announced this session (parents + atRaces)
local function key(pend: any): string
	return tostring(pend.parents[1]) .. ":" .. tostring(pend.parents[2]) .. ":" .. tostring(pend.atRaces)
end

local function announce(player: Player, data: any, delay: number)
	local pend = Breeding.pending(data)
	if not pend or not cfg().enabled or told[player] == key(pend) then return end
	if not Foals.ready(data, os.time()) then return end
	told[player] = key(pend)
	task.delay(delay, function()
		if player.Parent then Profiles.notify(player, "💞 Your foal is here!", "heart") end
	end)
end

-- One counted race (RaceService, after Profile.recordRace). `before` = the horse's races before it.
function Foals.afterRace(player: Player, data: any, horseId: string?, before: number?)
	if not cfg().enabled then return end
	local ok, err = pcall(function()
		announce(player, data, GameConfig.runInSeconds + 4)
		local h = horseId and Breeding.find(data, horseId)
		if h and h.origin == "bred" and before == 0 and typeof(h.parents) == "table" then
			local info = { foal = h.name, parent = nameOf(data, h.parents[1]) }
			task.delay(GameConfig.runInSeconds + 2, function()
				if player.Parent then FirstRace:FireClient(player, info) end
			end)
		end
	end)
	if not ok then warn("[Foals] afterRace: " .. tostring(err)) end
end

function Foals.onLoaded(player: Player)
	local data = Profiles.get(player)
	if data then announce(player, data, 10) end
end

Players.PlayerRemoving:Connect(function(player: Player) told[player] = nil end)

return Foals
