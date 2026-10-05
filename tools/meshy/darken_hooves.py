# Paint the hooves of a generated horse dark (council: dark, high-contrast hooves on every coat). No credits, no network.
# Finds the four leg tips geometrically (legs = mesh below the belly that reaches the ground; hoof = the last
# HOOF_FRACTION of each leg measured along the surface), rasterizes those triangles in UV space and darkens the texture.
# Every coat is a retexture with enable_original_uv, so one mask fits them all. Writes <slot>_hoofed.glb and
# <slot>_base_color_hoofed.png next to the originals and a <slot>_hoof_check.png side view to eyeball.
#   python tools/meshy/darken_hooves.py horse_gallop_bay horse_gallop_chestnut ... --models-root <dir>/Models
from __future__ import annotations

import argparse
import heapq
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HOOF_DARK = np.array([38, 38, 44], dtype=float)  # near-ink charcoal
KEEP = 0.18  # share of the original texel kept, so the painted hoof still has shading
LEG_CUT = 0.35  # mesh below this fraction of the height counts as legs
GROUND = 0.15  # a leg must reach this low (fraction of height) to count
HOOF_FRACTION = 0.25  # last 25% of each leg's surface length below the cut (tuned on the bay: covers the hoof capsule, not the fetlock)

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    _, _, length = struct.unpack_from("<III", data, 0)
    off, js, binc = 12, None, b""
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        else:
            binc = chunk
        off += 8 + clen
    return js, binc


def write_glb(path: Path, js: dict, views: list[bytes]) -> None:
    binc = bytearray()
    for i, blob in enumerate(views):
        while len(binc) % 4:
            binc.append(0)
        js["bufferViews"][i]["byteOffset"] = len(binc)
        js["bufferViews"][i]["byteLength"] = len(blob)
        js["bufferViews"][i]["buffer"] = 0
        binc += blob
    while len(binc) % 4:
        binc.append(0)
    js["buffers"] = [{"byteLength": len(binc)}]
    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jb += b" " * ((4 - len(jb) % 4) % 4)
    total = 12 + 8 + len(jb) + 8 + len(binc)
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(jb), 0x4E4F534A) + jb + struct.pack("<II", len(binc), 0x004E4942) + bytes(binc))


def accessor(js: dict, binc: bytes, i: int) -> np.ndarray:
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    n = NCOMP[a["type"]]
    dt = np.dtype(COMP[a["componentType"]])
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0) or dt.itemsize * n
    raw = np.frombuffer(binc, dtype=np.uint8, count=stride * (a["count"] - 1) + dt.itemsize * n, offset=start)
    out = np.lib.stride_tricks.as_strided(raw, shape=(a["count"], dt.itemsize * n), strides=(stride, 1)).copy()
    return out.view(dt).reshape(a["count"], n).astype(np.float64)


def mesh_arrays(js: dict, binc: bytes) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    prim = js["meshes"][0]["primitives"][0]
    pos = accessor(js, binc, prim["attributes"]["POSITION"])
    uv = accessor(js, binc, prim["attributes"]["TEXCOORD_0"])
    idx = accessor(js, binc, prim["indices"]).astype(int).reshape(-1, 3)
    return pos, uv, idx


def hoof_triangles(pos: np.ndarray, idx: np.ndarray) -> np.ndarray:
    """Indices of triangles whose three corners lie in a hoof (y is up in glTF)."""
    weld_key = np.round(pos / 1e-4).astype(np.int64)
    _, weld = np.unique(weld_key, axis=0, return_inverse=True)
    weld = weld.ravel()
    wpos = np.zeros((weld.max() + 1, 3))
    wpos[weld] = pos
    y0, y1 = pos[:, 1].min(), pos[:, 1].max()
    h = y1 - y0
    cut = y0 + LEG_CUT * h
    tri_w = weld[idx]
    leg_tri = np.all(wpos[tri_w][:, :, 1] < cut, axis=1)
    adj: dict[int, dict[int, float]] = {}
    for a, b, c in tri_w[leg_tri]:
        for u, v in ((a, b), (b, c), (c, a)):
            d = float(np.linalg.norm(wpos[u] - wpos[v]))
            adj.setdefault(u, {})[v] = d
            adj.setdefault(v, {})[u] = d
    seen: set[int] = set()
    hoof_verts: set[int] = set()
    legs = 0
    for start in adj:
        if start in seen:
            continue
        comp, stack = [], [start]
        seen.add(start)
        while stack:
            u = stack.pop()
            comp.append(u)
            for v in adj[u]:
                if v not in seen:
                    seen.add(v)
                    stack.append(v)
        ys = wpos[comp, 1]
        if ys.min() > y0 + GROUND * h or len(comp) < 20:
            continue
        legs += 1
        top = [u for u in comp if wpos[u, 1] > ys.max() - 0.02 * h]
        dist = {u: 0.0 for u in top}
        heap = [(0.0, u) for u in top]
        while heap:
            d, u = heapq.heappop(heap)
            if d > dist[u]:
                continue
            for v, w in adj[u].items():
                nd = d + w
                if nd < dist.get(v, float("inf")):
                    dist[v] = nd
                    heapq.heappush(heap, (nd, v))
        dmax = max(dist.values())
        hoof_verts.update(u for u, d in dist.items() if d >= dmax * (1 - HOOF_FRACTION))
    print(f"  found {legs} legs, {len(hoof_verts)} hoof vertices")
    if legs != 4:
        print(f"  warning: expected 4 legs, found {legs}; check the _hoof_check.png view")
    in_hoof = np.isin(tri_w, list(hoof_verts))
    return np.where(np.all(in_hoof, axis=1))[0]


