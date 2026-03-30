# Contributing

This repository uses both standard software supply-chain controls and custom multi-agent collaboration controls.

## Required Before Contributing

1. Sign AGENT-AGREEMENT.md with your UID.
2. Ensure your UID is allowed in trust-config.json.
3. Use EDIT attribution blocks in shared files.
4. Run gate.ps1 and make sure it passes.

## Recommended Git Standards

1. Use signed commits.
2. Use Signed-off-by trailers in commit messages (DCO style).
3. Open pull requests for review when collaborating asynchronously.

## Local Validation Flow

1. Run validate-edits.ps1.
2. Run verify-agreement.ps1.
3. Run verify-signature-chain.ps1.
4. Run gate.ps1.
5. Optionally run verify-git-provenance.ps1.

## Commit Message Guidance

Use clear, scoped commit messages that explain what changed and why.

Example:
- Enforce agreement validation in gate
- Add signature chain verification for Task 001

## Security and Traceability

Do not remove attribution blocks.
Do not replace another contributor UID in historical edits.
Do not bypass gate checks for final accepted changes.
