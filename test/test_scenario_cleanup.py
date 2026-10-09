"""Remove only a finished launcher's generated scenario, including path races."""
from __future__ import annotations

from pathlib import Path
import os
import runpy
from dataclasses import dataclass
from collections.abc import Callable, Iterator

import pytest

from test_launcher import ROOT, Sandbox, raw_code, run_launcher, sandbox


def installer_body(sandbox: Sandbox, body: str) -> None:
    """Replace the isolated fake installer with a specific filesystem exercise."""
    Path(sandbox.env["FAKE_INSTALLER"]).write_text("#!/bin/sh\nset -eu\n" + body + "\n")


@pytest.mark.parametrize("status", (0, 1, 23, 129, 130, 143))
def test_finished_attempt_removes_generated_scenario_and_retains_backup(sandbox: Sandbox, status: int) -> None:
    """Completion, failure and interruption preserve results and original settings."""
    sandbox.seed_scenario()
    installer_body(sandbox, 'test -f "$HOME/.config/ovos-installer/scenario.yaml"\n'
                   f'exit {status}')
    result = run_launcher(sandbox, raw_code())
    assert result.returncode == status
    assert not sandbox.scenario.exists()
    assert not list(sandbox.scenario.parent.glob(".scenario-cleanup.*"))
    backups = list(sandbox.scenario.parent.glob("scenario.yaml.backup.*"))
    assert len(backups) == 1
    assert backups[0].read_text() == "original-user-settings\n"
    assert (sandbox.scenario.parent / "check-setup.sh").is_file()
    assert not list(sandbox.temp.iterdir())


@pytest.mark.parametrize("sig, status", (("HUP", 129), ("INT", 130), ("TERM", 143)))
def test_installer_signal_cleans_scenario_and_preserves_status(sandbox: Sandbox, sig: str, status: int) -> None:
    """A genuine signal in the installer follows the same bounded exit cleanup."""
    installer_body(sandbox, f"kill -{sig} $$")
    result = run_launcher(sandbox, raw_code())
    assert result.returncode == status
    assert not sandbox.scenario.exists()
    assert not list(sandbox.scenario.parent.glob(".scenario-cleanup.*"))


@pytest.mark.parametrize("kind", ("file", "symlink", "fifo", "directory"))
def test_unexpected_scenario_replacement_is_preserved(sandbox: Sandbox, kind: str) -> None:
    """Quarantine permits identity checking without deleting an unexpected object."""
    original = sandbox.home / "unrelated"
    original.write_text("keep unrelated\n")
    operations = {
        "file": 'printf "replacement settings\\n" > "$scenario"',
        "symlink": 'ln -s "$HOME/unrelated" "$scenario"',
        "fifo": 'mkfifo "$scenario"',
        "directory": 'mkdir "$scenario"; printf "keep directory\\n" > "$scenario/keep"',
    }
    installer_body(sandbox, 'scenario="$HOME/.config/ovos-installer/scenario.yaml"\n'
                   'rm "$scenario"\n' + operations[kind])
    result = run_launcher(sandbox, raw_code())
    assert result.returncode == 0, result.stderr
    assert original.read_text() == "keep unrelated\n"
    if kind == "directory":
        assert (sandbox.scenario / "keep").read_text() == "keep directory\n"
        assert not list(sandbox.scenario.parent.glob(".scenario-cleanup.*"))
    else:
        assert not list(sandbox.scenario.parent.glob(".scenario-cleanup.*"))
        if kind == "file":
            assert sandbox.scenario.read_text() == "replacement settings\n"
        elif kind == "symlink":
            assert sandbox.scenario.is_symlink()
            assert os.readlink(sandbox.scenario) == str(original)
        else:
            assert sandbox.scenario.is_fifo()


