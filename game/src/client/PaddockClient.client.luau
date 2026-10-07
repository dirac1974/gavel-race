--!nonstrict
-- PaddockClient (D-039, D-040, D-053): the training picker at the Training Paddock and the
-- heartbeat check-up at the Vet.
--   Train (D-053): four picture tiles for the ride-through courses on your active horse
--     (GameConfig.training.courses says which are open; a closed one says "Coming soon"), plus "Quick
--     train" for the old games. Picking a course (here or at its picture sign's "Ride" prompt)
--     asks TrainingRideClient to start it. GameConfig.training.mode = "meters" shows only the
--     games, as before D-053.
--   Quick train: pick a horse and a stat, play a 10-second game. The server seeds the game and
--   scores the tap times (T4, QuickTrain); this screen draws the same game from the same rules
--   and shows the server's score at the end.
--   Ride together (T4): "👫 Ride together" lists friends nearby who can be invited; pick one and
--   a course and an invite goes out (the friend must accept). No text travels with it.
--   This week's course (T5): the Mud Splash tile says "This week's course" and shows four small
--   ribbon icons, one per layout (the ribbon you have on it, or an empty one), this week's
--   ringed in orange. No dates or timers: a layout's ribbons can be earned whenever it's back.
--     Sprint Lane (Speed): tap as the runner crosses each glowing zone.
--     Gate Break (Acceleration): wait for green, then tap fast.
--     Hill Climb (Stamina): hold to keep the marker in the moving green band.
--     Mud Splash (Grit): tap as each puddle reaches the hoof.
--   Vet: tap with each heartbeat; collect Health Passport stamps (one a day).
--   Spa Day (D-058, stage 4): at the Vet (or the wash bay's "Spa Day" prompt) pick a horse, then
--     rinse with the hose, brush and dry with a towel, tapping only (about 30 s). +1 Energy, a
--     Spa stamp and a shine on the next race, once per horse per day; after that the button says
--     "Spa opens again tomorrow" (no clock anywhere).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Training = require(Shared:WaitForChild("Training"))
local QuickTrain = require(Shared:WaitForChild("QuickTrain"))
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TrainingCourses = require(Shared:WaitForChild("TrainingCourses"))
local TrainingState = require(script.Parent:WaitForChild("TrainingState"))
local Spa = require(Shared:WaitForChild("Spa"))

local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local C = Ui.colors

-- Modal ------------------------------------------------------------------------------
local gui = Ui.screen("Paddock", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local W, H = 620, 440
local card = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), C.paper)
card.AnchorPoint = Vector2.new(0.5, 0.5)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
local function rescale()
	local cam = workspace.CurrentCamera
	if cam then cardScale.Scale = math.min(1, (cam.ViewportSize.X - 20) / W, (cam.ViewportSize.Y - 20) / H) end
end
rescale()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
local title = Ui.text(card, "", 30, { Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 36) })
local sub = Ui.text(card, "", 18, { Position = UDim2.new(0, 20, 0, 50), Size = UDim2.new(1, -40, 0, 24) })
sub.TextColor3 = C.plum
local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, -32, 1, -96)
body.Position = UDim2.new(0, 16, 0, 82)
body.Parent = card
local closeBtn = Ui.button(card, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 10), C.white, 22)
local cleanup: { () -> () } = {}
local generation = 0 -- bumps on every clear, so delayed callbacks from a closed game do nothing
local function clear()
	generation += 1
	for _, f in cleanup do f() end
	table.clear(cleanup)
	body:ClearAllChildren()
end
local function alive(gen: number): boolean
	return gen == generation and gui.Enabled
end
-- A Quick train game asked for or in play: closing the card (or opening another) tells the
-- server, which ends it with no gain.
local quickLive = false
local function stopQuickIfLive()
	if not quickLive then return end
	quickLive = false
	gameRemotes:WaitForChild("QuickStop"):FireServer()
end
local function close()
	stopQuickIfLive()
	clear()
	gui.Enabled = false
end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
local function open(t: string, s: string)
	stopQuickIfLive()
	clear()
	title.Text, sub.Text = t, s
	if not gui.Enabled then
		gui.Enabled = true
		card.Position = UDim2.fromScale(0.5, 0.55)
		TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end
end

local function now(): number
	return os.clock()
end

