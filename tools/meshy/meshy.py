# Meshy AI asset generator (copied from the owner's haunt-nyc repo, paths unchanged: queue next to this file, outputs in Models/generated/). Notes: docs/art/ASSET_PLAN.md. Key: MESHY_API_KEY env var only.
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

API = "https://api.meshy.ai/openapi"
TEXT_EP = f"{API}/v2/text-to-3d"
IMAGE_EP = f"{API}/v1/image-to-3d"
RIG_EP = f"{API}/v1/rigging"
ANIM_EP = f"{API}/v1/animations"
RETEX_EP = f"{API}/v1/retexture"

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
QUEUE = HERE / "queue.json"
OUT_ROOT = REPO / "Models" / "generated"

PROMPT_MAX = 800
POLL_START_S = 5.0
POLL_MAX_S = 30.0
TASK_TIMEOUT_S = 30 * 60
HTTP_RETRIES = 6

# Credit prices from https://docs.meshy.ai/en/api/pricing (standard geometry_resolution, 2k textures)
COST = {"preview": 20, "refine": 10, "image_textured": 30, "rig": 5, "animation": 3, "retexture": 10}


class MeshyError(RuntimeError):
    pass


def set_models_root(root: Path) -> None:
    """--models-root: write outputs to <root>/generated (e.g. the main checkout's Models/ from a worktree)."""
    global OUT_ROOT
    OUT_ROOT = root.expanduser().resolve() / "generated"


def rel(p: Path) -> str:
    for base in (REPO, OUT_ROOT.parent.parent):
        try:
            return p.relative_to(base).as_posix()
        except ValueError:
            continue
    return str(p)


def load_queue() -> dict[str, Any]:
    with QUEUE.open(encoding="utf-8") as f:
        return json.load(f)


def get_slot(queue: dict[str, Any], slot_id: str) -> dict[str, Any]:
    for s in queue["slots"]:
        if s["slot_id"] == slot_id:
            merged = {k: v for k, v in queue.get("defaults", {}).items()}
            merged.update(s)
            return merged
    ids = ", ".join(s["slot_id"] for s in queue["slots"])
    raise SystemExit(f"error: slot '{slot_id}' not in {QUEUE}. Known slots: {ids}")


def api_key() -> str:
    key = os.environ.get("MESHY_API_KEY", "").strip()
    if not key:
        raise SystemExit(
            "error: MESHY_API_KEY is not set.\n"
            "  Windows: run  setx MESHY_API_KEY \"msy_...\"  in your own terminal, then open a NEW terminal.\n"
            "  Or use --dry-run to print request bodies without calling the API."
        )
    return key


def full_prompt(slot: dict[str, Any]) -> str:
    prompt = slot["prompt"]
    suffix = slot.get("style_suffix")
    if suffix:
        prompt = f"{prompt}, {suffix}"
    if len(prompt) > PROMPT_MAX:
        raise SystemExit(f"error: prompt for {slot['slot_id']} is {len(prompt)} chars (max {PROMPT_MAX})")
    return prompt


def texture_prompt(slot: dict[str, Any]) -> str | None:
    tp = slot.get("texture_prompt")
    if tp and len(tp) > PROMPT_MAX:
        raise SystemExit(f"error: texture_prompt for {slot['slot_id']} is {len(tp)} chars (max {PROMPT_MAX})")
    return tp


def preview_body(slot: dict[str, Any]) -> dict[str, Any]:
    body: dict[str, Any] = {
        "mode": "preview",
        "prompt": full_prompt(slot),
        "ai_model": slot["ai_model"],
        "topology": slot["topology"],
        "target_polycount": int(slot["target_polycount"]),
        "should_remesh": bool(slot["should_remesh"]),
        "target_formats": slot["target_formats"],
        "origin_at": slot["origin_at"],
    }
    if slot.get("pose_mode"):
        body["pose_mode"] = slot["pose_mode"]
    return body


