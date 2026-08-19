---
name: pre-pr-review
description: Use when reviewing changes before a pull request or commit. Runs an adaptive diff-first review with auto, focused, and deep modes, escalating scope and validation by risk.
---

# Pre-PR Review

Review changed code with production impact as the priority. Prefer attributable
diff evidence over repeating broad repository reconnaissance.

## Modes

Use `auto` when no mode is requested.

- `auto`: start from the current diff, classify risk, and expand context or
  validation only when the evidence requires it. Escalate to `deep` for HIGH
  risk or unresolved cross-cutting uncertainty.
- `focused`: incremental re-review after fixes. Review the delta since the last
  trustworthy reviewed HEAD, unresolved findings, and only the context
  invalidated by that delta. If no trustworthy prior snapshot exists, fall
  back to `auto`.
- `deep`: exhaustive review of the complete current diff and all materially
  affected callers, contracts, configuration, tests, security boundaries, and
  failure paths.

An explicit mode changes review breadth, not safety requirements. Never skip a
required check because a narrower mode was requested.

## Review Snapshot

Before analysis, capture an immutable snapshot of:

- the intended base and merge-base;
- current HEAD SHA;
- changed commits and files;
- diff and diff stat;
- validation evidence attributable to that HEAD.

Resolve the base from PR or upstream metadata when available; do not assume a
branch name when the repository says otherwise.

Key reusable evidence by commit SHA, not by branch name. Reuse previous
reconnaissance or validation only when its base, HEAD, inputs, and relevant
files are unchanged. If HEAD changes during the review, invalidate stale
results and repeat every affected check before issuing a verdict.

## Diff-First Scope

1. Read the file list, diff stat, changed commits, and actual diff first.
2. Apply the repository's `risk-classification` definitions and use the
   highest applicable risk. Risk can expand scope; it must never shrink it.
3. Build an impact map only from changed behavior: callers, imports, modules,
   generated configuration, external contracts, tests, and operational
   boundaries.
4. Read surrounding repository context when the impact map or an invalidation
   rule requires it. Do not roam the repository without a review question.
5. Verify claims against current files and command evidence rather than an
   implementation summary.

## Context Invalidation

Treat cached context as invalid when a change can alter the assumptions behind
it. Re-open the affected context when changes touch, at minimum:

- public options, schemas, commands, interfaces, paths, or generated outputs;
- flake inputs, dependency/package selection, shared modules, host features, or
  module wiring;
- authentication, secrets, permissions, networking, services, deployment, or
  other security boundaries;
- CI/workflows, agents, commands, skills, validation policy, or build logic;
- error handling, persistence/state, destructive behavior, or external
  contracts.

In `focused`, inspect the new delta plus every surface invalidated by it. Do not
repeat unchanged, already-resolved findings merely because they existed in the
previous review.

## Risk-Based Validation

Run the narrowest trustworthy checks first and escalate by evidence.

### Tier 0 - Integrity and Static Review

- Confirm the snapshot is attributable to the intended base and HEAD.
- Inspect the diff for syntax errors, incorrect names/paths, unsafe defaults,
  leaked secrets, missing error handling, and obvious regressions.
- Confirm no unrelated or baseline-contaminated changes are being attributed
  to the implementation.

### Tier 1 - Targeted Checks

- Run the repository-provided evaluator, linter, parser, or focused tests that
  directly cover the changed files.
- Verify option names, command forms, package availability, and generated
  values against the repository instead of assuming them.

### Tier 2 - Affected-System Checks

- Run tests or builds for components whose behavior or shared configuration
  changed.
- For this NixOS repository, evaluate the flake and build affected hosts when a
  system module, shared module, package selection, or host feature profile can
  change their output.

### Tier 3 - Deep Checks

Use for `deep`, HIGH-risk changes, or unresolved evidence from lower tiers.
Inspect and validate relevant integration paths, security/failure boundaries,
cross-host effects, and other materially affected consumers.

Do not run expensive broad checks before the diff establishes a reason. A
failed required check is evidence to investigate; a required check that cannot
be run belongs in validation gaps and prevents an `approved` verdict.

## Independent Evidence

Parallelize independent read-only investigations when useful. Give each
investigation the same immutable snapshot and a narrow question. Share raw
evidence such as file references, diff hunks, command output, and test results;
do not share conclusions before independent checks complete, so one review
path does not anchor another.

## Finding Rules

Prioritize correctness, security, regressions, scope deviations, broken
contracts, unsafe failure modes, and missing required validation.

- Report only findings supported by current diff/context evidence.
- Give each finding a `file:line` reference and observable impact.
- Do not elevate style preferences or unrelated pre-existing issues.
- Mention a pre-existing issue only when the changed code makes it newly
  reachable, worse, or relevant to merge safety.
- Do not turn the review into implementation unless the user asks for fixes.

## Output

Start with one compact snapshot line:

`Review: mode=<effective-mode> risk=<LOW|MEDIUM|HIGH> base=<sha> head=<sha>`

Then output exactly these sections:

### Blockers

List merge-blocking findings ordered by severity, with `file:line` and
observable impact, or `None`.

### Non-blocking

List useful non-blocking improvements with `file:line`, or `None`.

### Validation gaps

List each missing, stale, failed, or unverifiable required check, or `None`.

### Verdict

Use exactly one of:

- `changes-required` when any blocker exists;
- `unverified` when the snapshot is incomplete, HEAD changed without refreshed
  evidence, attribution is uncertain, or required validation is missing or
  failed without resolution;
- `approved` only when there are no blockers and every required validation has
  successful evidence attributable to the reviewed HEAD.

Non-blocking findings alone do not prevent `approved`.
