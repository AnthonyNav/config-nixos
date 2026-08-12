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

This repository has four relevant profile layers: `base`, `development`,
`database-tools`, and a selected desktop style. Creative NVIDIA software is a
separate opt-in capability and must not be added to the ThinkPad profile.

## 3. Use Reproducible Project Environments

For a project, create a `flake.nix` and `.envrc`:

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

Run this after any flake or module change:

```sh
nix flake check --no-build --no-write-lock-file
```

Format Nix files and use the repository's reproducible maintenance shell:

```sh
nix fmt
nix develop
```

For a host-specific change, build without switching first:

```sh
nix build --no-write-lock-file \
  .#nixosConfigurations.victus.config.system.build.toplevel
```

For a Home Manager-only change, build the matching activation package:

```sh
nix build --no-write-lock-file .#homeConfigurations."anthony@victus".activationPackage
```

Changes to shared desktop or shell modules must cover all workstations:

```sh
for host in thinkpad victus desktop; do
  nix build --no-link --no-write-lock-file \
    ".#nixosConfigurations.$host.config.system.build.toplevel"
  nix build --no-link --no-write-lock-file \
    ".#homeConfigurations.\"anthony@$host\".activationPackage"
done
```

Only then apply locally with `nix-switch` or `hm-switch`. Once the PR is merged,
each workstation receives it with `nixos-update`. If an activation goes wrong,
select an earlier boot generation or run `sudo nixos-rebuild switch --rollback`.

## 6. Update Deliberately

An input update changes versions for every host that consumes the shared lock.
Keep it separate from functional refactors in its own PR. Do not run this as
part of a normal workstation update:

```sh
nix flake update
nix flake check --no-write-lock-file
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
an externally bootstrapped Kiro Gateway and a downloaded Blender GPU build.
Treat each exception as a contract: document its owner, pinned version or hash,
update method, secrets boundary, and a command that proves it works.

The goal is not to force everything into Nix immediately. The goal is to know
which state is reproducible, which is intentionally local, and how to recover
either one on a new machine. Kiro Gateway source is now pinned by the flake;
only its secrets and virtual environment remain local.