def refine_body(slot: dict[str, Any], preview_id: str) -> dict[str, Any]:
    body: dict[str, Any] = {
        "mode": "refine",
        "preview_task_id": preview_id,
        "enable_pbr": bool(slot["enable_pbr"]),
        "texture_resolution": slot["texture_resolution"],
        "target_formats": slot["target_formats"],
        "origin_at": slot["origin_at"],
    }
    tp = texture_prompt(slot)
    if tp:
        body["texture_prompt"] = tp
    return body


def image_body(slot: dict[str, Any], data_uri: str) -> dict[str, Any]:
    body: dict[str, Any] = {
        "image_url": data_uri,
        "ai_model": slot["ai_model"],
        "topology": slot["topology"],
        "target_polycount": int(slot["target_polycount"]),
        "should_remesh": bool(slot["should_remesh"]),
        "should_texture": True,
        "enable_pbr": bool(slot["enable_pbr"]),
        "texture_resolution": slot["texture_resolution"],
        "target_formats": slot["target_formats"],
        "origin_at": slot["origin_at"],
    }
    if slot.get("pose_mode"):
        body["pose_mode"] = slot["pose_mode"]
    tp = texture_prompt(slot)
    if tp:
        body["texture_prompt"] = tp
    return body


def image_data_uri(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"error: image not found: {path}")
    mime = mimetypes.guess_type(path.name)[0]
    if mime not in ("image/png", "image/jpeg"):
        raise SystemExit(f"error: Meshy accepts .png/.jpg/.jpeg only, got {path.suffix}")
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def show_request(method: str, url: str, body: dict[str, Any] | None) -> None:
    print(f"[dry-run] {method} {url}")
    if body is not None:
        printable = dict(body)
        for k in ("image_url", "texture_image_url"):
            v = printable.get(k)
            if isinstance(v, str) and v.startswith("data:") and len(v) > 80:
                printable[k] = f"{v[:48]}...<{len(v)} chars>"
        print(json.dumps(printable, indent=2))


def http(method: str, url: str, key: str, body: dict[str, Any] | None = None) -> Any:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    delay = 2.0
    for attempt in range(1, HTTP_RETRIES + 1):
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {key}")
        req.add_header("Accept", "application/json")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")
            try:
                msg = json.loads(text).get("message", text)
            except (ValueError, AttributeError):
                msg = text
            if e.code == 429 or e.code >= 500:
                if attempt == HTTP_RETRIES:
                    raise MeshyError(f"{method} {url} -> {e.code} after {attempt} tries: {msg}")
                retry_after = e.headers.get("Retry-After")
                wait = float(retry_after) if retry_after and retry_after.isdigit() else delay
                kind = "rate limited" if e.code == 429 else "server error"
                print(f"  {kind} ({e.code}: {msg}); retrying in {wait:.0f}s")
                time.sleep(wait)
                delay = min(delay * 2, 60.0)
                continue
            hints = {
                401: "API key rejected - check MESHY_API_KEY",
                402: "insufficient credits on the Meshy account",
                400: "bad request - check the body printed by --dry-run",
                404: "task not found (tasks/files expire after 3 days on non-Enterprise plans)",
            }
            raise MeshyError(f"{method} {url} -> {e.code}: {msg} ({hints.get(e.code, 'see docs')})")
        except urllib.error.URLError as e:
            if attempt == HTTP_RETRIES:
                raise MeshyError(f"{method} {url} network error: {e.reason}")
            print(f"  network error ({e.reason}); retrying in {delay:.0f}s")
            time.sleep(delay)
            delay = min(delay * 2, 60.0)
    raise MeshyError("unreachable")


def create(url: str, key: str, body: dict[str, Any]) -> str:
    resp = http("POST", url, key, body)
    task_id = resp.get("result")
    if not task_id:
        raise MeshyError(f"POST {url}: no task id in response {resp}")
    return task_id


