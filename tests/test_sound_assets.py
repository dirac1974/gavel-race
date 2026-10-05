import importlib.util
import io
import json
import re
import urllib.error
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "tools" / "audio" / "sounds.json"
CLIENT = ROOT / "game" / "src" / "client"
SOUND_ASSETS = ROOT / "game" / "src" / "shared" / "SoundAssets.luau"
BANNED = re.compile(r"\b(bet|bets|betting|wager|wagers|odds|stake|stakes|payout|house|bookie)\b", re.I)


def spec_names() -> set[str]:
    return {s["name"] for s in json.loads(SPEC.read_text())["sounds"]}


def call_args(text: str, func: str) -> list[str]:
    """The argument text of every `func(...)` call, matching nested parentheses and skipping strings."""
    out = []
    for m in re.finditer(rf"(?<![\w.:]){re.escape(func)}\(", text):
        i, depth, quote = m.end(), 1, None
        while i < len(text) and depth:
            ch = text[i]
            if quote:
                if ch == "\\":
                    i += 1
                elif ch == quote:
                    quote = None
            elif ch in "\"'`":
                quote = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            i += 1
        out.append(text[m.end():i - 1])
    return out


def used_names() -> set[str]:
    used = set()
    for path in CLIENT.glob("*.luau"):
        text = path.read_text(encoding="utf-8")
        used |= set(re.findall(r'Sound\.(?:play|loop|stop|recent)\(\s*"([a-z0-9_]+)"', text))
        for args in call_args(text, "cue"):
            used |= set(re.findall(r'"([a-z0-9_]+)"', args))
        for table in re.findall(r"FX_SOUND = \{([^}]*)\}", text):
            used |= set(re.findall(r'"([a-z0-9_]+)"', table))
    return used


def test_cue_scanner_handles_nested_parentheses():
    text = 'cue(start + (a * f(b)), "gate_bell") x.cue("no") cue(math.max(0, t), "vo_off", ")")'
    assert call_args(text, "cue") == ['start + (a * f(b)), "gate_bell"', 'math.max(0, t), "vo_off", ")"']


def test_every_sound_the_client_plays_is_in_the_sound_list():
    used = used_names()
    assert used, "found no Sound.play / Sound.loop / cue calls"
    assert {"gate_bell", "vo_off", "vo_stretch", "vo_finish"} <= used  # the race cues are found
    assert used <= spec_names(), sorted(used - spec_names())


def test_sound_levels_name_listed_sounds():
    text = (CLIENT / "Sound.luau").read_text(encoding="utf-8")
    block = re.search(r"local LEVEL = \{(.*?)\n\}", text, re.S)
    assert block, "no LEVEL table in Sound.luau"
    keys = set(re.findall(r"\b([a-z0-9_]+)\s*=", block.group(1)))
    assert keys, "LEVEL table is empty"
    assert keys <= spec_names(), sorted(keys - spec_names())


def test_generated_ids_name_listed_sounds():
    ids = dict(re.findall(r"^\t(\w+) = (\d+),$", SOUND_ASSETS.read_text(), re.M))
    assert set(ids) <= spec_names(), sorted(set(ids) - spec_names())
    assert all(int(v) > 0 for v in ids.values())


def test_sound_text_has_no_wagering_words():
    assert BANNED.search("the house always") and not BANNED.search("a horse in the household")
    for s in json.loads(SPEC.read_text())["sounds"]:
        words = s.get("text") or s.get("prompt") or ""
        assert not BANNED.search(words), s["name"]


def test_sound_list_is_short_and_kid_sized():
    for s in json.loads(SPEC.read_text())["sounds"]:
        if s["kind"] == "sfx":
            assert 0.5 <= s["seconds"] <= 3.0, s["name"]
        else:
            assert len(s["text"]) <= 30, s["name"]


# The generator, with the network mocked (nothing is ever sent) -----------------------------
FAKE_KEY = "fake-key-for-tests"


class FakeResponse:
    def __init__(self, body: bytes, headers: dict[str, str]):
        self.body, self.headers = body, headers

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def read(self) -> bytes:
        return self.body


class FakeApi:
    """Stands in for urllib.request.urlopen: usage stats stay flat, generations return fake audio."""

    def __init__(self):
        self.posts: list[str] = []
        self.gets: list[str] = []
        self.post_error: Exception | None = None
        self.get_error_after_post: Exception | None = None

    def __call__(self, req, timeout=None):
        if req.get_method() == "POST":
            self.posts.append(req.full_url)
            if self.post_error:
                raise self.post_error
            return FakeResponse(b"ID3 fake audio", {"character-cost": "3"})
        self.gets.append(req.full_url)
        if self.posts and self.get_error_after_post:
            raise self.get_error_after_post
        return FakeResponse(json.dumps({"usage": {"all": [100.0]}}).encode(), {})


