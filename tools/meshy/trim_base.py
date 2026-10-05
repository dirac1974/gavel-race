# Remove a ground plate Meshy added under a model (local, no credits). Drops every triangle that lies wholly below
# --cut (a fraction of the model's height), or whose centre is below --cut-wide and farther than --radius from the
# vertical axis (the plate's rim), then compacts the vertices so the bounding box shrinks to what is left. Writes
# <slot>_trimmed.glb and <slot>_trimmed_check.png (side view) next to Meshy's own <slot>.glb, which is never touched.
#   python tools/meshy/trim_base.py race_board_frame --cut 0.065 --models-root <main checkout>/Models
from __future__ import annotations

import argparse
import io
from pathlib import Path

import numpy as np
from PIL import Image

import darken_hooves as dh


def trim(slot_dir: Path, cut: float, cut_wide: float, radius: float) -> None:
    slot = slot_dir.name
    js, binc = dh.read_glb(slot_dir / f"{slot}.glb")
    prim = js["meshes"][0]["primitives"][0]
    pos, uv, idx = dh.mesh_arrays(js, binc)
    y0, y1 = pos[:, 1].min(), pos[:, 1].max()
    rel = (pos[:, 1] - y0) / (y1 - y0)
    tri_rel = rel[idx]
    centre = pos[idx].mean(axis=1)
    wide = (centre[:, 1] - y0) / (y1 - y0) < cut_wide
    far = np.hypot(centre[:, 0], centre[:, 2]) > radius
    drop = np.all(tri_rel < cut, axis=1) | (wide & far)
    keep_tris = idx[~drop]
    used = np.unique(keep_tris)
    remap = np.full(len(pos), -1, dtype=np.int64)
    remap[used] = np.arange(len(used))
    new_idx = remap[keep_tris].astype(np.uint32)

    views = [binc[v.get("byteOffset", 0): v.get("byteOffset", 0) + v["byteLength"]] for v in js["bufferViews"]]
    ia = js["accessors"][prim["indices"]]
    ia.update({"componentType": 5125, "count": int(new_idx.size), "byteOffset": 0})
    views[ia["bufferView"]] = new_idx.tobytes()
    for name, ai in prim["attributes"].items():
        acc = js["accessors"][ai]
        data = dh.accessor(js, binc, ai).astype(np.float32)[used]
        acc.update({"count": int(len(used)), "byteOffset": 0, "componentType": 5126})
        js["bufferViews"][acc["bufferView"]].pop("byteStride", None)
        if "min" in acc:
            acc["min"], acc["max"] = data.min(0).tolist(), data.max(0).tolist()
        views[acc["bufferView"]] = data.tobytes()
    dh.write_glb(slot_dir / f"{slot}_trimmed.glb", js, views)

    img_view = js["images"][0]["bufferView"]
    tex = np.asarray(Image.open(io.BytesIO(views[img_view])).convert("RGB"))
    dh.side_check(pos[used], uv[used], new_idx.reshape(-1, 3).astype(int), tex, slot_dir / f"{slot}_trimmed_check.png")
    print(f"  dropped {int(drop.sum())} of {len(idx)} triangles; wrote {slot}_trimmed.glb and {slot}_trimmed_check.png")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Remove a ground plate from a generated model (local)")
    ap.add_argument("slots", nargs="+")
    ap.add_argument("--cut", type=float, default=0.065, help="drop triangles wholly below this share of the height")
    ap.add_argument("--cut-wide", type=float, default=0.10, help="...and plate-rim triangles centred below this share")
    ap.add_argument("--radius", type=float, default=0.5, help="plate rim = centre farther than this from the axis (glTF units)")
    ap.add_argument("--models-root", type=Path, default=Path(__file__).resolve().parents[2] / "Models")
    args = ap.parse_args(argv)
    for slot in args.slots:
        print(f"[{slot}]")
        trim(args.models_root.expanduser().resolve() / "generated" / slot, args.cut, args.cut_wide, args.radius)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