def poll(base: str, task_id: str, key: str, label: str) -> dict[str, Any]:
    start = time.monotonic()
    wait = POLL_START_S
    last = None
    while True:
        task = http("GET", f"{base}/{task_id}", key)
        status = task.get("status")
        progress = task.get("progress", 0)
        line = f"  {label} {task_id}: {status} {progress}%"
        if line != last:
            print(line)
            last = line
        if status == "SUCCEEDED":
            return task
        if status in ("FAILED", "CANCELED"):
            err = (task.get("task_error") or {}).get("message", "")
            raise MeshyError(f"{label} task {task_id} {status}: {err}")
        if time.monotonic() - start > TASK_TIMEOUT_S:
            raise MeshyError(f"{label} task {task_id} timed out after {TASK_TIMEOUT_S}s (still {status})")
        time.sleep(wait)
        wait = min(wait * 1.5, POLL_MAX_S)


def download(url: str, dest: Path) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "gavel-derby-meshy/1"})
    delay = 2.0
    for attempt in range(1, HTTP_RETRIES + 1):
        try:
            with urllib.request.urlopen(req, timeout=300) as resp, dest.open("wb") as f:
                while chunk := resp.read(1 << 16):
                    f.write(chunk)
            print(f"  saved {rel(dest)}")
            return dest
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt == HTTP_RETRIES:
                raise MeshyError(f"download failed {dest.name}: {e}")
            time.sleep(delay)
            delay = min(delay * 2, 60.0)
    return dest


def url_ext(url: str, fallback: str) -> str:
    suffix = Path(urllib.parse.urlparse(url).path).suffix
    return suffix or fallback


def save_model_outputs(task: dict[str, Any], out: Path, stem: str) -> list[str]:
    files: list[str] = []
    for fmt, url in (task.get("model_urls") or {}).items():
        if url and fmt in ("fbx", "glb", "obj", "mtl", "usdz"):
            files.append(download(url, out / f"{stem}.{fmt}").name)
    for i, tex in enumerate(task.get("texture_urls") or []):
        for channel, url in tex.items():
            if url:
                idx = "" if i == 0 else f"_{i}"
                files.append(download(url, out / f"{stem}_{channel}{idx}{url_ext(url, '.png')}").name)
    thumb = task.get("thumbnail_url")
    if thumb:
        files.append(download(thumb, out / f"{stem}_thumbnail{url_ext(thumb, '.png')}").name)
    return files


def out_dir(slot_id: str) -> Path:
    return OUT_ROOT / slot_id


def read_record(slot_id: str) -> dict[str, Any] | None:
    p = out_dir(slot_id) / "task.json"
    if not p.is_file():
        return None
    with p.open(encoding="utf-8") as f:
        return json.load(f)


def write_record(slot_id: str, record: dict[str, Any]) -> None:
    p = out_dir(slot_id) / "task.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    record["credits_used"] = sum(t.get("consumed_credits") or 0 for t in record.get("tasks", []))
    p.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"  wrote {rel(p)} (credits_used={record['credits_used']})")


def task_entry(stage: str, task: dict[str, Any]) -> dict[str, Any]:
    return {
        "stage": stage,
        "id": task.get("id"),
        "type": task.get("type"),
        "status": task.get("status"),
        "consumed_credits": task.get("consumed_credits"),
        "finished_at": task.get("finished_at"),
        "expires_at": task.get("expires_at"),
    }


def guard_existing(slot_id: str, force: bool) -> None:
    rec = read_record(slot_id)
    if rec and rec.get("status") == "done" and not force:
        raise SystemExit(f"error: {slot_id} already generated ({out_dir(slot_id) / 'task.json'}). Use --force to regenerate (costs credits).")


