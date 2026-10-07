# Art review log

Records the design council's review of the art plan and the art lead's verdict on every generated model. Style rules: [ART_DIRECTION.md](ART_DIRECTION.md). Asset list and spend: [ASSET_PLAN.md](ASSET_PLAN.md). Studio import: [IMPORT.md](IMPORT.md).

## Council review of the Phase 1 plan (2026-10-04)

Phase 2 (generation) was approved with these changes. All seven points were 4/4.

| # | Council decision | How the art applies it |
| --- | --- | --- |
| 1 | **Horse look:** chunky stylized natural horses. Small eyes on the sides of the head, no eyelashes or eyebrows, no big glossy eyes, natural coat and mane colours (no pastels), no flank symbols. Expression comes from ears and tail; ears forward, mouth closed, no foam or strain. The hero horse is never a buckskin mustang with a flowing black mane (Spirit). Hooves are dark and high-contrast on every coat, because the beat lands on the hoof. | Prompts and negatives in `tools/meshy/queue.json` carry every guardrail. The hero coat is a red bay with a short mane. Dark hooves are enforced after generation by `tools/meshy/darken_hooves.py`. |
| 2 | **Race motion:** a fixed gallop pose with a bob for the playtest. The bottom of the bob (a small squash) lands exactly on the beat, with no easing past it. A dust puff and a mane flick play on each beat. The leg cycle comes later and isn't built now. | Motion spec in ART_DIRECTION.md. The mesh is static, so the mane flick is a particle (`fx_mane_flick`) from a crest Attachment, alongside `fx_dust_puff`. Leg cycle noted as later work. |
| 3 | **Rare coats:** natural only, and none in the Phase 1 playtest. | The rare-coat and standing-horse slots were removed from the queue, saving 40 credits. |
| 4 | **Final Burst celebration:** only on the rider's own screen, fired after the burst is scored, never during the live window. A tiny camera punch, off when `GuiService.ReducedMotionEnabled` is on. Never more than 3 flashes a second. Other players see only a small sparkle on that lane's badge. | `burst_rays` (own screen, after scoring) and `lane_sparkle` plus `lane_N_sparkle` (what others see). Timings are in ART_DIRECTION.md. |
| 5 | **Lanes and markers:** lane colours fixed per lane number. "YOU" is huge. Silks come later, as a second marker on the rider. | Lane chips 1–8 unchanged. `you_marker` is now 256 px, gold with a 96 px "YOU", and shown at a constant 180 px on screen. Silks marker noted as later work. |
| 6 | **Tapping:** tap anywhere (any key or gamepad button too), with the hoof ring as the visual target. A big pulsing "GIDDY-UP!" pad at the bottom is the affordance (kids look for a button), but it is not an aim target. While tapping, only the ring is prominent: nothing glows near it, and the ring is an overlay unaffected by lighting. | `giddyup_pad` (idle, pressed, blank). The old round tap button is gone. The ring is a ScreenGui overlay, or a BillboardGui with `LightInfluence = 0`. **Interpretation for the council to check:** the pad pulses before and between stretches, but holds steady (85% opacity, pressed frame on each tap) while rings are on screen. That way the ring is the only rhythmic thing during taps. |
| 7 | **Ring timing:** every ring takes the same time to close, and tempo changes show through the spacing between rings. The coordinator is changing the client code for this. The art must work with several rings on screen. | The dashed tempo-change ring is gone. The ring is drawn with a constant on-screen stroke (UIStroke). Rings spawn at 3.0× the hoof radius, and opacity goes 100% / 70% / 45% from the next ring outward. The review sheet shows 2.0, 2.6 and 1.6 beats per second. |

## Generation verdicts (2026-10-04)

**How each model was checked:**

- The Meshy thumbnail (front three-quarter view).
- A local four-view render of the GLB: both sides, front and top, via `tools/meshy/preview_glb.py`.
- Each model was compared against the council guardrails and the look-alike rules (Spirit, My Little Pony, Horse Life, Wild Horse Islands, real brands).