-- A big TAP button, plus Space / gamepad A bound above everything else and sunk, so the
-- character never hops and typing in chat never counts. onRelease is for the hold game.
local function tapper(onTap: () -> (), label: string?, onRelease: (() -> ())?): TextButton
	local b = Ui.button(body, label or "TAP!", UDim2.new(0.6, 0, 0, 64), UDim2.new(0.2, 0, 1, -70), C.orange, 30)
	b:SetAttribute("NoPop", true) -- a pop on every game tap would cover the beat
	b.MouseButton1Down:Connect(onTap)
	if onRelease then
		b.MouseButton1Up:Connect(onRelease)
		b.MouseLeave:Connect(onRelease)
	end
	ContextActionService:BindActionAtPriority("PaddockTap", function(_, state)
		if state == Enum.UserInputState.Begin then
			onTap()
		elseif state == Enum.UserInputState.End and onRelease then
			onRelease()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	table.insert(cleanup, function() ContextActionService:UnbindAction("PaddockTap") end)
	return b
end

local function heartbeat(fn: (number) -> ())
	local conn = RunService.RenderStepped:Connect(fn)
	table.insert(cleanup, function() conn:Disconnect() end)
	return conn
end

local function area(height: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, height)
	f.BackgroundColor3 = C.sky
	Ui.corner(f, 16)
	Ui.stroke(f, 2)
	f.ClipsDescendants = true
	f.Parent = body
	return f
end

local function flash(text: string, color: Color3?)
	local l = Ui.text(body, text, 34, { Position = UDim2.new(0, 0, 0, 90), Size = UDim2.new(1, 0, 0, 44), ZIndex = 20 })
	l.TextColor3 = color or C.orangeDark
	l.TextStrokeTransparency = 0.6
	TweenService:Create(l, TweenInfo.new(0.7), { TextTransparency = 1, Position = UDim2.new(0, 0, 0, 60) }):Play()
	task.delay(0.75, function() l:Destroy() end)
end

local function label(score: number): string
	return if score >= 90 then "Perfect!" elseif score >= 75 then "Great!" elseif score >= 50 then "Good" else "Okay"
end

-- Games (T4): the server seeds each game and scores the tap times (QuickTrain); each game
-- draws itself from the same rules on the server's clock and calls done(preview score).
-- g = { stat, seed, startAt, events, now = seconds since the game started }
local Games = {}

-- Record a tap (or a hold / let go) and send its time; returns that tap's own score if it counted.
local function quickTap(g, kind: string): number?
	local t = g.now()
	if t < 0 or g.over then return nil end
	if not QuickTrain.addEvent(g.events, t, kind) then return nil end
	gameRemotes:WaitForChild("QuickTap"):FireServer(kind, g.startAt + t) -- the same moment the preview used
	local res = QuickTrain.play(g.stat, g.seed, g.events, t)
	for i = #g.events, 1, -1 do
		if g.events[i].t == t and g.events[i].kind == kind then return res.taps[i] end
	end
	return nil
end

local function whenDone(g, done)
	if g.over then return end
	local res = QuickTrain.play(g.stat, g.seed, g.events, math.max(0, g.now()))
	if res.done then
		g.over = true
		done(res.score)
	end
end

function Games.speed(g, done)
	local a = area(170)
	local lane = Instance.new("Frame")
	lane.Size = UDim2.new(1, -40, 0, 30)
	lane.Position = UDim2.new(0, 20, 0.5, -15)
	lane.BackgroundColor3 = Color3.fromHex("D9B98A")
	Ui.corner(lane, 15)
	lane.Parent = a
	local zone = Instance.new("Frame")
	zone.Size = UDim2.new(QuickTrain.SPEED.half * 2, 0, 1, 10)
	zone.AnchorPoint = Vector2.new(0.5, 0.5)
	zone.BackgroundColor3 = C.gold
	zone.BackgroundTransparency = 0.15
	Ui.corner(zone, 8)
	zone.Parent = lane
	local runner = Ui.text(lane, "🐎", 34, { Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), TextScaled = true })
	local lastRound, tapsSeen = 1, 0
	heartbeat(function()
		local x, center, round = QuickTrain.speedView(g.seed, g.events, math.max(0, g.now()))
		runner.Position = UDim2.fromScale(x, 0.5)
		zone.Position = UDim2.fromScale(center, 0.5)
		if round > lastRound then
			if #g.events == tapsSeen then flash("Next one!", C.plum) end -- that round passed with no tap
			lastRound, tapsSeen = round, #g.events
		end
		whenDone(g, done)
	end)
	tapper(function()
		local s = quickTap(g, "tap")
		if s then flash(label(s), if s >= 75 then C.green else C.orangeDark) end
	end)
end