def cmd_text(args: argparse.Namespace) -> None:
    slot = get_slot(load_queue(), args.slot_id)
    pbody = preview_body(slot)
    est = COST["preview"] + COST["refine"]
    if args.dry_run:
        print(f"slot {slot['slot_id']} ({slot.get('kind')}) -> {rel(out_dir(slot['slot_id']))}  est. {est} credits")
        print("step 1/2 preview:")
        show_request("POST", TEXT_EP, pbody)
        print(f"step 1b: poll GET {TEXT_EP}/<preview_task_id> until SUCCEEDED")
        print("step 2/2 refine:")
        show_request("POST", TEXT_EP, refine_body(slot, "<preview_task_id>"))
        print(f"step 2b: poll GET {TEXT_EP}/<refine_task_id>, download model_urls.fbx/glb + texture_urls[] + thumbnail, write task.json")
        return
    guard_existing(slot["slot_id"], args.force)
    key = api_key()
    out = out_dir(slot["slot_id"])
    record: dict[str, Any] = {
        "slot_id": slot["slot_id"], "source": "text-to-3d", "status": "running",
        "prompt": pbody["prompt"], "texture_prompt": slot.get("texture_prompt"),
        "requests": {"preview": pbody}, "tasks": [], "files": [],
    }
    print(f"[{slot['slot_id']}] preview ...")
    pid = create(TEXT_EP, key, pbody)
    record["tasks"].append({"stage": "preview", "id": pid})
    write_record(slot["slot_id"], record)
    ptask = poll(TEXT_EP, pid, key, "preview")
    record["tasks"][-1] = task_entry("preview", ptask)
    rbody = refine_body(slot, pid)
    record["requests"]["refine"] = rbody
    print(f"[{slot['slot_id']}] refine ...")
    rid = create(TEXT_EP, key, rbody)
    record["tasks"].append({"stage": "refine", "id": rid})
    write_record(slot["slot_id"], record)
    rtask = poll(TEXT_EP, rid, key, "refine")
    record["tasks"][-1] = task_entry("refine", rtask)
    record["model_task_id"] = rid
    record["files"] = save_model_outputs(rtask, out, slot["slot_id"])
    record["status"] = "done"
    write_record(slot["slot_id"], record)


def cmd_image(args: argparse.Namespace) -> None:
    slot = get_slot(load_queue(), args.slot_id)
    img = Path(args.image_path).expanduser().resolve()
    uri = image_data_uri(img)
    body = image_body(slot, uri)
    if args.dry_run:
        print(f"slot {slot['slot_id']} from {img} -> {rel(out_dir(slot['slot_id']))}  est. {COST['image_textured']} credits")
        show_request("POST", IMAGE_EP, body)
        print(f"then: poll GET {IMAGE_EP}/<task_id>, download model_urls + texture_urls[], write task.json")
        return
    guard_existing(slot["slot_id"], args.force)
    key = api_key()
    record: dict[str, Any] = {
        "slot_id": slot["slot_id"], "source": "image-to-3d", "status": "running",
        "image_path": str(img), "texture_prompt": slot.get("texture_prompt"),
        "requests": {"image": {k: v for k, v in body.items() if k != "image_url"}}, "tasks": [], "files": [],
    }
    print(f"[{slot['slot_id']}] image-to-3d ...")
    tid = create(IMAGE_EP, key, body)
    record["tasks"].append({"stage": "image", "id": tid})
    write_record(slot["slot_id"], record)
    task = poll(IMAGE_EP, tid, key, "image")
    record["tasks"][-1] = task_entry("image", task)
    record["model_task_id"] = tid
    record["files"] = save_model_outputs(task, out_dir(slot["slot_id"]), slot["slot_id"])
    record["status"] = "done"
    write_record(slot["slot_id"], record)


