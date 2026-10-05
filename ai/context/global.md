# Managed development environment

This host uses declarative Nix configuration. Inspect the existing modules and
profiles before adding abstractions. Put system services/drivers in NixOS,
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
