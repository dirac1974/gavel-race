--!nonstrict
-- BreedingClient (D-080 provisional): the 💞 Foal Barn panel, meeting your foal, naming it, and the
-- one-time "🍼 Comet's foal!" moment. The server decides everything (BreedingService); this only shows.
--   Opens from the barn's door prompt and from GO (GoTo "foalBarn": the Map's 14th tile).
--   Two steps (UI/UX vote), each fitting a phone without scrolling (Ui.fitPanel 640 x 400, 16 px / 64 px):
--     "Pick two parents": two slots over a list of your horses; the ones that can't be parents now are
--       greyed with the server's short reason ("Needs 30 races", "Lent", "Out riding").
--     "Your foal": the family line (🌱 sprouts, never numbers), the Coat chances box (3 rows: swatch,
--       name, bar, %; the word is always "chance"), the fee in Green Cash, and a two-tap confirm.
--   Waiting: "Arrives in 5 races or tomorrow". Counted in races, never a clock.
--   Meeting (the feel vote F1, F5): the parent stands in the paddock; the foal steps out from behind its
--     flank, turns to it and nuzzles twice; hearts rise; the foal's nicker at 1.45, the parent answers
--     at 0.9. No confetti, no newborn scene; a Surprise coat gets one line and no bigger party.
--     Reduced Motion: a fade-in beside the parent, the hearts kept. Any tap skips after 1 s.
--   Naming copies the Starter's step 2: word chips, "🔀 New words", "That's the name!".
-- STATUS: written without Studio access; verify in Studio before relying on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local GoTo = require(script.Parent:WaitForChild("GoTo"))
local RaceState = require(script.Parent:WaitForChild("RaceState"))
local okSound, Sound = pcall(require, script.Parent:WaitForChild("Sound", 5))
if not okSound then Sound = nil end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Breeding = require(Shared:WaitForChild("Breeding"))
local NameGen = require(Shared:WaitForChild("NameGen"))
local HorseLook = require(Shared:WaitForChild("HorseLook"))
local HorseBook = require(Shared:WaitForChild("HorseBook"))
local Ageing = require(Shared:WaitForChild("Ageing"))
local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local HudEvents = ReplicatedStorage:WaitForChild("HudEvents")

local B = GameConfig.breeding
local F = GameConfig.foalLook
local C = Ui.colors
local TEXT = 16
local TAP = 64
local player = Players.LocalPlayer
local ICON, EMOJI, SURPRISE = B.icon or "family", "💞", "❔"

local function remote(name: string): RemoteEvent
	return gameRemotes:WaitForChild(name)
end