def cmd_rig(args: argparse.Namespace) -> None:
    slot = get_slot(load_queue(), args.slot_id)
    sid = slot["slot_id"]
    if not slot.get("rig"):
        print(f"{sid} is not marked rig:true in queue.json. Meshy auto-rigging supports textured bipedal "
              f"humanoids only (face toward +Z, clear limbs); props, vehicles and blob creatures cannot be rigged via the API.")
        return
    anims: dict[str, int] = dict(slot.get("rig_animations") or {})
    rec = read_record(sid)
    model_task = (rec or {}).get("model_task_id")
    rig_body = {"input_task_id": model_task or "<model_task_id from task.json>", "height_meters": float(slot.get("height_meters", 1.7))}
    est = COST["rig"] + COST["animation"] * len(anims)
    if args.dry_run:
        print(f"slot {sid}: rig + animations  est. {est} credits (walk + run come free with the rig task)")
        show_request("POST", RIG_EP, rig_body)
        print(f"poll GET {RIG_EP}/<rig_task_id>; download result.rigged_character_fbx_url/glb and result.basic_animations walking_*/running_*")
        for name, action_id in anims.items():
            print(f"animation '{name}':")
            show_request("POST", ANIM_EP, {"rig_task_id": "<rig_task_id>", "action_id": action_id})
        if not model_task:
            print(f"note: {sid} has no task.json yet - run `text {sid}` (or `image`) first.")
        return
    if not model_task or (rec or {}).get("status") != "done":
        raise SystemExit(f"error: {sid} has no finished model. Run `python tools/meshy/meshy.py text {sid}` first.")
    if rec.get("rig", {}).get("status") == "done" and not args.force:
        raise SystemExit(f"error: {sid} already rigged. Use --force to redo (costs credits).")
    key = api_key()
    out = out_dir(sid) / "rig"
    rig_rec: dict[str, Any] = {"status": "running", "request": rig_body, "files": []}
    rec["rig"] = rig_rec
    print(f"[{sid}] rigging ...")
    rid = create(RIG_EP, key, rig_body)
    rec["tasks"].append({"stage": "rig", "id": rid})
    write_record(sid, rec)
    rtask = poll(RIG_EP, rid, key, "rig")
    rec["tasks"][-1] = task_entry("rig", rtask)
    result = rtask.get("result") or {}
    for field, fname in (("rigged_character_fbx_url", f"{sid}_rigged.fbx"), ("rigged_character_glb_url", f"{sid}_rigged.glb")):
        if result.get(field):
            rig_rec["files"].append(str(download(result[field], out / fname).relative_to(out_dir(sid))))
    for field, url in (result.get("basic_animations") or {}).items():
        if url and field.endswith("_url"):
            fname = f"{sid}_anim_{field.removesuffix('_url')}{url_ext(url, '')}"
            rig_rec["files"].append(str(download(url, out / fname).relative_to(out_dir(sid))))
    rig_rec["rig_task_id"] = rid
    write_record(sid, rec)
    for name, action_id in anims.items():
        body = {"rig_task_id": rid, "action_id": int(action_id)}
        print(f"[{sid}] animation {name} (action_id {action_id}) ...")
        aid = create(ANIM_EP, key, body)
        rec["tasks"].append({"stage": f"anim_{name}", "id": aid})
        write_record(sid, rec)
        atask = poll(ANIM_EP, aid, key, f"anim_{name}")
        rec["tasks"][-1] = task_entry(f"anim_{name}", atask)
        ares = atask.get("result") or {}
        for field, ext in (("animation_fbx_url", "fbx"), ("animation_glb_url", "glb")):
            if ares.get(field):
                rig_rec["files"].append(str(download(ares[field], out / f"{sid}_anim_{name}.{ext}").relative_to(out_dir(sid))))
        write_record(sid, rec)
    rig_rec["status"] = "done"
    write_record(sid, rec)


def retexture_body(slot: dict[str, Any], input_task_id: str) -> dict[str, Any]:
    style = slot.get("text_style_prompt")
    if not style:
        raise SystemExit(f"error: {slot['slot_id']} has no text_style_prompt in queue.json")
    if len(style) > PROMPT_MAX:
        raise SystemExit(f"error: text_style_prompt for {slot['slot_id']} is {len(style)} chars (max {PROMPT_MAX})")
    return {
        "input_task_id": input_task_id,
        "text_style_prompt": style,
        "ai_model": slot["ai_model"],
        "enable_original_uv": bool(slot.get("enable_original_uv", True)),
        "enable_pbr": bool(slot["enable_pbr"]),
        "texture_resolution": slot["texture_resolution"],
        "target_formats": slot["target_formats"],
    }


