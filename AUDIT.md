Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Introduce the tested versioned compact-code launcher and GitHub Pages publication.

# Audit

## 2026-10-07 — Initial compact launcher

Evidence: **30 Node tests and 83 pytest cases pass**, plus `sh -n v1.sh`. Tests never invoke real network installers. Manual review compared `scenario` and all shell compatibility conditions with the wizard contract.

- **Verified code validation:** [codec.test.mjs](test/codec.test.mjs) covers golden vectors, every field value, reserved enum indexes, unsupported versions and all 248 single-character substitutions of the baseline code. [test_launcher.py](test/test_launcher.py) compares Node codes with the actual shell decoder and scenario output.
- **Verified installation guards:** The Python tests use fake curl/git/sudo, reject 32-bit/root/wrong-OS/existing-checkout paths, preserve existing scenario data across failed downloads or SHA mismatches, and check backups, locale and feature flags.
- **Fixed during review:** `resolve_bash_runtime 4` now runs in a guarded substitution before scenario replacement. Tests cover a missing first candidate and unavailable Bash. This avoids premature `set -e` exits on Intel Mac Homebrew layouts.
- **Verified credential handling:** Real PTY tests feed literal metacharacters to Home Assistant and LLM prompts. Secrets are not echoed or interpreted as shell code.
- **Known inherited limitation:** The default upstream main bootstrap can return zero after setup.sh fails. The launcher deliberately prints no installation-success claim. Preview execution propagates setup status.
- **Known validation limit:** Integration endpoint validation checks an HTTP(S) prefix, not complete URL syntax or reachability. Malformed values may fail later in the installer. Quoted environment forwarding prevents shell evaluation.
- **Trust boundary:** GitHub Pages supplies executable launcher code over HTTPS. CRC-8 only detects code transcription errors; it is not a signature. Codes accept only known data values, never scripts or arbitrary URLs.
- **Coverage limit:** Mock tests do not demonstrate real installation success, physical audio behavior, or native macOS execution. Real hardware acceptance remains outstanding.
