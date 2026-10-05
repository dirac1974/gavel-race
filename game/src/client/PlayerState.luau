--!nonstrict
-- PlayerState: the owner's view of their own profile (Profile.view on the server), kept in
-- sync by ProfileSync. Every client script reads it from here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("GameRemotes")

local PlayerState = {
	data = nil, -- { cash, items, horses = { view }, activeHorse, stalls, daysPlayed, totals, settings, flags }
}
PlayerState.Changed = Instance.new("BindableEvent")

remotes:WaitForChild("ProfileSync").OnClientEvent:Connect(function(view)
	local before = PlayerState.data
	PlayerState.data = view
	PlayerState.Changed:Fire(view, before)
end)
task.defer(function()
	remotes:WaitForChild("RequestSync"):FireServer() -- in case the first sync arrived before we listened
end)

function PlayerState.activeHorse()
	local d = PlayerState.data
	if not d then return nil end
	for _, h in d.horses do
		if h.id == d.activeHorse then return h end
	end
	return nil
end

function PlayerState.horse(id: string)
	local d = PlayerState.data
	if not d then return nil end
	for _, h in d.horses do
		if h.id == id then return h end
	end
	return nil
end

-- Call fn(data) now if loaded, and on every change.
function PlayerState.watch(fn)
	if PlayerState.data then task.spawn(fn, PlayerState.data, nil) end
	return PlayerState.Changed.Event:Connect(fn)
end

return PlayerState
