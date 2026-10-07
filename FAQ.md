Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Introduce the tested versioned compact-code launcher and GitHub Pages publication.

# Frequently asked questions

## Do setup codes expire?

No stored expiry exists. The choices are encoded in the code. The matching launcher version and upstream installer must still be available. The wire layout is frozen for version 1.

## Does the browser upload settings to a paste service?

No. `encodeRecipeCode` in [codec.mjs](codec.mjs) works locally. The public launcher is the same for everyone; the code is passed as a local shell argument, not an HTTP query parameter.

## Can a code include my Home Assistant token or AI key?

No. The format accepts only fixed enums and booleans. The launcher asks for credentials through `/dev/tty`, masks secret input, and exports it to the installer. A checksum is not encryption or authentication; treat codes as public settings.

## Does online speech allow a 32-bit OS?

No. Every route requires `getconf LONG_BIT` to return 64 before installer downloads or settings changes.

## Can I inspect a code without installing?

After downloading and inspecting the launcher, `sh v1.sh --decode CODE` prints validated JSON; `sh v1.sh --scenario CODE` prints YAML. These modes do not download the installer or alter settings. They also require 64-bit userland.

## What happens to existing settings?

The launcher protects `~/ovos-installer` and creates a scenario backup. Failed source fetches/pin checks do not replace the scenario. Missing preview Bash is detected before scenario replacement. See [test_launcher.py](test/test_launcher.py).

## Is local speech fully offline?

No such guarantee is made. The reviewed preview retains online STT fallback. Language, hardware and actual installer checks still apply.
