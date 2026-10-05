# Playtest asset plan

Status: Phase 1, plan only. Nothing has been generated, uploaded or paid for. The design council reviews this plan and [ART_DIRECTION.md](ART_DIRECTION.md) before Phase 2 (generation). Prepared 2026-10-04.

## Budget

| | Meshy credits |
| --- | --- |
| P0 (horse, 4 coats, finish post) | 100 |
| P1 (starting gate stall) | 30 |
| P2 (rare coat, standing horse) | 40 |
| **Full queue, one attempt each (dry-run total)** | **170** |
| Spend cap | 200 |

Run P0 first and review the thumbnails before anything else. The 70 credits between P0+P1 (130) and the cap cover one horse re-roll plus one prop re-roll; P2 only runs if they're not needed or the council asks for it. The rates come from the tool: text-to-3D = preview 20 + refine 10, retexture 10. Rigging (5) is for humanoids only and isn't used.

## Asset list

| # | Asset | 2D/3D | Tool | Meshy credits | Priority | Why the playtest needs it |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Racehorse, mid-gallop, bay (`horse_gallop`) | 3D | Meshy text-to-3D | 30 | P0 | Race presentation (STATUS item 6) needs a horse; one mesh moved by tweens |
| 2 | Coats: chestnut, dapple grey, black, palomino (`horse_gallop_*`) | 3D | Meshy retexture | 40 (4 × 10) | P0 | 8 lanes of identical clones look broken; 5 coats total |
| 3 | Finish post, one per rail (`finish_post`) | 3D | Meshy text-to-3D | 30 | P0 | The finish is the payoff moment that leads into results |
| 4 | Rail section, track surface, lane chalk, finish banner and line | 3D | Roblox parts/Terrain + `finish_checker` tile | 0 | P0 | Tiling pieces need exact sizes; generated meshes don't tile |
| 5 | Hoof icon + closing ring + dashed tempo-change ring | 2D | `tools/ui/make_ui_svgs.py` | 0 | P0 | The Giddy-up beat cue (D-022) |
| 6 | Giddy-up tap button (idle, pressed) | 2D | same | 0 | P0 | Visible tap cue for phones; tapping anywhere still counts |
| 7 | Final Burst bar, glow zone, marker | 2D | same | 0 | P0 | The burst tap (D-022) |
| 8 | Feedback shapes: Perfect star, Great chevrons, Good check, Okay dot, Miss dash, Steady wave | 2D | same | 0 | P0 | Per-beat labels readable without colour |
| 9 | Lane chips 1–8 (colour + pattern + number) | 2D | same | 0 | P0 | Lobby board rows and the badge over each horse |
| 10 | Win chance up/down arrows | 2D | same | 0 | P0 | Live win chance change after each stretch |
| 11 | Ribbons: Blue, Red, Yellow, White | 2D | same | 0 | P0 | Results screen (D-016) |
| 12 | "YOU" marker | 2D | same | 0 | P0 | Find your own horse in an 8-horse pack |
| 13 | Starting gate stall, cloned × 8 (`gate_stall`) | 3D | Meshy text-to-3D | 30 | P1 | A start moment; the race can start from a painted line until then |
| 14 | Jockey riding pose + hands-and-heels pump | Anim | Roblox Animation Editor (R15) | 0 | P1 | Avatars otherwise show the default sit pose; never a whip |
| 15 | Saddle cloth overlay with lane pattern | 3D/2D | Blender cut from the horse mesh + lane pattern decals | 0 | P1 | Shows the lane on the horse itself |
| 16 | Top Fans badge | 2D | `make_ui_svgs.py` | 0 | P1 | Top Fans board (D-020), coming soon |
| 17 | Cheer / clap icon | 2D | same | 0 | P1 | Spectator cheering and Clap Along (D-019, D-020) |
| 18 | Paper panel 9-slice | 2D | same | 0 | P1 | Lobby board, results and Top Fans panels |
| 19 | Particle textures: dust puff, sparkle, confetti | 2D | same | 0 | P1 | Hoof strikes, Perfect, the burst |
| 20 | Green Cash token icon | 2D | same | 0 | P1 | Purse and prize amounts; one token, never a cash pile |
| 21 | Rare coat placeholder: leopard spots (`horse_gallop_rare`) | 3D | Meshy retexture | 10 | P2 | Waits on council question 3 |
| 22 | Standing horse (`horse_stand`) | 3D | Meshy text-to-3D | 30 | P2 | Lobby, podium and stable; not needed in Phase 1 |
| 23 | Fan level badges, stand flags | 2D | `make_ui_svgs.py` | 0 | P2 | Fan XP cosmetics (D-019) |

