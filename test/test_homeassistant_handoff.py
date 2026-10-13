"""Redeem wizard credentials through the real launcher without network or sudo."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess

import pytest

from test_launcher import Sandbox, raw_code, run_interactive, sandbox

TRACK_TOKEN = "0123456789abcdef" * 4
HA_URL = "http://homeassistant.local:8123"
HA_TOKEN = "private.homeassistant-token_~" * 3


def response(sandbox: Sandbox, payload: bytes, status: str = "200") -> None:
    """Provide a byte-exact transport reply without putting secrets in shell arguments."""
    path = sandbox.home.parent / "homeassistant-response"
    path.write_bytes(payload)
    sandbox.env.update(FAKE_HA_RESPONSE_FILE=str(path), FAKE_HA_HTTP=status)


def run(sandbox: Sandbox, *, enabled: bool = True) -> subprocess.CompletedProcess[str]:
    """Run the tracked installer with its real generated elevated launch script."""
    return subprocess.run(
        ["/bin/sh", str(sandbox.launcher), raw_code({"homeassistant": enabled}),
         "--track", TRACK_TOKEN], cwd=sandbox.home, env=sandbox.env,
        capture_output=True, text=True, timeout=15,
    )


def requests(sandbox: Sandbox) -> list[dict[str, object]]:
    """Read only fake request metadata; response secrets are never recorded here."""
    path = sandbox.home / "homeassistant-requests.jsonl"
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def test_valid_credentials_skip_prompts_and_use_private_transport(sandbox: Sandbox) -> None:
    """A complete handoff reaches the installer once, with no terminal secrets or files."""
    response(sandbox, f"{HA_URL}\n{HA_TOKEN}\n".encode())
    result = run(sandbox)
    assert result.returncode == 0, result.stderr
    assert sandbox.received()["HOMEASSISTANT_URL"] == HA_URL
    assert sandbox.received()["HOMEASSISTANT_API_KEY"] == HA_TOKEN
    assert "Home Assistant URL:" not in result.stdout + result.stderr
    assert "Home Assistant long-lived token:" not in result.stdout + result.stderr
    assert HA_TOKEN not in result.stdout + result.stderr
    assert HA_TOKEN not in (sandbox.home / "scenario-during-install.yaml").read_text()
    assert HA_TOKEN not in (sandbox.scenario.parent / "check-setup.sh").read_text()
    captured = requests(sandbox)
    assert len(captured) == 1
    request = captured[0]
    assert request["mode"] == 0o600
    assert 'url = "https://start-api.smartgic.io/v1/homeassistant"' in request["config"]
    assert f'header = "Authorization: Bearer {TRACK_TOKEN}"' in request["config"]
    assert 'request = "POST"' in request["config"]
    assert 'data = "{}"' in request["config"]
    assert request["args"][:5] == ["-q", "--config", "-", "--proto", "=https"]
    assert "--location" not in request["args"]
    assert "--max-filesize" in request["args"] and "4098" in request["args"]
    assert all(TRACK_TOKEN not in json.dumps(call) and HA_TOKEN not in json.dumps(call)
               for call in sandbox.calls())
    assert all(not call["ha_token_exported"] for call in sandbox.calls())
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("token_length", [20, 2048])
def test_token_limits_and_ipv6_url_survive_literal_handoff(sandbox: Sandbox, token_length: int) -> None:
    """Allowed token boundaries and IPv6 addresses remain supported without shell evaluation."""
    url = "http://[fd00::1]:8123"
    token = "a" * token_length
    response(sandbox, f"{url}\n{token}\n".encode())
    recorder = Path(sandbox.env["FAKE_RECORDER"])
    recorder.write_text(recorder.read_text() +
        "pathlib.Path(os.environ['HOME'],'handoff-remains.json').write_text("
        "json.dumps([str(p) for p in pathlib.Path(os.environ['TMPDIR']).glob('ovos-ha.*')]))\n")
    result = run(sandbox)
    assert result.returncode == 0, result.stderr
    assert sandbox.received()["HOMEASSISTANT_URL"] == url
    assert sandbox.received()["HOMEASSISTANT_API_KEY"] == token
    assert json.loads((sandbox.home / "handoff-remains.json").read_text()) == []
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("status", ["410", "400", "401", "403", "404", "429", "500", "302"])
def test_failed_handoff_stops_before_installing_or_prompting(sandbox: Sandbox, status: str) -> None:
    """Consumed, expired, redirected and unavailable handoffs require fresh wizard input."""
    sandbox.seed_scenario()
    response(sandbox, f"{HA_URL}\n{HA_TOKEN}\n".encode(), status)
    result = run(sandbox)
    assert result.returncode != 0
    assert "Return to the wizard" in result.stderr
    assert HA_TOKEN not in result.stdout + result.stderr
    assert "Home Assistant URL:" not in result.stdout + result.stderr
    assert not (sandbox.home / "received.json").exists()
    assert sandbox.scenario.read_text() == "original-user-settings\n"
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("failure", ["6", "28", "60", "63"])
def test_transport_failure_cleans_up_partial_secret_response(sandbox: Sandbox, failure: str) -> None:
    """Network, TLS and response-limit failures never activate a partial handoff."""
    response(sandbox, f"{HA_URL}\n{HA_TOKEN}\n".encode())
    sandbox.env["FAKE_HA_STATUS"] = failure
    result = run(sandbox)
    assert result.returncode != 0
    assert "Return to the wizard" in result.stderr
    assert HA_TOKEN not in result.stdout + result.stderr
    assert not (sandbox.home / "received.json").exists()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("url", [
    "file:///etc/passwd", "http://", "https://user:password@ha.local", "http://ha.local?token=x",
    "http://ha.local/#fragment", "http://ha.local/with space", "http://ha.local:65536",
    "http://ha.local/\rpath", "http://ha.local/\\path", "http://ha.local/" + "a" * 2033,
])
def test_invalid_address_is_rejected_before_export(sandbox: Sandbox, url: str) -> None:
    """Only bounded HTTP(S) HA addresses without URL credentials or controls are accepted."""
    response(sandbox, f"{url}\n{HA_TOKEN}\n".encode())
    result = run(sandbox)
    assert result.returncode != 0
    assert "Return to the wizard" in result.stderr
    assert not (sandbox.home / "received.json").exists()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("token", ["", "a" * 19, "a" * 2049, "a" * 20 + " ",
                                   "literal$(touch PWNED)" * 2, "a" * 20 + "\r", "a" * 20 + "é"])
def test_invalid_token_is_rejected_as_data(sandbox: Sandbox, token: str) -> None:
    """Server replies cannot inject shell, whitespace or unsupported token bytes."""
    response(sandbox, f"{HA_URL}\n{token}\n".encode())
    result = run(sandbox)
    assert result.returncode != 0
    assert "Return to the wizard" in result.stderr
    assert not (sandbox.home / "received.json").exists()
    assert not (sandbox.home / "PWNED").exists()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("suffix", [b"", b"\nextra\n", b"\x00\n", b"\n" + b"a" * 4099])
def test_response_framing_requires_exactly_two_complete_lines(sandbox: Sandbox, suffix: bytes) -> None:
    """Truncated, NUL-containing and oversized response bodies cannot become credentials."""
    response(sandbox, f"{HA_URL}\n{HA_TOKEN}".encode() + suffix)
    result = run(sandbox)
    assert result.returncode != 0
    assert "Return to the wizard" in result.stderr
    assert not (sandbox.home / "received.json").exists()
    assert not list(sandbox.temp.iterdir())


def test_explicit_absence_preserves_legacy_terminal_prompts(sandbox: Sandbox) -> None:
    """HTTP 204 alone permits the existing locally entered HA setup."""
    sandbox.env["FAKE_HA_HTTP"] = "204"
    status, output = run_interactive(
        sandbox, raw_code({"homeassistant": True}),
        [(b"Home Assistant URL: ", HA_URL.encode()),
         (b"Home Assistant long-lived token: ", HA_TOKEN.encode()),
         (b"Next: 1 =", b"")], extra_args=("--track", TRACK_TOKEN),
    )
    assert status == 0, output.decode(errors="replace")
    assert sandbox.received()["HOMEASSISTANT_API_KEY"] == HA_TOKEN
    assert len(requests(sandbox)) == 1
    assert HA_TOKEN.encode() not in output
    assert not list(sandbox.temp.iterdir())


def test_nonempty_absence_reply_is_not_a_legacy_fallback(sandbox: Sandbox) -> None:
    """An inconsistent HTTP 204 response fails without asking users for duplicate input."""
    response(sandbox, f"{HA_URL}\n{HA_TOKEN}\n".encode(), "204")
    result = run(sandbox)
    assert result.returncode != 0
    assert "Return to the wizard" in result.stderr
    assert not (sandbox.home / "received.json").exists()
    assert not list(sandbox.temp.iterdir())


def test_disabled_homeassistant_never_requests_credentials(sandbox: Sandbox) -> None:
    """Unselected integrations never redeem credentials left in an unrelated response."""
    response(sandbox, f"{HA_URL}\n{HA_TOKEN}\n".encode())
    result = run(sandbox, enabled=False)
    assert result.returncode == 0
    assert requests(sandbox) == []
    assert sandbox.received()["HOMEASSISTANT_API_KEY"] is None


def test_valid_homeassistant_handoff_preserves_llm_prompts(sandbox: Sandbox) -> None:
    """Saving HA in the wizard skips only HA prompts, leaving separately configured AI intact."""
    response(sandbox, f"{HA_URL}\n{HA_TOKEN}\n".encode())
    status, output = run_interactive(
        sandbox, raw_code({"homeassistant": True, "llmMode": "local"}),
        [(b"OpenAI-compatible API URL: ", b"http://localhost:11434/v1"),
         (b"Model name: ", b"model"),
         (b"API key (or provider-required placeholder for a keyless local endpoint): ", b"local"),
         (b"Next: 1 =", b"")], extra_args=("--track", TRACK_TOKEN),
    )
    assert status == 0, output.decode(errors="replace")
    assert b"Home Assistant URL:" not in output
    assert sandbox.received()["HOMEASSISTANT_API_KEY"] == HA_TOKEN
    assert sandbox.received()["LLM_MODEL"] == "model"
    assert not list(sandbox.temp.iterdir())
