Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Document localized recovery, durable verification and pinned Mac support in 2.1.0.

# Suggestions

## Completed: recoverable terminal handoff

**Problem:** Missing fields exited silently and installation ended without verification. **Implemented:** Localized retry/cancel, common URL syntax validation, stage reporting, a durable service checker, optional sound output and explicit first-voice confirmation. **Impact:** Users can recover in place and distinguish copied/installed/running/actually heard states. Evidence: [`test_launcher.py`](test/test_launcher.py#L682), [`runtime.sh`](lib/runtime.sh).

## Hardware and native-language acceptance

**Remaining opportunity:** Mock tests do not prove every device or locale works in a real room. **Proposal:** Maintain physical Pi5, Intel/Apple Silicon Mac and WSL2 acceptance runs covering restart recovery, service scopes, audio output, wake word and one installed skill. Invite fluent reviewers for all terminal catalogs, especially smaller language communities. **Impact:** Detect environment and language issues that unit tests cannot establish; avoid claiming automatic completion based on service state alone.

## Preserve frozen data meanings while retiring old execution

**Opportunity:** Future options may need new enum values or fields. **Proposal:** Keep the existing field indexes immutable and introduce another protocol version for incompatible changes. Preserve [contract-v1.json](contract-v1.json) for choice recovery while keeping both public endpoints on the v2 expiry policy. Extend Python [raw_code](test/test_launcher.py#L191) and the cross-language golden-vector tests for future versions. **Impact:** Old choices remain interpretable without allowing timeless installation codes.

## Add trusted expiry only if the product later needs authorization

**Problem:** Public timestamps and local clocks cannot provide tamper-resistant expiration or individual revocation. **Proposal:** If a future requirement needs those properties, design an authenticated service or signature-verification protocol with a trusted clock and explicit threat model; do not treat CRC-8 as protection. Keep the current service-free format for ordinary setup freshness. **Impact:** Stronger guarantees would add infrastructure and maintenance costs; no such system is needed for the current public recipe data. Evidence: [expiry audit](AUDIT.md) and [timestamp boundary tests](test/test_launcher.py#L309).

## Adopt an OVOS-owned short domain

**Opportunity:** The initial launcher uses the goldyfruit GitHub Pages address. **Proposal:** Project maintainers can later point a short project-owned hostname at the reviewed launcher. **Impact:** Shorter terminal commands and clearer project ownership, without changing code contents.

## Further endpoint connectivity checks upstream

**Problem:** Local syntax validation cannot establish DNS, TLS, authentication or endpoint compatibility. **Proposal:** Validate service connectivity in the installer before committing integration configuration. **Impact:** Better target-device errors without adding questions to the wizard.
