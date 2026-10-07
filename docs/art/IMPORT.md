# Importing the generated models into Studio by hand

**Uploaded 2026-10-04** with David's approval, under the LlamaWorks group (`ROBLOX_CREATOR_GROUP_ID`), by `tools/roblox/upload_assets.py`: five horse coats, the finish post, the gate stall, and the two UI atlas sheets (`tools/ui/build_atlas.py`). The world set (51 more models and two more UI sheets) followed the same day; see [World models](#world-models-2026-10-04). Ids are in `tools/roblox/uploaded.json`, `game/src/shared/MeshAssets.luau` and `game/src/shared/UiImages.luau`. At server start `AssetService` loads and sizes the models into `ReplicatedStorage.RaceModels` (as below) and publishes the UI sheets' image ids; `TrackScene` and the client use them, with placeholders until then.

**The place must belong to the LlamaWorks group**, because Roblox only lets a place load assets owned by its own creator. In Studio: File → Publish to Roblox As → LlamaWorks. New assets also wait for moderation (minutes to hours).

The rest of this page covers bringing the files into a place by hand, if ever needed.

## Where the files are

The raw Meshy output is in the main checkout, `C:/Users/David S/Documents/GitHub/gavel-race/Models/generated/<slot>/`. It is ignored by git and is never committed. The task files expire on Meshy's side after 3 days, but everything was downloaded during the run.

| Use this | For |
| --- | --- |
| `horse_gallop_<coat>/horse_gallop_<coat>_hoofed.glb` (coat = bay, chestnut, grey, black, palomino) | Race horses, with hooves darkened by `tools/meshy/darken_hooves.py` |
| `horse_gallop_<coat>/horse_gallop_<coat>_base_color_hoofed.png` | The same texture on its own, for SurfaceAppearance or when importing the FBX |
| `finish_post/finish_post.glb` | Finish posts, one per rail |
| `gate_stall/gate_stall.glb` | Starting gate stall, cloned × 8 |

Don't use `horse_gallop/` (smeared saddle patch), the plain `*.glb` of any coat (light bay hooves), or `gate_stall_attempt1/` (broken). Each folder's `.fbx` is the same mesh, if your Studio build prefers FBX.

## Facts about the files (measured 2026-10-04)

