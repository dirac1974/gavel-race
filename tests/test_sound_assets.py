import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "tools" / "audio" / "sounds.json"
CLIENT = ROOT / "game" / "src" / "client"
SOUND_ASSETS = ROOT / "game" / "src" / "shared" / "SoundAssets.luau"
BANNED = re.compile(r"\b(bet|bets|betting|wager|wagers|odds|stake|stakes|payout|bookie)\b", re.I)


def spec_names() -> set[str]:
    return {s["name"] for s in json.loads(SPEC.read_text())["sounds"]}


def used_names() -> set[str]:
    used = set()
    for path in CLIENT.glob("*.luau"):
        text = path.read_text(encoding="utf-8")
        used |= set(re.findall(r'Sound\.(?:play|loop)\(\s*"([a-z0-9_]+)"', text))
        for args in re.findall(r"\bcue\(([^)]*)\)", text):
            used |= set(re.findall(r'"([a-z0-9_]+)"', args))
        for table in re.findall(r"FX_SOUND = \{([^}]*)\}", text):
            used |= set(re.findall(r'"([a-z0-9_]+)"', table))
    return used


def test_every_sound_the_client_plays_is_in_the_sound_list():
    used = used_names()
    assert used, "found no Sound.play / Sound.loop / cue calls"
    assert used <= spec_names(), sorted(used - spec_names())


def test_generated_ids_name_listed_sounds():
    ids = dict(re.findall(r"^\t(\w+) = (\d+),$", SOUND_ASSETS.read_text(), re.M))
    assert set(ids) <= spec_names(), sorted(set(ids) - spec_names())
    assert all(int(v) > 0 for v in ids.values())


def test_sound_text_has_no_wagering_words():
    for s in json.loads(SPEC.read_text())["sounds"]:
        words = s.get("text") or s.get("prompt") or ""
        assert not BANNED.search(words), s["name"]


def test_sound_list_is_short_and_kid_sized():
    for s in json.loads(SPEC.read_text())["sounds"]:
        if s["kind"] == "sfx":
            assert 0.5 <= s["seconds"] <= 3.0, s["name"]
        else:
            assert len(s["text"]) <= 30, s["name"]
