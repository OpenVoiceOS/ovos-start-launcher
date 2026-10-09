"""Exercise the real checker and terminal choices without real audio or sockets."""
from __future__ import annotations

import json
import subprocess

import pytest

from test_callbacks import TOKEN, callbacks, events, tracked_run
from test_launcher import CATALOGS, Sandbox, raw_code, run_interactive, sandbox


def prepare_checker(sandbox: Sandbox, *, locale: str = "en-us", hub: bool = False) -> None:
    """Install a durable checker and a silent bounded sound transport fixture."""
    code = raw_code({"locale": locale, **({"experience": "hub"} if hub else {})})
    assert tracked_run(sandbox, arguments=[code, "--track", TOKEN]).returncode == 0
    binary = sandbox.home / ".venvs/ovos/bin/python3"
    binary.parent.mkdir(parents=True)
    binary.write_text('#!/bin/sh\ncat >/dev/null\nexit "${FAKE_SOUND_STATUS:-0}"\n')
    binary.chmod(0o700)
    sandbox.env["FAKE_LAUNCHER"] = str(sandbox.scenario.parent / "check-setup.sh")
    sandbox.env["FAKE_HEALTH"] = "running"
    (sandbox.home / "callbacks.jsonl").unlink()


@pytest.mark.parametrize("locale", CATALOGS)
def test_both_checks_require_positive_answers_in_every_language(sandbox: Sandbox, locale: str) -> None:
    """Two explicit confirmations, never silent transport success, verify voice."""
    prepare_checker(sandbox, locale=locale)
    catalog = CATALOGS[locale]
    status, output = run_interactive(sandbox, None, [
        (catalog["checkMenu"].encode(), b"1"),
        (catalog["audioQuestion"].encode(), b"1"),
        (catalog["voiceQuestion"].encode(), b"1"),
    ])
    assert status == 0, output.decode(errors="replace")
    assert events(sandbox) == ["installed", "services_ready", "audio_checking", "audio_passed",
                               "microphone_checking", "microphone_passed", "voice_ready"]
    for request in callbacks(sandbox):
        line = next(line for line in request["config"].splitlines() if line.startswith("data = "))
        assert set(json.loads(json.loads(line.removeprefix("data = ")))) == {"event"}
    assert TOKEN.encode() not in output


@pytest.mark.parametrize("check", ("speaker", "microphone"))
def test_no_reports_the_actual_unconfirmed_check(sandbox: Sandbox, check: str) -> None:
    """An explicit negative answer is visible without blaming unrelated hardware."""
    prepare_checker(sandbox)
    answers = [(b"Next: 1 =", b"1"), (b"Did you hear it?", b"3" if check == "speaker" else b"1")]
    if check == "microphone":
        answers.append((b"Did OVOS answer correctly?", b"3"))
    status, output = run_interactive(sandbox, None, answers)
    assert status == 3
    expected = ["installed", "services_ready", "audio_checking"]
    expected += (["audio_failed"] if check == "speaker" else
                 ["audio_passed", "microphone_checking", "microphone_failed"])
    assert events(sandbox) == [*expected, "needs_attention"]
    assert b"First voice response confirmed" not in output


def test_failed_probe_stops_before_manual_voice_confirmation(sandbox: Sandbox) -> None:
    """An unreachable bus cannot accidentally lead to voice-ready confirmation."""
    prepare_checker(sandbox)
    sandbox.env["FAKE_SOUND_STATUS"] = "1"
    status, output = run_interactive(sandbox, None, [(b"Next: 1 =", b"1")])
    assert status == 3
    assert events(sandbox) == ["installed", "services_ready", "audio_checking", "audio_failed", "needs_attention"]
    assert b"Did you hear it?" not in output
    assert b"Did OVOS answer correctly?" not in output


def test_retries_start_new_checks_before_positive_results(sandbox: Sandbox) -> None:
    """A retry can move a failed/pending check back through its checking state."""
    prepare_checker(sandbox)
    status, _ = run_interactive(sandbox, None, [
        (b"Next: 1 =", b"1"), (b"Did you hear it?", b"2"),
        (b"Did you hear it?", b"1"), (b"Did OVOS answer correctly?", b"2"),
        (b"Did OVOS answer correctly?", b"1"),
    ])
    assert status == 0
    assert events(sandbox) == ["installed", "services_ready", "audio_checking", "audio_checking",
                               "audio_passed", "microphone_checking", "microphone_checking",
                               "microphone_passed", "voice_ready"]


@pytest.mark.parametrize("stage", ("start", "speaker", "microphone"))
@pytest.mark.parametrize("answer", (b"", b":cancel"))
def test_deferred_or_cancelled_question_remains_unfinished(sandbox: Sandbox, stage: str, answer: bytes) -> None:
    """A skipped question never reports a fabricated failed hardware result."""
    prepare_checker(sandbox)
    answers = [(b"Next: 1 =", answer if stage == "start" else b"1")]
    expected = ["installed", "services_ready"]
    if stage != "start":
        answers.append((b"Did you hear it?", answer if stage == "speaker" else b"1"))
        expected.append("audio_checking")
    if stage == "microphone":
        answers.append((b"Did OVOS answer correctly?", answer))
        expected += ["audio_passed", "microphone_checking"]
    status, _ = run_interactive(sandbox, None, answers)
    assert status == 3
    assert events(sandbox) == [*expected, "needs_attention"]


@pytest.mark.parametrize("hub", (False, True))
def test_no_terminal_or_hub_never_probes_device_audio(sandbox: Sandbox, hub: bool) -> None:
    """Headless installation and hubs preserve pending rather than failed checks."""
    prepare_checker(sandbox, hub=hub)
    result = subprocess.run(["/bin/sh", str(sandbox.launcher)], env=sandbox.env,
                            capture_output=True, text=True, timeout=5, start_new_session=True)
    assert result.returncode == 3
    assert events(sandbox) == ["installed", "services_ready", "needs_attention"]
    assert "Did you hear it?" not in result.stdout


def test_callback_outage_does_not_block_terminal_confirmation(sandbox: Sandbox) -> None:
    """Best-effort reporting cannot prevent a successful local check."""
    prepare_checker(sandbox)
    sandbox.env["FAKE_CALLBACK_STATUS"] = "28"
    status, _ = run_interactive(sandbox, None, [(b"Next: 1 =", b"1"),
                                              (b"Did you hear it?", b"1"),
                                              (b"Did OVOS answer correctly?", b"1")])
    assert status == 0
    assert events(sandbox)[-1] == "voice_ready"


@pytest.mark.parametrize("stage", ("speaker", "microphone"))
def test_interrupt_clears_active_check_without_reporting_failure(sandbox: Sandbox, stage: str) -> None:
    """Ctrl+C clears checking state while preserving the terminal cancellation."""
    prepare_checker(sandbox)
    answers = [(b"Next: 1 =", b"1"), (b"Did you hear it?", b"\x03" if stage == "speaker" else b"1")]
    if stage == "microphone":
        answers.append((b"Did OVOS answer correctly?", b"\x03"))
    status, _ = run_interactive(sandbox, None, answers)
    assert status in (130, -2)
    assert events(sandbox)[-1] == "needs_attention"
    assert not any(event.endswith("_failed") for event in events(sandbox))
