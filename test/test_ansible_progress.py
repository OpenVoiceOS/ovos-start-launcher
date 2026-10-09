"""Verify real role-based phases without running an installer or network client."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from types import SimpleNamespace

import pytest

from test_callbacks import ENDPOINT, TOKEN, events, tracked_run
from test_launcher import ROOT, Sandbox, raw_code, sandbox

SPEC = importlib.util.spec_from_file_location("ovos_start_progress", ROOT / "lib/ansible_progress.py")
assert SPEC and SPEC.loader
progress = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(progress)


def private_token(home: Path) -> Path:
    """Create a private regular token fixture in the validated account path."""
    token = home / ".config/ovos-installer/status-token"
    token.parent.mkdir(parents=True, exist_ok=True)
    token.write_text(TOKEN + "\n")
    token.chmod(0o600)
    return token


def role_result(name: str) -> SimpleNamespace:
    """Return only Ansible's role identity, with no task output or arguments."""
    return SimpleNamespace(_task=SimpleNamespace(_role=SimpleNamespace(get_name=lambda: name)))


def test_callback_advances_only_successful_roles_and_ignores_late_handlers(monkeypatch: pytest.MonkeyPatch) -> None:
    """Skipped, failed and unknown tasks never invent a completed stage."""
    sent: list[str] = []
    monkeypatch.setattr(progress, "report_phase", sent.append)
    callback = progress.CallbackModule()
    callback.v2_playbook_on_task_start(SimpleNamespace(name="ovos_finalize"), False)
    callback.v2_runner_on_start(None, role_result("ovos_finalize")._task)
    # The base class failed/skipped callbacks require host/result metadata; no
    # override exists, so these cannot invoke our progress-only handler.
    assert "v2_runner_on_skipped" not in vars(progress.CallbackModule)
    assert "v2_runner_on_failed" not in vars(progress.CallbackModule)
    for name in ("unknown", "ovos_contract", "ovos_sound", "ovos_virtualenv", "ovos_python",
                 "ovos_services", "ovos_sound", "ovos_finalize", "ovos_services"):
        callback.v2_runner_on_ok(role_result(name))
    callback.v2_runner_on_ok(SimpleNamespace())
    assert sent == ["stage_system", "stage_packages", "stage_services", "stage_finalize"]


@pytest.mark.parametrize("failure", ("timeout", "missing", "nonzero"))
def test_phase_transport_failure_is_bounded_private_and_never_retried(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, failure: str,
) -> None:
    """At most four silent requests are attempted, with no capability in argv."""
    private_token(tmp_path)
    monkeypatch.setenv("RUN_AS_HOME", str(tmp_path))
    calls: list[tuple[list[str], dict[str, object]]] = []

    def send(args: list[str], **kwargs: object) -> None:
        """Capture transport inputs without making any network connection."""
        calls.append((args, kwargs))
        if failure == "timeout":
            raise subprocess.TimeoutExpired(args, 4)
        if failure == "missing":
            raise FileNotFoundError("curl")
        return None

    monkeypatch.setattr(progress.subprocess, "run", send)
    callback = progress.CallbackModule()
    for name in ("ovos_contract", "ovos_sound", "ovos_virtualenv", "ovos_services", "ovos_finalize"):
        callback.v2_runner_on_ok(role_result(name))
        callback.v2_runner_on_ok(role_result(name))
    assert len(calls) == 4
    for args, kwargs in calls:
        assert args == ["curl", "-q", "--config", "-", "--proto", "=https", "--connect-timeout", "2",
                        "--max-time", "3", "--silent", "--fail", "--output", "/dev/null"]
        assert TOKEN not in json.dumps(args)
        assert kwargs["timeout"] == 4 and kwargs["check"] is False
        assert kwargs["stdout"] == kwargs["stderr"] == subprocess.DEVNULL
        assert str(kwargs["input"]).count(TOKEN) == 1
        assert f'url = "{ENDPOINT}"' in str(kwargs["input"])
        assert len(str(kwargs["input"]).splitlines()) == 5


