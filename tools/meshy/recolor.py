# Local texture fixes for generated models (no credits, no network). Reads <slot>_hoofed.glb when it exists (run
# darken_hooves.py first for horses), else Meshy's own <slot>.glb, and writes <slot>_recolored.glb,
# <slot>_base_color_recolored.png and a <slot>_recolored_check.png side view. Meshy's files are never touched.
#   roan    Meshy can't paint a roan: the re-roll came back with a pastel pink body and a fantasy bright-red mane and
#           tail. Saturated reds (mane, tail, red legs) become dark chestnut, keeping their shading; the pale pink body
#           becomes rosy grey with fine darker flecks, which reads as a natural strawberry roan.
#   canopy  The apple tree's leaves came back brick red, so the red apples got lost in them. Muted reds (the canopy)
#           turn leaf green; the saturated crimson apples and the brown trunk stay as they are.
#   python tools/meshy/recolor.py roan horse_stand_roan horse_gallop_roan --models-root <main checkout>/Models
#   python tools/meshy/recolor.py canopy apple_tree_small --models-root <main checkout>/Models
from __future__ import annotations

import argparse
import io
from pathlib import Path

import numpy as np
from PIL import Image

import darken_hooves as dh


def _hsv(f: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    mx, mn = f.max(-1), f.min(-1)
    d = mx - mn
    sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    dd = np.maximum(d, 1e-6)
    hue = np.where(mx == r, ((g - b) / dd) % 6, np.where(mx == g, (b - r) / dd + 2, (r - g) / dd + 4)) * 60
    return np.where(d > 0, hue, 0), sat, mx


def roan(f: np.ndarray) -> np.ndarray:
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    _, sat, mx = _hsv(f)
    points = (r >= g) & (r >= b) & ((r - np.maximum(g, b)) > 0.25) & (sat > 0.55)
    out = f.copy()
    out[points] = np.clip(np.array([0.42, 0.20, 0.12]) * (0.55 + 0.9 * mx[..., None]), 0, 1)[points]
    body = ~points & (r > g) & (sat > 0.08) & (mx > 0.55)
    grey = f.mean(-1, keepdims=True)
    fleck = (np.random.default_rng(7).random(r.shape) < 0.10)[..., None] * np.array([-0.18, -0.24, -0.26])
    mixed = np.clip(grey + (f - grey) * 0.45 + fleck, 0, 1)
    out[body] = mixed[body]
    return out


def canopy(f: np.ndarray) -> np.ndarray:
    hue, sat, val = _hsv(f)
    leaves = (hue < 16) & (sat > 0.35) & (sat < 0.84) & (val > 0.35)
    leaf = np.array([0.36, 0.62, 0.22])  # fresh leaf green, close to the turf token
    out = f.copy()
    shade = (0.45 + 0.8 * val)[..., None]
    out[leaves] = np.clip(leaf * shade, 0, 1)[leaves]
    return out


PRESETS = {"roan": roan, "canopy": canopy}


def process(slot_dir: Path, fn) -> None:
    slot = slot_dir.name
    src = slot_dir / f"{slot}_hoofed.glb"
    if not src.exists():
        src = slot_dir / f"{slot}.glb"
    js, binc = dh.read_glb(src)
    iv = js["images"][0]["bufferView"]
    bv = js["bufferViews"][iv]
    img = Image.open(io.BytesIO(binc[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]])).convert("RGB")
    fixed = Image.fromarray((fn(np.asarray(img).astype(float) / 255.0) * 255).round().astype(np.uint8))
    fixed.save(slot_dir / f"{slot}_base_color_recolored.png")
    buf = io.BytesIO()
    fixed.save(buf, format="PNG")
    views = [binc[v.get("byteOffset", 0): v.get("byteOffset", 0) + v["byteLength"]] for v in js["bufferViews"]]
    views[iv] = buf.getvalue()
    js["images"][0]["mimeType"] = "image/png"
    dh.write_glb(slot_dir / f"{slot}_recolored.glb", js, views)
    pos, uv, idx = dh.mesh_arrays(js, binc)
    dh.side_check(pos, uv, idx, np.asarray(fixed), slot_dir / f"{slot}_recolored_check.png")
    print(f"  {src.name} -> {slot}_recolored.glb, {slot}_base_color_recolored.png, {slot}_recolored_check.png")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Local texture fixes for generated models")
    ap.add_argument("preset", choices=sorted(PRESETS))
    ap.add_argument("slots", nargs="+")
    ap.add_argument("--models-root", type=Path, default=Path(__file__).resolve().parents[2] / "Models")
    args = ap.parse_args(argv)
    for slot in args.slots:
        print(f"[{slot}] {args.preset}")
        process(args.models_root.expanduser().resolve() / "generated" / slot, PRESETS[args.preset])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