- Each GLB is one mesh with one colour texture (2048 × 2048, no PBR maps) and an identity node transform.
- Units are glTF metres, normalised so the longest side is about 1.9.
- **The origin is at the bounding-box centre, not the bottom**, even though the request asked for `origin_at: bottom`.
- After import into Roblox the horses already face −Z (Roblox's forward). Playtest on 2026-10-04 showed the earlier "rotate 180°" note was wrong; `AssetService` now applies no turn (`YAW` table).

| Slot | Triangles | Raw size X × Y × Z | Front | Target size in studs (X × Y × Z) | Uniform scale |
| --- | --- | --- | --- | --- | --- |
| Horses (all coats, one mesh) | 8,317 | 0.42 × 1.21 × 1.90 (length on Z) | head toward +Z | 1.77 × 5.09 × 8.0 | × 4.20 |
| `finish_post` | 2,889 | 0.88 × 1.90 × 0.21 | disc faces ±Z | 6.45 × 14.0 × 1.57 | × 7.36 |
| `gate_stall` | 2,930 | 1.90 × 1.48 × 1.01 | doors toward +Z | 5.5 × 8.0 × 5.0 (non-uniform) | (n/a) |

Every mesh is under Roblox's 20,000-triangle limit for a MeshPart. Eight horses come to about 67k triangles on screen.

## Steps

1. **Shrink the textures first** (optional but predictable). Roblox stores images at no more than 1024 × 1024. Run `python -c "from PIL import Image; im=Image.open('IN.png'); im.resize((1024,1024), Image.LANCZOS).save('OUT.png')"`.
2. **Import:**
   - In Studio, go to Home (or Avatar) → **Import 3D**, or File → Import 3D, and pick the `.glb` (or the `.fbx`).
   - In the import window, check the preview and leave it as a single MeshPart. Tick Anchored.
   - Any scale unit is fine, because step 3 sets the exact size. These option names come from the current 3D Importer and may move between Studio versions.
3. **Size:** select the MeshPart and type the target Size from the table. For the horse and finish post, keep the ratios (uniform scale). The gate stall can be stretched to fit a horse plus a seated avatar (about 8 studs tall).
4. **Face forward:** rotate 180° about Y so the horse's head, the gate doors and the disc point along −Z (`LookVector`).
5. **Pivot on the ground:** set `PivotOffset = CFrame.new(0, -Size.Y / 2, 0)`. The pivot then sits where the lowest hoof touches the ground (gallop pose), or at the base of a post or gate. The race code places each horse by its pivot on the track and adds the bob on top.
6. **Properties:** `Anchored = true`, `CanCollide = false`, `CanQuery = false` and `CanTouch = false` on horses, since they move by CFrame. Use `CollisionFidelity = Box` and `RenderFidelity = Automatic`. Props keep `CanCollide = true` only if players should bump into them.
7. **Texture:** if the importer didn't pick up the embedded texture, add a `SurfaceAppearance` with `ColorMap` set to the uploaded `*_base_color_hoofed.png` (or set `MeshPart.TextureID`).
8. **One mesh, five coats:** all coats share the same mesh and UVs. Import the horse once and swap only the SurfaceAppearance `ColorMap` per coat: one MeshId and five 1024 px maps, which is lighter on phones.

## Horse model layout (for the race presentation code)

```
Horse_<coat> (Model, PrimaryPart = Root)
  Root          invisible Part 1.8 x 1 x 8, Anchored, at the pivot
  Body          the MeshPart, WeldConstraint to Root
  SaddleCloth   thin Part ~2.2 x 0.15 x 2.6 on the back behind the withers, Decal = lane_N_blank pattern (P0, lane identity on the horse)
  Attachments on Body:
    Saddle      top of the back, where the avatar sits (riding animation: hands and heels, never a whip)
    HoofFL, HoofFR, HoofHL, HoofHR   at each hoof: fx_dust_puff, 1 particle per beat
    Crest       top of the neck: fx_mane_flick, 1 particle per beat, tinted to the mane colour
    Badge       about 2.5 studs above the saddle: lane chip BillboardGui (plus lane_sparkle); the YOU marker sits higher on the player's horse
```

Mane tints for `fx_mane_flick`: bay `#1D2433`, chestnut `#C9692E`, grey `#E6E8EC`, black `#1D2433`, palomino `#F3E3BE`.

## Props

- **Gate:** clone × 8, one per lane, 5.5 studs apart. Put a SurfaceGui on the blank plate with the lane chip (`lane_N`). Leave the doors closed and park the horses just behind the stall front, or hide the gate when the race starts. Opening doors would need the doors split off in Blender.
- **Finish:** one `finish_post` on each rail. Stretch a banner Part between them, and lay a 0.05-stud ground strip Part across the track, both with a `Texture` using `finish_checker.png` (`StudsPerTileU/V = 4`).
- **Rails and lane chalk:** Roblox parts (white cylinders, posts every 8 studs). These are not generated.

## 2D UI

- PNGs are in `assets/ui/png/` at 2× (256 px for every 128 px icon), made by `python tools/ui/make_ui_svgs.py` (needs `pip install resvg-py`). Upload them as Images after approval.
- Words and numbers are TextLabels. Use the `*_blank` variants of the pad, YOU marker and lane chips in game; the baked text is a placeholder.
- **Ring:** build it as a circular Frame (`UICorner` 0.5) with a white 6 px `UIStroke` and a thin ink stroke behind it, so the stroke stays the same thickness at every size. `hoof_ring.png` is the fallback image. Put it in a ScreenGui, or a BillboardGui with `LightInfluence = 0` and `AlwaysOnTop = true`, so lighting never dims it.

## World models (2026-10-04)

Uploaded by `tools/roblox/upload_assets.py` and approved by Roblox moderation the same day. `AssetService` loads every slot in `MeshAssets` into `ReplicatedStorage.RaceModels` (the folder name is historical; it now holds the world too) and sizes, turns and sets collision from `game/src/shared/ModelSpecs.luau`: the exact slot first, then the longest prefix ending in `_` (`horse_`, `foal_`). A slot with no entry gets a 4-stud fallback and a warning. Pivots sit at the bottom centre, as before.

**Facing:** every Meshy model has its front toward glTF +Z (horses' heads, building doors, sign faces), which imports facing −Z, Roblox forward, like the playtest horses. So `yaw = 0` everywhere; turn a building with its CFrame when placing it.

**Horses and foals** (one mesh per pose; all coats share its UVs):

| Slots | File | Triangles | Size in studs (X × Y × Z) | Collide |
| --- | --- | --- | --- | --- |
| `horse_stand_<coat>` (12 coats) | `horse_stand_<coat>_hoofed.glb` (roan: `_recolored.glb`) | 8,301 | 3.1 × 6.0 × 8.0 | no |
| `horse_gallop_<coat>` (7 new coats) | `horse_gallop_<coat>_hoofed.glb` (roan: `_recolored.glb`) | 8,317 | 1.8 × 5.1 × 8.0 | no |
| `foal_stand_<coat>` (bay, chestnut, grey) | `foal_stand_<coat>_hoofed.glb` | 6,283 | 1.3 × 4.0 × 3.2 | no |

Coats: bay, chestnut, grey, black, palomino, pinto, appaloosa, buckskin, dun, roan, white, chestnut_blaze (standing); pinto, appaloosa, buckskin, dun, roan, white, chestnut_blaze (new gallop). The five playtest gallop coats keep their slot names `horse_bay` ... `horse_palomino`. Standing horses have no saddle on the mesh, like the gallop horses; the saddle and tack are separate parts. The buckskin is a collectible, never the hero (art direction).

**Props and buildings:**

| Slot | File | Triangles | Size in studs (X × Y × Z) | Collide |
| --- | --- | --- | --- | --- |
| `stable_barn` | `stable_barn.glb` | 5,937 | 40.1 × 32.0 × 25.2 | yes |
| `hay_bale` | `hay_bale.glb` | 2,619 | 4.3 × 3.0 × 3.5 | yes |
| `water_trough` | `water_trough.glb` | 2,790 | 6.5 × 2.5 × 2.8 | yes |
| `feed_bucket` | `feed_bucket.glb` | 1,911 | 2.2 × 1.6 × 2.1 | no |
| `grooming_brush` | `grooming_brush.glb` | 2,736 | 1.2 × 0.8 × 0.6 | no |
| `wheelbarrow` | `wheelbarrow.glb` | 3,028 | 4.9 × 3.0 × 2.6 | yes |
| `pitchfork` | `pitchfork.glb` | 3,068 | 1.4 × 5.5 × 0.4 | no |
| `noticeboard` | `noticeboard.glb` | 2,973 | 7.0 × 8.0 × 3.9 | yes |
| `post_box` | `post_box.glb` | 2,926 | 2.6 × 4.5 × 2.2 | yes |
| `saddle_rack` | `saddle_rack.glb` | 3,035 | 4.9 × 3.5 × 2.8 | yes |
| `carrot_crop` | `carrot_crop.glb` | 2,756 | 2.3 × 1.2 × 2.4 | no |
| `apple_tree_small` | `apple_tree_small_recolored.glb` | 4,029 | 12.0 × 12.0 × 9.7 | yes |
| `oat_crop` | `oat_crop.glb` | 2,898 | 2.4 × 2.4 × 1.9 | no |
| `garden_bed` | `garden_bed.glb` | 2,849 | 6.0 × 2.3 × 2.6 | yes |
| `feed_store` | `feed_store.glb` | 7,689 | 45.2 × 32.0 × 39.4 | yes |
| `vet_clinic` | `vet_clinic.glb` | 6,662 | 43.5 × 30.0 × 41.3 | yes |
| `market_corral_booth` | `market_corral_booth.glb` | 4,665 | 29.5 × 24.0 × 25.4 | yes |
| `training_shed` | `training_shed.glb` | 5,940 | 37.5 × 24.0 × 36.0 | no |
| `race_board_frame` | `race_board_frame_trimmed.glb` | 2,911 | 24.4 × 28.0 × 12.6 | yes |
| `trail_gate_arch` | `trail_gate_arch.glb` | 5,412 | 27.6 × 20.0 × 6.6 | no |
| `lantern_post` | `lantern_post.glb` | 2,945 | 3.1 × 9.0 × 2.4 | yes |
| `bench` | `bench.glb` | 2,666 | 5.1 × 3.0 × 2.4 | yes |
| `picnic_table` | `picnic_table.glb` | 2,686 | 5.9 × 3.0 × 5.1 | yes |
| `trophy_cup` | `trophy_cup.glb` | 3,136 | 3.0 × 3.0 × 1.8 | no |
| `rosette_ribbon` | `rosette_ribbon.glb` | 3,032 | 1.3 × 2.5 × 0.2 | no |
| `horseshoe_decor` | `horseshoe_decor.glb` | 3,106 | 2.2 × 2.5 × 0.5 | no |
| `log_jump` | `log_jump.glb` | 2,863 | 7.1 × 3.0 × 1.8 | no |
| `wooden_bridge` | `wooden_bridge.glb` | 3,614 | 16.0 × 7.8 × 12.2 | no |
| `hay_cart` | `hay_cart.glb` | 1,348 | 8.9 × 6.0 × 5.3 | yes |
| `post_box_carrots` | `post_box_carrots.glb` | 2,926 | 2.6 × 4.5 × 2.2 | yes |
| `visitor_bell` | `visitor_bell.glb` | 2,903 | 1.2 × 5.5 × 1.5 | yes |
| `rosette_wall` | `rosette_wall.glb` | 2,568 | 5.6 × 7.5 × 1.2 | yes |

**Notes for the world code:**

- **Collision is the uploaded mesh's own.** `CollisionFidelity` can't be set by scripts, so a building with `collide = true` blocks players with its default hull. The barn's stall bays may not be walkable inside; put horses there by CFrame (they never collide) or add invisible box colliders. The training shed, trail arch, bridge and log jump are `collide = false` so riders can pass through or under; add invisible parts where people should stand (for example the bridge deck).
- **Signs:** the barn, training shed, market booth, noticeboard, race board and trail arch have blank boards for a `SurfaceGui`. The feed store and vet clinic have no board: add a sign part on the front.
- **Water trough:** the inside is pale wood. Add a thin blue water part at the rim (it can rise when the fill-water chore is done).
- **Garden:** two crops fit side by side on a `garden_bed` (6 × 2.6). The apple tree stands on the ground beside the beds.
- **Hoofprint trail markers:** `hoofprint` is in the UI atlas. A ground `Decal` can't use an atlas rect, so upload `assets/ui/png/hoofprint.png` as its own image if the trail is drawn with Decals.
- **Not made:** `flower_planter` failed review and was dropped; the base meshes `horse_stand` and `foal_stand` aren't uploaded (use a coat).
