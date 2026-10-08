Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Add actual Ansible installation phases in launcher 2.3.0.

# Suggestions

## Completed: actual installer substeps

**Problem:** One long installing state gave no view of completed and remaining work. **Implemented:** [CallbackModule](lib/ansible_progress.py) maps real successful Ansible role tasks to four fixed phase events, preserves the installer terminal output, and leaves completion gated on setup exit. **Impact:** The wizard can display device preparation, package installation, service setup and finalization without parsing logs or guessing from timers. [Real play fixtures](test/test_ansible_progress.py) cover skipped branches, errors and offline delivery.

## Keep the upstream phase contract checked

**Opportunity:** Main can add or rename roles beyond the reviewed preview pin. **Proposal:** During installer-pin updates, compare the role sequence with `PHASES` in [ansible_progress.py](lib/ansible_progress.py), and retain the real callback-discovery test against the installer’s Ansible-core version. **Impact:** Preserves useful detail while unknown roles safely remain unreported. Measured device-specific installation durations would also improve the wizard’s estimates; this launcher does not invent timing observations.

## Completed: separate private staging from user-accessible installer tools

**Problem:** Root-owned Python venv children inherited the launcher’s restrictive mask, preventing Ansible tasks running as the normal user from executing Python. Cached tool reuse retained that failure on a retry. **Implemented:** Scope `umask022` to the setup child and preserve only the old installer runtime in a private sibling backup before rebuilding it. Configuration, tokens and application venvs retain their permissions. **Impact:** Fresh installs and retries receive usable tooling without broad permission changes. Evidence: [`test_installer_venv_is_accessible_without_exposing_launcher_secrets`](test/test_storage_hardening.py#L144) and [`test_failed_runtime_retry_preserves_backup_and_reports_only_failure`](test/test_callbacks.py#L103).

## Narrow upstream shared-cache cleanup

**Problem:** The pinned installer still removes hard-coded `/root/.ansible` after successful setup and when rebuilding a nonreusable venv. **Proposal:** Upstream can isolate its collections/cache in an installer-specific directory and restrict cleanup to that directory. **Impact:** Avoids affecting unrelated Ansible content. The launcher does not force the broad cache-refresh option; its new recovery moves only `~/.venvs/ovos-installer`. Source: [pinned setup cleanup](https://github.com/OpenVoiceOS/ovos-installer/blob/6ffd465028bac299e5235d619819bfdc734af073/setup.sh#L319).

## Completed: optional browser progress

**Problem:** The browser could not tell installation from successful voice setup. **Implemented:** Separate status-write capabilities, minimal fixed events, private restart recovery, bounded best-effort HTTPS callbacks and human-confirmed voice completion. **Impact:** The wizard can show meaningful progress without collecting logs or blocking an install when the browser/relay is unavailable. Evidence: [`test_callbacks.py`](test/test_callbacks.py) and [callback audit](AUDIT.md#2026-10-07--version-220-callback-audit).

## Exercise relay interruptions on real hardware

**Remaining opportunity:** Mock transport tests cannot prove reboots, offline periods and proxy behavior in a real household. **Proposal:** Validate an actual Pi installation with the relay temporarily unreachable, a reboot before voice confirmation, and later `check-setup.sh` recovery in the selected language. Confirm the browser never treats missing status as proof of success or failure. **Impact:** Verifies the complete device-to-browser contract while retaining installation independence from tracking.

## Completed: reliable activation and failure handling

**Problem:** The main bootstrap hid failures; ambiguous destination paths, concurrent launches and stalled service tools could break recovery. **Implemented:** Direct setup execution, exact-path validation, private backups, per-account locking, delayed checker replacement, bounded probes and Linux/macOS CI. **Impact:** Failures remain visible, competing launchers preserve settings, and health checks return instead of waiting indefinitely. [Audit evidence](AUDIT.md#2026-10-07--version-211-reliability-audit).

## Keep interrupted-lock recovery deliberate

**Problem:** An uncatchable interruption can retain the launcher lock. **Proposal:** Keep the explicit inactive-process check and `rmdir` recovery documented; add automatic stale-lock recovery only with a portable process/boot identity design and race tests. **Impact:** Prevents accidentally unlocking a still-running installation.

## Completed: recoverable terminal handoff

**Problem:** Missing fields exited silently and installation ended without verification. **Implemented:** Localized retry/cancel, common URL syntax validation, stage reporting, a durable service checker, optional sound output and explicit first-voice confirmation. **Impact:** Users can recover in place and distinguish copied/installed/running/actually heard states. Evidence: [`test_launcher.py`](test/test_launcher.py#L682), [`runtime.sh`](lib/runtime.sh).

## Hardware and native-language acceptance

**Remaining opportunity:** Mock tests do not prove every device or locale works in a real room. **Proposal:** Maintain physical Pi5, Intel/Apple Silicon Mac and WSL2 acceptance runs covering restart recovery, service scopes, audio output, wake word and one installed skill. Invite fluent reviewers for all terminal catalogs, especially smaller language communities. **Impact:** Detect environment and language issues that unit tests cannot establish; avoid claiming automatic completion based on service state alone.

## Preserve frozen data meanings while retiring old execution

**Opportunity:** Future options may need new enum values or fields. **Proposal:** Keep the existing field indexes immutable and introduce another protocol version for incompatible changes. Preserve [contract-v1.json](contract-v1.json) for choice recovery while keeping both public endpoints on the v2 expiry policy. Extend Python [raw_code](test/test_launcher.py#L191) and the cross-language golden-vector tests for future versions. **Impact:** Old choices remain interpretable without allowing timeless installation codes.

## Add trusted expiry only if the product later needs authorization

**Problem:** Public timestamps and local clocks cannot provide tamper-resistant expiration or individual revocation. **Proposal:** If a future requirement needs those properties, design an authenticated service or signature-verification protocol with a trusted clock and explicit threat model; do not treat CRC-8 as protection. Keep the current service-free format for ordinary setup freshness. **Impact:** Stronger guarantees would add infrastructure and maintenance costs; no such system is needed for the current public recipe data. Evidence: [expiry audit](AUDIT.md) and [timestamp boundary tests](test/test_launcher.py#L309).

## Adopt an OVOS-owned short domain

**Opportunity:** The initial launcher uses the goldyfruit GitHub Pages address. **Proposal:** Project maintainers can later point a short project-owned hostname at the reviewed launcher. **Impact:** Shorter terminal commands and clearer project ownership, without changing code contents.

## Further endpoint connectivity checks upstream

**Problem:** Local syntax validation cannot establish DNS, TLS, authentication or endpoint compatibility. **Proposal:** Validate service connectivity in the installer before committing integration configuration. **Impact:** Better target-device errors without adding questions to the wizard.


CI caught a dash-specific background-stdin difference after the local Bash checks passed. `run_bounded` now duplicates the original input on descriptor3 before starting its child, preserving the Python audio heredoc on Ubuntu. The existing literal-input and real sound-transport regressions caught this; publication remains gated on both CI jobs.

CI portability follow-up: all524 Ubuntu cases now pass; explicit validation branches and narrowly scoped trap annotations also support the older CI ShellCheck. The previous macOS suite passed524 cases. The final publication workflow rechecks both platforms.