function Games.accel(g, done)
	local a = area(170)
	local light = Instance.new("Frame")
	light.Size = UDim2.fromOffset(110, 110)
	light.AnchorPoint = Vector2.new(0.5, 0.5)
	light.Position = UDim2.fromScale(0.5, 0.5)
	light.BackgroundColor3 = C.red
	Ui.corner(light, 55)
	Ui.stroke(light, 4)
	light.Parent = a
	local text = Ui.text(a, "Wait for green…", 24, { Position = UDim2.new(0, 0, 1, -34), Size = UDim2.new(1, 0, 0, 30) })
	heartbeat(function()
		local _, green, over = QuickTrain.accelView(g.seed, g.events, math.max(0, g.now()))
		local on = green and not over and g.now() >= 0
		light.BackgroundColor3 = if on then C.green else C.red
		text.Text = if on then "GO!" else "Wait for green…"
		whenDone(g, done)
	end)
	tapper(function()
		local s = quickTap(g, "tap")
		if s == 0 then
			flash("Too soon!", C.red) -- that round counts 0, gently
		elseif s then
			flash(label(s), if s >= 75 then C.green else C.orangeDark)
		end
	end)
end

function Games.stamina(g, done)
	local a = area(220)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 60, 1, -30)
	track.Position = UDim2.new(0.5, -30, 0, 15)
	track.BackgroundColor3 = C.white
	Ui.corner(track, 14)
	Ui.stroke(track, 2)
	track.Parent = a
	local half = QuickTrain.STAMINA.band
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, half * 2, 0)
	band.BackgroundColor3 = C.green
	band.BackgroundTransparency = 0.25
	Ui.corner(band, 10)
	band.Parent = track
	local marker = Ui.text(track, "🐎", 30, { Size = UDim2.new(1, 0, 0, 34), AnchorPoint = Vector2.new(0, 0.5), TextScaled = true })
	-- pressed: the button now; sent: what the server was last told. Holding during "Get ready…"
	-- starts the climb at GO.
	local pressed, sent = false, false
	tapper(function() pressed = true end, "HOLD", function() pressed = false end)
	local cheered = false
	heartbeat(function()
		local t = g.now()
		if t >= 0 and pressed ~= sent and not g.over then
			quickTap(g, if pressed then "down" else "up")
			sent = pressed
		end
		local run = QuickTrain.staminaRun(g.seed, g.events, math.max(0, t))
		band.Position = UDim2.fromScale(0, 1 - run.band - half)
		marker.Position = UDim2.fromScale(0, 1 - run.y)
		band.BackgroundColor3 = if math.abs(run.y - run.band) <= half then C.green else C.gold
		if not cheered and t >= QuickTrain.STAMINA.duration then
			cheered = true
			flash("All done!", C.green) -- the climb is over
		end
		whenDone(g, done)
	end)
end

function Games.grit(g, done)
	local a = area(170)
	local hit = Instance.new("Frame")
	hit.Size = UDim2.fromOffset(70, 70)
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.new(0, 70, 0.5, 0)
	hit.BackgroundColor3 = C.gold
	hit.BackgroundTransparency = 0.3
	Ui.corner(hit, 35)
	Ui.stroke(hit, 3)
	hit.Parent = a
	Ui.text(hit, "🐴", 34, { Size = UDim2.fromScale(1, 1), TextScaled = true })
	local times = QuickTrain.puddles(g.seed)
	local travel = QuickTrain.GRIT.travel
	local puddles = {}
	for k = 1, #times do
		local p = Ui.text(a, "💦", 34, { Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), TextScaled = true })
		p.Position = UDim2.new(1, 40, 0.5, 0)
		puddles[k] = p
	end
	heartbeat(function()
		local t = g.now()
		local res = QuickTrain.play("grit", g.seed, g.events, math.max(0, t))
		local width = a.AbsoluteSize.X
		for k, p in puddles do
			local f = (times[k] - t) / travel -- 1 when it appears, 0 at the hoof
			p.Position = UDim2.new(0, 70 + f * (width - 70), 0.5, 0)
			p.Visible = f <= 1.05 and f >= -0.2 and not res.used[k]
		end
		whenDone(g, done)
	end)
	tapper(function()
		local s = quickTap(g, "tap")
		if s then flash(label(s), if s >= 75 then C.green else C.orangeDark) end
	end)
end

