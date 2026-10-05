# Textured 4-view preview of a generated GLB (side +X/-X, front +Z, top) for art review; flat shading, painter's algorithm.
#   python tools/meshy/preview_glb.py Models/generated/<slot>/<slot>.glb out.png
from __future__ import annotations

import io
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path: Path) -> tuple[dict, bytes]:
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


def node_matrix(node: dict) -> np.ndarray:
    if "matrix" in node:
        return np.array(node["matrix"]).reshape(4, 4).T
    m = np.eye(4)
    if "scale" in node:
        m = np.diag(list(node["scale"]) + [1]) @ m
    if "rotation" in node:
        x, y, z, w = node["rotation"]
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        rm = np.eye(4)
        rm[:3, :3] = r
        m = rm @ m
    if "translation" in node:
        t = np.eye(4)
        t[:3, 3] = node["translation"]
        m = t @ m
    return m


def main() -> None:
    path, out = Path(sys.argv[1]), Path(sys.argv[2])
    js, binc = load(path)
    tris, cols = [], []
    tex = None
    if js.get("images"):
        img = js["images"][0]
        bv = js["bufferViews"][img["bufferView"]]
        tex = np.asarray(Image.open(io.BytesIO(binc[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]])).convert("RGB"))
    for ni, node in enumerate(js["nodes"]):
        if "mesh" not in node:
            continue
        m = node_matrix(node)
        for prim in js["meshes"][node["mesh"]]["primitives"]:
            pos = accessor(js, binc, prim["attributes"]["POSITION"])
            pos = (np.c_[pos, np.ones(len(pos))] @ m.T)[:, :3]
            idx = accessor(js, binc, prim["indices"]).astype(int).reshape(-1, 3) if "indices" in prim else np.arange(len(pos)).reshape(-1, 3)
            uv = accessor(js, binc, prim["attributes"]["TEXCOORD_0"]) if "TEXCOORD_0" in prim["attributes"] else None
            tri = pos[idx]
            tris.append(tri)
            if uv is not None and tex is not None:
                c = uv[idx].mean(axis=1)
                h, w, _ = tex.shape
                px = np.clip((c[:, 0] % 1) * (w - 1), 0, w - 1).astype(int)
                py = np.clip((c[:, 1] % 1) * (h - 1), 0, h - 1).astype(int)
                cols.append(tex[py, px].astype(float))
            else:
                cols.append(np.full((len(tri), 3), 180.0))
    tri = np.concatenate(tris)
    col = np.concatenate(cols)
    lo, hi = tri.reshape(-1, 3).min(0), tri.reshape(-1, 3).max(0)
    print(f"{path.name}: {len(tri)} tris, bbox min {np.round(lo, 3)} max {np.round(hi, 3)} size {np.round(hi - lo, 3)}")
    views = {  # name: (right axis, up axis, depth axis toward viewer)
        "side +X": (np.array([0, 0, -1.0]), np.array([0, 1.0, 0]), np.array([1.0, 0, 0])),
        "side -X": (np.array([0, 0, 1.0]), np.array([0, 1.0, 0]), np.array([-1.0, 0, 0])),
        "front +Z": (np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0])),
        "top": (np.array([1.0, 0, 0]), np.array([0, 0, -1.0]), np.array([0, 1.0, 0])),
    }
    size = 420
    sheet = Image.new("RGB", (size * len(views), size + 24), (142, 214, 255))
    light = np.array([0.4, 0.8, 0.45])
    light /= np.linalg.norm(light)
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
    shade = 0.45 + 0.55 * np.abs(n @ light)
    center = (lo + hi) / 2
    span = (hi - lo).max()
    for vi, (name, (rx, uy, dz)) in enumerate(views.items()):
        im = Image.new("RGB", (size, size), (142, 214, 255) if "top" not in name else (198, 138, 82))
        d = ImageDraw.Draw(im)
        p = tri - center
        sx = (p @ rx) / span * size * 0.9 + size / 2
        sy = -(p @ uy) / span * size * 0.9 + size / 2
        depth = (p @ dz).mean(axis=1)
        for i in np.argsort(depth):
            c = tuple(int(v) for v in np.clip(col[i] * shade[i], 0, 255))
            d.polygon([(sx[i, k], sy[i, k]) for k in range(3)], fill=c)
        sheet.paste(im, (vi * size, 24))
        ImageDraw.Draw(sheet).text((vi * size + 8, 6), name, fill=(29, 36, 51))
    sheet.save(out)


if __name__ == "__main__":
    main()
