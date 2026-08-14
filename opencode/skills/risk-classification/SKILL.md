---
name: risk-classification
description: Use when classifying software task risk and deciding whether a mode must escalate to human approval.
---

# Risk Classification

Classify the task using the highest applicable level. A requested mode may be
escalated by the detected risk, but risk may never be downgraded automatically.

## LOW

- Documentation.
- Small, isolated changes.
- Easily reversible modifications.
- No secrets, deployment, or shared interfaces.

## MEDIUM

- Shared modules.
- Dependencies.
- Plugins.
- Build configuration.
- Behavior shared between hosts or components.

## HIGH

- Secrets, authentication, or security.
- Infrastructure or deployment.
- Migrations.
- Destructive changes.
- Cross-cutting architecture.

## Gates

- LOW may produce a ready contract in `fast`.
- MEDIUM escalates `fast` to `controlled`.
- HIGH escalates any lower mode to `architecture` and must expose every risky
  decision in the contract.
- `controlled` resolves required alternatives and decisions before declaring
  the contract ready.
- `architecture` always investigates and records architectural decisions.
- No mode edits directly. Approval is the user's separate invocation of
  `/work-apply <revision>` for the exact ready revision.
