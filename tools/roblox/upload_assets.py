#!/usr/bin/env python3
"""Upload playtest models, UI sheets and sounds to Roblox through the Open Cloud Assets API.

Adapted from haunt-nyc (Ghost Hunters/tools/roblox/upload_assets.py).

  python tools/ui/build_atlas.py                    # UI sheets first
  python tools/roblox/upload_assets.py --dry-run    # list what would upload
  python tools/roblox/upload_assets.py              # upload new or changed files
  python tools/roblox/upload_assets.py --kind Audio # only the sounds (assets/audio, tools/audio)
  python tools/roblox/upload_assets.py --moderation # refresh each asset's moderation state

Models (GLB) become Model assets; UI sheets become Decals; sounds (assets/audio/*.mp3 or .ogg)
become Audio. Results go to tools/roblox/uploaded.json (the record) and three generated
modules the game reads: game/src/shared/MeshAssets.luau (slot -> Model id),
game/src/shared/UiImages.luau (sheet -> Decal id) and game/src/shared/SoundAssets.luau
(sound -> Audio id). New assets pass Roblox moderation first (minutes to hours); until then
the game keeps its placeholder shapes and plays no sound. Audio can't be updated in place:
a changed file uploads as a new asset. Roblox caps audio uploads per 30 days (100 for
ID-verified accounts, 10 otherwise), so --force re-uploads sounds only with --kind Audio,
and an upload request is never resent when it may already have gone through. Sounds that
moderation Rejected stay in the record but are left out of SoundAssets.luau.

Key: ROBLOX_API_KEY env var only (Open Cloud key, Assets API read + write); it is never
printed or written. Creator: the group in ROBLOX_CREATOR_GROUP_ID (LlamaWorks, like
haunt-nyc), or --user-id to upload as a user. Places can only load assets owned by their
own creator, so the playtest place must belong to the same group.
"""

from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
STATE = REPO / "tools" / "roblox" / "uploaded.json"
MESH_ASSETS = REPO / "game" / "src" / "shared" / "MeshAssets.luau"
UI_IMAGES = REPO / "game" / "src" / "shared" / "UiImages.luau"
SOUND_ASSETS = REPO / "game" / "src" / "shared" / "SoundAssets.luau"
AUDIO = REPO / "assets" / "audio"
GENERATED = REPO / "Models" / "generated"
ATLAS = REPO / "assets" / "ui" / "atlas"

API = "https://apis.roblox.com/assets/v1"
CONTENT_TYPES = {".glb": "model/gltf-binary", ".fbx": "model/fbx", ".png": "image/png", ".mp3": "audio/mpeg",
                 ".ogg": "audio/ogg"}
KIND_WORD = {"Model": "model", "Decal": "UI sheet", "Audio": "sound"}
MAX_BYTES = 20 * 1024 * 1024
POLL_START_S, POLL_MAX_S, OP_TIMEOUT_S = 2.0, 15.0, 10 * 60
HTTP_RETRIES = 6

# slot -> file under Models/generated (see docs/art/IMPORT.md for which files to use). Only slots that passed
# review (docs/art/ART_REVIEW.md) are listed. Horses and foals use the *_hoofed.glb from darken_hooves.py.
STAND_COATS = ("bay", "chestnut", "grey", "black", "palomino", "pinto", "appaloosa", "buckskin", "dun", "roan", "white",
               "chestnut_blaze")
