Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Harden launcher activation, failure propagation, recovery and bounded health checks in 2.1.1. Preserve probe input under dash.

# Maintenance report

## 2026-10-07 — Version 2.1.1

Replaced the error-swallowing main bootstrap with direct setup execution from a private Git checkout; retained main/PR648 selection and preview SHA. Added exact-path guards, private backups, per-account launcher locking, delayed checker activation and HUP cleanup. Privileged cleanup cannot replace the install exit status. Added localized interrupted-lock guidance, noninteractive low-speed-bounded Git fetching, bounded service/audio probes, strict Docker running-state checks and guaranteed MessageBus cleanup. Expanded CI to Ubuntu/macOS and ShellCheck. Wizard integration updates the immutable launcher URL and adds connection/total limits to its initial curl.

Verification: 38 Node tests passed. 524 Python cases passed. Added64 storage/concurrency cases and14 runtime cases, plus main/preview failure and cleanup regressions. All network, installer, privilege and service commands used by tests are local fakes. ShellCheck, shell syntax, generated-source parity and diff whitespace checks pass; v2 remains below120,000bytes. Independent shell/message matrices passed. Physical-device acceptance remains outstanding.

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
