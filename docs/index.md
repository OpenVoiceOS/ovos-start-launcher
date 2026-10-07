Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Harden launcher activation, failure propagation, recovery and bounded health checks in 2.1.1. Preserve probe input under dash.

# Launcher developer guide

## Source map

| File | Functions / responsibility |
| --- | --- |
| [codec.mjs](../codec.mjs) | `encodeRecipeCode`, `decodeRecipeCode`, `decodeRecipeEnvelope`, `timestamp`, `currentTime`, `checksum`: typed fields, issuance/expiry and CRC-8 |
| [contract.json](../contract.json) | V2 wire layout, frozen field enums, expiry rules and golden vectors |
| [contract-v1.json](../contract-v1.json) | Historical v1 field layout and vectors for explicit choice recovery |
| [v2.sh](../v2.sh), [v1.sh](../v1.sh) | Identical v2 entry points; streamed byte decoding and time checks; `take`, `scenario`, `fail`, `invalid`, `read_field`, `run_bounded`, `restore_tty`, `cleanup_launcher` |
| [codec.test.mjs](../test/codec.test.mjs) | Wire format, corruption/reserved inputs, deadline/future/clock behavior and explicit recovery |
| [test_launcher.py](../test/test_launcher.py) | Python `Sandbox`, `run_launcher` and `run_interactive` fixture helpers and PTY tests; fake installer commands only |
| [pages.yml](../.github/workflows/pages.yml) | Tests, syntax/parity checks, then minimal GitHub Pages artifact with both shell endpoints |

