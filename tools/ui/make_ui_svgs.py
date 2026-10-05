# Race UI art as SVG (assets/ui/<name>.svg), a review sheet (assets/ui/_sheet.svg) and 2x PNGs (assets/ui/png/).
# Style: docs/art/ART_DIRECTION.md; council review: docs/art/ART_REVIEW.md. Chunky shapes, ink outline painted under
# the fill, every state = shape + colour. In game, words and numbers are TextLabels: use the *_blank variants; the baked
# text in the other variants is for review and placeholders.
#   python tools/ui/make_ui_svgs.py            # SVGs + sheet + PNGs (PNGs need: pip install resvg-py)
#   python tools/ui/make_ui_svgs.py --no-png
from __future__ import annotations

import argparse
import math
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "ui"
PNG_OUT = OUT / "png"
PNG_ZOOM = 2  # every 128 px icon exports at 256 px

INK = "#1D2433"
WHITE = "#FFFFFF"
PAPER = "#FFF7E6"
ORANGE = "#FF9F1C"
ORANGE_DARK = "#D97A00"
ORANGE_PRESSED = "#F28C00"
GOLD = "#FFD23F"
GOLD_LIGHT = "#FFE98A"
SLATE = "#2A3247"
TEAL = "#17A398"
PLUM = "#7D6B91"
DIRT = "#C68A52"
FONT = "Fredoka One, Arial Rounded MT Bold, Arial Black, Arial, sans-serif"

FEEDBACK = {  # label: colour (shape is in the drawing)
    "perfect": GOLD,
    "great": "#4CC3FF",
    "good": "#3CC46A",
    "okay": "#CBB89D",
    "miss": "#9A8FB0",
    "steady": "#F2A65A",
}

LANES: list[tuple[str, str, bool]] = [  # (hex, pattern, light hue -> ink pattern), fixed per lane number (council 5)
    ("#D55E00", "solid", False),
    ("#56B4E9", "hoops", True),
    ("#F0E442", "dots", True),
    ("#009E73", "chevrons", False),
    ("#CC79A7", "sash", False),
    ("#E69F00", "checks", False),
    ("#0072B2", "stars", False),
    ("#3A3F4B", "diamonds", False),
]

RIBBONS: list[tuple[str, str, str, int]] = [  # (name, pleat, inner ring, place)
    ("blue", "#2F6FDE", "#1F55B8", 1),
    ("red", "#E0474C", "#B8323A", 2),
    ("yellow", GOLD, "#E8B21F", 3),
    ("white", WHITE, "#DDE2EA", 4),
]

HOOF = "M64 12 C94 12 112 38 112 68 C112 94 100 114 84 114 L74 114 L64 100 L54 114 L44 114 C28 114 16 94 16 68 C16 38 34 12 64 12 Z"
SHOE = "M36 104 C26 90 24 62 34 46 C42 32 54 26 64 26 C74 26 86 32 94 46 C104 62 102 90 92 104"
NAILS = [(31, 84), (30, 62), (38, 42), (97, 84), (98, 62), (90, 42)]

# Rings (council 7): every ring takes RING_CLOSE_S to close from RING_SPAWN x the hoof radius; tempo shows as spacing.
RING_SPAWN = 3.0
RING_CLOSE_S = 1.0
RING_ALPHA = [1.0, 0.7, 0.45]  # next ring to land, then the ones behind it


def solid(fill: str, *els: str, outline: int = 12) -> str:
    """Filled shapes with the ink outline painted underneath (half the stroke shows outside the shape)."""
    return (
        f'<g fill="{fill}" stroke="{INK}" stroke-width="{outline}" stroke-linejoin="round" '
        f'stroke-linecap="round" paint-order="stroke">{"".join(els)}</g>'
    )


def band(d: str, w: int, colour: str, outline: int = 12) -> str:
    """A thick coloured stroke with an ink outline."""
    return (
        f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{w + outline}" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'
    )


def text(x: float, y: float, s: str, size: int, fill: str = INK, stroke: str = "", sw: int = 0) -> str:
    st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" paint-order="stroke"' if stroke else ""
    return f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="900" fill="{fill}" text-anchor="middle"{st}>{s}</text>'