Drafted now: every P0 2D asset (rows 5–12, 30 SVGs, about 60 KB in `assets/ui/`). `assets/ui/_sheet.svg` shows them all together, plus the ring timeline and the composed burst meter.

## How the horse moves without a rig

Meshy auto-rigging only supports bipedal humanoids, so the horse is a single static mesh.

- **Phase 1 (P0): mid-gallop pose plus tweens.**
  - Each lane is a Model: the horse MeshPart, a saddle Attachment that the avatar welds to, and hoof Attachments for dust.
  - The client moves each Model along the track path every frame (`RenderStepped`, CFrame along a spline from the server's finish-order timeline), not with one long tween.
  - **Gallop illusion:** body bob `y = A · |sin(π · phase)|` with A ≈ 0.35 studs, and pitch ±4° (nose down on landing). `phase` is that horse's stride-beat phase, so the player's horse bobs on the same clock as the hoof ring: what you tap is what you see.
  - At each beat, the hoof Attachments emit 3 dust particles.
  - **Surge** (on-beat taps): lean forward 3° and show speed-line Trails for 0.4 s.
  - **Break stride** (mashing): the bob loses phase for about 0.5 s as a skip-hop, with a small slowdown. No stumbling or falling.
- **Later (P2):** split `horse_stand`'s legs into 4 MeshParts with Motor6Ds in Blender and tween a 4-key gallop cycle, or build a custom quadruped skinned rig in Blender (outside Meshy).

## Pipeline

- **3D:** `python tools/meshy/meshy.py text <slot>` (or `retexture <slot>`) writes FBX, GLB, textures and `task.json` to `Models/generated/<slot>/`, which is gitignored. In Blender, check the scale, origin at the hooves, triangle count ≤ 8k (Roblox allows 20k per MeshPart) and that the legs are clean. Import into Studio with the 3D Importer as a MeshPart with SurfaceAppearance (`enable_pbr: false` gives one colour map per asset, lighter on phones).
  - Meshy task files expire after 3 days, so run the retextures within 3 days of `horse_gallop`.
  - Uploading to Roblox needs David's approval and isn't part of this plan.
- **2D:** the SVGs are the source of truth. Phase 2 rasterizes them to PNG at 2× with `resvg_py` + Pillow (the Ghost Hunters `build_atlas.py` approach), packs them into a sheet and uploads after approval. Numbers and words come from TextLabels.
- **Tool:** `tools/meshy/meshy.py` is copied from the owner's haunt-nyc repo. That tool takes `--models-root` but has no queue-path flag, so the copy keeps its paths relative to its own folder. Only the header comment, the User-Agent and the CLI description changed. The key comes only from the `MESHY_API_KEY` environment variable, and `--dry-run` never reads it. The text-to-3D API has no negative-prompt field, so the `negative` entries in `queue.json` are review notes and are never sent.

## Questions for the design council

1. **Horse look:** chunky stylized natural horses (recommended), more realistic proportions, or more cartoon (bigger eyes and heads)? Where is the line from My Little Pony and Spirit for our audience?
2. **Race motion:** a static mid-gallop mesh with a bob tween now (recommended, almost no engineering), or a standing mesh split into legs for a tweened gallop cycle (more work, reusable in the lobby and stable)?
3. **Rare coats:** natural rare coats (leopard spots, pinto, cremello) or fantasy coats (galaxy, glowing)? Do any appear in the Phase 1 playtest?
4. **Final Burst boldness:** show gold rays, confetti and a camera punch only on the rider's own screen (recommended), or show every lane's Perfect to the field and spectators? Is that too much for 8-year-olds?
5. **Lane identity:** keep lane colours fixed per lane number (recommended, so lane 3 is always yellow dots), or let a player's cosmetic silks colour follow them? Is it confusing if a kid's silks clash with their lane colour?
6. **Tap button:** show a big Giddy-up button, or rely on tapping anywhere with only the hoof as the target? Does a button teach "tap here" or hide the horse on small phones?

## Meshy dry-run (2026-10-04)

No API calls were made: every command ran with `--dry-run`, and no key was set or read. Retexture bodies show `<model_task_id of horse_gallop>` because the base doesn't exist yet. Full output follows.

<details><summary>Full dry-run output (status + every request body)</summary>

```text
slot_id                       kind         tris  rig model    rigged   est  spent
horse_gallop                  creature     8000  no  -        -         30      0
horse_gallop_chestnut         creature     8000  no  -        -         10      0
horse_gallop_grey             creature     8000  no  -        -         10      0
horse_gallop_black            creature     8000  no  -        -         10      0
horse_gallop_palomino         creature     8000  no  -        -         10      0
finish_post                   prop         3000  no  -        -         30      0
gate_stall                    prop         3000  no  -        -         30      0
horse_gallop_rare             creature     8000  no  -        -         10      0
horse_stand                   creature     8000  no  -        -         30      0

9 slots, estimated 170 credits for the full queue (one attempt each), 0 spent so far.
outputs: Models/generated/<slot_id>/
[dry-run] status never calls the network.

$ python tools/meshy/meshy.py text horse_gallop --dry-run
slot horse_gallop (creature) -> Models/generated/horse_gallop  est. 30 credits
step 1/2 preview:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "preview",
  "prompt": "full body stylized thoroughbred racehorse in a smooth mid-gallop pose seen from the side, front legs reaching forward and hind legs pushing back, all four legs clearly separated, head and neck stretched forward, ears pricked forward, bright calm happy eyes, relaxed closed mouth, glossy healthy bay coat with black mane, black tail and black lower legs, short tidy mane, flowing tail, slightly chunky toy-like proportions with a sturdy neck, strong legs and large rounded hooves, simple brown leather bridle and reins, small flat brown racing saddle on a plain white saddle cloth, riderless, stylized cartoon game asset, chunky readable silhouette, soft hand-painted colors, bright sunny daylight palette, single object, no base, no text, no logos",
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
  "texture_prompt": "glossy healthy bay horse coat, warm reddish brown body, black mane, tail and lower legs, soft hand-painted shading, clean plain white saddle cloth, simple brown leather bridle and saddle, bright daylight colors"
}
step 2b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<refine_task_id>, download model_urls.fbx/glb + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py text finish_post --dry-run
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

$ python tools/meshy/meshy.py text gate_stall --dry-run
slot gate_stall (prop) -> Models/generated/gate_stall  est. 30 credits
step 1/2 preview:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "preview",
  "prompt": "a single starting gate stall for a cartoon horse race, one narrow open bay with a pair of front swing doors and a back door, chunky rounded tube frame painted white, soft sky blue padding on the bars, soft green padded side walls, a large blank square plate on the top front bar, grey rubber floor mat, friendly toy-like proportions, stylized cartoon game asset, chunky readable silhouette, soft hand-painted colors, bright sunny daylight palette, single object, no base, no text, no logos",
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
  "texture_prompt": "glossy white painted tube frame, soft sky blue padding, soft green padded walls, plain light grey blank plate, dark grey rubber mat, soft hand-painted shading"
}
step 2b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<refine_task_id>, download model_urls.fbx/glb + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py text horse_stand --dry-run
slot horse_stand (creature) -> Models/generated/horse_stand  est. 30 credits
step 1/2 preview:
[dry-run] POST https://api.meshy.ai/openapi/v2/text-to-3d
{
  "mode": "preview",
  "prompt": "full body stylized thoroughbred racehorse standing square in a relaxed side-on pose, all four hooves flat on the ground, head up, ears pricked forward, bright calm happy eyes, relaxed closed mouth, glossy healthy bay coat with black mane, black tail and black lower legs, short tidy mane, slightly chunky toy-like proportions with a sturdy neck, strong straight legs and large rounded hooves, simple brown leather bridle and reins, small flat brown racing saddle on a plain white saddle cloth, riderless, stylized cartoon game asset, chunky readable silhouette, soft hand-painted colors, bright sunny daylight palette, single object, no base, no text, no logos",
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
  "texture_prompt": "glossy healthy bay horse coat, warm reddish brown body, black mane, tail and lower legs, soft hand-painted shading, clean plain white saddle cloth, simple brown leather bridle and saddle, bright daylight colors"
}
step 2b: poll GET https://api.meshy.ai/openapi/v2/text-to-3d/<refine_task_id>, download model_urls.fbx/glb + texture_urls[] + thumbnail, write task.json

$ python tools/meshy/meshy.py retexture horse_gallop_chestnut --dry-run
slot horse_gallop_chestnut: retexture of horse_gallop -> Models/generated/horse_gallop_chestnut  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "<model_task_id of horse_gallop>",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, eyes, bridle, saddle and plain white saddle cloth, chestnut coat: warm copper-red body, slightly lighter copper mane and tail, a white blaze down the face and two white socks on the hind legs, glossy healthy coat, soft hand-painted shading, bright daylight colors",
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
note: horse_gallop has no task.json with model_task_id under Models/generated

$ python tools/meshy/meshy.py retexture horse_gallop_grey --dry-run
slot horse_gallop_grey: retexture of horse_gallop -> Models/generated/horse_gallop_grey  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "<model_task_id of horse_gallop>",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, eyes, bridle, saddle and plain white saddle cloth, dapple grey coat: light silver-grey body with soft round darker grey dapples, darker grey lower legs, silver-white mane and tail, dark grey muzzle, glossy healthy coat, soft hand-painted shading, bright daylight colors",
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
note: horse_gallop has no task.json with model_task_id under Models/generated

$ python tools/meshy/meshy.py retexture horse_gallop_black --dry-run
slot horse_gallop_black: retexture of horse_gallop -> Models/generated/horse_gallop_black  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "<model_task_id of horse_gallop>",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, eyes, bridle, saddle and plain white saddle cloth, black coat with a soft blue-black sheen and gentle grey highlights on the shoulders and hindquarters, black mane and tail, a white star on the forehead and one white front sock, glossy healthy coat, soft hand-painted shading, bright daylight colors",
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
note: horse_gallop has no task.json with model_task_id under Models/generated

$ python tools/meshy/meshy.py retexture horse_gallop_palomino --dry-run
slot horse_gallop_palomino: retexture of horse_gallop -> Models/generated/horse_gallop_palomino  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "<model_task_id of horse_gallop>",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, eyes, bridle, saddle and plain white saddle cloth, palomino coat: rich golden body, creamy white mane and tail, a white stripe down the face, golden lower legs and light cream hooves, glossy healthy coat, soft hand-painted shading, bright daylight colors",
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
note: horse_gallop has no task.json with model_task_id under Models/generated

$ python tools/meshy/meshy.py retexture horse_gallop_rare --dry-run
slot horse_gallop_rare: retexture of horse_gallop -> Models/generated/horse_gallop_rare  est. 10 credits
[dry-run] POST https://api.meshy.ai/openapi/v1/retexture
{
  "input_task_id": "<model_task_id of horse_gallop>",
  "text_style_prompt": "same stylized galloping racehorse, keep the exact shape, pose, eyes, bridle, saddle and plain white saddle cloth, leopard spotted coat: bright white body covered in round dark brown spots, spotted dark brown lower legs, soft grey mottled muzzle, striped hooves, brown and white mane and tail, glossy healthy coat, soft hand-painted shading, bright daylight colors",
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
note: horse_gallop has no task.json with model_task_id under Models/generated
```

</details>
