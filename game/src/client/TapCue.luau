--!nonstrict
-- TapCue (D-071, provisional; GameConfig.tapCue, GameConfig.tapPreview.heldCue): the tap preview's
-- words and feel on the rider's own screen. Moved out of RaceController (it is near Luau's limit for
-- top-level locals); RaceController hands it what it needs (attach).
--   The message: the server's TapNote ("up", sent to you alone) shows as a silent BillboardGui just
--   above your saddle, "Giddy-up! Moving up!", and the place badge pops with it. It waits behind a
--   steering chip or coaching, never shows in the Final Burst or after the lock (TapMessage).
--   Spectators never get it. In first person (camera zoom under raceHud.youMarker.firstPersonZoom)
--   the billboard would sit behind the camera, so the words go on the hint line instead. While it
--   shows, the YOU marker steps aside (when riderShown puts it over your horse) and the tap word
--   shows only Perfect, Early and Late (RaceState.tapMessageUp, RaceController).
--   Held by lane room: the server's TapHeld (feet, unreliable, to you alone). Held long enough, your
--   horse bobs a little harder, leans forward a little and kicks up an extra puff a stride
--   (RaceState.tapPressure, drawn by RaceView; none under Reduced Motion), and a chip shows
--   (TapPreview.stepCue, TapMessage.chip): "Room this way! ◀" (or ▶) toward the side with room when
--   you have the steering buttons, with that button's ring lit briefly; "Keep tapping! Room soon."
--   once a race with Smart Steer. A chip that would crowd another steering chip, coaching or the
--   Final Burst waits.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local TapCue = {}