The rule allowed at most one re-roll per slot.

| Slot | Attempt | Credits | Verdict | Notes |
| --- | --- | --- | --- | --- |
| `horse_gallop` (mesh) | 1 | 30 | **Mesh PASS, texture FAIL** | Clean mid-gallop with four clearly separated legs, neck stretched, small eyes on the sides, ears forward, mouth closed, short swept mane, full tail. No saddle geometry, and the "white saddle cloth" became a smeared white and brown patch on the back that reads as a flank marking. Fixed with a 10-credit retexture instead of a 30-credit re-roll. |
| `horse_gallop_bay` | retexture | 10 | **PASS after hoof fix** | Bare back, even red-bay coat, black points, small star, bridle kept. Hooves came out light tan (the "pale band above the hoof" wording backfired), so they were painted dark locally (`darken_hooves.py`, no credits). |
| `horse_gallop_chestnut` | retexture | 10 | **PASS** | Copper coat, lighter mane and tail, white blaze, white hind socks, dark hooves straight from the prompt ("glossy jet-black hooves"). |
| `horse_gallop_grey` | retexture | 10 | **PASS (note)** | Reads as light grey, close to white. The dapples are faint, the lower legs and hooves dark, the mane silver. Natural, not pastel. |
| `horse_gallop_black` | retexture | 10 | **PASS** | Blue-black coat with grey highlights, white star, short white socks, dark hooves. Normal eyes, not menacing. |
| `horse_gallop_palomino` | retexture | 10 | **PASS** | Golden coat, cream mane and tail, white stripe, dark hooves. Natural gold, not metallic. |
| `finish_post` | 1 | 30 | **PASS (notes)** | Clean, simple geometry with no guardrail issues. It came out as two white poles with a crossbar, gold stars and gold streamers, and the disc reads as black-and-white plaid rather than bold checks. The finish read comes from the checker banner and ground strip. Not re-rolled. |
| `gate_stall` | 1 | 30 | **FAIL** | Broken geometry: huge triangular fins on both sides and shards across the open frame. Kept as `gate_stall_attempt1/` for the record; don't use it. |
| `gate_stall` | 2 (re-roll) | 30 | **PASS (notes)** | The re-prompt used solid shapes and no thin bars. Clean result: padded side walls, a white roof beam with a blank plate, two solid half doors, a grey floor. The walls are paler mint than specified, and the doors are closed half doors (fine left closed or hidden; opening them needs a Blender split). |
| **Total** | | **170 of 200** | | 30 credits unspent. Every figure is Meshy's own `consumed_credits` from each `task.json`. |

Look-alike check, all models: no buckskin and no long flowing black mane (not Spirit), no pastel coats, big eyes, eyelashes or symbols (not My Little Pony), and no fantasy coats (not Horse Life or Wild Horse Islands). No real racecourse, sponsor or silks.

Hoof check, all five coats: after `darken_hooves.py`, every hoof is near-ink charcoal (`#26262C`), so it stands out against the dirt track (`#C68A52`). On the chestnut and black, the white socks add a light band above the dark hoof.

## Open items for the council or David

1. **No saddle on the horses.** Meshy couldn't build one, so the saddle cloth is now a separate lane-coloured part made in Studio (P0, see IMPORT.md). A simple saddle mesh could come later.
2. **The grey reads near-white.** Accept it, or spend 10 credits on a darker dapple retexture (budget allows).
3. **The finish post disc is plaid, not bold checks.** Accept it (the banner carries the finish read), or re-roll for 30 credits, which would reach the 200 cap.
4. **Pad pulse interpretation** (council 6 above): confirm "steady during stretches".
5. **The main checkout didn't ignore `Models/`.** The coordinator's note said it did, but `main` has no such rule yet. I added a self-ignoring `Models/.gitignore` (`*`) in the main checkout so the 175 MB of raw output can't be committed by accident. Merging this PR adds `Models/` to the repo `.gitignore`.
6. ~~**Nothing is uploaded to Roblox.**~~ Done 2026-10-04 with David's approval (LlamaWorks group); see IMPORT.md.

