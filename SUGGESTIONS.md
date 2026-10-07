Last Edit: Codex (GPT-6) - 2026-10-07 - Motive: Update protocol-maintenance suggestions for v2 expiry and explicit legacy recovery.

# Suggestions

## Preserve frozen data meanings while retiring old execution

**Opportunity:** Future options may need new enum values or fields. **Proposal:** Keep the existing field indexes immutable and introduce another protocol version for incompatible changes. Preserve [contract-v1.json](contract-v1.json) for choice recovery while keeping both public endpoints on the v2 expiry policy. Extend Python [raw_code](test/test_launcher.py#L191) and the cross-language golden-vector tests for future versions. **Impact:** Old choices remain interpretable without allowing timeless installation codes.

## Add trusted expiry only if the product later needs authorization

**Problem:** Public timestamps and local clocks cannot provide tamper-resistant expiration or individual revocation. **Proposal:** If a future requirement needs those properties, design an authenticated service or signature-verification protocol with a trusted clock and explicit threat model; do not treat CRC-8 as protection. Keep the current service-free format for ordinary setup freshness. **Impact:** Stronger guarantees would add infrastructure and maintenance costs; no such system is needed for the current public recipe data. Evidence: [expiry audit](AUDIT.md) and [timestamp boundary tests](test/test_launcher.py#L309).

## Adopt an OVOS-owned short domain

**Opportunity:** The initial launcher uses the goldyfruit GitHub Pages address. **Proposal:** Project maintainers can later point a short project-owned hostname at the reviewed launcher. **Impact:** Shorter terminal commands and clearer project ownership, without changing code contents.

## Strengthen endpoint feedback upstream

**Problem:** HTTP(S)-prefix checks permit malformed service endpoints. **Proposal:** Validate endpoint syntax and connectivity in the installer before committing integration configuration. **Impact:** Better target-device errors without adding questions to the wizard.