No production Python classes or OVOS plugin entry points exist. The caller is the OVOS Start wizard, whose `buildShortCommand` and `readSetupFragment` use this codec and whose `validateState` applies matching compatibility rules. [OVOS installer documentation](https://github.com/OpenVoiceOS/ovos-installer/tree/main/docs) remains authoritative for actual target support.

## Protocol

The v2 word is `[version:4][payload:28][issuedAt:40][CRC-8:8]`, big-endian: 80 bits encoded as 16 Crockford Base32 characters, grouped `XXXX-XXXX-XXXX-XXXX`. `issuedAt` is a positive integer Unix timestamp. CRC-8/SMBUS uses polynomial 0x07, init 0, non-reflected, xorout 0 over the first nine bytes. Lowercase and ungrouped input are accepted; whitespace and ambiguous O/I/L aliases are rejected.

The first 32 bits retain v1's version/header structure and all payload indexes. Version 2 uses version value 2; no recipe fields were reordered. JavaScript uses BigInt. The shell emits decoded bytes incrementally, keeping arithmetic within the forty-bit timestamp range instead of accumulating an 80-bit integer.

Example test vector, not a current installation code: computer-default at `issuedAt=1700000000` gives `4400-00G0-CN9Z-2055`; header `0x21000002`, CRC `0xa5`, deadline `1700003600`. It is expired on today's clock.

The checksum detects typing errors, not malicious changes. Decode known enums as data, then reject incompatible combinations. Never eval code content. Both published endpoints reject old v1 codes; [contract-v1.json](../contract-v1.json) preserves their immutable meanings for recovery.

## Codec API and expiry

| API | Behavior |
| --- | --- |
| `encodeRecipeCode(state, {issuedAt})` | Checks exact typed recipe fields; defaults issuance to `floor(Date.now()/1000)`; returns grouped v2 code |
| `decodeRecipeCode(code, {now, allowLegacy, allowExpired})` | Returns typed choices after format, CRC, version, time and reserved-value checks |
| `decodeRecipeEnvelope(code, sameOptions)` | Returns `{version, issuedAt, expiresAt, state}`; recovered legacy timestamps are `null` |
| `RECIPE_TTL_SECONDS` | 3600 |
| `MAX_RECIPE_TIMESTAMP` | 1099511627775, the largest forty-bit unsigned timestamp |

Default decoding accepts only `0 < issuedAt <= now < issuedAt + 3600`. The exact deadline, future-dated codes and unavailable or invalid clocks fail. `now` defaults to the current JavaScript clock in whole Unix seconds; explicit times are useful in deterministic tests. The target launcher independently reads `date +%s` and performs the same boundary checks before any installer or file side effect, including for its read-only output modes.

`allowLegacy: true` and `allowExpired: true` are explicit library options for restoring choices. They do not bypass bad checksums, unsupported layouts, reserved values, future timestamps or invalid clocks. They are not accepted by either shell endpoint. The caller must revalidate recovered choices and deliberately issue a new code. Preserve `issuedAt` across copies/reloads rather than calling the default encoder to silently extend a code's life.

Expiry is a local freshness policy. Browser/target clocks can disagree, and timestamps plus checksums are public and reproducible. There is no signature, single-use record or per-code revocation service. The [audit](../AUDIT.md) records these limits and the distinction between accepting a code at launcher start and timing out an installation already underway.

## Verification and publication

The current checks passed **38 Node tests and 524 Python cases**. Run `npm run build`, `npm test`, `python3 -m pytest test/ -q`, both `sh -n` checks and `cmp v1.sh v2.sh`. Python [Sandbox](../test/test_launcher.py#L94) owns isolated paths; `raw_code` supplies an independent wire encoder, `run_launcher` exercises the actual shell, and `run_interactive` checks real PTY reads with fake curl/git/sudo and installer commands. [test_timestamp_boundaries_match_javascript_in_every_mode](../test/test_launcher.py#L309) compares the JavaScript and shell deadlines. No production Python classes or live installation are part of the test suite.

The `dev` workflow tests pull requests and packages `index.html`, `v1.sh`, `v2.sh` and `.nojekyll` for non-PR Pages deployments. It does not publish the wizard or any recipe database. Documentation updates do not themselves deploy the site.

## Installer contract

All installs require 64-bit userland, a regular user, and the correct Linux/macOS target. Windows recipes run in Ubuntu/WSL2. Dependencies and existing checkouts are checked before downloading installer sources. The launcher creates private temporary files and scenario backups.

Every Mac recipe and explicit public/local speech fetches and verifies commit `6ffd465028bac299e5235d619819bfdc734af073` from [preview PR #648](https://github.com/OpenVoiceOS/ovos-installer/pull/648), resolves Bash 4+, then calls `setup.sh` with `RUN_AS`, `RUN_AS_HOME` and `LOCALE`. Default speech on non-Mac devices fetches main into the same private checkout and invokes setup.sh directly, preserving its exit status. Mac default speech uses the same reviewed pin but leaves `speech_engine` absent. The initial pin is deliberate; evolving PR heads do not silently change this launcher.

Credentials are read only on `/dev/tty` and exported to the target installer. A cancelled/failed secret read restores terminal echo. No secret is encoded in the code or URL. See [audit](../AUDIT.md) for runtime and test limits.

## Localized recovery and completion

[`build`](../scripts/build-launcher.py#L11) combines the shell template, runtime and 12 message catalogs into each public single-file endpoint. Regenerate with `npm run build`; [`test_generated_launchers_match_sources`](../test/test_launcher.py#L797) rejects stale output or an oversized `sh -c` payload. No language files are fetched at runtime.

[`read_field`](../lib/runtime.sh#L28) holds accepted answers in memory and retries only the current field. Secret echo remains disabled across retries and is restored on completion or cancellation. `valid_url` checks local syntax without contacting a service. Python [`test_all_locales_retry_missing_credentials_without_losing_valid_url`](../test/test_launcher.py#L682) and `test_url_syntax_is_validated_without_contacting_the_service` cover this behavior.

The outer launcher writes a private `~/.config/ovos-installer/check-setup.sh` before invoking the installer. [`check_services`](../lib/runtime.sh#L58) uses real systemd units, launchd labels or Compose service labels; these match [the pinned installer service definitions](https://github.com/OpenVoiceOS/ovos-installer/blob/6ffd465028bac299e5235d619819bfdc734af073/ansible/roles/ovos_services/defaults/main.yml) and [OVOS Docker Compose](https://github.com/OpenVoiceOS/ovos-docker/blob/dev/compose/docker-compose.yml).

[`sound_check`](../lib/runtime.sh#L94) uses installed `ovos_bus_client.MessageBusClient` / `Message` to emit a localized `speak` message only after a user chooses the test. It waits at most eight seconds for connection, fifteen for playback notification, with a thirty-second Python alarm. See [`ovos-bus-client: scripts.py`](../../ovos-bus-client/ovos_bus_client/scripts.py), specifically `ovos_speak`, for the existing API contract. Docker uses the installed `ovos_audio` container; virtualenv routes use `~/.venvs/ovos/bin/python3`. User confirmation of an audible response remains separate from transport events.

[`check_setup`](../lib/runtime.sh#L131) returns0 only after a human confirms a spoken response; return3 means unfinished or satellite-dependent. The installer return code is not a voice-health signal. The parent installation command does not convert an unfinished optional check into an installation failure. It prints safe log/community recovery on an actual nonzero installer exit. No callback is sent to the browser, no inbound server is opened and no logs are uploaded. Physical installation and fluent language review remain outside mock-test evidence.

## Safe activation and bounded recovery (2.1.1)

The launcher checks exact configuration path types before downloading and before elevated activation, stages the checker until preparation succeeds, and holds a per-account directory lock through setup. Existing scenarios receive a0600 backup. The default-main route directly calls the fetched `setup.sh`, retaining its true result; pinned routes keep the existing reviewed SHA. Both use a disposable checkout outside the user’s `~/ovos-installer`. See [path/concurrency tests](../test/test_storage_hardening.py) (`run_with_process_deadline`, `test_concurrent_launcher_cannot_replace_an_active_install_recipe`).

[`run_bounded`](../lib/runtime.sh#L10) supervises systemd/launchd probes (5seconds), Docker listing (10seconds) and audio dispatch (35seconds), with TERM then KILL after2seconds. Its own command and watchdog are reaped. [Runtime tests](../test/test_runtime_hardening.py) use `run_runtime` with local stalled workers; no production Python classes exist. Docker must report running services in project `ovos`. MessageBus connections close in `finally`; human voice confirmation remains required.

Git disables interactive prompts and aborts sustained slow transfer, but this is not a total installation timeout. The initial wizard curl has a15-second connection and120-second total deadline. [Wizard handoff](../../ovos-start/docs/short-codes.md) explains the immutable launcher. A power loss can retain the directory lock; [deliberate recovery](../FAQ.md#why-does-it-say-a-setup-is-already-running) prevents unlocking a live installer. The CI workflow gates Pages on both Ubuntu and macOS test jobs.


CI caught a dash-specific background-stdin difference after the local Bash checks passed. `run_bounded` now duplicates the original input on descriptor3 before starting its child, preserving the Python audio heredoc on Ubuntu. The existing literal-input and real sound-transport regressions caught this; publication remains gated on both CI jobs.
