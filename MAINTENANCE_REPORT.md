Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Retire the duplicate v1.sh endpoint and publish only v2.sh.

# Maintenance report

## 2026-10-07 — Version 2.3.1: v2-only launcher publication

Removed the duplicate `v1.sh` as explicitly requested. [`scripts/build-launcher.py`](scripts/build-launcher.py#L11) now emits only `v2.sh`, and [Pages CI](.github/workflows/pages.yml) checks its reproducibility, rejects a reintroduced `v1.sh`, tests it on Linux/macOS and packages only `v2.sh`, `index.html` and `.nojekyll`. The [sandbox fixture](test/test_launcher.py#L139) runs each case against the one supported entry point. The generated `v2.sh` bytes are unchanged, so existing immutable wizard/relay URLs continue working; code expiry and callbacks are unchanged.

Verification: **370 Python tests and 38 Node tests passed**. `sh -n`, `bash --posix -n`, ShellCheck and `git diff --check` passed. [`test_build_cli_emits_only_v2`](test/test_launcher.py#L825) executes the actual builder in a clean temporary tree and proves it creates only the expected script. [`test_generated_launcher_matches_sources`](test/test_launcher.py#L814) also checks that the retired file is absent. The lower Python count removes duplicate executions against the identical old entry point, while retaining behavioral cases and the newly merged umask regression. Tests use isolated fake installers; no real OVOS installation was run.

### Transparency Report

- **AI Model:** GPT-6.
- **Actions Taken:** Removed the duplicate launcher; updated build, publication workflow, test fixture and generation regressions; refreshed repository and workspace documentation. A read-only review checked sibling runtime dependencies.
- **Oversight:** The user explicitly requested removal after the duplicate was identified. Existing upstream changes were fast-forwarded first and preserved. Automated local validation completed before publication.


## 2026-10-07 — Version 2.3.0

Added a generated Ansible notification callback for tracked installation runs. Successful role tasks advance through the four fixed `stage_system`, `stage_packages`, `stage_services` and `stage_finalize` enums. Skips, failed tasks, native terminal output, role handlers returning to an earlier phase and timing cannot fabricate progress. Each phase gets at most one bounded callback attempt; failures never change the installer result. Existing zero-exit success, service health, voice confirmation, one-hour code expiry, private staging and scoped installer umask remain unchanged.

The plugin is embedded in the launcher and staged only in its temporary checkout. It preserves callback search paths and an explicit enabled-callback list, or retains upstream’s `ansible.posix.profile_tasks` default. The bearer is read from the existing private token file and never exported or placed in curl arguments. Added 31 meaningful cases, including harmless real Ansible plays for both methods, branch skips, a failed package role, callback failures, native callback preservation and private token checks. CI now installs Ansible-core 2.17 alongside pytest for those integration fixtures.

Verification: 31 targeted cases pass under Ansible-core 2.17 and 2.20; 38 Node tests pass. Shell syntax, Bash POSIX syntax, generated parity, ShellCheck and whitespace checks pass. v2 is 116,582 bytes, below 120,000. The complete Python regression suite passes all 687 cases. Tests use fake curl, installer and privilege tools; the real Ansible fixtures execute only harmless assertion/failure tasks. No commit, push or publication is performed by this delegated agent.

### Transparency Report

- **AI Model:** GPT-6 (Codex).
- **Actions Taken:** Inspected pinned upstream role ordering and Ansible callback semantics, implemented the fixed phase emitter, added callback/transport/integration regressions, regenerated launcher entry points and updated repository documentation and CI.
- **Oversight:** The user requested clear installation steps. The coordinating agent defined the monotonic relay phase contract, reviews this implementation, and owns UI/relay integration plus publication. Tests establish callback mechanics and failure handling; physical-device acceptance remains outstanding.

## 2026-10-07 — Version 2.2.1

Corrected a reproduced launcher permission defect affecting Ansible tasks that run as the normal user. The installer child now uses `umask022`, while private launcher staging stays077. Before setup, a cached installer venv is moved to a unique private sibling backup after nonsymlink/type checks; retries therefore rebuild inaccessible tooling without deleting existing contents or changing permissions across the home directory. Added a localized backup-path notice in all 12 catalogs and regenerated both public entry points. Failure/signal reporting and zero-exit completion gating are unchanged.

Verification: **656 pytest cases and 38 Node tests pass**. Eighteen new cases cover real fresh/cached Python venv permissions, preserved private state/application files, unsafe runtime paths and a cached-runtime exit 126 that reports failure with no success receipt. The original permission regression failed for both entry points before the fix and passes afterward. Shell syntax, generated parity, ShellCheck and whitespace checks pass. v2 is 112,503 bytes, below 120,000. No real installer, sudo operation or physical MarkII verification was performed. No commit/push/publication was performed by this delegated agent.

### Transparency Report

- **AI Model:** GPT-6 (Codex).
- **Actions Taken:** Traced the pinned upstream Python-venv and Ansible task code, reproduced the mask defect with real local Python venvs, implemented scoped permissions and preserved-runtime recovery, authored 18 regression cases, regenerated assets and updated repository documentation.
- **Oversight:** The user reported a failed installation and misleading browser status. The coordinating agent reviewed the recovery scope, required preserved backups instead of broad cache cleanup, and owns wizard/relay evidence plus publication. Network/install/privilege/service operations in automated tests are local fakes; human hardware acceptance remains outstanding.


## 2026-10-07 — Version 2.2.0

Added optional `CODE --track TOKEN` progress callbacks without changing the recipe codec or its one-hour deadline. The generated launchers send only fixed event names to a fixed HTTPS relay using a separate write capability. Added private delayed token activation, durable checker callbacks after restart, strict input/path guards, disabled curlrc loading, bounded transport and exact failure/signal preservation. Plain and read-only execution remain callback-free. Documented the command-history limitation and the separation between installer completion, running services and human-confirmed voice response.

Coordinating-agent review added a private success receipt, bound to the current token and written only after zero installer exit, so a later checker can recover a dropped completion event. Added generic reporting for validated preflight rejection while suppressing duplicate-lock events to protect an active browser session. Early architecture/invalid/expired-code gates remain callback-free. Receipt write errors never alter an actual successful installer result.

Verification: **638 pytest cases and 38 Node cases pass**, including 114 new callback cases. POSIX/Bash syntax, generated parity, diff checks and ShellCheck 0.11/0.9 pass. Generated v2 is 110,196 bytes, below 120,000. No real installer, administrator escalation, network callback or physical microphone/speaker operation was performed. Coordinating-agent relay/browser integration and live deployment verification remain separate.

### Transparency Report

- **AI Model:** GPT-6 (Codex).
- **Actions Taken:** Implemented callback transport, launcher/runtime hooks, private token persistence, generated artifacts, regression/PTY/signal tests, CI coverage and documentation.
- **Oversight:** The user explicitly requested webhook-based installation progress. The coordinating agent specified the relay contract and owns server/UI integration, review and publication. Tests substituted local fakes for every network/installer/service operation; human hardware testing remains outstanding.

## 2026-10-07 — Version 2.1.1

Replaced the error-swallowing main bootstrap with direct setup execution from a private Git checkout; retained main/PR648 selection and preview SHA. Added exact-path guards, private backups, per-account launcher locking, delayed checker activation and HUP cleanup. Privileged cleanup cannot replace the install exit status. Added localized interrupted-lock guidance, noninteractive low-speed-bounded Git fetching, bounded service/audio probes, strict Docker running-state checks and guaranteed MessageBus cleanup. Expanded CI to Ubuntu/macOS and ShellCheck. Wizard integration updates the immutable launcher URL and adds connection/total limits to its initial curl.

Verification: 38 Node tests passed. 524 Python cases passed. Added64 storage/concurrency cases and14 runtime cases, plus main/preview failure and cleanup regressions. All network, installer, privilege and service commands used by tests are local fakes. ShellCheck, shell syntax, generated-source parity and diff whitespace checks pass; v2 remains below 120,000bytes. Independent shell/message matrices passed. Physical-device acceptance remains outstanding.

### Transparency Report

- **AI Model:** Codex, GPT-6.
- **Actions Taken:** Reviewed launcher/build/protocol sources; delegated independent security/runtime/portability reviews; reproduced failure modes; implemented fixes, regression tests, CI and documentation; integrated the hardened release into the wizard.
- **Oversight:** User requested hardening. The coordinating agent reviewed delegated changes and verification evidence. No OVOS installation, real administrator escalation, microphone test or credential collection was performed.

## 2026-10-07 — Version 2.1.0

Implemented 12-locale terminal messages, field-specific retries, literal credential forwarding, strict common HTTP(S) syntax checks, cancellation, four real install stages and a durable private verification helper. Added systemd/launchd/Compose checks, optional real MessageBus sound output and explicit human confirmation of a supported voice response. Zero installer exit and active services do not mark speech complete. All Mac routes now share the tested Intel/Apple Silicon PR648 pin while retaining upstream-selected speech when `speech=auto`.

Generated both public scripts from [`lib/launcher.sh.in`](lib/launcher.sh.in), [`lib/runtime.sh`](lib/runtime.sh) and [`locales/messages.json`](locales/messages.json) using Python [`build`](scripts/build-launcher.py#L11). Sources contain no runtime language fetch. The chosen catalog alone is embedded in the helper so the downloaded script remains within the one-line command's shell argument limit. During verification, corrected an early prompt/terminal-echo race and duplicate catalog size before release.

Verification: **436 pytest cases and 38 Node tests pass**, shell syntax/parity and ShellCheck pass (existing cosmetic SC1112 excluded). New tests cover all-language retries and expiry, invalid URL recovery, cancellation, retained backups, durable read-only checks, emitted sound metadata and human confirmation. All installers, network clients, privilege tools, service managers and message transport are local fakes. Exact pinned upstream service definitions and Mac support documentation were read; current Compose names were verified against upstream source.

### Transparency Report

- **AI Model:** Codex, GPT-6.
- **Actions Taken:** Implemented launcher/runtime/catalogs and generated artifacts, authored regression and PTY tests, inspected upstream contracts, wrote documentation, and prepared the release for coordinating-agent publication.
- **Oversight:** User explicitly requested implementation of all audit recommendations. The coordinating agent owns wizard UX and release integration and approved pinning default Mac installation to the reviewed support contract. No real OVOS installation, microphone recording or user-service mutation occurred. Human hardware and native-language review remain pending.

## 2026-10-07 — Version 2.0.0

Added a forty-bit Unix issuance timestamp to the unchanged version/payload header, producing an 80-bit code with 16 Base32 characters. The deadline is exactly issuance plus 3,600 seconds. `decodeRecipeCode` and `decodeRecipeEnvelope` reject legacy, expired, future-dated and invalid-clock inputs by default. Explicit `allowLegacy` and `allowExpired` options recover choices without making those codes executable; future timestamps and invalid clocks still fail.

Added `v2.sh` and replaced the `v1.sh` entry point with identical v2 validation. Both scripts check freshness before installer fetches, temporary/configuration writes or privileged execution. Byte-at-a-time decoding avoids putting the 80-bit wire word into shell arithmetic. Preserved the frozen v1 schema in `contract-v1.json` and updated `contract.json` with v2 layout, expiry rules and five deterministic vectors. The publication workflow now compares both shell files and packages both endpoints with the landing page.

Verification completed before this documentation update: **38 Node tests and 350 pytest cases passed**. [codec.test.mjs](test/codec.test.mjs) covers all typed values, five vectors, all 496 one-character substitutions, all 80 single-bit changes, reserved/version errors, full forty-bit timestamps, default clock behavior and explicit recovery. Python [test_launcher.py](test/test_launcher.py) exercises both endpoints using `Sandbox`, `run_launcher` and `run_interactive`: deadline minus one/exact/plus one, future time, malformed/missing/failed clocks, v1 refusal in every mode, state preservation, source pinning and literal masked TTY credentials. `sh -n` passed for both scripts, `cmp v1.sh v2.sh` passed, and `git diff --check` passed. ShellCheck passed with the existing cosmetic Unicode-apostrophe warning SC1112 excluded. No real installer or hardware operation was run.

Documented that expiry relies on browser/target clocks and public editable timestamps. CRC-8 is not authentication; the format has no per-code server storage, signature, individual revocation or single-use enforcement. Existing limits around actual hardware validation and the upstream main bootstrap remain in [AUDIT.md](AUDIT.md).

### Transparency Report

- **AI Model:** Codex, GPT-6.
- **Actions Taken:** Implemented the timestamped codec and both shell entry points, preserved the legacy contract, added codec tests, delegated independent Python reference vectors and launcher tests, and updated this repository's documentation. The coordinating agent updated the Pages workflow and landing-page copy.
- **Oversight:** The user required one-hour expiry. The coordinating agent approved the wire layout and API; separate agents implemented and reviewed the JavaScript/shell and Python verification. All installer/network/privileged actions in tests used local fakes. Human acceptance on physical targets remains pending. This documentation task did not publish or push changes.

## 2026-10-07 — Version 1.0.0

Implemented a frozen 40-bit recipe codec and POSIX shell launcher. The launcher decodes and validates all choices, preserves the experimental speech pin, backs up scenarios and prompts for credentials only on the target TTY. The one-line bootstrap executes only after a complete successful download. GitHub Actions checks code/tests before publishing the two public assets to Pages.

Verification: **30 Node and 83 pytest tests pass**. Tests cover enum round trips, corruption, version errors, invalid combinations, 64-bit/user/OS/checkouts, failed fetches and pin mismatches, scenario backups, locale/features, guarded Bash resolution and real PTY secret masking. `sh -n` passes. No real OVOS installation was performed.

### Transparency Report

- **AI Model:** Codex, GPT-6.
- **Actions Taken:** Implemented launcher, codec, tests and hosting workflow; reviewed contract and failure handling; wrote documentation.
- **Oversight:** User explicitly approved the self-contained setup-code approach with GitHub Pages. Separate agents implemented/reviewed the codec and shell tests. Human hardware acceptance remains pending.


CI caught a dash-specific background-stdin difference after the local Bash checks passed. `run_bounded` now duplicates the original input on descriptor3 before starting its child, preserving the Python audio heredoc on Ubuntu. The existing literal-input and real sound-transport regressions caught this; publication remains gated on both CI jobs.

CI portability follow-up: all524 Ubuntu cases now pass; explicit validation branches and narrowly scoped trap annotations also support the older CI ShellCheck. The previous macOS suite passed524 cases. The final publication workflow rechecks both platforms.
