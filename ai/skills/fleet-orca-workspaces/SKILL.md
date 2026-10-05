---
name: fleet-orca-workspaces
description: Coordinate Orca workspaces, agent worktrees and project environments across the NixOS workstations with explicit work/personal identities.
---

Resolve the logical workspace with fleet-info or workspace-context status and
read its HANDOFF.md before resuming tasks. workspace open imports its repositories
using Orca's supported CLI; the shared folder/handoff supplies the multi-repo group.
For remote runtime preparation and acceptance, read docs/orca.md in the fleet repo.

Inspect existing Orca tabs, workspaces, repositories and Git worktrees before
creating anything. On Linux use the pinned `orca-ide` CLI. First load the
version-matched guide with `orca-ide skills get orca-cli`; consult orchestration
and computer-use guides only when that work is authorized. Prefer structured
CLI output and commands documented by the installed version. Do not guess API
endpoints or change opaque Orca state.

Use `workspace-context status` and the project's actual Git common directory to
check identity. Canonical roots are `~/Workspace/work` and
`~/Workspace/personal`; `~/nixos-config` and `~/projects` remain personal
compatibility roots. A neutral session requires explicit context before using
credentials. Mobile approval does not change the chosen identity. Wrappers
route credentials; same-user processes are not an OS security isolation layer.

Read project instructions, flake/.envrc, lockfiles and CI. Use its existing
`nix develop`/direnv environment. Inspect `.envrc` before allowing it. Keep global
Flutter/Android and legacy SDK compatibility until consumers have replacements.

When parallel agent work is explicitly authorized, use separate branches and
Git worktrees. Never concurrently edit the same checkout. Worktrees share Git
metadata and do not isolate ports, Docker sockets, containers, databases,
credentials or caches; assign those resources deliberately. Each agent session
belongs to one work/personal context. Start a separate session to change identity.

Keep mutable Orca skills owned by Orca; run `orca-skills-sync --dry-run` before
an explicitly requested refresh. Fleet skills are Home Manager links. Never
self-update Nix-owned applications, activate a feature branch, publish a skill
link or enable a permanent remote runtime just to coordinate agents.

Prefer Manual agent permissions. Respect customized launch arguments and have
the owner review any approval-bypass flags. Validate Android approvals,
questions and reconnects against the deployed versions. Async Codex questions
may lack a structured mobile card (stablyai/orca#20073): use the supported
Terminal View/plain reply flow, and never fabricate a blocking approval state.
