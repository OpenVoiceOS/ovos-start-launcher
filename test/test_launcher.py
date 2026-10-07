"""Exercise the real POSIX launcher with local fakes, never real installation."""
from __future__ import annotations

from dataclasses import dataclass
import errno
import json
import os
from pathlib import Path
import pty
import select
import signal
import shutil
import subprocess
import sys
import time

import pytest

ROOT = Path(__file__).resolve().parents[1]
PIN = "6ffd465028bac299e5235d619819bfdc734af073"
ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
ISSUED_AT = 1_700_000_000
MAX_TIMESTAMP = (1 << 40) - 1
DEFAULTS: dict[str, object] = {
    "device": "pi", "experience": "ready", "locale": "en-us",
    "method": "virtualenv", "channel": "testing", "expertise": "guided",
    "speech": "auto", "memory": "unknown", "cpu": "unknown",
    "piModel": "unknown", "llmMode": "off", "extraSkills": False,
    "telemetry": False, "skills": True, "homeassistant": False,
}
FIELDS = (
    ("device", 4, ("pi", "computer", "mark1", "mark2", "devkit", "jetson", "server", "mac", "windows", "other")),
    ("experience", 2, ("ready", "tinker", "hub")),
    ("locale", 4, ("en-us", "fr-fr", "de-de", "es-es", "it-it", "nl-nl", "pt-pt", "ca-es", "eu-es", "gl-es", "hi-in", "kab-dz")),
    ("method", 1, ("virtualenv", "containers")),
    ("channel", 1, ("testing", "alpha")),
    ("expertise", 2, ("guided", "tinker", "expert")),
    ("speech", 2, ("auto", "public", "local")),
    ("memory", 2, ("unknown", "under8", "8plus")),
    ("cpu", 2, ("unknown", "arm64", "avx2", "intel-mac")),
    ("piModel", 2, ("unknown", "older", "pi5")),
    ("llmMode", 2, ("off", "local", "online")),
    ("extraSkills", 1, (False, True)),
    ("telemetry", 1, (False, True)),
    ("skills", 1, (False, True)),
    ("homeassistant", 1, (False, True)),
)
LOCAL = {"speech": "local", "channel": "alpha", "memory": "8plus", "cpu": "arm64", "piModel": "pi5"}

# This command dispatcher never invokes a network client or real sudo.
FAKE_COMMAND = r'''
import json, os, pathlib, shutil, sys
name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
home = pathlib.Path(os.environ['HOME'])
if name == 'date':
    assert args == ['+%s'], args
    sys.stdout.write(os.environ['FAKE_NOW'] + '\n')
    sys.exit(int(os.environ.get('FAKE_DATE_STATUS', '0')))
if name == 'getconf':
    value = os.environ.get('FAKE_BITS', '64')
    if value == 'error': sys.exit(1)
    print(value); sys.exit(0)
if name == 'id': print(os.environ.get('FAKE_UID', '1000')); sys.exit(0)
if name == 'uname': print(os.environ.get('FAKE_OS', 'Linux')); sys.exit(0)
with (home / 'calls.jsonl').open('a') as log:
    log.write(json.dumps({'command': name, 'args': args}) + '\n')
if name == 'curl':
    if '-o' not in args:
        if os.environ.get('FAIL_BOOTSTRAP'):
            print('printf executed > "$HOME/truncated-ran"'); sys.exit(22)
        print(pathlib.Path(os.environ['FAKE_LAUNCHER']).read_text(), end=''); sys.exit(0)
    shutil.copyfile(os.environ['FAKE_INSTALLER'], args[args.index('-o') + 1])
    sys.exit(22 if os.environ.get('FAIL_CURL') else 0)
if name == 'git':
    assert args[0] == '-C', args
    source, operation = pathlib.Path(args[1]), args[2]
    if os.environ.get('FAIL_GIT') == operation: sys.exit(23)
    if operation == 'checkout':
        (source / 'utils').mkdir()
        shutil.copyfile(os.environ['FAKE_INSTALLER'], source / 'setup.sh')
        shutil.copyfile(os.environ['FAKE_RUNTIME_FILE'], source / 'utils/bash_runtime.sh')
    if operation == 'rev-parse':
        print(os.environ.get('FAKE_SHA', '6ffd465028bac299e5235d619819bfdc734af073'))
    sys.exit(0)
if name == 'sudo':
    assert args[0] == 'sh', args
    assert pathlib.Path(args[1]).resolve().is_relative_to(pathlib.Path(os.environ['TMPDIR']).resolve())
    os.execve('/bin/sh', ['/bin/sh', *args[1:]], {**os.environ, 'SUDO_USER': 'fixture-user'})
raise SystemExit('Unexpected fixture command: ' + name)
'''


