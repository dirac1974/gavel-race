--!nonstrict
-- PaddockClient (D-039, D-040, D-053): the training picker at the Training Paddock and the
-- heartbeat check-up at the Vet.
--   Train (D-053): four picture tiles for the ride-through courses on your active horse
--     (Sprint Lane and Mud Splash now; Gate Break and Hill Climb "Coming soon"), plus "Quick
--     train" for the old games. Picking a course (here or at its picture sign's "Ride" prompt)
--     asks TrainingRideClient to start it. GameConfig.training.mode = "meters" shows only the
--     games, as before D-053.
--   Quick train: pick a horse and a stat, play a 10-second game, the server adds the gain
--   (still client-scored until T4; the server caps its quality).
--     Sprint Lane (Speed): tap as the runner crosses each glowing zone.
--     Gate Break (Acceleration): wait for green, then tap fast.
--     Hill Climb (Stamina): hold to keep the marker in the moving green band.
--     Mud Splash (Grit): tap as each puddle reaches the hoof.
--   Vet: tap with each heartbeat; collect Health Passport stamps (one a day).
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
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TrainingCourses = require(Shared:WaitForChild("TrainingCourses"))
local TrainingState = require(script.Parent:WaitForChild("TrainingState"))

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
local function close()
	clear()
	gui.Enabled = false
end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)
local function open(t: string, s: string)
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

-- Games: each calls done(score 0..100) -----------------------------------------------------
local Games = {}

function Games.speed(done)
	local a = area(170)
	local lane = Instance.new("Frame")
	lane.Size = UDim2.new(1, -40, 0, 30)
	lane.Position = UDim2.new(0, 20, 0.5, -15)
	lane.BackgroundColor3 = Color3.fromHex("D9B98A")
	Ui.corner(lane, 15)
	lane.Parent = a
	local zone = Instance.new("Frame")
	zone.Size = UDim2.new(0.12, 0, 1, 10)
	zone.AnchorPoint = Vector2.new(0.5, 0.5)
	zone.BackgroundColor3 = C.gold
	zone.BackgroundTransparency = 0.15
	Ui.corner(zone, 8)
	zone.Parent = lane
	local runner = Ui.text(lane, "🐎", 34, { Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), TextScaled = true })
	local rounds, total, round = 5, 0, 0
	local x, dir, speed = 0, 1, 0.55
	local center = 0.5
	local rng = Random.new()
	local function nextRound()
		round += 1
		if round > rounds then
			done(total / rounds)
			return false
		end
		center = rng:NextNumber(0.15, 0.85)
		zone.Position = UDim2.fromScale(center, 0.5)
		speed = 0.55 + round * 0.1
		return true
	end
	nextRound()
	local tapped = false
	heartbeat(function(dt)
		x += dir * speed * dt
		if x >= 1 then x, dir = 1, -1 elseif x <= 0 then x, dir = 0, 1 end
		runner.Position = UDim2.fromScale(x, 0.5)
	end)
	tapper(function()
		if tapped then return end
		local err = math.abs(x - center) / 0.06 -- zone half-width
		local s = math.clamp(100 * (1 - math.max(0, err - 1) * 0.5 - (if err > 1 then 0.2 else 0)), 0, 100)
		if err <= 1 then s = 100 - err * 15 end
		total += s
		flash(label(s), if s >= 75 then C.green else C.orangeDark)
		tapped = true
		local gen = generation
		task.delay(0.25, function()
			if not alive(gen) then return end
			tapped = false
			nextRound()
		end)
	end)
end

function Games.accel(done)
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
	local rounds, total, round = 3, 0, 0
	local greenAt: number? = nil
	local waiting = false
	local rng = Random.new()
	local function startRound()
		round += 1
		if round > rounds then
			done(total / rounds)
			return
		end
		light.BackgroundColor3, greenAt, waiting = C.red, nil, true
		text.Text = "Wait for green…"
		local delayS = rng:NextNumber(1.2, 3)
		local gen = generation
		task.delay(delayS, function()
			if waiting and alive(gen) then
				greenAt = now()
				light.BackgroundColor3 = C.green
				text.Text = "GO!"
			end
		end)
	end
	startRound()
	tapper(function()
		if not waiting then return end
		if not greenAt then
			flash("Too soon!", C.red) -- that round counts as 0, gently
			waiting = false
			local gen = generation
			task.delay(0.8, function() if alive(gen) then startRound() end end)
			return
		end
		local rt = now() - greenAt
		local s = math.clamp(100 - (rt - 0.22) / (0.8 - 0.22) * 70, 30, 100)
		total += s
		waiting = false
		flash(string.format("%.2fs %s", rt, label(s)), if s >= 75 then C.green else C.orangeDark)
		local gen = generation
		task.delay(0.9, function() if alive(gen) then startRound() end end)
	end)
