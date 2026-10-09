Last Edit: Codex (GPT-6) - 2026-10-08 - Motive: Explain optional error-report links for tracked installations.

# OVOS Start launcher

A short setup code carries the choices made in OVOS Start and expires one hour after issuance. The launcher checks it on the target device and prepares the existing OVOS installer. Recipe decoding does not require a database, upload or login. The wizard can also supply a separate private capability for optional installation progress.

Copy the complete command from your finished wizard and run it as your regular user on the target device. It downloads the launcher fully before executing it. Do not prepend sudo; the launcher requests administrator access when needed.

- [Version 2 launcher](https://goldyfruit.github.io/ovos-start-launcher/v2.sh)
- [Protocol, behavior and tests](docs/index.md)
- [Known limits](AUDIT.md)
- [Questions](FAQ.md)

A 64-bit OS is required. Installer versions are pinned and verified before running. Mac recipes and explicit local/online speech retain the existing experimental compatibility version, with the error-report handoff added. Passwords and API keys are entered only on the target terminal. Codes are public settings, not passwords.

Codes contain 16 Base32 characters, grouped `XXXX-XXXX-XXXX-XXXX`. They are valid when `issuedAt <= now < issuedAt + 3600`. At the deadline, the launcher refuses the code. Future timestamps and unavailable or malformed clocks also fail before installer downloads or settings changes. `v2.sh` is the only published launcher. The old `v1.sh` address is retired; copy a new command from the wizard. Timeless eight-character codes are still refused.

Expiry relies on the browser and target clocks. The timestamp and CRC are editable public data, so this is not a signed authorization, single-use token or server-enforced revocation. The codec has explicit recovery options for restoring old choices without making the old code executable. See [clock and recovery details](FAQ.md).

This repository is maintained under the goldyfruit account; its hosting address is not an OpenVoiceOS-owned domain.

`v2.sh CODE --track TOKEN` reports installation stages to the wizard. If the installer offers to share an error report and you agree, the wizard also receives its paste link. The launcher does not upload log contents, recordings, API keys or device identifiers. Failed status requests do not fail installation. The private recovery checker can resume progress after a restart, and only explicit human confirmation reports a working voice response. The tracked command contains a status-write capability; keep the full command private. See [callback behavior and limits](docs/index.md#optional-installation-progress-220).

## Development

Run `npm run build`, `npm test`, `uv run pytest test/ -q`, `sh -n v2.sh`, and `bash --posix -n v2.sh`. The build emits only `v2.sh`; tests and CI reject a recreated `v1.sh`. The Python [Sandbox](test/test_launcher.py#L106), `run_launcher` and `run_interactive` helpers use fake installers and real local terminal tests; they never perform an OVOS installation or contact the live relay.

PRs target `dev`. GitHub Actions checks reproducible generation and tests `v2.sh` on Linux and macOS, then packages only `index.html`, `v2.sh` and `.nojekyll` for Pages. The wizard is not part of that artifact.

Apache-2.0. Version is recorded in `package.json`.

After installation or a restart, run `sh "$HOME/.config/ovos-installer/check-setup.sh"` to check services and try the speaker and microphone. It never reinstalls OVOS. The terminal only confirms a first voice response after you explicitly report hearing the correct answer. Missing integration fields can be corrected in place; type `:cancel` to stop. All launcher-owned prompts use the selected language.
