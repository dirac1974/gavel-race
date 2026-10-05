--!nonstrict
-- StableBoard (D-043): the clipboard button in the dock (and the noticeboard in your barn)
-- opens your board:
--   Top row: one card per stalled horse with what's true right now ("ready to race",
--   "napping", "fed and shiny") and its next step, each with a GO button.
--   Today's jobs: three big cards with a picture, a few words, progress and GO, or Claim when
--   done. When all three are claimed: a sleeping horse and "All done today!".
--   This week / this month: one progress ribbon each. One free reroll a day.
-- No bell, no red badge, no timers. Words state facts about the horse, never guilt.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("WorldLayout"))
local Advice = require(Shared:WaitForChild("Advice"))

local player = Players.LocalPlayer
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors

local gui = Ui.screen("StableBoard", 11)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local W, H = 780, 520
local board = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), Color3.fromHex("F3DDB3")) -- cork-ish
board.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = Instance.new("UIScale")
scale.Parent = board
local function rescale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.min(1, (cam.ViewportSize.X - 20) / W, (cam.ViewportSize.Y - 20) / H) end
end
rescale()
task.spawn(function()
	while not workspace.CurrentCamera do task.wait(0.1) end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end)
Ui.text(board, "📋 Stable Board", 32, { Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 38) })
local closeBtn = Ui.button(board, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 10), C.white, 22)

local horsesRow = Instance.new("ScrollingFrame")
horsesRow.BackgroundTransparency = 1
horsesRow.Size = UDim2.new(1, -32, 0, 150)
horsesRow.Position = UDim2.new(0, 16, 0, 56)
horsesRow.ScrollingDirection = Enum.ScrollingDirection.X
horsesRow.AutomaticCanvasSize = Enum.AutomaticSize.X
horsesRow.CanvasSize = UDim2.new()
horsesRow.ScrollBarThickness = 6
horsesRow.Parent = board
local hl = Instance.new("UIListLayout")
hl.FillDirection = Enum.FillDirection.Horizontal
hl.Padding = UDim.new(0, 10)
hl.Parent = horsesRow