@pytest.fixture
def gen(tmp_path, monkeypatch):
    spec = importlib.util.spec_from_file_location("generate_audio_under_test", ROOT / "tools" / "audio" / "generate_audio.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    (tmp_path / "sounds.json").write_text(json.dumps({
        "voice": {"model": "m", "voiceId": "v", "settings": {}},
        "sounds": [
            {"name": "vo_a", "priority": "VO", "kind": "voice", "text": "Hello there!"},  # estimate 12
            {"name": "sfx_b", "priority": "P0", "kind": "sfx", "seconds": 1.0, "prompt": "a tick"},  # estimate 40
        ],
    }))
    monkeypatch.setattr(mod, "SPEC", tmp_path / "sounds.json")
    monkeypatch.setattr(mod, "LEDGER", tmp_path / "ledger.json")
    monkeypatch.setattr(mod, "OUT", tmp_path / "audio")
    monkeypatch.setattr(mod, "TAKES", tmp_path / "audio" / "takes")
    monkeypatch.setattr(mod.time, "sleep", lambda _s: None)
    api = FakeApi()
    monkeypatch.setattr(mod.urllib.request, "urlopen", api)
    monkeypatch.setenv("ELEVENLABS_API_KEY", FAKE_KEY)
    mod.api = api
    mod.tmp = tmp_path
    return mod


def write_ledger(gen, spent_estimate: float, calls=None, budget=2000):
    calls = list(calls or [])
    if spent_estimate:
        calls.append({"name": "earlier", "take": 1, "kind": "sfx", "estimate": spent_estimate})
    gen.LEDGER.write_text(json.dumps({"budget": budget, "usageBaseline": 100.0, "calls": calls}))


def test_plan_sends_nothing(gen, monkeypatch):
    def no_network(*_a, **_k):
        raise AssertionError("--plan touched the network")

    monkeypatch.setattr(gen.urllib.request, "urlopen", no_network)
    monkeypatch.delenv("ELEVENLABS_API_KEY")
    assert gen.main(["--plan"]) == 0
    assert not gen.LEDGER.exists() and not gen.OUT.exists()


def test_cap_refuses_a_call_that_would_pass_2000(gen):
    write_ledger(gen, 1990)  # 1990 + 12 > 2000
    assert gen.main(["--only", "vo_a"]) == 0
    assert gen.api.posts == []
    assert not (gen.OUT / "vo_a.mp3").exists()


def test_cap_allows_a_call_that_lands_on_2000(gen):
    write_ledger(gen, 1988)  # 1988 + 12 == 2000
    assert gen.main(["--only", "vo_a"]) == 0
    assert len(gen.api.posts) == 1
    assert (gen.OUT / "vo_a.mp3").read_bytes() == b"ID3 fake audio"


def test_budget_flag_never_raises_the_cap(gen):
    write_ledger(gen, 1990)
    assert gen.main(["--only", "vo_a", "--budget", "5000"]) == 0
    assert gen.api.posts == []
    assert json.loads(gen.LEDGER.read_text())["budget"] == 2000


def test_budget_flag_cannot_raise_a_new_ledger_either(gen):
    assert gen.main(["--only", "none", "--budget", "5000"]) == 0
    assert json.loads(gen.LEDGER.read_text())["budget"] == 2000


def test_budget_flag_can_lower_the_cap(gen):
    write_ledger(gen, 990)
    assert gen.main(["--only", "vo_a", "--budget", "1000"]) == 0
    assert gen.api.posts == []


def test_reroll_stops_at_two_takes(gen):
    write_ledger(gen, 0, [{"name": "vo_a", "take": 1, "kind": "voice", "estimate": 12}])
    gen.OUT.mkdir()
    (gen.OUT / "vo_a.mp3").write_bytes(b"first take")
    assert gen.main(["--reroll", "vo_a"]) == 0
    assert len(gen.api.posts) == 1
    assert (gen.TAKES / "vo_a.1.mp3").read_bytes() == b"first take"
    calls = [c for c in json.loads(gen.LEDGER.read_text())["calls"] if c["name"] == "vo_a"]
    assert [c["take"] for c in calls] == [1, 2]
    assert gen.main(["--reroll", "vo_a"]) == 0  # a third take is refused
    assert len(gen.api.posts) == 1


def test_unknown_reroll_name_is_an_error(gen):
    assert gen.main(["--reroll", "not_a_sound"]) == 2
    assert gen.api.posts == [] and gen.api.gets == []


def test_paid_call_is_recorded_even_if_the_next_request_fails(gen):
    write_ledger(gen, 0)
    gen.api.get_error_after_post = urllib.error.URLError("connection reset")
    assert gen.main(["--only", "vo_a"]) == 0
    calls = json.loads(gen.LEDGER.read_text())["calls"]
    assert [c["name"] for c in calls if c.get("take")] == ["vo_a"]
    assert not list(gen.tmp.glob("*.tmp"))  # the atomic save left no temp file behind


def test_a_paid_call_lost_to_a_timeout_counts_against_the_budget(gen):
    write_ledger(gen, 0)
    gen.api.post_error = TimeoutError("timed out")
    assert gen.main(["--only", "vo_a"]) == 0
    calls = json.loads(gen.LEDGER.read_text())["calls"]
    uncertain = [c for c in calls if c.get("status") == "uncertain"]
    assert [(c["name"], c["estimate"]) for c in uncertain] == [("vo_a", 12)]
    assert gen.takes_so_far(json.loads(gen.LEDGER.read_text())).get("vo_a") is None  # not a take


def test_errors_never_print_the_key(gen, capsys):
    write_ledger(gen, 0)
    gen.api.post_error = urllib.error.HTTPError("https://example.invalid", 401, "Unauthorized", {},
                                                io.BytesIO(f"bad key {FAKE_KEY}".encode()))
    assert gen.main(["--only", "vo_a"]) == 0
    out = capsys.readouterr()
    assert "FAIL vo_a" in out.err
    assert FAKE_KEY not in out.out + out.err
