--!strict
-- BarnCatalog (D-070, provisional): the Barn Builder shelf, bought with Green Cash only. One data
-- module so the economy analyst's prices can be swapped in one place (docs/reviews/aaa-2026-10-11/
-- greencash-plan.md, "Final prices (sim)"; tests/test_greencash_catalog.py keeps it in step with
-- sims/economy.py CATALOG by tier and price).
-- Every item is a look: never stats, Rating, Energy, win chance or Diamonds. Nothing is random,
-- timed or limited, and nothing here is ever sold for Diamonds (Style keeps the two apart).
-- Tiers open by the highest league any of your horses has ever reached (Profile.bestLeague, a
-- high-water mark that never goes down). Things every yard already has for free (StableService:
-- hay bale, trough, feed bucket, wheelbarrow, horseshoe, photo board) are sold only as variants
-- that swap in at the same spot. Gold and Champion use fair materials (painted wood, rope,
-- bunting colours), never chrome. Ids start "bb_" so they never meet a Tack & Paint id.
-- Icons: never a win (🏵️ 🎖️ 🏅 🏆 🥇 🥈 🥉), never 🎀 (monthly stamps) or ❤️-like hearts (care).
-- Fields:
--   slot   "paint" | "cloth" | "helmet" | "plate" (worn like Tack & Paint looks), "doors" | "trim" |
--          "frame" | "fence" (one barn look each), "yard" (each placed on its own)
--   spot   where it shows in your plot: { inward, across } (plot space, StableService.plotCF), or an
--          anchor name from ANCHORS (a free prop it swaps for, or a part of the barn)
--   build  how StableService builds it (yard pieces): "tree" | "logJump" | "swapTrough" |
--          "swapBarrow" | "swapBucket" | "swapHay" | "swapShoe" | "swapPhoto" | "hayloft" |
--          "bunting" | "weathervane" | "gateArch"

local BarnCatalog = {}

export type Item = {
	id: string,
	name: string,
	tier: string,   -- the league that opens it
	price: number,  -- Green Cash
	slot: string,
	emoji: string,
	spot: any,      -- { number, number } | string
	build: string?,
	color: string?,
	color2: string?,
	color3: string?,
	pattern: string?,
	model: string?,
}

BarnCatalog.TIERS = { "Rookie", "Bronze", "Silver", "Gold", "Champion" }
BarnCatalog.TIER_LABEL = { Rookie = "Rookie", Bronze = "Bronze", Silver = "Silver", Gold = "Gold", Champion = "Champion" }

-- Named spots (inward, across) to walk to: the barn front is fixed at inward 88 (StableService:
-- back = PLOT_DEPTH - 6, BARN_D = 24), so these hold whatever the barn's width.
BarnCatalog.ANCHORS = {
	barn = { 70, 0 },        -- paints, trim, doors, plates: stand back and see the whole barn
	trough = { 76, -35 },    -- the free water trough's spot (front - 6, -(PLOT_FRONT/2 - 10))
	hay = { 76, 35 },        -- the free hay bale's spot
	barrow = { 68, 29 },     -- the free wheelbarrow's spot
	bucket = { 80, -12 },    -- by the first stall
	horseshoe = { 72, 0 },   -- over the barn front
	photo = { 46, -4 },      -- the photo board (54, -4)
	wall = { 44, 12 },       -- the Rosette Wall (52, 12)
	fence = { 10, 0 },       -- the front fence, by the gate
	roof = { 62, 0 },        -- the ridge: step back to look up
	gate = { 14, 0 },        -- inside the gate
	saddle = { 16, 0 },      -- worn looks (cloth, helmet): your own yard, where you hop on
}

