--!nonstrict
-- TrainingFriends (D-053, T4): who is friends with whom, for Ride together and shared ghosts.
-- Player:IsFriendsWith is asked once per pair when someone joins (pcall; a failure counts as
-- "not friends" until they rejoin) and cached; it's never asked on a button press.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")

local TrainingFriends = {}

local cache: { [number]: { [number]: boolean } } = {}

local function set(a: number, b: number, v: boolean)
	cache[a] = cache[a] or {}
	cache[b] = cache[b] or {}
	cache[a][b], cache[b][a] = v, v
end

local function check(a: Player, b: Player)
	if a == b or not a.Parent or not b.Parent then return end
	local known = cache[a.UserId] and cache[a.UserId][b.UserId]
	if known ~= nil then return end
	local ok, res = pcall(function() return a:IsFriendsWith(b.UserId) end)
	set(a.UserId, b.UserId, ok and res == true)
end

function TrainingFriends.areFriends(a: Player, b: Player): boolean
	return a ~= b and cache[a.UserId] ~= nil and cache[a.UserId][b.UserId] == true
end

-- Friends of `player` who are in this server.
function TrainingFriends.friendsOf(player: Player): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if TrainingFriends.areFriends(player, p) then table.insert(out, p) end
	end
	return out
end

Players.PlayerAdded:Connect(function(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player then task.spawn(check, player, other) end
	end
end)
for _, a in Players:GetPlayers() do
	for _, b in Players:GetPlayers() do
		if a.UserId < b.UserId then task.spawn(check, a, b) end
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	local row = cache[player.UserId]
	cache[player.UserId] = nil
	for other in row or {} do
		if cache[other] then cache[other][player.UserId] = nil end
	end
end)

return TrainingFriends
