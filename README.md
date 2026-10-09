<!-- Last Edit: Codex - 2026-10-08 - Motive: Link to the public OpenVoiceOS wizard. -->

# OVOS Start launcher

This script installs [OpenVoiceOS](https://www.openvoiceos.org/) using the choices you made in the setup wizard. It checks your setup code and device, prepares the OVOS installer, and starts the installation.

## Get started

1. Complete the [OVOS setup wizard](https://start.openvoiceos.pt).
2. Copy the install command shown at the end.
3. Paste it into Terminal on your device and follow the prompts.

Run the command as your normal user. The launcher asks for administrator access when needed. Setup codes expire after one hour; return to the wizard for a new command if yours expires. Keep your install command private.

## Check your setup

After installation or a restart, run:

```sh
sh "$HOME/.config/ovos-installer/check-setup.sh"
```

This checks services and helps you test your speaker and microphone.

## Development

[`v2.sh`](v2.sh) is the launcher. See the [developer guide](docs/index.md) for its source, build instructions, and tests.

## Sponsorship

[![Sponsored by NLnet through the NGI0 Commons Fund](./ngi.png)](https://nlnet.nl/project/OpenVoiceOS/)

Supported by [NLnet](https://nlnet.nl/) through the [NGI0 Commons Fund](https://nlnet.nl/commonsfund/), with European Commission funding for the [Next Generation Internet](https://ngi.eu/) programme ([grant 101135429](https://cordis.europa.eu/project/id/101135429)).

## License

Apache-2.0. See [LICENSE](LICENSE).
