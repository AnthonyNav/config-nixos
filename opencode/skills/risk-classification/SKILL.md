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

- LOW may continue without approval in `fast` or `controlled` after the
  contract is shown.
- MEDIUM requires a human approval gate in `controlled`, and escalates
  `fast` to that gate.
- HIGH always requires a human approval gate before editing. Escalate `fast`
  to the architecture/high-risk gate and show the risky decisions.
- `architecture` always investigates, shows architectural decisions, and
  stops for approval before editing regardless of the classified level.
