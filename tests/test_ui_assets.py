import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "assets" / "ui" / "atlas"
SHARED = ROOT / "game" / "src" / "shared"


def png_size(path: Path) -> tuple[int, int]:
    """Width and height from the PNG header (stdlib only; CI has no Pillow)."""
    data = path.read_bytes()[:24]
    assert data[:8] == bytes.fromhex("89504e470d0a1a0a"), path
    return struct.unpack(">II", data[16:24])


def atlas():
    return json.loads((ATLAS / "atlas.json").read_text())


def test_every_rect_fits_its_sheet_and_none_overlap():
    entries = atlas()
    by_sheet = {}
    for name, e in entries.items():
        w, h = png_size(ATLAS / f"{e['sheet']}.png")
        assert w <= 1024 and h <= 1024, f"{e['sheet']} larger than Roblox stores"
        assert 0 <= e["x"] and e["x"] + e["w"] <= w and 0 <= e["y"] and e["y"] + e["h"] <= h, name
        by_sheet.setdefault(e["sheet"], []).append((name, e))
    for rects in by_sheet.values():
        for i, (a, ea) in enumerate(rects):
            for b, eb in rects[i + 1:]:
                apart = (ea["x"] + ea["w"] <= eb["x"] or eb["x"] + eb["w"] <= ea["x"]
                         or ea["y"] + ea["h"] <= eb["y"] or eb["y"] + eb["h"] <= ea["y"])
                assert apart, f"{a} overlaps {b}"


def test_luau_atlas_matches_json():
    text = (SHARED / "UiAtlas.luau").read_text()
    rows = dict(re.findall(r'^\t(\w+) = (\{[^}]*\}),$', text, re.M))
    entries = atlas()
    assert set(rows) == set(entries)
    for name, e in entries.items():
        assert f'sheet = "{e["sheet"]}", x = {e["x"]}, y = {e["y"]}, w = {e["w"]}, h = {e["h"]}' in rows[name]


def test_client_art_names_exist_in_the_atlas():
    names = set(atlas())
    used = set()
    for path in (ROOT / "game" / "src").rglob("*.luau"):
        text = path.read_text(encoding="utf-8")
        used |= set(re.findall(r'UiArt\.(?:set|attach)\([^,]+,\s*"([a-z0-9_]+)"', text))
        used |= set(re.findall(r'"((?:label|ribbon)_[a-z]+)"', text))
        if "`lane_{i}" in text or 'UiAtlas["lane_" .. i]' in text:
            used |= {f"lane_{i}" for i in range(1, 9)}
        if "`lane_{i}_sparkle`" in text:
            used |= {f"lane_{i}_sparkle" for i in range(1, 9)}
    assert used, "found no art references"
    assert used <= names, sorted(used - names)


def test_generated_id_modules_cover_every_upload():
    state = json.loads((ROOT / "tools" / "roblox" / "uploaded.json").read_text())
    meshes = dict(re.findall(r"^\t(\w+) = (\d+),$", (SHARED / "MeshAssets.luau").read_text(), re.M))
    images = dict(re.findall(r"^\t(\w+) = (\d+),$", (SHARED / "UiImages.luau").read_text(), re.M))
    for name, rec in state.items():
        target = meshes if rec["kind"] == "Model" else images
        assert target.get(name) == str(rec["assetId"]), name
    assert {"horse_bay", "horse_chestnut", "horse_grey", "horse_black", "horse_palomino", "finish_post", "gate_stall"} <= set(meshes)
    assert set(images) == {p.stem for p in ATLAS.glob("ui_atlas_*.png")}