-- h = { steer = () -> the race you ride (RaceController's steer table) or nil, myLane = () -> your lane,
--   chip = (text) -> () (RaceController's showChip), chipBusy = () -> a steering chip is up,
--   coachBusy = () -> first-race coaching has the moment, badge = the place badge's text (GuiObject),
--   hintLine = (text, seconds) -> () (the hint line, for first person) }
function TapCue.attach(h)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local GuiService = game:GetService("GuiService")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local TapPreview = require(Shared:WaitForChild("TapPreview"))
	local TapMessage = require(Shared:WaitForChild("TapMessage"))
	local RaceState = require(script.Parent:WaitForChild("RaceState"))
	local remotes = ReplicatedStorage:WaitForChild("RaceRemotes")
	local CFG = GameConfig.tapCue or {}
	local PCFG = GameConfig.tapPreview
	local SHUD = GameConfig.steerHud
	local HUDCFG = GameConfig.raceHud or {}
	local YOU = HUDCFG.youMarker or {}

	local function still(): boolean
		local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
		return ok and on == true
	end
	local function serverNow(): number
		return workspace:GetServerTimeNow()
	end
	local function firstPerson(): boolean
		local camera = workspace.CurrentCamera
		if not camera then return false end
		return (camera.CFrame.Position - camera.Focus.Position).Magnitude < (YOU.firstPersonZoom or 2)
	end

	local pop: UIScale? = nil
	if h.badge then
		pop = Instance.new("UIScale")
		pop.Name = "TapPop"
		pop.Parent = h.badge
	end
	local st = { steer = nil, held = 0, cue = TapPreview.newCue(), q = TapMessage.new(), bb = nil, label = nil, scale = nil,
		token = 0, you = nil }

	-- The YOU marker steps aside while the message shows (only where riderShown puts it over your horse).
	local function hideYou(horse: Instance?, on: boolean)
		if on and not (HUDCFG.enabled ~= false and YOU.riderShown == true) then return end
		local you = if on and horse then horse:FindFirstChild("YouMarker") else st.you
		if you then you:SetAttribute("TapHidden", if on then true else nil) end
		st.you = if on then you else nil
	end

	local function reset(s)
		st.steer, st.held = s, 0
		st.cue, st.q = TapPreview.newCue(), TapMessage.new()
		st.token += 1
		hideYou(nil, false)
		if st.bb then st.bb:Destroy() end
		st.bb, st.label, st.scale = nil, nil, nil
		RaceState.tapPressure, RaceState.tapMessageUp = false, false
	end

	local function horseOf(s): Instance?
		local lane = h.myLane()
		local track = lane and RaceState.trackFolder(s.course)
		local horses = track and track:FindFirstChild("Horses")
		return horses and horses:FindFirstChild("Lane" .. lane)
	end

	-- The billboard just above your saddle (under the YOU marker), made on first use each race. A
	-- BillboardGui parented to a Model needs an Adornee to render: the horse's main part.
	local function billboard(horse: Instance): (BillboardGui?, TextLabel?)
		if st.bb and st.bb.Parent == horse then return st.bb, st.label end
		if st.bb then st.bb:Destroy() end
		local k = RaceState.hudScale()
		local bb = Instance.new("BillboardGui")
		bb.Name = "TapMessage"
		bb.Size = UDim2.fromOffset(math.floor(230 * k), math.floor(44 * k))
		bb.StudsOffsetWorldSpace = Vector3.new(0, CFG.studsAbove or 6.5, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Enabled = false
		bb.Adornee = (horse:IsA("Model") and horse.PrimaryPart) or horse:FindFirstChildWhichIsA("BasePart", true)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromHex("FFF7E6") -- Paper (RaceHudStyle)
		label.BackgroundTransparency = 0.05
		label.TextColor3 = Color3.fromHex("1D2433") -- Ink
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = ""
		label.Parent = bb
		local size = Instance.new("UITextSizeConstraint")
		size.MinTextSize, size.MaxTextSize = CFG.minTextPx or 14, CFG.maxTextPx or 24
		size.Parent = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromHex("1D2433")
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = label
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = label
		local scale = Instance.new("UIScale")
		scale.Parent = label
		bb.Parent = horse
		st.bb, st.label, st.scale = bb, label, scale
		return bb, label
	end

	-- Show the words over your horse (silent; the hint line in first person) and pop the place badge.
	local function show(s, text: string)
		local seconds = CFG.messageSeconds or 1.6
		local horse = horseOf(s)
		if not horse then return end
		st.token += 1
		local token = st.token
		local calm = still()
		RaceState.tapMessageUp = true
		if firstPerson() then
			if h.hintLine then h.hintLine(text, seconds) end
		else
			local bb, label = billboard(horse)
			if not bb or not label then
				RaceState.tapMessageUp = false
				return
			end
			label.Text = text
			label.TextTransparency, label.BackgroundTransparency = 0, 0.05
			bb.Enabled = true
			hideYou(horse, true)
			if st.scale then
				if calm then
					st.scale.Scale = 1
				else
					st.scale.Scale = 0.8
					TweenService:Create(st.scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end
			end
		end
		if pop and not calm then
			pop.Scale = CFG.badgePopScale or 1.15
			TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		task.delay(seconds, function()
			if token ~= st.token then return end
			local label, bb = st.label, st.bb
			if label and label.Parent then
				TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			end
			task.delay(0.3, function()
				if token ~= st.token then return end
				if bb and bb.Parent then bb.Enabled = false end
				hideYou(nil, false)
				RaceState.tapMessageUp = false
			end)
		end)
	end

	local function ours(s, courseId): boolean
		return s ~= nil and s == st.steer and s.course == (courseId or "dirt")
	end
	remotes:WaitForChild("TapNote").OnClientEvent:Connect(function(kind, courseId)
		local s = h.steer()
		if not ours(s, courseId) or s.locked then return end
		TapMessage.offer(st.q, kind, serverNow() - s.start)
	end)
	remotes:WaitForChild("TapHeld").OnClientEvent:Connect(function(feet, courseId)
		local s = h.steer()
		if not ours(s, courseId) then return end
		st.held = if type(feet) == "number" then feet else 0
	end)

	RunService.RenderStepped:Connect(function(dt)
		local s = h.steer()
		if s ~= st.steer then reset(s) end
		if not s or CFG.enabled == false or not TapPreview.enabled(PCFG) then
			RaceState.tapPressure = false
			return
		end
		local now = serverNow() - s.start
		local burst = RaceState.burstShowing == true
		local busy = h.chipBusy() or h.coachBusy()
		-- Held by lane room: the pressure cue and the chip.
		local lane = s.lane
		local room = lane ~= nil and (lane.inSide == "free" or lane.outSide == "free")
		local chipAt, tapsShown = st.cue.chipAt, st.cue.tapsShown
		local pressure, chip = TapPreview.stepCue(st.cue, PCFG, st.held, dt, now, s.locked == true, not s.shown, room)
		RaceState.tapPressure = pressure and not still()
		if chip then
			local text, dir = TapMessage.chip(chip, lane and lane.inSide, lane and lane.outSide)
			local crowded = busy or burst or (s.chips ~= nil and now - s.chips.lastAt < (SHUD.chipMinGap or 2))
			if crowded or not text then
				st.cue.chipAt, st.cue.tapsShown = chipAt, tapsShown -- (not shown: it may come on a later frame)
			else
				h.chip(text)
				if dir ~= 0 then -- that button's ring lights briefly (RaceController's updateSteer draws it)
					s.roomRing, s.roomRingUntil = dir, os.clock() + (CFG.ringSeconds or 1.5)
				end
			end
		end
		-- The message over your horse.
		local text = TapMessage.take(st.q, now, CFG, PCFG, s.locked == true, burst, busy)
		if text then show(s, text) end
	end)
end

return TapCue