## World set verdicts (2026-10-04)

Models for the world in `docs/WORLD_DESIGN.md`: standing horses, more coats, foals, the stable, care props, the garden, Fair Street and trail decor. Each was checked the same way (Meshy thumbnail plus the four-view `preview_glb.py` render; horses also with the `darken_hooves.py` side view), with at most one re-roll per slot. Credits are Meshy's `consumed_credits`.

| Slot | Credits | Verdict | Notes |
| --- | --- | --- | --- |
| `horse_stand` (mesh) | 30 | PASS | Calm square stance, four separate legs, hooves down, head up, small side eyes, ears forward, bridle, bare back. Chunkier than the gallop mesh (thicker crest mane, a little leg feathering). Base not uploaded. |
| `horse_stand_` bay, chestnut, grey, black, palomino, appaloosa, buckskin, white, chestnut_blaze | 9 × 10 | PASS | Match the gallop coats. Bay got a blaze rather than a star. |
| `horse_stand_dun`, `horse_gallop_dun` | 2 × 10 | PASS (note) | Sandy with dark brown points and a dorsal stripe; close to the buckskin at a glance (brown points vs black). |
| `horse_stand_pinto`, `horse_gallop_pinto` | 2 × (10 + 10) | PASS on re-roll | First try was a brown horse with one small white flank patch. The re-roll asked for "about half brown, half white" tobiano. The gallop pinto is still less bold than the standing one. |
| `horse_stand_roan`, `horse_gallop_roan` | 2 × (10 + 10) | PASS after local fix | First try was a plain chestnut (Meshy ignores "mixed white hairs"). The re-roll gave a pastel pink body and a fantasy bright-red mane. `tools/meshy/recolor.py roan` turns the reds dark chestnut and the body rosy grey with flecks (a natural strawberry roan), at no cost. |
| `horse_gallop_` appaloosa, buckskin, white, chestnut_blaze | 4 × 10 | PASS | |
| `foal_stand` (mesh) + bay, chestnut, grey | 30 + 3 × 10 | PASS | Long legs, fluffy short mane, small side eyes. The grey is warm grey-fawn. Foals are taller than long, so they are sized by height (4 studs, about two thirds of a standing adult) instead of 5 studs nose to tail, which would have made them taller than the adults. |
| `stable_barn` | 30 | PASS (notes) | Red siding, white trim and X braces, two open stall bays beside a closed centre door, blank sign board. Gable roof with a dormer instead of a gambrel. |
| `hay_bale`, `grooming_brush`, `wheelbarrow`, `noticeboard`, `saddle_rack` | 5 × 30 | PASS | |
| `feed_bucket`, `post_box` | 2 × 30 | PASS (notes) | Bucket has no handle and a small grain spill at its foot; the mailbox has two little flags. |
| `water_trough` | 30 + 30 | PASS on re-roll (note) | First try was a square tub with a stray plank standing up like a backrest. The re-roll is a good long trough, but its inside is pale wood with no water: add a blue water part in game (it can rise when the fill-water chore is done). |
| `pitchfork` | 30 + 30 | PASS on re-roll (note) | First try read as a sceptre or mace. The re-roll is a toy fork with four rounded tines; the grip has odd knobs. |
| `carrot_crop`, `oat_crop`, `garden_bed` | 3 × 30 | PASS | |
| `apple_tree_small` | 30 | PASS after local fix | The canopy came out brick red and hid the apples. `recolor.py canopy` turns the leaves green and keeps the apples red. |
| `feed_store` | 30 | PASS (note) | Yellow siding, green roof, striped awning, sacks. No blank sign board: add a sign part for the game's text. |
| `vet_clinic` | 30 | PASS | White and mint, horseshoe-with-heart emblem, no cross anywhere (checked all four views). |
| `market_corral_booth` | 30 | PASS (notes) | The brief said "ticket-booth style"; the prompt avoided the word, because ticket windows read as betting windows. A blank board sticks out sideways. |
| `training_shed`, `trail_gate_arch` | 2 × 30 | PASS | |
| `race_board_frame` | 30 | PASS after local fix | Came with a wide red ground disc (a base). `tools/meshy/trim_base.py` removed it. Blank face, no numbers. |
| `lantern_post`, `bench`, `rosette_ribbon`, `horseshoe_decor`, `log_jump` | 5 × 30 | PASS | |
| `picnic_table`, `trophy_cup`, `wooden_bridge`, `hay_cart` | 4 × 30 | PASS (notes) | Bench end caps read as wheels end-on; the cup is pale blue with gold handles; the bridge is short and wide; the cart wheels have thin spokes. |
| `flower_planter` | 30 | **FAIL, dropped** | The "flowers" are dry orange shards that read as dead leaves. No budget left to re-roll. |
| **Total** | **1,280** | | 32 text-to-3D slots (960), 22 retextures (220), 6 re-rolls (100). Balance 1,740 → 460, above the 450 floor. |

