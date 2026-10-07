--!nonstrict
-- StableBoard (D-043): the 📋 Jobs button in the dock (and the noticeboard in your barn)
-- opens your board:
--   Top row: one card per stalled horse with what's true right now ("ready to race",
--   "napping", "fed and shiny") and its next step, each with a GO button.
--   Jobs, in three tabs you tap (no scrolling, no toasts, D-064 stage 3): Today (three big cards
--   with a picture, a few words, progress and GO, or Claim when done; "All done today!" when all
--   three are claimed), This week and This month (every job inline with its progress, and one
--   "Get prizes" button). One free swap a day.
-- The "Next thing" pill (D-064): one thing to do above the dock, from Advice.nextThing, with GO;
-- Pip gives a hint when you seem stuck.
-- No bell, no red badge, no timers. Words state facts about the horse, never guilt.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Advice = require(Shared:WaitForChild("Advice"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors
local TEXT = GameConfig.ui.panelMinText -- the smallest text on this panel (16)
local TAP = GameConfig.ui.panelButtonPx  -- the smallest button on this panel (64)

local function localEvent(name: string): BindableEvent
	local e = HudEvents:FindFirstChild(name)
	if not e then
		e = Instance.new("BindableEvent")
		e.Name = name
		e.Parent = HudEvents
	end
	return e
end

local gui = Ui.screen("StableBoard", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local W, H = 780, 520
local board = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.new(), Color3.fromHex("F3DDB3")) -- cork-ish
local slideIn = Ui.fitPanel(board, W, H)
Ui.text(board, "📋 Stable Board", 30, { Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 38) })
local closeBtn = Ui.button(board, "✕", UDim2.fromOffset(TAP, TAP), UDim2.new(1, -TAP - 10, 0, 6), C.white, 26)

local horsesRow = Instance.new("ScrollingFrame")
horsesRow.BackgroundTransparency = 1
horsesRow.Size = UDim2.new(1, -32, 0, 160)
horsesRow.Position = UDim2.new(0, 16, 0, 76)
horsesRow.ScrollingDirection = Enum.ScrollingDirection.X
horsesRow.AutomaticCanvasSize = Enum.AutomaticSize.X
horsesRow.CanvasSize = UDim2.new()
horsesRow.ScrollBarThickness = 6
horsesRow.Parent = board
local hl = Instance.new("UIListLayout")
hl.FillDirection = Enum.FillDirection.Horizontal
hl.Padding = UDim.new(0, 10)
hl.Parent = horsesRow

-- Jobs tabs: Today, This week, This month (tap, never scroll).
local tabRow = Instance.new("Frame")
tabRow.BackgroundTransparency = 1
tabRow.Size = UDim2.new(1, -32, 0, TAP)
tabRow.Position = UDim2.new(0, 16, 0, 244)
tabRow.Parent = board
local tl = Instance.new("UIListLayout")
tl.FillDirection = Enum.FillDirection.Horizontal
tl.Padding = UDim.new(0, 8)
tl.SortOrder = Enum.SortOrder.LayoutOrder
tl.Parent = tabRow
local TABS = { { "daily", "📋 Today" }, { "weekly", "📅 Week" }, { "monthly", "🎀 Month" } }
local tabButtons = {}
local tab = "daily"
local render
for k, t in TABS do
	local b = Ui.button(tabRow, t[2], UDim2.fromOffset(160, TAP), UDim2.new(), C.white, 20)
	b.LayoutOrder = k
	tabButtons[t[1]] = b
	b.Activated:Connect(function()
		tab = t[1]
		render()
	end)
end
-- Swap a job (Today) or Get prizes (a week or month set with finished jobs), on the tab row's right.
local actionBtn = Ui.button(board, "🔀 Swap a job", UDim2.fromOffset(210, TAP), UDim2.new(1, -226, 0, 244), C.white, 18)
local jobsArea = Instance.new("Frame")
jobsArea.BackgroundTransparency = 1
jobsArea.Size = UDim2.new(1, -32, 0, 190)
jobsArea.Position = UDim2.new(0, 16, 0, 318)
jobsArea.Parent = board

local swapping = false

local function goTo(go: string?)
	if not go then return end
	gui.Enabled = false
	if go == "stable" then
		local i = player:GetAttribute("PlotIndex")
		if i then
			local x, z = WorldLayout.plotPoint(i, 40, 0)
			Guide.to(x, z)
		end
	elseif go == "raceBoard" then
		local p = WorldLayout.places.raceBoard
		Guide.to(p.x, p.z + 10)
	elseif WorldLayout.places[go] then
		local p = WorldLayout.places[go]
		Guide.to(p.x + p.fx * 12, p.z + p.fz * 12)
	end
	Ui.toast("Follow the golden hoofprints!", "hoofprint", "🐾")
end

local function rewardText(r): string
	local bits = {}
	if r.cash then table.insert(bits, "💵 " .. r.cash) end
	for item, n in r.items or {} do
		local name = (string.gsub(string.gsub(item, "seed_", ""), "_", " "))
		table.insert(bits, string.format("%s ×%d", name, n))
	end
	if r.stamps then table.insert(bits, "🎀 ×" .. r.stamps) end -- 🎀 = monthly stamps (D-064)
	return table.concat(bits, "  ")
end

local function horseCard(h, tip)
	local card = Ui.card(horsesRow, UDim2.fromOffset(250, 150), UDim2.new(), C.paper)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(46, 46)
	dot.Position = UDim2.new(0, 10, 0, 10)
	dot.BackgroundColor3 = Ui.coatColors[h.coat] or Ui.coatColors.bay
	Ui.corner(dot, 23)
	Ui.stroke(dot, 2)
	dot.Parent = card
	Ui.text(dot, tip.emoji, 24, { Size = UDim2.fromScale(1, 1), TextScaled = true })
	local name = Ui.text(card, h.name, 20, { Position = UDim2.new(0, 64, 0, 8), Size = UDim2.new(1, -70, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local fact = Ui.text(card, tip.fact, TEXT, { Position = UDim2.new(0, 64, 0, 32), Size = UDim2.new(1, -70, 0, 40), TextXAlignment = Enum.TextXAlignment.Left })
	fact.TextColor3 = C.plum
	local next = Ui.text(card, string.gsub(tip.next, "^Next: ", ""), TEXT, { Position = UDim2.new(0, 10, 0, 78), Size = UDim2.new(1, if tip.go then -124 else -20, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center })
	next.TextTruncate = Enum.TextTruncate.AtEnd
	if tip.go then
		local go = Ui.button(card, "GO ▶", UDim2.fromOffset(104, TAP), UDim2.new(1, -112, 1, -TAP - 10), C.orange, 20)
		go.Activated:Connect(function() goTo(tip.go) end)
	end
end

local function bar(parent: Instance, frac: number, done: boolean, pos: UDim2, size: UDim2)
	local b = Instance.new("Frame")
	b.Size, b.Position = size, pos
	b.BackgroundColor3 = C.white
	Ui.corner(b, 8)
	Ui.stroke(b, 2)
	b.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(frac, 0.03, 1), 1)
	fill.BackgroundColor3 = if done then C.green else C.gold
	Ui.corner(fill, 8)
	fill.Parent = b
end

local function jobCard(parent: Instance, job, index: number)
	local done = job.progress >= job.target
	local card = Ui.card(parent, UDim2.fromOffset(236, 186), UDim2.new(), if job.claimed then C.cream else C.paper)
	Ui.icon(card, job.icon, "📋", UDim2.fromOffset(46, 46), UDim2.new(0, 10, 0, 10))
	Ui.text(card, job.text, 18, { Position = UDim2.new(0, 62, 0, 8), Size = UDim2.new(1, -70, 0, 50), TextXAlignment = Enum.TextXAlignment.Left })
	bar(card, job.progress / job.target, done, UDim2.new(0, 10, 0, 64), UDim2.new(1, -86, 0, 16))
	Ui.text(card, string.format("%d/%d", job.progress, job.target), TEXT, { Position = UDim2.new(1, -72, 0, 61), Size = UDim2.new(0, 64, 0, 22) })
	local reward = Ui.text(card, rewardText(job.reward), TEXT, { Position = UDim2.new(0, 10, 0, 86), Size = UDim2.new(1, -20, 0, 22) })
	reward.TextColor3 = C.cash
	reward.TextTruncate = Enum.TextTruncate.AtEnd
	local foot = UDim2.new(0, 10, 1, -TAP - 10)
	if job.claimed then
		Ui.text(card, "✓ Done!", 22, { Position = UDim2.new(0, 0, 1, -50), Size = UDim2.new(1, 0, 0, 30) }).TextColor3 = C.green
	elseif done then
		local claim = Ui.button(card, "🎁 Claim", UDim2.new(1, -20, 0, TAP), foot, C.green, 20)
		claim.Activated:Connect(function()
			gameRemotes:WaitForChild("JobClaim"):FireServer("daily", index)
			if Sound then Sound.play("job_done") end
		end)
		claim:SetAttribute("NoPop", true)
	elseif swapping then
		local swap = Ui.button(card, "🔀 Swap this", UDim2.new(1, -20, 0, TAP), foot, C.sky, 18)
		swap.Activated:Connect(function()
			swapping = false
			gameRemotes:WaitForChild("JobReroll"):FireServer(index)
		end)
	elseif job.go then
		local go = Ui.button(card, "GO ▶", UDim2.new(1, -20, 0, TAP), foot, C.orange, 20)
		go.Activated:Connect(function() goTo(job.go) end)
	end
end

-- A week or month job, inline (no toasts): picture, words, progress.
local function jobChip(parent: Instance, job, order: number)
	local done = job.progress >= job.target
	local chip = Ui.card(parent, UDim2.new(), UDim2.new(), if job.claimed then C.cream elseif done then Color3.fromHex("DDF5DF") else C.paper)
	chip.LayoutOrder = order
	Ui.icon(chip, job.icon, "📋", UDim2.fromOffset(40, 40), UDim2.new(0, 8, 0, 8))
	local text = Ui.text(chip, job.text, TEXT, { Position = UDim2.new(0, 54, 0, 4), Size = UDim2.new(1, -60, 0, 44), TextXAlignment = Enum.TextXAlignment.Left })
	text.TextTruncate = Enum.TextTruncate.AtEnd
	if job.claimed then
		Ui.text(chip, "✓ Done!", TEXT, { Position = UDim2.new(0, 10, 0, 54), Size = UDim2.new(1, -20, 0, 22) }).TextColor3 = C.green
	else
		bar(chip, job.progress / job.target, done, UDim2.new(0, 10, 0, 58), UDim2.new(1, -86, 0, 14))
		Ui.text(chip, if done then "🎁" else string.format("%d/%d", job.progress, job.target), TEXT,
			{ Position = UDim2.new(1, -72, 0, 54), Size = UDim2.new(0, 64, 0, 22) })
	end
end

local function claimable(list): number
	local n = 0
	for _, j in list do
		if not j.claimed and j.progress >= j.target then n += 1 end
	end
	return n
end

render = function()
	local d = PlayerState.data
	if not d or not gui.Enabled then return end
	for _, c in horsesRow:GetChildren() do if not c:IsA("UIListLayout") then c:Destroy() end end
	jobsArea:ClearAllChildren()
	local now = workspace:GetServerTimeNow()
	for _, h in d.horses do
		if h.stalled then horseCard(h, Advice.forHorse(h, d, now)) end
	end
	local jobs = d.jobs or {}
	-- Tabs: the picked one gold; a 🎁 on a tab with prizes waiting.
	for _, t in TABS do
		local b = tabButtons[t[1]]
		local n = claimable(jobs[t[1]] or {})
		b.BackgroundColor3 = if tab == t[1] then C.gold else C.white
		-- This month's stamps toward its cloth (D-063): "🎀 Month 6/8"
		local label = if t[1] == "monthly"
			then string.format("%s %d/%d", t[2], math.min(jobs.monthStamps or 0, jobs.stampsNeeded or 8), jobs.stampsNeeded or 8)
			else t[2]
		b.Text = if n > 0 and tab ~= t[1] then label .. " 🎁" else label
	end
	local list = jobs[tab] or {}
	if tab == "daily" then
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 1)
		row.Parent = jobsArea
		local jl = Instance.new("UIListLayout")
		jl.FillDirection = Enum.FillDirection.Horizontal
		jl.Padding = UDim.new(0, 12)
		jl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		jl.Parent = row
		local allClaimed = #list > 0
		for _, j in list do if not j.claimed then allClaimed = false end end
		if allClaimed then
			local rest = Ui.card(row, UDim2.fromOffset(520, 170), UDim2.new(), C.cream)
			Ui.icon(rest, "sleeping_horse", "😴🐴", UDim2.fromOffset(90, 90), UDim2.new(0, 20, 0.5, -45))
			Ui.text(rest, "All done today!", 32, { Position = UDim2.new(0, 120, 0, 30), Size = UDim2.new(1, -130, 0, 40), TextXAlignment = Enum.TextXAlignment.Left })
			local sub = Ui.text(rest, "Your horses are happy. New jobs tomorrow.", 18,
				{ Position = UDim2.new(0, 120, 0, 76), Size = UDim2.new(1, -130, 0, 44), TextXAlignment = Enum.TextXAlignment.Left })
			sub.TextColor3 = C.plum
		else
			for i, j in list do jobCard(row, j, i) end
		end
		actionBtn.Visible = not jobs.rerollUsed and not allClaimed
		actionBtn.Text = if swapping then "Pick one to swap" else "🔀 Swap a job"
		actionBtn.BackgroundColor3 = if swapping then C.sky else C.white
	else
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(1 / 3, -6, 0, 88)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = jobsArea
		for k, j in list do jobChip(jobsArea, j, k) end
		local n = claimable(list)
		actionBtn.Visible = n > 0
		actionBtn.Text = string.format("🎁 Get %d prize%s", n, if n == 1 then "" else "s")
		actionBtn.BackgroundColor3 = C.green
	end
end

actionBtn.Activated:Connect(function()
	if tab == "daily" then
		swapping = not swapping
		render()
	else
		gameRemotes:WaitForChild("JobClaim"):FireServer(tab, "all")
		if Sound then Sound.play("job_done") end
	end
end)

local function open()
	gui.Enabled = true
	swapping = false
	gameRemotes:WaitForChild("BoardOpened"):FireServer() -- the tour's last step
	slideIn()
	render()
end
local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)

localEvent("OpenBoard").Event:Connect(function() if gui.Enabled then close() else open() end end)
PlayerState.Changed.Event:Connect(function() render() end)

-- The Next-thing pill (D-064, stage 3): one suggestion just above the dock, icon + a few words +
-- GO. It replaces the pinned job (the pill picks the job when a job is the next thing).
local NEXT = GameConfig.nextThing or { enabled = true, pipHintSeconds = 20, stillStuds = 6 }
local LAYOUT = GameConfig.touchLayout
local pinGui = Ui.screen("NextThing", 3)
pinGui.Enabled = NEXT.enabled ~= false
local PILL_H = GameConfig.ui.minTouchPx + 8
local pill = Ui.card(pinGui, UDim2.fromOffset(440, PILL_H), UDim2.new(0.5, 0, 1, -100), C.paper)
pill.AnchorPoint = Vector2.new(0.5, 1)
local pillIcon = Ui.icon(pill, "clipboard", "📋", UDim2.fromOffset(40, 40), UDim2.new(0, 10, 0.5, -20))
local pillText = Ui.text(pill, "", 20, { Position = UDim2.new(0, 58, 0, 0), Size = UDim2.new(1, -176, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
pillText.TextTruncate = Enum.TextTruncate.AtEnd
local pillGo = Ui.button(pill, "GO ▶", UDim2.fromOffset(108, GameConfig.ui.minTouchPx), UDim2.new(1, -114, 0.5, -GameConfig.ui.minTouchPx / 2), C.orange, 22)
local pipBubble = Ui.card(pinGui, UDim2.fromOffset(0, 48), UDim2.new(0.5, 0, 1, -100 - PILL_H - 8), C.cream)
pipBubble.AnchorPoint = Vector2.new(0.5, 1)
pipBubble.AutomaticSize = Enum.AutomaticSize.X
pipBubble.Visible = false
local pipPad = Ui.pad(pipBubble, 8)
pipPad.PaddingLeft, pipPad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
Ui.text(pipBubble, "🐴 " .. Advice.PIP_HINT, 18, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false })

local current = nil
local inLine = false
local shownAt, hinted = 0, false
local function placePill()
	local cam = workspace.CurrentCamera
	local touch = Ui.touchLayout()
	-- On touch the pill sits left, clear of Hop and Gallop (like the dock).
	local width = 440
	if cam and touch then width = math.min(440, cam.ViewportSize.X - 24 - LAYOUT.movementColumn) end
	pill.Size = UDim2.fromOffset(math.max(260, width), PILL_H)
	pill.AnchorPoint = if touch then Vector2.new(0, 1) else Vector2.new(0.5, 1)
	pill.Position = if touch then UDim2.new(0, 12, 1, -100) else UDim2.new(0.5, 0, 1, -100)
	pipBubble.AnchorPoint = pill.AnchorPoint
	pipBubble.Position = if touch then UDim2.new(0, 12, 1, -100 - PILL_H - 8) else UDim2.new(0.5, 0, 1, -100 - PILL_H - 8)
end
placePill()
Ui.TouchChanged.Event:Connect(placePill)
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placePill)
	placePill()
end)

local function renderPill()
	local d = PlayerState.data
	if not d then
		current = nil
		return
	end
	local nxt = Advice.nextThing(d, workspace:GetServerTimeNow())
	if inLine and nxt.go == "race" then -- already waiting for a race: nothing to press
		nxt = { key = "inline", emoji = "🏁", icon = "flag_ready", text = "You're in line. Race soon!", go = nil }
	end
	if not current or current.key ~= nxt.key then
		shownAt, hinted = os.clock(), false
		pipBubble.Visible = false
	end
	current = nxt
	pillIcon:Destroy()
	pillIcon = Ui.icon(pill, nxt.icon, nxt.emoji, UDim2.fromOffset(40, 40), UDim2.new(0, 10, 0.5, -20))
	pillText.Text = nxt.text
	pillGo.Visible = nxt.go ~= nil
	pillText.Size = UDim2.new(1, if nxt.go then -176 else -68, 1, 0)
end
PlayerState.watch(renderPill)
ReplicatedStorage:WaitForChild("RaceRemotes"):WaitForChild("QueueStatus").OnClientEvent:Connect(function(isIn)
	inLine = isIn == true
	renderPill()
end)

pillGo.Activated:Connect(function()
	if not current or not current.go then return end
	pipBubble.Visible = false
	local go = current.go
	if go == "board" then
		-- open on the first tab with a prize waiting
		local jobs = (PlayerState.data and PlayerState.data.jobs) or {}
		for _, t in TABS do
			if claimable(jobs[t[1]] or {}) > 0 then
				tab = t[1]
				break
			end
		end
		open()
	elseif go == "race" then
		localEvent("PressRace"):Fire()
	elseif go == "starter" then
		localEvent("OpenStarter"):Fire()
	else
		goTo(go)
	end
end)

-- Pip's hint: the same suggestion for pipHintSeconds and you haven't moved in that time.
local lastMovedAt, anchor = os.clock(), nil
local nextCheck = 0
local lastPillAt = 0
RunService.Heartbeat:Connect(function()
	local racing = RaceState.active and RaceState.myLane ~= nil
	local replay = player.PlayerGui:FindFirstChild("ReplayUI")
	local more = player.PlayerGui:FindFirstChild("DockMore")
	local show = current ~= nil and not racing and not gui.Enabled and not RaceState.resultsOpen
		and not (replay and replay.Enabled) and not (more and more.Enabled)
	if pill.Visible ~= show then pill.Visible = show end
	if not show then
		if pipBubble.Visible then pipBubble.Visible = false end
		return
	end
	local now = os.clock()
	if now < nextCheck then return end
	nextCheck = now + 0.5
	if now - lastPillAt > 5 then -- time-based suggestions (crops ready) show without a data change
		lastPillAt = now
		renderPill()
		if not current then return end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		if not anchor or (root.Position - anchor).Magnitude > NEXT.stillStuds then
			anchor = root.Position
			lastMovedAt = now
		end
	end
	if current.go and Advice.pipHintDue(shownAt, lastMovedAt, hinted, now, NEXT) then
		hinted = true
		pipBubble.Visible = true
		Ui.pop(pill)
		task.delay(6, function() pipBubble.Visible = false end)
	end
end)
