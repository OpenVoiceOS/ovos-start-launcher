Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Retire the duplicate v1.sh endpoint and publish only v2.sh.

# Launcher developer guide

## Single public entry point (2.3.1)

`v2.sh` is the sole public launcher. The builder keeps modular sources, localized messages and the embedded Python `CallbackModule` for maintenance, but emits no `v1.sh`. [`test_build_cli_emits_only_v2`](../test/test_launcher.py) runs the real builder in a temporary source tree and checks its output. The frozen v1 code schema remains solely for explicit saved-choice recovery, and old immutable Git revisions remain valid. Current [wizard](../../ovos-start/docs/index.md) and [relay](../../ovos-install-status/docs/index.md) commands already pin `v2.sh`; their behavior is unchanged.

## Real installation phases (2.3.0)

[`CallbackModule.v2_runner_on_ok`](../lib/ansible_progress.py) is an optional Ansible notification plugin injected into the temporary checkout only for tracked runs. [`build`](../scripts/build-launcher.py) embeds its reviewed Python source into the self-contained `v2.sh` entry point. No remote Python plugin download is added, no terminal output is parsed, and no timing heuristic advances phases.

| Fixed event | Successful role task begins the phase |
| --- | --- |
| `stage_system` | Contract, device hardware/facts/tuning, sound, timezone or configuration |
| `stage_packages` | `ovos_containers`, `ovos_virtualenv` or nested `ovos_python` |
| `stage_services` | `ovos_services`; service setup/configuration, not running-health proof |
| `stage_finalize` | `ovos_finalize`; finishing work, not successful-install proof |

The callback ignores skipped/failed tasks and earlier roles encountered again as handlers. Its four states advance monotonically and are each attempted once. A first successful task can lag the beginning of a role; unknown roles safely provide no extra detail. Existing launcher `installed` stays after the successful setup exit; the existing checker owns service health and human-confirmed voice events. The [wizard](../../ovos-start/docs/install-progress.md) and [relay](../../ovos-install-status/docs/index.md) consume these fixed enums as subphases of installing.

[`report_phase`](../lib/ansible_progress.py) reads only the regular private `RUN_AS_HOME/.config/ovos-installer/status-token` file. It refuses links, nonregular files, public file permissions and malformed content. Curl uses a fixed HTTPS endpoint, a bearer in stdin, no curlrc, no redirects, a 3-second transport deadline and a 4-second process wait. Exceptions and nonzero results are silent; the plugin cannot declare success/failure or stop installation. Native stdout and profile callbacks remain enabled.

[New tests](../test/test_ansible_progress.py) cover actual callback discovery under Ansible-core 2.17 and 2.20, conditional branches, skipped and failed roles, ordering, offline transport and the generated launcher’s private integration. CI installs `ansible-core>=2.17,<2.18` for the harmless fixture plays.

## Source map

| File | Functions / responsibility |
| --- | --- |
| [codec.mjs](../codec.mjs) | `encodeRecipeCode`, `decodeRecipeCode`, `decodeRecipeEnvelope`, `timestamp`, `currentTime`, `checksum`: typed fields, issuance/expiry and CRC-8 |
| [contract.json](../contract.json) | V2 wire layout, frozen field enums, expiry rules and golden vectors |
| [contract-v1.json](../contract-v1.json) | Historical v1 field layout and vectors for explicit choice recovery |
| [v2.sh](../v2.sh) | Sole public launcher; streamed byte decoding and time checks; `take`, `scenario`, `fail`, `invalid`, `read_field`, `run_bounded`, `restore_tty`, `cleanup_launcher` |
| [codec.test.mjs](../test/codec.test.mjs) | Wire format, corruption/reserved inputs, deadline/future/clock behavior and explicit recovery |
| [test_launcher.py](../test/test_launcher.py) | Python `Sandbox`, `run_launcher` and `run_interactive` fixture helpers and PTY tests; fake installer commands only |
| [ansible_progress.py](../lib/ansible_progress.py) | `CallbackModule.v2_runner_on_ok`, `report_phase`: fixed role phases and private bounded notification transport |
| [test_ansible_progress.py](../test/test_ansible_progress.py) | Real harmless Ansible plays, phase ordering and skipped/failed branches, transport and launcher integration |
| [pages.yml](../.github/workflows/pages.yml) | Tests, reproducible generation and syntax checks, then minimal GitHub Pages artifact with only v2.sh |