-- Vet: tap with each heartbeat.
local function heartGame(done)
	local a = area(200)
	local heart = Ui.text(a, "❤️", 90, { Size = UDim2.fromOffset(120, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), TextScaled = true })
	local scale = Instance.new("UIScale")
	scale.Parent = heart
	local beats, interval = 6, 0.8
	local start = now() + 1.2
	local times = {}
	for k = 1, beats do times[k] = start + (k - 1) * interval + (if k % 2 == 0 then 0.03 else -0.02) end
	local used, total, finished = {}, 0, false
	local heard = 0 -- beats played as sound so far
	heartbeat(function(dt)
		local t = now()
		if heard < beats and t + dt > times[heard + 1] then -- the beat lands in this frame: play it now, not a frame late
			heard += 1
			if Sound then Sound.play("heartbeat") end
		end
		local pulse = 0
		for _, bt in times do
			local d = t - bt
			if d >= 0 and d < 0.25 then pulse = math.max(pulse, 1 - d / 0.25) end
		end
		scale.Scale = 1 + 0.25 * pulse
		if not finished and t > times[beats] + 0.5 then
			finished = true
			done(total / beats)
		end
	end)
	tapper(function()
		local t = now()
		local best, bestErr = nil, math.huge
		for k, bt in times do
			if not used[k] and math.abs(t - bt) < bestErr then best, bestErr = k, math.abs(t - bt) end
		end
		if best and bestErr <= 0.3 then
			used[best] = true
			local s = math.clamp(100 - (bestErr - 0.05) / 0.25 * 70, 30, 100)
			total += s
			flash(label(s), if s >= 75 then C.green else C.orangeDark)
		end
	end, "TAP ON THE BEAT")
end

-- Horse picker and stat chooser -------------------------------------------------------------
local function stalledHorses()
	local out = {}
	for _, h in (PlayerState.data and PlayerState.data.horses) or {} do
		if h.stalled then table.insert(out, h) end
	end
	return out
end

local function horseRow(onPick: (any) -> ())
	local row = Instance.new("ScrollingFrame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 90)
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.ScrollBarThickness = 4
	row.Parent = body
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 10)
	l.Parent = row
	for _, h in stalledHorses() do
		-- D-058: how it's resting, icon and word
		local rest = if h.resting then "\n" .. Spa.NAP elseif h.yawning then "\n" .. Spa.YAWN else ""
		local b = Ui.button(row, h.name .. rest, UDim2.fromOffset(170, 80), UDim2.new(), Ui.coatColors[h.coat] or C.cream, 20)
		b.TextColor3 = if h.coat == "black" or h.coat == "bay" or h.coat == "chestnut" then C.white else C.ink
		b.Activated:Connect(function() onPick(h) end)
	end
	return row
end

-- A Quick train game asked for (QuickStart) and waiting for the server's seed (QuickBegin), and
-- the server's score once it's done (QuickEnd).
local waitingQuick = nil -- { gen, stat }
local quickScore = nil :: number?

local function showResult(score: number)
	quickLive = false
	clear()
	Ui.text(body, label(score), 44, { Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 54) }).TextColor3 = C.orangeDark
	Ui.text(body, string.format("Score %d", math.floor(score + 0.5)), 24, { Position = UDim2.new(0, 0, 0, 100), Size = UDim2.new(1, 0, 0, 30) })
	local again = Ui.button(body, "Done", UDim2.new(0.4, 0, 0, 56), UDim2.new(0.3, 0, 0, 170), C.green, 24)
	again.Activated:Connect(close)
end

local function playTraining(h, stat: string)
	local game = Training.GAMES[stat]
	local intros = {
		speed = "Tap when the runner is in the glowing zone (5 times)",
		accel = "Wait for the light to turn green, then tap fast (3 times)",
		stamina = "Hold to climb, let go to slide: stay in the green band",
		grit = "Tap as each puddle reaches the hoof (8 puddles)",
	}
	open(game.emoji .. " " .. game.name, intros[stat])
	local go = Ui.button(body, "Ready? GO!", UDim2.new(0.5, 0, 0, 70), UDim2.new(0.25, 0, 0.4, 0), C.orange, 30)
	go.Activated:Connect(function()
		clear()
		local gen = generation
		Ui.text(body, "Get ready…", 34, { Position = UDim2.new(0, 0, 0, 80), Size = UDim2.new(1, 0, 0, 44) })
		waitingQuick, quickScore = { gen = gen, stat = stat }, nil
		quickLive = true
		gameRemotes:WaitForChild("QuickStart"):FireServer(h.id, stat)
		task.delay(4, function()
			-- no game came back: the server turned it down (its toast says why) or the message was lost
			if waitingQuick and waitingQuick.gen == gen and alive(gen) then
				waitingQuick = nil
				close()
			end
		end)
	end)
end

