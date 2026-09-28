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

Prefer RTK for supported human-readable command output. Keep original commands
when output is parsed, exact output matters, or RTK has no equivalent. Never
retry a command automatically merely because an RTK-wrapped execution failed.
