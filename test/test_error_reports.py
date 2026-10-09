"""Exercise consented error-report handoff without uploading logs or installing."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess

import pytest

from test_callbacks import TOKEN, callbacks, events, tracked_run
from test_launcher import ROOT, Sandbox, raw_code, sandbox

REPORT = "https://paste.uoi.io/Abc_123-xyz"


def event_payloads(sandbox: Sandbox) -> list[dict[str, str]]:
    """Decode the JSON bodies sent through curl's private config input."""
    return [
        json.loads(json.loads(next(
            line.removeprefix("data = ") for line in str(request["config"]).splitlines()
            if line.startswith("data = ")
        ))) for request in callbacks(sandbox)
    ]


def report_installer(sandbox: Sandbox, payload: bytes = b"", *, status: int = 23,
                     replacement: str = "", remove_source: bool = False) -> None:
    """Write a fixture that uses the inherited descriptor and records its boundary."""
    body = f"""import json, os, pathlib, shutil, stat
home = pathlib.Path(os.environ['HOME'])
receipt = pathlib.Path.cwd().parent / 'error-report'
descriptor = os.environ.get('OVOS_INSTALLER_REPORT_FD')
data = {{'descriptor': descriptor, 'receipt_exists': receipt.exists()}}
if descriptor is not None:
    info = os.fstat(int(descriptor))
    data.update(mode=stat.S_IMODE(info.st_mode), regular=stat.S_ISREG(info.st_mode),
                same_file=info.st_ino == receipt.stat().st_ino,
                directory_mode=stat.S_IMODE(receipt.parent.stat().st_mode))
    os.write(int(descriptor), {payload!r})
else:
    try:
        os.fstat(3)
        data['unexpected_fd'] = True
    except OSError:
        data['unexpected_fd'] = False
(home / 'report-handoff.json').write_text(json.dumps(data))
replacement = {replacement!r}
if replacement:
    receipt.unlink()
    if replacement == 'symlink':
        target = home / 'unrelated-report'
        target.write_text({REPORT!r} + '\\n')
        receipt.symlink_to(target)
    elif replacement == 'fifo': os.mkfifo(receipt)
    elif replacement == 'directory': receipt.mkdir()
if {remove_source!r}: shutil.rmtree(pathlib.Path.cwd())
print('Untrusted terminal text: https://elsewhere.example/private-log')
raise SystemExit({status})
"""
    Path(sandbox.env["FAKE_INSTALLER"]).write_text(
        '#!/bin/sh\nexec "$FAKE_PYTHON" - <<\'REPORT_FIXTURE\'\n' + body + 'REPORT_FIXTURE\n'
    )


@pytest.mark.parametrize("url", [REPORT, REPORT + "/", "https://paste.uoi.io/" + "A" * 128 + "/"])
def test_failed_install_reports_one_private_validated_url_atomically(sandbox: Sandbox, url: str) -> None:
    """A final failure includes only the consented URL, even after checkout cleanup."""
    report_installer(sandbox, (url + "\n").encode(), remove_source=True)
    result = tracked_run(sandbox)
    assert result.returncode == 23, result.stderr
    assert events(sandbox) == ["started", "downloading", "installing", "failed"]
    assert event_payloads(sandbox)[-1] == {"event": "failed", "errorUrl": url}
    assert all(set(event) == {"event"} for event in event_payloads(sandbox)[:-1])
    assert json.loads((sandbox.home / "report-handoff.json").read_text()) == {
        "descriptor": "3", "receipt_exists": True, "mode": 0o600,
        "regular": True, "same_file": True, "directory_mode": 0o700,
    }
    assert url not in result.stdout + result.stderr
    assert all(url not in json.dumps(call) and TOKEN not in json.dumps(call) for call in sandbox.calls())
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("payload", [
    b"", REPORT.encode(), (REPORT + "\n\n").encode(), (REPORT + "\n" + REPORT + "\n").encode(),
    b"https://paste.uoi.io/\n", b"http://paste.uoi.io/abc\n", b"https://evil.example/abc\n",
    b"https://paste.uoi.io.evil.example/abc\n", b"https://paste.uoi.io@evil.example/abc\n",
    b"https://paste.uoi.io/abc/extra\n", b"https://paste.uoi.io/abc//\n",
    b"https://paste.uoi.io/abc?token=secret\n", b"https://paste.uoi.io/abc#secret\n",
    b"https://paste.uoi.io/abc%0aextra\n", b"https://paste.uoi.io/abc\r\n",
    b"https://paste.uoi.io/abc\x00\n", b"https://paste.uoi.io/" + b"a" * 129 + b"\n",
    b"x" * 200_000,
])
def test_invalid_or_oversized_receipts_preserve_failure_without_a_link(sandbox: Sandbox, payload: bytes) -> None:
    """Reject malformed URLs and multi-line/log output without evaluating any bytes."""
    report_installer(sandbox, payload)
    result = tracked_run(sandbox)
    assert result.returncode == 23
    assert event_payloads(sandbox)[-1] == {"event": "failed"}
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("replacement", ["missing", "symlink", "fifo", "directory"])
def test_unsafe_report_receipts_are_ignored_without_blocking(sandbox: Sandbox, replacement: str) -> None:
    """Cleanup neither follows another file nor waits on a pipe substituted by setup."""
    report_installer(sandbox, (REPORT + "\n").encode(), replacement=replacement)
    assert tracked_run(sandbox).returncode == 23
    assert event_payloads(sandbox)[-1] == {"event": "failed"}


