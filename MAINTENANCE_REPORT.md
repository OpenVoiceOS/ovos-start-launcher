Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Introduce the tested versioned compact-code launcher and GitHub Pages publication.

# Maintenance report

## 2026-10-07 — Version 1.0.0

Implemented a frozen 40-bit recipe codec and POSIX shell launcher. The launcher decodes and validates all choices, preserves the experimental speech pin, backs up scenarios and prompts for credentials only on the target TTY. The one-line bootstrap executes only after a complete successful download. GitHub Actions checks code/tests before publishing the two public assets to Pages.

Verification: **30 Node and 83 pytest tests pass**. Tests cover enum round trips, corruption, version errors, invalid combinations, 64-bit/user/OS/checkouts, failed fetches and pin mismatches, scenario backups, locale/features, guarded Bash resolution and real PTY secret masking. `sh -n` passes. No real OVOS installation was performed.

### Transparency Report

- **AI Model:** Codex, GPT-6.
- **Actions Taken:** Implemented launcher, codec, tests and hosting workflow; reviewed contract and failure handling; wrote documentation.
- **Oversight:** User explicitly approved the self-contained setup-code approach with GitHub Pages. Separate agents implemented/reviewed the codec and shell tests. Human hardware acceptance remains pending.
