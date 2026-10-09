<!-- Last Edit: Codex - 2026-10-09 - Motive: Explain automatic tuning for Raspberry Pi and Mycroft hardware. -->

# OVOS Start launcher

[`v2.sh`](v2.sh) runs on your device. It checks your choices from the [OVOS Start wizard](https://start.openvoiceos.pt/), starts [ovos-installer](https://github.com/OpenVoiceOS/ovos-installer), and sends progress and error-report links back to the wizard.

Every installation uses the latest `ovos-installer` **main** branch, including macOS. New Mac installations need Apple Silicon and macOS 15 or later.

Raspberry Pi, Mark I, Mark II and DevKit setups enable the installer's Raspberry Pi tuning. Other device choices leave it off. Overclocking is not enabled by this setting.

The website and progress API live in [ovos-start](https://github.com/OpenVoiceOS/ovos-start). This repository contains the device-side launcher.

## Get started

1. Open the [wizard](https://start.openvoiceos.pt/) and choose your setup.
2. Prepare your device, then copy the install command.
3. Paste it into your device's terminal and follow the prompts.

Run as your normal user; the launcher asks for administrator access when needed. Keep the command private. If it expires after one hour, get a new one from the wizard.

## Check your setup

After installation or a restart, run:

```sh
sh "$HOME/.config/ovos-installer/check-setup.sh"
```

This checks services and helps you test your speaker and microphone.

## Development

See the [developer guide](docs/index.md) for source files, builds, tests and progress reporting.

## Sponsorship

[![Sponsored by NLnet through the NGI0 Commons Fund](./ngi.png)](https://nlnet.nl/project/OpenVoiceOS/)

Supported by [NLnet](https://nlnet.nl/) through the [NGI0 Commons Fund](https://nlnet.nl/commonsfund/), with European Commission funding for the [Next Generation Internet](https://ngi.eu/) programme ([grant 101135429](https://cordis.europa.eu/project/id/101135429)).

## License

Apache-2.0. See [LICENSE](LICENSE).
