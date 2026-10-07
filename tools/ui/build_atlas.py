#!/usr/bin/env python3
"""Pack the in-game UI PNGs into 1024 px sheets for one Roblox upload each.

Reads assets/ui/png/<name>.png (rendered at 2x), scales each to half size, shelf-packs
them into as many 1024 x 1024 sheets as needed (Roblox stores images at 1024 max), and
writes assets/ui/atlas/ui_atlas_<n>.png plus game/src/shared/UiAtlas.luau (name ->
sheet, x, y, w, h). Particle textures (fx_*) and unused variants stay out: particles
need their own image ids.

The race set (NAMES) and the world set (WORLD_NAMES) are packed separately: the race
sheets ui_atlas_<n> are already uploaded (sha256 in tools/roblox/uploaded.json), so new
icons go on their own sheets ui_atlas_world_<n> and never move a race rect. A sheet file
whose pixels are unchanged is left untouched.

  python tools/ui/build_atlas.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "ui" / "png"
OUT = ROOT / "assets" / "ui" / "atlas"
LUAU = ROOT / "game" / "src" / "shared" / "UiAtlas.luau"
SHEET = 1024
PAD = 2
SCALE = 0.5

# What the client uses. Keep in sync with game/src/client/RaceController.client.luau.
NAMES = (
    ["hoof", "hoof_ring", "giddyup_pad", "giddyup_pad_pressed", "burst_bar", "burst_glow", "burst_marker", "burst_rays",
     "you_marker", "chance_up", "chance_down", "lane_sparkle", "finish_checker"]
    + [f"label_{k}" for k in ("perfect", "great", "good", "okay", "miss", "steady")]
    + [f"ribbon_{c}" for c in ("blue", "red", "yellow", "white")]
    + [f"lane_{i}" for i in range(1, 9)]
    + [f"lane_{i}_sparkle" for i in range(1, 9)]
)

# World UI (docs/WORLD_DESIGN.md): wallet, care, Map, Race Board, Health Passport, Stable Board, training.
WORLD_NAMES = (
    ["cash", "diamond", "hay", "grain", "carrot", "apple", "oats", "treat", "brush", "seed_carrot", "seed_apple", "seed_oats",
     "energy_hoof", "energy_hoof_empty", "heart", "care_star", "flag_ready", "zzz_resting",
     "clipboard", "map", "camera", "gift", "lock", "friends", "settings", "grownups", "go_button", "go_button_pressed",
     "map_stable", "map_track", "map_fair", "map_vet", "map_trail", "hoofprint"]
    + [f"league_{t}" for t in ("rookie", "bronze", "silver", "gold", "champion")]
    + ["dist_short", "dist_long", "surface_dirt", "surface_turf", "weather_sunny", "weather_rain", "weather_wind",
       "lane_dot_empty", "lane_dot_full"]
    + [f"stamp_{k}" for k in ("checkup", "teeth", "farrier", "vaccine", "potential")]
    + ["stethoscope", "job_care", "job_ride", "job_explore", "job_cheer", "trophy", "ribbon_progress", "sleeping_horse",
       "welcome_sun"]
    + [f"stat_{k}" for k in ("speed", "accel", "stamina", "grit")]
)

# Clarity pass (D-064, horse-life stage 3): its own sheet, so the uploaded race and world sheets never move.
CLARITY_NAMES = ["energy_shoe", "energy_shoe_empty", "rosette", "sprout"] + [f"badge_{t}" for t in ("rookie", "bronze", "silver", "gold", "champion")]

SETS = ((NAMES, "ui_atlas_"), (WORLD_NAMES, "ui_atlas_world_"), (CLARITY_NAMES, "ui_atlas_clarity_"))


def pack(images: dict[str, Image.Image]) -> list[dict[str, tuple[int, int, int, int]]]:
    """Shelf packing, tallest first. Returns one {name: (x, y, w, h)} per sheet."""
    order = sorted(images, key=lambda n: (-images[n].height, -images[n].width, n))
    sheets: list[dict[str, tuple[int, int, int, int]]] = [{}]
    x = y = shelf = 0
    for name in order:
        w, h = images[name].size
        if w > SHEET or h > SHEET:
            raise SystemExit(f"{name} is {w}x{h} after scaling, larger than a sheet")
        if x + w > SHEET:
            x, y, shelf = 0, y + shelf + PAD, 0
        if y + h > SHEET:
            sheets.append({})
            x = y = shelf = 0
        sheets[-1][name] = (x, y, w, h)
        x += w + PAD
        shelf = max(shelf, h)
    return sheets


def save_sheet(path: Path, canvas: Image.Image) -> bool:
    """Write a sheet unless the file already holds the same pixels (keeps uploaded sheets byte-identical)."""
    if path.exists():
        with Image.open(path) as old:
            if old.size == canvas.size and old.convert("RGBA").tobytes() == canvas.tobytes():
                return False
    canvas.save(path, optimize=True)
    return True


def build(names: list[str], prefix: str, entries: dict[str, dict[str, int | str]]) -> list[str]:
    images = {}
    for name in names:
        if name in entries:
            raise SystemExit(f"{name} is listed twice")
        im = Image.open(SRC / f"{name}.png").convert("RGBA")
        images[name] = im.resize((max(1, round(im.width * SCALE)), max(1, round(im.height * SCALE))), Image.LANCZOS)
    written = []
    for i, rects in enumerate(pack(images), start=1):
        sheet_name = f"{prefix}{i}"
        height = max(y + h for (_, y, _, h) in rects.values())
        canvas = Image.new("RGBA", (SHEET, height), (0, 0, 0, 0))
        for name, (x, y, w, h) in rects.items():
            canvas.paste(images[name], (x, y))
            entries[name] = {"sheet": sheet_name, "x": x, "y": y, "w": w, "h": h}
        changed = save_sheet(OUT / f"{sheet_name}.png", canvas)
        print(f"{sheet_name}.png  {SHEET}x{height}  {len(rects)} images{'' if changed else '  (unchanged)'}")
        written.append(sheet_name)
    return written


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    entries: dict[str, dict[str, int | str]] = {}
    written = []
    for names, prefix in SETS:
        written += build(names, prefix, entries)
    for stale in [*OUT.glob("ui_atlas_world_*.png"), *OUT.glob("ui_atlas_clarity_*.png")]:
        if stale.stem not in written:
            stale.unlink()
            print(f"removed stale {stale.name}")
    (OUT / "atlas.json").write_text(json.dumps(entries, indent=1, sort_keys=True) + "\n")
    lines = [
        "--!strict",
        "-- GENERATED by tools/ui/build_atlas.py: UI image name -> sheet and pixel rect. Do not edit by hand.",
        "-- Sheets are uploaded as Decals (tools/roblox/upload_assets.py, ids in UiImages); AssetService resolves",
        "-- each to an image id as ReplicatedStorage attribute UiSheet_<sheet>.",
        "export type Rect = { sheet: string, x: number, y: number, w: number, h: number }",
        "local UiAtlas: { [string]: Rect } = {",
    ]
    for name in sorted(entries):
        e = entries[name]
        lines.append(f'\t{name} = {{ sheet = "{e["sheet"]}", x = {e["x"]}, y = {e["y"]}, w = {e["w"]}, h = {e["h"]} }},')
    lines += ["}", "", "return UiAtlas", ""]
    LUAU.write_text("\n".join(lines))
    print(f"wrote {LUAU.relative_to(ROOT)} ({len(entries)} entries)")


if __name__ == "__main__":
    main()