@pytest.mark.parametrize("status", [0, 129, 130, 143])
def test_success_and_cancellation_never_send_report_links(sandbox: Sandbox, status: int) -> None:
    """Only an unsuccessful, non-signal install can publish its report receipt."""
    report_installer(sandbox, (REPORT + "\n").encode(), status=status)
    assert tracked_run(sandbox).returncode == status
    assert all(set(event) == {"event"} for event in event_payloads(sandbox))
    assert events(sandbox)[-1] == ("needs_attention" if status == 0 else "cancelled")


def test_plain_launch_has_no_report_channel_even_with_inherited_flag(sandbox: Sandbox) -> None:
    """Opting out of tracking removes the inherited flag and closes the reserved FD."""
    report_installer(sandbox)
    result = tracked_run(sandbox, arguments=[raw_code()], changes={"OVOS_INSTALLER_REPORT_FD": "99"})
    assert result.returncode == 23
    assert json.loads((sandbox.home / "report-handoff.json").read_text()) == {
        "descriptor": None, "receipt_exists": False, "unexpected_fd": False,
    }
    assert callbacks(sandbox) == []


def test_report_is_not_reused_for_another_attempt_with_the_same_token(sandbox: Sandbox) -> None:
    """A fresh temporary receipt cannot resurrect a previous failure's report."""
    report_installer(sandbox, (REPORT + "\n").encode())
    assert tracked_run(sandbox).returncode == 23
    assert event_payloads(sandbox)[-1]["errorUrl"] == REPORT
    report_installer(sandbox)
    assert tracked_run(sandbox).returncode == 23
    assert event_payloads(sandbox)[-1] == {"event": "failed"}


def test_report_transport_failure_keeps_the_installer_exit_code(sandbox: Sandbox) -> None:
    """Adding the report field cannot make a network error replace installer failure."""
    report_installer(sandbox, (REPORT + "\n").encode(), status=126)
    result = tracked_run(sandbox, changes={"FAKE_CALLBACK_STATUS": "28"})
    assert result.returncode == 126
    assert event_payloads(sandbox)[-1] == {"event": "failed", "errorUrl": REPORT}
    assert TOKEN not in result.stdout + result.stderr


@pytest.mark.parametrize("event", ["failed", "installed", "cancelled"])
def test_callback_validates_optional_url_at_the_transport_boundary(sandbox: Sandbox, event: str) -> None:
    """A forged helper call cannot smuggle unsafe JSON or attach a link to success."""
    for url in (REPORT, 'https://paste.uoi.io/abc"}\\n', 'https://elsewhere.example/a'):
        result = subprocess.run(
            ["/bin/sh", "-c", '. "$1"; ovos_track=$2; report_status "$3" "$4"',
             "sh", str(ROOT / "lib/callback.sh"), TOKEN, event, url],
            env=sandbox.env, capture_output=True, text=True, timeout=5,
        )
        assert result.returncode == 0
        expected = {"event": event}
        if event == "failed" and url == REPORT:
            expected["errorUrl"] = url
        assert event_payloads(sandbox)[-1] == expected
