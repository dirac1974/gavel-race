# Playtest asset plan

Status: **Phase 2 done and the world set done (2026-10-04).** The playtest set below was council-approved and generated first; the world set (standing horses, more coats, foals, stable, care, garden, Fair Street, decor) follows in [World set](#world-set-2026-10-04). Everything that passed review is uploaded to Roblox (LlamaWorks group). Verdicts: [ART_REVIEW.md](ART_REVIEW.md). Style: [ART_DIRECTION.md](ART_DIRECTION.md). Studio import: [IMPORT.md](IMPORT.md).

## Credits spent

| Slot | Kind | Credits | Verdict |
| --- | --- | --- | --- |
| `horse_gallop` | text-to-3D (preview 20 + refine 10) | 30 | Mesh pass; texture fail (saddle patch), fixed by the bay retexture |
| `horse_gallop_bay` | retexture | 10 | Pass after the local hoof fix |
| `horse_gallop_chestnut` | retexture | 10 | Pass |
| `horse_gallop_grey` | retexture | 10 | Pass (reads light grey) |
| `horse_gallop_black` | retexture | 10 | Pass |
| `horse_gallop_palomino` | retexture | 10 | Pass |
| `finish_post` | text-to-3D | 30 | Pass (two poles, plaid disc) |
| `gate_stall`, attempt 1 | text-to-3D | 30 | Fail (broken fins and shards); kept as `gate_stall_attempt1/` |
| `gate_stall`, re-roll | text-to-3D | 30 | Pass (paler mint, closed half doors) |
| **Total** | | **170 of the 200 cap** | 30 unspent |

The figures are Meshy's own `consumed_credits` from each `task.json`. The tool's `status` line shows 140 because the failed gate attempt lives outside the slot folder. The rare coat and the standing horse were dropped by the council (no rare coats in Phase 1), so nothing was spent on P2.

## Asset list

| # | Asset | 2D/3D | Tool | Credits | Priority | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Racehorse, mid-gallop (`horse_gallop` mesh) | 3D | Meshy text-to-3D | 30 | P0 | Done |
| 2 | Coats: bay, chestnut, grey, black, palomino (`horse_gallop_*`) | 3D | Meshy retexture + `darken_hooves.py` | 50 | P0 | Done; use the `*_hoofed.glb` files |
| 3 | Finish post (`finish_post`), one per rail | 3D | Meshy text-to-3D | 30 | P0 | Done |
| 4 | Rails, track surface, lane chalk, finish banner and ground line | 3D | Roblox parts + `finish_checker` tile | 0 | P0 | Spec in IMPORT.md |
| 5 | Saddle cloth part with the lane pattern | 3D/2D | Studio Part + `lane_N_blank` decal | 0 | P0 (was P1) | Spec in IMPORT.md; replaces the saddle Meshy couldn't build |
| 6 | Hoof icon + ring overlay (several rings at once) | 2D | `tools/ui/make_ui_svgs.py` | 0 | P0 | Done; the ring is built from UIStroke, PNG fallback |
| 7 | GIDDY-UP pad: idle, pressed, blank | 2D | same | 0 | P0 | Done |
| 8 | Final Burst bar, glow, marker + `burst_rays` | 2D | same | 0 | P0 | Done |
| 9 | Tap-result shapes: Perfect, Great, Good, Okay, Miss, Steady | 2D | same | 0 | P0 | Done |
| 10 | Lane chips 1–8 (+ blank) and `lane_sparkle` / `lane_N_sparkle` | 2D | same | 0 | P0 | Done |
| 11 | Huge YOU marker (+ blank) | 2D | same | 0 | P0 | Done |
| 12 | Win chance up/down, ribbons Blue/Red/Yellow/White, finish checker | 2D | same | 0 | P0 | Done |
| 13 | Beat effects: `fx_dust_puff`, `fx_mane_flick` | 2D | same | 0 | P0 | Done; particle textures, tinted per track and mane |
| 14 | Starting gate stall (`gate_stall`), cloned × 8 | 3D | Meshy text-to-3D | 30 + 30 re-roll | P1 | Done |
| 15 | Jockey riding pose + hands-and-heels pump | Anim | Roblox Animation Editor (R15) | 0 | P1 | To do in Studio; never a whip |
| 16 | Top Fans badge, cheer/clap icon, paper panel 9-slice, confetti, Green Cash token | 2D | `make_ui_svgs.py` | 0 | P1 | Not drawn yet |
| 17 | Fan level badges, stand flags | 2D | same | 0 | P2 | Not drawn yet |
| 18 | Silks marker on the rider; horse leg cycle | 2D/3D | later | 0 | Later | Council: later, not now |

UI files: 51 SVGs in `assets/ui/`, the review sheet `assets/ui/_sheet.svg`, and 51 PNGs in `assets/ui/png/`. PNGs are 2× the SVG size: 256 px for every 128 px icon, 512 px for the YOU marker, 1024 × 352 for the pad.

## How the horse moves without a rig

Covered in ART_DIRECTION.md, "Horse motion". In short: a static mid-gallop mesh moved by CFrame. A beat-synced bob puts its squash exactly on the beat, with a dust puff and a mane-flick particle each beat. Surges lean forward; mashing gives a skip-hop. A leg cycle comes later and isn't built.

## Pipeline

1. Update the prompt in `tools/meshy/queue.json` and run `python tools/meshy/meshy.py text|retexture <slot> --dry-run --models-root "<main checkout>/Models"`.
2. Run the same command without `--dry-run`. Outputs (FBX, GLB, texture, thumbnail, `task.json` with the exact request bodies and credits) land in the main checkout's `Models/generated/<slot>/`, which is ignored by git.
3. Review with the thumbnail plus `python tools/meshy/preview_glb.py <glb> out.png` (both sides, front, top).
4. For horses, run `python tools/meshy/darken_hooves.py <slots...> --models-root ...`. It writes `*_hoofed.glb`, `*_base_color_hoofed.png` and a `*_hoof_check.png` side view. Rerun it after any coat re-roll: all coats share the mesh's UVs, so one hoof mask fits all.
5. Import by hand per IMPORT.md. Uploading needs David.

- **2D:** `python tools/ui/make_ui_svgs.py` rewrites every SVG, the sheet and the PNGs (`pip install resvg-py`; Pillow isn't needed for this step). `--no-png` skips the PNGs.
- **Tool:** `meshy.py` is copied from the owner's haunt-nyc repo, with only the name strings changed. It reads the key from `MESHY_API_KEY` only, and no key was ever read or printed. The text-to-3D API has no negative-prompt field, so the `negative` entries are review notes.
- **Lessons for next time:**
  - Meshy won't build a saddle or a thin-barred frame. Ask for solid shapes, and make tack separately.
  - A "pale band above the hoof" turns the whole hoof pale. Ask for "glossy jet-black hooves on every leg".
  - The origin comes back at the bounding-box centre, not the bottom.

## Meshy dry-run of the final queue (2026-10-04)

These are the request bodies that were sent (the retextures show the real source task id). Each slot was dry-run before its real call. The first gate attempt's prompt is recorded in `Models/generated/gate_stall_attempt1/task.json`; it asked for a "tube frame" with padded bars and failed.

<details><summary>Dry-run output (status + every request body)</summary>

```text
slot_id                       kind         tris  rig model    rigged   est  spent
horse_gallop                  creature     8000  no  done     -         30     30
horse_gallop_bay              creature     8000  no  done     -         10     10
horse_gallop_chestnut         creature     8000  no  done     -         10     10
horse_gallop_grey             creature     8000  no  done     -         10     10
horse_gallop_black            creature     8000  no  done     -         10     10
horse_gallop_palomino         creature     8000  no  done     -         10     10
finish_post                   prop         3000  no  done     -         30     30
gate_stall                    prop         3000  no  done     -         30     30

8 slots, estimated 140 credits for the full queue (one attempt each), 140 spent so far.
outputs: Models/generated/<slot_id>/
[dry-run] status never calls the network.

$ python tools/meshy/meshy.py text horse_gallop --dry-run --models-root <main>/Models
slot horse_gallop (creature) -> Models/generated/horse_gallop  est. 30 credits
step 1/2 preview:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "preview",
  "prompt": "full body stylized thoroughbred racehorse in a smooth mid-gallop side pose, front legs reaching forward, hind legs pushing back, all four legs clearly separated, neck stretched forward, small calm dark eyes on the sides of the head, ears pricked forward, mouth closed, glossy bay coat: reddish brown body, black lower legs, short neat black mane, full black tail streaming behind, dark charcoal hooves with a thin pale cream band just above each hoof, chunky toy-like proportions, sturdy neck and legs, large rounded hooves, simple brown bridle and reins, small flat brown racing saddle on a plain white saddle cloth, riderless, stylized cartoon game asset, chunky readable silhouette, soft hand-painted colors, bright sunny daylight palette, single object, no base, no text, no logos",
  "ai_model": "latest",
  "topology": "triangle",
  "target_polycount": 8000,
  "should_remesh": true,
  "target_formats": [
    "fbx",
    "glb"
  ],
  "origin_at": "bottom"
}
step 1b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<preview_task_id> until SUCCEEDED
step 2/2 refine:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "refine",
  "preview_task_id": "<preview_task_id>",
  "enable_pbr": false,
  "texture_resolution": "2k",
  "target_formats": [
    "fbx",
    "glb"
  ],
  "origin_at": "bottom",
  "texture_prompt": "glossy healthy bay horse coat, warm reddish brown body, black mane, tail and lower legs, dark charcoal hooves with a thin pale cream band above each hoof, small dark eyes, plain white saddle cloth, simple brown leather bridle and saddle, soft hand-painted shading, bright daylight colors"
}
step 2b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<refine_task_id>, download model_urls.fbx/glb + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py text finish_post --dry-run --models-root <main>/Models
slot finish_post (prop) -> Models/generated/finish_post  est. 30 credits
step 1/2 preview:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "preview",
  "prompt": "a tall chunky finish line post for a cartoon countryside horse race, a thick round white painted wooden pole, topped by a large round sign disc with a bold black and white checkered pattern on both faces, a small golden star on top of the disc, three short ribbon streamers in red, yellow and sky blue tied just under the disc, friendly toy-like proportions, stylized cartoon game asset, chunky readable silhouette, soft hand-painted colors, bright sunny daylight palette, single object, no base, no text, no logos",
  "ai_model": "latest",
  "topology": "triangle",
  "target_polycount": 3000,
  "should_remesh": true,
  "target_formats": [
    "fbx",
    "glb"
  ],
  "origin_at": "bottom"
}
step 1b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<preview_task_id> until SUCCEEDED
step 2/2 refine:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "refine",
  "preview_task_id": "<preview_task_id>",
  "enable_pbr": false,
  "texture_resolution": "2k",
  "target_formats": [
    "fbx",
    "glb"
  ],
  "origin_at": "bottom",
  "texture_prompt": "clean white painted wood, crisp black and white checkered disc, warm golden star, bright satin ribbon streamers, soft hand-painted shading"
}
step 2b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<refine_task_id>, download model_urls.fbx/glb + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py text gate_stall --dry-run --models-root <main>/Models
slot gate_stall (prop) -> Models/generated/gate_stall  est. 30 credits
step 1/2 preview:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "preview",
  "prompt": "a single starting gate stall for a cartoon horse race built from simple solid chunky shapes, two thick soft green padded side walls, a thick rounded white top beam joining them with a large blank light grey square sign plate on the front, two short solid white half doors at the front, a flat dark grey rubber floor, an open walk-through bay between the walls, friendly toy-like proportions, stylized cartoon game asset, chunky readable silhouette, soft hand-painted colors, bright sunny daylight palette, single object, no base, no text, no logos",
  "ai_model": "latest",
  "topology": "triangle",
  "target_polycount": 3000,
  "should_remesh": true,
  "target_formats": [
    "fbx",
    "glb"
  ],
  "origin_at": "bottom"
}
step 1b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<preview_task_id> until SUCCEEDED
step 2/2 refine:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "refine",
  "preview_task_id": "<preview_task_id>",
  "enable_pbr": false,
  "texture_resolution": "2k",
  "target_formats": [
    "fbx",
    "glb"
  ],
  "origin_at": "bottom",
  "texture_prompt": "soft green padded walls, glossy white painted beam and doors, plain light grey blank plate, dark grey rubber floor, soft hand-painted shading"
}
step 2b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<refine_task_id>, download model_urls.fbx/glb + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py retexture horse_gallop_bay --dry-run --models-root <main>/Models
slot horse_gallop_bay: retexture of horse_gallop -> Models/generated/horse_gallop_bay  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "01a10a0c-b915-7718-a330-63c84847af36",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, small side eyes and bridle, bare back with no saddle and no saddle cloth: the coat colour continues evenly over the back and flanks with no patches, bay coat: warm reddish brown body, black mane, black tail and black lower legs, a small white star on the forehead, dark charcoal hooves with a thin pale cream band above each hoof, natural colors, glossy healthy coat, soft hand-painted shading, bright daylight colors",
  "ai_model": "latest",
  "enable_original_uv": true,
  "enable_pbr": false,
  "texture_resolution": "2k",
  "target_formats": [
    "fbx",
    "glb"
  ]
}
then: poll GET https://api.meshy.ai/openapi/v1/retexture/<task_id>, download model_urls.glb/fbx + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py retexture horse_gallop_chestnut --dry-run --models-root <main>/Models
slot horse_gallop_chestnut: retexture of horse_gallop -> Models/generated/horse_gallop_chestnut  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "01a10a0c-b915-7718-a330-63c84847af36",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, small side eyes and bridle, bare back with no saddle and no saddle cloth: the coat colour continues evenly over the back and flanks with no patches, chestnut coat: warm copper-red body, slightly lighter copper mane and tail, a white blaze down the face, two white socks on the hind legs, glossy jet-black hooves on every leg, natural colors, glossy healthy coat, soft hand-painted shading, bright daylight colors",
  "ai_model": "latest",
  "enable_original_uv": true,
  "enable_pbr": false,
  "texture_resolution": "2k",
  "target_formats": [
    "fbx",
    "glb"
  ]
}
then: poll GET https://api.meshy.ai/openapi/v1/retexture/<task_id>, download model_urls.glb/fbx + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py retexture horse_gallop_grey --dry-run --models-root <main>/Models
slot horse_gallop_grey: retexture of horse_gallop -> Models/generated/horse_gallop_grey  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "01a10a0c-b915-7718-a330-63c84847af36",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, small side eyes and bridle, bare back with no saddle and no saddle cloth: the coat colour continues evenly over the back and flanks with no patches, dapple grey coat: light silver-grey body with soft round darker grey dapples, darker grey lower legs, silver-white mane and tail, dark grey muzzle, glossy jet-black hooves on every leg, natural colors, glossy healthy coat, soft hand-painted shading, bright daylight colors",
  "ai_model": "latest",
  "enable_original_uv": true,
  "enable_pbr": false,
  "texture_resolution": "2k",
  "target_formats": [
    "fbx",
    "glb"
  ]
}
then: poll GET https://api.meshy.ai/openapi/v1/retexture/<task_id>, download model_urls.glb/fbx + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py retexture horse_gallop_black --dry-run --models-root <main>/Models
slot horse_gallop_black: retexture of horse_gallop -> Models/generated/horse_gallop_black  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "01a10a0c-b915-7718-a330-63c84847af36",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, small side eyes and bridle, bare back with no saddle and no saddle cloth: the coat colour continues evenly over the back and flanks with no patches, black coat with a soft blue-black sheen and gentle grey highlights on the shoulders and hindquarters, black mane and tail, a white star on the forehead, four short white socks, glossy jet-black hooves on every leg, natural colors, glossy healthy coat, soft hand-painted shading, bright daylight colors",
  "ai_model": "latest",
  "enable_original_uv": true,
  "enable_pbr": false,
  "texture_resolution": "2k",
  "target_formats": [
    "fbx",
    "glb"
  ]
}
then: poll GET https://api.meshy.ai/openapi/v1/retexture/<task_id>, download model_urls.glb/fbx + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py retexture horse_gallop_palomino --dry-run --models-root <main>/Models
slot horse_gallop_palomino: retexture of horse_gallop -> Models/generated/horse_gallop_palomino  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "01a10a0c-b915-7718-a330-63c84847af36",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, small side eyes and bridle, bare back with no saddle and no saddle cloth: the coat colour continues evenly over the back and flanks with no patches, palomino coat: rich golden body, creamy white mane and tail, a white stripe down the face, golden lower legs, glossy jet-black hooves on every leg, natural colors, glossy healthy coat, soft hand-painted shading, bright daylight colors",
  "ai_model": "latest",
  "enable_original_uv": true,
  "enable_pbr": false,
  "texture_resolution": "2k",
  "target_formats": [
    "fbx",
    "glb"
  ]
}
then: poll GET https://api.meshy.ai/openapi/v1/retexture/<task_id>, download model_urls.glb/fbx + texture_urls[] + thumbnail, write task.json
```

</details>

## Follow-up (2026-10-04)

- Grey re-rolled as a darker dapple grey at David's request (10 credits; total 180 of 200). The pale version is kept locally as `Models/generated/horse_gallop_grey_light/`.
- Finish post kept with its plaid disc (David: reevaluate later).
- Uploaded to Roblox under the LlamaWorks group; see `docs/art/IMPORT.md`.

## World set (2026-10-04)

**Budget:** David allowed up to 75% of the day's Meshy credits. The balance was 1,740, so the floor was 450 (1,290 to spend). The balance was checked (`GET /openapi/v1/balance`) before every batch.

| Batch | What | Credits |
| --- | --- | --- |
| 1 | `horse_stand`, `foal_stand`, `stable_barn` (text) + 7 new gallop coats (retexture) | 160 |
| 2 | 12 standing coats + 3 foal coats (retexture) + 8 care props (text) | 390 |
| 3 | Garden (4), `saddle_rack`, Fair Street (6) (text) | 330 |
| Re-rolls | `pitchfork`, `water_trough` (text); pinto and roan, both poses (retexture) | 100 |
| 4 | Decor and trail (10, text) | 300 |
| **Total** | 32 text-to-3D slots, 22 retextures, 6 re-rolls | **1,280** (balance 1,740 → 460) |

Every figure is Meshy's `consumed_credits` from the slot's `task.json` (first attempts are in `<slot>_attempt1/`). The per-slot list, prompts and verdict notes are in `tools/meshy/queue.json`; the budget block there has the same totals.

**Uploaded** (51 new models, 58 in all, every one approved by Roblox moderation on 2026-10-04; ids in `tools/roblox/uploaded.json` and `game/src/shared/MeshAssets.luau`):

| Group | Slots |
| --- | --- |
| Standing horses | `horse_stand_` bay, chestnut, grey, black, palomino, pinto, appaloosa, buckskin, dun, roan, white, chestnut_blaze |
| Gallop horses (new) | `horse_gallop_` pinto, appaloosa, buckskin, dun, roan, white, chestnut_blaze (the playtest gallop coats keep their names `horse_bay` ... `horse_palomino`) |
| Foals | `foal_stand_` bay, chestnut, grey |
| Stable and care | `stable_barn`, `hay_bale`, `water_trough`, `feed_bucket`, `grooming_brush`, `wheelbarrow`, `pitchfork`, `noticeboard`, `post_box`, `saddle_rack` |
| Garden | `carrot_crop`, `apple_tree_small`, `oat_crop`, `garden_bed` |
| Fair Street | `feed_store`, `vet_clinic`, `market_corral_booth`, `training_shed`, `race_board_frame`, `trail_gate_arch` |
| Decor and trail | `lantern_post`, `bench`, `picnic_table`, `trophy_cup`, `rosette_ribbon`, `horseshoe_decor`, `log_jump`, `wooden_bridge`, `hay_cart` |

**Dropped:** `flower_planter` (failed review, no budget to re-roll). The bases `horse_stand` and `foal_stand` are meshes for the retextures and aren't uploaded.

**UI (free):** 66 world icons drawn in `tools/ui/make_ui_svgs.py` (review sheet `assets/ui/_sheet_world.svg`) and packed by `tools/ui/build_atlas.py` into two new sheets, `ui_atlas_world_1` (48 icons) and `ui_atlas_world_2` (18 icons), uploaded as Decals. The race sheets `ui_atlas_1` and `ui_atlas_2` are byte-identical to before. Names are in `game/src/shared/UiAtlas.luau`.

**Local fixes (no credits):**

- `tools/meshy/darken_hooves.py`: now keeps only the four lowest leg-like parts, so a standing horse's long tail isn't painted as a fifth hoof. The gallop output is byte-identical to before.
- `tools/meshy/recolor.py`: `roan` (natural strawberry roan from the pastel re-roll) and `canopy` (green leaves for the apple tree). Writes `<slot>_recolored.glb`.
- `tools/meshy/trim_base.py`: removes a ground plate (used on `race_board_frame`). Writes `<slot>_trimmed.glb`.

Pipeline order for horses: `meshy.py retexture` → `darken_hooves.py` (one run per mesh: gallop, stand and foal meshes each get their own run, because the hoof mask is shared within a run) → `recolor.py roan` for roans only → `upload_assets.py`.