def star_points(cx: float, cy: float, outer: float, inner: float, n: int = 5, rot: float = -90) -> str:
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + i * 180 / n)
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(pts)


def hoof_glyph(fill: str = WHITE) -> str:
    nails = "".join(f'<circle cx="{x}" cy="{y}" r="2.6"/>' for x, y in NAILS)
    return (
        solid(fill, f'<path d="{HOOF}"/>')
        + f'<path d="{SHOE}" fill="none" stroke="{INK}" stroke-width="11" stroke-linecap="round"/>'
        + f'<g fill="{fill}">{nails}</g>'
    )


def ring_circle(cx: float, cy: float, r: float, w: float = 6, colour: str = WHITE, alpha: float = 1.0) -> str:
    """A ring with a constant on-screen stroke (what a UIStroke ring draws) and a thin ink edge each side."""
    return (
        f'<g opacity="{alpha}"><circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="none" stroke="{INK}" stroke-width="{w + 6}"/>'
        f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="none" stroke="{colour}" stroke-width="{w}"/></g>'
    )


def giddyup_pad(state: str) -> str:
    """Bottom-of-screen affordance (council 6). Not an aim target: taps count anywhere."""
    label = "" if state == "blank" else text(256, 106 if state != "pressed" else 120, "GIDDY-UP!", 62, WHITE, INK, 12)
    if state == "pressed":
        return solid(ORANGE_PRESSED, '<rect x="16" y="28" width="480" height="136" rx="68"/>') + label
    return (
        solid(ORANGE_DARK, '<rect x="16" y="30" width="480" height="136" rx="68"/>')
        + solid(ORANGE, '<rect x="16" y="14" width="480" height="136" rx="68"/>')
        + f'<rect x="70" y="26" width="372" height="20" rx="10" fill="{WHITE}" opacity="0.3"/>'
        + label
    )


def burst_bar() -> str:
    ticks = "".join(
        f'<path d="M{12 + 1000 * i / 10:.0f} 48 L{12 + 1000 * i / 10:.0f} 80" stroke="{WHITE}" stroke-opacity="0.25" stroke-width="5" stroke-linecap="round"/>'
        for i in range(1, 10)
    )
    return solid(SLATE, '<rect x="12" y="28" width="1000" height="72" rx="36"/>') + f'<rect x="32" y="38" width="960" height="14" rx="7" fill="{WHITE}" opacity="0.10"/>' + ticks


def burst_glow(pid: str) -> str:
    stripes = "".join(f'<path d="M{x} 110 L{x + 80} 18" stroke="{GOLD_LIGHT}" stroke-width="10"/>' for x in range(-40, 240, 26))
    return (
        f'<defs><radialGradient id="{pid}g" cx="50%" cy="50%" r="50%">'
        f'<stop offset="0" stop-color="{GOLD}" stop-opacity="0.85"/><stop offset="0.6" stop-color="{GOLD}" stop-opacity="0.35"/>'
        f'<stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></radialGradient>'
        f'<clipPath id="{pid}c"><rect x="56" y="28" width="144" height="72" rx="14"/></clipPath></defs>'
        f'<ellipse cx="128" cy="64" rx="126" ry="62" fill="url(#{pid}g)"/>'
        + solid(GOLD, '<rect x="56" y="28" width="144" height="72" rx="14"/>', outline=8)
        + f'<g clip-path="url(#{pid}c)">{stripes}</g>'
        + f'<rect x="56" y="28" width="144" height="72" rx="14" fill="none" stroke="{INK}" stroke-width="4"/>'
        + f'<rect x="68" y="35" width="120" height="9" rx="4.5" fill="{WHITE}" opacity="0.55"/>'
    )


def burst_marker() -> str:
    return solid(WHITE, '<path d="M10 8 L54 8 L32 38 Z"/>', '<rect x="22" y="38" width="20" height="112" rx="10"/>')


