import hashlib
import json
import re
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "tools" / "audio" / "sounds.json"
MANIFEST = ROOT / "tools" / "audio" / "sheet.json"
SHEET_LUAU = ROOT / "game" / "src" / "shared" / "SoundSheet.luau"
SOUND_ASSETS = ROOT / "game" / "src" / "shared" / "SoundAssets.luau"
SOUND = ROOT / "game" / "src" / "client" / "Sound.luau"
UPLOADED = ROOT / "tools" / "roblox" / "uploaded.json"
BANNED = re.compile(r"\b(bet|bets|betting|wager|wagers|odds|stake|stakes|payout|house|bookie)\b", re.I)


def manifest() -> dict:
    return json.loads(MANIFEST.read_text())


def sheet_path() -> Path:
    return ROOT / manifest()["file"]


def sheet_audio() -> tuple[np.ndarray, int]:
    with wave.open(str(sheet_path())) as w:
        assert (w.getnchannels(), w.getsampwidth()) == (1, 2)
        return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2") / 32768, w.getframerate()


def effects() -> list[dict]:
    return [s for s in json.loads(SPEC.read_text())["sounds"] if s["kind"] == "sfx"]


def luau_clips() -> dict[str, tuple[float, float, bool]]:
    rows = re.findall(r"^\t\t(\w+) = \{ start = ([\d.]+), length = ([\d.]+), loop = (true|false) \},$",
                      SHEET_LUAU.read_text(), re.M)
    return {n: (float(s), float(ln), lp == "true") for n, s, ln, lp in rows}


def test_sheet_names_are_the_effects_plus_tap_ok():
    names = {s["name"] for s in effects()}
    assert "tap_ok" in names
    assert set(manifest()["clips"]) == names


def test_every_clip_fits_in_the_sheet_without_overlap():
    x, sr = sheet_audio()
    assert sr == manifest()["sampleRate"]
    seconds = len(x) / sr
    clips = sorted(manifest()["clips"].values(), key=lambda c: c["start"])
    assert clips[0]["start"] >= 0.05
    for a, b in zip(clips, clips[1:]):
        assert a["start"] + a["length"] + 0.2 <= b["start"] + 1e-9  # silence between clips
    assert clips[-1]["start"] + clips[-1]["length"] <= seconds + 1e-9
    for c in clips:
        assert c["length"] > 0


def test_clips_are_mastered_and_the_gaps_are_silent():
    x, sr = sheet_audio()
    covered = np.zeros(len(x), bool)
    for name, c in manifest()["clips"].items():
        a, b = round(c["start"] * sr), round((c["start"] + c["length"]) * sr)
        clip = x[a:b]
        covered[a:b] = True
        peak = 20 * np.log10(np.max(np.abs(clip)))
        assert -4.0 <= peak <= -2.5, (name, peak)  # about -3 dBFS, never near clipping
        if not c["loop"]:
            assert abs(clip[0]) < 1e-3 and np.max(np.abs(clip[-20:])) < 1e-3, name  # de-clicked edges
    assert np.max(np.abs(x[~covered])) == 0


def test_loop_flags_follow_the_spec_and_the_gallop_wraps_cleanly():
    loops = {s["name"] for s in effects() if s.get("loop")}
    assert loops == {n for n, c in manifest()["clips"].items() if c["loop"]} == {"gallop_loop"}
    x, sr = sheet_audio()
    c = manifest()["clips"]["gallop_loop"]
    clip = x[round(c["start"] * sr): round((c["start"] + c["length"]) * sr)]
    steps = np.abs(np.diff(clip))
    assert abs(clip[-1] - clip[0]) <= 4 * np.median(steps) + 1e-4  # no click at the wrap


def test_generated_module_matches_the_manifest():
    m = manifest()
    want = {n: (c["start"], c["length"], c["loop"]) for n, c in m["clips"].items() if n not in m.get("muted", [])}
    assert luau_clips() == want
    assert "GENERATED" in SHEET_LUAU.read_text().splitlines()[1]


def test_sheet_asset_id_belongs_to_this_exact_file():
    asset = int(re.search(r"^\tassetId = (\d+),$", SHEET_LUAU.read_text(), re.M).group(1))
    rec = json.loads(UPLOADED.read_text()).get("sound_sheet")
    if asset == 0:
        return
    assert rec and rec["assetId"] == asset and rec.get("moderation") != "Rejected"
    assert rec["sha256"] == hashlib.sha256(sheet_path().read_bytes()).hexdigest()  # offsets match the upload


def test_the_sheet_is_not_a_sound_name():
    assert "sound_sheet" not in SOUND_ASSETS.read_text()


def test_sheet_text_has_no_wagering_words():
    for path in (MANIFEST, SHEET_LUAU, ROOT / "tools" / "audio" / "synth_sheet.py"):
        assert not BANNED.search(path.read_text(encoding="utf-8")), path.name


def test_sound_module_falls_back_to_the_sheet():
    text = SOUND.read_text(encoding="utf-8")
    assert 'WaitForChild("SoundSheet"' in text
    for prop in ("PlaybackRegionsEnabled = true", "PlaybackRegion = region", "LoopRegion = region", "PlaybackSpeed"):
        assert prop in text, prop
    src = re.search(r"local function sourceOf\(.*?\nend\n", text, re.S).group(0)
    assert src.index("ids[name]") < src.index("sheet.clips[name]")  # an own upload wins over the stand-in
    assert re.search(r"function Sound\.play\(name: string, volume: number\?, at: Instance\?, speed: number\?\)", text)
    assert re.search(r"function Sound\.loop\(name: string, volume: number\?, speed: number\?\)", text)