@dataclass
class Sandbox:
    """Fixture paths and sanitized subprocess environment."""

    home: Path
    temp: Path
    env: dict[str, str]

    @property
    def launcher(self) -> Path:
        """Return the public launcher entry point selected for this test."""
        return Path(self.env["FAKE_LAUNCHER"])

    @property
    def scenario(self) -> Path:
        """Return the active scenario inside the isolated user directory."""
        return self.home / ".config/ovos-installer/scenario.yaml"

    def seed_scenario(self) -> None:
        """Create pre-existing user configuration for preservation checks."""
        self.scenario.parent.mkdir(parents=True, exist_ok=True)
        self.scenario.write_text("original-user-settings\n", encoding="utf-8")

    def calls(self) -> list[dict[str, object]]:
        """Read network/install command records, excluding harmless probes."""
        log = self.home / "calls.jsonl"
        return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

    def received(self) -> dict[str, str | None]:
        """Read environment captured by the local fake installer."""
        return json.loads((self.home / "received.json").read_text())


@pytest.fixture(params=("v1.sh", "v2.sh"))
def sandbox(tmp_path: Path, request: pytest.FixtureRequest) -> Sandbox:
    """Shadow every network or privileged command; preserve no user environment."""
    home, binary, temp = (tmp_path / part for part in ("test home", "bin", "temp"))
    for folder in (home, binary, temp):
        folder.mkdir()
    recorder = tmp_path / "record.py"
    recorder.write_text(
        "import json,os,pathlib\n"
        "keys=['LOCALE','HOMEASSISTANT_URL','HOMEASSISTANT_API_KEY','LLM_API_URL',"
        "'LLM_API_KEY','LLM_MODEL','LLM_PERSONA','LLM_MAX_TOKENS','LLM_TEMPERATURE',"
        "'LLM_TOP_P','RUN_AS','RUN_AS_HOME']\n"
        "pathlib.Path(os.environ['HOME'],'received.json').write_text("
        "json.dumps({key:os.environ.get(key) for key in keys}))\n",
        encoding="utf-8",
    )
    installer = tmp_path / "installer-fixture.sh"
    installer.write_text('#!/bin/sh\nexec "$FAKE_PYTHON" "$FAKE_RECORDER"\n')
    runtime = tmp_path / "runtime-fixture.sh"
    runtime.write_text(
        "fake_major() { [ \"$1\" != missing ] || return 1; printf '5\\n'; }\n"
        "resolve_bash_runtime() {\n"
        "  [ \"${FAKE_RUNTIME:-ok}\" != unavailable ] || return 1\n"
        "  if [ \"${FAKE_RUNTIME:-ok}\" = missing-first ]; then\n"
        "    for candidate in missing /bin/sh; do\n"
        "      major=$(fake_major \"$candidate\")\n"
        "      if [ \"${major:-0}\" -ge 4 ]; then printf '%s\\n' \"$candidate\"; return 0; fi\n"
        "    done\n"
        "  else printf '/bin/sh\\n'; fi\n"
        "}\n",
        encoding="utf-8",
    )
    for name in ("date", "getconf", "id", "uname", "curl", "git", "sudo"):
        target = binary / name
        target.write_text(f"#!{sys.executable}\n{FAKE_COMMAND}", encoding="utf-8")
        target.chmod(0o700)
    env = {
        "HOME": str(home), "TMPDIR": str(temp), "PATH": f"{binary}:/usr/bin:/bin",
        "LC_ALL": "C.UTF-8", "FAKE_PYTHON": sys.executable,
        "FAKE_RECORDER": str(recorder), "FAKE_INSTALLER": str(installer),
        "FAKE_RUNTIME_FILE": str(runtime), "FAKE_LAUNCHER": str(ROOT / request.param),
        "FAKE_NOW": str(ISSUED_AT),
    }
    return Sandbox(home, temp, env)