@pytest.mark.parametrize("kind", ("missing", "short", "long", "uppercase", "non-ascii", "public", "symlink", "fifo", "parent-link"))
def test_phase_transport_refuses_unusable_token_files(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, kind: str,
) -> None:
    """Unsafe token storage cannot block, leak data or initiate a callback."""
    token = private_token(tmp_path)
    monkeypatch.setenv("RUN_AS_HOME", str(tmp_path))
    if kind == "missing":
        token.unlink()
    elif kind == "public":
        token.chmod(0o644)
    elif kind in ("symlink", "fifo"):
        token.unlink()
        if kind == "symlink":
            other = tmp_path / "secret"
            other.write_text(TOKEN)
            other.chmod(0o600)
            token.symlink_to(other)
        else:
            os.mkfifo(token, 0o600)
    elif kind == "parent-link":
        directory = token.parent
        target = tmp_path / "config-copy"
        directory.rename(target)
        directory.symlink_to(target, target_is_directory=True)
    else:
        token.write_text({"short": "a" * 63, "long": "a" * 65, "uppercase": "A" * 64,
                          "non-ascii": "é" * 64}[kind])
    monkeypatch.setattr(progress.subprocess, "run", lambda *args, **kwargs: pytest.fail("Unexpected callback"))
    progress.report_phase("stage_system")
    progress.report_phase("not-a-phase")


@pytest.mark.parametrize("tracked", (False, True))
@pytest.mark.parametrize("inherited", (False, True))
def test_launcher_enables_only_tracked_callback_and_preserves_native_callbacks(
    sandbox: Sandbox, tracked: bool, inherited: bool,
) -> None:
    """The setup child gets callback code/paths, never a bearer environment value."""
    recorder = Path(sandbox.env["FAKE_RECORDER"])
    recorder.write_text(
        "import json,os,pathlib\n"
        "home=pathlib.Path(os.environ['HOME'])\n"
        "plugin=pathlib.Path('.ovos-start-callbacks/ovos_start_progress.py')\n"
        "token=home/'.config/ovos-installer/status-token'\n"
        "data={'plugins':os.environ.get('ANSIBLE_CALLBACK_PLUGINS'),"
        "'enabled':os.environ.get('ANSIBLE_CALLBACKS_ENABLED'),"
        "'code':plugin.read_text() if plugin.exists() else None,"
        "'token_mode':token.stat().st_mode&0o777,"
        f"'secret_in_env':any({TOKEN!r} in value for value in os.environ.values())}}\n"
        "(home/'progress-environment.json').write_text(json.dumps(data))\n"
    )
    changes = {"ANSIBLE_CALLBACK_PLUGINS": "/native/callbacks", "ANSIBLE_CALLBACKS_ENABLED": "native_custom"} if inherited else {}
    result = tracked_run(sandbox, arguments=[raw_code(), "--track", TOKEN] if tracked else [raw_code()], changes=changes)
    assert result.returncode == 0, result.stderr
    data = json.loads((sandbox.home / "progress-environment.json").read_text())
    assert data["token_mode"] == 0o600 and data["secret_in_env"] is False
    if tracked:
        assert data["code"] == (ROOT / "lib/ansible_progress.py").read_text() + "\n"
        assert "/.ovos-start-callbacks" in data["plugins"]
        assert data["enabled"] == ("native_custom" if inherited else "ansible.posix.profile_tasks") + ",ovos_start_progress"
        if inherited:
            assert data["plugins"].endswith(":/native/callbacks")
    else:
        assert data["code"] is None
        assert data["enabled"] == ("native_custom" if inherited else None)
        assert data["plugins"] == ("/native/callbacks" if inherited else None)


