# Signature Chain Protocol

Version: 1.0

This protocol adds role-based handoff accountability for shared collaboration artifacts.

## Required Roles

- `a1-scaffold` signed by `a1-uuid`
- `a2-ack` signed by `a2-uuid`
- `captain-approval` signed by `b1c3-uuid`

## Signature Artifact Format

Each signature artifact must include:

- `role`
- `payload_path`
- `payload_sha256`

And one signed block:

<!-- CHAIN-SIGNATURE:a1-scaffold:a1-uuid:2026-03-30T09:00:00Z:4b66edbf79d9c096275c26852758755f6601a20b2ac8be331173d5c371bf4dd0 -->
A1 authored Task 001 scaffold handoff for shared file.

## Validation Rules

1. All three role artifacts exist.
2. Role-to-UID mapping is correct.
3. Signature hash matches exact claim line.
4. Timestamp is parseable and within policy bounds.
5. All signatures reference the same payload path and payload hash.
6. Signature timestamps are monotonic: A1 <= A2 <= Captain.

## Gate Rule

Proceed only if both checks pass:
- edit attribution validation (`validate-edits.ps1`)
- signature-chain verification (`verify-signature-chain.ps1`)