def recipe(overrides: dict[str, object] | None = None, *,
           issued_at: int = ISSUED_AT) -> tuple[dict[str, object], str]:
    """Encode and decode a complete recipe through the independent Node codec."""
    state = {**DEFAULTS, **(overrides or {})}
    script = (
        "import {encodeRecipeCode,decodeRecipeCode} from './codec.mjs';"
        "const state=JSON.parse(process.argv[1]);const issuedAt=Number(process.argv[2]);"
        "const code=encodeRecipeCode(state,{issuedAt});"
        "console.log(JSON.stringify({code,state:decodeRecipeCode(code,{now:issuedAt})}));"
    )
    result = subprocess.run(
        ["node", "--input-type=module", "-e", script, json.dumps(state), str(issued_at)],
        cwd=ROOT, capture_output=True, text=True, check=True, timeout=10,
    )
    encoded = json.loads(result.stdout)
    assert encoded["state"] == state
    return state, encoded["code"]


def raw_code(overrides: dict[str, object] | None = None, *, version: int = 2,
             indices: dict[str, int] | None = None, issued_at: int = ISSUED_AT,
             legacy: bool = False) -> str:
    """Encode independent big-endian vectors, including malformed but valid-CRC codes."""
    state = {**DEFAULTS, **(overrides or {})}
    payload = 0
    for key, width, values in FIELDS:
        index = (indices or {}).get(key, values.index(state[key]))
        payload = (payload << width) | index
    header = (version << 28) | payload
    body = header.to_bytes(4, "big")
    if not legacy:
        body += issued_at.to_bytes(5, "big")
    crc = 0
    for byte in body:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ (7 if crc & 128 else 0)) & 255
    word = int.from_bytes(body + bytes((crc,)), "big")
    bit_count = (len(body) + 1) * 8
    compact = "".join(ALPHABET[(word >> shift) & 31]
                      for shift in range(bit_count - 5, -1, -5))
    return "-".join(compact[offset:offset + 4] for offset in range(0, len(compact), 4))


