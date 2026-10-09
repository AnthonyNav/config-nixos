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
units in NixOS modules. On macOS, nix-darwin owns system policy and declared
native applications; services use launchd. Put user programs, shell configuration,
desktop files and dotfiles in Home Manager. Put project-specific SDKs in each
project's own flake and enter them with `nix develop`.

Do not add a project dependency to this repository's shared profile unless all
workstations need it regularly.

On NixOS, from a Flutter project root, run `flutter-stop` after finishing Android
builds to stop Gradle daemons for the wrapper's Gradle version and release their
memory.
The alias supplies Android Studio's bundled Java even when `JAVA_HOME` is unset,
and preserves the current directory and shell environment. Finish other Android
builds using that Gradle version first: the stop command is not project-scoped.
It does not delete APKs or build caches; the next build starts a daemon again.
On macOS, use the project's compatible JDK when stopping its wrapper instead
of assuming Android Studio's newest bundled Java is compatible. The
[macOS development workflow](macos-development-workflow.md) covers this boundary,
Xcode, FVM, containers and local credentials.

This repository composes one daily base, a selected desktop style and explicit
functional profiles under `profiles/home/`. Desktop and Victus select the same
profiles in the inventory. Creative software requires NVIDIA; daily-only devices
do not inherit SDKs or GPU packages. See [workstation-architecture.md](workstation-architecture.md).

## 3. Use Reproducible Project Environments

Follow [the migration procedure](project-environments.md) before retiring global
SDKs or native-library workarounds. For a project, create a `flake.nix` and `.envrc`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let systems = [ "x86_64-linux" "aarch64-darwin" ];
    in {
      devShells = nixpkgs.lib.genAttrs systems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.nodejs_22 pkgs.go ];
          };
        });
    };
}
```

```sh
cat .envrc              # review an existing file before changing or approving it
direnv allow           # only after reviewing its code and referenced setup
```

For a new file, put `use flake` in `.envrc`; preserve existing project setup.
The package versions above are examples: select SDKs against that project's
requirements and lockfile. Commit the flake, its lock and the reviewed `.envrc`
in the project repository, excluding caches and credentials. Test builds on
both platforms if both are supported; evaluation does not prove runtime health.

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
profile. NVIDIA and PRIME hardware belong to host modules; physical display
identities belong to the shared desk policy, not hostname-specific Home files.

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

For the registered Mac, build both Darwin system and Home without activation:

```sh
nix-config build all MacBook-Pro-de-Antonio
```

Changes to shared desktop or shell modules must cover every affected workstation.
The native host matrix can be built with:

```sh
nix-check all
```

This covers hosts matching the local CPU/OS. Obtain build results from compatible
Linux and Darwin builders when both platforms are affected; a skipped host is
not a passed build.

Do not activate a feature branch. Once the PR is merged, each workstation
receives it with `nix-update`. If activation goes wrong, inspect candidates with
`nix-generations` and run `nix-rollback`.

## 6. Update Deliberately

An input update changes versions for every host that consumes the shared lock.
Normally keep it in a dedicated PR. An explicitly approved combined PR may
include it in a separate dependency commit with all affected builds. Do not run this as
part of a normal workstation update:

```sh
nix-input-update
```

Build all hosts before switching any of them. Test NVIDIA changes on both
Victus and desktop; one uses PRIME and the other uses direct rendering. Test
Caelestia and Hyprland in a real graphical session after their inputs change.

## 7. Debug The Running System

On NixOS, use systemd logs instead of guessing:

```sh
systemctl --user status <unit>
journalctl --user -u <unit> -b
journalctl -u <unit> -b
```

On macOS, use `launchctl list`, `launchctl print gui/$(id -u)/<label>` for
user agents, and macOS Console/`log show` for runtime evidence. Inspect a
LaunchAgent's configured output/error files; a scheduled oneshot can have no
PID between runs while its last exit status is successful.

Compare the declared configuration, the evaluated option, and the active
generation. Check `nixos-rebuild list-generations` or
`home-manager generations` before deleting generations.
On Darwin, compare the declared build with `/run/current-system` and
`/nix/var/nix/profiles/system` separately from the user profile. A Linux build
cannot validate Darwin activation or an Apple SDK workload.

## 8. Keep Exceptions Visible

Blender's official GPU build and the curated wallpaper collection are now
fixed-hash Nix packages, downloaded during builds rather than activation.
Previous local copies remain user-owned. A user-installed Spec Kit CLI is still
an explicit exception.
Treat each exception as a contract: document its owner, pinned version or hash,
update method, secrets boundary, and a command that proves it works.

The goal is not to force everything into Nix immediately. The goal is to know
which state is reproducible, which is intentionally local, and how to recover
either one on a new machine.
