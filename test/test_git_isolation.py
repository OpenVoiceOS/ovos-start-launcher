"""Use real local Git to prove inherited context cannot redirect installation."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest

from test_launcher import Sandbox, raw_code, run_launcher, sandbox


def repository_snapshot(repository: Path) -> dict[str, bytes]:
    """Capture working files, refs, objects and index without invoking Git."""
    return {
        str(path.relative_to(repository)): path.read_bytes()
        for path in repository.rglob("*") if path.is_file()
    }


@pytest.mark.parametrize("context", [
    "repository", "index", "objects", "common-directory", "config-count",
    "config-parameters", "ref-context", "clean",
])
@pytest.mark.parametrize("upstream_state", ("current-main", "advanced-main", "tag-only"))
def test_inherited_git_context_cannot_modify_an_unrelated_repository(
    sandbox: Sandbox, context: str, upstream_state: str,
) -> None:
    """Fetch the real main branch in isolation; a main tag cannot substitute for it."""
    real_git = shutil.which("git")
    assert real_git is not None
    root = sandbox.home.parent
    user_config = root / "user.gitconfig"
    # Fixture commits must not start background maintenance: a transient lock
    # disappearing after the snapshot is not a mutation by the launcher.
    # Keep the snapshot strict so every unexpected repository change is caught.
    user_config.write_text(
        "[audit]\n\tmarker = preserve-user-settings\n"
        "[maintenance]\n\tauto = false\n"
        "[gc]\n\tauto = 0\n"
    )
    clean_env = {
        "PATH": os.pathsep.join((str(Path(real_git).parent), "/usr/bin", "/bin")),
        "HOME": str(sandbox.home), "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": str(user_config),
        "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
        "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
    }

    def git(repository: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
        """Operate only on local fixture repositories with a clean environment."""
        return subprocess.run(
            [real_git, "-C", str(repository), *arguments], env=clean_env,
            capture_output=True, text=True, check=True, timeout=10,
        )

    upstream = root / "local-upstream"
    upstream.mkdir()
    git(upstream, "init", "--quiet", "-b", "main")
    (upstream / "utils").mkdir()
    shutil.copyfile(sandbox.env["FAKE_RUNTIME_FILE"], upstream / "utils/bash_runtime.sh")
    (upstream / "setup.sh").write_text('#!/bin/sh\nexec "$FAKE_PYTHON" "$FAKE_RECORDER"\n')
    git(upstream, "add", ".")
    git(upstream, "commit", "--quiet", "-m", "Harmless fixture installer")
    # Same-name tags must never win over refs/heads/main, even when main is absent.
    git(upstream, "tag", "main")
    if upstream_state == "advanced-main":
        (upstream / "latest.txt").write_text("The next attempt must use this commit.\n")
        git(upstream, "add", ".")
        git(upstream, "commit", "--quiet", "-m", "Advance main beyond the tag")
    expected_commit = git(upstream, "rev-parse", "HEAD").stdout.strip()
    if upstream_state == "tag-only":
        git(upstream, "branch", "-m", "other")
        sandbox.seed_scenario()

    unrelated = root / "unrelated-repository"
    unrelated.mkdir()
    git(unrelated, "init", "--quiet", "-b", "main")
    (unrelated / "setup.sh").write_text("Preserve this unrelated tracked file.\n")
    git(unrelated, "add", ".")
    git(unrelated, "commit", "--quiet", "-m", "Unrelated original content")
    before = repository_snapshot(unrelated)
    original_config = user_config.read_bytes()

    # The sole production remote is redirected to a harmless local repository.
    # Every Git operation itself is real, including the installer's Git probes.
    wrapper = Path(sandbox.env["PATH"].split(os.pathsep)[0]) / "git"
    wrapper.write_text(
        f"#!{sys.executable}\nimport os, sys\n"
        f"args = [{str(upstream)!r} if value == "
        "'https://github.com/OpenVoiceOS/ovos-installer.git' "
        "else value for value in sys.argv[1:]]\n"
        f"os.execv({real_git!r}, [{real_git!r}, *args])\n"
    )
    recorder = Path(sandbox.env["FAKE_RECORDER"])
    recorder.write_text(
        "import json, os, pathlib, subprocess\n"
        "def git(*args):\n"
        "    return subprocess.check_output(['git', *args], text=True).strip()\n"
        "data = {'root': git('rev-parse', '--show-toplevel'), "
        "'commit': git('rev-parse', '--verify', 'HEAD^{commit}'), "
        "'git_dir': git('rev-parse', '--absolute-git-dir'), "
        "'marker': git('config', '--get', 'audit.marker'), "
        "'safe_config': os.environ.get('GIT_CONFIG_GLOBAL'), "
        "'safe_ca': os.environ.get('GIT_SSL_CAINFO'), "
        "'contexts': {key: value for key, value in os.environ.items() "
        "if key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', "
        "'GIT_OBJECT_DIRECTORY', 'GIT_COMMON_DIR', 'GIT_CONFIG_COUNT', "
        "'GIT_CONFIG_PARAMETERS', 'GIT_NAMESPACE', 'GIT_SHALLOW_FILE')}}\n"
        "pathlib.Path(os.environ['HOME'], 'git-probes.json').write_text(json.dumps(data))\n"
    )
    changes = {
        "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": str(user_config),
        "GIT_SSL_CAINFO": str(root / "preserved-certificate-setting.pem"),
    }
    if context == "repository":
        changes.update(GIT_DIR=str(unrelated / ".git"), GIT_WORK_TREE=str(unrelated))
    elif context == "index":
        changes["GIT_INDEX_FILE"] = str(unrelated / ".git/index")
    elif context == "objects":
        changes["GIT_OBJECT_DIRECTORY"] = str(unrelated / ".git/objects")
    elif context == "common-directory":
        changes["GIT_COMMON_DIR"] = str(unrelated / ".git")
    elif context == "config-count":
        changes.update(GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0="core.worktree", GIT_CONFIG_VALUE_0=str(unrelated))
    elif context == "config-parameters":
        changes["GIT_CONFIG_PARAMETERS"] = "'core.worktree=" + str(unrelated) + "'"
    elif context == "ref-context":
        changes.update(GIT_NAMESPACE="unrelated-namespace", GIT_SHALLOW_FILE=str(unrelated / "shallow-context"))

    result = run_launcher(sandbox, raw_code(), changes=changes)

    assert repository_snapshot(unrelated) == before
    assert user_config.read_bytes() == original_config
    if upstream_state == "tag-only":
        assert result.returncode != 0
        assert sandbox.scenario.read_text() == "original-user-settings\n"
        assert not list(sandbox.scenario.parent.glob("scenario.yaml.backup.*"))
        assert not (sandbox.home / "git-probes.json").exists()
        assert not list(sandbox.temp.iterdir())
        assert not (sandbox.scenario.parent / ".launcher-lock").exists()
        return
    assert result.returncode == 0, result.stdout + result.stderr
    probes = json.loads((sandbox.home / "git-probes.json").read_text())
    assert probes["commit"] == expected_commit
    private_root = Path(probes["root"])
    # The checkout has already been cleaned; compare resolved parent paths to
    # accommodate macOS's /var -> /private/var spelling without requiring it.
    assert private_root.parent.parent.resolve() == sandbox.temp.resolve()
    assert private_root.name == "source"
    assert Path(probes["git_dir"]) == private_root / ".git"
    assert probes["contexts"] == {}
    assert probes["marker"] == "preserve-user-settings"
    assert probes["safe_config"] == str(user_config)
    assert probes["safe_ca"] == changes["GIT_SSL_CAINFO"]
    assert not list(sandbox.temp.iterdir())