def run_launcher(sandbox: Sandbox, code: str, mode: str | None = None,
                 changes: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    """Run the real shell with only fixture external commands available."""
    args = ["/bin/sh", str(sandbox.launcher), *([mode] if mode else []), code]
    return subprocess.run(args, cwd=sandbox.home, env={**sandbox.env, **(changes or {})},
                          capture_output=True, text=True, timeout=15)


def assert_untouched(sandbox: Sandbox) -> None:
    """Assert validation rejected before downloads, configuration or temp creation."""
    assert sandbox.calls() == []
    assert not sandbox.scenario.parent.exists()
    assert not list(sandbox.temp.iterdir())


def expected_scenario(state: dict[str, object]) -> str:
    """Build the documented YAML contract independently of shell implementation."""
    lines = ["# Created with OVOS Start · contract checked 2026-10-06", "uninstall: false",
             f"method: {state['method']}", f"channel: {state['channel']}",
             "profile: server" if state["experience"] == "hub" else "profile: ovos"]
    if state["speech"] != "auto":
        lines.append(f"speech_engine: {state['speech']}")
    screen = state["device"] in ("mark2", "devkit")
    if screen:
        lines.append(f"hardware: {state['device']}")
    features = {"skills": state["skills"], "extra_skills": state["extraSkills"],
                "gui": screen, "homeassistant": state["homeassistant"], "llm": state["llmMode"] != "off"}
    lines += ["features:", *(f"  {key}: {str(value).lower()}" for key, value in features.items()),
              "raspberry_pi_tuning: false", f"share_telemetry: {str(state['telemetry']).lower()}",
              "share_usage_telemetry: false"]
    return "\n".join(lines) + "\n"


CASES = [
    *({"locale": locale} for locale in FIELDS[2][2]),
    *({"device": device, **({"channel": "alpha"} if device in ("mark2", "devkit", "mac") else {}),
       **({"experience": "hub"} if device == "server" else {})} for device in FIELDS[0][2]),
    {**LOCAL, "experience": "tinker", "expertise": "expert", "extraSkills": True,
     "telemetry": True, "homeassistant": True, "llmMode": "online"},
    {"device": "other", "experience": "hub", "method": "containers", "skills": False,
     "expertise": "tinker", "memory": "under8", "cpu": "avx2", "piModel": "older"},
    {"device": "mac", "channel": "alpha", "speech": "public", "cpu": "intel-mac", "llmMode": "local"},
]


# Frozen protocol fixtures are intentionally literal, not produced by the JS codec.
GOLDEN_VECTORS = (
    ({}, 1_700_000_000, "4000-00G0-CN9Z-206W"),
    ({"device": "computer", "locale": "fr-fr", "homeassistant": True},
     1_700_000_001, "4420-00R0-CN9Z-20E7"),
    ({**LOCAL, "experience": "tinker", "expertise": "expert", "extraSkills": True,
      "telemetry": True, "homeassistant": True, "llmMode": "online"},
     1_700_000_123, "410T-KBR0-CN9Z-2YVY"),
    ({"device": "server", "experience": "hub", "method": "containers", "skills": False},
     1_700_003_600, "4T10-0000-CN9Z-Y450"),
    ({}, MAX_TIMESTAMP, "4000-00QZ-ZZZZ-ZZXR"),
    ({}, 1, "4000-00G0-0000-00AR"),
)


def node_decode(code: str, now: int) -> subprocess.CompletedProcess[str]:
    """Check JavaScript freshness with an explicit clock, independently of the shell."""
    script = (
        "import {decodeRecipeCode} from './codec.mjs';"
        "console.log(JSON.stringify(decodeRecipeCode(process.argv[1],"
        "{now:Number(process.argv[2])})));"
    )
    return subprocess.run(
        ["node", "--input-type=module", "-e", script, code, str(now)],
        cwd=ROOT, capture_output=True, text=True, timeout=10,
    )


@pytest.mark.parametrize(("overrides", "issued_at", "expected"), GOLDEN_VECTORS)
def test_frozen_vectors_match_python_javascript_and_shell(
    sandbox: Sandbox, overrides: dict[str, object], issued_at: int, expected: str
) -> None:
    """Freeze 80-bit ordering, timestamp range, CRC and grouped Crockford encoding."""
    assert raw_code(overrides, issued_at=issued_at) == expected
    state, actual = recipe(overrides, issued_at=issued_at)
    assert actual == expected
    for code in (expected, expected.replace("-", "").lower()):
        decoded = run_launcher(sandbox, code, "--decode", {"FAKE_NOW": str(issued_at)})
        assert decoded.returncode == 0, decoded.stderr
        assert json.loads(decoded.stdout) == state
    scenario = run_launcher(sandbox, expected, "--scenario", {"FAKE_NOW": str(issued_at)})
    assert scenario.returncode == 0, scenario.stderr
    assert scenario.stdout == expected_scenario(state)
    assert_untouched(sandbox)


@pytest.mark.parametrize("mode", (None, "--decode", "--scenario"))
@pytest.mark.parametrize("age", (-1, 0, 3599, 3600, 3601))
def test_timestamp_boundaries_match_javascript_in_every_mode(
    sandbox: Sandbox, mode: str | None, age: int
) -> None:
    """Codes work for one hour, rejecting the exact deadline and future issue times."""
    code = raw_code()
    now = ISSUED_AT + age
    result = run_launcher(sandbox, code, mode, {"FAKE_NOW": str(now)})
    javascript = node_decode(code, now)
    accepted = 0 <= age < 3600
    assert (result.returncode == 0) == accepted, result.stderr
    assert (javascript.returncode == 0) == accepted, javascript.stderr
    if not accepted:
        assert_untouched(sandbox)
    elif mode == "--decode":
        assert json.loads(result.stdout) == json.loads(javascript.stdout) == DEFAULTS
        assert_untouched(sandbox)
    elif mode == "--scenario":
        assert result.stdout == expected_scenario(DEFAULTS)
        assert_untouched(sandbox)
    else:
        assert sandbox.scenario.read_text() == expected_scenario(DEFAULTS)
        assert sandbox.received()["LOCALE"] == "en-us"


@pytest.mark.parametrize("mode", (None, "--decode", "--scenario"))
@pytest.mark.parametrize("code", ("2000-00K9", "200000K9", "2000-00k9"))
def test_legacy_codes_require_regeneration_before_any_effects(
    sandbox: Sandbox, mode: str | None, code: str
) -> None:
    """Frozen v1 codes never activate an untimed install through either public URL."""
    assert raw_code(version=1, legacy=True) == "2000-00K9"
    result = run_launcher(sandbox, code, mode)
    assert result.returncode != 0
    diagnostic = result.stderr.lower()
    assert "generate" in diagnostic and "new" in diagnostic
    assert_untouched(sandbox)


@pytest.mark.parametrize("mode", (None, "--decode", "--scenario"))
@pytest.mark.parametrize("clock", (
    "", "0", "-1", "+1700000000", "01700000000", "1700000000.0", "1.7e9",
    "NaN", " 1700000000", "1700000000 ", "1700000000\t", "1700000000\n1",
    str(MAX_TIMESTAMP + 1), "999999999999999999999999999999999999999999",
))
def test_invalid_clock_rejects_before_any_effects(
    sandbox: Sandbox, mode: str | None, clock: str
) -> None:
    """The date probe must yield one positive canonical 40-bit decimal timestamp."""
    result = run_launcher(sandbox, raw_code(), mode, {"FAKE_NOW": clock})
    assert result.returncode != 0
    assert_untouched(sandbox)


@pytest.mark.parametrize("mode", (None, "--decode", "--scenario"))
@pytest.mark.parametrize("status", (1, 127))
def test_failed_clock_command_rejects_even_with_valid_output(
    sandbox: Sandbox, mode: str | None, status: int
) -> None:
    """A failed date command cannot authenticate freshness using its partial output."""
    result = run_launcher(sandbox, raw_code(), mode, {"FAKE_DATE_STATUS": str(status)})
    assert result.returncode != 0
    assert_untouched(sandbox)


@pytest.mark.parametrize("mode", (None, "--decode", "--scenario"))
def test_missing_clock_command_rejects_before_any_effects(
    sandbox: Sandbox, mode: str | None
) -> None:
    """A PATH without date reports a safe failure without falling back to real time."""
    binary = Path(sandbox.env["PATH"].split(os.pathsep)[0])
    (binary / "date").unlink()
    tr = shutil.which("tr")
    assert tr is not None
    (binary / "tr").symlink_to(tr)
    result = run_launcher(sandbox, raw_code(), mode, {"PATH": str(binary)})
    assert result.returncode != 0
    assert_untouched(sandbox)


@pytest.mark.parametrize("mode", (None, "--decode", "--scenario"))
def test_invalid_freshness_preserves_existing_scenario(
    sandbox: Sandbox, mode: str | None
) -> None:
    """Expiry leaves existing user configuration and installer state completely alone."""
    sandbox.seed_scenario()
    result = run_launcher(sandbox, raw_code(), mode, {"FAKE_NOW": str(ISSUED_AT + 3600)})
    assert result.returncode != 0
    assert sandbox.scenario.read_text() == "original-user-settings\n"
    assert list(sandbox.scenario.parent.iterdir()) == [sandbox.scenario]
    assert sandbox.calls() == []
    assert not (sandbox.home / "received.json").exists()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("overrides", CASES)
def test_node_codes_decode_all_fields_and_emit_expected_scenario(
    sandbox: Sandbox, overrides: dict[str, object]
) -> None:
    """Every field, locale and hardware route survives independent Node/shell decoding."""
    state, code = recipe(overrides)
    decoded = run_launcher(sandbox, code.lower(), "--decode")
    assert decoded.returncode == 0, decoded.stderr
    assert json.loads(decoded.stdout) == state
    scenario = run_launcher(sandbox, code, "--scenario")
    assert scenario.returncode == 0, scenario.stderr
    assert scenario.stdout == expected_scenario(state)
    assert_untouched(sandbox)


@pytest.mark.parametrize("code", [
    "", "1234567", "123456789", "IIIIIIII", "0000_0000", "$(id)xxx", "00000000",
    "123456789ABCDEF", "123456789ABCDEFGH", "IIIIIIIIIIIIIIII",
    "4000_00G0_CN9Z_206W", "400000G0-CN9Z206W", " 4000-00G0-CN9Z-206W",
    "4000-00G0-CN9Z-206W\n", "4000-00G0-CN9Z-206O",
])
def test_malformed_codes_fail_before_effects(sandbox: Sandbox, code: str) -> None:
    """Malformed text cannot trigger shell substitution, fetches or configuration writes."""
    result = run_launcher(sandbox, code)
    assert result.returncode != 0
    assert_untouched(sandbox)


def test_checksum_corruption_and_unknown_version_fail_before_effects(sandbox: Sandbox) -> None:
    """Reject a one-character corruption and a checksum-valid unsupported version."""
    _, code = recipe()
    compact = code.replace("-", "").upper()
    corrupted = compact[:-1] + ALPHABET[(ALPHABET.index(compact[-1]) + 1) % 32]
    for invalid in (corrupted, raw_code(version=3)):
        assert run_launcher(sandbox, invalid).returncode != 0
        assert_untouched(sandbox)


@pytest.mark.parametrize("field", ["device", "experience", "locale", "expertise", "speech", "memory", "piModel", "llmMode"])
def test_unused_enum_values_fail_before_effects(sandbox: Sandbox, field: str) -> None:
    """A valid checksum does not permit unused binary enum values."""
    width = next(width for name, width, _ in FIELDS if name == field)
    result = run_launcher(sandbox, raw_code(indices={field: (1 << width) - 1}))
    assert result.returncode != 0
    assert "unsupported choice" in result.stderr
    assert_untouched(sandbox)


@pytest.mark.parametrize("overrides", [
    {"device": "server"}, {"device": "mark1", "experience": "hub"},
    {"device": "mark2"}, {"device": "mac"}, {"device": "windows", "method": "containers"},
    {"extraSkills": True, "skills": False}, {"experience": "hub", "speech": "public"},
    {"experience": "hub", "homeassistant": True}, {"experience": "hub", "llmMode": "local"},
    {"experience": "hub", "method": "containers", "extraSkills": True},
    {"speech": "local"}, {**LOCAL, "locale": "hi-in"}, {**LOCAL, "piModel": "older"},
    {**LOCAL, "cpu": "avx2"}, {**LOCAL, "device": "mac", "cpu": "intel-mac"},
])
def test_incompatible_choices_fail_before_effects(sandbox: Sandbox, overrides: dict[str, object]) -> None:
    """Raw valid-CRC codes cannot bypass cross-field eligibility and hardware rules."""
    result = run_launcher(sandbox, raw_code(overrides))
    assert result.returncode != 0
    assert "do not fit together" in result.stderr
    assert_untouched(sandbox)


@pytest.mark.parametrize("changes", [{"FAKE_BITS": "32"}, {"FAKE_BITS": ""}, {"FAKE_BITS": "error"}, {"FAKE_UID": "0"}, {"FAKE_OS": "Darwin"}])
def test_preflight_rejects_unsupported_host_before_effects(sandbox: Sandbox, changes: dict[str, str]) -> None:
    """Unsupported architecture, root and wrong target OS stop before any fetch."""
    _, code = recipe()
    assert run_launcher(sandbox, code, changes=changes).returncode != 0
    assert_untouched(sandbox)


def test_mac_code_rejects_linux_before_effects(sandbox: Sandbox) -> None:
    """A Mac recipe is not executable on the fixture's Linux host."""
    _, code = recipe({"device": "mac", "channel": "alpha"})
    assert run_launcher(sandbox, code).returncode != 0
    assert_untouched(sandbox)


@pytest.mark.parametrize("kind", ["directory", "file", "dangling-symlink"])
def test_existing_checkout_is_never_replaced(sandbox: Sandbox, kind: str) -> None:
    """Protect checkout directories, plain files and dangling links equally."""
    checkout = sandbox.home / "ovos-installer"
    if kind == "directory":
        checkout.mkdir()
    elif kind == "file":
        checkout.write_text("keep me")
    else:
        checkout.symlink_to(sandbox.home / "missing")
    _, code = recipe()
    result = run_launcher(sandbox, code)
    assert result.returncode != 0
    assert checkout.exists() or checkout.is_symlink()
    assert_untouched(sandbox)


@pytest.mark.parametrize(("speech", "changes"), [
    ("auto", {"FAIL_CURL": "1"}),
    *(("public", {"FAIL_GIT": operation}) for operation in ("init", "fetch", "checkout", "rev-parse")),
    ("public", {"FAKE_SHA": "0" * 40}),
])
def test_failed_download_or_pin_check_preserves_active_configuration(
    sandbox: Sandbox, speech: str, changes: dict[str, str]
) -> None:
    """Even partial downloads and incorrect revisions cannot overwrite a user scenario."""
    sandbox.seed_scenario()
    _, code = recipe({"speech": speech})
    result = run_launcher(sandbox, code, changes=changes)
    assert result.returncode != 0
    assert sandbox.scenario.read_text() == "original-user-settings\n"
    assert not list(sandbox.scenario.parent.glob("scenario.yaml.backup.*"))
    assert not (sandbox.home / "received.json").exists()
    assert "sudo" not in [call["command"] for call in sandbox.calls()]
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("overrides", [{}, {"speech": "public"}, LOCAL, {"device": "server", "experience": "hub", "method": "containers", "skills": False}])
def test_auto_and_preview_installers_back_up_and_receive_exact_recipe(
    sandbox: Sandbox, overrides: dict[str, object]
) -> None:
    """Only the fixture installer runs with locale, private modes and verified preview pin."""
    sandbox.seed_scenario()
    state, code = recipe({"locale": "fr-fr", "telemetry": True, **overrides})
    result = run_launcher(sandbox, code)
    assert result.returncode == 0, result.stderr
    assert sandbox.scenario.read_text() == expected_scenario(state)
    backups = list(sandbox.scenario.parent.glob("scenario.yaml.backup.*"))
    assert len(backups) == 1 and backups[0].read_text() == "original-user-settings\n"
    assert sandbox.scenario.stat().st_mode & 0o777 == 0o600
    assert sandbox.received()["LOCALE"] == "fr-fr"
    calls = sandbox.calls()
    assert calls[-1]["command"] == "sudo"
    if state["speech"] == "auto":
        assert [call["command"] for call in calls] == ["curl", "sudo"]
    else:
        fetch = next(call for call in calls if "fetch" in call["args"])
        assert fetch["args"][-1] == PIN
        assert sandbox.received()["RUN_AS"] == "fixture-user"
        assert sandbox.received()["RUN_AS_HOME"] == str(sandbox.home)
        assert "curl" not in [call["command"] for call in calls]
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("runtime", ["missing-first", "unavailable"])
def test_preview_runtime_search_handles_missing_candidates(sandbox: Sandbox, runtime: str) -> None:
    """A missing candidate must not abort later candidates or hide the useful diagnostic."""
    sandbox.seed_scenario()
    _, code = recipe({"device": "mac", "channel": "alpha", "speech": "public"})
    result = run_launcher(sandbox, code, changes={"FAKE_OS": "Darwin", "FAKE_RUNTIME": runtime})
    if runtime == "missing-first":
        assert result.returncode == 0, result.stderr
        assert (sandbox.home / "received.json").exists()
    else:
        assert result.returncode != 0
        assert "Install Bash 4+ first" in result.stderr
        assert not (sandbox.home / "received.json").exists()
        assert sandbox.scenario.read_text() == "original-user-settings\n"
    assert not list(sandbox.temp.iterdir())


def run_interactive(sandbox: Sandbox, code: str, answers: list[tuple[bytes, bytes]]) -> tuple[int, bytes]:
    """Drive real terminal reads and masking while every install command stays mocked."""
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(sandbox.home)
        os.execve("/bin/sh", ["/bin/sh", str(sandbox.launcher), code], sandbox.env)
    output = b""
    sent = 0
    reaped = False
    deadline = time.monotonic() + 15
    try:
        while time.monotonic() < deadline:
            if select.select([fd], [], [], 0.1)[0]:
                try:
                    chunk = os.read(fd, 65536)
                except OSError as exc:
                    if exc.errno == errno.EIO:
                        break
                    raise
                if not chunk:
                    break
                output += chunk
                if sent < len(answers) and answers[sent][0] in output:
                    os.write(fd, answers[sent][1] + b"\n")
                    sent += 1
        else:
            pytest.fail("Isolated terminal fixture timed out")
        _, status = os.waitpid(pid, 0)
        reaped = True
        return os.waitstatus_to_exitcode(status), output
    finally:
        if not reaped:
            try:
                os.killpg(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(pid, 0)
        os.close(fd)


@pytest.mark.parametrize("speech", ["auto", "public"])
def test_real_tty_preserves_special_characters_and_masks_credentials(sandbox: Sandbox, speech: str) -> None:
    """HA and LLM credentials remain literal, masked and absent from the stored scenario."""
    sandbox.seed_scenario()
    state, code = recipe({"device": "computer", "locale": "fr-fr", "speech": speech,
                          "homeassistant": True, "llmMode": "local", "extraSkills": True})
    secret = b"literal'$(touch PWNED)&token\\with space"
    model = b"model'$(touch MODEL_PWNED)&literal"
    answers = [
        (b"Home Assistant URL: ", b"http://homeassistant.local:8123"),
        (b"long-lived token: ", secret),
        (b"API URL: ", b"http://localhost:11434/v1"),
        (b"Model name: ", model),
        (b"local endpoint): ", secret),
    ]
    status, output = run_interactive(sandbox, code, answers)
    assert status == 0, output.decode(errors="replace")
    assert secret not in output
    received = sandbox.received()
    assert received["HOMEASSISTANT_API_KEY"] == secret.decode()
    assert received["LLM_API_KEY"] == secret.decode()
    assert received["LLM_MODEL"] == model.decode()
    assert received["HOMEASSISTANT_URL"] == "http://homeassistant.local:8123"
    assert received["LLM_API_URL"] == "http://localhost:11434/v1"
    assert "Français" in received["LLM_PERSONA"]
    assert received["LLM_MAX_TOKENS"] == "300"
    assert received["LLM_TEMPERATURE"] == "0.2"
    assert received["LLM_TOP_P"] == "0.1"
    assert sandbox.scenario.read_text() == expected_scenario(state)
    assert secret.decode() not in sandbox.scenario.read_text()
    assert not (sandbox.home / "PWNED").exists()
    assert not (sandbox.home / "MODEL_PWNED").exists()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("url", [b"", b"file:///etc/passwd"])
def test_invalid_service_input_does_not_activate_scenario(sandbox: Sandbox, url: bytes) -> None:
    """Cancelled or invalid integration input leaves existing configuration active."""
    sandbox.seed_scenario()
    _, code = recipe({"homeassistant": True})
    status, _ = run_interactive(sandbox, code, [(b"Home Assistant URL: ", url), (b"long-lived token: ", b"token")])
    assert status != 0
    assert sandbox.scenario.read_text() == "original-user-settings\n"
    assert not (sandbox.home / "received.json").exists()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("failed", [False, True])
def test_short_bootstrap_never_executes_partial_failed_download(sandbox: Sandbox, failed: bool) -> None:
    """The copyable command uses curl's exit status before evaluating downloaded text."""
    _, code = recipe()
    script = (f'(ovos=$(curl -fsSL https://goldyfruit.github.io/ovos-start-launcher/{sandbox.launcher.name}) '
              '&& sh -c "$ovos" -- "$1")')
    result = subprocess.run(["/bin/sh", "-c", script, "fixture", code], cwd=sandbox.home,
                            env={**sandbox.env, **({"FAIL_BOOTSTRAP": "1"} if failed else {})},
                            capture_output=True, text=True, timeout=15)
    assert not (sandbox.home / "truncated-ran").exists()
    if failed:
        assert result.returncode == 22
        assert not sandbox.scenario.exists()
        assert [call["command"] for call in sandbox.calls()] == ["curl"]
    else:
        assert result.returncode == 0, result.stderr
        assert sandbox.received()["LOCALE"] == "en-us"
