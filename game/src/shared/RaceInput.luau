--!strict
-- Race steering input (D-054 S3): which keys and buttons steer, and the left-stick flick. Pure
-- (key names, not Enum values), so it runs under Lune. RaceController passes KeyCode.Name.
-- Lane 1 is the rail, on the left in a counter-clockwise race: In (-1) is left, Out (+1) right.
-- None of these is a tap (D-055: only GameConfig.tapKeys tap); tests/luau/steer_controls_tests.luau
-- checks the two lists never share a key.

local RaceInput = {}

RaceInput.STEER = {
	A = -1, Left = -1, DPadLeft = -1,
	D = 1, Right = 1, DPadRight = 1,
}
-- The left stick steers by flicks, read from its position (InputChanged), never as a press.
RaceInput.STICK = "Thumbstick1"
RaceInput.FLICK_FIRE = 0.6  -- a flick fires past this...
RaceInput.FLICK_REARM = 0.3 -- ...and the stick must come back under this before the next one

-- -1 (In), 1 (Out) or nil for a key or button name.
function RaceInput.steerDir(name: string): number?
	return RaceInput.STEER[name]
end

-- A steering key or button (the left stick included): never a tap.
function RaceInput.isSteerInput(name: string): boolean
	return RaceInput.STEER[name] ~= nil or name == RaceInput.STICK
end

-- The left stick at horizontal position x (-1..1). armed = whether the next flick may fire.
-- Returns the direction to steer (or nil) and the new armed state.
function RaceInput.flick(armed: boolean, x: number): (number?, boolean)
	if armed and math.abs(x) > RaceInput.FLICK_FIRE then
		return if x < 0 then -1 else 1, false
	end
	if not armed and math.abs(x) < RaceInput.FLICK_REARM then return nil, true end
	return nil, armed
end

return RaceInput
