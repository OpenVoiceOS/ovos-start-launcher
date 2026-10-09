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


def checkpoint_result(role: str, filename: str, name: str, data: dict[str, object] | None = None,
                      check_mode: bool = False) -> SimpleNamespace:
    """Provide real-shaped task identity and aggregate results without private output."""
    return SimpleNamespace(
        _task=SimpleNamespace(_role=SimpleNamespace(get_name=lambda: role), name=name,
                              check_mode=check_mode,
                              get_path=lambda: f"/private/ansible/roles/{role}/tasks/{filename}:12"),
        _result={"changed": False} if data is None else data,
    )


@pytest.mark.parametrize("checkpoint,event", list(progress.CHECKPOINTS.items()))
def test_fixed_checkpoints_report_once_after_complete_success(
    monkeypatch: pytest.MonkeyPatch, checkpoint: tuple[str, str, str], event: str,
) -> None:
    """Successful unchanged items and conditional skips prove the selected work finished."""
    sent: list[str] = []
    monkeypatch.setattr(progress, "report_phase", sent.append)
    callback = progress.CallbackModule()
    result = checkpoint_result(*checkpoint, {"results": [{"changed": False}, {"skipped": True}]})
    callback.v2_runner_on_ok(result)
    callback.v2_runner_on_ok(result)
    assert [item for item in sent if item in progress.COMPLETED] == [event]


@pytest.mark.parametrize("data", [
    {"skipped": True}, {"failed": True}, {"rc": 1}, {"results": []},
    {"results": [{"skipped": True}]}, {"results": [{"changed": True}, {"failed": True}]},
    {"results": [{"changed": True}, {"failed": False, "rc": 1}]},
    {"results": [{"changed": True}, "invalid metadata"]},
    {"rc": 1, "results": [{"changed": True}]},
])
def test_skipped_failed_or_partial_aggregate_never_reports_completion(
    monkeypatch: pytest.MonkeyPatch, data: dict[str, object],
) -> None:
    """An ignored failure or partial loop cannot become an installed receipt."""
    sent: list[str] = []
    monkeypatch.setattr(progress, "report_phase", sent.append)
    callback = progress.CallbackModule()
    result = checkpoint_result("ovos_virtualenv", "venv.yml", "Install Open Voice OS in Python venv", data)
    callback.v2_runner_on_ok(result)
    assert not any(item in progress.COMPLETED for item in sent)


@pytest.mark.parametrize("changed", ("role", "path", "name", "check-mode"))
def test_completion_requires_exact_role_task_file_name_and_real_execution(
    monkeypatch: pytest.MonkeyPatch, changed: str,
) -> None:
    """Unknown metadata or dry-run simulation safely provides less progress detail."""
    sent: list[str] = []
    monkeypatch.setattr(progress, "report_phase", sent.append)
    result = checkpoint_result("ovos_virtualenv", "venv.yml", "Install Open Voice OS in Python venv")
    if changed == "role":
        result._task._role = SimpleNamespace(get_name=lambda: "ovos_config")
    elif changed == "path":
        result._task.get_path = lambda: "/private/other/roles/ovos_virtualenv/handlers/venv.yml:12"
    elif changed == "name":
        result._task.name = "Install some other packages"
    else:
        result._task.check_mode = True
    progress.CallbackModule().v2_runner_on_ok(result)
    assert not any(item in progress.COMPLETED for item in sent)


@pytest.mark.parametrize("failure", ("none", "before", "after", "skipped"))
def test_audio_configuration_waits_until_sound_role_reaches_timezone(
    monkeypatch: pytest.MonkeyPatch, failure: str,
) -> None:
    """Sound setup's final optional work must finish before recording configuration."""
    sent: list[str] = []
    monkeypatch.setattr(progress, "report_phase", sent.append)
    callback = progress.CallbackModule()
    sound = checkpoint_result("ovos_sound", "install.yml", "Resolve ALSA default backend for .asoundrc")
    timezone = checkpoint_result("ovos_timezone", "main.yml", "Normalize timezone facts for config consumers")
    if failure == "before":
        callback.v2_runner_on_failed(sound, ignore_errors=True)
    if failure != "skipped":
        callback.v2_runner_on_ok(sound)
    assert "audio_configured" not in sent
    if failure == "after":
        callback.v2_runner_on_failed(sound, ignore_errors=True)
    callback.v2_runner_on_ok(timezone)
    callback.v2_runner_on_ok(timezone)
    assert sent.count("audio_configured") == int(failure == "none")


