# Nix Configuration Commands

`nix-config` is the canonical maintenance interface for this repository. It
centralizes repository and host selection, validation, build, deployment,
rollback, and garbage-collection policy in one shell-independent executable.

## Command Families

| Command | Purpose |
|---|---|
| `nix-status` | Show checkout, upstream, and active system status. |
| `nix-format [--check]` | Format Nix sources or verify formatting. |
| `nix-check [current\|all]` | Run executable flake checks and build the selected NixOS and Home Manager outputs. |
| `nix-config build system HOST` | Build one NixOS output without activation. |
| `nix-config build home HOST` | Build one Home Manager output without activation. |
| `nix-config build all HOST` | Build both outputs for one host. |
| `nix-config build all all` | Build all workstation outputs. |
| `nix-config build iso` | Build the installer ISO. |
| `nix-switch` | Validate and activate the system only when local `main` exactly matches `origin/main`. |
| `nix-home-switch` | Validate and activate Home Manager under the same published-main policy. |
| `nix-update` | Fetch and fast-forward reviewed `main`, validate the current host, and activate it. |
| `nix-input-update` | Update `flake.lock` on a clean feature branch and validate every host. |
| `nix-generations [system\|home]` | List rollback candidates. |
| `nix-rollback` | Roll back the NixOS generation. |
| `nix-config rollback home PATH` | Activate a selected Home Manager generation path. |
| `nix-clean [AGE]` | Delete generations older than `AGE`; the default is `30d`. |

The short commands are thin wrappers over the corresponding `nix-config`
subcommand. `nixos-update` and `hm-switch` remain temporary compatibility
shims and print their replacements before continuing.

## Safety Model

Formatting, checks, and builds may run on a feature branch and never activate a
generation. `switch`, `test`, and normal Home Manager activation require all of
the following:

- a clean checkout;
- branch `main` tracking `origin/main`;
- a fresh fetch proving that `HEAD` exactly equals `origin/main`;
- successful formatting, executable flake checks, and affected builds.

Pure flake evaluation cannot see untracked files. Checks and builds therefore
stop with an explicit message until new files are added or marked with
`git add --intent-to-add`.

`nix-update` is the only command that updates the checkout. It rejects local
commits and divergence, accepts only a fast-forward from `origin/main`, and
then applies the same validation before activation. Input updates are excluded
from deployment and require a separate feature branch.

Rollbacks are an intentional recovery exception: they operate on an existing
generation and do not require Git or a successful current evaluation.

## Before First Activation

The command is also exposed as a flake app, so a checkout that has not installed
it can validate itself:

```sh
nix run .#nix-config -- check all
```

On an existing workstation receiving these commands for the first time, update
a clean `main` and use the old `nix-switch` once. On a new installation, use the
documented direct `nixos-rebuild switch --flake ...` bootstrap command.


For fleet hosts with `homeModules = null`, `build all`, `check`, and
`deploy` validate/build only the NixOS system. `build home all` selects only
hosts with Home Manager, while `build home <host>` rejects an absent Home
output. The inventory-derived host list includes servers as well as workstations.
