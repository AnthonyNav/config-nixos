---
name: pre-pr-review
description: Use when reviewing changes before a pull request or commit. Finds production-impact regressions by checking the real code, contracts, and validation paths.
---

# Pre-PR Review

Review changed code with production impact as the priority.

## Required Checks

1. Read the intended change from the diff and recent commits.
2. Trace changed files to their callers, modules, configuration outputs, and
   external contracts.
3. Verify paths, option names, command forms, package availability, and error
   paths against the repository rather than assuming them.
4. Run the narrowest relevant validation. For this NixOS repository, evaluate
   the flake; build affected hosts when a system or feature profile changes.

## Output

List findings first, ordered by severity, with `file:line` references and the
observable impact. State explicitly when there are no findings and identify
remaining validation gaps. Do not turn a review into an implementation unless
the user asks for fixes.