Ui.text(board, "Today's jobs", 22, { Position = UDim2.new(0, 18, 0, 210), Size = UDim2.new(0, 300, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
local reroll = Ui.button(board, "🔀 Swap a job", UDim2.fromOffset(150, 34), UDim2.new(1, -168, 0, 206), C.white, 16)
local jobsRow = Instance.new("Frame")
jobsRow.BackgroundTransparency = 1
jobsRow.Size = UDim2.new(1, -32, 0, 170)
jobsRow.Position = UDim2.new(0, 16, 0, 242)
jobsRow.Parent = board
local jl = Instance.new("UIListLayout")
jl.FillDirection = Enum.FillDirection.Horizontal
jl.Padding = UDim.new(0, 12)
jl.HorizontalAlignment = Enum.HorizontalAlignment.Center
jl.Parent = jobsRow

local ribbons = Instance.new("Frame")
ribbons.BackgroundTransparency = 1
ribbons.Size = UDim2.new(1, -32, 0, 90)
ribbons.Position = UDim2.new(0, 16, 1, -100)
ribbons.Parent = board

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
	if r.stamps then table.insert(bits, "⭐ ×" .. r.stamps) end
	return table.concat(bits, "  ")
end

local function horseCard(h, tip)
	local card = Ui.card(horsesRow, UDim2.fromOffset(230, 140), UDim2.new(), C.paper)
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
	local fact = Ui.text(card, tip.fact, 15, { Position = UDim2.new(0, 64, 0, 32), Size = UDim2.new(1, -70, 0, 36), TextXAlignment = Enum.TextXAlignment.Left })
	fact.TextColor3 = C.plum
	local next = Ui.text(card, tip.next, 16, { Position = UDim2.new(0, 10, 0, 70), Size = UDim2.new(1, -20, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
	next.TextTruncate = Enum.TextTruncate.AtEnd
	if tip.go then
		local go = Ui.button(card, "GO ▶", UDim2.fromOffset(90, 36), UDim2.new(1, -100, 1, -44), C.orange, 18)
		go.Activated:Connect(function() goTo(tip.go) end)
	end
end

local function jobCard(job, index: number)
	local done = job.progress >= job.target
	local card = Ui.card(jobsRow, UDim2.fromOffset(232, 166), UDim2.new(), if job.claimed then C.cream else C.paper)
	Ui.icon(card, job.icon, "⭐", UDim2.fromOffset(46, 46), UDim2.new(0, 10, 0, 10))
	Ui.text(card, job.text, 18, { Position = UDim2.new(0, 62, 0, 8), Size = UDim2.new(1, -70, 0, 50), TextXAlignment = Enum.TextXAlignment.Left })
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -20, 0, 16)
	bar.Position = UDim2.new(0, 10, 0, 66)
	bar.BackgroundColor3 = C.white
	Ui.corner(bar, 8)
	Ui.stroke(bar, 2)
	bar.Parent = card
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(job.progress / job.target, 0.03, 1), 1)
	fill.BackgroundColor3 = if done then C.green else C.gold
	Ui.corner(fill, 8)
	fill.Parent = bar
	Ui.text(card, string.format("%d / %d", job.progress, job.target), 14, { Position = UDim2.new(0, 10, 0, 84), Size = UDim2.new(1, -20, 0, 18) })
	local reward = Ui.text(card, rewardText(job.reward), 14, { Position = UDim2.new(0, 10, 0, 102), Size = UDim2.new(1, -20, 0, 18) })
	reward.TextColor3 = C.cash
	if job.claimed then
		Ui.text(card, "✓ Done!", 22, { Position = UDim2.new(0, 0, 1, -42), Size = UDim2.new(1, 0, 0, 30) }).TextColor3 = C.green
	elseif done then
		local claim = Ui.button(card, "🎁 Claim", UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 1, -46), C.green, 20)
		claim.Activated:Connect(function() gameRemotes:WaitForChild("JobClaim"):FireServer("daily", index) end)
	elseif swapping then
		local swap = Ui.button(card, "🔀 Swap this", UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 1, -46), C.sky, 18)
		swap.Activated:Connect(function()
			swapping = false
			gameRemotes:WaitForChild("JobReroll"):FireServer(index)
		end)
	elseif job.go then
		local go = Ui.button(card, "GO ▶", UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 1, -46), C.orange, 20)
		go.Activated:Connect(function() goTo(job.go) end)
	end
end

local function ribbon(kind: string, label: string, list, y: number)
	local done, total = 0, #list
	local claimable = 0
	for _, j in list do
		if j.claimed then done += 1 elseif j.progress >= j.target then claimable += 1 end
	end
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Position = UDim2.new(0, 0, 0, y)
	row.Parent = ribbons
	Ui.text(row, label, 18, { Size = UDim2.new(0, 130, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -300, 0, 18)
	bar.Position = UDim2.new(0, 130, 0.5, -9)
	bar.BackgroundColor3 = C.white
	Ui.corner(bar, 9)
	Ui.stroke(bar, 2)
	bar.Parent = row
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(done / math.max(1, total), 0.02, 1), 1)
	fill.BackgroundColor3 = C.teal
	Ui.corner(fill, 9)
	fill.Parent = bar
	Ui.text(row, string.format("%d of %d jobs", done, total), 16, { Position = UDim2.new(1, -165, 0, 0), Size = UDim2.new(0, 100, 1, 0) })
	local more = Ui.button(row, if claimable > 0 then "🎁 " .. claimable else "See", UDim2.fromOffset(60, 34), UDim2.new(1, -62, 0.5, -17),
		if claimable > 0 then C.green else C.white, 16)
	more.Activated:Connect(function()
		-- Claim everything ready in this set, or list the jobs in a toast.
		if claimable > 0 then
			gameRemotes:WaitForChild("JobClaim"):FireServer(kind, "all")
		else
			for _, j in list do
				if not j.claimed then Ui.toast(string.format("%s (%d/%d)", j.text, j.progress, j.target), j.icon, "⭐") end
			end
		end
	end)
end

local function render()
	local d = PlayerState.data
	if not d or not gui.Enabled then return end
	for _, c in horsesRow:GetChildren() do if not c:IsA("UIListLayout") then c:Destroy() end end
	for _, c in jobsRow:GetChildren() do if not c:IsA("UIListLayout") then c:Destroy() end end
	for _, c in ribbons:GetChildren() do c:Destroy() end
	local now = workspace:GetServerTimeNow()
	for _, h in d.horses do
		if h.stalled then horseCard(h, Advice.forHorse(h, d, now)) end
	end
	local jobs = d.jobs or {}
	local daily = jobs.daily or {}
	local allClaimed = #daily > 0
	for _, j in daily do if not j.claimed then allClaimed = false end end
	if allClaimed then
		local rest = Ui.card(jobsRow, UDim2.fromOffset(520, 160), UDim2.new(), C.cream)
		Ui.icon(rest, "sleeping_horse", "😴🐴", UDim2.fromOffset(90, 90), UDim2.new(0, 20, 0.5, -45))
		Ui.text(rest, "All done today!", 32, { Position = UDim2.new(0, 120, 0, 30), Size = UDim2.new(1, -130, 0, 40), TextXAlignment = Enum.TextXAlignment.Left })
		local sub = Ui.text(rest, "Your horses are happy. New jobs tomorrow.", 18,
			{ Position = UDim2.new(0, 120, 0, 76), Size = UDim2.new(1, -130, 0, 44), TextXAlignment = Enum.TextXAlignment.Left })
		sub.TextColor3 = C.plum
	else
		for i, j in daily do jobCard(j, i) end
	end
	reroll.Visible = not jobs.rerollUsed and not allClaimed
	reroll.Text = if swapping then "Pick a job to swap" else "🔀 Swap a job"
	ribbon("weekly", "This week", jobs.weekly or {}, 0)
	ribbon("monthly", "This month ⭐" .. tostring(jobs.stamps or 0), jobs.monthly or {}, 46)
end

reroll.Activated:Connect(function()
	swapping = not swapping
	render()
end)

local function open()
	gui.Enabled = true
	swapping = false
	gameRemotes:WaitForChild("BoardOpened"):FireServer() -- the tour's last step
	board.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(board, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	render()
end
local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)

local openEvent = HudEvents:FindFirstChild("OpenBoard")
if not openEvent then
	openEvent = Instance.new("BindableEvent")
	openEvent.Name = "OpenBoard"
	openEvent.Parent = HudEvents
end
openEvent.Event:Connect(function() if gui.Enabled then close() else open() end end)
PlayerState.Changed.Event:Connect(render)

-- The pinned job: the first unfinished job of the day, just above the dock, with GO.
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local pinGui = Ui.screen("PinnedJob", 3)
local pin = Ui.card(pinGui, UDim2.fromOffset(380, 46), UDim2.new(0.5, 0, 1, -104), C.paper)
pin.AnchorPoint = Vector2.new(0.5, 1)
local pinText = Ui.text(pin, "", 18, { Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -110, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
pinText.TextTruncate = Enum.TextTruncate.AtEnd
local pinGo = Ui.button(pin, "GO ▶", UDim2.fromOffset(84, 34), UDim2.new(1, -92, 0.5, -17), C.orange, 18)
local pinned = nil
pinGo.Activated:Connect(function()
	if not pinned then return end
	if pinned.progress >= pinned.target then open() else goTo(pinned.go) end
end)
local function renderPin()
	local d = PlayerState.data
	pinned = nil
	for _, j in (d and d.jobs and d.jobs.daily) or {} do
		if not j.claimed then
			pinned = j
			break
		end
	end
	if pinned then
		local done = pinned.progress >= pinned.target
		pinText.Text = if done then "📌 " .. pinned.text .. " ✓" else string.format("📌 %s  %d/%d", pinned.text, pinned.progress, pinned.target)
		pinGo.Text = if done then "🎁" else "GO ▶"
	end
end
PlayerState.watch(renderPin)
game:GetService("RunService").Heartbeat:Connect(function()
	local racing = RaceState.active and RaceState.myLane ~= nil
	local show = pinned ~= nil and not racing and not gui.Enabled
	if pin.Visible ~= show then pin.Visible = show end
end)