def burst_rays(pid: str) -> str:
    """Perfect celebration behind the player's horse, own screen only, after scoring (council 4)."""
    rays = []
    for i in range(12):
        a0, a1 = math.radians(i * 30 - 6), math.radians(i * 30 + 6)
        rays.append(f'<path d="M128 128 L{128 + 124 * math.cos(a0):.1f} {128 + 124 * math.sin(a0):.1f} L{128 + 124 * math.cos(a1):.1f} {128 + 124 * math.sin(a1):.1f} Z"/>')
    return (
        f'<defs><radialGradient id="{pid}r" cx="50%" cy="50%" r="50%">'
        f'<stop offset="0" stop-color="{WHITE}" stop-opacity="1"/><stop offset="0.3" stop-color="{GOLD}" stop-opacity="1"/>'
        f'<stop offset="1" stop-color="#FFB000" stop-opacity="0"/></radialGradient></defs>'
        f'<g fill="url(#{pid}r)">{"".join(rays)}</g>'
    )


def fx_dust_puff(pid: str) -> str:
    """Particle: one puff per hoof per beat. White so ParticleEmitter.Color tints it to the track (dirt #E3B985)."""
    blobs = [(64, 74, 34), (40, 82, 22), (90, 80, 24), (58, 52, 22), (80, 58, 18)]
    return (
        f'<defs><radialGradient id="{pid}p" cx="50%" cy="45%" r="50%"><stop offset="0.55" stop-color="{WHITE}" stop-opacity="0.95"/>'
        f'<stop offset="1" stop-color="{WHITE}" stop-opacity="0"/></radialGradient></defs>'
        + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#{pid}p)"/>' for x, y, r in blobs)
    )


def fx_mane_flick() -> str:
    """Particle: a quick hair flick from the crest on each beat (the mesh is static). White, tinted to the mane colour."""
    strokes = ["M18 104 C40 70 70 52 112 40", "M26 112 C52 86 80 72 116 66", "M14 90 C30 60 52 40 86 22"]
    return "".join(
        f'<path d="{d}" fill="none" stroke="{WHITE}" stroke-width="{w}" stroke-linecap="round" opacity="{o}"/>'
        for d, w, o in zip(strokes, (14, 10, 8), (1.0, 0.85, 0.7))
    )


def feedback(name: str) -> str:
    c = FEEDBACK[name]
    if name == "perfect":
        return solid(c, f'<polygon points="{star_points(64, 68, 56, 25)}"/>') + f'<ellipse cx="52" cy="52" rx="9" ry="5" fill="{WHITE}" opacity="0.7" transform="rotate(-35 52 52)"/>'
    if name == "great":
        return band("M28 72 L64 40 L100 72", 18, c) + band("M28 104 L64 72 L100 104", 18, c)
    if name == "good":
        return band("M26 66 L52 92 L104 38", 22, c)
    if name == "okay":
        return solid(c, '<circle cx="64" cy="64" r="30"/>')
    if name == "miss":
        return band("M30 64 L98 64", 22, c)
    return band("M16 64 C28 38 40 38 50 64 S74 90 84 64 S104 42 112 56", 16, c)  # steady (mashing)


def lane_pattern(pattern: str, colour: str) -> str:
    if pattern == "solid":
        return ""
    if pattern == "hoops":
        return "".join(f'<rect x="0" y="{y}" width="128" height="14" fill="{colour}"/>' for y in (22, 56, 90))
    if pattern == "dots":
        return "".join(f'<circle cx="{x}" cy="{y}" r="7" fill="{colour}"/>' for x in range(20, 128, 26) for y in range(20, 128, 26))
    if pattern == "chevrons":
        return "".join(f'<path d="M-4 {y + 24} L64 {y} L132 {y + 24}" fill="none" stroke="{colour}" stroke-width="10"/>' for y in range(4, 128, 30))
    if pattern == "sash":
        return f'<path d="M-10 138 L138 -10" stroke="{colour}" stroke-width="38"/>'
    if pattern == "checks":
        return "".join(f'<rect x="{10 + i * 27}" y="{10 + j * 27}" width="27" height="27" fill="{colour}"/>' for i in range(4) for j in range(4) if (i + j) % 2 == 0)
    if pattern == "stars":
        spots = [(30, 30), (98, 30), (30, 98), (98, 98), (64, 18), (64, 110), (18, 64), (110, 64)]
        return "".join(f'<polygon points="{star_points(x, y, 12, 5)}" fill="{colour}"/>' for x, y in spots)
    if pattern == "diamonds":
        return "".join(
            f'<path d="M{x} {y - 12} L{x + 9} {y} L{x} {y + 12} L{x - 9} {y} Z" fill="{colour}"/>'
            for x in range(16, 128, 32) for y in range(16, 128, 32)
        )
    raise ValueError(pattern)


