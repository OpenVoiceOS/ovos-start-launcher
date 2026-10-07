Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Introduce the tested versioned compact-code launcher and GitHub Pages publication.

# OVOS Start launcher

A short setup code carries the choices made in OVOS Start. The launcher decodes it on the target device and prepares the existing OVOS installer. No recipe database, upload or login is needed.

Copy the complete command from your finished wizard and run it as your regular user on the target device. It downloads the launcher fully before executing it. Do not prepend sudo; the launcher requests administrator access when needed.

- Public launcher: https://goldyfruit.github.io/ovos-start-launcher/v1.sh
- [Protocol, behavior and tests](docs/index.md)
- [Known limits](AUDIT.md)
- [Questions](FAQ.md)

A 64-bit OS is required. Explicit local/online speech uses the reviewed experimental PR #648 revision, not the current main release. Passwords and API keys are entered only on the target terminal. Codes are public settings, not passwords.

This repository is maintained under the goldyfruit account; its hosting address is not an OpenVoiceOS-owned domain.

## Development

Run `node --test test/*.test.mjs`, `python3 -m pytest test/ -q`, and `sh -n v1.sh`. Tests use local fake installers, never a real installation. PRs target `dev`. GitHub Actions publishes only `index.html` and `v1.sh` after tests pass.

Apache-2.0. Version is recorded in `package.json`.
