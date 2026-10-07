Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Harden launcher activation, failure propagation, recovery and bounded health checks in 2.1.1.

# Quick facts

| Field | Value |
| --- | --- |
| Package / version | `ovos-start-launcher` / `2.1.1`; `package.json` |
| License | Apache-2.0 |
| Entry points | POSIX shell `v2.sh CODE`; `v1.sh` has identical v2 validation; ES module `encodeRecipeCode`, `decodeRecipeCode`, `decodeRecipeEnvelope`; no Python plugin entry points |
| Runtime dependencies | 64-bit userland, POSIX sh, getconf, tr, date with `+%s`, git, sudo (curl for the wizard bootstrap); upstream platform prerequisites still apply |
| Protocol | 80-bit word: version4 + choices28 + issuedAt40 + CRC8; 16 Crockford Base32 characters grouped XXXX-XXXX-XXXX-XXXX |
| Code data | All 15 frozen enum/boolean wizard fields plus Unix issuance seconds; no credentials, arbitrary text or executable payload |
| Checksum | CRC-8/SMBUS over nine big-endian bytes; polynomial 0x07, init/xorout 0, no reflection; not authentication |
| Lifetime | `RECIPE_TTL_SECONDS = 3600`; valid only when `0 < issuedAt <= now < issuedAt + 3600`; exact deadline rejected |
| Clock bounds | Integer Unix seconds 1–1099511627775; target `date +%s`; invalid/unavailable clocks and future codes rejected |
| Legacy handling | Eight-character v1 refused by both shell endpoints; explicit JS `allowLegacy` restores choices only |
| Expired recovery | Explicit JS `allowExpired` restores expired v2 choices; future codes, bad clocks and malformed data still rejected |
| Protocol records | `contract.json` is v2; `contract-v1.json` preserves the old layout and vectors |
| Hosting | GitHub Pages, `dev` workflow; only index.html, v1.sh, v2.sh and .nojekyll |
| Preview pin | `6ffd465028bac299e5235d619819bfdc734af073` for explicit speech |
| Default speech | Mac uses reviewed pin with no speech override; other devices fetch main and invoke setup.sh directly |
| Preflight | 64-bit, format/checksum/version/time, compatible choices, nonroot user, correct OS, dependencies, protected existing checkout; freshness checked before side effects |
| Secrets | Masked target /dev/tty prompts; no code/URL secrets |
| Validation | 38 Node + 524 Python tests pass; both scripts pass sh -n and compare identically; mock installers only |
| Python test API | [test/test_launcher.py](test/test_launcher.py): `Sandbox`, `raw_code`, `run_launcher`, `run_interactive`; no production Python classes |
| Security limit | Public, reproducible code and local-clock freshness; no signature, encryption, per-code revocation or single-use enforcement |
| Terminal recovery | `read_field` retries only current field; :cancel/EOF/signals cancel safely; secret echo stays off through retries |
| Terminal locales | 52 messages × 12 languages in `locales/messages.json`; upstream installer output is separate |
| Durable checker | `sh "$HOME/.config/ovos-installer/check-setup.sh"`; private mode0700; no installation or download; code expiry does not apply |
| Completion | Active services, heard audio and confirmed voice response are distinct; only human-confirmed response returns checker status0; incomplete status3 |
| Build | `python3 scripts/build-launcher.py`; `build()` embeds trusted sources into identical v1/v2; size regression <120000bytes |

See [source map](docs/index.md) and [audit](AUDIT.md).
