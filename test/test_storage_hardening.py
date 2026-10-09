"""Keep launcher state private and serialize activation without real installation."""
from __future__ import annotations

import os
from pathlib import Path
import signal
import subprocess
import time

import pytest

from test_launcher import (
    Sandbox,
    raw_code,
    run_interactive,
    run_launcher,
    sandbox,
)


def run_with_process_deadline(sandbox: Sandbox) -> subprocess.CompletedProcess[str]:
    """Kill the complete fake-command group if an unsafe FIFO blocks regression."""
    args = ["/bin/sh", str(sandbox.launcher), raw_code()]
    process = subprocess.Popen(
        args, cwd=sandbox.home, env=sandbox.env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate(timeout=5)
        pytest.fail("Launcher blocked on an unsafe configuration path")
    return subprocess.CompletedProcess(args, process.returncode, stdout, stderr)


@pytest.mark.parametrize("relative", [".config", ".config/ovos-installer"])
@pytest.mark.parametrize("kind", ["file", "fifo", "directory-link", "file-link", "dangling-link"])
def test_unsafe_configuration_parent_is_rejected_before_download(
    sandbox: Sandbox, relative: str, kind: str,
) -> None:
    """Reject ambiguous configuration parents without following or altering them."""
    path = sandbox.home / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    destination = sandbox.home / "unrelated-destination"
    if kind == "file":
        path.write_text("keep parent file\n")
    elif kind == "fifo":
        os.mkfifo(path)
    elif kind == "directory-link":
        destination.mkdir()
        (destination / "keep").write_text("keep unrelated content\n")
        path.symlink_to(destination, target_is_directory=True)
    elif kind == "file-link":
        destination.write_text("keep unrelated file\n")
        path.symlink_to(destination)
    else:
        path.symlink_to(destination)
    before = path.lstat()

    result = run_with_process_deadline(sandbox)

    assert result.returncode != 0
    assert sandbox.calls() == []
    assert path.lstat().st_ino == before.st_ino
    assert not (sandbox.home / "received.json").exists()
    assert not list(sandbox.temp.iterdir())
    if kind == "directory-link":
        assert sorted(item.name for item in destination.iterdir()) == ["keep"]
        assert (destination / "keep").read_text() == "keep unrelated content\n"
    elif kind == "file-link":
        assert destination.read_text() == "keep unrelated file\n"
    elif kind == "dangling-link":
        assert not destination.exists()


@pytest.mark.parametrize("name", ["scenario.yaml", "check-setup.sh"])
@pytest.mark.parametrize("kind", ["directory", "fifo", "directory-link", "file-link", "dangling-link"])
def test_unsafe_scenario_or_checker_is_rejected_before_download(
    sandbox: Sandbox, name: str, kind: str,
) -> None:
    """Never follow symlinks, block on FIFOs or move scripts into directories."""
    config = sandbox.scenario.parent
    config.mkdir(parents=True)
    path = config / name
    destination = sandbox.home / "unrelated-destination"
    if kind == "directory":
        path.mkdir()
        (path / "keep").write_text("keep directory content\n")
    elif kind == "fifo":
        os.mkfifo(path)
    elif kind == "directory-link":
        destination.mkdir()
        (destination / "keep").write_text("keep unrelated content\n")
        path.symlink_to(destination, target_is_directory=True)
    elif kind == "file-link":
        destination.write_text("keep unrelated file\n")
        path.symlink_to(destination)
    else:
        path.symlink_to(destination)
    before = path.lstat()

    result = run_with_process_deadline(sandbox)

    assert result.returncode != 0
    assert sandbox.calls() == []
    assert path.lstat().st_ino == before.st_ino
    assert not (sandbox.home / "received.json").exists()
    assert not (config / ".launcher-lock").exists()
    assert not list(config.glob("scenario.yaml.backup.*"))
    assert not list(sandbox.temp.iterdir())
    if kind == "directory":
        assert sorted(item.name for item in path.iterdir()) == ["keep"]
    elif kind == "directory-link":
        assert sorted(item.name for item in destination.iterdir()) == ["keep"]
    elif kind == "file-link":
        assert destination.read_text() == "keep unrelated file\n"
    elif kind == "dangling-link":
        assert not destination.exists()


def test_regular_configuration_and_checker_are_replaced_with_private_files(sandbox: Sandbox) -> None:
    """A normal existing setup remains supported and receives a private backup."""
    sandbox.seed_scenario()
    sandbox.scenario.chmod(0o644)
    checker = sandbox.scenario.parent / "check-setup.sh"
    checker.write_text("old recovery helper\n")
    checker.chmod(0o644)

    result = run_launcher(sandbox, raw_code())

    assert result.returncode == 0, result.stderr
    backups = list(sandbox.scenario.parent.glob("scenario.yaml.backup.*"))
    assert len(backups) == 1
    assert backups[0].read_text() == "original-user-settings\n"
    assert backups[0].stat().st_mode & 0o777 == 0o600
    assert not sandbox.scenario.exists()
    assert checker.stat().st_mode & 0o777 == 0o700
    assert checker.read_text() != "old recovery helper\n"
    assert not (sandbox.scenario.parent / ".launcher-lock").exists()


@pytest.mark.parametrize("cached", (False, True))
def test_installer_venv_is_accessible_without_exposing_launcher_secrets(
    sandbox: Sandbox, cached: bool,
) -> None:
    """A root-created Python venv must remain traversable for Ansible become_user."""
    installer = Path(sandbox.env["FAKE_INSTALLER"])
    installer.write_text(
        '#!/bin/sh\nset -eu\n'
        '"$FAKE_PYTHON" -m venv --without-pip "$HOME/.venvs/ovos-installer"\n'
    )
    venv = sandbox.home / ".venvs/ovos-installer"
    if cached:
        subprocess.run(
            [sandbox.env["FAKE_PYTHON"], "-m", "venv", "--without-pip", str(venv)],
            check=True, capture_output=True, timeout=10, umask=0o077,
        )
        assert (venv / "bin").stat().st_mode & 0o777 == 0o700
    unrelated = sandbox.home / ".venvs/ovos/private-settings"
    unrelated.parent.mkdir(parents=True, exist_ok=True)
    unrelated.write_text("Keep application state\n")
    unrelated.chmod(0o600)

    result = run_launcher(sandbox, raw_code())

    assert result.returncode == 0, result.stderr
    # Upstream chowns only the venv root and .venvs. Its root-owned children
    # still need read/traverse permissions after a task becomes the user.
    for directory in [venv / "bin", venv / "lib", *list((venv / "lib").glob("python*"))]:
        assert directory.stat().st_mode & 0o777 == 0o755
    assert (venv / "pyvenv.cfg").stat().st_mode & 0o777 == 0o644
    # venv copies activate's mode from the interpreter's own template rather than
    # creating it under the umask, so its exact mode depends on how that Python
    # was installed (0777 in GitHub's hosted toolcache). What the user needs is
    # to read it.
    assert (venv / "bin/activate").stat().st_mode & 0o444 == 0o444
    assert not sandbox.scenario.exists()
    assert (sandbox.scenario.parent / "status-token").stat().st_mode & 0o777 == 0o600
    assert (sandbox.scenario.parent / "status-installed").stat().st_mode & 0o777 == 0o600
    assert (sandbox.scenario.parent / "check-setup.sh").stat().st_mode & 0o777 == 0o700
    assert unrelated.read_text() == "Keep application state\n"
    assert unrelated.stat().st_mode & 0o777 == 0o600
    backups = list(venv.parent.glob("ovos-installer.backup.*/runtime"))
    assert len(backups) == int(cached)
    if cached:
        assert (backups[0] / "bin").stat().st_mode & 0o777 == 0o700
        assert backups[0].parent.stat().st_mode & 0o777 == 0o700
        assert str(backups[0]) in result.stdout


@pytest.mark.parametrize("relative", (".venvs", ".venvs/ovos-installer"))
@pytest.mark.parametrize("kind", ("file", "symlink", "fifo"))
def test_unsafe_installer_runtime_is_not_archived_or_followed(
    sandbox: Sandbox, relative: str, kind: str,
) -> None:
    """Archiving a prior runtime must never follow a link or replace another file."""
    path = sandbox.home / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    unrelated = sandbox.home / "unrelated-runtime"
    unrelated.mkdir()
    sentinel = unrelated / "keep"
    sentinel.write_text("keep\n")
    if kind == "file":
        path.write_text("unexpected file\n")
    elif kind == "symlink":
        path.symlink_to(unrelated, target_is_directory=True)
    else:
        os.mkfifo(path)
    inode = path.lstat().st_ino

    result = run_launcher(sandbox, raw_code())

    assert result.returncode == 1
    assert path.lstat().st_ino == inode
    assert sentinel.read_text() == "keep\n"
    assert not (sandbox.home / "received.json").exists()
    assert not sandbox.scenario.exists()


@pytest.mark.parametrize("kind", ["directory", "directory-link", "file", "dangling-link"])
def test_existing_lock_is_preserved_without_network_or_state_changes(
    sandbox: Sandbox, kind: str,
) -> None:
    """Refuse occupied or ambiguous locks rather than deleting another run's state."""
    sandbox.seed_scenario()
    checker = sandbox.scenario.parent / "check-setup.sh"
    checker.write_text("previous recovery helper\n")
    lock = sandbox.scenario.parent / ".launcher-lock"
    destination = sandbox.home / "lock-destination"
    if kind == "directory":
        lock.mkdir()
        (lock / "owner").write_text("another launcher\n")
    elif kind == "directory-link":
        destination.mkdir()
        (destination / "owner").write_text("another launcher\n")
        lock.symlink_to(destination, target_is_directory=True)
    elif kind == "file":
        lock.write_text("keep existing lock file\n")
    else:
        lock.symlink_to(destination)
    before = lock.lstat()

    result = run_launcher(sandbox, raw_code())

    assert result.returncode != 0
    assert sandbox.calls() == []
    assert lock.lstat().st_ino == before.st_ino
    assert sandbox.scenario.read_text() == "original-user-settings\n"
    assert checker.read_text() == "previous recovery helper\n"
    assert not list(sandbox.scenario.parent.glob("scenario.yaml.backup.*"))
    assert not list(sandbox.temp.iterdir())
    if kind == "directory":
        assert (lock / "owner").read_text() == "another launcher\n"
    elif kind == "directory-link":
        assert (destination / "owner").read_text() == "another launcher\n"


def test_concurrent_launcher_cannot_replace_an_active_install_recipe(sandbox: Sandbox) -> None:
    """Hold the first fake install open while a second recipe is safely refused."""
    installer = Path(sandbox.env["FAKE_INSTALLER"])
    installer.write_text(
        '#!/bin/sh\nprintf ready > "$HOME/installer-started"\n'
        'while [ ! -f "$HOME/release-installer" ]; do sleep 0.05; done\n'
        'exec "$FAKE_PYTHON" "$FAKE_RECORDER"\n'
    )
    process = subprocess.Popen(
        ["/bin/sh", str(sandbox.launcher), raw_code()],
        cwd=sandbox.home, env=sandbox.env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
    )
    release = sandbox.home / "release-installer"
    try:
        deadline = time.monotonic() + 10
        while not (sandbox.home / "installer-started").exists():
            assert process.poll() is None, "The first local fixture exited before installation"
            assert time.monotonic() < deadline, "The first local fixture never started"
            time.sleep(0.02)
        before_scenario = sandbox.scenario.read_bytes()
        checker = sandbox.scenario.parent / "check-setup.sh"
        before_checker = checker.read_bytes()
        before_calls = sandbox.calls()

        refused = run_launcher(sandbox, raw_code({"locale": "fr-fr"}))

        assert refused.returncode != 0
        assert sandbox.calls() == before_calls
        assert sandbox.scenario.read_bytes() == before_scenario
        assert checker.read_bytes() == before_checker
        assert (sandbox.scenario.parent / ".launcher-lock").is_dir()
        release.touch()
        stdout, stderr = process.communicate(timeout=10)
        assert process.returncode == 0, stdout + stderr
        assert not (sandbox.scenario.parent / ".launcher-lock").exists()
    finally:
        release.touch()
        if process.poll() is None:
            try:
                process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=5)


