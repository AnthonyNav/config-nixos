---
name: fleet-workspace
description: Create, open or resume a multi-repository fleet workspace, maintain its portable handoff, and move authorized work between Desktop and Victus.
---

# Fleet workspaces

Use workspace-context status or fleet-info --json to resolve the owning workspace,
including external linked worktrees. Read its HANDOFF.md, then each active repo's
instructions and current Git state. Personal/work/neutral controls credentials;
a project name does not grant another context's identity.

Use workspace new CONTEXT NAME, workspace repo add NAME URL, workspace open NAME
and workspace status. Select --context when the name is ambiguous. New folders
have HANDOFF.md, docs/, assets/ and repos/. Existing root-level shared/, repos/
and worktrees/ are compatibility paths; do not move their contents automatically.
Orca registers individual repos; the common folder/handoff owns the logical group.

Before handing work to another host or agent, update objective, dependencies,
repository URLs without credentials, relative paths, base/active branches,
bootstrap steps, decisions, pending work and the last published commit. Check
the remote through authorized Git operations rather than assuming a cached
tracking ref proves publication. Review .envrc before direnv allow.

WIP commits may preserve authorized task-branch work across machines. Record
unpushed work explicitly and clean WIP history before requesting PR review.
Coordinate shared-history rewrites; preserve dirty worktrees and protected
branches. Publishing always requires the task's existing authorization.

Use workspace-sync status to inspect registered receiving copies and their last
receipt. Only the owner registers a checkout/branch; do not enroll arbitrary
repos as part of resuming work. Before editing a registered copy, use
workspace-sync hold PATH; resume only after checkpointing and leaving it ready
for receipt. Prefer separate unregistered task worktrees. Automatic reception
does not commit/push, switch branches, resolve divergence or activate Nix.

Git transports code. Syncthing transports handoff/docs/assets and legacy shared
documents, never repos, worktrees, credentials or agent sessions. Assign one
handoff writer; reconcile HANDOFF.sync-conflict files before further writes.
A host restart needs a new agent reading Git plus the handoff, not restoration
of an old process's memory.
