#!/usr/bin/env python3
"""Make Giddy-Up's sound effects and announcer lines with ElevenLabs (tools/audio/sounds.json).

  python tools/audio/generate_audio.py --plan                 # list and estimated credits; sends nothing
  python tools/audio/generate_audio.py --priority P0          # generate missing P0 sounds
  python tools/audio/generate_audio.py --reroll coin          # second take (at most one re-roll per sound)

Writes assets/audio/<name>.mp3 (a re-roll keeps the first take in assets/audio/takes/, gitignored) and logs
every paid call to tools/audio/ledger.json. Then upload with tools/roblox/upload_assets.py --kind Audio.

Budget: --budget (default 2000 credits, David's approval of 2026-10-05). Before each call the script adds a
conservative estimate of that call to the spend so far and stops if the total could pass the budget. The
spend so far is the larger of the summed estimates and the measured usage (GET /v1/usage/character-stats,
cumulative since the first run; the key has no user_read permission, so /v1/user/subscription is not
available). Estimates: sound effects with a set duration 40 credits per second (the highest published rate),
voice 1 credit per character (Flash v2.5 bills 0.5).

Key: ELEVENLABS_API_KEY env var only; never printed or written. Standard library only.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
SPEC = REPO / "tools" / "audio" / "sounds.json"
LEDGER = REPO / "tools" / "audio" / "ledger.json"
OUT = REPO / "assets" / "audio"
TAKES = OUT / "takes"
API = "https://api.elevenlabs.io"
SFX_CREDITS_PER_SECOND = 40
VOICE_CREDITS_PER_CHAR = 1
USAGE_SINCE_MS = 1759276800000  # 2025-10-01: a fixed start, so the cumulative usage only grows
MAX_TAKES = 2


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def estimate(item: dict[str, Any]) -> int:
    if item["kind"] == "voice":
        return math.ceil(len(item["text"]) * VOICE_CREDITS_PER_CHAR)
    return math.ceil(item["seconds"] * SFX_CREDITS_PER_SECOND)


def load_ledger() -> dict[str, Any]:
    if LEDGER.exists():
        return json.loads(LEDGER.read_text())
    return {"budget": None, "usageBaseline": None, "calls": []}


def save_ledger(ledger: dict[str, Any]) -> None:
    LEDGER.write_text(json.dumps(ledger, indent=1) + "\n")


def call(method: str, path: str, key: str, body: dict[str, Any] | None = None) -> tuple[bytes, dict[str, str]]:
    data = json.dumps(body).encode() if body is not None else None
    headers = {"xi-api-key": key, "Accept": "audio/mpeg" if body is not None else "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    for attempt in (1, 2, 3):
        req = urllib.request.Request(API + path, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                keep = {k.lower(): v for k, v in r.headers.items() if "cost" in k.lower() or "character" in k.lower()}
                return r.read(), keep
        except urllib.error.HTTPError as e:
            detail = e.read()[:300].decode("utf-8", "replace")
            if e.code == 429 and attempt < 3:
                time.sleep(5 * attempt)
                continue
            raise RuntimeError(f"HTTP {e.code}: {detail}") from None
    raise RuntimeError("retries exhausted")


def usage_total(key: str) -> float | None:
    end = int(time.time() * 1000)
    try:
        raw, _ = call("GET", f"/v1/usage/character-stats?start_unix={USAGE_SINCE_MS}&end_unix={end}", key)
    except RuntimeError as e:
        print(f"  (usage stats unavailable: {e})", file=sys.stderr)
        return None
    usage = json.loads(raw).get("usage", {})
    return float(sum(sum(v) for v in usage.values()))


def spent(ledger: dict[str, Any], measured: float | None) -> float:
    est = sum(c["estimate"] for c in ledger["calls"])
    if measured is None or ledger["usageBaseline"] is None:
        return est
    return max(est, measured - ledger["usageBaseline"])


def generate(item: dict[str, Any], voice: dict[str, Any], key: str) -> tuple[bytes, dict[str, str]]:
    if item["kind"] == "voice":
        body = {"text": item["text"], "model_id": voice["model"], "voice_settings": voice["settings"]}
        return call("POST", f"/v1/text-to-speech/{voice['voiceId']}?output_format=mp3_44100_128", key, body)
    body = {"text": item["prompt"], "duration_seconds": item["seconds"], "prompt_influence": item.get("influence", 0.3),
            "model_id": "eleven_text_to_sound_v2"}
    if item.get("loop"):
        body["loop"] = True
    return call("POST", "/v1/sound-generation?output_format=mp3_44100_128", key, body)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--plan", action="store_true", help="print the list and estimates; send nothing")
    ap.add_argument("--priority", nargs="*", help="only these priorities (P0, P1, VO)")
    ap.add_argument("--only", nargs="*", help="only these sound names")
    ap.add_argument("--reroll", nargs="*", default=[], help="make a second take of these (once each)")
    ap.add_argument("--budget", type=float, default=2000)
    args = ap.parse_args(argv)

    spec = json.loads(SPEC.read_text())
    items = [s for s in spec["sounds"]
             if (not args.priority or s["priority"] in args.priority) and (not args.only or s["name"] in args.only)]
    if args.reroll:
        items = [s for s in spec["sounds"] if s["name"] in args.reroll]
    ledger = load_ledger()
    takes = {}
    for c in ledger["calls"]:
        takes[c["name"]] = takes.get(c["name"], 0) + 1

    if args.plan:
        total = 0
        for s in items:
            what = s["text"] if s["kind"] == "voice" else f"{s['seconds']} s{' loop' if s.get('loop') else ''}"
            print(f"  {s['priority']:<3} {s['name']:<15} {what:<30} est {estimate(s):>4}  takes so far {takes.get(s['name'], 0)}")
            total += estimate(s)
        print(f"\n{len(items)} items, estimate {total} credits (re-rolls would add up to the same again). Nothing sent.")
        return 0

    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        print("Set ELEVENLABS_API_KEY first; it is never stored or printed.", file=sys.stderr)
        return 2
    measured = usage_total(key)
    if ledger["usageBaseline"] is None:
        ledger["usageBaseline"] = measured
        ledger["budget"] = args.budget
        ledger["startedAt"] = now_iso()
        save_ledger(ledger)
    print(f"spent so far (upper bound): {spent(ledger, measured):.0f} of {args.budget:.0f}")

    OUT.mkdir(parents=True, exist_ok=True)
    made = 0
    for s in items:
        name, mp3 = s["name"], OUT / f"{s['name']}.mp3"
        n = takes.get(name, 0)
        if name in args.reroll:
            if n >= MAX_TAKES:
                print(f"  skip {name}: already re-rolled once")
                continue
        elif mp3.exists():
            print(f"  have {name}")
            continue
        cost = estimate(s)
        so_far = spent(ledger, measured)
        if so_far + cost > args.budget:
            print(f"  STOP before {name}: {so_far:.0f} + {cost} could pass the {args.budget:.0f} budget")
            break
        try:
            audio, hdrs = generate(s, spec["voice"], key)
        except RuntimeError as e:
            print(f"  FAIL {name}: {e}", file=sys.stderr)
            continue
        if mp3.exists():
            TAKES.mkdir(parents=True, exist_ok=True)
            shutil.move(str(mp3), TAKES / f"{name}.{n}.mp3")
        mp3.write_bytes(audio)
        takes[name] = n + 1
        entry = {"name": name, "take": n + 1, "kind": s["kind"], "estimate": cost, "bytes": len(audio), "at": now_iso()}
        entry.update({"seconds": s["seconds"]} if s["kind"] == "sfx" else {"chars": len(s["text"])})
        if hdrs:
            entry["headers"] = hdrs
        ledger["calls"].append(entry)
        measured = usage_total(key)
        if measured is not None and ledger["usageBaseline"] is not None:
            entry["usageAfter"] = measured - ledger["usageBaseline"]
        save_ledger(ledger)
        made += 1
        print(f"  ok   {name} take {n + 1} ({len(audio) // 1024} KB, est {cost}, measured so far "
              f"{entry.get('usageAfter', '?')})")
    print(f"made {made}; spent so far (upper bound): {spent(ledger, measured):.0f} of {args.budget:.0f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
