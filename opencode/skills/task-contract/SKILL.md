---
name: task-contract
description: Use when converting a software request into a brief executable task contract before implementation.
---

# Task Contract

Create a short contract before implementation. Output only these headings and
their concise contents:

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

Relevant checks, tests, builds, or inspections to run.

## Human decisions

Decisions requiring the user, or `None` when the approved LOW task has none.

Do not create line-by-line plans, duplicate repository investigation, or add
extra contract sections. Keep the contract small enough to pass between
agents without repeating the full context.