NEW_GALLOP_COATS = ("pinto", "appaloosa", "buckskin", "dun", "roan", "white", "chestnut_blaze")
FOAL_COATS = ("bay", "chestnut", "grey")
# Napping horses (D-058): the starter coats lying in the straw. Raw Meshy files: darken_hooves.py finds the
# legs of a standing horse, not folded ones (its hooves are already dark). Other coats sink a standing horse.
LIE_COATS = ("bay", "palomino", "grey")
PROPS = (
    "stable_barn", "hay_bale", "water_trough", "feed_bucket", "grooming_brush", "wheelbarrow", "pitchfork", "noticeboard",
    "post_box", "saddle_rack", "carrot_crop", "apple_tree_small", "oat_crop", "garden_bed",
    "feed_store", "vet_clinic", "market_corral_booth", "training_shed", "race_board_frame", "trail_gate_arch",
    "lantern_post", "bench", "picnic_table", "trophy_cup", "rosette_ribbon", "horseshoe_decor", "log_jump",
    "wooden_bridge", "hay_cart", "post_box_carrots", "visitor_bell", "rosette_wall",
    "spa_wash_stall", "towel_rack", "welcome_hay_bale", "photo_frame_stand",
    "legend_paddock_arch", "legend_plaque_post", "riding_school_sign",
)
MODELS = {
    # The playtest gallop coats keep their original slot names (horse_<coat>); the race code uses them.
    **{f"horse_{c}": f"horse_gallop_{c}/horse_gallop_{c}_hoofed.glb" for c in ("bay", "chestnut", "grey", "black", "palomino")},
    **{f"horse_gallop_{c}": f"horse_gallop_{c}/horse_gallop_{c}_hoofed.glb" for c in NEW_GALLOP_COATS},
    **{f"horse_stand_{c}": f"horse_stand_{c}/horse_stand_{c}_hoofed.glb" for c in STAND_COATS},
    **{f"foal_stand_{c}": f"foal_stand_{c}/foal_stand_{c}_hoofed.glb" for c in FOAL_COATS},
    **{f"horse_lie_{c}": f"horse_lie_{c}/horse_lie_{c}.glb" for c in LIE_COATS},
    # Standing horses cut into Body + four legs by tools/meshy/split_legs.py, for animated legs.
    **{f"horse_anim_{c}": f"horse_anim_{c}/horse_anim_{c}.glb" for c in STAND_COATS},
    "finish_post": "finish_post/finish_post.glb",
    "gate_stall": "gate_stall/gate_stall.glb",
    **{slot: f"{slot}/{slot}.glb" for slot in PROPS},
    # Local fixes (docs/art/ART_REVIEW.md): roan coats and the apple canopy recoloured by recolor.py, the race board's
    # ground plate removed by trim_base.py.
    "horse_stand_roan": "horse_stand_roan/horse_stand_roan_recolored.glb",
    "horse_gallop_roan": "horse_gallop_roan/horse_gallop_roan_recolored.glb",
    "apple_tree_small": "apple_tree_small/apple_tree_small_recolored.glb",
    "race_board_frame": "race_board_frame/race_board_frame_trimmed.glb",
}


class UploadError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_state() -> dict[str, Any]:
    return json.loads(STATE.read_text()) if STATE.exists() else {}


def save_state(state: dict[str, Any]) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=1, sort_keys=True) + "\n")


def write_luau(path: Path, head: str, ids: dict[str, int]) -> None:
    lines = ["--!strict", *[f"-- {line}" for line in head.splitlines()], "local ids: { [string]: number } = {"]
    lines += [f"\t{k} = {v}," for k, v in sorted(ids.items())]
    lines += ["}", "", "return ids", ""]
    path.write_text("\n".join(lines))


def write_modules(state: dict[str, Any]) -> None:
    models = {k: v["assetId"] for k, v in state.items() if v.get("kind") == "Model"}
    decals = {k: v["assetId"] for k, v in state.items() if v.get("kind") == "Decal"}
    sounds = {k: v["assetId"] for k, v in state.items() if v.get("kind") == "Audio" and v.get("moderation") != "Rejected"}
    write_luau(MESH_ASSETS, "GENERATED by tools/roblox/upload_assets.py: slot -> Model asset id. Do not edit by hand.\n"
               "AssetService loads these into ReplicatedStorage.RaceModels at server start.", models)
    write_luau(UI_IMAGES, "GENERATED by tools/roblox/upload_assets.py: UI sheet -> Decal asset id. Do not edit by hand.\n"
               "AssetService resolves each to its image id as ReplicatedStorage attribute UiSheet_<sheet>.", decals)
    write_luau(SOUND_ASSETS, "GENERATED by tools/roblox/upload_assets.py: sound -> Audio asset id. Do not edit by hand.\n"
               "The client Sound module plays these; a missing name plays nothing.", sounds)


