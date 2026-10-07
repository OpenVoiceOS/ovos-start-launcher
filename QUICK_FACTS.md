Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Introduce the tested versioned compact-code launcher and GitHub Pages publication.

# Quick facts

| Field | Value |
| --- | --- |
| Package / version | `ovos-start-launcher` / `1.0.0`; `package.json` |
| License | Apache-2.0 |
| Entry points | POSIX shell `v1.sh CODE`; ES module `encodeRecipeCode`, `decodeRecipeCode`; no Python plugin entry points |
| Runtime dependencies | 64-bit userland, POSIX sh, getconf, tr, curl, git, sudo; upstream platform prerequisites still apply |
| Protocol | 40-bit wire word: 4 version bits, 28 choice bits, 8 CRC bits; 8 Crockford Base32 characters, grouped XXXX-XXXX |
| Code data | All 15 fixed enum/boolean wizard fields; no credentials, arbitrary text or executable payload |
| Hosting | GitHub Pages, `dev` workflow; only index.html and v1.sh |
| Preview pin | `6ffd465028bac299e5235d619819bfdc734af073` for explicit speech |
| Default speech | Existing upstream main installer.sh bootstrap |
| Preflight | 64-bit, valid code, compatible choices, nonroot user, correct OS, dependencies, protected existing checkout |
| Secrets | Masked target /dev/tty prompts; no code/URL secrets |
| Validation | 30 Node + 83 Python tests pass; sh -n passes; mock installers only |

See [source map](docs/index.md) and [audit](AUDIT.md).