BarnCatalog.ITEMS = {
	-- Starter (every stable) ---------------------------------------------------------------
	{ id = "bb_paint_cherry", name = "Cherry barn paint", tier = "Rookie", price = 300, slot = "paint", emoji = "🍒",
		color = "D93A4A", color2 = "2B2B30", color3 = "FBFBF5", spot = "barn" },
	{ id = "bb_paint_sky", name = "Sky barn paint", tier = "Rookie", price = 350, slot = "paint", emoji = "🩵",
		color = "8EC9F0", color2 = "2E5AAC", color3 = "FBFBF5", spot = "barn" },
	{ id = "bb_paint_mint", name = "Mint barn paint", tier = "Rookie", price = 400, slot = "paint", emoji = "🌱",
		color = "8FD9C4", color2 = "17A398", color3 = "FBFBF5", spot = "barn" },
	{ id = "bb_paint_sunny", name = "Sunny barn paint", tier = "Rookie", price = 450, slot = "paint", emoji = "🌻",
		color = "FFD98A", color2 = "C0392B", color3 = "FBFBF5", spot = "barn" },
	{ id = "bb_cloth_sun", name = "Sunny saddle cloth", tier = "Rookie", price = 300, slot = "cloth", emoji = "🟨",
		color = "FFD23F", pattern = "plain", spot = "saddle" },
	{ id = "bb_cloth_sky", name = "Sky saddle cloth", tier = "Rookie", price = 350, slot = "cloth", emoji = "🟦",
		color = "8EC9F0", pattern = "plain", spot = "saddle" },
	{ id = "bb_cloth_berry", name = "Berry saddle cloth", tier = "Rookie", price = 400, slot = "cloth", emoji = "🫐",
		color = "C2185B", pattern = "plain", spot = "saddle" },
	{ id = "bb_plates_wood", name = "Carved wood name plates", tier = "Rookie", price = 350, slot = "plate", emoji = "🪵",
		color = "C48A55", spot = "barn" },
	{ id = "bb_trough_painted", name = "Painted water trough", tier = "Rookie", price = 300, slot = "yard", emoji = "💧",
		color = "4FA9DB", build = "swapTrough", spot = "trough" },
	{ id = "bb_barrow_flowers", name = "Flower-box wheelbarrow", tier = "Rookie", price = 400, slot = "yard", emoji = "🌷",
		color = "E5484D", build = "swapBarrow", spot = "barrow" },
	{ id = "bb_bucket_painted", name = "Painted feed bucket", tier = "Rookie", price = 250, slot = "yard", emoji = "🪣",
		color = "17A398", build = "swapBucket", spot = "bucket" },
	{ id = "bb_hay_bow", name = "Hay bale with a bow", tier = "Rookie", price = 250, slot = "yard", emoji = "🌾",
		color = "E5484D", build = "swapHay", spot = "hay" },
	-- Bronze ---------------------------------------------------------------------------------
	{ id = "bb_apple_tree_1", name = "Apple tree", tier = "Bronze", price = 700, slot = "yard", emoji = "🍎",
		model = "apple_tree_small", build = "tree", spot = { 28, 40 } },
	{ id = "bb_apple_tree_2", name = "Second apple tree", tier = "Bronze", price = 700, slot = "yard", emoji = "🍏",
		model = "apple_tree_small", build = "tree", spot = { 72, 40 } },
	{ id = "bb_horseshoe_red", name = "Red horseshoe", tier = "Bronze", price = 600, slot = "yard", emoji = "🐴",
		color = "C0392B", build = "swapShoe", spot = "horseshoe" },
	{ id = "bb_helmet_orange", name = "Orange helmet", tier = "Bronze", price = 500, slot = "helmet", emoji = "🟠",
		color = "FF9F1C", spot = "saddle" },
	{ id = "bb_helmet_sky", name = "Sky helmet", tier = "Bronze", price = 500, slot = "helmet", emoji = "🔵",
		color = "4FA9DB", spot = "saddle" },
	{ id = "bb_helmet_grass", name = "Grass helmet", tier = "Bronze", price = 500, slot = "helmet", emoji = "🟢",
		color = "46C46A", spot = "saddle" },
	{ id = "bb_cloth_hearts", name = "Hearts saddle cloth", tier = "Bronze", price = 600, slot = "cloth", emoji = "🧵",
		color = "F7B2C4", pattern = "hearts", spot = "saddle" },
	{ id = "bb_cloth_daisy", name = "Daisy saddle cloth", tier = "Bronze", price = 600, slot = "cloth", emoji = "🌼",
		color = "2F5D3A", pattern = "daisies", spot = "saddle" },
	{ id = "bb_cloth_rainbow", name = "Rainbow saddle cloth", tier = "Bronze", price = 600, slot = "cloth", emoji = "🌈",
		color = "FBFBF5", pattern = "rainbow", spot = "saddle" },
	{ id = "bb_stall_doors", name = "Stall-door paint", tier = "Bronze", price = 800, slot = "doors", emoji = "🚪",
		color = "2E9E5B", spot = "barn" },
	-- Silver ---------------------------------------------------------------------------------
	{ id = "bb_log_jump", name = "Yard log jump", tier = "Silver", price = 1500, slot = "yard", emoji = "🪵",
		model = "log_jump", build = "logJump", spot = { 50, -18 } },
	{ id = "bb_frame_silver", name = "Silver wall frame", tier = "Silver", price = 1200, slot = "frame", emoji = "🖼️",
		color = "D5DCE6", color2 = "8A93A6", spot = "wall" },
	{ id = "bb_fence_paint", name = "Sky fence paint", tier = "Silver", price = 1000, slot = "fence", emoji = "🎨",
		color = "7EC8E3", spot = "fence" },
	{ id = "bb_paint_birch", name = "Silver Birch barn", tier = "Silver", price = 1200, slot = "paint", emoji = "🌳",
		color = "F4F0E8", color2 = "8A8F99", color3 = "2B2B30", spot = "barn" },
	{ id = "bb_photo_flowers", name = "Flower photo board", tier = "Silver", price = 1400, slot = "yard", emoji = "🌸",
		color = "F7B2C4", build = "swapPhoto", spot = "photo" },
	-- Gold (painted wood, rope and bunting colours; never chrome) -------------------------------
	{ id = "bb_trim_gold", name = "Gold-painted barn trim", tier = "Gold", price = 2000, slot = "trim", emoji = "🟡",
		color = "E3B341", spot = "barn" },
	{ id = "bb_frame_bunting", name = "Bunting wall frame", tier = "Gold", price = 2500, slot = "frame", emoji = "🎪",
		color = "E3B341", color2 = "2F6FDE", spot = "wall" },
	{ id = "bb_hayloft", name = "Hay-loft doors and sign", tier = "Gold", price = 3500, slot = "yard", emoji = "🪜",
		color = "C48A55", build = "hayloft", spot = "roof" },
	{ id = "bb_bunting", name = "County-fair bunting", tier = "Gold", price = 1800, slot = "yard", emoji = "🎏",
		build = "bunting", spot = "barn" },
	-- Champion -------------------------------------------------------------------------------
	{ id = "bb_weathervane", name = "Weathervane", tier = "Champion", price = 5000, slot = "yard", emoji = "🧭",
		color = "2B2B30", build = "weathervane", spot = "roof" },
	{ id = "bb_paint_champion", name = "Champion barn paint", tier = "Champion", price = 4000, slot = "paint", emoji = "👑",
		color = "4B3F8C", color2 = "F4EBD9", color3 = "FFD23F", spot = "barn" },
	{ id = "bb_gate_arch", name = "Grand gate arch", tier = "Champion", price = 6000, slot = "yard", emoji = "🏛️",
		model = "trail_gate_arch", build = "gateArch", spot = "gate" },
	{ id = "bb_frame_champion", name = "Champion wall frame", tier = "Champion", price = 4000, slot = "frame", emoji = "🖼️",
		color = "B9B9F0", color2 = "4B3F8C", spot = "wall" },
} :: { Item }

-- The tier's place in TIERS (1 = Starter), or nil.
function BarnCatalog.tierIndex(tier: string?): number?
	return if tier then table.find(BarnCatalog.TIERS, tier) else nil
end

-- (inward, across) to walk to for an item: its own spot, a named anchor, or the barn.
function BarnCatalog.lookAt(it: Item): (number, number)
	local s = it.spot
	if typeof(s) == "table" then return s[1] - 10, s[2] end
	local a = BarnCatalog.ANCHORS[s] or BarnCatalog.ANCHORS.barn
	return a[1], a[2]
end

return BarnCatalog
