Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Record version 2 expiry implementation, independent test evidence and AI transparency.

# Maintenance report

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