end

function Games.stamina(done)
	local a = area(220)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 60, 1, -30)
	track.Position = UDim2.new(0.5, -30, 0, 15)
	track.BackgroundColor3 = C.white
	Ui.corner(track, 14)
	Ui.stroke(track, 2)
	track.Parent = a
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0.26, 0)
	band.BackgroundColor3 = C.green
	band.BackgroundTransparency = 0.25
	Ui.corner(band, 10)
	band.Parent = track
	local marker = Ui.text(track, "🐎", 30, { Size = UDim2.new(1, 0, 0, 34), AnchorPoint = Vector2.new(0, 0.5), TextScaled = true })
	local time = Ui.text(a, "", 20, { Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 160, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	local holding = false
	local y, vy = 0.5, 0      -- marker height 0 (bottom) .. 1 (top)
	local bandC, t, inside, duration = 0.5, 0, 0, 8
	tapper(function() holding = true end, "HOLD", function() holding = false end)
	local finished = false
	heartbeat(function(dt)
		if finished then return end
		t += dt
		bandC = 0.5 + 0.3 * math.sin(t * 0.9) * math.sin(t * 0.37 + 1)
		vy += (if holding then 1.6 else -1.4) * dt
		vy = math.clamp(vy, -0.9, 0.9)
		y = math.clamp(y + vy * dt, 0, 1)
		if y == 0 or y == 1 then vy = 0 end
		band.Position = UDim2.fromScale(0, 1 - bandC - 0.13)
		marker.Position = UDim2.fromScale(0, 1 - y)
		local inBand = math.abs(y - bandC) <= 0.13
		if inBand then inside += dt end
		band.BackgroundColor3 = if inBand then C.green else C.gold
		time.Text = string.format("⏱ %.1f s", math.max(0, duration - t))
		if t >= duration then
			finished = true
			done(math.clamp(inside / duration * 110, 0, 100))
		end
	end)
end

function Games.grit(done)
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
	local beats, interval, travel = 8, 0.75, 1.6
	local start = now() + 1
	local puddles = {}
	for k = 1, beats do
		local p = Ui.text(a, "💦", 34, { Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), TextScaled = true })
		p.Position = UDim2.new(1, 40, 0.5, 0)
		puddles[k] = { label = p, at = start + (k - 1) * interval + travel, scored = false }
	end
	local total, finished = 0, false
	heartbeat(function()
		local t = now()
		local width = a.AbsoluteSize.X
		for _, p in puddles do
			local f = (p.at - t) / travel -- 1 when it appears, 0 at the hoof
			p.label.Position = UDim2.new(0, 70 + f * (width - 70), 0.5, 0)
			p.label.Visible = f <= 1.05 and f >= -0.2 and not p.scored
			if not p.scored and t > p.at + 0.25 then
				p.scored = true -- missed
			end
		end
		if not finished and t > puddles[beats].at + 0.4 then
			finished = true
			done(total / beats)
		end
	end)
	tapper(function()
		local t = now()
		local best, bestErr = nil, math.huge
		for _, p in puddles do
			if not p.scored and math.abs(t - p.at) < bestErr then best, bestErr = p, math.abs(t - p.at) end
		end
		if best and bestErr <= 0.25 then
			best.scored = true
			local s = math.clamp(100 - (bestErr - 0.04) / 0.21 * 70, 30, 100)
			total += s
			flash(label(s), if s >= 75 then C.green else C.orangeDark)
		end
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
		local b = Ui.button(row, h.name, UDim2.fromOffset(170, 80), UDim2.new(), Ui.coatColors[h.coat] or C.cream, 20)
		b.TextColor3 = if h.coat == "black" or h.coat == "bay" or h.coat == "chestnut" then C.white else C.ink
		b.Activated:Connect(function() onPick(h) end)
	end
	return row
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
		Games[stat](function(score)
			if not alive(gen) then return end
			clear()
			Ui.text(body, label(score), 44, { Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 54) }).TextColor3 = C.orangeDark
			Ui.text(body, string.format("Score %d", math.floor(score + 0.5)), 24, { Position = UDim2.new(0, 0, 0, 100), Size = UDim2.new(1, 0, 0, 30) })
			gameRemotes:WaitForChild("Train"):FireServer(h.id, stat, score)
			local again = Ui.button(body, "Done", UDim2.new(0.4, 0, 0, 56), UDim2.new(0.3, 0, 0, 170), C.green, 24)
			again.Activated:Connect(close)
		end)
	end)
