--!strict
-- The first ten minutes (D-049): a short guided tour after the starter pick, one step at a
-- time, each finished by doing the thing (the same events the Stable Board counts). Pure,
-- tested under Lune. Players can skip it any time; nothing is locked behind it.

local Tour = {}

export type Step = { id: string, event: string, text: string, go: string? }

-- Text uses {horse} for the active horse's name.
Tour.STEPS = {
	{ id = "race", event = "race", text = "Let's race! Tap RACE! and pick a race for {horse}.", go = "raceBoard" },
	{ id = "feed", event = "feed", text = "Great ride! Head to your barn and give {horse} some hay.", go = "stable" },
	{ id = "groom", event = "groom", text = "Now brush {horse} until it shines!", go = "stable" },
	{ id = "plant", event = "plant", text = "Plant your carrot seeds in a garden bed. They grow while you're away.", go = "stable" },
	{ id = "board", event = "board", text = "Your Stable Board has jobs for today. Tap 📋 to see them!", go = nil },
} :: { Step }

-- Current step index (1..#STEPS), or nil when finished or skipped.
function Tour.current(flags: { [string]: any }): number?
	if flags.tourDone then return nil end
	local i = tonumber(flags.tourStep) or 1
	if i > #Tour.STEPS then return nil end
	return i
end

-- An event happened: advance if it finishes the current step. Returns the new step index
-- (or nil when the tour just ended) and whether it moved.
function Tour.advance(flags: { [string]: any }, event: string): (number?, boolean)
	local i = Tour.current(flags)
	if not i then return nil, false end
	if Tour.STEPS[i].event ~= event then return i, false end
	i += 1
	flags.tourStep = i
	if i > #Tour.STEPS then
		flags.tourDone = true
		return nil, true
	end
	return i, true
end

function Tour.skip(flags: { [string]: any })
	flags.tourDone = true
end

function Tour.text(step: Step, horseName: string?): string
	return (string.gsub(step.text, "{horse}", horseName or "your horse"))
end

return Tour