gameRemotes:WaitForChild("QuickBegin").OnClientEvent:Connect(function(stat, seed, startAt)
	local w = waitingQuick
	if not w or w.stat ~= stat or not alive(w.gen) or typeof(seed) ~= "number" or typeof(startAt) ~= "number" then return end
	waitingQuick = nil
	clear()
	local gen = generation
	local g = { stat = stat, seed = seed, startAt = startAt, events = {}, over = false }
	g.now = function(): number return workspace:GetServerTimeNow() - startAt end
	local ready = Ui.text(body, "Get ready…", 30, { Position = UDim2.new(0, 0, 0, 96), Size = UDim2.new(1, 0, 0, 40), ZIndex = 25 })
	heartbeat(function() ready.Visible = g.now() < 0 end)
	Games[stat](g, function(preview: number)
		if not alive(gen) then return end
		-- the server's score arrives a moment after the game ends; its preview is the same
		local t0 = os.clock()
		task.spawn(function()
			while alive(gen) and quickScore == nil and os.clock() - t0 < 3 do task.wait(0.1) end
			if alive(gen) then showResult(quickScore or preview) end
		end)
	end)
end)

gameRemotes:WaitForChild("QuickEnd").OnClientEvent:Connect(function(score)
	if typeof(score) == "number" then quickScore = score end
end)

local function chooseStat(h)
	local trained = h.trainedWeek or 0
	open("Train " .. h.name, string.format("This week: %.1f of %d points%s", trained, Training.WEEKLY_CAP, if h.rested then " · Rested ✨" else ""))
	if not h.trainingReady then
		Ui.text(body, h.name .. " has trained enough this week. Races and care still help!", 22,
			{ Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(1, 0, 0, 80) })
		return
	end
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 1, 0)
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -8, 0, 140)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.Parent = grid
	for _, stat in Training.STATS do
		local game = Training.GAMES[stat]
		local value = h.stats[stat] or 0
		local cap = if h.potential then string.format(" / %d", h.potential[stat]) else " / ?"
		local room = if h.potential then h.potential[stat] - value else nil
		local hint = if room == nil then "Potential: visit the Vet" elseif room < 0.1 then "As high as it goes" elseif room < 8 then "A little room" else "Lots of room to grow"
		local b = Ui.button(grid, string.format("%s %s\n%.1f%s\n%s", game.emoji, game.label, value, cap, hint), UDim2.new(), UDim2.new(), C.cream, 20)
		b.Activated:Connect(function() playTraining(h, stat) end)
	end
end

local function quickTrainMenu()
	open(if GameConfig.training.mode == "rides" then "⚡ Quick train" else "⭐ Training Paddock", "Pick a horse to train")
	if #stalledHorses() == 0 then
		Ui.text(body, "Pick your first horse to start training!", 22, { Size = UDim2.new(1, 0, 0, 40) })
		return
	end
	horseRow(chooseStat)
	Ui.text(body, "Training moves you up leagues. Riding wins races!", 18, { Position = UDim2.new(0, 0, 0, 110), Size = UDim2.new(1, 0, 0, 26) }).TextColor3 = C.plum
end

-- The course picker (D-053): four picture tiles and Quick train.
local RIBBON_EMOJI = { bronze = "🥉", silver = "🥈", gold = "🥇" }

-- Mud Splash's four layouts (T5): a small ribbon icon for each, this week's ringed. The card
-- shrinks on phones (cardScale), so the icons grow to stay at least MIN_ICON_PX on screen.
local MIN_ICON_PX = 22
local function layoutRibbons(parent: Instance, h, y: number)
	local size = math.clamp(math.ceil(MIN_ICON_PX / math.max(cardScale.Scale, 0.1)), 36, 46)
	local row = Instance.new("Frame")
	row.Name = "LayoutRibbons"
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 0, 0, y)
	row.Size = UDim2.new(1, 0, 0, size)
	row.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Padding = UDim.new(0, 8)
	l.Parent = row
	local week = ReplicatedStorage:GetAttribute("WeeklyCourse")
	for n, key in TrainingCourses.LAYOUTS do
		local got = h.ribbons and RIBBON_EMOJI[h.ribbons[key]]
		local cell = Instance.new("Frame")
		cell.LayoutOrder = n
		cell.Size = UDim2.fromOffset(size, size)
		cell.BackgroundColor3 = if got then C.paper else C.white
		Ui.corner(cell, 8)
		Ui.stroke(cell, if key == week then 3 else 1.5, if key == week then C.orange else C.shade)
		cell.Parent = row
		local t = Ui.text(cell, got or "🎀", math.floor(size * 0.62), { Size = UDim2.fromScale(1, 1) })
		if not got then t.TextTransparency = 0.4 end
	end
	return row
end