def lane_chip(n: int, pid: str, number: bool = True) -> str:
    colour, pattern, light = LANES[n - 1]
    pcol = INK if light else WHITE
    op = "0.45" if light else "0.85"
    body = '<rect x="10" y="10" width="108" height="108" rx="26"/>'
    return (
        f'<defs><clipPath id="{pid}c">{body}</clipPath></defs>'
        + solid(colour, body)
        + f'<g clip-path="url(#{pid}c)" opacity="{op}">{lane_pattern(pattern, pcol)}</g>'
        + f'<rect x="10" y="10" width="108" height="108" rx="26" fill="none" stroke="{INK}" stroke-width="6"/>'
        + solid(WHITE, '<circle cx="64" cy="64" r="30"/>', outline=8)
        + (text(64, 78, str(n), 40) if number else "")
    )


def lane_sparkle() -> str:
    """Overlay for any lane chip: shown to other players when that rider scores a Perfect burst (council 4)."""
    spots = [(106, 20, 20), (20, 106, 14), (114, 98, 10)]
    return solid(GOLD, *(f'<polygon points="{star_points(x, y, r, r * 0.32, 4)}"/>' for x, y, r in spots), outline=7)


def you_marker(baked: bool) -> str:
    """Huge marker over the player's own horse (council 5)."""
    d = "M50 16 L206 16 Q240 16 240 50 L240 132 Q240 166 206 166 L162 166 L128 238 L94 166 L50 166 Q16 166 16 132 L16 50 Q16 16 50 16 Z"
    return solid(GOLD, f'<path d="{d}"/>', outline=16) + f'<rect x="44" y="28" width="168" height="16" rx="8" fill="{WHITE}" opacity="0.45"/>' + (text(128, 128, "YOU", 96) if baked else "")


def ribbon(pleat: str, inner: str, place: int) -> str:
    tails = solid(pleat, '<path d="M54 84 L36 150 L50 140 L60 154 L68 88 Z"/>', '<path d="M74 84 L92 150 L78 140 L68 154 L60 88 Z"/>')
    extra = solid(inner, f'<polygon points="{star_points(64, 62, 60, 50, 22)}"/>') if place == 1 else ""
    return (
        tails
        + extra
        + solid(pleat, f'<polygon points="{star_points(64, 62, 50, 40, 18)}"/>')
        + solid(inner, '<circle cx="64" cy="62" r="32"/>', outline=8)
        + solid(PAPER, '<circle cx="64" cy="62" r="22"/>', outline=6)
        + text(64, 73, str(place), 30)
    )


def chance_arrow(up: bool) -> str:
    d = "M64 14 L110 62 L82 62 L82 112 L46 112 L46 62 L18 62 Z" if up else "M64 114 L110 66 L82 66 L82 16 L46 16 L46 66 L18 66 Z"
    return solid(TEAL if up else PLUM, f'<path d="{d}"/>')


def finish_checker() -> str:
    return "".join(f'<rect x="{i * 32}" y="{j * 32}" width="32" height="32" fill="{INK if (i + j) % 2 == 0 else WHITE}"/>' for i in range(4) for j in range(4))


def assets() -> dict[str, tuple[int, int, str]]:
    a: dict[str, tuple[int, int, str]] = {
        "hoof": (128, 128, hoof_glyph()),
        "hoof_ring": (256, 256, ring_circle(128, 128, 118, w=10)),
        "giddyup_pad": (512, 176, giddyup_pad("idle")),
        "giddyup_pad_pressed": (512, 176, giddyup_pad("pressed")),
        "giddyup_pad_blank": (512, 176, giddyup_pad("blank")),
        "burst_bar": (1024, 128, burst_bar()),
        "burst_glow": (256, 128, burst_glow("burst_glow")),
        "burst_marker": (64, 160, burst_marker()),
        "burst_rays": (256, 256, burst_rays("burst_rays")),
        "chance_up": (128, 128, chance_arrow(True)),
        "chance_down": (128, 128, chance_arrow(False)),
        "finish_checker": (128, 128, finish_checker()),
        "you_marker": (256, 256, you_marker(True)),
        "you_marker_blank": (256, 256, you_marker(False)),
        "lane_sparkle": (128, 128, lane_sparkle()),
        "fx_dust_puff": (128, 128, fx_dust_puff("fx_dust_puff")),
        "fx_mane_flick": (128, 128, fx_mane_flick()),
    }
    for name in FEEDBACK:
        a[f"label_{name}"] = (128, 128, feedback(name))
    for n in range(1, 9):
        a[f"lane_{n}"] = (128, 128, lane_chip(n, f"lane_{n}"))
        a[f"lane_{n}_blank"] = (128, 128, lane_chip(n, f"lane_{n}_blank", number=False))
        a[f"lane_{n}_sparkle"] = (128, 128, lane_chip(n, f"lane_{n}_sparkle") + lane_sparkle())
    for name, pleat, inner, place in RIBBONS:
        a[f"ribbon_{name}"] = (128, 160, ribbon(pleat, inner, place))
    return a