def hoof_mask(uv: np.ndarray, idx: np.ndarray, tris: np.ndarray, size: tuple[int, int]) -> Image.Image:
    w, h = size
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    for t in tris:
        pts = [((uv[k, 0] % 1) * w, (uv[k, 1] % 1) * h) for k in idx[t]]
        d.polygon(pts, fill=255)
    return mask.filter(ImageFilter.MaxFilter(5))


def side_check(pos: np.ndarray, uv: np.ndarray, idx: np.ndarray, tex: np.ndarray, out: Path) -> None:
    size = 520
    tri = pos[idx]
    lo, hi = pos.min(0), pos.max(0)
    span = (hi - lo).max()
    c = uv[idx].mean(axis=1)
    th, tw, _ = tex.shape
    col = tex[np.clip((c[:, 1] % 1) * (th - 1), 0, th - 1).astype(int), np.clip((c[:, 0] % 1) * (tw - 1), 0, tw - 1).astype(int)]
    im = Image.new("RGB", (size, size), (198, 138, 82))
    d = ImageDraw.Draw(im)
    sx = -(tri[:, :, 2] - (lo[2] + hi[2]) / 2) / span * size * 0.9 + size / 2
    sy = -(tri[:, :, 1] - (lo[1] + hi[1]) / 2) / span * size * 0.9 + size / 2
    for i in np.argsort(tri[:, :, 0].mean(axis=1)):
        d.polygon([(sx[i, k], sy[i, k]) for k in range(3)], fill=tuple(int(v) for v in col[i]))
    im.save(out)


def process(slot_dir: Path, tris: np.ndarray | None) -> np.ndarray:
    slot = slot_dir.name
    js, binc = read_glb(slot_dir / f"{slot}.glb")
    pos, uv, idx = mesh_arrays(js, binc)
    if tris is None:
        tris = hoof_triangles(pos, idx)
    img_view = js["images"][0]["bufferView"]
    bv = js["bufferViews"][img_view]
    tex_img = Image.open(io.BytesIO(binc[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]])).convert("RGB")
    mask = np.asarray(hoof_mask(uv, idx, tris, tex_img.size), dtype=float)[:, :, None] / 255.0
    tex = np.asarray(tex_img, dtype=float)
    fixed = tex * (1 - mask) + (tex * KEEP + HOOF_DARK * (1 - KEEP)) * mask
    fixed_img = Image.fromarray(np.clip(fixed, 0, 255).astype(np.uint8))
    fixed_img.save(slot_dir / f"{slot}_base_color_hoofed.png")
    buf = io.BytesIO()
    fixed_img.save(buf, format="PNG")
    views = [binc[v.get("byteOffset", 0): v.get("byteOffset", 0) + v["byteLength"]] for v in js["bufferViews"]]
    views[img_view] = buf.getvalue()
    js["images"][0]["mimeType"] = "image/png"
    write_glb(slot_dir / f"{slot}_hoofed.glb", js, views)
    side_check(pos, uv, idx, np.asarray(fixed_img), slot_dir / f"{slot}_hoof_check.png")
    print(f"  wrote {slot}_hoofed.glb, {slot}_base_color_hoofed.png, {slot}_hoof_check.png")
    return tris


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Darken the hooves of generated horses (local, no credits)")
    ap.add_argument("slots", nargs="+")
    ap.add_argument("--models-root", type=Path, default=Path(__file__).resolve().parents[2] / "Models")
    args = ap.parse_args(argv)
    tris = None
    for slot in args.slots:
        print(f"[{slot}]")
        tris = process(args.models_root.expanduser().resolve() / "generated" / slot, tris)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