The only production Python class is the embedded Ansible `CallbackModule`; no OVOS plugin entry points exist. The caller is the [OVOS Start wizard](../../ovos-start/docs/index.md), whose `buildShortCommand` and `readSetupFragment` use this codec and whose `validateState` applies matching compatibility rules. [OVOS installer documentation](https://github.com/OpenVoiceOS/ovos-installer/tree/main/docs) remains authoritative for actual target support.

## Installer permissions and retry recovery (2.2.1)

The launcher keeps `umask077` while staging configuration, credentials, callbacks and the private checker. Its [`setup.sh` child](../lib/launcher.sh.in#L369) alone uses `umask022`, because the root-created installer Python venv must also be executable by Ansible tasks that become the regular user. Upstream protects its secret extra-vars files explicitly; the launcher's existing scenario/token modes remain 0600 and checker mode 0700.

Before invoking setup, the [runtime guard](../lib/launcher.sh.in#L329) rejects linked or non-directory `.venvs` and `ovos-installer` paths. An existing installer runtime is moved into a unique mode 0700 sibling backup and the location is printed in the selected language. The backup remains after success or failure. The installer creates its missing runtime normally; the launcher does not force upstream's broader cache-refresh setting or change permissions recursively. Application environments such as `~/.venvs/ovos` remain untouched by this preparation.

Python tests [`test_installer_venv_is_accessible_without_exposing_launcher_secrets`](../test/test_storage_hardening.py#L144) create real local venvs and cover fresh/cached 0700 directories, private launcher state and retained app files. [`test_failed_runtime_retry_preserves_backup_and_reports_only_failure`](../test/test_callbacks.py#L103) confirms an exit 126 retry retains its backup, emits only `failed` after `installing` and leaves the success receipt empty. These tests use fake sudo/install/service/network commands; they do not prove operation on physical MarkII hardware.

## Optional installation progress (2.2.0)

`v2.sh CODE --track TOKEN` accepts a separate 64-character lowercase hexadecimal write capability. `CODE` and its one-hour validation remain unchanged. Unknown arguments or malformed capabilities fail before file/network effects. `--decode` and `--scenario` never send progress or persist the capability. Plain `v2.sh CODE` remains supported without callbacks.

[`report_status`](../lib/callback.sh#L3) sends only `{"event":"EVENT"}` to the fixed HTTPS relay at `https://ovos-install-status.goldyfruit.chatgpt.site/v1/events`. Allowed events are `started`, `downloading`, `installing`, `installed`, `services_ready`, `voice_ready`, `needs_attention`, `failed` and `cancelled`. The token goes in the Authorization header through curl config stdin, never curl's argv. Curl disables automatic `.curlrc` loading, permits HTTPS only, does not follow redirects or retry, and limits connection/total time to 2/3 seconds. Missing curl and every transport failure are ignored. No logs, answers, device identifiers or installer secrets are uploaded. The copyable terminal command contains a private status-write capability; do not publish that complete command.

The relay, separately maintained by the wizard, enforces capability lifetime (24 hours). This expiry does not renew or replace the one-hour recipe start deadline. Do not treat the recipe checksum as callback authentication. Reports are best effort and can arrive with earlier events missing. A relay outage, expired token, reboot or power loss can leave the browser behind the terminal; the terminal remains authoritative. There is no inbound listener on the device.

The launcher writes `status-token` with mode 0600 beside the mode 0700 durable checker. It rejects symlink/nonregular destinations and activates both only after installer runtime and prompted inputs pass validation. [`load_status_token`](../lib/callback.sh#L21) reads the file as data, with parent/type checks; no token file is sourced. An untracked later install replaces it with an empty file. Removing `~/.config/ovos-installer/status-token` stops future reports from that checker; relay-side retention/deletion is a separate service concern.

The private mode 0600 `status-installed` receipt is cleared when a validated attempt activates and replaced with the current capability only after `setup.sh` returns zero. [`report_saved_install`](../lib/callback.sh#L32) re-sends `installed` from a regular, nonsymlink receipt matching the loaded token before recovery checks. This recovers a lost completion callback without inferring installation from pre-existing services. It intentionally sends an idempotent duplicate when the first callback already arrived. Receipt persistence is best effort and cannot change a successful installer exit.

Once the code, freshness and optional capability are validated, OS/user/dependency/path preflight rejection sends only `failed`; it does not send `started`. A pre-existing launcher lock suppresses callbacks so a double paste cannot fail the already-running session. Early 32-bit rejection precedes timestamp arithmetic and therefore remains callback-free, as do invalid/expired codes and missing curl. Generate a fresh tracked command for a deliberate retry after failure; an old failed/cancelled relay session is not renewed by executing its token again.

`installed` means only that `setup.sh` returned zero. `services_ready` requires every expected service to be running; it does not prove audio readiness. `voice_ready` is sent only when the person explicitly confirms a real spoken response. Noninteractive/unfinished verification reports `needs_attention`, preserving installer success. Before installation completes, trapped HUP/INT/TERM and installer exit statuses 129/130/143 report `cancelled`; other failures report `failed` without changing the exit result. [`test_callbacks.py`](../test/test_callbacks.py) contains Python `tracked_run`, `callbacks` and `events` helpers plus 114 isolated transport, storage, signal, opt-out and confirmation regressions. [`build`](../scripts/build-launcher.py#L11) embeds the trusted callback/runtime sources in both generated entry points.

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

See [the current validation record](../MAINTENANCE_REPORT.md). Run `npm run build`, `npm test`, `uv run pytest test/ -q`, `sh -n v2.sh` and `bash --posix -n v2.sh`. Python [Sandbox](../test/test_launcher.py#L106) owns isolated paths; `raw_code` supplies an independent wire encoder, `run_launcher` exercises the actual shell, and `run_interactive` checks real PTY reads with fake curl/git/sudo and installer commands. [test_timestamp_boundaries_match_javascript_in_every_mode](../test/test_launcher.py#L322) compares the JavaScript and shell deadlines. The callback tests additionally exercise the production `CallbackModule` through harmless real Ansible plays; no live installation is part of the test suite.

The `dev` workflow tests pull requests and packages `index.html`, `v2.sh` and `.nojekyll` for non-PR Pages deployments. It does not publish the wizard or any recipe database. Documentation updates do not themselves deploy the site.

## Installer contract

All installs require 64-bit userland, a regular user, and the correct Linux/macOS target. Windows recipes run in Ubuntu/WSL2. Dependencies and existing checkouts are checked before downloading installer sources. The launcher creates private temporary files and scenario backups.

Every Mac recipe and explicit public/local speech fetches and verifies commit `6ffd465028bac299e5235d619819bfdc734af073` from [preview PR #648](https://github.com/OpenVoiceOS/ovos-installer/pull/648), resolves Bash 4+, then calls `setup.sh` with `RUN_AS`, `RUN_AS_HOME` and `LOCALE`. Default speech on non-Mac devices fetches main into the same private checkout and invokes setup.sh directly, preserving its exit status. Mac default speech uses the same reviewed pin but leaves `speech_engine` absent. The initial pin is deliberate; evolving PR heads do not silently change this launcher.

Credentials are read only on `/dev/tty` and exported to the target installer. A cancelled/failed secret read restores terminal echo. No secret is encoded in the code or URL. See [audit](../AUDIT.md) for runtime and test limits.

## Localized recovery and completion

[`build`](../scripts/build-launcher.py#L11) combines the shell template, runtime and 12 message catalogs into each public single-file endpoint. Regenerate with `npm run build`; [`test_generated_launchers_match_sources`](../test/test_launcher.py#L797) rejects stale output or an oversized `sh -c` payload. No language files are fetched at runtime.

[`read_field`](../lib/runtime.sh#L28) holds accepted answers in memory and retries only the current field. Secret echo remains disabled across retries and is restored on completion or cancellation. `valid_url` checks local syntax without contacting a service. Python [`test_all_locales_retry_missing_credentials_without_losing_valid_url`](../test/test_launcher.py#L682) and `test_url_syntax_is_validated_without_contacting_the_service` cover this behavior.

The outer launcher writes a private `~/.config/ovos-installer/check-setup.sh` before invoking the installer. [`check_services`](../lib/runtime.sh#L58) uses real systemd units, launchd labels or Compose service labels; these match [the pinned installer service definitions](https://github.com/OpenVoiceOS/ovos-installer/blob/6ffd465028bac299e5235d619819bfdc734af073/ansible/roles/ovos_services/defaults/main.yml) and [OVOS Docker Compose](https://github.com/OpenVoiceOS/ovos-docker/blob/dev/compose/docker-compose.yml).

[`sound_check`](../lib/runtime.sh#L94) uses installed `ovos_bus_client.MessageBusClient` / `Message` to emit a localized `speak` message only after a user chooses the test. It waits at most eight seconds for connection, fifteen for playback notification, with a thirty-second Python alarm. See [`ovos-bus-client: scripts.py`](../../ovos-bus-client/ovos_bus_client/scripts.py), specifically `ovos_speak`, for the existing API contract. Docker uses the installed `ovos_audio` container; virtualenv routes use `~/.venvs/ovos/bin/python3`. User confirmation of an audible response remains separate from transport events.

[`check_setup`](../lib/runtime.sh#L225) returns0 only after a human confirms a spoken response; return3 means unfinished or satellite-dependent. The installer return code is not a voice-health signal. The parent installation command does not convert an unfinished optional check into an installation failure. It prints safe log/community recovery on an actual nonzero installer exit. With a tracking capability, fixed progress events update the wizard through its relay; no inbound server is opened and no logs are uploaded. Physical installation and fluent language review remain outside mock-test evidence.

## Safe activation and bounded recovery (2.1.1)

The launcher checks exact configuration path types before downloading and before elevated activation, stages the checker until preparation succeeds, and holds a per-account directory lock through setup. Existing scenarios receive a0600 backup. The default-main route directly calls the fetched `setup.sh`, retaining its true result; pinned routes keep the existing reviewed SHA. Both use a disposable checkout outside the user’s `~/ovos-installer`. See [path/concurrency tests](../test/test_storage_hardening.py) (`run_with_process_deadline`, `test_concurrent_launcher_cannot_replace_an_active_install_recipe`).

[`run_bounded`](../lib/runtime.sh#L10) supervises systemd/launchd probes (5seconds), Docker listing (10seconds) and audio dispatch (35seconds), with TERM then KILL after2seconds. Its own command and watchdog are reaped. [Runtime tests](../test/test_runtime_hardening.py) use `run_runtime` with local stalled workers; the phase callback is separate from these shell service checks. Docker must report running services in project `ovos`. MessageBus connections close in `finally`; human voice confirmation remains required.

Git disables interactive prompts and aborts sustained slow transfer, but this is not a total installation timeout. The initial wizard curl has a15-second connection and120-second total deadline. [Wizard handoff](../../ovos-start/docs/short-codes.md) explains the immutable launcher. A power loss can retain the directory lock; [deliberate recovery](../FAQ.md#why-does-it-say-a-setup-is-already-running) prevents unlocking a live installer. The CI workflow gates Pages on both Ubuntu and macOS test jobs.


CI caught a dash-specific background-stdin difference after the local Bash checks passed. `run_bounded` now duplicates the original input on descriptor3 before starting its child, preserving the Python audio heredoc on Ubuntu. The existing literal-input and real sound-transport regressions caught this; publication remains gated on both CI jobs.

CI portability follow-up: all524 Ubuntu cases now pass; explicit validation branches and narrowly scoped trap annotations also support the older CI ShellCheck. The previous macOS suite passed524 cases. The final publication workflow rechecks both platforms.
