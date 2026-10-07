"""Exercise bounded service probes with local processes and no OVOS installation."""
from __future__ import annotations

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

import pytest

ROOT = Path(__file__).resolve().parents[1]
SHELLS = ("/bin/sh", "/bin/bash")


def run_runtime(tmp_path: Path, source: str, *, shell: str = "/bin/sh",
                input_text: str = "", changes: dict[str, str] | None = None,
                timeout: float = 8) -> subprocess.CompletedProcess[str]:
    """Source production helpers in an isolated home with only explicit commands."""
    environment = {"HOME": str(tmp_path), "PATH": "/usr/bin:/bin", "LC_ALL": "C",
                   **(changes or {})}
    return subprocess.run(
        [shell, "-c", 'set -eu; . "$2"; . "$1"; ' + source, "runtime",
         str(ROOT / "lib/runtime.sh"), str(ROOT / "lib/callback.sh")],
        cwd=tmp_path, env=environment, input=input_text, capture_output=True,
        text=True, timeout=timeout,
    )


@pytest.mark.parametrize("shell", SHELLS)
def test_failed_terminal_restore_does_not_override_failure_or_stop_cleanup(
    tmp_path: Path, shell: str
) -> None:
    """Losing /dev/tty during cancellation still runs cleanup and retains exit status."""
    result = run_runtime(tmp_path, 'ovos_tty=unavailable; restore_tty; printf cleanup; exit 23', shell=shell)
    assert result.returncode == 23
    assert result.stdout == "cleanup"


@pytest.mark.parametrize("shell", SHELLS)
def test_bounded_command_preserves_stdin_output_status_and_cancels_timer(
    tmp_path: Path, shell: str
) -> None:
    """Background probes retain heredoc input and do not wait for an unused watchdog."""
    started = time.monotonic()
    result = run_runtime(
        tmp_path, "run_bounded 30 /bin/sh -c 'IFS= read -r line; printf \"%s\" \"$line\"; exit 23'",
        shell=shell, input_text="literal $input ' with spaces\n", timeout=3,
    )
    assert result.returncode == 23
    assert result.stdout == "literal $input ' with spaces"
    assert time.monotonic() - started < 3


@pytest.mark.parametrize("shell", SHELLS)
@pytest.mark.parametrize("ignore_term", (False, True))
def test_bounded_command_stops_stalled_processes_and_reaps_them(
    tmp_path: Path, shell: str, ignore_term: bool
) -> None:
    """A hung local/remote probe is terminated, then killed if TERM is ignored."""
    worker = tmp_path / "stalled.py"
    worker.write_text(
        "import os, signal, time\n"
        + ("signal.signal(signal.SIGTERM, signal.SIG_IGN)\n" if ignore_term else "")
        + "print(os.getpid(), flush=True)\ntime.sleep(60)\n",
        encoding="utf-8",
    )
    started = time.monotonic()
    result = run_runtime(tmp_path, 'run_bounded 1 "$PYTHON" "$WORKER"', shell=shell,
                         changes={"PYTHON": sys.executable, "WORKER": str(worker)})
    assert result.returncode == (137 if ignore_term else 143)
    assert time.monotonic() - started < 6
    with pytest.raises(ProcessLookupError):
        os.kill(int(result.stdout.strip()), 0)


@pytest.mark.parametrize("shell", SHELLS)
def test_bounded_command_reaps_worker_when_checker_is_interrupted(tmp_path: Path, shell: str) -> None:
    """Closing the checker while a probe hangs does not leave its child behind."""
    pid_file = tmp_path / "worker.pid"
    worker = tmp_path / "worker.py"
    worker.write_text(
        "import os, pathlib, signal, time\n"
        "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
        "pathlib.Path(os.environ['PID_FILE']).write_text(str(os.getpid()))\n"
        "time.sleep(60)\n",
        encoding="utf-8",
    )
    process = subprocess.Popen(
        [shell, "-c", '. "$1"; run_bounded 30 "$2" "$3"', "runtime",
         str(ROOT / "lib/runtime.sh"), sys.executable, str(worker)],
        cwd=tmp_path, env={"PATH": "/usr/bin:/bin", "PID_FILE": str(pid_file)},
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
    )
    deadline = time.monotonic() + 3
    try:
        while not pid_file.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        assert pid_file.exists()
        os.killpg(process.pid, signal.SIGTERM)
        process.communicate(timeout=3)
        with pytest.raises(ProcessLookupError):
            os.kill(int(pid_file.read_text()), 0)
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()


@pytest.mark.parametrize("state", ("running", "restarting", "paused"))
def test_container_health_requires_running_status_in_the_ovos_project(tmp_path: Path, state: str) -> None:
    """Crash-looping or paused containers cannot satisfy the service-running check."""
    binary = tmp_path / "bin"
    binary.mkdir()
    docker = binary / "docker"
    docker.write_text(
        f"#!{sys.executable}\n"
        "import json, os, pathlib, sys\n"
        "pathlib.Path(os.environ['HOME'], 'args.json').write_text(json.dumps(sys.argv[1:]))\n"
        "print('ovos_messagebus\\novos_core\\novos_listener')\n"
        "if os.environ['STATE'] == 'running' or 'status=running' not in sys.argv: print('ovos_audio')\n",
        encoding="utf-8",
    )
    docker.chmod(0o700)
    result = run_runtime(
        tmp_path, "say() { printf '%s\\n' \"$1\"; }; ovos_experience=ready; ovos_method=containers; check_services",
        changes={"PATH": f"{binary}:/usr/bin:/bin", "STATE": state},
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == ("servicesOk" if state == "running" else "servicesMissing")
    assert "label=com.docker.compose.project=ovos" in json.loads((tmp_path / "args.json").read_text())


def test_sound_transport_failure_still_closes_client(tmp_path: Path) -> None:
    """A bus exception releases the connection before the shell offers manual recovery."""
    binary = tmp_path / ".venvs/ovos/bin"
    binary.mkdir(parents=True)
    (binary / "python3").symlink_to(sys.executable)
    module = tmp_path / "ovos_bus_client.py"
    module.write_text(
        "import os\nfrom pathlib import Path\n"
        "class Message:\n    def __init__(self, *args): pass\n"
        "class Connected:\n    def wait(self, seconds): return True\n"
        "class MessageBusClient:\n"
        "    def __init__(self): self.connected_event = Connected()\n"
        "    def on(self, *args): pass\n"
        "    def run_in_thread(self): pass\n"
        "    def emit(self, message): raise RuntimeError('fixture transport failure')\n"
        "    def close(self): Path(os.environ['HOME'], 'closed').touch()\n",
        encoding="utf-8",
    )
    result = run_runtime(
        tmp_path, "message() { printf test; }; ovos_locale=en-us; ovos_method=virtualenv; sound_check",
        changes={"PYTHONPATH": str(tmp_path)},
    )
    assert result.returncode == 1, result.stderr
    assert (tmp_path / "closed").exists()