@pytest.mark.parametrize("method", ("containers", "virtualenv"))
@pytest.mark.parametrize("failure", (False, True))
def test_real_ansible_callback_discovery_and_conditional_roles(
    sandbox: Sandbox, method: str, failure: bool,
) -> None:
    """A harmless real play proves conditional roles, failure and callback loading."""
    private_token(sandbox.home)
    fixture = sandbox.temp / "ansible-fixture"
    callbacks = fixture / "callbacks"
    callbacks.mkdir(parents=True)
    shutil.copyfile(ROOT / "lib/ansible_progress.py", callbacks / "ovos_start_progress.py")
    names = ("ovos_contract", "ovos_containers", "ovos_virtualenv", "ovos_services", "ovos_finalize")
    for name in names:
        tasks = fixture / "roles" / name / "tasks"
        tasks.mkdir(parents=True)
        body = "- ansible.builtin.assert:\n    that: true\n"
        if failure and name == "ovos_" + method:
            body = "- ansible.builtin.fail:\n    msg: expected fixture failure\n"
        (tasks / "main.yml").write_text(body)
    (fixture / "play.yml").write_text(
        "- hosts: localhost\n  gather_facts: false\n  connection: local\n  roles:\n"
        "    - ovos_contract\n"
        f"    - role: ovos_containers\n      when: {'true' if method == 'containers' else 'false'}\n"
        f"    - role: ovos_virtualenv\n      when: {'true' if method == 'virtualenv' else 'false'}\n"
        "    - ovos_services\n    - ovos_finalize\n"
    )
    (fixture / "ansible.cfg").write_text("[defaults]\nretry_files_enabled=False\nhost_key_checking=False\n")
    result = subprocess.run(
        [sys.executable, "-m", "ansible.cli.playbook", "-i", "localhost,", "play.yml"],
        cwd=fixture, env={**sandbox.env, "RUN_AS_HOME": str(sandbox.home),
                          "PYTHONPATH": os.pathsep.join(path for path in sys.path if path),
                          "ANSIBLE_CONFIG": str(fixture / "ansible.cfg"),
                          "ANSIBLE_CALLBACK_PLUGINS": str(callbacks),
                          "ANSIBLE_CALLBACKS_ENABLED": "ovos_start_progress",
                          "FAKE_CALLBACK_STATUS": "28"},
        capture_output=True, text=True, timeout=20,
    )
    assert result.returncode == (2 if failure else 0), result.stdout + result.stderr
    assert events(sandbox) == (["stage_system"] if failure else
                               ["stage_system", "stage_packages", "stage_services", "stage_finalize"])
    assert TOKEN not in result.stdout + result.stderr
    assert "PLAY RECAP" in result.stdout  # Native stdout remains available.


def test_real_ansible_skipped_roles_emit_no_phase(sandbox: Sandbox) -> None:
    """A play with only a skipped package role must send no progress event."""
    private_token(sandbox.home)
    fixture = sandbox.temp / "skip-fixture"
    tasks = fixture / "roles/ovos_virtualenv/tasks"
    tasks.mkdir(parents=True)
    (tasks / "main.yml").write_text("- ansible.builtin.assert:\n    that: true\n")
    (fixture / "play.yml").write_text(
        "- hosts: localhost\n  gather_facts: false\n  connection: local\n"
        "  roles:\n    - role: ovos_virtualenv\n      when: false\n"
    )
    callbacks = fixture / "callbacks"
    callbacks.mkdir()
    shutil.copyfile(ROOT / "lib/ansible_progress.py", callbacks / "ovos_start_progress.py")
    (fixture / "ansible.cfg").write_text("[defaults]\nretry_files_enabled=False\n")
    result = subprocess.run(
        [sys.executable, "-m", "ansible.cli.playbook", "-i", "localhost,", "play.yml"],
        cwd=fixture, env={**sandbox.env, "RUN_AS_HOME": str(sandbox.home),
                          "PYTHONPATH": os.pathsep.join(path for path in sys.path if path),
                          "ANSIBLE_CONFIG": str(fixture / "ansible.cfg"),
                          "ANSIBLE_CALLBACK_PLUGINS": str(callbacks),
                          "ANSIBLE_CALLBACKS_ENABLED": "ovos_start_progress"},
        capture_output=True, text=True, timeout=20,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "skipped=1" in result.stdout
    assert events(sandbox) == []
