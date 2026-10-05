---
name: fleet-agent-orchestration
description: Coordinate authorized parallel coding or review in fleet workspaces, with a lead integrating isolated worker scopes and maintaining the portable handoff.
---

# Fleet agent orchestration

Use one agent for sequential or tightly coupled work. Additional workers are
useful when independent scopes or distinct expertise outweigh coordination cost,
and the task/session permits delegation. Do not infer delegation permission from
the presence of Orca or this skill.

The lead defines each worker's task, files, worktree and acceptance evidence,
coordinates shared ports/databases/containers, integrates changes, validates the
combined result and updates HANDOFF.md. Start with a ceiling of 2-3 workers per
host, reducing it for heavy builds or memory pressure.

Give each worker a separate worktree and one writer per overlapping file. A
worktree is Git separation, not a sandbox. Serialize shared runtimes and preserve
context-scoped credentials. Workers report changed files, validation and pending
work; they do not publish, merge or spawn more workers without authorization.

Use the pinned Orca CLI's version-matched orchestration skill when coordinating
Orca tasks. Inspect its supported commands before dispatch; no private Orca
database edits or assumptions about cross-host process transfer.

Before requesting review, verify the aggregate diff, remove task WIP history
through a coordinated authorized rewrite, run the relevant checks, and record
repository branches/commits and remaining limitations in the handoff.
