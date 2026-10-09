Last Edit: Codex (GPT-6) - 2026-10-08 - Motive: Record automatic wizard failure reports in release 2.4.1.

# Quick facts

| Field | Value |
| --- | --- |
| Package / version | `ovos-start-launcher` / `2.4.1`; `package.json` |
| License | Apache-2.0 |
| Entry points | POSIX shell `v2.sh CODE`; ES module `encodeRecipeCode`, `decodeRecipeCode`, `decodeRecipeEnvelope`; no Python plugin entry points |
| Runtime dependencies | 64-bit userland, POSIX sh, getconf, tr, date with `+%s`, git, sudo (curl for the wizard bootstrap); upstream platform prerequisites still apply |
| Protocol | 80-bit word: version4 + choices28 + issuedAt40 + CRC8; 16 Crockford Base32 characters grouped XXXX-XXXX-XXXX-XXXX |
| Code data | All 15 frozen enum/boolean wizard fields plus Unix issuance seconds; no credentials, arbitrary text or executable payload |
| Checksum | CRC-8/SMBUS over nine big-endian bytes; polynomial 0x07, init/xorout 0, no reflection; not authentication |
| Lifetime | `RECIPE_TTL_SECONDS = 3600`; valid only when `0 < issuedAt <= now < issuedAt + 3600`; exact deadline rejected |
| Clock bounds | Integer Unix seconds 1–1099511627775; target `date +%s`; invalid/unavailable clocks and future codes rejected |
| Legacy handling | Eight-character v1 refused by v2.sh; explicit JS `allowLegacy` restores choices only |
| Expired recovery | Explicit JS `allowExpired` restores expired v2 choices; future codes, bad clocks and malformed data still rejected |
| Protocol records | `contract.json` is v2; `contract-v1.json` preserves the old layout and vectors |
| Hosting | GitHub Pages, `dev` workflow; only index.html, v2.sh and .nojekyll |
| Compatibility pin | `e406a0cb93376e7dbf750bf4629a11079f8f8108` for Mac and explicit speech; retains the `6ffd4650` support base |
| Default speech | Non-Mac devices use verified immutable `44fcada5cd29e0f6a307f39961f510ca1060b5d2`; Mac keeps the compatibility pin without a speech override; both invoke setup.sh directly |
| Git isolation | Repository/index/object/ref context and command-scoped Git config overrides are cleared before checkout and child setup; ordinary Git config, proxies and CA settings are retained |
| Preflight | 64-bit, format/checksum/version/time, compatible choices, nonroot user, correct OS, dependencies, protected existing checkout; freshness checked before side effects |
| Installer runtime | setup.sh child uses umask022; launcher staging remains077; existing installer venv is preserved in a private sibling backup before rebuilding |
| Secrets | Masked target /dev/tty prompts; no code/URL secrets |
| Validation | 38 Node + 423 Python tests pass; v2.sh passes sh/Bash syntax and ShellCheck; clean build emits only v2.sh; fake installers and offline real-Git fixtures only |
| Python test API | [test/test_launcher.py](test/test_launcher.py): `Sandbox`, `raw_code`, `run_launcher`, `run_interactive`; production Python API: `CallbackModule`, `report_phase` in `lib/ansible_progress.py` |
| Security limit | Public, reproducible code and local-clock freshness; no signature, encryption, per-code revocation or single-use enforcement |
| Terminal recovery | `read_field` retries only current field; :cancel/EOF/signals cancel safely; secret echo stays off through retries |
| Terminal locales | 53 messages × 12 languages in `locales/messages.json`; upstream installer output is separate |
| Durable checker | `sh "$HOME/.config/ovos-installer/check-setup.sh"`; private mode 0700; no installation or download; code expiry does not apply |
| Completion | Active services, heard audio and confirmed voice response are distinct; only human-confirmed response returns checker status0; incomplete status3 |
| Build | `python3 scripts/build-launcher.py`; `build()` embeds trusted sources into v2.sh only; size regression <120000bytes |
| Progress CLI | `v2.sh CODE --track TOKEN`; optional 64-character lowercase hex write capability; code-only/read-only invocations never report |
| Progress transport | Fixed HTTPS `/v1/events`; Authorization bearer through curl config stdin; event enum plus validated `errorUrl` on failure; 2-second connection/3-second total cap; no retry/redirect; failures ignored |
| Progress lifetime | Relay-enforced 24-hour capability; separate from unchanged one-hour setup-code deadline |
| Progress privacy | Relay receives no report contents; installer separately uploads wizard failure reports to `paste.uoi.io`; keep full tracked command private because shell history/launcher argv contain the write capability |
| Automatic reports | Tracked child alone receives `OVOS_INSTALLER_AUTO_REPORT=1` with private FD3; inherited flags cleared; untracked installs keep the upload prompt; success/cancellation never attach report URLs |
| Progress recovery | Private `status-token` mode 0600 activated with checker after validation; empty on untracked replacement; data only, never sourced |
| Completion receipt | Private `status-installed` mode 0600 cleared before activation, bound to current capability only after setup.sh zero; checker replays installed before health checks |
| Preflight callbacks | Valid-code OS/user/path/dependency failure reports failed only; early architecture/invalid/expired codes and duplicate-lock rejection emit nothing |
| Installation phases | `stage_system`, `stage_packages`, `stage_services`, `stage_finalize`; successful Ansible role-task results only; monotonic and deduplicated within one run |
| Phase callback | [CallbackModule](lib/ansible_progress.py), notification type; tracked runs only; preserves upstream terminal/profile callbacks; first successful task starts each reported phase |
| Phase privacy | [report_phase](lib/ansible_progress.py) reads a regular nonsymlink mode 0600 token, sends only enum, bounds curl to 3 seconds/Python wait to 4 seconds; never reports completion |

See [source map](docs/index.md) and [audit](AUDIT.md).


CI caught a dash-specific background-stdin difference after the local Bash checks passed. `run_bounded` now duplicates the original input on descriptor3 before starting its child, preserving the Python audio heredoc on Ubuntu. The existing literal-input and real sound-transport regressions caught this; publication remains gated on both CI jobs.

CI portability follow-up: all524 Ubuntu cases now pass; explicit validation branches and narrowly scoped trap annotations also support the older CI ShellCheck. The previous macOS suite passed524 cases. The final publication workflow rechecks both platforms.
