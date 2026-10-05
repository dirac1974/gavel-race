--!nonstrict
-- CollisionGroups (D-053): the ride and course collision groups, set up by whoever needs them
-- first (Rides, WorldScene). Each group is registered only if it isn't yet, since other
-- scripts may register CourseProps too.
--   Walkers         player characters on foot: collide with the world and everyone as Default
--                   does, except TrainingRiders (course riders never collide with anyone).
--   RideHorses      every ride rig and its rider; collides with everything as before.
--   TrainingRiders  a rig and its rider on a training ride: collides with the world (Default:
--                   ground, rails, fences) but not with Walkers, RideHorses, itself or
--                   CourseProps.
--   CourseProps     hoops, poles, logs, cones and finish posts: never collides with a ride
--                   horse, whichever group it's in. Logs never block a horse.
-- STATUS: written without Studio access; verify in Studio before relying on it.

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {
	RIDE = "RideHorses",
	TRAINING = "TrainingRiders",
	PROPS = "CourseProps",
	WALKERS = "Walkers",
}

local ready = false

local function collidable(a: string, b: string, on: boolean)
	local ok, err = pcall(function() PhysicsService:CollisionGroupSetCollidable(a, b, on) end)
	if not ok then warn("[CollisionGroups] " .. a .. "/" .. b .. ": " .. tostring(err)) end
end

function CollisionGroups.ensure()
	if ready then return end
	ready = true
	for _, name in { CollisionGroups.RIDE, CollisionGroups.TRAINING, CollisionGroups.PROPS, CollisionGroups.WALKERS } do
		local ok, err = pcall(function()
			if not PhysicsService:IsCollisionGroupRegistered(name) then PhysicsService:RegisterCollisionGroup(name) end
		end)
		if not ok then warn("[CollisionGroups] register " .. name .. ": " .. tostring(err)) end
	end
	-- Never turn off TrainingRiders with Default, or course riders would fall through the ground.
	collidable(CollisionGroups.TRAINING, CollisionGroups.RIDE, false)
	collidable(CollisionGroups.TRAINING, CollisionGroups.TRAINING, false)
	collidable(CollisionGroups.TRAINING, CollisionGroups.WALKERS, false)
	collidable(CollisionGroups.PROPS, CollisionGroups.TRAINING, false)
	collidable(CollisionGroups.PROPS, CollisionGroups.RIDE, false)
	collidable(CollisionGroups.PROPS, "Default", false) -- nor any other horse or walker
	collidable(CollisionGroups.PROPS, CollisionGroups.WALKERS, false)
end

function CollisionGroups.set(model: Instance, group: string)
	CollisionGroups.ensure()
	if model:IsA("BasePart") then model.CollisionGroup = group end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end
end

return CollisionGroups
