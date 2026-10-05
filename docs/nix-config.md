# Nix Configuration Commands

`nix-config` is the canonical maintenance interface for this repository. It
centralizes repository and host selection, validation, build, deployment,
rollback, and garbage-collection policy in one shell-independent executable.

## Command Families

| Command | Purpose |
|---|---|
| `nix-status` | Show checkout, upstream, and active system status. |
| `nix-format [--check]` | Format Nix sources or verify formatting. |
| `nix-check [current\|all]` | Run native flake checks and build the selected system and Home Manager outputs. |
| `nix-config build system HOST` | Build one NixOS or nix-darwin output without activation. |
| `nix-config build home HOST` | Build one Home Manager output without activation. |
| `nix-config build all HOST` | Build both outputs for one host. |
| `nix-config build all all` | Build workstation outputs matching the native CPU/OS system. |
| `nix-config build iso` | Build the installer ISO. |
| `nix-switch` | Validate and activate the system only when local `main` exactly matches `origin/main`. |
| `nix-home-switch` | Validate and activate Home Manager under the same published-main policy. |
| `nix-update` | Fetch and fast-forward reviewed `main`, validate the current host, and activate it. |
| `nix-input-update` | Update `flake.lock` on a clean feature branch and validate every host. |
| `nix-generations [system\|home]` | List rollback candidates. |
| `nix-rollback` | Roll back the native system generation. |
| `nix-config rollback home PATH` | Activate a selected Home Manager generation path. |
| `nix-clean [AGE]` | Delete generations older than `AGE`; the default is `30d`. |

The short commands are thin wrappers over the corresponding `nix-config`
subcommand. `nixos-update` and `hm-switch` remain temporary compatibility
shims and print their replacements before continuing.

Inventory selects the platform, CPU/OS and user for each output. Darwin detects
the LocalHostName with `scutil`, builds `darwinConfigurations.<host>.system`,
and activates through `darwin-rebuild`; NixOS keeps its existing behavior.
`nix-config test system` remains NixOS-only. Explicit non-native build selectors
can use a separately configured builder. No Mac is registered yet; the Darwin
checks validate preparation without activating a fixture.

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


Every declared fleet host is a daily workstation with a Home Manager output.
`build all all` and `check all` cover both systems and both Home outputs.
The installer is not included in the workstation build matrix.