def request(method: str, url: str, key: str, body: bytes | None = None, ctype: str | None = None,
            idempotent: bool = True) -> dict[str, Any]:
    """idempotent=False (the upload POST): retry only a 429, never a 5xx or a network error, since
    the asset may already exist and a second upload would spend another one."""
    headers = {"x-api-key": key}
    if ctype:
        headers["Content-Type"] = ctype
    delay = 2.0
    unsure = "it may have uploaded anyway: check Creator Hub before re-running"
    for attempt in range(HTTP_RETRIES):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            try:
                detail = e.read().decode("utf-8", "replace")[:400]
            except (OSError, http.client.HTTPException):
                detail = ""
            retry = e.code == 429 or (idempotent and e.code in (500, 502, 503, 504))
            if retry and attempt < HTTP_RETRIES - 1:
                time.sleep(float(e.headers.get("Retry-After") or delay))
                delay = min(delay * 2, 60)
                continue
            if e.code in (401, 403):
                raise UploadError(f"HTTP {e.code}: check the key has Assets API read+write for this creator. {detail}")
            if not idempotent and e.code >= 500:
                raise UploadError(f"HTTP {e.code}; {unsure}. {detail}")
            raise UploadError(f"HTTP {e.code}: {detail}")
        except (urllib.error.URLError, OSError, http.client.HTTPException) as e:  # includes timeouts
            reason = getattr(e, "reason", None) or e
            if idempotent and attempt < HTTP_RETRIES - 1:
                time.sleep(delay)
                delay = min(delay * 2, 60)
                continue
            raise UploadError(f"network error ({type(e).__name__}: {reason})" + ("" if idempotent else f"; {unsure}"))
        except ValueError as e:
            raise UploadError(f"unreadable response: {e}")
    raise UploadError("retries exhausted")


def multipart(fields: dict[str, str], path: Path, ctype: str) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    parts = [f'--{boundary}\r\nContent-Disposition: form-data; name="{n}"\r\n\r\n{v}\r\n'.encode() for n, v in fields.items()]
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
                 f"Content-Type: {ctype}\r\n\r\n".encode())
    parts += [path.read_bytes(), f"\r\n--{boundary}--\r\n".encode()]
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def upload(path: Path, name: str, kind: str, creator: dict[str, str], key: str) -> int:
    meta = {"assetType": kind, "displayName": f"GiddyUp_{name}",
            "description": f"Giddy-Up playtest {KIND_WORD[kind]} {name}",
            "creationContext": {"creator": creator}}
    body, ctype = multipart({"request": json.dumps(meta)}, path, CONTENT_TYPES[path.suffix.lower()])
    op = request("POST", f"{API}/assets", key, body, ctype, idempotent=False)
    op_id = op.get("operationId") or str(op.get("path", "")).rsplit("/", 1)[-1]
    if not op_id:
        raise UploadError(f"no operation id in {op}")
    wait, t0 = POLL_START_S, time.time()
    while not op.get("done"):
        if time.time() - t0 > OP_TIMEOUT_S:
            raise UploadError(f"operation {op_id} still running after {OP_TIMEOUT_S}s; re-run later")
        time.sleep(wait)
        wait = min(wait * 1.5, POLL_MAX_S)
        op = request("GET", f"{API}/operations/{op_id}", key)
    if op.get("error"):
        raise UploadError(f"operation {op_id} failed: {op['error']}")
    asset_id = (op.get("response") or {}).get("assetId")
    if not asset_id:
        raise UploadError(f"operation {op_id} done without an assetId: {op}")
    return int(asset_id)


def candidates() -> list[tuple[str, Path, str]]:
    out = [(slot, GENERATED / rel, "Model") for slot, rel in MODELS.items()]
    out += [(p.stem, p, "Decal") for p in sorted(ATLAS.glob("ui_atlas_*.png"))]
    out += [(p.stem, p, "Audio") for p in sorted([*AUDIO.glob("*.mp3"), *AUDIO.glob("*.ogg")])]
    return out


