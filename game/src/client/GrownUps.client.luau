--!nonstrict
-- GrownUps (D-045, D-049): the ⚙️ button (top right) opens settings and a page for parents;
-- plus the first-ten-minutes tour card and the optional break reminder.
--   Settings: who can visit your stable (Friends, Everyone here or Nobody, D-079), break reminder on or off, sound on or off,
--   Easy Rein (steering help on training courses, D-053) on or off, Smart Steer in races (D-054, on
--   by default), and whether friends may see your training ghosts (off by default). "Nobody"
--   visits also turns off Ride together invites and keeps your barn off friends' lists (D-060).
--   For grown-ups: how races work (no gambling, nothing buys speed), what's saved, chat and
--   safety, this week's play time, and where Roblox's parental controls live.
--   Tour: one friendly step at a time with a GO button (golden hoofprints) and a quiet ✕ far from GO
--   that asks once (AAA Phase 2, D-067). While it runs it owns the screen: it takes the top-centre
--   spot (Ui.slot), and during the race step toasts wait and the step points at the real RACE!.
--   Break reminder: off by default; when on, a gentle note after each hour of play.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local TrainingState = require(script.Parent:WaitForChild("TrainingState"))
local GoTo = require(script.Parent:WaitForChild("GoTo"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tour = require(Shared:WaitForChild("Tour"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors
local player = Players.LocalPlayer

local gui = Ui.screen("GrownUps", 12)

-- ⚙️ button --------------------------------------------------------------------------
-- On touch the 💎 pill sits top right (Hud), so the gear goes under it (touchLayout.gearBelowGem).
local GuiService = game:GetService("GuiService")
local TOUCH = GameConfig.touchLayout
local gear = Ui.button(gui, "⚙️", UDim2.fromOffset(GameConfig.ui.minTouchPx, GameConfig.ui.minTouchPx), UDim2.new(1, -12, 0, 64), C.white, 26)
gear.AnchorPoint = Vector2.new(1, 0)
local function placeGear()
	local top = GuiService:GetGuiInset().Y + 8
	local under = TOUCH.gearBelowGem ~= false and TOUCH.gemPlacement == "topRight" and Ui.touchLayout()
	-- the 💎 pill is minTouchPx tall (Hud.client.luau); the gear sits 8 px under it
	gear.Position = UDim2.new(1, -12, 0, if under then top + GameConfig.ui.minTouchPx + 8 else top)
end
placeGear()
Ui.TouchChanged.Event:Connect(placeGear)

-- Panel ------------------------------------------------------------------------------
local panelGui = Ui.screen("GrownUpsPanel", 13)
panelGui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = panelGui
local W, H = 640, 470
local panel = Ui.card(panelGui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
-- Smallest text 16, smallest button 56: never shrinks; on a short screen it gets shorter and its
-- body scrolls (D-064 floors, AAA Phase 2).
local slideIn = Ui.fitPanel(panel, W, H, 300, 16, 56)
local closeBtn = Ui.closeButton(panel)
local tabs = Instance.new("Frame")
tabs.BackgroundTransparency = 1
tabs.Size = UDim2.new(1, -120, 0, 56)
tabs.Position = UDim2.new(0, 16, 0, 12)
tabs.Parent = panel
local tl = Instance.new("UIListLayout")
tl.FillDirection = Enum.FillDirection.Horizontal
tl.Padding = UDim.new(0, 8)
tl.Parent = tabs
local body = Instance.new("ScrollingFrame")
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, -32, 1, -98)
body.Position = UDim2.new(0, 16, 0, 84)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.CanvasSize = UDim2.new()
body.ScrollBarThickness = 6
body.Parent = panel
local bl = Instance.new("UIListLayout")
bl.Padding = UDim.new(0, 10)
bl.SortOrder = Enum.SortOrder.LayoutOrder
bl.Parent = body

local tab = "settings"
local render

local function para(text: string, size: number?, order: number)
	local l = Ui.text(body, text, size or 18, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order })
	return l
end

local function choice(label: string, options: { { string } }, current: any, onPick, order: number, buttonW: number?)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 60)
	row.LayoutOrder = order
	row.Parent = body
	Ui.text(row, label, 18, { Size = UDim2.new(0, 220, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -230, 1, 0)
	holder.Position = UDim2.new(0, 230, 0, 0)
	holder.Parent = row
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 8)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = holder
	for _, opt in options do
		local b = Ui.button(holder, opt[2], UDim2.fromOffset(buttonW or 150, 56), UDim2.new(), if opt[1] == current then C.gold else C.white, 17)
		b.Activated:Connect(function() onPick(opt[1]) end)
	end
end

local function settingsTab()
	local d = PlayerState.data
	if not d then return end
	-- (D-079) three choices, 116 px each so they fit beside the label; an old "Club" shows as Friends
	local visits = if d.settings.visits == "Everyone" or d.settings.visits == "Nobody" then d.settings.visits else "Friends"
	local visitOpts = { { "Friends", "👫 Friends" }, { "Everyone", "🌍 Everyone here" }, { "Nobody", "🔒 Nobody" } }
	if GameConfig.visit.everyone == false then table.remove(visitOpts, 2) end
	choice("Who can visit my stable?", visitOpts, visits,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("visits", v) end, 1, 116)
	choice("Break reminder (each hour)", { { true, "On" }, { false, "Off" } }, d.settings.breakReminder == true,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("breakReminder", v) end, 2)
	choice("Sound", { { true, "🔊 On" }, { false, "🔇 Off" } }, d.settings.sound ~= false,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("sound", v) end, 3)
	choice("Easy Rein (helps steer on training rides)", { { true, "🐴 On" }, { false, "Off" } }, d.settings.easyRein == true,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("easyRein", v) end, 4)
	choice("Smart Steer (your race horse finds the rail)", { { true, "🧭 On" }, { false, "Off" } }, d.settings.smartSteer ~= false,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("smartSteer", v) end, 5)
	choice("Share my ghost with friends", { { true, "👻 On" }, { false, "Off" } }, d.settings.shareGhost == true,
		function(v) gameRemotes:WaitForChild("SetSetting"):FireServer("shareGhost", v) end, 6)
	local tourBtn = Ui.button(body, "🧭 Show me around again", UDim2.fromOffset(280, 56), UDim2.new(), C.sky, 18)
	tourBtn.LayoutOrder = 7
	tourBtn.Activated:Connect(function()
		Ui.toast("Follow the steps at the top of the screen!", "map", "🧭")
		panelGui.Enabled = false
		gameRemotes:WaitForChild("SetSetting"):FireServer("tour", "restart")
	end)
	para("👫 Friends: only Roblox friends can visit. 🌍 Everyone here: anyone in this server can look around, pat your horses and send a cheer; only friends can give a treat or drop a carrot. Nobody can take, move, buy or write anything in your stable. Tap 🚪 Close gate any time to send visitors home. \"Nobody\" also means no Ride together invites.", 16, 8).TextColor3 = C.plum
end

local function grownUpsTab()
	local d = PlayerState.data
	local mins = math.floor(((d and d.playtimeWeek) or 0) / 60)
	para("👋 Hello, grown-ups!", 24, 10)
	para(string.format("Play time this week: %d h %d min", mins // 60, mins % 60), 18, 20)
	para("🏁 How races work: each horse's chance comes from its care and training; riding well (tapping in time) moves it up; a little luck shows near the finish. There is no gambling of any kind: entry is free, prizes are fixed before the race, and nothing can be bought to win.", 16, 30)
	para("🧭 Riders can steer a little: the best trip is worth about 2 points of a 100-point ride, and nothing buys it. Smart Steer is on unless turned off, and always on in a rider's first 3 races.", 16, 31)
	para("🐎 Horses can get boxed in, like in real racing: they wait for a gap or ease back to find one. There's no penalty for being boxed in; a horse held wide just runs a little farther.", 16, 32)
	para("🤝 A rider who keeps pressing into a horse alongside makes the two brush shoulders. A brush costs the horse that bumped a tiny bit (a third of a point at most), never the horse that was bumped. Bots and Smart Steer never bump.", 16, 33)
	local shop = d and d.shop
	para("💎 Diamonds cost real money through Robux, 1 Diamond = 1 Robux in every pack (no bigger-pack bonus). They buy looks only: saddle cloths and helmets for riding around, barn paint, name plates and yard decor.", 16, 40)
	para("Never for sale: horses, coats, stats, speed, Green Cash, food, Energy, race entries, fan gear, trophies, rosettes or anything random.", 16, 41)
	para(string.format("Our own limits: the game won't offer more than %d Robux of Diamonds in 24 hours or %d in 30 days. Diamonds bought in the last 30 days: %d Robux. No buying in line, during a race, on the results screen or for two minutes after. Any look can be returned within a day for all its Diamonds; Robux refunds go through Roblox Support.",
		shop and shop.caps and shop.caps.dayRobux or 250, shop and shop.caps and shop.caps.monthRobux or 1000, shop and shop.monthRobux or 0), 16, 42)
	para("🐴 Horses never fall ill, run away or come to harm if your child takes a break. There are no streaks to lose and no countdowns.", 16, 50)
	para("💬 Chat uses Roblox's own filtered chat and age settings. Horse names are built from a word list, so nothing can be typed.", 16, 60)
	para("👫 Ride together: only Roblox friends can invite each other to a training ride, and only if the invite is accepted (it can always be declined, lapses by itself and is limited to a few). Riders see each other's stars and medals, never times or who was first. Setting stable visits to Nobody turns invites off. 🎈 Race with a friend: from More choices, your child can join a Roblox friend in this server in a free Practice race (no prizes, no points); nothing is sent to the friend.", 16, 61)
	para("👻 Ghosts: a see-through horse shows your child's own best training ride. Friends see it only if \"Share my ghost with friends\" is turned on in Settings (it's off at first).", 16, 62)
	para(string.format("🏡 Visiting barns: stable visits are set to Friends unless changed (Settings). The Map lists Roblox friends' barns in the same game server, plus barns whose owners chose Everyone here. Anyone visiting can look around, walk a 4-stop tour, pat horses (no stats) and send one of 4 preset cheers, shown to the owner with no name. Only friends can give a free treat or drop a carrot. There is no typing, nothing can be taken or changed, and nobody sees visitor counts, likes or rankings. Everyone here works only where Roblox allows content sharing for both players; otherwise only friends visit. Visitors arrive outside the gate. The owner can ask one visitor to leave (they can't come back for %d minutes) or close the gate in one tap, which walks everyone back to the lane. Nobody keeps everyone out.", GameConfig.visit.askLeaveSeconds // 60), 16, 63)
	local career, rehome = GameConfig.career, GameConfig.rehome
	para(string.format("🎖️ Careers: every %d races a horse earns a career patch. Horses have life stages: Young (training grows a little faster for the first %d races), Prime, and Veteran at %d races. Once a Veteran has finished growing, it races a little slower in rated races, very gently (at most %d Rating), never in Practice; stats, League Points and everything earned stay. The card says so 10 races ahead. A Veteran may retire as a 👑 Legend, only if your child chooses: it moves to the Hall of Fame paddock, keeps its stats and can still be ridden. A Legend can come back to the races any time.",
		career.badgeEvery, GameConfig.ageing.youngRaces, career.veteranAt, GameConfig.ageing.declineCap), 16, 64)
	para(string.format("🩺 Legs and the vet: after %d races in a row on one horse, rated races wait for a free 30-second Cool-down Check at the Vet (cool water, soft wraps, a carrot). Practice stays open. Feeding, brushing, %d minutes' rest, a Spa Day or training lowers the count. It only comes from lots of racing, never from neglect; nothing is permanent and nothing is for sale.",
		GameConfig.legs.runLimit, GameConfig.legs.restSeconds // 60), 16, 65)
	para(string.format("🏫 Riding School: a horse can be lent to %s for free and brought home any time (it stays yours), or sold there. A sale pays half of what your child paid plus a small bonus for its wins (never more than the price; nothing for a tamed or gifted horse, which earns a goodbye rosette instead). It takes two taps, and for %d days a sold horse can come back for the same Green Cash. The first horse is never sold and the last racing horse always stays. Horses are never traded between players.",
		rehome.school, rehome.undoHours // 24), 16, 66)
	para("🔒 Spending limits, chat and play-time controls live in Roblox's Parental Controls (Settings → Parental Controls on roblox.com).", 16, 70)
end

render = function()
	for _, ch in tabs:GetChildren() do if ch:IsA("TextButton") then ch:Destroy() end end
	for _, ch in body:GetChildren() do if not ch:IsA("UIListLayout") then ch:Destroy() end end
	for _, t in { { "settings", "⚙️ Settings" }, { "grownups", "👪 For grown-ups" } } do
		local b = Ui.button(tabs, t[2], UDim2.fromOffset(200, 56), UDim2.new(), if tab == t[1] then C.gold else C.white, 18)
		b.Activated:Connect(function()
			tab = t[1]
			render()
		end)
	end
	if tab == "settings" then settingsTab() else grownUpsTab() end
end

local function open()
	panelGui.Enabled = true
	slideIn()
	render()
end
gear.Activated:Connect(function() if panelGui.Enabled then panelGui.Enabled = false else open() end end)
closeBtn.Activated:Connect(function() panelGui.Enabled = false end)
dim.Activated:Connect(function() panelGui.Enabled = false end)
PlayerState.Changed.Event:Connect(function() if panelGui.Enabled then render() end end)

-- Tour card -------------------------------------------------------------------------------
-- The first minute has one voice (AAA Phase 2, D-067): the tour takes the top-centre spot (over
-- the queue card and toasts), the race step points at the real RACE! button (Hud pulses it) instead
-- of a GO of its own, toasts wait during that step, and the ✕ that skips sits at the far end from
-- GO and asks once.
local FM = GameConfig.firstMinute or {}
local SLOTP = GameConfig.topSlot or { tour = 30 }
local TOUR_W, TOUR_H = 600, 76
local BTN = GameConfig.ui.minTouchPx
local tourCard = Ui.card(gui, UDim2.fromOffset(TOUR_W, TOUR_H), UDim2.new(0.5, 0, 0, 96), C.cream)
tourCard.AnchorPoint = Vector2.new(0.5, 0)
tourCard.Visible = false
local wantTop = Ui.slot("tour", SLOTP.tour or 30, tourCard)
local tourSkip = Ui.closeButton(tourCard, UDim2.new(0, 10, 0.5, -BTN / 2), BTN)
local tourText = Ui.text(tourCard, "", 18, { Position = UDim2.new(0, BTN + 22, 0, 0), Size = UDim2.new(1, -(BTN + 22) - 132, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left })
local tourGo = Ui.button(tourCard, "GO ▶", UDim2.fromOffset(112, BTN), UDim2.new(1, -122, 0.5, -BTN / 2), C.orange, 20)
local currentStep = nil
local inLine = false
local skipAsked = 0 -- os.clock() of the first ✕ tap (skipConfirm), 0 = not asked

local function goTo(go: string?)
	if go == "race" then -- the tour's first GO: the RACE! button's one tap (D-063)
		local quick = HudEvents:FindFirstChild("QuickRace")
		if quick then quick:Fire() end
	elseif go then -- (D-075) walk or a trip, then open what's there (GoTo)
		GoTo.place(go)
	end
end

local function renderTour()
	local d = PlayerState.data
	local step = nil
	if d and #d.horses > 0 then
		local flags = d.flags or {}
		local i = Tour.current(flags)
		step = i and Tour.STEPS[i]
	end
	currentStep = if step then table.find(Tour.STEPS, step) else nil
	if step then
		local h = PlayerState.activeHorse()
		local racing = step.go == "race"
		local pointing = racing and FM.tourGoOnRace == false
		if skipAsked > 0 then
			tourText.Text = "Skip the tour? Tap ✕ again."
		else
			tourText.Text = "🧭 " .. Tour.text(step, h and h.name, pointing)
		end
		-- GO only where it does something: never while you're already in line for the race step.
		tourGo.Visible = step.go ~= nil and not pointing and not (racing and inLine)
		tourText.Size = UDim2.new(1, -(BTN + 22) - (if tourGo.Visible then 132 else 14), 1, 0)
		tourSkip.BackgroundColor3 = if skipAsked > 0 then C.gold else C.white
	end
end
tourGo.Activated:Connect(function()
	local step = currentStep and Tour.STEPS[currentStep]
	if step then goTo(step.go) end
end)
tourSkip.Activated:Connect(function()
	-- (D-069, the UI/UX consult) A quick double tap never skips: the second tap must come
	-- skipGuardSeconds after the first.
	if skipAsked > 0 and os.clock() - skipAsked < (FM.skipGuardSeconds or 0.6) then return end
	if FM.skipConfirm ~= false and skipAsked == 0 then
		skipAsked = os.clock()
		renderTour()
		task.delay(4, function()
			if skipAsked > 0 and os.clock() - skipAsked >= 3.9 then
				skipAsked = 0
				renderTour()
			end
		end)
		return
	end
	skipAsked = 0
	gameRemotes:WaitForChild("TourSkip"):FireServer()
	currentStep = nil
	tourCard.Visible = false
end)
ReplicatedStorage:WaitForChild("RaceRemotes"):WaitForChild("QueueStatus").OnClientEvent:Connect(function(isIn)
	inLine = isIn == true
	renderTour()
end)
PlayerState.watch(function() renderTour() end)

-- Toasts wait while the race step is up (the first minute), at most holdToastSeconds.
local holdSince: number? = nil
local holding = false
local function setHold(on: boolean)
	if on == holding then return end
	holding = on
	Ui.holdToasts(on)
end
RunService.Heartbeat:Connect(function()
	-- While any race is on screen (riding or watching) the race map and board own the top.
	local busy = RaceState.active == true or RaceState.resultsOpen == true
	local step = currentStep and Tour.STEPS[currentStep]
	-- In line for the race step: that step is as good as done, and the queue card has the news.
	local wants = step ~= nil and not busy and not (step.go == "race" and inLine)
	local show = wantTop(wants)
	if tourCard.Visible ~= show then tourCard.Visible = show end
	if show then
		local cx, w, top = Ui.topSlotPlace(TOUR_W)
		tourCard.Position = UDim2.fromOffset(cx, top)
		tourCard.Size = UDim2.fromOffset(w, TOUR_H)
	end
	-- (a training ride's ✕ Stop sits top right too)
	local gearOff = busy or TrainingState.active == true
	if gear.Visible == gearOff then gear.Visible = not gearOff end
	-- The first minute: hold toasts during the race step until you're in line (or the time is up).
	local raceStep = step ~= nil and step.go == "race" and FM.tourOwnsScreen ~= false
	if raceStep and not inLine and not busy then
		holdSince = holdSince or os.clock()
		setHold(os.clock() - holdSince < (FM.holdToastSeconds or 60))
	else
		if not raceStep then holdSince = nil end
		setHold(false)
	end
end)

-- Break reminder ---------------------------------------------------------------------
local sessionStart = os.clock()
local nextReminder = 60 * 60
RunService.Heartbeat:Connect(function()
	local d = PlayerState.data
	if not d or not d.settings or not d.settings.breakReminder then return end
	local elapsed = os.clock() - sessionStart
	if elapsed >= nextReminder then
		nextReminder = (math.floor(elapsed / 3600) + 1) * 3600 -- one note, even if it was just turned on
		Ui.toast("Time for a stretch and a drink of water! 🌤️", "welcome_sun", "🌤️")
	end
end)

-- Opening your stable (D-065) ---------------------------------------------------------
-- While another server still holds this player's save (a fast rejoin after a crash), the
-- server keeps trying instead of kicking (Profiles.load) and says so here. "Try again" rejoins
-- the game; the card goes away by itself when the profile arrives.
local waitGui = Ui.screen("OpeningStable", 20)
waitGui.Enabled = false
local waitCard = Ui.card(waitGui, UDim2.fromOffset(420, 220), UDim2.fromScale(0.5, 0.5), C.paper)
waitCard.AnchorPoint = Vector2.new(0.5, 0.5)
Ui.text(waitCard, "🐴 Opening your stable…", 28, { Position = UDim2.new(0, 12, 0, 18), Size = UDim2.new(1, -24, 0, 36) })
Ui.text(waitCard, "Your horses are on their way. This can take a minute.", 18,
	{ Position = UDim2.new(0, 20, 0, 62), Size = UDim2.new(1, -40, 0, 50), TextWrapped = true }).TextColor3 = C.plum
local retryBtn = Ui.button(waitCard, "Try again", UDim2.fromOffset(200, 60), UDim2.new(0.5, -100, 1, -78), C.orange, 24)
retryBtn.Activated:Connect(function()
	retryBtn.Text = "Rejoining…"
	local ok = pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, player) end)
	if not ok then
		retryBtn.Text = "Try again"
		Ui.toast("Couldn't rejoin just now. Your stable is still opening!", "hay", "🐴")
	end
end)
gameRemotes:WaitForChild("ProfileWaiting").OnClientEvent:Connect(function(waiting)
	waitGui.Enabled = waiting == true and PlayerState.data == nil
end)
gameRemotes:WaitForChild("ProfileSync").OnClientEvent:Connect(function()
	waitGui.Enabled = false
end)
