--!nonstrict
-- RehomeClient (D-059, stage 7): three cards, each one clear thing for an 8-10 year old.
--   Rehome card: at the Market Corral, the Sunny Meadow Riding School sign's prompt lists your
--   horses with what the school pays (half of what you paid; 🏵️ a goodbye rosette for tamed and
--   gifted horses). Two taps: "🏫 Rehome", then "Sure?". The starter, your last racing horse, a
--   Legend and a busy horse say why they stay.
--   Goodbye card: "Comet is joining Sunny Meadow Riding School!", the cash or rosette, and
--   "↩️ Undo" for rehome.undoHours (said in days, never a clock).
--   Legend card: once per horse, when it becomes a Veteran: "👑 Show me" opens My Horses, where
--   the Legend button (two taps) retires it to the Hall of Fame paddock. Never during a race.
-- Text is never under ui.panelMinText and buttons never under ui.panelButtonPx (D-064).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")
local C = Ui.colors
local TEXT = GameConfig.ui.panelMinText
local TAP = GameConfig.ui.panelButtonPx
local SCHOOL = GameConfig.rehome.school
local player = Players.LocalPlayer

local function remote(name: string): RemoteEvent
	return gameRemotes:WaitForChild(name)
end

local function modal(name: string, w: number, h: number)
	local gui = Ui.screen(name, 12)
	gui.Enabled = false
	local dim = Instance.new("TextButton")
	dim.Text, dim.AutoButtonColor = "", false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = C.ink
	dim.BackgroundTransparency = 0.5
	dim.Parent = gui
	local panel = Ui.card(gui, UDim2.fromOffset(w, h), UDim2.new(), C.paper)
	local slide = Ui.fitPanel(panel, w, h, 300)
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = panel
	return gui, panel, body, slide, dim
end

