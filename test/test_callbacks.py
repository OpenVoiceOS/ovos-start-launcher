"""Verify optional status transport without network, privilege or installation."""
from __future__ import annotations

import json
import os
from pathlib import Path
import signal
import subprocess
import time

import pytest

from test_launcher import Sandbox, raw_code, run_interactive, sandbox

TOKEN = "0123456789abcdef" * 4
ENDPOINT = "https://start-api.smartgic.io/v1/events"


def tracked_run(sandbox: Sandbox, *, arguments: list[str] | None = None,
                changes: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    """Execute the generated launcher with an isolated optional capability."""
    return subprocess.run(
        ["/bin/sh", str(sandbox.launcher), *(arguments or [raw_code(), "--track", TOKEN])],
        cwd=sandbox.home, env={**sandbox.env, **(changes or {})},
        capture_output=True, text=True, timeout=15,
    )


def callbacks(sandbox: Sandbox) -> list[dict[str, object]]:
    """Read requests captured by the fake curl, including config stdin."""
    path = sandbox.home / "callbacks.jsonl"
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def events(sandbox: Sandbox) -> list[str]:
    """Extract event names from each recorded curl config."""
    result = []
    for request in callbacks(sandbox):
        data_line = next(line for line in str(request["config"]).splitlines() if line.startswith("data = "))
        result.append(json.loads(json.loads(data_line.removeprefix("data = ")))["event"])
    return result


@pytest.mark.parametrize("healthy", (False, True))
def test_progress_keeps_installed_services_and_voice_distinct(sandbox: Sandbox, healthy: bool) -> None:
    """An installer success never becomes an unverified voice success."""
    result = tracked_run(sandbox, changes={"FAKE_HEALTH": "running" if healthy else "waiting"})
    assert result.returncode == 0, result.stderr
    assert events(sandbox) == ["started", "downloading", "installing", "installed", "installed",
                               *(["services_ready"] if healthy else []), "needs_attention"]
    token_file = sandbox.scenario.parent / "status-token"
    assert token_file.read_text() == TOKEN + "\n"
    assert token_file.stat().st_mode & 0o777 == 0o600
    receipt = sandbox.scenario.parent / "status-installed"
    assert receipt.read_text() == TOKEN + "\n"
    assert receipt.stat().st_mode & 0o777 == 0o600
    assert TOKEN not in result.stdout + result.stderr
    assert TOKEN not in (sandbox.scenario.parent / "check-setup.sh").read_text()
    for request in callbacks(sandbox):
        assert request["args"] == ["-q", "--config", "-", "--proto", "=https", "--connect-timeout", "2",
                                    "--max-time", "3", "--silent", "--fail", "--output", "/dev/null"]
        config = str(request["config"])
        assert f'url = "{ENDPOINT}"' in config
        assert f'header = "Authorization: Bearer {TOKEN}"' in config
        assert len(config.splitlines()) == 5
    assert all(TOKEN not in json.dumps(call) for call in sandbox.calls())


@pytest.mark.parametrize("failure", ("6", "22", "28", "60"))
def test_transport_failures_do_not_change_success_or_echo_secrets(sandbox: Sandbox, failure: str) -> None:
    """DNS, relay, timeout and TLS failures are strictly best effort."""
    result = tracked_run(sandbox, changes={"FAKE_CALLBACK_STATUS": failure})
    assert result.returncode == 0
    assert events(sandbox) == ["started", "downloading", "installing", "installed", "installed", "needs_attention"]
    assert TOKEN not in result.stdout + result.stderr
    assert not (sandbox.scenario.parent / ".launcher-lock").exists()


def test_checker_replays_success_receipt_after_lost_install_callback(sandbox: Sandbox) -> None:
    """A disconnected browser can later learn install success from durable proof."""
    assert tracked_run(sandbox, changes={"FAKE_CALLBACK_STATUS": "28"}).returncode == 0
    before = len(events(sandbox))
    result = subprocess.run(["/bin/sh", str(sandbox.scenario.parent / "check-setup.sh")],
                            cwd=sandbox.home, env=sandbox.env, capture_output=True, text=True, timeout=5)
    assert result.returncode == 3
    assert events(sandbox)[before:] == ["installed", "needs_attention"]
    for request in callbacks(sandbox)[before:]:
        assert f'url = "{ENDPOINT}"' in str(request["config"])
        assert request["args"] == ["-q", "--config", "-", "--proto", "=https", "--connect-timeout", "2",
                                    "--max-time", "3", "--silent", "--fail", "--output", "/dev/null"]


def test_failed_rerun_clears_prior_success_receipt_even_with_same_token(sandbox: Sandbox) -> None:
    """Old service state and a reused capability never prove a failed new install."""
    assert tracked_run(sandbox).returncode == 0
    Path(sandbox.env["FAKE_INSTALLER"]).write_text("#!/bin/sh\nexit 23\n")
    assert tracked_run(sandbox).returncode == 23
    assert (sandbox.scenario.parent / "status-installed").read_text() == ""
    before = len(events(sandbox))
    result = subprocess.run(["/bin/sh", str(sandbox.scenario.parent / "check-setup.sh")],
                            cwd=sandbox.home, env={**sandbox.env, "FAKE_HEALTH": "running"},
                            capture_output=True, text=True, timeout=5)
    assert result.returncode == 3
    assert events(sandbox)[before:] == ["services_ready", "needs_attention"]


def test_failed_runtime_retry_preserves_backup_and_reports_only_failure(sandbox: Sandbox) -> None:
    """Refreshing cached tools must not turn a permission failure into success."""
    runtime = sandbox.home / ".venvs/ovos-installer"
    runtime.mkdir(parents=True)
    previous = runtime / "keep"
    previous.write_text("previous installer tools\n")
    previous.chmod(0o600)
    Path(sandbox.env["FAKE_INSTALLER"]).write_text("#!/bin/sh\nexit 126\n")

    result = tracked_run(sandbox)

    assert result.returncode == 126
    assert events(sandbox) == ["started", "downloading", "installing", "failed"]
    backups = list(runtime.parent.glob("ovos-installer.backup.*/runtime/keep"))
    assert len(backups) == 1
    assert backups[0].read_text() == "previous installer tools\n"
    assert backups[0].stat().st_mode & 0o777 == 0o600
    assert (sandbox.scenario.parent / "status-installed").read_text() == ""
    assert (sandbox.scenario.parent / "status-token").stat().st_mode & 0o777 == 0o600


@pytest.mark.parametrize("kind", ("missing", "wrong-token", "symlink", "fifo", "directory"))
def test_checker_never_infers_install_success_from_unsafe_or_stale_receipt(sandbox: Sandbox, kind: str) -> None:
    """Only the current capability's regular private success receipt is replayed."""
    assert tracked_run(sandbox).returncode == 0
    receipt = sandbox.scenario.parent / "status-installed"
    receipt.unlink()
    if kind == "wrong-token":
        receipt.write_text("f" * 64 + "\n")
    elif kind == "symlink":
        receipt.symlink_to(sandbox.scenario.parent / "status-token")
    elif kind == "fifo":
        os.mkfifo(receipt)
    elif kind == "directory":
        receipt.mkdir()
    before = len(events(sandbox))
    result = subprocess.run(["/bin/sh", str(sandbox.scenario.parent / "check-setup.sh")],
                            cwd=sandbox.home, env=sandbox.env, capture_output=True, text=True, timeout=5)
    assert result.returncode == 3
    assert events(sandbox)[before:] == ["needs_attention"]


@pytest.mark.parametrize("kind", ("symlink", "fifo", "directory"))
def test_unsafe_receipt_destination_is_refused_before_installer_effects(sandbox: Sandbox, kind: str) -> None:
    """The installer cannot activate a success receipt through an unsafe path."""
    receipt = sandbox.scenario.parent / "status-installed"
    receipt.parent.mkdir(parents=True)
    if kind == "symlink":
        receipt.symlink_to(sandbox.home / "unrelated")
    elif kind == "fifo":
        os.mkfifo(receipt)
    else:
        receipt.mkdir()
    assert tracked_run(sandbox).returncode == 1
    assert events(sandbox) == ["failed"]
    assert [call for call in sandbox.calls() if call["command"] != "curl"] == []


def test_receipt_path_replaced_during_install_does_not_follow_link_or_hide_success(sandbox: Sandbox) -> None:
    """Installer success survives receipt loss without following replaced storage."""
    Path(sandbox.env["FAKE_INSTALLER"]).write_text(
        '#!/bin/sh\nrm "$HOME/.config/ovos-installer/status-installed"\n'
        'ln -s "$HOME/unrelated" "$HOME/.config/ovos-installer/status-installed"\n'
        'exit 0\n'
    )
    assert tracked_run(sandbox).returncode == 0
    assert not (sandbox.home / "unrelated").exists()
    assert events(sandbox) == ["started", "downloading", "installing", "installed", "needs_attention"]


@pytest.mark.parametrize("status", (1, 23, 129, 130, 143))
def test_installer_failure_and_cancellation_keep_exact_result(sandbox: Sandbox, status: int) -> None:
    """No callback can swallow an installer failure or invent installed status."""
    Path(sandbox.env["FAKE_INSTALLER"]).write_text(f"#!/bin/sh\nexit {status}\n")
    result = tracked_run(sandbox, changes={"FAKE_CALLBACK_STATUS": "28"})
    assert result.returncode == status
    assert events(sandbox) == ["started", "downloading", "installing",
                               "cancelled" if status in (129, 130, 143) else "failed"]
    assert not (sandbox.scenario.parent / ".launcher-lock").exists()


@pytest.mark.parametrize("failure", ("init", "fetch", "checkout"))
def test_download_failure_reports_failure_without_activating_token(sandbox: Sandbox, failure: str) -> None:
    """Early failures remain visible without replacing the prior recovery state."""
    result = tracked_run(sandbox, changes={"FAIL_GIT": failure})
    assert result.returncode == 1
    assert events(sandbox) == ["started", "downloading", "failed"]
    assert not (sandbox.scenario.parent / "status-token").exists()


@pytest.mark.parametrize("arguments", [
    [raw_code(), "--track"], [raw_code(), "--track", TOKEN, "extra"],
    [raw_code(), "--unknown", TOKEN], [raw_code(), "--track", "a" * 63],
    [raw_code(), "--track", "a" * 65], [raw_code(), "--track", "A" * 64],
    [raw_code(), "--track", "\n" + "a" * 63],
    [raw_code(), "--track", "$(touch owned)" + "a" * 50],
    [raw_code(), "--track", "https://evil.example/"],
])
def test_bad_tracking_arguments_fail_before_any_effect(sandbox: Sandbox, arguments: list[str]) -> None:
    """Only one fixed token grammar is allowed; never accept arbitrary destinations."""
    result = tracked_run(sandbox, arguments=arguments)
    assert result.returncode == 1
    assert sandbox.calls() == []
    assert callbacks(sandbox) == []
    assert not (sandbox.home / ".config").exists()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("mode", ("--decode", "--scenario"))
def test_readonly_modes_never_contact_or_persist_tracking(sandbox: Sandbox, mode: str) -> None:
    """A valid token does not turn protocol inspection into a tracking event."""
    result = tracked_run(sandbox, arguments=[mode, raw_code(), "--track", TOKEN])
    assert result.returncode == 0
    assert sandbox.calls() == []
    assert callbacks(sandbox) == []
    assert not (sandbox.home / ".config").exists()


@pytest.mark.parametrize("changes", ({"FAKE_NOW": "1700003600"}, {"FAKE_BITS": "32"}))
def test_invalid_preflight_never_reports_started(sandbox: Sandbox, changes: dict[str, str]) -> None:
    """Freshness, target support and regular-user validation precede callbacks."""
    result = tracked_run(sandbox, changes=changes)
    assert result.returncode == 1
    assert callbacks(sandbox) == []
    assert sandbox.calls() == []


@pytest.mark.parametrize("changes", ({"FAKE_UID": "0"}, {"FAKE_OS": "Darwin"}))
def test_valid_code_preflight_failure_reports_only_failed(sandbox: Sandbox, changes: dict[str, str]) -> None:
    """A validated attempt can explain unsupported target/user conditions remotely."""
    result = tracked_run(sandbox, changes=changes)
    assert result.returncode == 1
    assert events(sandbox) == ["failed"]
    assert [call for call in sandbox.calls() if call["command"] != "curl"] == []
    assert not (sandbox.home / ".config").exists()


@pytest.mark.parametrize("kind", ("directory", "fifo", "symlink"))
def test_unsafe_token_destination_is_rejected_before_installer_network(sandbox: Sandbox, kind: str) -> None:
    """Token activation must never follow a link, block on a FIFO or nest a file."""
    token_file = sandbox.scenario.parent / "status-token"
    token_file.parent.mkdir(parents=True)
    if kind == "directory":
        token_file.mkdir()
    elif kind == "fifo":
        os.mkfifo(token_file)
    else:
        token_file.symlink_to(sandbox.home / "unrelated")
    result = tracked_run(sandbox)
    assert result.returncode == 1
    assert events(sandbox) == ["failed"]
    assert [call for call in sandbox.calls() if call["command"] != "curl"] == []


def test_preflight_failure_keeps_an_existing_empty_lock(sandbox: Sandbox) -> None:
    """A refused double paste cannot release a lock or fail the active session."""
    lock = sandbox.scenario.parent / ".launcher-lock"
    lock.mkdir(parents=True)
    result = tracked_run(sandbox)
    assert result.returncode == 1
    assert events(sandbox) == []
    assert lock.is_dir()
    assert sandbox.calls() == []


def test_token_activation_waits_for_runtime_and_sensitive_input_validation(sandbox: Sandbox) -> None:
    """Cancelling prompted credentials preserves the previous installation token."""
    token_file = sandbox.scenario.parent / "status-token"
    token_file.parent.mkdir(parents=True)
    token_file.write_text("previous-token\n")
    status, output = run_interactive(sandbox, raw_code({"homeassistant": True}), [
        (b"Home Assistant URL: ", b":cancel"),
    ], extra_args=("--track", TOKEN))
    assert status == 130
    assert events(sandbox) == ["started", "downloading", "cancelled"]
    assert token_file.read_text() == "previous-token\n"
    assert TOKEN.encode() not in output


def test_durable_checker_reports_only_real_human_voice_confirmation(sandbox: Sandbox) -> None:
    """The recovery command survives a reboot and cannot reinstall the device."""
    assert tracked_run(sandbox).returncode == 0
    binary = sandbox.home / ".venvs/ovos/bin/python3"
    binary.parent.mkdir(parents=True)
    binary.write_text("#!/bin/sh\ncat >/dev/null\nexit 0\n")
    binary.chmod(0o700)
    original_calls = [call for call in sandbox.calls() if call["command"] != "curl"]
    sandbox.env["FAKE_LAUNCHER"] = str(sandbox.scenario.parent / "check-setup.sh")
    sandbox.env["FAKE_HEALTH"] = "running"
    status, output = run_interactive(sandbox, None, [
        (b"Next: 1 =", b"1"), (b"Did you hear it?", b"1"),
        (b"Did OVOS answer correctly?", b"1"),
    ])
    assert status == 0
    assert events(sandbox)[-6:] == ["services_ready", "audio_checking", "audio_passed",
                                    "microphone_checking", "microphone_passed", "voice_ready"]
    assert TOKEN.encode() not in output
    assert [call for call in sandbox.calls() if call["command"] != "curl"] == original_calls


def test_untracked_install_clears_old_capability_without_network(sandbox: Sandbox) -> None:
    """Opting out on a later run cannot keep reporting to an earlier browser."""
    assert tracked_run(sandbox).returncode == 0
    before = callbacks(sandbox)
    result = tracked_run(sandbox, arguments=[raw_code()])
    assert result.returncode == 0
    assert callbacks(sandbox) == before
    assert (sandbox.scenario.parent / "status-token").read_text() == "\n"


@pytest.mark.parametrize("kind", ("missing", "malformed", "symlink", "fifo"))
def test_durable_checker_ignores_untrusted_token_files(sandbox: Sandbox, kind: str) -> None:
    """No tracking file is ever sourced as shell or read through a symlink/FIFO."""
    assert tracked_run(sandbox).returncode == 0
    before = callbacks(sandbox)
    token_file = sandbox.scenario.parent / "status-token"
    token_file.unlink()
    if kind == "malformed":
        token_file.write_text('$(touch "$HOME/owned")\n')
    elif kind == "symlink":
        other = sandbox.home / "other-token"
        other.write_text(TOKEN + "\n")
        token_file.symlink_to(other)
    elif kind == "fifo":
        os.mkfifo(token_file)
    result = subprocess.run(["/bin/sh", str(sandbox.scenario.parent / "check-setup.sh")],
                            cwd=sandbox.home, env=sandbox.env, capture_output=True, text=True, timeout=5)
    assert result.returncode == 3
    assert callbacks(sandbox) == before
    assert not (sandbox.home / "owned").exists()


def test_callback_helper_rejects_unknown_events(sandbox: Sandbox) -> None:
    """Only the fixed event enum can ever be encoded in an outbound request."""
    root = Path(__file__).resolve().parents[1]
    result = subprocess.run(
        ["/bin/sh", "-c", 'set -eu; . "$1"; ovos_track="$2"; report_status "$3"',
         "callback", str(root / "lib/callback.sh"), TOKEN, 'arbitrary"logs'],
        cwd=sandbox.home, env=sandbox.env, capture_output=True, text=True, timeout=5,
    )
    assert result.returncode == 0
    assert callbacks(sandbox) == []


@pytest.mark.parametrize("interruption", (signal.SIGTERM, signal.SIGHUP, signal.SIGINT))
@pytest.mark.parametrize("shell", ("/bin/sh", "/bin/bash"))
def test_interruption_reports_cancelled_and_releases_lock(
    sandbox: Sandbox, interruption: int, shell: str,
) -> None:
    """Actual process-group signals retain their shell status and send cancellation."""
    # A signal can arrive between a sleep finishing and the next one starting.
    # Give the fake installer explicit exits before announcing readiness, so the
    # test measures launcher cleanup instead of the host shell's loop semantics.
    Path(sandbox.env["FAKE_INSTALLER"]).write_text(
        "#!/bin/sh\ntrap 'exit 130' INT\ntrap 'exit 143' TERM\ntrap 'exit 129' HUP\n"
        'printf ready > "$HOME/installer-started"\n'
        'while :; do sleep 0.05; done\n'
    )
    Path(sandbox.env["FAKE_RUNTIME_FILE"]).write_text(
        f"resolve_bash_runtime() {{ printf '%s\\n' '{shell}'; }}\n"
    )
    process = subprocess.Popen(
        [shell, str(sandbox.launcher), raw_code(), "--track", TOKEN],
        cwd=sandbox.home, env=sandbox.env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
    )
    try:
        deadline = time.monotonic() + 10
        while not (sandbox.home / "installer-started").exists():
            assert process.poll() is None
            assert time.monotonic() < deadline
            time.sleep(0.02)
        os.killpg(process.pid, interruption)
        stdout, stderr = process.communicate(timeout=5)
        assert process.returncode == 128 + interruption, stdout + stderr
        assert events(sandbox) == ["started", "downloading", "installing", "cancelled"]
        assert not (sandbox.scenario.parent / ".launcher-lock").exists()
        assert not list(sandbox.temp.iterdir())
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate(timeout=5)


def test_runtime_failure_keeps_previous_token(sandbox: Sandbox) -> None:
    """An unavailable supported Bash runtime cannot activate fresh credentials."""
    token_file = sandbox.scenario.parent / "status-token"
    token_file.parent.mkdir(parents=True)
    token_file.write_text("previous-token\n")
    result = tracked_run(sandbox, changes={"FAKE_RUNTIME": "unavailable"})
    assert result.returncode == 1
    assert events(sandbox) == ["started", "downloading", "failed"]
    assert token_file.read_text() == "previous-token\n"


def test_missing_curl_is_not_an_installation_dependency(sandbox: Sandbox) -> None:
    """Direct launcher users without curl can still install without status reports."""
    root = Path(__file__).resolve().parents[1]
    result = subprocess.run(
        ["/bin/sh", "-c", 'set -eu; . "$1"; ovos_track="$2"; PATH=/nonexistent; report_status started; printf ok',
         "callback", str(root / "lib/callback.sh"), TOKEN],
        cwd=sandbox.home, env=sandbox.env, capture_output=True, text=True, timeout=5,
    )
    assert result.returncode == 0
    assert result.stdout == "ok"
    assert callbacks(sandbox) == []