Guardrail check, every model: no text, logos, numbers or prices; no red cross; no whip, crop or rider; no casino or wagering shapes; horses calm with small side eyes, ears forward, mouths closed, natural coats and dark hooves (every coat run through `darken_hooves.py`, which now ignores a tail that hangs low on a standing horse).

## Horse life stage 5 verdicts (2026-10-07, D-060)

Balance checked before each batch: 460 → 360 (floor 150). The plan asked for about 60 credits; the bell's re-roll took it to 100.

| Slot | Credits | Verdict | Notes |
| --- | --- | --- | --- |
| `rosette_wall` | 30 | PASS (note) | Red frame, little shingle roof, two short legs, cream backboard with hooks and two shelves, empty and ready to fill (stage 8 hangs the rosettes). A pale cross-brace shape is painted on the back board. Stands in the yard, visible from the gate. |
| `post_box_carrots` | 10 (retexture of `post_box`) | PASS (note) | Same mailbox with both flags carrot orange. No carrots show on the door (a retexture keeps the mesh and didn't paint them), so on carrot days the game also puts a small part-built carrot pile on the lid. |
| `visitor_bell` | 30 + 30 | PASS on re-roll (notes) | First try FAIL: no post, just a bell on a floating arm above a separate flower pot. The re-roll is one tall post with the brass bell at the top and a red flower box at the foot (asked for halfway up), on a small grey stone base. |
| **Total** | **100** | | 2 text-to-3D, 1 retexture, 1 re-roll. Uploaded to the LlamaWorks group; moderation pending. |

Guardrail check: no text, numbers or logos; nothing that reads as a counter, score or ranking; no wagering shapes.

## Horse life stage 4: Spa Day (2026-10-07)

Plan `docs/plans/horse-life-and-retention.md` stage 4 (≈ 90 credits asked). The balance was checked before every job (another builder was using Meshy for stage 5): 360 before, 250 after, never near the 150 floor. Checked on the Meshy thumbnails. Uploaded to the LlamaWorks group with `tools/roblox/upload_assets.py` (moderation pending; the game keeps its placeholder shapes until Roblox approves them).

| Slot | Credits | Verdict | Notes |
| --- | --- | --- | --- |
| `spa_wash_stall` | 30 | PASS | Pale-blue open bay, white scalloped roof, green hose on a wall reel, soapy bucket, yellow sponge, dark mat. No horse, no cross. |
| `horse_lie_bay` | 30 | PASS (note) | Lying in a sphinx pose with the front legs stretched forward, head up, ears forward, calm, bridle, healthy glossy coat: reads as resting, not unwell. Hooves dark with pale tips; `darken_hooves.py` only finds the legs of a standing horse (it found 1 of 4), so the raw file is uploaded. No straw on the model: it lies on the barn's straw floor. |
| `horse_lie_palomino`, `horse_lie_grey` | 2 × 10 | PASS | Retextures of the bay (the starter coats). Golden with a cream mane and black hooves; steel grey with dapples, silver mane, dark hooves. The other nine coats sink a standing horse into a straw bed instead (90 credits saved). |
| `towel_rack` | 30 | PASS (note) | Honey-wood stand with a red-and-white striped towel over the top; the brush caddy is small and odd-shaped. |
| **Total** | **110** | | 3 text-to-3D (90) + 2 retextures (20). Balance 360 → 250. |

## Horse life stage 6: reasons to come back (2026-10-07)

Plan `docs/plans/horse-life-and-retention.md` stage 6 (≈ 60 credits asked); this stage had a hard cap of 50 and a floor of 150 (stage 7 needs the rest). The balance was checked before each job: 250 before, 240 after the retexture, 210 at the end. Checked on the Meshy thumbnails. Uploaded to the LlamaWorks group with `tools/roblox/upload_assets.py` (moderation pending; the game keeps part-built stand-ins until Roblox approves them).

| Slot | Credits | Verdict | Notes |
| --- | --- | --- | --- |
| `welcome_hay_bale` | 10 | PASS (note) | Retexture of `hay_bale` (a new model would have cost 30): golden straw with one wide shiny red ribbon band round the middle. A retexture can't add a bow, carrots or a gift tag, so the client adds a part-built red bow, two carrots and an apple on top. Asset 115478221440793. |
| `photo_frame_stand` | 30 | PASS (note) | Sky-blue and cream gabled frame with red, yellow, blue and orange bunting along the top and a gold rosette with a blue tail in the corner. Asked for an open centre on legs; it has a painted hills-and-pine backdrop in the frame and a flat base, which works as a backdrop to pose a horse in front of. No text. Asset 138175926810022. |
| **Total** | **40** | | 1 text-to-3D (30) + 1 retexture (10), no re-rolls. Balance 250 → 210. |

Guardrail check: no text, numbers or logos; nothing that reads as a counter, score, ranking or offer; no wagering shapes.
## Horse life stage 7: Careers, Legend Retirement and Rehoming (2026-10-07, D-059)

The plan asked for about 90 credits; this stage was capped at 50 with a 150 floor (another builder was spending at the same time), so all three are retextures of reviewed meshes (10 each) instead of text-to-3D. Balance checked before each job: 210 → 200 → 190 → 180. Checked on the Meshy thumbnails. Uploaded to the LlamaWorks group with `tools/roblox/upload_assets.py`; all three Approved by Roblox moderation.

| Slot | Credits | Verdict | Notes |
| --- | --- | --- | --- |
| `legend_paddock_arch` | 10 (retexture of `trail_gate_arch`) | PASS (note) | White-painted posts and beam, a gold disc in the middle of the beam, the hanging board cream with a gold border, laurel garlands in green and gold, gold and white flowers at the feet. It keeps the log-arch mesh, so no star finials, bunting or horseshoe shape, and the board is blank (no horseshoe painted). Sized 14 studs wide (about 10 tall). |
| `riding_school_sign` | 10 (retexture of `noticeboard`) | PASS | Sky-blue roof, cream posts and frame, a big yellow sun over green meadow hills with tiny flowers, plain sky in the upper middle for the game's "Sunny Meadow Riding School" overlay. The noticeboard's fold line on the face reads as a hill edge. Replaces the plan's `riding_school_trailer`. Sized 8 studs tall (about 7 wide). |
| `legend_plaque_post` | 10 (retexture of `noticeboard`) | PASS (notes) | Royal-blue roof, honey-wood posts, a plain cream face in a pale gold frame (less shiny than asked); no rosette was painted, and the noticeboard's dark fold line shows on the lower face. The game's name overlay should cover the face; add a part rosette if one is wanted. Sized 4.5 studs tall. |
| **Total** | **30** | | 3 retextures. Balance 210 → 180. |

Guardrail check: no text, numbers or logos; nothing that reads as a score, ranking or wagering shape.
