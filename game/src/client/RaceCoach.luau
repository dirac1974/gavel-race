--!nonstrict
-- RaceCoach (AAA Phase 2, D-067): first-race coaching and the tap's word at the marker, on your own
-- slider. Moved out of RaceController (it was near Luau's 200 top-level locals).
--   The word at the marker (raceFx.judgeAtMarker): small, just under the slider where you tapped,
--   sinking and fading over judgeSeconds (Reduced Motion: it fades in place). The big word still
--   shows in the middle.
--   Coaching (a player's first raceFx.coachRaces races): for the first coachPasses passes (and the
--   countdown before them) the ghost thumb (the steering tip's, reused) points at the green and
--   presses as the marker crosses it, with "NOW!" on the green (within coachNowZone of its centre).
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PaceMeter = require(Shared:WaitForChild("PaceMeter"))

local FX = GameConfig.raceFx
local Coach = {}

local function still(): boolean
	local ok, on = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ok and on == true
end

local judge: TextLabel, nowLabel: TextLabel = nil, nil
local token = 0

-- Build the two words on the pace slider (`pace` = RaceController's meter: { bar, zone, ... }).
function Coach.attach(pace)
	judge = Instance.new("TextLabel")
	judge.AnchorPoint = Vector2.new(0.5, 0)
	judge.Size = UDim2.fromOffset(140, 26)
	judge.Position = UDim2.new(0.5, 0, 1, 4)
	judge.BackgroundTransparency = 1
	judge.Font = Enum.Font.GothamBlack
	judge.TextSize = 20
	judge.TextColor3 = Color3.new(1, 1, 1)
	judge.TextStrokeTransparency = 0.2
	judge.ZIndex = 7
	judge.Visible = false
	judge.Parent = pace.bar
	nowLabel = Instance.new("TextLabel")
	nowLabel.Size = UDim2.fromScale(1, 1)
	nowLabel.BackgroundTransparency = 1
	nowLabel.Text = "NOW!"
	nowLabel.Font = Enum.Font.GothamBlack
	nowLabel.TextColor3 = Color3.fromHex("1F2430")
	nowLabel.TextScaled = true
	nowLabel.ZIndex = 5
	nowLabel.Visible = false
	nowLabel.Parent = pace.zone
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize, size.MinTextSize = 24, 14
	size.Parent = nowLabel
end

-- The tap's word at the marker (pos: the marker, -1..1 along the slider).
function Coach.judge(word: string, pos: number)
	if not judge or not (FX.enabled and FX.judgeAtMarker) or word == "" then return end
	token += 1
	local mine = token
	local x = math.clamp(0.5 + 0.5 * pos, 0.08, 0.92)
	judge.Text = word
	judge.TextColor3 = if word == "Perfect" then Color3.fromHex("FFD34D") elseif word == "Great" then Color3.fromHex("9FE07A") else Color3.new(1, 1, 1)
	judge.Position = UDim2.new(x, 0, 1, 4)
	judge.TextTransparency, judge.TextStrokeTransparency = 0, 0.2
	judge.Visible = true
	local seconds = FX.judgeSeconds or 0.6
	local goal = { TextTransparency = 1, TextStrokeTransparency = 1 }
	if not still() then goal.Position = UDim2.new(x, 0, 1, 14) end
	TweenService:Create(judge, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), goal):Play()
	task.delay(seconds, function()
		if mine == token then judge.Visible = false end
	end)
end

-- One frame of coaching. `pass` is the pass on the slider (the first during the countdown), `live`
-- whether it is running. The thumb lives in `thumbGui` (the steering screen); `tipBusy` is true while
-- the steering tip owns it. Returns nothing; hides "NOW!" when not coaching.
function Coach.frame(coached: boolean, pace, passes, pass: number?, live: boolean, t: number, thumb: TextLabel,
	thumbGui: LayerCollector, tipBusy: boolean)
	if not nowLabel then return end
	if coached and pass and pass <= (FX.coachPasses or 0) then
		local p = passes[pass]
		local inZone = live and math.abs(PaceMeter.position(p, t) - p.center) <= (FX.coachNowZone or 0.2)
		nowLabel.Visible = inZone
		local z = pace.zone
		local at = z.AbsolutePosition - thumbGui.AbsolutePosition
		local press = if inZone and not still() then 8 else 0
		thumb.Text, thumb.AnchorPoint = "👇", Vector2.new(0.5, 1)
		thumb.Position = UDim2.fromOffset(at.X + z.AbsoluteSize.X / 2, at.Y + 6 + press)
		thumb.Visible = true
	else
		nowLabel.Visible = false
		if coached and not tipBusy then thumb.Visible = false end
	end
end

return Coach
