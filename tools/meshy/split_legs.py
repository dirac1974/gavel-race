#!/usr/bin/env python3
"""Split a standing horse GLB into a body and four legs, so the game can animate the legs.

Meshy can't rig four-legged animals, so the standing horse (one mesh) is cut into named pieces
that share its texture: Body (with head and tail), LegFL, LegFR, LegBL, LegBR, and Cloth, a thin
shell over the back where a saddle cloth sits (hidden until the game tints it). The game swings
each leg about its hip (game/src/shared/HorseLegs.luau).

How it cuts (all in the model's own units, Y up):
  - legs are everything below CUT of the height, inside the front or back leg band;
  - bands come from clusters of low vertices along the body axis; the cluster at the very back
    that isn't a leg pair (the long tail) stays with the body;
  - each band splits left/right at the widest gap across the body;
  - a thin OVERLAP band above the cut is copied into each leg, so no gap opens at the hip when
    a leg swings; only overlap faces right above that leg's own faces are copied (strips of
    belly would swing out as flaps);
  - the cloth is a clean blanket just behind the withers (where the top line starts climbing
    into the neck): a grid of rays cast in toward the barrel lands on the body, lifted a little.
Normals from the source are kept (a file without normals gets flat, faceted shading).

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
NECK_RISE = 0.05    # the neck starts where the top line climbs this far above the back (of the height)
CLOTH_GAP = 0.04    # cloth's front edge this far behind the neck (fraction of the leg-band gap)
CLOTH_LEN = 0.42    # cloth length (fraction of the leg-band gap)
CLOTH_WRAP = 1.5    # radians around the barrel from the top line, each side (about 86°)
CLOTH_LIFT = 0.02   # lifted off the body (fraction of the height)


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


def cloth_window(mesh: trimesh.Trimesh, body: np.ndarray, cz: np.ndarray, back: tuple, front: tuple) -> tuple[float, float]:
    """Where the saddle cloth goes along the body ("forward" coordinates): just behind the withers,
    where the top line between the leg bands starts climbing into the neck."""
    c = mesh.triangles_center
    y = mesh.vertices[:, 1]
    H = y.max() - y.min()
    zb, zf = (back[0] + back[1]) / 2, (front[0] + front[1]) / 2
    span = zf - zb
    idx = np.where(body & (cz >= zb) & (cz <= zf))[0]
    edges = np.linspace(zb, zf, 21)
    tops = []
    for a, b in zip(edges[:-1], edges[1:]):
        s = idx[(cz[idx] >= a) & (cz[idx] < b)]
        tops.append(c[s, 1].max() if len(s) else np.nan)
    tops = np.array(tops)
    back_level = float(np.nanmedian(tops[: len(tops) // 2]))
    climb = np.where(tops > back_level + NECK_RISE * H)[0]
    neck_z = edges[climb[0]] if len(climb) else zf
    zz = neck_z - CLOTH_GAP * span
    return zz - CLOTH_LEN * span, zz


def first_hits(tris: np.ndarray, origins: np.ndarray, dirs: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Nearest triangle each ray hits (Möller–Trumbore, no extra packages): (points, triangle index
    or -1)."""
    v0, e1, e2 = tris[:, 0], tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0]
    pts = np.zeros_like(origins)
    which = np.full(len(origins), -1)
    for i, (o, d) in enumerate(zip(origins, dirs)):
        p = np.cross(d, e2)
        det = np.einsum("ij,ij->i", e1, p)
        ok = np.abs(det) > 1e-12
        inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
        tv = o - v0
        u = np.einsum("ij,ij->i", tv, p) * inv
        q = np.cross(tv, e1)
        v = (q @ d) * inv
        t = np.einsum("ij,ij->i", e2, q) * inv
        hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-9)
        if hit.any():
            j = np.where(hit)[0][np.argmin(t[hit])]
            pts[i], which[i] = o + d * t[j], j
    return pts, which


def cloth_mesh(mesh: trimesh.Trimesh, body_faces: np.ndarray, za: float, zz: float, fwd: float) -> trimesh.Trimesh:
    """A clean blanket over the back: a grid of rays cast in toward the barrel's axis, each landing
    on the body and lifted a little off it. Rows run along the body, columns around the barrel from
    one side, over the top, to the other side. UVs follow the grid (u around, v along)."""
    body = mesh.submesh([body_faces], append=True, repair=False)
    y = mesh.vertices[:, 1]
    H = y.max() - y.min()
    lift = CLOTH_LIFT * H
    rows, cols = 12, 23
    zs = np.linspace(za, zz, rows)
    thetas = np.linspace(-CLOTH_WRAP, CLOTH_WRAP, cols)  # 0 = straight up, ± = down each side
    bc = body.triangles_center
    bz = bc[:, 2] * fwd
    tris = body.triangles
    grid = np.zeros((rows, cols, 3))
    for r, zf_ in enumerate(zs):
        sl = bc[np.abs(bz - zf_) < 0.03 * (zz - za + 1e-9) + 0.01]
        cx = float(np.median(sl[:, 0])) if len(sl) else 0.0
        cy = float((sl[:, 1].max() + sl[:, 1].min()) / 2) if len(sl) else 0.0
        z = zf_ * fwd
        origins, dirs = [], []
        for t in thetas:
            d = np.array([np.sin(t), np.cos(t), 0.0])
            origins.append(np.array([cx, cy, z]) + d * 2.0 * H)
            dirs.append(-d)
        locs, tri_idx = first_hits(tris, np.array(origins), np.array(dirs))
        for k in range(cols):
            if tri_idx[k] >= 0:
                n = body.face_normals[tri_idx[k]]
                if np.dot(n, -dirs[k]) < 0:
                    n = -n
                grid[r, k] = locs[k] + (n * 0.5 + (-dirs[k]) * 0.5) * lift
            else:
                grid[r, k] = np.array([cx, cy, z]) + (-dirs[k]) * 0.25 * H
    verts = grid.reshape(-1, 3)
    faces = []
    for r in range(rows - 1):
        for k in range(cols - 1):
            a, b, c2, d = r * cols + k, r * cols + k + 1, (r + 1) * cols + k, (r + 1) * cols + k + 1
            faces += [[a, c2, b], [b, c2, d]]
    uv = np.array([[k / (cols - 1), r / (rows - 1)] for r in range(rows) for k in range(cols)])
    cloth = trimesh.Trimesh(vertices=verts, faces=np.array(faces), process=False)
    # Faces point outward (away from the barrel's middle).
    centre = verts.mean(0) - np.array([0, 0.3 * H, 0])
    if np.mean(np.einsum("ij,ij->i", cloth.face_normals, cloth.triangles_center - centre)) < 0:
        cloth.faces = cloth.faces[:, ::-1]
    cloth.visual = trimesh.visual.TextureVisuals(uv=uv, material=mesh.visual.material)
    return cloth