local function coursePicker()
	local h = PlayerState.activeHorse()
	if not h or not h.stalled then
		open("⭐ Training", "Ride your horse round a course!")
		local msg = if h then h.name .. " is out in the pasture. Pick a horse from a stall in My Horses to train!"
			else "Pick your first horse to start training!"
		Ui.text(body, msg, 22, { Size = UDim2.new(1, 0, 0, 60) })
		return
	end
	local sub = if h.trainingReady == false then string.format("%s's training is full this week. Ride for stars!", h.name)
		else string.format("Ride %s round a course · this week %.1f of %d points%s", h.name, h.trainedWeek or 0, Training.WEEKLY_CAP,
			if h.rested then " · Rested ✨" else "")
	open("⭐ Training", sub)
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 276)
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -8, 0, 130)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, key in TrainingCourses.ORDER do
		local c = TrainingCourses.info(key)
		local ready = GameConfig.training.courses[key] == true
		-- Mud Splash (T5): this week's layout; its ribbons show per layout below
		local weekly = ready and key == "grit"
		local ribbon = h.ribbons and RIBBON_EMOJI[h.ribbons[key]] or ""
		local line = if weekly then "This week's course"
			elseif ready then c.label .. (if ribbon ~= "" then "  " .. ribbon else "")
			else "Coming soon"
		local b = Ui.button(grid, "", UDim2.new(), UDim2.new(), if ready then C.cream else C.white, 20)
		b.LayoutOrder = i
		if weekly then
			-- the emoji joins the name so the four ribbon icons have room to be big
			Ui.text(b, c.emoji .. " " .. c.name, 24, { Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 30) })
		else
			Ui.text(b, c.emoji, 44, { Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 50) })
			Ui.text(b, c.name, 24, { Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(1, 0, 0, 30) })
		end
		local l = Ui.text(b, line, 18, { Position = UDim2.new(0, 0, 0, if weekly then 40 else 92), Size = UDim2.new(1, 0, 0, 24) })
		l.TextColor3 = if ready then C.plum else C.shade
		if weekly then layoutRibbons(b, h, 68) end
		b.Activated:Connect(function()
			if not ready then
				Ui.toast(c.name .. " is coming soon!", "stat_" .. key, c.emoji)
				return
			end
			close()
			TrainingState.StartRequested:Fire(key)
		end)
	end
	if GameConfig.training.quickTrain then
		local quick = Ui.button(body, "⚡ Quick train", UDim2.new(0.44, 0, 0, 52), UDim2.new(0.04, 0, 0, 290), C.gold, 22)
		quick.Activated:Connect(quickTrainMenu)
	end
	local together = Ui.button(body, "👫 Ride together", UDim2.new(0.44, 0, 0, 52), UDim2.new(0.52, 0, 0, 290), C.sky, 22)
	together.Activated:Connect(function()
		open("👫 Ride together", "Pick a friend nearby")
		Ui.text(body, "Looking for friends…", 22, { Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 40) })
		gameRemotes:WaitForChild("TrainFriends"):FireServer()
	end)
end

-- The friends you can invite (from the server), then a course for the two of you.
local function inviteCourse(friend)
	open("👫 Ride with " .. friend.name, "Pick a course. " .. friend.name .. " will be asked to join you.")
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 276)
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -8, 0, 130)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, key in TrainingCourses.ORDER do
		local c = TrainingCourses.info(key)
		if GameConfig.training.courses[key] then
			local b = Ui.button(grid, "", UDim2.new(), UDim2.new(), C.cream, 20)
			b.LayoutOrder = i
			Ui.text(b, c.emoji, 44, { Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 50) })
			Ui.text(b, c.name, 24, { Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(1, 0, 0, 30) })
			b.Activated:Connect(function()
				close()
				gameRemotes:WaitForChild("TrainInvite"):FireServer(friend.userId, key)
			end)
		end
	end
end

gameRemotes:WaitForChild("TrainFriendsList").OnClientEvent:Connect(function(list, private)
	if not gui.Enabled or title.Text ~= "👫 Ride together" then return end
	clear()
	if private then
		Ui.text(body, "Your stable visits are set to Nobody, so Ride together is off. A grown-up can change it in Settings.", 20,
			{ Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 80) })
		return
	end
	if typeof(list) ~= "table" or #list == 0 then
		Ui.text(body, "No friends nearby right now. When a Roblox friend is at the paddock or the Training Ground, they'll show here!", 20,
			{ Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 80) })
		return
	end
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 260)
	row.Parent = body
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 10)
	l.Parent = row
	for i, f in list do
		if i > 4 then break end
		local b = Ui.button(row, "🐴 " .. tostring(f.name), UDim2.new(1, 0, 0, 56), UDim2.new(), C.cream, 22)
		b.Activated:Connect(function() inviteCourse(f) end)
	end
