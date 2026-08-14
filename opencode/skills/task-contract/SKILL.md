---
name: task-contract
description: Use when converting a software request into a brief executable task contract before implementation.
---

# Task Contract

Create a short, versioned contract before implementation. Output only these
headings and their concise contents:

## Revision

An unambiguous identifier containing revision number, baseline HEAD prefix, and
task slug, such as `C1-a1b2c3d4-opencode`; include the clean-tree baseline it is
bound to and the revision it supersedes when applicable.

## Objective

The single outcome the task must achieve.

## Scope

Files, components, interfaces, and behavior that may change.

## Out of scope

Explicit exclusions that prevent scope drift.

## Acceptance criteria

Observable conditions that prove the objective is complete.

## Risk

The classified level and the concrete reason.

## Validation

Relevant checks, tests, builds, or inspections. Mark each as `required` or
`optional` and as `agent` or `manual`.

## Human decisions

Decisions requiring the user, or `None` when the contract has none. A new
architecture, scope, or risk decision requires a new revision and gate.

Do not create line-by-line plans, duplicate repository investigation, or add
extra contract sections. Keep the contract small enough to pass between
agents without repeating the full context.
