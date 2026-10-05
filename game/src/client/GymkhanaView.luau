--!nonstrict
-- GymkhanaView (D-053, T5 "This week's course"): the Mud Splash props in the paddock arena on
-- this screen. The server builds every layout into ReplicatedStorage.Gymkhanas (a folder per
-- course key, WorldScene) and names this week's in ReplicatedStorage's WeeklyCourse attribute,
-- from its own clock (TrainingService). This client copies that layout into workspace.Gymkhana
-- and rebuilds it when the week changes.
--   While you ride Mud Splash, the layout of your ride is pinned (TrainingRideClient), so a week
--   turning over mid-ride never changes the course under you; it switches when the ride ends.
--   View.pin(key) / View.unpin()   keep a layout for a ride / follow the week again
--   View.find(name)                a piece of the shown layout ("Mud1", "Log2", "Finish", ...)
--   View.shown()                   the course key on screen
-- Props never collide (CourseProps, CanCollide off), so a copy on one screen is safe.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local View = {}

local pinned: string? = nil
local shownKey: string? = nil
local shownFrom: Instance? = nil -- the template the copy came from (a rebuild replaces it)
local current: Instance? = nil

local function wanted(): string?
	if pinned then return pinned end
	local key = ReplicatedStorage:GetAttribute("WeeklyCourse")
	return if typeof(key) == "string" then key else nil
end

local function refresh()
	local key = wanted()
	local root = ReplicatedStorage:FindFirstChild("Gymkhanas")
	local template = key and root and root:FindFirstChild(key)
	if not template then return end -- keep what's shown until that layout arrives
	if current and current.Parent and shownKey == key then
		-- the same layout: a rebuilt copy (uploaded models arriving) waits until a ride is over
		if shownFrom == template or pinned then return end
	end
	local copy = template:Clone()
	copy.Name = "Gymkhana"
	copy:SetAttribute("Course", key)
	if current then current:Destroy() end
	copy.Parent = workspace
	current, shownKey, shownFrom = copy, key, template
end

function View.pin(key: string)
	pinned = key
	refresh()
end

function View.unpin()
	pinned = nil
	refresh()
end

function View.find(name: string): Instance?
	return if current and current.Parent then current:FindFirstChild(name) else nil
end

function View.shown(): string?
	return shownKey
end

ReplicatedStorage:GetAttributeChangedSignal("WeeklyCourse"):Connect(refresh)
task.spawn(function()
	local root = ReplicatedStorage:WaitForChild("Gymkhanas", 120)
	if not root then return end
	root.ChildAdded:Connect(function() task.defer(refresh) end)
	refresh()
end)

return View
