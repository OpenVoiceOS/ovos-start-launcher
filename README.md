Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Harden launcher activation, failure propagation, recovery and bounded health checks in 2.1.1.

# OVOS Start launcher

A short setup code carries the choices made in OVOS Start and expires one hour after issuance. The launcher checks it on the target device and prepares the existing OVOS installer. No recipe database, upload or login is needed.

Copy the complete command from your finished wizard and run it as your regular user on the target device. It downloads the launcher fully before executing it. Do not prepend sudo; the launcher requests administrator access when needed.

- [Version 2 launcher](https://goldyfruit.github.io/ovos-start-launcher/v2.sh)
- [Protocol, behavior and tests](docs/index.md)
- [Known limits](AUDIT.md)
- [Questions](FAQ.md)

A 64-bit OS is required. All Mac recipes and explicit local/online speech use the reviewed experimental PR #648 revision, not the current main release. Passwords and API keys are entered only on the target terminal. Codes are public settings, not passwords.

Codes contain 16 Base32 characters, grouped `XXXX-XXXX-XXXX-XXXX`. They are valid when `issuedAt <= now < issuedAt + 3600`. At the deadline, the launcher refuses the code. Future timestamps and unavailable or malformed clocks also fail before installer downloads or settings changes. The old `v1.sh` address serves the same checks and refuses timeless eight-character codes; generate a new code in the wizard.

Expiry relies on the browser and target clocks. The timestamp and CRC are editable public data, so this is not a signed authorization, single-use token or server-enforced revocation. The codec has explicit recovery options for restoring old choices without making the old code executable. See [clock and recovery details](FAQ.md).

This repository is maintained under the goldyfruit account; its hosting address is not an OpenVoiceOS-owned domain.

## Development

Run `npm run build`, `npm test`, `python3 -m pytest test/ -q`, `sh -n v1.sh`, `sh -n v2.sh`, and `cmp v1.sh v2.sh`. The latest checks passed **38 Node tests and 524 Python tests**. The Python [Sandbox](test/test_launcher.py#L94), `run_launcher` and `run_interactive` helpers use fake installers and real local terminal tests; they never perform an OVOS installation.

PRs target `dev`. GitHub Actions tests both entry points, checks that they match, and packages only `index.html`, `v1.sh`, `v2.sh` and `.nojekyll` for Pages. The wizard is not part of that artifact.

Apache-2.0. Version is recorded in `package.json`.

After installation or a restart, run `sh "$HOME/.config/ovos-installer/check-setup.sh"` to check services and try the speaker and microphone. It never reinstalls OVOS. The terminal only confirms a first voice response after you explicitly report hearing the correct answer. Missing integration fields can be corrected in place; type `:cancel` to stop. All launcher-owned prompts use the selected language.
