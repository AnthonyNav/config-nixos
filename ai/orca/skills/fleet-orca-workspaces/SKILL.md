---
name: fleet-orca-workspaces
description: Work in an Orca-managed Fleet project or Git worktree, including opening an existing session, choosing an agent, or loading its Nix development environment.
---

# Fleet workspaces in Orca

Use this skill when the task concerns an Orca workspace or a project under
`~/Sync/Fleet/projects`. It supplies context, not permission to create sessions,
change credentials, publish code, or deploy a NixOS generation.

The directories under `~/Sync/Fleet/projects` coordinate multi-repo work. Read
the requested project's `project.json`, `.code-workspace` and relevant handoff
before choosing a component. Resolve each workspace folder path relative to the
`.code-workspace` file and confirm the resulting path exists. The coordination
folder itself is usually not a Git checkout; use `git -C <component-path>
rev-parse --show-toplevel` and inspect its branch and status. Some Kigo base
repositories under `~/dev/kigo/repos` are bare; operate from the actual worktree
under `~/dev/kigo/worktrees` instead. Never assume another project has this
layout.

On this NixOS host the CLI is `orca-ide`. If `ORCA_CLI_COMMAND` is set, use that
version-matched command instead. Check `status --json`, `repo list --json` and
`worktree list --json` before changing Orca state. Use exact `path:<absolute-path>`
or returned IDs to select an existing worktree. Register a component with
`repo add --path <checkout>` only when the user wants it in Orca and it is not
already registered. Use `terminal create --worktree path:<checkout> --focus`
only when asked to open a new terminal. To return to an existing agent session,
inspect `terminal list --worktree path:<checkout> --json` and use
`terminal switch --terminal <handle>`; do not start a duplicate agent or create
another Git worktree. If the session has exited or hibernated, inspect Orca's
resume state before starting a fresh one. Load the bundled
`skills get orca-cli` guide before using unfamiliar Orca commands. For
supervised multi-agent Runs, load `skills get orchestration --full` first.

For a new task, confirm the intended repository and base ref, inspect existing
changes, then create an independent Orca worktree only if requested. Keep one
agent's edits in its own worktree; inspect diffs before combining changes. Orca
worktrees separate files, not ports, containers, databases or credentials.
Inspect `.envrc` before allowing direnv; use the project's locked `nix develop`
environment for SDKs and tests. Do not install agent self-updates or activate a
NixOS feature branch.

Use the pinned `codex`, `claude`, `opencode` or `kiro-cli` already on PATH. Do not
launch extra agents or bypass their permission prompts merely because Orca
supports it. Follow the current repository's instructions and the user's
authorization for commits, publication and deployment.