local function calm(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

local function busy(): boolean
	return player:GetAttribute("Racing") == true or player:GetAttribute("InLine") == true
		or RaceState.resultsOpen == true or (RaceState.active and RaceState.myLane ~= nil)
end

local function coatWord(coat: string?): string
	return HorseBook.COAT_LABELS[coat or ""] or "Bay"
end

local function swatch(parent: Instance, coat: string?, px: number, pos: UDim2)
	local d = Instance.new("Frame")
	d.Size = UDim2.fromOffset(px, px)
	d.Position = pos
	d.BackgroundColor3 = Ui.coatColors[coat or ""] or C.shade
	Ui.corner(d, px // 2)
	Ui.stroke(d, 2)
	d.Parent = parent
	return d
end

-- The panel ---------------------------------------------------------------------------------------
local W, H = 640, 400
local gui = Ui.screen("FoalBarn", 12)
gui.Enabled = false
local dim = Instance.new("TextButton")
dim.Text, dim.AutoButtonColor = "", false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = C.ink
dim.BackgroundTransparency = 0.5
dim.Parent = gui
local panel = Ui.card(gui, UDim2.fromOffset(W, H), UDim2.new(), C.paper)
local slide = Ui.fitPanel(panel, W, H, nil, TEXT, TAP)
local closeBtn = Ui.closeButton(panel, UDim2.new(1, -TAP - 8, 0, 6), TAP)
Ui.icon(panel, ICON, EMOJI, UDim2.fromOffset(40, 40), UDim2.new(0, 14, 0, 14))
local title = Ui.text(panel, "Pick two parents", 26, { Position = UDim2.new(0, 62, 0, 14), Size = UDim2.new(1, -150, 0, 36),
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, -24, 1, -64)
body.Position = UDim2.new(0, 12, 0, 60)
body.Parent = panel

local step = "pick" -- "pick" | "foal" | "wait" | "here" | "closed"
local picks: { string? } = { nil, nil }
local preview: any = nil -- the server's BreedPreviewResult for the current pair
local sure = false       -- the confirm asked once

local render

local function close()
	gui.Enabled = false
	sure = false
end
closeBtn.Activated:Connect(close)
dim.Activated:Connect(close)

local function horses(): { any }
	local d = PlayerState.data
	return if d then d.horses else {}
end

local function horseById(id: string?): any
	return id and PlayerState.horse(id)
end

local function breeding(): any
	local d = PlayerState.data
	return d and d.breeding
end

local function clear()
	for _, ch in body:GetChildren() do ch:Destroy() end
end

local function line(text: string, y: number, size: number?, colour: Color3?): TextLabel
	local l = Ui.text(body, text, size or 20, { Position = UDim2.new(0, 8, 0, y), Size = UDim2.new(1, -16, 0, (size or 20) + 10) })
	if colour then l.TextColor3 = colour end
	return l
end

-- Step 1: Pick two parents -------------------------------------------------------------------------
local function slotCard(k: number, x: UDim)
	local id = picks[k]
	local h = horseById(id)
	local card = Ui.button(body, "", UDim2.fromOffset(200, 120), UDim2.new(x, UDim.new(0, 0)), if h then C.cream else C.white, 18)
	if h then
		swatch(card, h.coat, 44, UDim2.new(0.5, -22, 0, 12))
		local n = Ui.text(card, h.name, 18, { Position = UDim2.new(0, 6, 0, 62), Size = UDim2.new(1, -12, 0, 24), TextWrapped = false })
		n.TextTruncate = Enum.TextTruncate.AtEnd
		Ui.text(card, "Tap to change", TEXT, { Position = UDim2.new(0, 6, 0, 88), Size = UDim2.new(1, -12, 0, 22) }).TextColor3 = C.plum
	else
		Ui.text(card, if k == 1 then "Parent 1" else "Parent 2", 20, { Position = UDim2.new(0, 6, 0, 30), Size = UDim2.new(1, -12, 0, 28) })
		Ui.text(card, "Tap a horse below", TEXT, { Position = UDim2.new(0, 6, 0, 64), Size = UDim2.new(1, -12, 0, 22) }).TextColor3 = C.plum
	end
	card.Activated:Connect(function()
		picks[k] = nil
		render()
	end)
end

local function renderPick()
	title.Text = "Pick two parents"
	local b = breeding() or {}
	slotCard(1, UDim.new(0, 8))
	slotCard(2, UDim.new(0, 220))
	local nextBtn = Ui.button(body, "Next ▶", UDim2.fromOffset(176, TAP), UDim2.new(1, -184, 0, 28), if picks[1] and picks[2] then C.orange else C.shade, 22)
	nextBtn.Activated:Connect(function()
		if not (picks[1] and picks[2]) then
			Ui.pop(nextBtn)
			return
		end
		preview = nil
		sure = false
		step = "foal"
		remote("BreedPreview"):FireServer(picks[1], picks[2])
		render()
	end)
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, 0, 1, -132)
	list.Position = UDim2.new(0, 0, 0, 130)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for k, h in horses() do
		local why = b.horses and b.horses[h.id]
		local free = why == false
		local picked = picks[1] == h.id or picks[2] == h.id
		local row = Ui.button(list, "", UDim2.new(1, -10, 0, TAP), UDim2.new(), if picked then C.gold elseif free then C.white else C.shade, 18)
		row.LayoutOrder = if free then k else 100 + k
		swatch(row, h.coat, 36, UDim2.new(0, 10, 0.5, -18))
		local stage = h.life and h.life.stage or "Prime"
		local nm = Ui.text(row, string.format("%s %s", Ageing.EMOJI[if h.legend then "Legend" else stage] or "", h.name), 18,
			{ Position = UDim2.new(0, 56, 0, 0), Size = UDim2.new(0.55, -56, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
		nm.TextTruncate = Enum.TextTruncate.AtEnd
		local sub = Ui.text(row, if free then (h.league or "Rookie") else tostring(why or ""), TEXT,
			{ Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.45, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
		sub.TextColor3 = if free then C.textGood else C.plum
		row.Activated:Connect(function()
			if not free then
				Ui.pop(sub)
				return
			end
			if picked then
				if picks[1] == h.id then picks[1] = nil else picks[2] = nil end
			elseif not picks[1] then
				picks[1] = h.id
			elseif not picks[2] then
				picks[2] = h.id
			else
				picks[2] = h.id
			end
			render()
		end)
	end
end

-- Step 2: Your foal --------------------------------------------------------------------------------
-- A chance as the card shows it: whole numbers plain ("45%"), others to one place ("2.5%").
local function pct(chance: number): string
	local x = math.floor(chance * 1000 + 0.5) / 10
	return if x == math.floor(x) then string.format("%d%%", x) else string.format("%.1f%%", x)
end

local ROW = 30
local function chanceRow(parent: Instance, y: number, coat: string, label: string, chance: number, surprise: boolean)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -16, 0, ROW)
	row.Position = UDim2.new(0, 8, 0, y)
	row.Parent = parent
	swatch(row, coat, 24, UDim2.new(0, 0, 0.5, -12))
	local l = Ui.text(row, label, TEXT, { Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -224, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
	l.TextTruncate = Enum.TextTruncate.AtEnd
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(120, 12)
	bar.Position = UDim2.new(1, -190, 0.5, -6)
	bar.BackgroundColor3 = C.white
	Ui.corner(bar, 6)
	Ui.stroke(bar, 2)
	bar.Parent = row
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(chance, 0, 1), 1)
	fill.BackgroundColor3 = if surprise then C.sky else C.green
	Ui.corner(fill, 6)
	fill.Parent = bar
	Ui.text(row, pct(chance), 18, { Position = UDim2.new(1, -64, 0, 0), Size = UDim2.new(0, 64, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right })
end

local function renderFoal()
	title.Text = "Your foal"
	local a, b = horseById(picks[1]), horseById(picks[2])
	if not (a and b) then
		step = "pick"
		return render()
	end
	-- family line and fee (the server's preview; the coat chances are the same shared rule)
	local fam = preview and preview.family
	line(if fam then "Family " .. string.rep("🌱", fam) else "Family …", 0, 22)
	-- Coat chances: one row per coat the foal can have, each with its own chance (rule 2: every coat and
	-- its chance). The server's preview table when it has come (the same shared rule as the roll).
	local cc = (preview and preview.coats) or Breeding.coatChances(a.coat, b.coat)
	local rows = {}
	for _, pr in cc.parents or {} do
		local owner = if pr[1] == a.coat and pr[1] == b.coat then "Both parents'" elseif pr[1] == a.coat then a.name .. "'s" else b.name .. "'s"
		table.insert(rows, { coat = pr[1], label = owner .. " coat", chance = pr[2], surprise = false })
	end
	local each = if #(cc.surprise and cc.surprise.coats or {}) > 0 then cc.surprise.chance / #cc.surprise.coats else 0
	for _, c in (cc.surprise and cc.surprise.coats) or {} do
		table.insert(rows, { coat = c, label = SURPRISE .. " Surprise: " .. coatWord(c), chance = each, surprise = true })
	end
	local boxH = 28 + #rows * (ROW + 2) + 8
	local box = Ui.card(body, UDim2.new(1, -16, 0, math.min(boxH, 224)), UDim2.new(0, 8, 0, 38), C.cream)
	Ui.text(box, "Coat chances", TEXT, { Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(1, -24, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left }).TextColor3 = C.plum
	local holder = Instance.new("ScrollingFrame") -- scrolls only past 6 rows
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.new(1, 0, 1, -30)
	holder.Position = UDim2.new(0, 0, 0, 28)
	holder.CanvasSize = UDim2.fromOffset(0, #rows * (ROW + 2))
	holder.ScrollBarThickness = 6
	holder.Parent = box
	for k, r in rows do
		chanceRow(holder, (k - 1) * (ROW + 2), r.coat, r.label, r.chance, r.surprise)
	end
	local fee = (preview and preview.fee) or Breeding.fee(a.league, b.league)
	local feeL = Ui.text(body, if fee then string.format("Fee 💵 %d", fee) else "", 22, { Position = UDim2.new(0, 8, 1, -TAP + 8),
		Size = UDim2.new(0, 170, 0, 32), TextXAlignment = Enum.TextXAlignment.Left })
	feeL.TextColor3 = C.textGood
	local back = Ui.button(body, "◀ Back", UDim2.fromOffset(130, TAP), UDim2.new(0, 186, 1, -TAP - 4), C.white, 20)
	back.Activated:Connect(function()
		step = "pick"
		sure = false
		render()
	end)
	local why = preview and preview.block
	if why then
		local l = Ui.text(body, why, TEXT, { Position = UDim2.new(0, 326, 1, -TAP - 4), Size = UDim2.new(1, -334, 0, TAP) })
		l.TextColor3 = C.textWarn
		if why == "Make room first" then
			local room = Ui.button(body, "🏫 Lend or Sell", UDim2.fromOffset(200, TAP), UDim2.new(1, -208, 0, 0), C.sky, 18)
			room.Activated:Connect(function()
				close()
				local ev = HudEvents:FindFirstChild("OpenRidingSchool")
				if ev then ev:Fire(nil) end
			end)
		end
		return
	end
	local go = Ui.button(body, if sure then string.format("Sure? 💵 %d", fee or 0) else EMOJI .. " Have a foal",
		UDim2.fromOffset(220, TAP), UDim2.new(1, -228, 1, -TAP - 4), if sure then C.gold else C.orange, 20)
	go:SetAttribute("NoPop", true)
	go.Activated:Connect(function()
		if not preview then return end
		if not sure then
			sure = true
			render()
			return
		end
		sure = false
		go.Text = "…"
		if Sound then Sound.play("coin", nil, nil, 0.8) end -- soft, no jackpot
		remote("BreedConfirm"):FireServer(picks[1], picks[2])
	end)
end

-- Waiting, here, closed ------------------------------------------------------------------------------
local function waitLine(p: any): string
	local n = p.racesLeft or 0
	if n <= 0 then return "Arrives tomorrow" end
	local races = if n == 1 then "1 race" else n .. " races"
	return if p.newDay then string.format("Arrives in %s or tomorrow", races) else string.format("Arrives in %s", races)
end

local playArrival

local function renderWait(p: any)
	title.Text = "A foal is on the way!"
	for k = 1, 2 do
		swatch(body, p.coats and p.coats[k], 56, UDim2.new(0.5, if k == 1 then -140 else 84, 0, 16))
		local n = Ui.text(body, p.names and p.names[k] or "", 18, { Position = UDim2.new(0.5, if k == 1 then -190 else 34, 0, 76),
			Size = UDim2.fromOffset(156, 26), TextWrapped = false })
		n.TextTruncate = Enum.TextTruncate.AtEnd
	end
	Ui.text(body, EMOJI, 40, { Position = UDim2.new(0.5, -30, 0, 22), Size = UDim2.fromOffset(60, 50) })
	line(waitLine(p), 130, 24, C.textGood)
	line("Race and play. Your foal will be here!", 172, TEXT, C.plum)
end

local function renderHere(p: any)
	title.Text = "Your foal is here!"
	for k = 1, 2 do
		swatch(body, p.coats and p.coats[k], 48, UDim2.new(0.5, if k == 1 then -120 else 72, 0, 16))
	end
	Ui.text(body, EMOJI, 40, { Position = UDim2.new(0.5, -30, 0, 16), Size = UDim2.fromOffset(60, 50) })
	line(string.format("%s and %s's foal", p.names and p.names[1] or "", p.names and p.names[2] or ""), 84, 20)
	local meet = Ui.button(body, "Meet your foal ▶", UDim2.fromOffset(280, TAP), UDim2.new(0.5, -140, 0, 150), C.orange, 24)
	meet.Activated:Connect(function()
		close()
		playArrival(p)
	end)
end

local function renderClosed(why: string)
	title.Text = "Foal Barn"
	line(why, 40, 22, C.textWarn)
	if why == "Make room first" then
		local room = Ui.button(body, "🏫 Lend or Sell", UDim2.fromOffset(240, TAP), UDim2.new(0.5, -120, 0, 110), C.sky, 20)
		room.Activated:Connect(function()
			close()
			local ev = HudEvents:FindFirstChild("OpenRidingSchool")
			if ev then ev:Fire(nil) end
		end)
	else
		line(string.format("Two horses with %d races can start a family.", B.minParentRaces), 100, TEXT, C.plum)
	end
end

render = function()
	if not gui.Enabled then return end
	clear()
	local b = breeding()
	if not b or not b.enabled then
		renderClosed("The Foal Barn is closed")
		return
	end
	if b.pending then
		if b.ready then renderHere(b.pending) else renderWait(b.pending) end
		return
	end
	if b.stableBlock and step ~= "foal" then
		renderClosed(b.stableBlock)
		return
	end
	if step == "foal" then renderFoal() else renderPick() end
end

local function open()
	if not PlayerState.data or not B.enabled then return end
	if busy() then
		Ui.toast("After your race!", "flag_ready", "🏁")
		return
	end
	step, sure = "pick", false
	-- keep earlier picks that can still be parents
	local b = breeding() or {}
	for k = 1, 2 do
		if picks[k] and not (b.horses and b.horses[picks[k]] == false) then picks[k] = nil end
	end
	gui.Enabled = true
	slide()
	render()
end
GoTo.register("foalBarn", open)
PlayerState.Changed.Event:Connect(function()
	if gui.Enabled then render() end
end)
remote("BreedPreviewResult").OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" or info.idA ~= picks[1] or info.idB ~= picks[2] then return end
	preview = info
	render()
end)
remote("BreedResult").OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" then return end
	Ui.toast(info.text or "", "heart", EMOJI)
	if info.ok then
		picks = { nil, nil }
		step = "pick"
	end
	render()
end)
player:GetAttributeChangedSignal("Racing"):Connect(function()
	if player:GetAttribute("Racing") then close() end
end)

-- The door prompt --------------------------------------------------------------------------------
local function attach(spot: Instance)
	if not spot:IsA("BasePart") or spot.Name ~= "FoalBarnSpot" or spot:FindFirstChild("FoalPrompt") then return end
	local p = Instance.new("ProximityPrompt")
	p.Name = "FoalPrompt"
	p.ActionText = "Open"
	p.ObjectText = "💞 Foal Barn"
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Parent = spot
	p.Triggered:Connect(open)
end

local function stagePart(): BasePart?
	local world = workspace:FindFirstChild("World")
	local barn = world and world:FindFirstChild("FoalBarn")
	local s = barn and barn:FindFirstChild("FoalStage")
	return if s and s:IsA("BasePart") then s else nil
end

task.spawn(function()
	local world = workspace:WaitForChild("World", 60)
	if not world then return end
	local function watch(folder: Instance)
		for _, ch in folder:GetChildren() do attach(ch) end
		folder.ChildAdded:Connect(function(ch) task.defer(attach, ch) end)
	end
	local f = world:FindFirstChild("FoalBarn")
	if f then watch(f) end
	world.ChildAdded:Connect(function(ch)
		if ch.Name == "FoalBarn" then watch(ch) end
	end)
end)

-- Meeting your foal -------------------------------------------------------------------------------
local function horseModel(coat: string): Model
	local folder = ReplicatedStorage:FindFirstChild("RaceModels")
	local m = folder and (folder:FindFirstChild("horse_stand_" .. coat) or folder:FindFirstChild("horse_gallop_" .. coat) or folder:FindFirstChild("horse_" .. coat))
	if m then
		m = m:Clone()
	else
		m = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2, 3, 6.5)
		body.Color = Ui.coatColors[coat] or Ui.coatColors.bay
		body.CFrame = CFrame.new(0, 3.6, 0)
		body.Parent = m
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.4, 1.6, 2.4)
		head.Color = body.Color
		head.CFrame = CFrame.new(0, 5.8, -3.8)
		head.Parent = m
		for _, xz in { { -0.6, -2.4 }, { 0.6, -2.4 }, { -0.6, 2.4 }, { 0.6, 2.4 } } do
			local leg = Instance.new("Part")
			leg.Name = "Leg"
			leg.Size = Vector3.new(0.6, 2.2, 0.6)
			leg.Color = body.Color
			leg.CFrame = CFrame.new(xz[1], 1.1, xz[2])
			leg.Parent = m
		end
		m.PrimaryPart = body
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
	end
	return m :: Model
end

local function hearts(at: Vector3, n: number, sparkle: boolean?)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(at)
	part.Parent = workspace
	for k = 1, n do -- hearts that float up and fade (BillboardGuis: no texture upload)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(40, 40)
		bb.StudsOffsetWorldSpace = Vector3.new((k % 3 - 1) * 1.2, 0, ((k * 7) % 5 - 2) * 0.4)
		bb.AlwaysOnTop = true
		bb.Adornee = part
		bb.Parent = part
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.TextScaled = true
		l.Text = if sparkle then "✦" else "💞"
		l.TextColor3 = C.gold
		l.Parent = bb
		task.delay(0.12 * k, function()
			TweenService:Create(bb, TweenInfo.new(1.6, Enum.EasingStyle.Sine), { StudsOffsetWorldSpace = bb.StudsOffsetWorldSpace + Vector3.new(0, 5, 0) }):Play()
			TweenService:Create(l, TweenInfo.new(1.6), { TextTransparency = 1 }):Play()
		end)
	end
	task.delay(0.12 * n + 1.8, function() part:Destroy() end)
end

local scene: { parent: Model?, foal: Model?, cam: any? } = {}
local naming -- forward

local function endScene()
	if scene.parent then scene.parent:Destroy() end
	if scene.foal then scene.foal:Destroy() end
	scene.parent, scene.foal = nil, nil
	local cam = workspace.CurrentCamera
	if cam and scene.cam then
		cam.CameraType = scene.cam.type
		scene.cam = nil
	end
end

playArrival = function(p: any)
	local stage = stagePart()
	local coat = p.coat or (p.coats and p.coats[1]) or "bay"
	local surprise = p.surprise == true -- the server's flag, stored at the roll (right even after a parent left)
	if not stage then
		naming(p, surprise)
		return
	end
	endScene()
	local still = calm()
	local base = stage.CFrame * CFrame.new(0, -stage.Size.Y / 2, 0)
	local parent = horseModel(p.coats and p.coats[1] or "bay")
	parent:PivotTo(base)
	parent.Parent = workspace
	local foal = horseModel(coat)
	-- behind the parent's far flank, facing the same way; then steps out 4 studs to the side
	local behind = base * CFrame.new(-1.5, 0, 0)
	foal:PivotTo(behind)
	HorseLook.shapeFoal(foal, { body = F.body, legY = F.legY })
	foal.Parent = workspace
	scene.parent, scene.foal = parent, foal
	-- a side shot of the stall (the replay's side view), framing the parent
	local cam = workspace.CurrentCamera
	if cam then
		scene.cam = { type = cam.CameraType }
		cam.CameraType = Enum.CameraType.Scriptable
		local look = base.Position + Vector3.new(0, 3, 0)
		cam.CFrame = CFrame.lookAt((base * CFrame.new(16, 5, 2)).Position, look)
	end
	local out = base * CFrame.new(4, 0, -1)
	local skippable, done = false, false
	task.delay(1, function() skippable = true end)
	local function finish()
		if done then return end
		done = true
		endScene()
		naming(p, surprise)
	end
	local input = UserInputService.InputBegan:Connect(function(io)
		if skippable and (io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch
			or io.KeyCode == Enum.KeyCode.Space or io.KeyCode == Enum.KeyCode.ButtonA) then
			task.defer(finish)
		end
	end)
	Ui.toast("💞 Your foal is here!", "heart", EMOJI)
	task.spawn(function()
		local from = foal:GetPivot()
		if still then
			-- Reduced Motion: it simply fades in beside its parent
			foal:PivotTo(out)
			local parts = {}
			for _, d in foal:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) d.LocalTransparencyModifier = 1 end end
			for t = 0, 1, 0.1 do
				for _, d in parts do d.LocalTransparencyModifier = 1 - t end
				task.wait(0.05)
			end
		else
			local bob = (GameConfig.horseLook and GameConfig.horseLook.bobStuds or 0.25) * 1.4
			local t0 = os.clock()
			while os.clock() - t0 < 1.2 and not done do
				local a = (os.clock() - t0) / 1.2
				foal:PivotTo(from:Lerp(out, a) + Vector3.new(0, math.abs(math.sin(a * math.pi * 4)) * bob, 0))
				RunService.RenderStepped:Wait()
			end
			if done then return end
			foal:PivotTo(out)
			-- turns to its parent and nuzzles twice
			local turned = out * CFrame.Angles(0, math.rad(12), 0)
			foal:PivotTo(turned)
			for _ = 1, 2 do
				if done then return end
				foal:PivotTo(turned * CFrame.Angles(math.rad(-5), 0, 0))
				task.wait(0.25)
				foal:PivotTo(turned)
				task.wait(0.25)
			end
		end
		if done then return end
		local top = parent:GetBoundingBox().Position + Vector3.new(0, 3, 0)
		hearts(top, 8)
		if surprise then hearts(top, 6, true) end
		if Sound then
			Sound.play("horse_nicker", 0.5, nil, F.nickerSpeed)
			task.delay(0.4, function() if Sound then Sound.play("horse_nicker", 0.5, nil, F.parentSpeed) end end)
			task.delay(1.2, function() if Sound then Sound.play("job_done") end end)
		end
		task.wait(2.2)
		finish()
	end)
	task.spawn(function()
		while not done do task.wait(0.2) end
		input:Disconnect()
	end)
	task.delay(8, finish) -- never stuck
end

-- Naming: the Starter's step 2 -------------------------------------------------------------------
local NW, NH = 640, 400
local ngui = Ui.screen("FoalName", 13)
ngui.Enabled = false
local npanel = Ui.card(ngui, UDim2.fromOffset(NW, NH), UDim2.new(), C.paper)
local nslide = Ui.fitPanel(npanel, NW, NH, nil, TEXT, TAP)
local ntitle = Ui.text(npanel, "Name your foal", 30, { Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 38) })
local nsub = Ui.text(npanel, "Tap one or two words", 20, { Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 0, 26) })
nsub.TextColor3 = C.plum
local npreview = Ui.text(npanel, "", 36, { Position = UDim2.new(0, 0, 0, 82), Size = UDim2.new(1, 0, 0, 44) })
local rows = {}
for r = 1, 2 do
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -20, 0, TAP)
	row.Position = UDim2.new(0, 10, 0, 130 + (r - 1) * 72)
	row.Parent = npanel
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Padding = UDim.new(0, 8)
	l.Parent = row
	rows[r] = row
end
local chosen = { nil, nil }
local rng = Random.new()
local function updateName()
	local name = NameGen.build(chosen[1], chosen[2])
	npreview.Text = name or "Tap words to name your foal"
	npreview.TextColor3 = if name then C.textWarn else C.plum
end
local function fillChips()
	local first, second = NameGen.offer(rng, 5)
	for r, words in { first, second } do
		for _, c in rows[r]:GetChildren() do
			if c:IsA("TextButton") then c:Destroy() end
		end
		chosen[r] = nil
		for _, w in words do
			local b = Ui.button(rows[r], w, UDim2.fromOffset(112, TAP), UDim2.new(), C.white, 20)
			b.Activated:Connect(function()
				chosen[r] = if chosen[r] == w then nil else w
				for _, other in rows[r]:GetChildren() do
					if other:IsA("TextButton") then other.BackgroundColor3 = if other.Text == chosen[r] then C.gold else C.white end
				end
				updateName()
			end)
		end
	end
	updateName()
end
local shuffle = Ui.button(npanel, "🔀 New words", UDim2.fromOffset(190, TAP), UDim2.new(0, 24, 1, -TAP - 16), C.sky, 20)
shuffle.Activated:Connect(fillChips)
local nclose = Ui.closeButton(npanel, UDim2.new(1, -TAP - 8, 0, 6), TAP) -- the foal waits at the barn: meet it again any time
nclose.Activated:Connect(function() ngui.Enabled = false end)
local nameBtn = Ui.button(npanel, "That's the name!", UDim2.fromOffset(250, TAP), UDim2.new(1, -274, 1, -TAP - 16), C.orange, 22)
local surpriseLine: string? = nil
nameBtn.Activated:Connect(function()
	if not NameGen.build(chosen[1], chosen[2]) then
		Ui.pop(npreview)
		return
	end
	nameBtn.Text = "…"
	remote("FoalArrive"):FireServer(chosen[1], chosen[2])
	task.delay(5, function()
		if ngui.Enabled then nameBtn.Text = "That's the name!" end -- no reply: try again
	end)
end)

naming = function(p: any, surprise: boolean)
	surpriseLine = if surprise and p.coat then string.format("%s A surprise coat: %s!", SURPRISE, coatWord(p.coat)) else nil
	nsub.Text = surpriseLine or "Tap one or two words"
	nameBtn.Text = "That's the name!"
	fillChips()
	ngui.Enabled = true
	nslide()
end

-- The name plate drops in over the foal, letter by letter; the foal nods twice.
remote("FoalArrived").OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" then return end
	if not info.name then
		Ui.toast(info.text or "Try again", "heart", EMOJI)
		nameBtn.Text = "That's the name!"
		return
	end
	ngui.Enabled = false
	local stage = stagePart()
	if stage then
		local base = stage.CFrame * CFrame.new(0, -stage.Size.Y / 2, 0)
		local foal = horseModel(info.coat or "bay")
		foal:PivotTo(base * CFrame.new(4, 0, -1))
		HorseLook.shapeFoal(foal, { body = F.body, legY = F.legY })
		foal.Parent = workspace
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(260, 64)
		bb.StudsOffset = Vector3.new(0, 4, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = foal.PrimaryPart or foal:FindFirstChildWhichIsA("BasePart", true)
		bb.Parent = foal
		local plate = Instance.new("TextLabel")
		plate.Size = UDim2.fromScale(1, 1)
		plate.BackgroundColor3 = C.cream
		plate.Font = Ui.font
		plate.TextScaled = true
		plate.TextColor3 = C.ink
		plate.Text = ""
		Ui.corner(plate, 14)
		Ui.stroke(plate, 3)
		plate.Parent = bb
		local sc = Instance.new("UIScale")
		sc.Scale = if calm() then 1 else 0
		sc.Parent = plate
		if not calm() then
			TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		task.spawn(function()
			for k = 1, #info.name do
				plate.Text = string.sub(info.name, 1, k)
				task.wait(0.05)
			end
			local home = foal:GetPivot()
			for _ = 1, 2 do
				foal:PivotTo(home * CFrame.Angles(math.rad(-6), 0, 0))
				task.wait(0.2)
				foal:PivotTo(home)
				task.wait(0.2)
			end
		end)
		task.delay(4, function() foal:Destroy() end)
	end
	if Sound then
		Sound.play("tap_good")
		task.delay(0.3, function() if Sound then Sound.play("clap", 0.6) end end)
		task.delay(0.45, function() if Sound then Sound.play("clap", 0.6) end end)
	end
	Ui.toast(string.format("Hello, %s! 🌱", info.name), "heart", EMOJI)
end)

-- "🍼 Comet's foal!": once, after a bred horse's first counted race ------------------------------
local fgui = Ui.screen("FoalFirstRace", 13)
fgui.Enabled = false
local banner = Ui.button(fgui, "", UDim2.fromOffset(460, 72), UDim2.new(0.5, -230, 0.22, 0), C.gold, 26)
banner.TextWrapped = true
local queue = {}
local foalHere = false -- "💞 Your foal is here!" waits until you're out of the race and its results card
remote("FoalHere").OnClientEvent:Connect(function() foalHere = true end)
banner.Activated:Connect(function() fgui.Enabled = false end)
remote("FoalFirstRace").OnClientEvent:Connect(function(info)
	if typeof(info) == "table" and typeof(info.parent) == "string" then table.insert(queue, info) end
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		local sinceRace = os.time() - (tonumber(player:GetAttribute("LastRaceEnd")) or 0)
		if foalHere and not busy() and not fgui.Enabled and sinceRace >= GameConfig.runInSeconds + 3 then
			foalHere = false
			Ui.toast("💞 Your foal is here!", "heart", EMOJI)
		end
		if #queue > 0 and not fgui.Enabled and not busy() then
			local info = table.remove(queue, 1)
			banner.Text = string.format("🍼 %s's foal!", info.parent)
			fgui.Enabled = true
			Ui.pop(banner)
			if Sound then
				Sound.play("tap_good")
				task.delay(0.3, function() if Sound then Sound.play("clap", 0.6) end end)
			end
			task.delay(3.5, function() fgui.Enabled = false end)
		end
	end
end)