end

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
local function coursePicker()
	local h = PlayerState.activeHorse()
	if not h or not h.stalled then
		open("⭐ Training", "Ride your horse round a course!")
		Ui.text(body, "Pick your first horse to start training!", 22, { Size = UDim2.new(1, 0, 0, 40) })
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
		local c = TrainingCourses.courses[key]
		local ready = GameConfig.training.courses[key] == true
		local ribbon = h.ribbons and RIBBON_EMOJI[h.ribbons[key]] or ""
		local line = if ready then c.label .. (if ribbon ~= "" then "  " .. ribbon else "") else "Coming soon"
		local b = Ui.button(grid, "", UDim2.new(), UDim2.new(), if ready then C.cream else C.white, 20)
		b.LayoutOrder = i
		Ui.text(b, c.emoji, 44, { Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 50) })
		Ui.text(b, c.name, 24, { Position = UDim2.new(0, 0, 0, 60), Size = UDim2.new(1, 0, 0, 30) })
		local l = Ui.text(b, line, 18, { Position = UDim2.new(0, 0, 0, 92), Size = UDim2.new(1, 0, 0, 24) })
		l.TextColor3 = if ready then C.plum else C.shade
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
		local quick = Ui.button(body, "⚡ Quick train", UDim2.new(0.5, 0, 0, 52), UDim2.new(0.25, 0, 0, 290), C.gold, 22)
		quick.Activated:Connect(quickTrainMenu)
	end
end

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
		local cell = Ui.card(row, UDim2.fromOffset(104, 86), UDim2.new(), if got then C.cream else C.white)
		Ui.icon(cell, "stamp_" .. s, if got then "✅" else "⬜", UDim2.fromOffset(40, 40), UDim2.new(0.5, -20, 0, 6))
		local t = Ui.text(cell, Training.STAMP_LABELS[s], 13, { Position = UDim2.new(0, 2, 0, 48), Size = UDim2.new(1, -4, 0, 34) })
		t.TextColor3 = if got then C.ink else C.shade
	end
end

local function vetMenu()
	open("💚 Vet check-up", "Listen to the heartbeat. Collect Health Passport stamps!")
	if #stalledHorses() == 0 then
		Ui.text(body, "Pick your first horse first!", 22, { Size = UDim2.new(1, 0, 0, 40) })
		return
	end
	horseRow(function(h)
		open("💚 Check-up for " .. h.name, "Tap with each heartbeat")
		passport(h)
		local go = Ui.button(body, "🩺 Start", UDim2.new(0.4, 0, 0, 60), UDim2.new(0.3, 0, 0, 220), C.green, 26)
		go.Activated:Connect(function()
			clear()
			local gen = generation
			heartGame(function(score)
				if not alive(gen) then return end
				gameRemotes:WaitForChild("VetVisit"):FireServer(h.id, score)
				task.delay(0.6, function() if gui.Enabled then close() end end)
			end)
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
		local c = TrainingCourses.courses[sign.course]
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
promptAt("VetPrompt", vet.x, vet.z + 6, "Check-up", "Vet", vetMenu)

-- Your queued race starting closes the paddock card (the race HUD needs the screen and keys).
game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("Racing"):Connect(function()
	if game:GetService("Players").LocalPlayer:GetAttribute("Racing") and gui.Enabled then close() end
end)