def test_callback_advances_only_successful_roles_and_ignores_late_handlers(monkeypatch: pytest.MonkeyPatch) -> None:
    """Skipped, failed and unknown tasks never invent a completed stage."""
    sent: list[str] = []
    monkeypatch.setattr(progress, "report_phase", sent.append)
    callback = progress.CallbackModule()
    callback.v2_playbook_on_task_start(SimpleNamespace(name="ovos_finalize"), False)
    callback.v2_runner_on_start(None, role_result("ovos_finalize")._task)
    # Failure only suppresses a pending sound completion; it sends no event.
    assert "v2_runner_on_skipped" not in vars(progress.CallbackModule)
    callback.v2_runner_on_failed(role_result("ovos_sound"), ignore_errors=True)
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


@pytest.mark.parametrize("method", ("virtualenv", "containers"))
@pytest.mark.parametrize("outcome", ("success", "partial-failure", "skipped", "audio-failure"))
def test_real_ansible_completion_receipts_follow_aggregate_task_results(
    sandbox: Sandbox, method: str, outcome: str,
) -> None:
    """Real harmless task loops prove matched files, aggregate completion and skips."""
    private_token(sandbox.home)
    fixture = sandbox.temp / "milestone-fixture"
    callbacks = fixture / "callbacks"
    callbacks.mkdir(parents=True)
    shutil.copyfile(ROOT / "lib/ansible_progress.py", callbacks / "ovos_start_progress.py")

    def write_role(role: str, files: dict[str, str]) -> None:
        """Create fixed upstream-shaped files containing only local assertions."""
        tasks = fixture / "roles" / role / "tasks"
        tasks.mkdir(parents=True)
        for filename, content in files.items():
            (tasks / filename).write_text(content)

    write_role("ovos_sound", {
        "main.yml": "- ansible.builtin.import_tasks: install.yml\n",
        "install.yml": "- name: Resolve ALSA default backend for .asoundrc\n"
                       "  ansible.builtin.assert:\n    that: true\n"
                       "- name: Optional final sound configuration\n"
                       f"  ansible.builtin.assert:\n    that: {'false' if outcome == 'audio-failure' else 'true'}\n"
                       "  ignore_errors: true\n",
    })
    write_role("ovos_timezone", {"main.yml": "- ansible.builtin.assert:\n    that: true\n"})
    role = "ovos_" + method
    package_name = "Copy Python requirements.txt files" if method == "virtualenv" else "Start docker service"
    component_name = "Install Open Voice OS in Python venv" if method == "virtualenv" else "Deploy docker-compose stack"
    package_task = f"- name: {package_name}\n  ansible.builtin.assert:\n    that: true\n"
    component_task = (f"- name: {component_name}\n  ansible.builtin.assert:\n    that: item\n"
                      f"  loop: [true, {'false' if outcome == 'partial-failure' else 'true'}]\n"
                      f"  when: {'false' if outcome == 'skipped' else 'true'}\n"
                      "  ignore_errors: true\n")
    if method == "virtualenv":
        files = {"main.yml": "- ansible.builtin.import_tasks: venv.yml\n",
                 "venv.yml": package_task + component_task}
    else:
        files = {"main.yml": "- ansible.builtin.import_tasks: common.yml\n"
                             "- ansible.builtin.import_tasks: composer.yml\n",
                 "common.yml": package_task, "composer.yml": component_task}
    write_role(role, files)
    (fixture / "play.yml").write_text(
        "- hosts: localhost\n  gather_facts: false\n  connection: local\n  roles:\n"
        f"    - ovos_sound\n    - ovos_timezone\n    - {role}\n"
    )
    result = subprocess.run(
        [sys.executable, "-m", "ansible.cli.playbook", "-i", "localhost,", "play.yml"],
        cwd=fixture, env={**sandbox.env, "RUN_AS_HOME": str(sandbox.home),
                          "PYTHONPATH": os.pathsep.join(path for path in sys.path if path),
                          "ANSIBLE_CALLBACK_PLUGINS": str(callbacks),
                          "ANSIBLE_CALLBACKS_ENABLED": "ovos_start_progress"},
        capture_output=True, text=True, timeout=20,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    completed = [event for event in events(sandbox) if event in progress.COMPLETED]
    assert completed == [*(["audio_configured"] if outcome != "audio-failure" else []),
                         "packages_installed",
                         *(["components_installed"] if outcome in ("success", "audio-failure") else [])]
    assert TOKEN not in result.stdout + result.stderr
