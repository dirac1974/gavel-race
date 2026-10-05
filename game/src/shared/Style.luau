--!strict
-- The Tack & Paint shop (D-050): cosmetics bought with Diamonds, plus free starters. Pure
-- rules on a Profile, tested under Lune. Items only change how things look (saddle cloths and
-- helmets for riding around the world, barn paint, name plates, yard decor); never stats,
-- Rating, win chance, Energy or Green Cash, and never horses or coats. In races everyone
-- wears lane colours. Fan flags are earned with Fan levels, never sold.
-- Horse, rider, barn and fan items: one worn per slot. Yard decor: each piece is placed or put
-- away on its own. Owned items stay owned; anything bought can be returned within 24 hours
-- for all its Diamonds. Nothing is random, timed or limited.

local Style = {}

export type Item = {
	id: string,
	name: string,
	slot: string,      -- "cloth" | "helmet" | "paint" | "plate" | "fan" | "yard"
	price: number,     -- Diamonds (multiples of 25); 0 = free starter
	color: string?,    -- main colour hex
	color2: string?,   -- second colour (paint roof / trim)
	color3: string?,
	pattern: string?,  -- cloth pattern: "plain" | "stars" | "checks" | "lightning" | "goldtrim"
	model: string?,    -- yard decor model slot
	emoji: string,
	set: string?,      -- collection set (the Star Set)
	fanLevel: number?, -- earned at this Fan level (never sold)
}

Style.SLOT_LABELS = {
	cloth = "Saddle cloth", helmet = "Helmet", paint = "Barn paint", plate = "Name plates", fan = "Fan flag", yard = "Yard",
}
Style.CATEGORIES = {
	{ id = "tack", label = "🐴 Tack", slots = { "cloth" } },
	{ id = "jockey", label = "⛑️ Jockey", slots = { "helmet" } },
	{ id = "barn", label = "🏠 Barn Look", slots = { "paint", "plate" } },
	{ id = "yard", label = "🌼 Front Yard", slots = { "yard" } },
	{ id = "fan", label = "📣 Fan Gear", slots = { "fan" } },
}

Style.ITEMS = {
	-- Tack (shown on your own horse when you ride around the world and in its stall)
	{ id = "cloth_plain", name = "Plain cloth", slot = "cloth", price = 0, color = "FBFBF5", pattern = "plain", emoji = "⬜" },
	{ id = "cloth_stars", name = "Stars cloth", slot = "cloth", price = 75, color = "2E5AAC", pattern = "stars", emoji = "⭐", set = "star" },
	{ id = "cloth_checks", name = "Checks cloth", slot = "cloth", price = 75, color = "E5484D", pattern = "checks", emoji = "🏁" },
	{ id = "cloth_lightning", name = "Lightning cloth", slot = "cloth", price = 100, color = "1D2433", pattern = "lightning", emoji = "⚡" },
	{ id = "cloth_goldtrim", name = "Gold trim cloth", slot = "cloth", price = 150, color = "7B2D26", pattern = "goldtrim", emoji = "🥇" },
	-- Jockey
	{ id = "helmet_solid", name = "Solid helmet", slot = "helmet", price = 0, color = "E5484D", emoji = "⛑️" },
	{ id = "helmet_dots", name = "Polka dot helmet", slot = "helmet", price = 50, color = "17A398", pattern = "dots", emoji = "🔵" },
	{ id = "helmet_star", name = "Star helmet", slot = "helmet", price = 75, color = "FFD23F", pattern = "star", emoji = "🌟", set = "star" },
	-- Barn Look (walls, roof, trim together)
	{ id = "paint_classic", name = "Classic red barn", slot = "paint", price = 0, color = "C0392B", color2 = "7B2D26", color3 = "FBFBF5", emoji = "🟥" },
	{ id = "paint_meadow", name = "Meadow paint", slot = "paint", price = 100, color = "8DAE7E", color2 = "2F5D3A", color3 = "FBFBF5", emoji = "🌿" },
	{ id = "paint_candy", name = "Candy paint", slot = "paint", price = 100, color = "F7B2C4", color2 = "FBFBF5", color3 = "E5484D", emoji = "🍬" },
	{ id = "paint_midnight", name = "Midnight & Gold", slot = "paint", price = 150, color = "1F2A44", color2 = "2B2B30", color3 = "E3B341", emoji = "🌙" },
	{ id = "plate_white", name = "Plain name plates", slot = "plate", price = 0, color = "FBFBF5", emoji = "🪧" },
	{ id = "plate_gold", name = "Gold name plates", slot = "plate", price = 100, color = "E3B341", emoji = "✨" },
	-- Front Yard (each piece has its own spot in your yard)
	{ id = "yard_bench", name = "Bench", slot = "yard", price = 50, model = "bench", emoji = "🪑" },
	{ id = "yard_lanterns", name = "Lantern pair", slot = "yard", price = 75, model = "lantern_post", emoji = "🏮" },
	{ id = "yard_saddlerack", name = "Saddle rack", slot = "yard", price = 75, model = "saddle_rack", emoji = "🐎" },
	{ id = "yard_picnic", name = "Picnic table", slot = "yard", price = 100, model = "picnic_table", emoji = "🧺" },
	{ id = "yard_haycart", name = "Hay cart", slot = "yard", price = 100, model = "hay_cart", emoji = "🛒" },
	{ id = "yard_bridge", name = "Wooden bridge", slot = "yard", price = 150, model = "wooden_bridge", emoji = "🌉" },
	-- Fan Gear: earned with Fan levels from cheering (never sold), shown over your head
	{ id = "fan_lane", name = "Lane flag", slot = "fan", price = 0, emoji = "🚩" },
	{ id = "fan_star", name = "Star flag", slot = "fan", price = 0, fanLevel = 3, emoji = "🌟", set = "star" },
	{ id = "fan_hoof", name = "Foam hoof", slot = "fan", price = 0, fanLevel = 5, emoji = "🧡" },
} :: { Item }

