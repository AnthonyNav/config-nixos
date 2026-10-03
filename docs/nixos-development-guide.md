# NixOS Development Guide

This guide is for using this configuration as a reproducible development
environment, not merely as a package installer.

## 1. Learn The Nix Model

Nix builds immutable outputs in `/nix/store`. A package, system configuration,
or development shell is a derivation whose inputs determine its result.

- A **generation** is an activated system or user-profile result.
- A **flake** declares inputs and outputs reproducibly.
- `flake.lock` pins every Nix input used by all workstations.
- Rollbacks work because old generations remain available until garbage
  collection removes them.

Useful inspection commands:

```sh
nix flake show
nix flake metadata
nix search nixpkgs <package>
nix why-depends <target> <dependency>
```

## 2. Separate System, Home, And Project Needs

Put root-required services, drivers, boot options, networking, and systemd
units in NixOS modules. Put user programs, shell configuration, desktop files,
and dotfiles in Home Manager. Put project-specific SDKs in each project's own
flake and enter them with `nix develop`.

Do not add a project dependency to this repository's shared profile unless all
workstations need it regularly.

From a Flutter project root, run `flutter-stop` after finishing Android builds
to stop Gradle daemons for the wrapper's Gradle version and release their memory.
The alias supplies Android Studio's bundled Java even when `JAVA_HOME` is unset,
and preserves the current directory and shell environment. Finish other Android
builds using that Gradle version first: the stop command is not project-scoped.
It does not delete APKs or build caches; the next build starts a daemon again.

This repository composes a shared `base`, a selected desktop style, and
host-selected roles under `profiles/home/roles`. Desktop and Victus share the
creative/ML development role. Creative NVIDIA software is a separate opt-in
capability and must not be added to the ThinkPad profile.

## 3. Use Reproducible Project Environments

Follow [the migration procedure](project-environments.md) before retiring global
SDKs or native-library workarounds. For a project, create a `flake.nix` and `.envrc`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.nodejs_22 pkgs.go ];
      };
    };
}
```

```sh
echo 'use flake' > .envrc
direnv allow
```

Use `nix develop` for an interactive shell, `nix run nixpkgs#tool` for a
one-off executable, and `nix shell nixpkgs#tool` for a temporary package set.

## 4. Read And Compose Modules

Nix modules merge option declarations. Learn these primitives before creating
new abstractions:

- `imports` composes modules.
- `lib.mkIf` gates a declaration.
- `lib.mkDefault` provides an overridable default.
- `lib.mkForce` is an exceptional final override.
- `assertions` reject unsupported feature combinations during evaluation.

Inspect an effective option with:

```sh
nixos-option services.pipewire.enable
```

Prefer small feature modules over conditionals scattered through a shared base
profile. In this repository, NVIDIA, PRIME, and fixed monitor behavior belong
to host overlays, not `home.nix`.

## 5. Validate Before Switching

Format and validate the current workstation after a Nix change:

```sh
nix-format
nix-check
```

The raw commands remain available inside the reproducible maintenance shell:

```sh
nix develop
nix fmt
nix flake check --no-build --no-write-lock-file
```

For a host-specific change, build without switching first:

```sh
nix-config build system victus
```

For a Home Manager-only change, build the matching activation package:

```sh
nix-config build home victus
```

Changes to shared desktop or shell modules must cover all workstations:

```sh
nix-check all
```

Do not activate a feature branch. Once the PR is merged, each workstation
receives it with `nix-update`. If activation goes wrong, inspect candidates with
`nix-generations` and run `nix-rollback`.

## 6. Update Deliberately

An input update changes versions for every host that consumes the shared lock.
Keep it separate from functional refactors in its own PR. Do not run this as
part of a normal workstation update:

```sh
nix-input-update
```

Build all hosts before switching any of them. Test NVIDIA changes on both
Victus and desktop; one uses PRIME and the other uses direct rendering. Test
Caelestia and Hyprland in a real graphical session after their inputs change.

## 7. Debug The Running System

Use systemd logs instead of guessing:

```sh
systemctl --user status <unit>
journalctl --user -u <unit> -b
journalctl -u <unit> -b
```

Compare the declared configuration, the evaluated option, and the active
generation. Check `nixos-rebuild list-generations` or
`home-manager generations` before deleting generations.

## 8. Keep Exceptions Visible

Not every useful tool is packaged declaratively. This repository currently has
a downloaded Blender GPU build, downloaded wallpapers, and a user-installed
Spec Kit CLI.
Treat each exception as a contract: document its owner, pinned version or hash,
update method, secrets boundary, and a command that proves it works.

The goal is not to force everything into Nix immediately. The goal is to know
which state is reproducible, which is intentionally local, and how to recover
either one on a new machine.