@pytest.mark.parametrize("parent", (".config", ".config/ovos-installer"))
@pytest.mark.parametrize("replacement", ("directory", "symlink"))
def test_replaced_parent_does_not_redirect_privileged_cleanup(sandbox: Sandbox, parent: str, replacement: str) -> None:
    """The open config descriptor cleans its own directory and leaves a new tree alone."""
    relative = "ovos-installer" if parent == ".config" else "."
    install = f'mv "$HOME/{parent}" "$HOME/moved-config"\n'
    if replacement == "directory":
        install += f'mkdir -p "$HOME/{parent}/{relative}"\n'
    else:
        install += (f'mkdir -p "$HOME/unrelated/{relative}"\n'
                    f'ln -s "$HOME/unrelated" "$HOME/{parent}"\n')
    install += 'printf "new settings\\n" > "$HOME/.config/ovos-installer/scenario.yaml"'
    installer_body(sandbox, install)
    result = run_launcher(sandbox, raw_code())
    assert result.returncode == 0, result.stderr
    assert sandbox.scenario.read_text() == "new settings\n"
    moved = sandbox.home / "moved-config" / relative
    assert not (moved / "scenario.yaml").exists()
    assert not list(moved.glob(".scenario-cleanup.*"))


@dataclass
class CleanupCase:
    """Real directory handles and generated inode for an injected syscall race."""

    config: Path
    staging: Path
    config_fd: int
    staging_fd: int
    function: Callable[[int, int, str], None]

    def run(self) -> None:
        """Apply the helper's best-effort exception boundary around real syscalls."""
        try:
            self.function(self.config_fd, self.staging_fd, self.staging.name)
        except OSError:
            pass


@pytest.fixture
def cleanup_case(tmp_path: Path) -> Iterator[CleanupCase]:
    """Pin isolated directories exactly as the original user shell does."""
    config = tmp_path / "config"
    staging = config / ".scenario-cleanup.fixture"
    staging.mkdir(parents=True)
    owned = staging / "owned"
    owned.write_text("wizard-generated settings\n")
    os.link(owned, config / "scenario.yaml")
    config_fd = os.open(config, os.O_RDONLY | os.O_DIRECTORY)
    staging_fd = os.open(staging, os.O_RDONLY | os.O_DIRECTORY)
    function = runpy.run_path(str(ROOT / "lib/scenario_cleanup.py"))["cleanup"]
    try:
        yield CleanupCase(config, staging, config_fd, staging_fd, function)
    finally:
        os.close(config_fd)
        os.close(staging_fd)


@pytest.mark.parametrize("conflict", (False, True))
def test_replacement_racing_quarantine_is_never_unlinked(
    cleanup_case: CleanupCase, monkeypatch: pytest.MonkeyPatch, conflict: bool,
) -> None:
    """Swap after identity check and before rename; preserve both racing writers."""
    case = cleanup_case
    scenario = case.config / "scenario.yaml"
    original_rename = os.rename

    def replace_before_capture(source: str, target: str, **kwargs: int) -> None:
        """Inject the precise pathname-swap window without changing cleanup logic."""
        scenario.unlink()
        scenario.write_text("racing settings\n")
        original_rename(source, target, **kwargs)
        if conflict:
            scenario.write_text("newer settings\n")

    monkeypatch.setattr(os, "rename", replace_before_capture)
    case.run()
    if conflict:
        assert scenario.read_text() == "newer settings\n"
        assert (case.staging / "candidate").read_text() == "racing settings\n"
        assert not (case.staging / "owned").exists()
    else:
        assert scenario.read_text() == "racing settings\n"
        assert not case.staging.exists()


