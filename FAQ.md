Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Harden launcher activation, failure propagation, recovery and bounded health checks in 2.1.1.

# Frequently asked questions

## Why does it say a setup is already running?

A private lock prevents two commands from replacing the same settings. Let the active setup and its optional checks finish. A forced reboot, power loss or SIGKILL can leave the empty lock behind. **Only after confirming no installer or launcher is running**, remove it with `rmdir "$HOME/.config/ovos-installer/.launcher-lock"`, then copy a fresh command. `rmdir` refuses a nonempty directory; never recursively delete an unfamiliar lock. The recovery checker works independently of this lock. See [concurrency tests](test/test_storage_hardening.py#L181).

## Why was a configuration path refused?

Setup expects ordinary `.config`/`ovos-installer` directories and regular scenario/checker files. Symlinks, directories in place of files, FIFOs and other unexpected paths are refused before downloads to protect existing content. The message prints the path. Move that object aside yourself, keeping its contents, before retrying. [Storage tests](test/test_storage_hardening.py#L39) verify refusal and preservation.

## Are installer errors and stalled service checks handled?

Both main and preview run `setup.sh` directly, so its failure status reaches the caller. Running services still do not prove working speech. The checker limits systemd/launchd probes to5seconds, Docker listing to10seconds and sound dispatch to35seconds, with up to2seconds to terminate an unresponsive process. An unavailable check stays incomplete. Source: [`run_bounded`](lib/runtime.sh#L10), [`check_services`](lib/runtime.sh#L104) and [runtime tests](test/test_runtime_hardening.py).

## Can I correct a URL or missing token without starting again?

Yes. The launcher retries only the current field and retains earlier valid fields in memory. HTTP(S) addresses need a host and valid optional port, without whitespace, passwords embedded in the address or URL fragments. `:cancel` in any field or Ctrl+C stops before the new scenario is activated; secrets remain masked even while retrying. See [`read_field`](lib/runtime.sh#L28) and Python [`test_all_locales_retry_missing_credentials_without_losing_valid_url`](test/test_launcher.py#L682).

## How do I check OVOS after restarting?

Run `sh "$HOME/.config/ovos-installer/check-setup.sh"` as the same regular user. The launcher saves this private helper before starting installation. It only checks services and offers sound/voice tests; it does not download or reinstall OVOS and does not need an unexpired setup code. It can be removed after verification. See [`check_setup`](lib/runtime.sh#L131) and [`test_durable_checker_is_private_read_only_and_honest_about_unverified_voice`](test/test_launcher.py#L763).

## What does verification actually confirm?

The helper reports expected service state separately from speaker and microphone tests. If you choose a sound test, it sends a short localized sample through the installed OVOS MessageBus API. You must confirm hearing it, then try a spoken command and confirm the reply. Missing tools, unfinished checks, unavailable services or server-only setups never produce an automatic success claim. A server requires a connected satellite. The shell check returns 0 only after you confirm a voice response, otherwise 3 for an unfinished check.

## Does the terminal use my chosen language?

All launcher-owned prompts and recovery messages have catalogs for English, French, German, Spanish, Italian, Dutch, Portuguese, Catalan, Basque, Galician, Hindi and Kabyle. These are independent of upstream installer messages, which may contain English. The locale comes from a checksum-verified code when possible and from the terminal environment before decoding. Fluent human review remains necessary; automated parity does not certify translation quality.

## Why does default Mac installation also use the reviewed preview?

The reviewed [PR648 revision](https://github.com/OpenVoiceOS/ovos-installer/blob/6ffd465028bac299e5235d619819bfdc734af073/docs/supported-systems.md) documents Intel and Apple Silicon support. Current main changed that contract. Pinning Mac installation preserves the wizard's architecture promise; choosing default speech still leaves speech selection to that installer and adds no `speech_engine` override.

## Do setup codes expire?

Yes. A v2 code contains its issuance time in Unix seconds and expires exactly 3,600 seconds later. The launcher accepts `issuedAt <= now < issuedAt + 3600`; the deadline itself is rejected. Expiry is checked before installer downloads or file changes, including in `--decode` and `--scenario` modes. See [timestamp boundary tests](test/test_launcher.py#L309).

## Does copying or reopening a code extend its life?

The same code keeps the same issuance timestamp. The caller must preserve that timestamp when displaying or copying it. Calling `encodeRecipeCode(state)` without an `issuedAt` explicitly creates a new issuance using the current clock; it should be used for a deliberate new code, not silently on each copy or reload. Expiry controls starting the launcher, not how long an accepted installation may run.

## What happens to old eight-character setup codes?

Both public shell entry points now require v2 codes and tell users with timeless v1 codes to generate a new one. Keeping the old `v1.sh` URL does not keep old codes executable. The original field map and vectors remain in [contract-v1.json](contract-v1.json).

## Can the browser recover choices from a legacy or expired link?

Yes. `decodeRecipeCode(code, {allowLegacy: true})` can recover v1 choices; `decodeRecipeCode(code, {allowExpired: true})` can recover expired v2 choices. Both flags can be supplied for a restoration flow. Defaults reject both cases. `decodeRecipeEnvelope` applies the same checks and returns `{version, issuedAt, expiresAt, state}`; legacy timestamps are `null`.

These flags are browser/library recovery controls only. Shell commands have no bypass flags. The restored choices still need compatibility validation and deliberate issuance of a new code. Future timestamps, invalid clocks, bad checksums, unsupported versions and reserved values remain rejected. See [codec recovery tests](test/codec.test.mjs#L246).

## Why does the target say the code is future-dated or the clock is invalid?

The browser supplies the issuance timestamp; the target reads `date +%s`. Both need correctly set clocks. A target clock behind the browser can make a fresh code look future-dated; a clock far ahead can make it appear expired. Correct the clocks, then generate a new code. Missing, failed, nonnumeric, nonpositive or out-of-range clock values fail closed. [Clock failure tests](test/test_launcher.py#L353) verify that no installer commands or settings changes occur.

## Is the one-hour expiry a security token or server-side deletion?

No server stores a per-code record. The timestamp is public and CRC-8 detects transcription errors, not forgery. Someone can change their clock or regenerate a code and checksum. A code is reusable within its valid period; there is no signature, individual revocation, encryption or single-use guarantee. The check helps users avoid running stale instructions. Launcher availability, downloaded upstream code and the target's actual compatibility remain separate requirements.

## Does the browser upload settings to a paste service?

No. `encodeRecipeCode` in [codec.mjs](codec.mjs) works locally. The public launcher is the same for everyone; the code is passed as a local shell argument, not an HTTP query parameter.

## Can a code include my Home Assistant token or AI key?

No. Recipe choices accept only fixed enums and booleans; the only additional data is the issuance timestamp. The launcher asks for credentials through `/dev/tty`, masks secret input, and exports it to the installer. Treat codes as public settings.

## Does online speech allow a 32-bit OS?

No. Every route requires `getconf LONG_BIT` to return 64 before installer downloads or settings changes.

## Can I inspect a code without installing?

After downloading and inspecting the launcher, `sh v2.sh --decode CODE` prints validated JSON; `sh v2.sh --scenario CODE` prints YAML. These modes do not download the installer or alter settings. They require 64-bit userland and a valid, unexpired v2 code. The old `v1.sh` address applies the same requirements.

## What happens to existing settings?

The launcher protects `~/ovos-installer` and creates a scenario backup. Invalid, expired or legacy codes do not create a backup or alter active settings. Failed source fetches/pin checks do not replace the scenario. Missing preview Bash is detected before scenario replacement. See Python `Sandbox.seed_scenario` and [test_invalid_freshness_preserves_existing_scenario](test/test_launcher.py#L389).

## Is local speech fully offline?

No such guarantee is made. The reviewed preview retains online STT fallback. Language, hardware and actual installer checks still apply.
