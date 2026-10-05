# Project Environments and macOS Plan

See [project-environments.md](project-environments.md) for the implemented
compatibility switches and per-project migration procedure. Six local migrations
are recorded in [project-migration-status.md](project-migration-status.md);
remaining consumers and removal of global fallbacks still require validation.

## Project environment goal

The machine should provide general development infrastructure while each
project declares the SDKs and toolchain versions it needs.

The existing direnv + nix-direnv configuration is the basis for this model.

Daily flow:

```text
cd project
  -> direnv loads project devShell
work normally
leave project
  -> project-specific toolchain leaves PATH
```

## Ownership boundary

Keep globally:

- Git/SSH;
- editors/IDEs;
- Docker/container runtime;
- direnv/nix-direnv;
- AI CLIs;
- general diagnostics;
- tools intentionally useful across projects.

Prefer project environments for:

- Go versions;
- Node.js versions;
- Rust toolchains;
- Python versions;
- project JDKs;
- project compilers/native libraries;
- data-science/Jupyter libraries.

Migration should be incremental. Do not remove a global toolchain until affected
projects have a working replacement.

## Project flake pattern

A new project should be able to contain:

```text
project/
├── flake.nix
├── flake.lock
├── .envrc
└── native project files
```

`.envrc` should normally use the flake. The project lock fixes the Nix inputs
for that project independently from the workstation configuration.

## Jupyter/native libraries

The current global Zsh workaround that injects native libraries into
`LD_LIBRARY_PATH` for Jupyter should eventually move into a data-science
project/devShell.

Reason: global library paths affect unrelated processes launched from the shell.

Do not remove the workaround until data projects are tested with the isolated
replacement.

## Flutter/Android

Flutter requires a pragmatic split because some Android/Flutter components are
mutable.

Preferred direction:

- Nix/Home Manager owns Android Studio, stable Android/JDK host infrastructure
  and native build tools where appropriate;
- FVM/project can own the Flutter version when that is more reliable;
- avoid multiple Flutter installations competing in PATH;
- verify Gradle, emulator, desktop and Android builds before removing the
  current working setup.

## Project templates

A separate future repository such as `dev-templates` may expose templates for:

- Rust;
- Go;
- web/Node;
- Flutter;
- Python/data science.

The desired workflow could be:

```text
nix flake init -t <templates>#rust
direnv allow
cargo init .
```

Keep templates separate from this fleet repository unless a strong ownership
reason appears.

## macOS goal

The detailed target architecture is in [macOS workstation plan](macos-workstation-plan.md).
The operational bootstrap/synchronization procedure is in
[macOS onboarding runbook](macos-onboarding.md).

A future Apple Silicon Mac should reuse the shared user/development/AI
experience while keeping OS-specific behavior separate.

Target shape:

```text
NixOS hosts -> NixOS modules + shared Home Manager
macOS host  -> nix-darwin modules + shared Home Manager
```

## Prerequisites before nix-darwin

1. Stop assuming every host is `x86_64-linux`.
2. Make system/platform a host property.
3. Replace inappropriate hardcoded `/home/<user>` references with
   platform-aware Home Manager/user paths.
4. Split Home Manager into common, Linux-specific and Darwin-specific behavior.
5. Allow host constructors that do not depend on Linux desktop modules.

Do not add a concrete Mac host before hardware/role requirements are known.

## Shared capabilities expected on macOS

Where packages/integrations support Darwin, reuse:

- Git/SSH identities;
- Zsh/shell behavior;
- Neovim/editor tooling;
- direnv/nix-direnv;
- AI CLIs;
- global AI context and skills;
- MCP registry/policy;
- RTK integration where supported.

macOS-native requirements such as Xcode remain platform-owned.

Homebrew may be managed declaratively for applications that are more appropriate
there, while Nix remains the source of truth for shared development tooling.

## Darwin validation

When nix-darwin is introduced:

- add Darwin-specific evaluation/build outputs;
- use a compatible macOS runner/builder for actual Darwin builds;
- do not claim Linux CI proves Darwin runtime behavior;
- validate macOS-specific launchd, GUI and Xcode-dependent workflows on the Mac.

## Acceptance criteria

- New projects can obtain language SDKs without modifying `config-nixos`.
- Leaving a project removes its project-specific toolchain from the active
  environment.
- Data/Jupyter native libraries no longer need global injection once migration
  is complete.
- Flutter migration preserves working Android/Gradle/emulator behavior.
- Shared configuration has no Linux-home-path assumption that blocks Darwin.
- A future Apple Silicon host can reuse common Home Manager and AI policy.