def cmd_retexture(args: argparse.Namespace) -> None:
    """Retexture a finished model (same mesh, new style) into its own slot. Source = queue `retexture_of`."""
    slot = get_slot(load_queue(), args.slot_id)
    sid = slot["slot_id"]
    source = args.source or slot.get("retexture_of")
    if not source:
        raise SystemExit(f"error: {sid} has no retexture_of in queue.json (or pass --source <slot>)")
    src_rec = read_record(source) or {}
    input_id = args.input_task_id or src_rec.get("model_task_id")
    body = retexture_body(slot, input_id or f"<model_task_id of {source}>")
    if args.dry_run:
        print(f"slot {sid}: retexture of {source} -> {rel(out_dir(sid))}  est. {COST['retexture']} credits")
        show_request("POST", RETEX_EP, body)
        print(f"then: poll GET {RETEX_EP}/<task_id>, download model_urls.glb/fbx + texture_urls[] + thumbnail, write task.json")
        if not input_id:
            print(f"note: {source} has no task.json with model_task_id under {rel(OUT_ROOT)}")
        return
    if not input_id:
        raise SystemExit(f"error: {source} has no finished model_task_id in {rel(out_dir(source))}/task.json")
    guard_existing(sid, args.force)
    key = api_key()
    record: dict[str, Any] = {
        "slot_id": sid, "source": f"retexture of {source}", "status": "running", "retexture_of": source,
        "input_task_id": input_id, "text_style_prompt": body["text_style_prompt"],
        "requests": {"retexture": body}, "tasks": [], "files": [],
    }
    print(f"[{sid}] retexture of {source} ...")
    tid = create(RETEX_EP, key, body)
    record["tasks"].append({"stage": "retexture", "id": tid})
    write_record(sid, record)
    task = poll(RETEX_EP, tid, key, "retexture")
    record["tasks"][-1] = task_entry("retexture", task)
    record["model_task_id"] = tid
    record["files"] = save_model_outputs(task, out_dir(sid), sid)
    record["status"] = "done"
    write_record(sid, record)


def slot_estimate(slot: dict[str, Any]) -> int:
    if slot.get("retexture_of"):
        return COST["retexture"]
    est = COST["preview"] + COST["refine"]
    if slot.get("rig"):
        est += COST["rig"] + COST["animation"] * len(slot.get("rig_animations") or {})
    return est


def cmd_status(args: argparse.Namespace) -> None:
    queue = load_queue()
    total = 0
    spent = 0
    print(f"{'slot_id':<30}{'kind':<11}{'tris':>6}  {'rig':<4}{'model':<9}{'rigged':<8}{'est':>4}  {'spent':>5}")
    for raw in queue["slots"]:
        slot = get_slot(queue, raw["slot_id"])
        rec = read_record(slot["slot_id"]) or {}
        d = out_dir(slot["slot_id"])
        has_fbx = any(d.glob("*.fbx")) if d.is_dir() else False
        model = "done" if rec.get("status") == "done" and has_fbx else (rec.get("status") or "-")
        rigged = "-" if not slot.get("rig") else ((rec.get("rig") or {}).get("status") or "todo")
        est = slot_estimate(slot)
        total += est
        spent += rec.get("credits_used") or 0
        print(f"{slot['slot_id']:<30}{slot.get('kind', ''):<11}{slot['target_polycount']:>6}  "
              f"{'yes' if slot.get('rig') else 'no':<4}{model:<9}{rigged:<8}{est:>4}  {rec.get('credits_used') or 0:>5}")
    print(f"\n{len(queue['slots'])} slots, estimated {total} credits for the full queue (one attempt each), {spent} spent so far.")
    print(f"outputs: {rel(OUT_ROOT)}/<slot_id>/")
    if args.dry_run:
        print("[dry-run] status never calls the network.")