@pytest.mark.parametrize("stage", ["download", "bash", "installer"])
def test_failure_releases_only_the_current_launcher_lock(sandbox: Sandbox, stage: str) -> None:
    """Failures at each stage permit a deliberate retry without stale lock removal."""
    sandbox.seed_scenario()
    changes = {}
    if stage == "download":
        changes["FAIL_GIT"] = "fetch"
    elif stage == "bash":
        changes["FAKE_RUNTIME"] = "unavailable"
    else:
        Path(sandbox.env["FAKE_INSTALLER"]).write_text("#!/bin/sh\nexit 23\n")

    result = run_launcher(sandbox, raw_code({"speech": "public"}), changes=changes)

    assert result.returncode != 0
    assert not (sandbox.scenario.parent / ".launcher-lock").exists()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("failure", ["cancel", "bash"])
def test_canceled_preparation_preserves_the_previous_recovery_checker(
    sandbox: Sandbox, failure: str,
) -> None:
    """Activate the new helper only after runtime checks and credential collection."""
    sandbox.seed_scenario()
    checker = sandbox.scenario.parent / "check-setup.sh"
    checker.write_text("previous recovery helper\n")
    checker.chmod(0o700)
    code = raw_code({"speech": "public", "homeassistant": True})
    if failure == "cancel":
        status, output = run_interactive(sandbox, code, [(b"Home Assistant URL: ", b":cancel")])
        assert status == 130, output.decode(errors="replace")
    else:
        result = run_launcher(sandbox, code, changes={"FAKE_RUNTIME": "unavailable"})
        assert result.returncode != 0

    assert checker.read_text() == "previous recovery helper\n"
    assert checker.stat().st_mode & 0o777 == 0o700
    assert sandbox.scenario.read_text() == "original-user-settings\n"
    assert not (sandbox.home / "received.json").exists()
    assert not (sandbox.scenario.parent / ".launcher-lock").exists()
    assert not list(sandbox.temp.iterdir())


def test_configuration_parent_changed_during_download_cannot_receive_a_backup(sandbox: Sandbox) -> None:
    """Recheck a moved config directory before following a newly introduced link."""
    sandbox.seed_scenario()
    unrelated = sandbox.home / "unrelated"
    unrelated.mkdir()
    (unrelated / "scenario.yaml").write_text("unrelated settings\n")
    git = Path(sandbox.env["PATH"].split(":", 1)[0]) / "git"
    source = git.read_text()
    source = source.replace(
        "    if operation == 'checkout':\n",
        "    if operation == 'checkout':\n"
        "        config = home / '.config/ovos-installer'\n"
        "        config.rename(home / 'moved-config')\n"
        "        config.symlink_to(home / 'unrelated', target_is_directory=True)\n",
    )
    git.write_text(source)
    result = run_launcher(sandbox, raw_code())
    assert result.returncode != 0
    assert sorted(p.name for p in unrelated.iterdir()) == ["scenario.yaml"]
    assert (unrelated / "scenario.yaml").read_text() == "unrelated settings\n"
    assert (sandbox.home / "moved-config/scenario.yaml").read_text() == "original-user-settings\n"
    assert not (sandbox.home / "received.json").exists()
    assert not list(sandbox.temp.iterdir())
