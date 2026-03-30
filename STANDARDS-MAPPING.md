# Standards Mapping

This repository intentionally combines:
- established git governance standards
- custom collaboration protocol for human and agent contributors

## Existing Standards Covered Elsewhere

- Commit identity and history: git
- Commit signing: GPG or SSH signatures
- Signed-off-by policy: DCO style
- Ownership and review: CODEOWNERS and pull request workflow

## Repository-Specific Additions

- UID-level edit attribution in content blocks
- Trust-policy validation by UID class (trusted, conditional, blocked)
- Signature-chain validation for A1 -> A2 -> Captain handoff
- Contributor agreement signature verification tied to UID
- Gate script that enforces protocol checks before acceptance

## Why This Is Not Redundant

Standard controls mostly validate repository and commit-level integrity.
This protocol validates collaboration behavior at content and handoff level.

Together they provide:
- provenance of commits
- provenance of in-file contributor intent
- deterministic acceptance or rejection rules
