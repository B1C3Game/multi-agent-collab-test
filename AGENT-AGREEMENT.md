# Agent and Contributor Agreement

Version: 1.0
Status: active

All agents and human contributors must sign this agreement before contributing to this repository.

## Scope

This agreement applies to:
- human contributors
- AI agents
- automated scripts that write content

No contribution is valid unless the signer appears in the signature section below.

## Mandatory Rules

1. Every contributor must have a unique UID.
2. Every contributor must sign this file before first contribution.
3. Every edit to shared files must include an EDIT block with:
   - UID
   - TIMESTAMP (UTC ISO8601)
   - INTENT
   - EDITOR
4. Contributors must follow trust policy from `trust-config.json`.
5. Blocked UIDs are not allowed to contribute.
6. Conditional UIDs require explicit captain approval before merge.
7. Signature chain checks and gate checks must pass before final acceptance.

## Contributor Commitments

By signing below, the contributor agrees to:
- provide truthful UID identity
- avoid unauthorized edits
- keep edits attributable and auditable
- accept that violating this agreement can invalidate their contributions

## Signature Format

Use this exact format when signing:

<!-- AGREEMENT-SIGNATURE:UID:TIMESTAMP:SHA256_OF_CLAIM -->
I, [EDITOR], agree to the Agent and Contributor Agreement v1.0.

Example:

<!-- AGREEMENT-SIGNATURE:a1-uuid:2026-03-30T10:00:00Z:REPLACE_WITH_HASH -->
I, Wijak, agree to the Agent and Contributor Agreement v1.0.

## Signed Contributors

Add one block per contributor.

### Founder

<!-- AGREEMENT-SIGNATURE:b1c3-uuid:2026-03-30T10:00:00Z:3f5e230acb22e54ca8625fb7ad1405929a9fb3b7d33ef1dfd4e6d294bb219ed9 -->
I, B1C3, agree to the Agent and Contributor Agreement v1.0.

### A1 Scaffolder

<!-- AGREEMENT-SIGNATURE:a1-uuid:2026-03-30T10:01:00Z:d899491cbf6df7d2c9abe9a1ecdc94b0d9b8f82eb15ee01c9ab646b0be76aa1b -->
I, Wijak, agree to the Agent and Contributor Agreement v1.0.

### A2 Builder

<!-- AGREEMENT-SIGNATURE:a2-uuid:2026-03-30T10:02:00Z:7a546b78a9a73a00d76c88868b778546e26c5a487656f03a3e86227ce3e8b5bb -->
I, Copilot, agree to the Agent and Contributor Agreement v1.0.

## Enforcement

A pull request or change set should be rejected if:
- contributor signature is missing
- signature UID is not in trust policy
- required edit attribution is missing
- gate validation fails