TASK_BASES = {
    "text": f"{API}/v2/text-to-3d",
    "image": f"{API}/v1/image-to-3d",
}


def cmd_fetch(args: argparse.Namespace) -> None:
    """Download an already-finished Meshy task into a slot folder (no credits spent)."""
    base = TASK_BASES[args.kind]
    out = OUT_ROOT / args.slot_id
    if args.dry_run:
        show_request("GET", f"{base}/{args.task_id}", None)
        return
    key = api_key()
    task = poll(base, args.task_id, key, "fetch")
    files = save_model_outputs(task, out, args.slot_id)
    write_record(
        args.slot_id,
        {
            "slot_id": args.slot_id,
            "source": f"existing {args.kind} task (fetched, no new credits)",
            "status": "done",
            "prompt": task.get("prompt") or task.get("texture_prompt") or task.get("name"),
            "tasks": [task_entry("fetched", {**task, "consumed_credits": 0})],
            "files": files,
        },
    )


def cmd_list(args: argparse.Namespace) -> None:
    """List tasks already in the Meshy account (name/prompt, status, id)."""
    key = api_key()
    for kind, base in TASK_BASES.items():
        page = 1
        while True:
            batch = http("GET", f"{base}?page_num={page}&page_size=50&sort_by=-created_at", key)
            if not batch:
                break
            for t in batch:
                name = (t.get("name") or t.get("prompt") or t.get("texture_prompt") or "")[:60]
                print(f"{kind:5} {t.get('id')} {t.get('status', ''):10} {name}")
            page += 1


def main(argv: list[str] | None = None) -> int:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--dry-run", action="store_true", help="print request bodies, no network, no key needed")
    common.add_argument("--force", action="store_true", help="regenerate even if outputs exist (spends credits)")
    common.add_argument("--models-root", type=Path, default=None,
                        help="Models folder to read/write (outputs in <root>/generated); default: this repo's Models/")
    ap = argparse.ArgumentParser(prog="meshy.py", description="Meshy AI asset generation for Gavel Derby")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("text", parents=[common], help="text-to-3D preview + refine for a queue slot")
    p.add_argument("slot_id")
    p.set_defaults(fn=cmd_text)
    p = sub.add_parser("image", parents=[common], help="image-to-3D for a queue slot")
    p.add_argument("slot_id")
    p.add_argument("image_path")
    p.set_defaults(fn=cmd_image)
    p = sub.add_parser("rig", parents=[common], help="auto-rig + walk/run (+ jump via animation API)")
    p.add_argument("slot_id")
    p.set_defaults(fn=cmd_rig)
    p = sub.add_parser("retexture", parents=[common], help="retexture a finished model into a slot (10 cr)")
    p.add_argument("slot_id")
    p.add_argument("--source", default=None, help="slot whose model_task_id is retextured (default: queue retexture_of)")
    p.add_argument("--input-task-id", default=None, help="explicit Meshy task id to retexture")
    p.set_defaults(fn=cmd_retexture)
    p = sub.add_parser("fetch", parents=[common], help="download an existing finished task into a slot (no credits)")
    p.add_argument("slot_id")
    p.add_argument("task_id")
    p.add_argument("--kind", choices=["text", "image"], default="text")
    p.set_defaults(fn=cmd_fetch)
    p = sub.add_parser("list", parents=[common], help="list tasks already in the Meshy account")
    p.set_defaults(fn=cmd_list)
    p = sub.add_parser("status", parents=[common], help="list queue slots and outputs")
    p.set_defaults(fn=cmd_status)
    args = ap.parse_args(argv)
    if getattr(args, "models_root", None):
        set_models_root(args.models_root)
    try:
        args.fn(args)
    except MeshyError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\ninterrupted - task ids so far are in task.json; Meshy tasks keep running server-side", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