@pytest.mark.parametrize("kind", ("directory", "directory-link"))
def test_restore_cannot_follow_a_racing_destination_directory(
    cleanup_case: CleanupCase, monkeypatch: pytest.MonkeyPatch, kind: str,
) -> None:
    """The exact link syscall refuses directory destinations instead of nesting files."""
    case = cleanup_case
    scenario = case.config / "scenario.yaml"
    unrelated = case.config / "unrelated"
    unrelated.mkdir()
    (unrelated / "keep").write_text("keep unrelated\n")
    original_rename, original_link = os.rename, os.link

    def replace_before_capture(source: str, target: str, **kwargs: int) -> None:
        """Introduce an unexpected file for the restorative rather than delete path."""
        scenario.unlink()
        scenario.write_text("replacement settings\n")
        original_rename(source, target, **kwargs)

    def replace_before_restore(source: str, target: str, **kwargs: object) -> None:
        """Introduce a directory while restore is attempting to reclaim the name."""
        if kind == "directory":
            scenario.mkdir()
        else:
            scenario.symlink_to(unrelated, target_is_directory=True)
        original_link(source, target, **kwargs)

    monkeypatch.setattr(os, "rename", replace_before_capture)
    monkeypatch.setattr(os, "link", replace_before_restore)
    case.run()
    assert sorted(path.name for path in unrelated.iterdir()) == ["keep"]
    assert (unrelated / "keep").read_text() == "keep unrelated\n"
    if kind == "directory":
        assert list(scenario.iterdir()) == []
    assert (case.staging / "candidate").read_text() == "replacement settings\n"
    assert not (case.staging / "owned").exists()


def test_early_failure_without_python_preserves_scenario_privately(sandbox: Sandbox) -> None:
    """Missing cleanup tooling never changes the installer failure or deletes by path."""
    binary = Path(sandbox.env["PATH"].split(":", 1)[0]) / "python3"
    binary.write_text("#!/bin/sh\nexit 127\n")
    binary.chmod(0o700)
    installer_body(sandbox, "exit 23")
    result = run_launcher(sandbox, raw_code())
    assert result.returncode == 23
    assert sandbox.scenario.is_file()
    assert sandbox.scenario.stat().st_mode & 0o777 == 0o600
    guards = list(sandbox.scenario.parent.glob(".scenario-cleanup.*"))
    assert len(guards) == 1
    assert guards[0].stat().st_mode & 0o777 == 0o700


def test_macos_target_uses_portable_cleanup_without_devfd_paths(sandbox: Sandbox) -> None:
    """The same generated launcher cleans a Mac target without Linux fd symlinks."""
    result = run_launcher(sandbox, raw_code({"device": "mac", "channel": "alpha"}),
                          changes={"FAKE_OS": "Darwin"})
    assert result.returncode == 0, result.stderr
    assert not sandbox.scenario.exists()
    assert not list(sandbox.scenario.parent.glob(".scenario-cleanup.*"))
    assert "/dev/fd/" not in (ROOT / "lib/scenario_cleanup.py").read_text()


def test_installed_python_fallback_cleans_when_system_python_is_unavailable(sandbox: Sandbox) -> None:
    """Successful setup's own interpreter handles cleanup without a new prerequisite."""
    binary = Path(sandbox.env["PATH"].split(":", 1)[0]) / "python3"
    binary.write_text("#!/bin/sh\nexit 127\n")
    binary.chmod(0o700)
    installer_body(sandbox, 'mkdir -p "$HOME/.venvs/ovos-installer/bin"\n'
                   'ln -s "$FAKE_PYTHON" "$HOME/.venvs/ovos-installer/bin/python3"')
    result = run_launcher(sandbox, raw_code())
    assert result.returncode == 0, result.stderr
    assert not sandbox.scenario.exists()
    assert not list(sandbox.scenario.parent.glob(".scenario-cleanup.*"))


def test_cleanup_python_is_isolated_and_outside_the_sudo_child(sandbox: Sandbox) -> None:
    """The helper receives isolation flags and never inherits the sudo handoff."""
    binary = Path(sandbox.env["PATH"].split(":", 1)[0]) / "python3"
    binary.write_text('#!/bin/sh\nprintf "%s\\n" "${SUDO_USER:-unset}" "$@" > "$HOME/cleanup-argv"\n'
                      'exec "$FAKE_PYTHON" "$@"\n')
    binary.chmod(0o700)
    result = run_launcher(sandbox, raw_code())
    assert result.returncode == 0, result.stderr
    assert (sandbox.home / "cleanup-argv").read_text().splitlines()[:4] == ["unset", "-I", "-S", "-"]
    assert not sandbox.scenario.exists()
