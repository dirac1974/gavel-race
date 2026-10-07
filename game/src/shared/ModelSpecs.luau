--!strict
-- Size, facing and collision for every uploaded model slot (MeshAssets). Measurements and
-- reasons: docs/art/IMPORT.md and docs/art/ASSET_PLAN.md.
-- AssetService uses the exact slot first, then the longest matching prefix that ends in "_"
-- (horse_, foal_). A slot with neither keeps the fallback in AssetService and warns.
--   axis    "Y" scales the height to `studs`; "Z" scales the longest horizontal side
--           (nose to tail, or the long side of a prop) to `studs`.
--   studs   target size in studs (about one stud per real foot; an R15 avatar is ~5 studs).
--   yaw     radians turned after import so the model faces -Z. Imported Meshy models already
--           face -Z (horses' heads, building fronts, sign faces), so this is 0 everywhere.
--   collide CanCollide for players. Creatures (prefix slots) are never queryable.

export type Spec = { axis: "Y" | "Z", studs: number, yaw: number, collide: boolean }

local ModelSpecs: { [string]: Spec } = {
	-- Creatures, by prefix: every horse_<coat>, horse_stand_<coat>, horse_gallop_<coat>, foal_stand_<coat>.
	horse_ = { axis = "Z", studs = 8.0, yaw = 0, collide = false },
	-- Foals are taller than long (long legs, head up), so they are sized by height: about two
	-- thirds of a standing adult (6 studs), 3.2 studs nose to tail.
	foal_ = { axis = "Y", studs = 4.0, yaw = 0, collide = false },

	-- Race props (unchanged from the playtest).
	finish_post = { axis = "Y", studs = 14.0, yaw = 0, collide = true },
	gate_stall = { axis = "Y", studs = 8.0, yaw = 0, collide = true },

	-- Your stable and care. The barn is ~40 studs wide at this height.
	stable_barn = { axis = "Y", studs = 32.0, yaw = 0, collide = true },
	hay_bale = { axis = "Y", studs = 3.0, yaw = 0, collide = true },
	water_trough = { axis = "Y", studs = 2.5, yaw = 0, collide = true },
	feed_bucket = { axis = "Y", studs = 1.6, yaw = 0, collide = false },
	grooming_brush = { axis = "Z", studs = 1.2, yaw = 0, collide = false },
	wheelbarrow = { axis = "Y", studs = 3.0, yaw = 0, collide = true },
	pitchfork = { axis = "Y", studs = 5.5, yaw = 0, collide = false },
	noticeboard = { axis = "Y", studs = 8.0, yaw = 0, collide = true },
	post_box = { axis = "Y", studs = 4.5, yaw = 0, collide = true },
	-- Visits (D-060): the post box on carrot days, the bell by the gate, the Rosette Wall (filled in stage 8, D-062).
	post_box_carrots = { axis = "Y", studs = 4.5, yaw = 0, collide = true },
	visitor_bell = { axis = "Y", studs = 5.5, yaw = 0, collide = true },
	rosette_wall = { axis = "Y", studs = 7.5, yaw = 0, collide = true },
	saddle_rack = { axis = "Y", studs = 3.5, yaw = 0, collide = true },

	-- Garden. Crops are sized to sit two to a garden_bed (6 x 2.6 studs).
	carrot_crop = { axis = "Z", studs = 2.4, yaw = 0, collide = false },
	apple_tree_small = { axis = "Y", studs = 12.0, yaw = 0, collide = true },
	oat_crop = { axis = "Z", studs = 2.4, yaw = 0, collide = false },
	garden_bed = { axis = "Z", studs = 6.0, yaw = 0, collide = true },

	-- Fair Street buildings, by height; widths are in docs/art/IMPORT.md (feed store ~45, vet ~44,
	-- market booth ~30, training shed ~38, race board ~24, trail arch ~28 studs wide).
	feed_store = { axis = "Y", studs = 32.0, yaw = 0, collide = true },
	vet_clinic = { axis = "Y", studs = 30.0, yaw = 0, collide = true },
	market_corral_booth = { axis = "Y", studs = 24.0, yaw = 0, collide = true },
	training_shed = { axis = "Y", studs = 24.0, yaw = 0, collide = false },
	race_board_frame = { axis = "Y", studs = 28.0, yaw = 0, collide = true },
	trail_gate_arch = { axis = "Y", studs = 20.0, yaw = 0, collide = false },

	-- Decor and trail.
	lantern_post = { axis = "Y", studs = 9.0, yaw = 0, collide = true },
	bench = { axis = "Y", studs = 3.0, yaw = 0, collide = true },
	picnic_table = { axis = "Y", studs = 3.0, yaw = 0, collide = true },
	trophy_cup = { axis = "Y", studs = 3.0, yaw = 0, collide = false },
	rosette_ribbon = { axis = "Y", studs = 2.5, yaw = 0, collide = false },
	horseshoe_decor = { axis = "Y", studs = 2.5, yaw = 0, collide = false },
	log_jump = { axis = "Y", studs = 3.0, yaw = 0, collide = false },
	wooden_bridge = { axis = "Z", studs = 16.0, yaw = 0, collide = false },
	hay_cart = { axis = "Y", studs = 6.0, yaw = 0, collide = true },
}

return ModelSpecs