def refresh_moderation(state: dict[str, Any], key: str, kinds: list[str] | None) -> int:
    """GET each asset's moderation result into the record; returns how many aren't approved yet."""
    waiting = 0
    for name, rec in sorted(state.items()):
        if kinds and rec.get("kind") not in kinds:
            continue
        try:
            info = request("GET", f"{API}/assets/{rec['assetId']}?readMask=moderationResult", key)
        except UploadError as e:
            print(f"  FAIL {name}: {e}", file=sys.stderr)
            waiting += 1
            continue
        mod = (info.get("moderationResult") or {}).get("moderationState", "Unknown")
        rec["moderation"] = mod
        if mod != "Approved":
            waiting += 1
        print(f"  {mod:<9} {name:<16} asset {rec['assetId']}")
    save_state(state)
    return waiting


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true", help="re-upload unchanged files (sounds only with --kind Audio)")
    ap.add_argument("--only", nargs="*", help="limit to these slot/sheet names")
    ap.add_argument("--user-id", help="upload as this user instead of the group")
    ap.add_argument("--group-id", default=os.environ.get("ROBLOX_CREATOR_GROUP_ID"))
    ap.add_argument("--kind", nargs="*", choices=("Model", "Decal", "Audio"), help="limit to these asset kinds")
    ap.add_argument("--moderation", action="store_true", help="refresh moderation states and exit")
    args = ap.parse_args(argv)

    state = load_state()
    if args.moderation:
        key = os.environ.get("ROBLOX_API_KEY", "")
        if not key:
            print("upload_assets: set the ROBLOX_API_KEY user environment variable", file=sys.stderr)
            return 2
        waiting = refresh_moderation(state, key, args.kind)
        write_modules(state)  # a Rejected sound drops out of SoundAssets
        print(f"{waiting} not approved yet" if waiting else "all approved")
        return 0
    todo = []
    for name, path, kind in candidates():
        if args.only and name not in args.only:
            continue
        if args.kind and kind not in args.kind:
            continue
        if not path.exists():
            print(f"  skip {name:<14} missing {path.relative_to(REPO)}")
            continue
        if path.stat().st_size > MAX_BYTES:
            print(f"  skip {name:<14} {path.stat().st_size // 1024} KB is over the 20 MB limit")
            continue
        digest = sha256(path)
        # Audio uploads are capped per 30 days: --force re-uploads sounds only when --kind Audio asks.
        force = args.force and (kind != "Audio" or "Audio" in (args.kind or []))
        if not force and state.get(name, {}).get("sha256") == digest:
            print(f"  same {name:<14} asset {state[name]['assetId']}")
            continue
        todo.append((name, path, kind, digest))
        print(f"  ->   {name:<14} {path.relative_to(REPO)} ({path.stat().st_size // 1024} KB, {kind})")

    if args.dry_run or not todo:
        print("dry run: nothing uploaded" if args.dry_run else "nothing to upload")
        return 0
    key = os.environ.get("ROBLOX_API_KEY", "")
    if not key:
        print("upload_assets: set the ROBLOX_API_KEY user environment variable", file=sys.stderr)
        return 2
    if args.user_id:
        creator = {"userId": str(args.user_id)}
    elif args.group_id:
        creator = {"groupId": str(args.group_id)}
    else:
        print("upload_assets: set ROBLOX_CREATOR_GROUP_ID or pass --user-id", file=sys.stderr)
        return 2

    failures = 0
    for name, path, kind, digest in todo:
        try:
            asset_id = upload(path, name, kind, creator, key)
        except UploadError as e:
            failures += 1
            print(f"  FAIL {name}: {e}", file=sys.stderr)
            continue
        state[name] = {"assetId": asset_id, "kind": kind, "sha256": digest, "file": str(path.relative_to(REPO)).replace("\\", "/"),
                       "uploadedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
        save_state(state)
        print(f"  ok   {name:<14} asset {asset_id}")
    write_modules(state)
    print(f"wrote {MESH_ASSETS.relative_to(REPO)}, {UI_IMAGES.relative_to(REPO)} and {SOUND_ASSETS.relative_to(REPO)}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
