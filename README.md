# Multi-Agent Collab Test

Shared workspace for founder and AI agents to collaborate with explicit accountability.

This folder is intended to be its own repository and belongs on:
https://github.com/B1C3Game/multi-agent-collab-test

Every edit is attributed with a UID, timestamp, and intent.

## Purpose

Test whether agents and humans can work on the same files, trust each other's edits, and maintain clear accountability across network boundaries.

## Edit Attribution

Every edit block should include this header:

<!-- EDIT
UID: agent-or-person-uuid
TIMESTAMP: 2026-03-30T19:14:00Z
INTENT: short reason for the edit
EDITOR: name or agent identifier
-->

Then the actual content.

## Trust Rules

- You know who edited what.
- You can verify the edit chain.
- You can decide whether to trust an editor.
- Untrusted or unknown editors can be flagged.

## Collaboration Loop

1. Founder writes task description.
2. A1 reads and writes scaffold.
3. Founder reviews and approves or requests changes.
4. A2 implements.
5. Founder tests and verifies.
6. Full chain is visible and auditable.

## File Structure

multi-agent-colab-test/
- README.md
- 0.md
- SHARED.md
- trust-config.json
- SIGNATURE-CHAIN.md
- signatures/
	- task-001-a1-signature.md
	- task-001-a2-signature.md
	- task-001-captain-signature.md
- sync-script.ps1
- validate-edits.ps1
- verify-agreement.ps1
- verify-signature-chain.ps1
- gate.ps1

## Current Test

Status: live test setup

Participants:
- B1C3 (founder)
- Wijak (A1 scaffolder)
- Copilot (A2 builder)

## Standards Alignment

This project does not replace existing standards. It layers on top of them.

- Standard layer: git history, signed commits, DCO-style sign-off, CODEOWNERS review.
- Protocol layer: UID-attributed edits, trust-policy checks, signature-chain checks, agreement checks.

See:
- STANDARDS-MAPPING.md
- CONTRIBUTING.md
- .github/CODEOWNERS

## Recommended Local Flow

1. Run validate-edits.ps1 to validate UID attribution and trust policy.
2. Run verify-signature-chain.ps1 to validate A1 -> A2 -> Captain handoff.
3. Run verify-agreement.ps1 to ensure trusted UIDs signed AGENT-AGREEMENT.md.
4. Run gate.ps1 to enforce all required checks.
5. Optional: run verify-git-provenance.ps1 for commit signature and DCO visibility.
6. Optional: run sync-script.ps1 for periodic git sync.

## Commands

Validate edit attribution:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "validate-edits.ps1" -FilePath "SHARED.md" -TrustConfigPath "trust-config.json"
```

Validate signature chain:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "verify-signature-chain.ps1"
```

Validate contributor agreement:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "verify-agreement.ps1"
```

Run gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "gate.ps1"
```

Optional git provenance checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "verify-git-provenance.ps1"
```

## Evidence

- Baseline edit validation: `evidence/validation-latest.json`
- Baseline signature-chain validation: `evidence/signature-chain-T1.json`
- Baseline agreement validation: `evidence/agreement-T1.json`
- Baseline gate pass: `evidence/gate-T3.json`
- Tampered signature gate fail: `evidence/gate-T2.json`
- Tampered agreement gate fail: `evidence/gate-T4.json`