local function dot(parent: Instance, coat: string, px: number, pos: UDim2)
	local d = Instance.new("Frame")
	d.Size = UDim2.fromOffset(px, px)
	d.Position = pos
	d.BackgroundColor3 = Ui.coatColors[coat] or Ui.coatColors.bay
	Ui.corner(d, px // 2)
	Ui.stroke(d, 2)
	d.Parent = parent
	return d
end

-- Rehome card ------------------------------------------------------------------------------------
local RW, RH = 600, 470
local rgui, rpanel, rbody, rslide, rdim = modal("RehomeCard", RW, RH)
local rclose = Ui.button(rpanel, "✕", UDim2.fromOffset(TAP, TAP), UDim2.new(1, -TAP - 8, 0, 6), C.white, 26)
local sure: string? = nil

local function renderRehome()
	if not rgui.Enabled then return end
	rbody:ClearAllChildren()
	local d = PlayerState.data
	if not d then return end
	Ui.text(rbody, "🏫 " .. SCHOOL, 24, { Position = UDim2.new(0, 16, 0, 14), Size = UDim2.new(1, -TAP - 40, 0, 32), TextXAlignment = Enum.TextXAlignment.Left })
	Ui.text(rbody, "Kids there ride and love every horse.", TEXT,
		{ Position = UDim2.new(0, 16, 0, 50), Size = UDim2.new(1, -32, 0, 22), TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
	Ui.text(rbody, string.format("You get half what you paid. Undo for %d days.", GameConfig.rehome.undoHours // 24), TEXT,
		{ Position = UDim2.new(0, 16, 0, 74), Size = UDim2.new(1, -32, 0, 22), TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -24, 1, -112)
	list.Position = UDim2.new(0, 12, 0, 104)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = rbody
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local n = 0
	for _, h in d.horses do
		if not h.legend then
			n += 1
			local row = Ui.card(list, UDim2.new(1, -10, 0, TAP + 16), UDim2.new(), if sure == h.id then C.gold else C.cream)
			row.LayoutOrder = n
			dot(row, h.coat, 40, UDim2.new(0, 10, 0.5, -20))
			local nm = Ui.text(row, h.name, 20, { Position = UDim2.new(0, 60, 0, 6), Size = UDim2.new(1, -250, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			local worth = if h.rehomeBlock then h.rehomeBlock
				elseif (h.rehomeValue or 0) > 0 then string.format("School pays 💵 %d", h.rehomeValue)
				else "🏵️ Goodbye rosette"
			local sub = Ui.text(row, worth, TEXT, { Position = UDim2.new(0, 60, 0, 36), Size = UDim2.new(1, -250, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
			sub.TextColor3 = C.plum
			if not h.rehomeBlock then
				local b = Ui.button(row, if sure == h.id then "Sure? ✓" else "🏫 Rehome", UDim2.fromOffset(170, TAP),
					UDim2.new(1, -180, 0.5, -TAP / 2), if sure == h.id then C.red else C.sky, 18)
				b.Activated:Connect(function()
					if sure == h.id then
						sure = nil
						remote("RehomeHorse"):FireServer(h.id)
						rgui.Enabled = false
					else
						sure = h.id
						renderRehome()
					end
				end)
			else
				Ui.text(row, "❤️ Stays", 18, { Position = UDim2.new(1, -150, 0.5, -14), Size = UDim2.new(0, 140, 0, 28) })
			end
		end
	end
end

local function openRehome()
	if not PlayerState.data or not GameConfig.rehome.enabled then return end
	sure = nil
	rgui.Enabled = true
	rslide()
	renderRehome()
end
rclose.Activated:Connect(function() rgui.Enabled = false end)
rdim.Activated:Connect(function() rgui.Enabled = false end)

-- Goodbye card -----------------------------------------------------------------------------------
local GW, GH = 480, 380
local ggui, _gpanel, gbody, gslide, gdim = modal("GoodbyeCard", GW, GH)

local function showGoodbye(info)
	if not info then
		ggui.Enabled = false
		return
	end
	gbody:ClearAllChildren()
	dot(gbody, info.coat, 64, UDim2.new(0.5, -32, 0, 18))
	Ui.text(gbody, "👋", 40, { Position = UDim2.new(0.5, 30, 0, 14), Size = UDim2.new(0, 50, 0, 50) })
	Ui.text(gbody, string.format("%s is joining %s!", info.name, SCHOOL), 24,
		{ Position = UDim2.new(0, 20, 0, 92), Size = UDim2.new(1, -40, 0, 64), TextWrapped = true })
	Ui.text(gbody, if info.cash > 0 then string.format("+💵 %d Green Cash", info.cash) elseif info.rosette then "🏵️ A goodbye rosette for you" else "Thank you for sharing!", 22,
		{ Position = UDim2.new(0, 20, 0, 164), Size = UDim2.new(1, -40, 0, 30) }).TextColor3 = C.cash
	Ui.text(gbody, string.format("Changed your mind? Undo for %d days.", info.days or 3), TEXT,
		{ Position = UDim2.new(0, 20, 0, 202), Size = UDim2.new(1, -40, 0, 24) }).TextColor3 = C.plum
	local undo = Ui.button(gbody, "↩️ Undo", UDim2.fromOffset(190, TAP), UDim2.new(0.5, -200, 1, -TAP - 18), C.white, 22)
	local ok = Ui.button(gbody, "👍 OK", UDim2.fromOffset(190, TAP), UDim2.new(0.5, 10, 1, -TAP - 18), C.green, 22)
	undo.Activated:Connect(function()
		remote("UndoRehome"):FireServer(info.id)
		ggui.Enabled = false
	end)
	ok.Activated:Connect(function() ggui.Enabled = false end)
	ggui.Enabled = true
	gslide()
end
gdim.Activated:Connect(function() ggui.Enabled = false end)
remote("RehomeResult").OnClientEvent:Connect(showGoodbye)

-- Legend card (once per horse) ------------------------------------------------------------------
local LW, LH = 480, 360
local lgui, _lpanel, lbody, lslide = modal("LegendCard", LW, LH)
local shownFor: { [string]: boolean } = {}

local function showLegend(h)
	shownFor[h.id] = true
	remote("LegendAsked"):FireServer(h.id) -- never suggested again, whatever is tapped
	lbody:ClearAllChildren()
	dot(lbody, h.coat, 64, UDim2.new(0.5, -32, 0, 18))
	Ui.text(lbody, string.format("🎖️ %s is a Veteran!", h.name), 26, { Position = UDim2.new(0, 20, 0, 90), Size = UDim2.new(1, -40, 0, 34) })
	Ui.text(lbody, string.format("%d races! %s can retire as a 👑 Legend.", h.record.races, h.name), TEXT + 2,
		{ Position = UDim2.new(0, 20, 0, 130), Size = UDim2.new(1, -40, 0, 26) })
	Ui.text(lbody, "Legends live in your Hall of Fame paddock. You can still ride them!", TEXT,
		{ Position = UDim2.new(0, 20, 0, 162), Size = UDim2.new(1, -40, 0, 48), TextWrapped = true }).TextColor3 = C.plum
	local show = Ui.button(lbody, "👑 Show me", UDim2.fromOffset(190, TAP), UDim2.new(0.5, -200, 1, -TAP - 18), C.gold, 22)
	local later = Ui.button(lbody, "Not now", UDim2.fromOffset(190, TAP), UDim2.new(0.5, 10, 1, -TAP - 18), C.white, 22)
	show.Activated:Connect(function()
		lgui.Enabled = false
		local ev = HudEvents:FindFirstChild("OpenHorses")
		if ev then ev:Fire() end
	end)
	later.Activated:Connect(function() lgui.Enabled = false end)
	lgui.Enabled = true
	lslide()
end

local pending = false
local function checkLegend()
	if pending or lgui.Enabled or not GameConfig.career.enabled then return end
	local d = PlayerState.data
	if not d then return end
	for _, h in d.horses do
		if h.career and h.career.suggestLegend and not shownFor[h.id] then
			pending = true
			task.spawn(function()
				-- never during a race or its results: wait until you're back in the world
				repeat task.wait(2) until not player:GetAttribute("Racing") and not player:GetAttribute("InLine")
				task.wait(6)
				pending = false
				local now = PlayerState.horse(h.id)
				if now and now.career and now.career.suggestLegend and not shownFor[h.id] then showLegend(now) end
			end)
			return
		end
	end
end

PlayerState.Changed.Event:Connect(function()
	renderRehome()
	checkLegend()
end)
task.defer(checkLegend)

-- The riding school sign's prompt at the corral ------------------------------------------------
local function attach(spot: Instance)
	if not spot:IsA("BasePart") or spot.Name ~= "RehomeSpot" or spot:FindFirstChild("RehomePrompt") then return end
	local p = Instance.new("ProximityPrompt")
	p.Name = "RehomePrompt"
	p.ActionText = "Rehome a horse"
	p.ObjectText = SCHOOL
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Enabled = spot:GetAttribute("Rehome") ~= false
	p.Parent = spot
	p.Triggered:Connect(openRehome)
end

task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	if not world then return end
	local function watch(folder: Instance)
		for _, ch in folder:GetChildren() do attach(ch) end
		folder.ChildAdded:Connect(function(ch) task.defer(attach, ch) end)
	end
	local f = world:FindFirstChild("MarketHorses")
	if f then watch(f) end
	world.ChildAdded:Connect(function(ch)
		if ch.Name == "MarketHorses" then watch(ch) end
	end)
end)
