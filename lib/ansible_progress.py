"""Report fixed phases and completed checkpoints without forwarding task data."""
from __future__ import annotations

import os
from pathlib import Path
import re
import stat
import subprocess

from ansible.plugins.callback import CallbackBase

PHASES = {
    "ovos_contract": 1, "ovos_hardware_mark1": 1, "ovos_hardware_mark2": 1,
    "ovos_facts": 1, "ovos_audio_tuning": 1, "ovos_network_tuning": 1,
    "ovos_storage_tuning": 1, "ovos_performance_tuning": 1,
    "ovos_sound": 1, "ovos_timezone": 1, "ovos_config": 1,
    "ovos_containers": 2, "ovos_virtualenv": 2, "ovos_python": 2,
    "ovos_services": 3, "ovos_finalize": 4,
}
EVENTS = ("", "stage_system", "stage_packages", "stage_services", "stage_finalize")
COMPLETED = ("packages_installed", "audio_configured", "components_installed")
CHECKPOINTS = {
    ("ovos_virtualenv", "venv.yml", "Copy Python requirements.txt files"): "packages_installed",
    ("ovos_containers", "common.yml", "Start docker service"): "packages_installed",
    ("ovos_virtualenv", "venv.yml", "Install Open Voice OS in Python venv"): "components_installed",
    ("ovos_containers", "composer.yml", "Deploy docker-compose stack"): "components_installed",
}


def report_phase(event: str) -> None:
    """Send one bounded, best-effort enum without exporting the private bearer."""
    if event not in EVENTS[1:] + COMPLETED:
        return
    try:
        home = Path(os.environ.get("RUN_AS_HOME", ""))
        if not home.is_absolute():
            return
        for path in (home / ".config", home / ".config/ovos-installer"):
            if path.is_symlink() or not path.is_dir():
                return
        token_path = home / ".config/ovos-installer/status-token"
        fd = os.open(token_path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
        with os.fdopen(fd, "r", encoding="ascii") as token_file:
            info = os.fstat(token_file.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
                return
            token = token_file.read(66)
        if not re.fullmatch(r"[0-9a-f]{64}\n?", token):
            return
        config = (
            'url = "https://start-api.smartgic.io/v1/events"\n'
            'request = "POST"\n'
            f'header = "Authorization: Bearer {token.rstrip()}"\n'
            'header = "Content-Type: application/json"\n'
            f'data = "{{\\"event\\":\\"{event}\\"}}"\n'
        )
        subprocess.run(
            ["curl", "-q", "--config", "-", "--proto", "=https",
             "--connect-timeout", "2", "--max-time", "3", "--silent",
             "--fail", "--output", "/dev/null"],
            input=config, text=True, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, timeout=4, check=False,
        )
    except (OSError, UnicodeError, subprocess.SubprocessError):
        # Reporting cannot change installation or print a token-bearing exception.
        pass


class CallbackModule(CallbackBase):
    """A notification callback which never overrides Ansible's terminal output."""

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "notification"
    CALLBACK_NAME = "ovos_start_progress"
    CALLBACK_NEEDS_ENABLED = True

    def __init__(self, *args: object, **kwargs: object) -> None:
        """Start with no confirmed phase; each phase is attempted at most once."""
        super().__init__(*args, **kwargs)
        self.phase = 0
        self.completed: set[str] = set()
        self.sound_pending = False
        self.sound_failed = False

    def completion(self, result: object, role: str) -> None:
        """Confirm known successful checkpoints, never partial or simulated loops."""
        task, data = result._task, result._result
        if task.check_mode or data.get("failed") or data.get("skipped") or data.get("rc", 0) != 0:
            return
        items = data.get("results", [data])
        if (not isinstance(items, list) or not items
                or any(not isinstance(item, dict) or item.get("failed") or item.get("rc", 0) != 0 for item in items)
                or all(item.get("skipped") for item in items)):
            return
        path = Path(task.get_path().rsplit(":", 1)[0])
        if path.parts[-4:-1] != ("roles", role, "tasks"):
            return
        event = CHECKPOINTS.get((role, path.name, task.name))
        if not self.sound_failed and (role, path.name, task.name) == ("ovos_sound", "install.yml", "Resolve ALSA default backend for .asoundrc"):
            self.sound_pending = True
        if role == "ovos_timezone" and self.sound_pending:
            event, self.sound_pending = "audio_configured", False
        if event and event not in self.completed:
            self.completed.add(event)
            report_phase(event)

    def v2_runner_on_failed(self, result: object, ignore_errors: bool = False) -> None:
        """An ignored sound failure must not become an audio-configuration receipt."""
        try:
            if result._task._role.get_name() == "ovos_sound":
                self.sound_pending = False
                self.sound_failed = True
        except (AttributeError, TypeError):
            pass

    def v2_runner_on_ok(self, result: object) -> None:
        """Advance coarse phases and confirm allowlisted task completion receipts."""
        try:
            metadata = result._task._role
            role = metadata.get_name() if metadata else ""
            phase = PHASES.get(role, 0)
            if phase > self.phase:
                self.phase = phase
                report_phase(EVENTS[phase])
            self.completion(result, role)
        except (AttributeError, TypeError):
            # Unknown upstream metadata means less detail, never guessed progress.
            pass