-- Owning a whole set adds a little extra (no random rolls): the Star Set puts a gold star on
-- your name plates.
Style.SETS = { star = { name = "Star Set", reward = "A gold star on your name plates" } }

local byId: { [string]: Item } = {}
for _, it in Style.ITEMS do byId[it.id] = it end

function Style.item(id: string): Item?
	return byId[id]
end

local function ensure(p: any)
	if typeof(p.style) ~= "table" then p.style = { owned = {}, equipped = {} } end
	p.style.owned = p.style.owned or {}
	p.style.equipped = p.style.equipped or {}
	p.diamonds = p.diamonds or 0
end
Style.ensure = ensure

function Style.fanLevel(p: any): number
	local xp = (typeof(p.fan) == "table" and tonumber(p.fan.xp)) or 0
	return 1 + xp // 100
end

function Style.owns(p: any, id: string): boolean
	ensure(p)
	local it = byId[id]
	if not it then return false end
	if it.fanLevel then return Style.fanLevel(p) >= it.fanLevel end
	return it.price == 0 or p.style.owned[id] == true
end

function Style.forSale(it: Item): boolean
	return it.price > 0 and it.fanLevel == nil
end

Style.RETURN_SECONDS = 24 * 60 * 60

-- Buy with Diamonds; worn (or placed) right away. Returns (ok, message).
function Style.buy(p: any, id: string, now: number): (boolean, string)
	ensure(p)
	local it = byId[id]
	if not it or not Style.forSale(it) then return false, "That isn't in the shop" end
	if Style.owns(p, id) then return false, "You already have it!" end
	if p.diamonds < it.price then return false, string.format("%s costs %d 💎", it.name, it.price) end
	p.diamonds -= it.price
	p.style.owned[id] = true
	p.style.boughtAt = p.style.boughtAt or {}
	p.style.boughtAt[id] = now
	Style.equip(p, id)
	return true, it.name .. " is yours! (You can return it within a day.)"
end

-- Changed your mind? Return an item within 24 hours for all its Diamonds.
function Style.canReturn(p: any, id: string, now: number): boolean
	ensure(p)
	local it = byId[id]
	local at = p.style.boughtAt and p.style.boughtAt[id]
	return it ~= nil and p.style.owned[id] == true and at ~= nil and now - at < Style.RETURN_SECONDS
end

function Style.giveBack(p: any, id: string, now: number): (boolean, string)
	if not Style.canReturn(p, id, now) then return false, "That can't be returned now" end
	local it = byId[id] :: Item
	Style.unequip(p, id)
	p.style.owned[id] = nil
	p.style.boughtAt[id] = nil
	p.diamonds += it.price
	return true, string.format("Returned %s: +%d 💎", it.name, it.price)
end

-- Wear an owned item (yard pieces: place it). Returns (ok, message).
function Style.equip(p: any, id: string): (boolean, string)
	ensure(p)
	local it = byId[id]
	if not it then return false, "That isn't in the shop" end
	if not Style.owns(p, id) then return false, "Get it in the Tack & Paint shop first" end
	if it.slot == "yard" then
		p.style.equipped["yard:" .. id] = true
	else
		p.style.equipped[it.slot] = id
	end
	return true, it.name .. " on!"
end

-- Take it off (back to the free starter) or put a yard piece away.
function Style.unequip(p: any, id: string): boolean
	ensure(p)
	local it = byId[id]
	if not it then return false end
	if it.slot == "yard" then
		p.style.equipped["yard:" .. id] = nil
	elseif p.style.equipped[it.slot] == id then
		p.style.equipped[it.slot] = nil
	end
	return true
end

-- What's worn in a slot: the equipped item if owned, else the slot's free starter.
function Style.worn(p: any, slot: string): Item?
	ensure(p)
	local id = p.style.equipped[slot]
	local it = if typeof(id) == "string" then byId[id] else nil
	if it and it.slot == slot and Style.owns(p, it.id) then return it end
	for _, x in Style.ITEMS do
		if x.slot == slot and x.price == 0 then return x end
	end
	return nil
end

-- Yard pieces that are placed (owned and on).
function Style.yard(p: any): { Item }
	ensure(p)
	local out = {}
	for _, it in Style.ITEMS do
		if it.slot == "yard" and p.style.equipped["yard:" .. it.id] and Style.owns(p, it.id) then table.insert(out, it) end
	end
	return out
end

function Style.hasSet(p: any, set: string): boolean
	for _, it in Style.ITEMS do
		if it.set == set and not Style.owns(p, it.id) then return false end
	end
	return true
end

-- Free Diamonds from milestones only (D-050): never for logging in, streaks or race places.
Style.EARN_PROMOTION = 25      -- a horse moves up a league
Style.EARN_MONTHLY_RIBBON = 25 -- every monthly job claimed
Style.EARN_FAN_LEVEL = 10      -- each new Fan level

function Style.earn(p: any, amount: number)
	ensure(p)
	local n = math.max(0, math.floor(amount))
	p.diamonds += n
	p.diamondsEarned = (p.diamondsEarned or 0) + n
end

return Style
