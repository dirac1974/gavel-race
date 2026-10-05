--!nonstrict
-- TrainingState: the training ride in progress on this client (D-053), shared between
-- TrainingRideClient (which writes it) and RideClient (which rides by it).
--   phase "countdown": hold the horse still at the start.
--   phase "ride": ride at the course's own speed (TrainingCourses.speedAt) and pull gently
--   toward `target` (the next hoop) when close.

local TrainingState = {
	active = false,
	course = nil :: string?,      -- course key while a session is on
	phase = nil :: string?,       -- "countdown" | "ride"
	target = nil,                 -- { x, z, nx, nz, half }: the next hoop's centre, forward normal, half width
	speed = nil :: number?,       -- the course's pace right now, if it isn't the usual one
	aim = nil,                    -- { x, z }: where Easy Rein steers
	easyRein = false,             -- the player's Easy Rein setting
	stick = 0,                    -- how far the move stick is pushed (RideClient writes it)
}

-- PaddockClient's picker asks to start a course through this (so both scripts share one path).
TrainingState.StartRequested = Instance.new("BindableEvent") -- (course)

function TrainingState.reset()
	TrainingState.active, TrainingState.course, TrainingState.phase, TrainingState.target = false, nil, nil, nil
	TrainingState.speed, TrainingState.aim = nil, nil
end

return TrainingState
