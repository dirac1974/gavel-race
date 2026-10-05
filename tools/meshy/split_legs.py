#!/usr/bin/env python3
"""Split a standing horse GLB into a body and four legs, so the game can animate the legs.

Meshy can't rig four-legged animals, so the standing horse (one mesh) is cut into five named
pieces that share its texture: Body (with head and tail), LegFL, LegFR, LegBL, LegBR. The game
swings each leg about its hip (game/src/shared/HorseLegs.luau).

How it cuts (all in the model's own units, Y up):
  - legs are everything below CUT of the height, inside the front or back leg band;
  - bands come from clusters of low vertices along the body axis; the cluster at the very back
    that isn't a leg pair (the long tail) stays with the body;
  - each band splits left/right at the widest gap across the body;
  - a thin OVERLAP band above the cut is copied into each leg, so no gap opens at the hip when
    a leg swings.

  python tools/meshy/split_legs.py Models/generated/horse_stand_bay/horse_stand_bay_hoofed.glb out.glb [--debug out.png]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import trimesh

CUT = 0.38       # legs below this fraction of the height
OVERLAP = 0.04   # copied into the legs above the cut (fraction of the height)
LOW = 0.30       # vertices below this fraction find the leg bands


def clusters(values: np.ndarray, gap: float) -> list[tuple[float, float]]:
    xs = np.sort(values)
    if len(xs) == 0:
        return []
    out, start = [], 0
    for i in np.where(np.diff(xs) > gap)[0]:
        out.append((float(xs[start]), float(xs[i])))
        start = i + 1
    out.append((float(xs[start]), float(xs[-1])))
    return out


def split_two(values: np.ndarray) -> float:
    """Split point at the widest gap (left/right legs of a pair)."""
    xs = np.sort(values)
    gaps = np.diff(xs)
    i = int(np.argmax(gaps))
    return float((xs[i] + xs[i + 1]) / 2)


def split(mesh: trimesh.Trimesh) -> dict[str, trimesh.Trimesh]:
    v = mesh.vertices
    y0, y1 = v[:, 1].min(), v[:, 1].max()
    H = y1 - y0
    # Head end: the end of the long axis whose highest point is higher.
    z = v[:, 2]
    zr = z.max() - z.min()
    head_plus = v[z > z.max() - 0.2 * zr, 1].max() > v[z < z.min() + 0.2 * zr, 1].max()
    fwd = 1.0 if head_plus else -1.0

    low = v[v[:, 1] < y0 + LOW * H]
    bands = clusters(low[:, 2] * fwd, gap=0.06 * zr)  # in "forward" coordinates, back to front
    bands = [b for b in bands if b[1] - b[0] > 0.02 * zr]
    if len(bands) >= 3:
        bands = bands[-2:]  # the back-most extra cluster is the tail
    if len(bands) != 2:
        raise SystemExit(f"expected two leg bands, found {len(bands)}: {bands}")
    back, front = bands
    pad = 0.04 * zr

    centroids = mesh.triangles_center
    cy, cz, cx = centroids[:, 1], centroids[:, 2] * fwd, centroids[:, 0]
    cut_y = y0 + CUT * H
    top_y = cut_y + OVERLAP * H

    pieces: dict[str, list[int]] = {"Body": []}
    leg_faces: dict[str, np.ndarray] = {}
    for tag, (za, zb) in (("B", back), ("F", front)):
        in_band = (cz > za - pad) & (cz < zb + pad)
        low_band = low[(low[:, 2] * fwd > za - pad) & (low[:, 2] * fwd < zb + pad)]
        x_split = split_two(low_band[:, 0])
        # left/right as seen by the horse: with Y up and forward along fwd·Z, its right is −fwd·X
        for side, sel in (("R", cx * fwd < x_split * fwd), ("L", cx * fwd >= x_split * fwd)):
            leg_faces[f"Leg{tag}{side}"] = np.where(in_band & sel & (cy < top_y))[0]
    in_leg = np.zeros(len(centroids), dtype=bool)
    for name, faces in leg_faces.items():
        pieces[name] = faces.tolist()
        in_leg[faces[cy[faces] < cut_y]] = True  # the overlap band stays on the body too
    pieces["Body"] = np.where(~in_leg)[0].tolist()

    out = {}
    for name, faces in pieces.items():
        if len(faces) == 0:
            raise SystemExit(f"{name} is empty")
        sub = mesh.submesh([np.array(faces)], append=True, repair=False)
        out[name] = sub
    return out


def debug_png(parts: dict[str, trimesh.Trimesh], path: Path) -> None:
    from PIL import Image, ImageDraw
    colours = {"Body": (180, 180, 180), "LegFL": (230, 80, 80), "LegFR": (80, 160, 230),
               "LegBL": (240, 200, 60), "LegBR": (80, 190, 110)}
    img = Image.new("RGB", (900, 450), (255, 255, 255))
    d = ImageDraw.Draw(img)
    allv = np.vstack([p.vertices for p in parts.values()])
    lo, hi = allv.min(0), allv.max(0)
    for col, (ax_h, ax_v, ox) in enumerate(((2, 1, 0), (0, 1, 450))):
        for name, p in parts.items():
            for c in p.triangles_center[:: max(1, len(p.faces) // 1500)]:
                x = ox + 20 + (c[ax_h] - lo[ax_h]) / (hi[ax_h] - lo[ax_h]) * 410
                y = 430 - (c[ax_v] - lo[ax_v]) / (hi[ax_v] - lo[ax_v]) * 410
                d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=colours.get(name, (0, 0, 0)))
    img.save(path)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    ap.add_argument("--debug", type=Path)
    a = ap.parse_args()
    scene = trimesh.load(a.src)
    mesh = list(scene.geometry.values())[0] if isinstance(scene, trimesh.Scene) else scene
    parts = split(mesh)
    out = trimesh.Scene()
    for name, p in parts.items():
        out.add_geometry(p, node_name=name, geom_name=name)
    a.dst.parent.mkdir(parents=True, exist_ok=True)
    out.export(a.dst, file_type="glb")
    if a.debug:
        debug_png(parts, a.debug)
    print(a.dst, {k: len(v.faces) for k, v in parts.items()})


if __name__ == "__main__":
    sys.exit(main())