end)

local function trainingMenu()
	if GameConfig.training.mode == "rides" then coursePicker() else quickTrainMenu() end
end

local function passport(h)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 90)
	row.Position = UDim2.new(0, 0, 0, 100)
	row.Parent = body
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Padding = UDim.new(0, 8)
	l.Parent = row
	for _, s in Training.STAMPS do
		local got = h.stamps and h.stamps[s]
		local cell = Ui.card(row, UDim2.fromOffset(88, 86), UDim2.new(), if got then C.cream else C.white)
		Ui.icon(cell, "stamp_" .. s, if got then "✅" else "⬜", UDim2.fromOffset(40, 40), UDim2.new(0.5, -20, 0, 6))
		local t = Ui.text(cell, Training.STAMP_LABELS[s], 14, { Position = UDim2.new(0, 2, 0, 48), Size = UDim2.new(1, -4, 0, 34) })
		t.TextColor3 = if got then C.ink else C.shade
	end
	-- The Spa Day stamp (D-058), with how many Spa Days this horse has had.
	local spa = (h.spaDays or 0) > 0
	local cell = Ui.card(row, UDim2.fromOffset(88, 86), UDim2.new(), if spa then C.cream else C.white)
	Ui.text(cell, if spa then "🛁" else "⬜", 30, { Position = UDim2.new(0.5, -20, 0, 6), Size = UDim2.fromOffset(40, 40) })
	local t = Ui.text(cell, Spa.STAMP_LABEL .. (if (h.spaDays or 0) > 1 then " ×" .. h.spaDays else ""), 14,
		{ Position = UDim2.new(0, 2, 0, 48), Size = UDim2.new(1, -4, 0, 34) })
	t.TextColor3 = if spa then C.ink else C.shade
end

-- Spa Day (D-058): hose, brush, towel. Each step is a row of taps on one big button, with the
-- step's chip lit along the top. The server takes it only spa.minSeconds after it started, so a
-- fast tapper sees "All clean!" a moment longer before it's sent.
local function spaGame(h)
	local spaCfg = GameConfig.spa
	local gen = generation
	local started = now()
	gameRemotes:WaitForChild("SpaStart"):FireServer(h.id)
	local a = area(200)
	local horse = Ui.text(a, "🐴", 90, { Size = UDim2.fromOffset(130, 130), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58), TextScaled = true })
	local scale = Instance.new("UIScale")
	scale.Parent = horse
	local fx = Ui.text(a, "", 40, { Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.74, 0.45), TextScaled = true })
	local chips = {}
	for k, step in Spa.STEPS do
		local info = Spa.STEP_TEXT[step]
		local chip = Ui.text(a, info.emoji .. " " .. info.verb, 22, { Size = UDim2.new(1 / 3, -8, 0, 32),
			Position = UDim2.new((k - 1) / 3, 4, 0, 6) })
		chip.TextColor3 = C.shade
		chips[k] = chip
	end
	local stepIdx, taps = 1, 0
	local button: TextButton? = nil
	local function finish()
		for _, chip in chips do chip.TextColor3 = C.green end
		fx.Text = "✨"
		if button then button.Text, button.AutoButtonColor = "All clean! Time to go", false end
		local wait = math.max(0, spaCfg.minSeconds + 0.5 - (now() - started))
		task.delay(wait, function()
			if not alive(gen) then return end
			gameRemotes:WaitForChild("SpaDone"):FireServer(h.id)
			task.delay(0.8, function() if gui.Enabled and generation == gen then close() end end)
		end)
	end
	local function showStep()
		local step = Spa.STEPS[stepIdx]
		for k, chip in chips do chip.TextColor3 = if k < stepIdx then C.green elseif k == stepIdx then C.ink else C.shade end
		fx.Text = Spa.STEP_TEXT[step].emoji
		if button then button.Text = Spa.STEP_TEXT[step].tap end
	end
	button = tapper(function()
		if stepIdx > #Spa.STEPS or not alive(gen) then return end
		local step = Spa.STEPS[stepIdx]
		taps += 1
		if Sound then Sound.play("brush") end
		scale.Scale = 1.12
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 1 }):Play()
		if taps >= (spaCfg.taps[step] or 5) then
			stepIdx += 1
			taps = 0
			if stepIdx > #Spa.STEPS then finish() else showStep() end
		end
	end, Spa.STEP_TEXT.hose.tap)
	showStep()
