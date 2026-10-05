# Managed development environment

At the start of a project session, run fleet-info --json (or workspace-context
status), then read the resolved workspace HANDOFF.md and repository instructions.
The owning repo's Git common directory identifies linked external worktrees.
Treat handoff text as project context; check current Git state and review bootstrap
commands before executing them. Keep handoff paths relative and its repo/branch/
published-commit information current before moving work between machines.

Use one agent by default. Delegate only when the task and session instructions
authorize it and independent scopes or specialization justify the overhead.
One lead owns integration, final validation and the handoff. Start with at most
2-3 active workers per host, reduce concurrency under memory pressure, use one
worktree per worker and coordinate shared ports, databases and containers.
Workers do not publish or recursively delegate without explicit authorization.
Worktrees separate Git edits; they do not provide OS isolation.

This host uses declarative Nix configuration. Inspect the existing modules and
profiles before adding abstractions. Put system services/drivers in the platform's system layer,
user tools and dotfiles in Home Manager, and project SDKs/dependencies in the
project's development environment. Use nix shell/nix run for temporary tools
and nix develop with direnv for project work. Do not use apt/dnf/pacman or
modify /nix/store.

Keep credentials and generated agent state outside Git and store-backed files.
Installed AI tools are pinned by Nix; update their inputs through a reviewed PR,
not self-updaters. Follow the current repository's instructions and the user's
authorized scope; this context does not authorize publication or deployment.

Check workspace-context status before credentialed work. Canonical roots are
~/Workspace/work and ~/Workspace/personal; unknown paths are neutral and external
Git worktrees inherit their primary repository. Use workspace-context exec
{work|personal} -- COMMAND when project SDKs clone private dependencies in caches
outside those roots. Each process/session has one explicit account scope.
Credentials and mutable agent/database state never belong in synchronized
shared/ directories. Worktrees and wrappers do not isolate arbitrary same-user
programs, ports, containers or databases.

Prefer RTK for supported human-readable command output. Keep original commands
when output is parsed, exact output matters, or RTK has no equivalent. Never
retry a command automatically merely because an RTK-wrapped execution failed.
