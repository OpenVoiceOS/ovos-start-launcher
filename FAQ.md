Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Explain one-hour expiry, legacy choice recovery, clock failures and security limits.

# Frequently asked questions

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