def split(mesh: trimesh.Trimesh) -> tuple[dict[str, np.ndarray], tuple[float, float], float]:
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
    hug = 0.015 * zr  # how far outside a leg's own faces an overlap face may sit

    centroids = mesh.triangles_center
    cy, cz, cx = centroids[:, 1], centroids[:, 2] * fwd, centroids[:, 0]
    cut_y = y0 + CUT * H
    top_y = cut_y + OVERLAP * H

    pieces: dict[str, np.ndarray] = {}
    for tag, (za, zb) in (("B", back), ("F", front)):
        in_band = (cz > za - pad) & (cz < zb + pad)
        low_band = low[(low[:, 2] * fwd > za - pad) & (low[:, 2] * fwd < zb + pad)]
        x_split = split_two(low_band[:, 0])
        # left/right as seen by the horse: with Y up and forward along fwd·Z, its right is −fwd·X
        for side, sel in (("R", cx * fwd < x_split * fwd), ("L", cx * fwd >= x_split * fwd)):
            below = np.where(in_band & sel & (cy < cut_y))[0]
            if len(below) == 0:
                raise SystemExit(f"Leg{tag}{side} is empty")
            x_lo, x_hi = cx[below].min() - hug, cx[below].max() + hug
            z_lo, z_hi = cz[below].min() - hug, cz[below].max() + hug
            over = np.where(in_band & sel & (cy >= cut_y) & (cy < top_y)
                            & (cx >= x_lo) & (cx <= x_hi) & (cz >= z_lo) & (cz <= z_hi))[0]
            pieces[f"Leg{tag}{side}"] = np.concatenate([below, over])
    in_leg = np.zeros(len(centroids), dtype=bool)
    for name, faces in pieces.items():
        in_leg[faces[cy[faces] < cut_y]] = True  # the overlap band stays on the body too
    pieces["Body"] = np.where(~in_leg)[0]
    for name, faces in pieces.items():
        if len(faces) == 0:
            raise SystemExit(f"{name} is empty")
    window = cloth_window(mesh, ~in_leg, cz, back, front)
    return pieces, window, fwd


def piece(mesh: trimesh.Trimesh, faces: np.ndarray) -> trimesh.Trimesh:
    """A submesh that keeps the source normals (and UVs)."""
    faces = np.sort(faces)
    idx = np.unique(mesh.faces[faces].reshape(-1))
    sub = mesh.submesh([faces], append=True, repair=False)
    sub.vertex_normals = mesh.vertex_normals[idx]
    return sub


def debug_png(parts: dict[str, trimesh.Trimesh], path: Path) -> None:
    from PIL import Image, ImageDraw
    colours = {"Body": (180, 180, 180), "LegFL": (230, 80, 80), "LegFR": (80, 160, 230),
               "LegBL": (240, 200, 60), "LegBR": (80, 190, 110), "Cloth": (150, 60, 200)}
    img = Image.new("RGB", (1350, 450), (255, 255, 255))
    d = ImageDraw.Draw(img)
    allv = np.vstack([p.vertices for p in parts.values()])
    lo, hi = allv.min(0), allv.max(0)
    # side (z,y), front (x,y), top (z,x)
    for ax_h, ax_v, ox in ((2, 1, 0), (0, 1, 450), (2, 0, 900)):
        for name in ("Body", "LegFL", "LegFR", "LegBL", "LegBR", "Cloth"):
            p = parts[name]
            for c in p.triangles_center[:: max(1, len(p.faces) // 2500)]:
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
    faces, (za, zz), fwd = split(mesh)
    parts = {name: piece(mesh, f) for name, f in faces.items()}
    parts["Cloth"] = cloth_mesh(mesh, faces["Body"], za, zz, fwd)
    out = trimesh.Scene()
    for name, p in parts.items():
        out.add_geometry(p, node_name=name, geom_name=name)
    a.dst.parent.mkdir(parents=True, exist_ok=True)
    out.export(a.dst, file_type="glb", include_normals=True)
    if a.debug:
        debug_png(parts, a.debug)
    print(a.dst, {k: len(v.faces) for k, v in parts.items()})


if __name__ == "__main__":
    sys.exit(main())
