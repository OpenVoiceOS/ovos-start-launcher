Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Introduce the tested versioned compact-code launcher and GitHub Pages publication.

# Launcher developer guide

## Source map

| File | Functions / responsibility |
| --- | --- |
| [codec.mjs](../codec.mjs) | `encodeRecipeCode`, `decodeRecipeCode`, `checksum`: exact typed-field format and CRC-8 |
| [contract.json](../contract.json) | Frozen field order, widths, enums and golden vectors |
| [v1.sh](../v1.sh) | `take`, `scenario`, `fail`, `invalid`, `read_value`, `read_secret`, `restore_tty`, `cleanup_launcher`: decoding, checks, scenario and target install |
| [codec.test.mjs](../test/codec.test.mjs) | Wire format round trips and corrupt/reserved inputs |
| [test_launcher.py](../test/test_launcher.py) | Python `Sandbox`, `run_launcher` and `run_interactive` fixture helpers and PTY tests; fake installer commands only |
| [pages.yml](../.github/workflows/pages.yml) | Tests then minimal GitHub Pages artifact |

No production Python classes or OVOS plugin entry points exist. The caller is the OVOS Start wizard, whose `buildShortCommand` and `readSetupFragment` use this codec and whose `validateState` applies matching compatibility rules. [OVOS installer documentation](https://github.com/OpenVoiceOS/ovos-installer/tree/main/docs) remains authoritative for actual target support.

## Protocol

The 40-bit word is `[version:4][payload:28][CRC-8:8]`, big-endian. CRC-8/SMBUS uses polynomial 0x07, init 0, non-reflected, xorout 0 over the first four bytes. Encode as eight Crockford Base32 characters with a visual middle hyphen. Lowercase and ungrouped input are accepted; whitespace and ambiguous O/I/L aliases are rejected.

The checksum detects typing errors, not malicious changes. Decode known enums as data, then reject incompatible combinations. Never eval code content. Version 1 field meanings are immutable.

## Installer contract

All installs require 64-bit userland, a regular user, and the correct Linux/macOS target. Windows recipes run in Ubuntu/WSL2. Dependencies and existing checkouts are checked before downloading installer sources. The launcher creates private temporary files and scenario backups.

Explicit public/local speech fetches and verifies commit `6ffd465028bac299e5235d619819bfdc734af073` from [preview PR #648](https://github.com/OpenVoiceOS/ovos-installer/pull/648), resolves Bash 4+, then calls `setup.sh` with `RUN_AS`, `RUN_AS_HOME` and `LOCALE`. Default speech downloads the upstream main bootstrap. The initial pin is deliberate; evolving PR heads do not silently change this launcher.

Credentials are read only on `/dev/tty` and exported to the target installer. A cancelled/failed secret read restores terminal echo. No secret is encoded in the code or URL. See [audit](../AUDIT.md) for runtime and test limits.
