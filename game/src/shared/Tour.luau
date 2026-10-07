--!strict
-- The first ten minutes (D-049): a short guided tour after the starter pick, one step at a
-- time, each finished by doing the thing (the same events the Stable Board counts). Pure,
-- tested under Lune. Players can skip it any time; nothing is locked behind it.

local Tour = {}

export type Step = { id: string, event: string, text: string, go: string? }

-- Text uses {horse} for the active horse's name.
Tour.STEPS = {
	-- The first GO joins a race with your horse at once (D-063: in a race within 2 minutes).
	{ id = "race", event = "race", text = "Let's race! Tap GO to race with {horse}.", go = "race" },
	{ id = "feed", event = "feed", text = "Great ride! Head to your barn and give {horse} some hay.", go = "stable" },
	{ id = "groom", event = "groom", text = "Now brush {horse} until it shines!", go = "stable" },
	{ id = "plant", event = "plant", text = "Plant your carrot seeds in a garden bed. They grow while you're away.", go = "stable" },
	{ id = "board", event = "board", text = "Your Stable Board has jobs for today. Tap 📋 to see them!", go = nil },
} :: { Step }

-- Current step index (1..#STEPS), or nil when finished or skipped. Steps already done (in
-- any order: a kid may feed before racing) are skipped.
function Tour.current(flags: { [string]: any }): number?
	if flags.tourDone then return nil end
	local did = if typeof(flags.tourDid) == "table" then flags.tourDid else {}
	local i = tonumber(flags.tourStep) or 1
	while i <= #Tour.STEPS and did[Tour.STEPS[i].event] do i += 1 end
	if i > #Tour.STEPS then return nil end
	return i
end

-- An event happened: remember it, and move past every step that's now done. Returns the new
-- step index (or nil when the tour just ended) and whether it moved.
function Tour.advance(flags: { [string]: any }, event: string): (number?, boolean)
	local before = Tour.current(flags)
	if not before then return nil, false end
	if typeof(flags.tourDid) ~= "table" then flags.tourDid = {} end
	flags.tourDid[event] = true
	local after = Tour.current(flags)
	if after == before then return before, false end
	if not after then
		flags.tourDone = true
		flags.tourStep = #Tour.STEPS + 1
		return nil, true
	end
	flags.tourStep = after
	return after, true
end

function Tour.skip(flags: { [string]: any })
	flags.tourDone = true
end

function Tour.text(step: Step, horseName: string?): string
	return (string.gsub(step.text, "{horse}", horseName or "your horse"))
end

return Tour
