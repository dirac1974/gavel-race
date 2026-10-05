--!strict
-- Horse names by tapping word chips (D-037): no typing, so no text filter is needed and no
-- player can write anything rude. The server accepts only names built from these lists.

local NameGen = {}

NameGen.FIRST = {
	"Lucky", "Sunny", "Rocket", "Maple", "Thunder", "Copper", "Misty", "Comet", "Dusty", "Honey",
	"Blaze", "Pepper", "Daisy", "Ziggy", "Biscuit", "Willow", "Clover", "Jazzy", "Pebble", "Captain",
	"Little", "Silver", "Golden", "Midnight", "Starry", "Cocoa", "Breezy", "Jolly", "Ginger", "Mighty",
}
NameGen.SECOND = {
	"Star", "Dash", "Bolt", "Belle", "Boots", "Spark", "Breeze", "Socks", "Moon", "Rose",
	"Jet", "Flash", "Penny", "Pie", "Bean", "Hooves", "Sky", "River", "Sprout", "Cupcake",
	"Rocket", "Comet", "Thunder", "Button", "Meadow", "Pickle", "Waffle", "Ranger", "Twister", "Muffin",
}

-- A name is one or two words from the lists ("Comet", "Lucky Star"). Returns the name or nil.
function NameGen.build(first: string?, second: string?): string?
	local a = if first and table.find(NameGen.FIRST, first) then first else nil
	local b = if second and table.find(NameGen.SECOND, second) then second else nil
	if first and not a then return nil end
	if second and not b then return nil end
	if a and b then
		if a == b then return a end
		return a .. " " .. b
	end
	return a or b
end

-- A few random chips to offer. `rng` has NextInteger(lo, hi).
function NameGen.offer(rng: any, count: number): ({ string }, { string })
	local function pick(list: { string }): { string }
		local pool = table.clone(list)
		local out = {}
		for _ = 1, math.min(count, #pool) do
			local k = rng:NextInteger(1, #pool)
			table.insert(out, pool[k])
			table.remove(pool, k)
		end
		return out
	end
	return pick(NameGen.FIRST), pick(NameGen.SECOND)
end

return NameGen