def svg(w: int, h: int, body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'


def nested(x: float, y: float, w: float, h: float, vw: int, vh: int, body: str) -> str:
    return f'<svg x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" viewBox="0 0 {vw} {vh}">{body}</svg>'


def caption(x: float, y: float, s: str, size: int = 13, bold: bool = False, anchor: str = "middle") -> str:
    fw = ' font-weight="bold"' if bold else ""
    return f'<text x="{x:.1f}" y="{y:.1f}" font-family="Arial, sans-serif" font-size="{size}"{fw} fill="{INK}" text-anchor="{anchor}">{s}</text>'


def ring_panel(x: float, y: float, w: float, h: float, beats_per_s: float, title: str, contact: bool = False) -> str:
    """Several rings at once: each closes in RING_CLOSE_S, so faster tempo = tighter spacing."""
    cx, cy, hoof_px = x + w / 2, y + h / 2 + 4, 48
    rc = hoof_px * 0.47  # ring radius at contact (sits on the hoof rim)
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" fill="{DIRT}"/>', nested(cx - hoof_px / 2, cy - hoof_px / 2, hoof_px, hoof_px, 128, 128, hoof_glyph())]
    gap = 1 / beats_per_s
    first = 0.0 if contact else 0.12
    rings = [first + k * gap for k in range(6) if first + k * gap < RING_CLOSE_S]
    for k, t in reversed(list(enumerate(rings))):
        r = rc * (1 + (RING_SPAWN - 1) * t / RING_CLOSE_S)
        colour = GOLD if contact and k == 0 else WHITE
        out.append(ring_circle(cx, cy, r, 6, colour, RING_ALPHA[min(k, len(RING_ALPHA) - 1)]))
    if contact:
        out.append(nested(cx + 26, y + 8, 42, 42, 128, 128, feedback("perfect")))
    out.append(caption(cx, y + h + 18, title))
    return "".join(out)


def sheet(a: dict[str, tuple[int, int, str]]) -> str:
    width, pad, row_h = 1240, 24, 128
    out = [caption(width / 2, 44, "Giddy-Up race UI (council-reviewed set)", 26, True)]
    y = 70.0

    def section(title: str) -> None:
        nonlocal y
        out.append(caption(pad, y + 6, title, 15, True, "start"))
        y += 18

    def flow(names: list[str], max_h: float = row_h) -> None:
        nonlocal y
        x = float(pad)
        for name in names:
            w, h, body = a[name]
            s = min(max_h / h, (row_h * 3) / w, 1.0 if w > 256 else max_h / h)
            dw, dh = w * s, h * s
            cell = max(dw, 110)
            if x + cell > width - pad:
                x, y = float(pad), y + max_h + 34
            out.append(nested(x + (cell - dw) / 2, y + (max_h - dh) / 2, dw, dh, w, h, body))
            out.append(caption(x + cell / 2, y + max_h + 16, name, 12))
            x += cell + 18
        y += max_h + 40

    section("Giddy-up stride: tap anywhere; the ring is the target, the pad is only the affordance")
    flow(["hoof", "hoof_ring", "giddyup_pad", "giddyup_pad_pressed"])
    flow([f"label_{n}" for n in FEEDBACK] + ["chance_up", "chance_down"], 100)
    section(f"Several rings at once (each closes in {RING_CLOSE_S:g} s from {RING_SPAWN:g}x; tempo shows as spacing; next ring opaque, later ones faded)")
    pw, ph = 270, 190
    panels = [(2.0, "2 beats/s (Rookie steady)", False), (2.6, "2.6 beats/s (faster: tighter)", False), (1.6, "1.6 beats/s (slower: wider)", False), (2.0, "contact + tap = Perfect", True)]
    for i, (bps, title, contact) in enumerate(panels):
        out.append(ring_panel(pad + i * (pw + 26), y, pw, ph, bps, title, contact))
    y += ph + 44
    section("Lanes: fixed colour + pattern + number; sparkle overlay = another rider's Perfect burst")
    flow([f"lane_{n}" for n in range(1, 9)], 100)
    flow([f"lane_{n}_sparkle" for n in range(1, 9)], 100)
    section("Race and results")
    flow(["you_marker"] + [f"ribbon_{r[0]}" for r in RIBBONS] + ["finish_checker"], 150)
    section("Beat effects (particle textures, white so the emitter tints them; shown on dirt)")
    x0 = pad
    for name, tint in (("fx_dust_puff", "#E3B985"), ("fx_mane_flick", "#1D2433")):
        out.append(f'<rect x="{x0}" y="{y}" width="128" height="128" rx="14" fill="{DIRT}"/>')
        body = a[name][2].replace(f'stop-color="{WHITE}"', f'stop-color="{tint}"').replace(f'stroke="{WHITE}"', f'stroke="{tint}"')
        out.append(nested(x0, y, 128, 128, 128, 128, body))
        out.append(caption(x0 + 64, y + 146, f"{name} (tinted {tint})", 12))
        x0 += 200
    y += 172
    section("Final Burst (bar, glow and marker composed; rays play after scoring, own screen only)")
    bw = width - 2 * pad - 200
    bh = bw * 160 / 1024
    sx = 160 / 144
    composed = (
        burst_bar()
        + f'<g transform="translate({632 - 128 * sx:.1f},0) scale({sx:.3f},1)">{burst_glow("sheet_glow")}</g>'
        + f'<g transform="translate({340 - 32 * 0.9:.1f},-12) scale(0.9)">{burst_marker()}</g>'
    )
    out.append(nested(pad, y, bw, bh, 1024, 160, f'<g transform="translate(0,16)">{composed}</g>'))
    out.append(f'<rect x="{pad + bw + 30}" y="{y - 10}" width="170" height="170" rx="16" fill="#8ED6FF"/>')
    out.append(nested(pad + bw + 35, y - 5, 160, 160, 256, 256, burst_rays("sheet_rays")))
    out.append(caption(pad + bw + 115, y + 178, "burst_rays", 12))
    y += max(bh, 170) + 40
    body = f'<rect width="100%" height="100%" fill="#F4EBD9"/>' + "".join(out)
    return svg(width, int(y), body)


def export_pngs(names: list[str]) -> str:
    try:
        import resvg_py
    except ImportError:
        return "PNG export skipped: pip install resvg-py, then rerun"
    PNG_OUT.mkdir(parents=True, exist_ok=True)
    for name in names:
        data = resvg_py.svg_to_bytes(svg_path=str(OUT / f"{name}.svg"), zoom=PNG_ZOOM)
        (PNG_OUT / f"{name}.png").write_bytes(bytes(data))
    return f"wrote {len(names)} PNGs at {PNG_ZOOM}x to {PNG_OUT}"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--no-png", action="store_true")
    args = ap.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    a = assets()
    for stale in OUT.glob("*.svg"):
        if stale.stem not in a and stale.name != "_sheet.svg":
            stale.unlink()
    for name, (w, h, body) in a.items():
        (OUT / f"{name}.svg").write_text(svg(w, h, body), encoding="utf-8", newline="\n")
    (OUT / "_sheet.svg").write_text(sheet(a), encoding="utf-8", newline="\n")
    print(f"make_ui_svgs: wrote {len(a)} SVGs + _sheet.svg to {OUT}")
    if not args.no_png:
        if PNG_OUT.is_dir():
            for stale in PNG_OUT.glob("*.png"):
                if stale.stem not in a:
                    stale.unlink()
        print(export_pngs(sorted(a)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
