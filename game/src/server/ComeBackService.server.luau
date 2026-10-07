--!nonstrict
-- ComeBackService (D-063, stage 6): reasons to come back, on the server.
--   The Horse Book: copies what your horses have earned into the book on every sync and sends
--   the book to its owner (RaceService adds courses, places, Cups and personal bests as they
--   happen; JobService pays the monthly stamp cloths).
--   Welcome Back Hay Bale: Profiles gives the flat gift as the profile loads (WelcomeBack.onJoin,
--   from the saved last visit); the owner's client shows it until they tap "Thanks!"
--   (WelcomeSeen). Nothing here is ranked, sold, timed or a streak.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local HorseBook = require(Shared:WaitForChild("HorseBook"))
local WelcomeBack = require(Shared:WaitForChild("WelcomeBack"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local CB = GameConfig.comeback or {}
local WelcomeSeen = Profiles.remote("WelcomeSeen") -- client -> server: the gift card was tapped

Profiles.addDecorator(function(data, view)
	HorseBook.sync(data)
	view.comeback = { horseBook = CB.horseBook ~= false, photo = CB.photo ~= false, bests = CB.bests ~= false }
	if CB.horseBook ~= false then view.book = HorseBook.view(data) end
	view.welcome = WelcomeBack.view(data)
end, "comeback")

local last: { [Player]: number } = {}
WelcomeSeen.OnServerEvent:Connect(function(player: Player)
	if os.clock() - (last[player] or 0) < 0.5 then return end
	last[player] = os.clock()
	local data = Profiles.get(player)
	if data and WelcomeBack.seen(data) then Profiles.changed(player) end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	last[player] = nil
end)
