--!nonstrict
-- GoTo (Find it, fun-and-return phase 1, D-075): one GO for the Tour, the Next-thing pill, the
-- Stable Board's job and horse cards and the Map's tiles. GO takes you to a place and OPENS what is
-- there (the shop, the Train menu, the vet, the corral...). FindIt.goPlan decides:
--   near (findIt.goTo.walkMaxStuds or less): golden hoofprints, and the feature opens as you arrive;
--   far: a 0.3 s Paper fade, the Map's own trip (the server's Travel), then it opens;
--   in a race line or on a training ride: hoofprints only (you never leave a line by teleporting);
--   riding a race: nothing moves ("After your race!").
-- Each feature registers how it opens: GoTo.register("barnBuilder", open). Panels that already
-- open from a HudEvents BindableEvent (the Stable Board, the picker, the Book, My Horses) are
-- registered here.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local TrainingState = require(script.Parent:WaitForChild("TrainingState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local FindIt = require(Shared:WaitForChild("FindIt"))

local GoTo = {}

local CFG = GameConfig.findIt.goTo
local player = Players.LocalPlayer

-- Which feature a place opens (a place with none just takes you there).
GoTo.OPENS = {
	raceBoard = "picker", pick = "picker", feedStore = "feedShop", barnBuilder = "barnBuilder", tackShop = "tackShop",
	vet = "vet", spa = "spa", market = "market", paddock = "train", trainingGround = "train",
	board = "board", book = "book", horses = "horses", visit = "visit",
	vetCheck = "coolDown", -- (D-077) VET CHECK and the vet Advice: the Vet, then the Cool-down Check
	foalBarn = "foalBarn", -- (D-080) the 💞 Foal Barn: the parents picker, the waiting card or meeting your foal
}
-- Places that stand at another place ("vetCheck" is the Vet).
GoTo.AT = { vetCheck = "vet" }

local opens: { [string]: () -> () } = {}
function GoTo.register(id: string, fn: () -> ())
	opens[id] = fn
end

local function hudEvent(name: string): BindableEvent
	local folder = ReplicatedStorage:FindFirstChild("HudEvents")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "HudEvents"
		folder.Parent = ReplicatedStorage
	end
	local e = folder:FindFirstChild(name)
	if not e then
		e = Instance.new("BindableEvent")
		e.Name = name
		e.Parent = folder
	end
	return e
end
-- picker: the Hud's 🔀 Pick (PressPick), so a join from it gets its reason window (pickerJoinWatch).
for id, event in { board = "OpenBoard", picker = "PressPick", book = "OpenHorseBook", horses = "OpenHorses" } do
	opens[id] = function() hudEvent(event):Fire() end
end

-- Open a feature now. Returns false when nothing is registered for it (yet).
function GoTo.open(id: string?): boolean
	local fn = id and opens[id]
	if not fn then return false end
	task.spawn(fn)
	return true
end

local function racing(): boolean
	return (RaceState.active and RaceState.myLane ~= nil) or player:GetAttribute("Racing") == true
end

local function state(): FindIt.GoState
	return { racing = racing(), inLine = player:GetAttribute("InLine") == true, training = TrainingState.active == true }
end

local function rootPos(): Vector3?
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

-- Where to walk to for a place (x, z), and which Map trip gets you there; nil when it has no spot.
local function spot(place: string): (number?, number?, string?)
	place = GoTo.AT[place] or place
	if place == "stable" or place == "wall" then
		local i = player:GetAttribute("PlotIndex")
		if not i then return nil, nil, nil end
		-- the Rosette Wall stands at (52, 12) in the plot (StableService); stop just in front of it
		local x, z = if place == "wall" then WorldLayout.plotPoint(i, 46, 12) else WorldLayout.plotPoint(i, 40, 0)
		return x, z, "stable"
	end
	local key = WorldLayout.MAP_ALIAS[place] or place
	local p = WorldLayout.places[key]
	if not p then return nil, nil, nil end
	if key == "raceBoard" then return p.x, p.z + 10, place end
	return p.x + p.fx * 12, p.z + p.fz * 12, place
end

-- The plan for a place right now (for a button's words: "GO ▶" or "Take me ▶").
function GoTo.plan(place: string): FindIt.GoPlan
	local x, z = spot(place)
	local pos = rootPos()
	local dist = if x and pos then math.sqrt((pos.X - x) ^ 2 + (pos.Z - (z :: number)) ^ 2) else nil
	return FindIt.goPlan(place, dist, state())
end

function GoTo.label(place: string): string
	return GoTo.plan(place).label
end

-- The Paper fade (FFF7E6, never a hard cut).
local fadeGui = Ui.screen("GoToFade", 30)
fadeGui.IgnoreGuiInset = true
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Ui.colors.paper
fade.BackgroundTransparency = 1
fade.BorderSizePixel = 0
fade.Parent = fadeGui
local function fadeTo(t: number)
	local tw = TweenService:Create(fade, TweenInfo.new(CFG.fadeSeconds, Enum.EasingStyle.Quad), { BackgroundTransparency = t })
	tw:Play()
	tw.Completed:Wait()
end

-- Opens on arrival only in a calm moment: not racing, in line, on a training ride or on the results
-- card (RaceState.shopClosed(0)); a kid who joined a line on the way just arrives.
local function calm(): boolean
	return not racing() and not RaceState.shopClosed(0)
end
local function openAfter(id: string?)
	if not id or not calm() then return end
	task.delay(CFG.openDelaySeconds, function()
		if calm() then GoTo.open(id) end
	end)
end

local busy = false
-- Go to `place` and open what's there (or `openId` instead). opts.toast = false: the caller says
-- "Follow the golden hoofprints!" itself. Returns the plan it followed.
function GoTo.place(place: string, openId: string?, opts: { toast: boolean? }?): FindIt.GoPlan
	local plan = GoTo.plan(place)
	local id = openId or GoTo.OPENS[place]
	local toast = not (opts and opts.toast == false)
	if plan.how == "wait" then
		Ui.toast("After your race!", "flag_ready", "🏁")
		return plan
	end
	if plan.how == "open" then
		if not GoTo.open(id) then Ui.toast("Coming soon!", "heart", "🐴") end
		return plan
	end
	local x, z, trip = spot(place)
	if not x then
		if place == "stable" or place == "wall" then Ui.toast("Pick your first horse to open your stable!", "heart", "🐴") end
		return plan
	end
	if plan.how == "walk" then
		Guide.to(x :: number, z :: number, if plan.open then function() openAfter(id) end else nil, CFG.arriveStuds)
		if toast then Ui.toast("Follow the golden hoofprints!", "hoofprint", "🐾") end
		return plan
	end
	-- Teleport: fade, the Map's trip, fade back, then open.
	if busy then return plan end
	busy = true
	task.spawn(function()
		local before = rootPos()
		fadeTo(0)
		Guide.clear()
		ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("Travel"):FireServer(trip)
		local t0 = os.clock()
		while os.clock() - t0 < CFG.travelWaitSeconds do
			task.wait(0.05)
			local now = rootPos()
			if now and before and (now - before).Magnitude > CFG.walkMaxStuds / 2 then break end
		end
		fadeTo(1)
		busy = false
		-- The trip didn't happen (on a race horse still, or too soon after the last): hoofprints instead.
		local now = rootPos()
		if now and math.sqrt((now.X - x) ^ 2 + (now.Z - z) ^ 2) > CFG.walkMaxStuds then
			Guide.to(x :: number, z :: number, if plan.open then function() openAfter(id) end else nil, CFG.arriveStuds)
			if toast then Ui.toast("Follow the golden hoofprints!", "hoofprint", "🐾") end
			return
		end
		openAfter(id)
	end)
	return plan
end

return GoTo