end

local function spaPick(h)
	local closed = not GameConfig.spa.enabled or (h.spaToday or 0) >= GameConfig.spa.perDay
	local full = (h.energy or 0) >= GameConfig.energy.maxPerRacer
	open("🛁 Spa Day for " .. h.name, if closed then "" elseif full then "Hose, brush and dry!" else "Hose, brush and dry. +1 Energy!")
	if closed then
		Ui.text(body, "🌙 " .. Spa.CLOSED, 26, { Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 40) })
		local ok = Ui.button(body, "OK", UDim2.new(0.3, 0, 0, 56), UDim2.new(0.35, 0, 0, 120), C.green, 24)
		ok.Activated:Connect(close)
		return
	end
	spaGame(h)
end

local function vetMenu(spaOnly: boolean)
	if spaOnly then
		open("🛁 Spa Day", "Pick a horse for a wash and a shine!")
	else
		open("💚 Vet", "Pick a horse: check-up or Spa Day")
	end
	if #stalledHorses() == 0 then
		Ui.text(body, "Pick your first horse first!", 22, { Size = UDim2.new(1, 0, 0, 40) })
		return
	end
	horseRow(function(h)
		if spaOnly then
			spaPick(h)
			return
		end
		open("💚 " .. h.name .. " at the Vet", "Health Passport")
		passport(h)
		local check = Ui.button(body, "🩺 Check-up", UDim2.new(0.44, 0, 0, 60), UDim2.new(0.04, 0, 0, 220), C.green, 26)
		check.Activated:Connect(function()
			open("💚 Check-up for " .. h.name, "Tap with each heartbeat")
			local gen = generation
			heartGame(function(score)
				if not alive(gen) then return end
				gameRemotes:WaitForChild("VetVisit"):FireServer(h.id, score)
				task.delay(0.6, function() if gui.Enabled then close() end end)
			end)
		end)
		local spaOpen = GameConfig.spa.enabled and (h.spaToday or 0) < GameConfig.spa.perDay
		local spa = Ui.button(body, if spaOpen then "🛁 Spa Day" else "🌙 " .. Spa.CLOSED, UDim2.new(0.44, 0, 0, 60),
			UDim2.new(0.52, 0, 0, 220), if spaOpen then C.sky else C.shade, if spaOpen then 26 else 18)
		spa.TextWrapped = true
		spa.Activated:Connect(function()
			if spaOpen then spaPick(h) end
		end)
	end)
end

-- Prompts at the paddock gate and the vet's door -----------------------------------------
local function promptAt(name: string, x: number, z: number, action: string, object: string, fn, reach: number?)
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.new(4, 4, 4)
	anchor.CFrame = CFrame.new(x, 2, z)
	anchor.Parent = workspace
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText = action, object
	p.MaxActivationDistance = reach or 14
	p.RequiresLineOfSight = false
	p.Parent = anchor
	p.Triggered:Connect(fn)
end

local pad = WorldLayout.places.paddock
promptAt("TrainPrompt", pad.x, pad.z + 6, "Train", "Training Paddock", trainingMenu)
-- "Ride" on the picture signs of the courses that are open (D-053).
if GameConfig.training.mode == "rides" then
	for _, sign in TrainingCourses.signs do
		local c = TrainingCourses.info(sign.course)
		if not sign.pointer and GameConfig.training.courses[sign.course] then
			-- in front of the sign, a little toward the path through the middle
			local gateX = WorldLayout.PADDOCK_SOUTH_GATE.x
			local ax = sign.x + sign.lookX * 3 + math.clamp(gateX - sign.x, -6, 6)
			promptAt("Ride_" .. sign.course, ax, sign.z + sign.lookZ * 3, "Ride", c.name, function()
				if gui.Enabled then close() end
				TrainingState.StartRequested:Fire(sign.course)
			end, 18)
		end
	end
end
local vet = WorldLayout.places.vet
promptAt("VetPrompt", vet.x, vet.z + 6, "Check-up", "Vet", function() vetMenu(false) end)
if GameConfig.spa.enabled then -- the wash bay beside the Vet (D-058)
	local sx, sz = WorldLayout.placePoint("vet", WorldLayout.SPA.across, WorldLayout.SPA.out)
	promptAt("SpaPrompt", sx, sz, "Spa Day", "Wash bay", function() vetMenu(true) end)
end

-- Your queued race starting closes the paddock card (the race HUD needs the screen and keys).
game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("Racing"):Connect(function()
	if game:GetService("Players").LocalPlayer:GetAttribute("Racing") and gui.Enabled then close() end
end)
