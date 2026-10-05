# macOS workstation onboarding and synchronization runbook

This guide describes how to bootstrap an Apple Silicon Mac and keep its
development environment aligned with the NixOS fleet.

It assumes the Darwin implementation described in
[macOS workstation portability plan](macos-workstation-plan.md) has been merged.

## 0. Before touching the Mac

From a healthy fleet workstation:

1. Ensure the configuration repository is pushed and clean.
2. Verify current `main`.
3. Review which workspaces should exist on the Mac.
4. Ensure every active workspace has a current `HANDOFF.md`.
5. Push any required unfinished state as an authorized WIP task branch.
6. Never copy SSH/AWS/GitHub/agent secrets into Syncthing.

The Mac is reconstructed from declarations + remotes + handoffs, not from a
filesystem clone of another machine.

## 1. Basic macOS preparation

On the Mac:

- finish normal macOS onboarding;
- enable FileVault;
- install all current macOS updates;
- set the desired computer/local hostname;
- install Xcode Command Line Tools:

```sh
xcode-select --install
```

Confirm Apple Silicon:

```sh
uname -m
# arm64
```

The Nix platform will be `aarch64-darwin`.

## 2. Install Tailscale first

Install Tailscale's official **Standalone** macOS app.

Sign into the existing tailnet and approve the Mac according to current tailnet
policy.

Enable the built-in CLI integration from Tailscale settings, then verify:

```sh
tailscale status
tailscale ip
```

Do not install both App Store and Standalone variants.

Tailscale provides private connectivity to Desktop/Victus/Orca; it does not
replace Git or Syncthing.

## 3. Install Nix

Use the fleet-selected Nix installer.

For parity with the existing NixOS fleet, the default implementation should use
upstream Nix unless the Darwin implementation explicitly chooses Lix.

One current official Nix installer path is:

```sh
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install
```

If the repository adopts Lix instead, document that choice in the Darwin host
and use it consistently; do not mix installers casually.

Open a new terminal and verify:

```sh
nix --version
nix store ping
```

## 4. Bootstrap the configuration repository

Before managed Git identities exist, clone the public configuration repository
using public HTTPS into a temporary/bootstrap-safe location:

```sh
mkdir -p "$HOME/Workspace/personal/repos"
git clone https://github.com/AnthonyNav/config-nixos.git   "$HOME/Workspace/personal/repos/config-nixos"
cd "$HOME/Workspace/personal/repos/config-nixos"
git switch main
```

Do not copy the NixOS checkout with Syncthing.

## 5. First nix-darwin activation

The repository should expose the real Mac host as a Darwin flake output, e.g.:

```text
darwinConfigurations.macbook
```

For the first installation, use nix-darwin's bootstrap runner against the
repository flake. The implementation should document the exact host selector.

Conceptually:

```sh
sudo nix run nix-darwin/master#darwin-rebuild --   switch --flake .#macbook
```

After nix-darwin is installed, normal updates should use the repository-managed
wrapper or:

```sh
sudo darwin-rebuild switch --flake .#macbook
```

Never activate a feature branch as the normal workstation configuration.

Expected first activation:

- nix-darwin system policy;
- common + Darwin Home Manager;
- workspace tools;
- shell configuration;
- shared AI context/skills;
- supported CLIs;
- Syncthing user service adapter;
- declared native package/cask ownership.

macOS may request permissions for native applications. Grant only permissions
required by the documented workflow.

## 6. Create local credentials

Credentials are intentionally not synchronized.

### SSH

Create/import authorized work and personal SSH keys using the fleet's declared
paths.

Verify without printing private material:

```sh
identity-doctor
```

### GitHub CLI

Authenticate each context separately:

```sh
gh-login personal
gh-login work

gh-whoami personal
gh-whoami work
```

### AWS

Configure/login independently:

```sh
aws-profile-setup personal
aws-profile-setup work

aws-login personal
aws-login work

aws-whoami personal
aws-whoami work
```

### Agents

Log into Codex/Claude/OpenCode/Kiro/other supported agents locally as needed.

Do not synchronize their token/session databases from Linux.

## 7. Install/validate Orca

Use the native Apple Silicon Orca distribution.

If the Darwin configuration chooses Homebrew ownership, manage the official
Orca tap/cask declaratively rather than installing a second copy manually.

At first launch:

- do not import/overwrite managed fleet instructions blindly;
- verify the existing `~/.agents/skills` layer;
- run the approved Orca skill sync helper if configured.

Validate:

```sh
ai-doctor
fleet-info --json
```

Then connect Orca on the Mac to Desktop's optional Remote Orca Server over
Tailscale.

The Mac must also work locally when Desktop is offline.

## 8. Pair Syncthing

The Darwin implementation should start Syncthing as a user LaunchAgent through
the declarative Home Manager adapter.

Do not manually create a second set of folder rules.

Pair the new device with the existing fleet and verify the declared folders:

```text
fleet-work
fleet-personal
```

Before accepting/resuming synchronization, inspect the effective ignore rules.

The expected behavior is:

```text
SYNC:
- <workspace>/HANDOFF.md
- <workspace>/docs/**
- <workspace>/assets/**
- approved shared files

DO NOT SYNC:
- repos/**
- worktrees/**
- .git/**
- .direnv/**
- node_modules/**
- .venv/**
- build/cache output
- credentials/secrets
- agent/Orca state
```

If employer policy restricts work data on the Mac, remove the Mac from the work
folder's host allowlist instead of weakening the global ignore model.

## 9. Reconstruct workspaces

Once handoffs/docs/assets have synchronized:

```sh
workspace status <name> --context personal
workspace status <name> --context work
```

For each workspace, read `HANDOFF.md`.

Clone/fetch the repositories listed there:

```sh
workspace repo add <workspace> <remote> --context <work|personal>
```

or use the exact documented clone/fetch commands.

Then:

- fetch all required branches;
- switch to the active branch/WIP branch;
- verify expected remote SHA;
- read repo-level instructions;
- authorize `.envrc` only after review;
- enter the project environment.

No source repository needs Syncthing.

## 10. Daily synchronization model

Use this ownership model:

```text
config-nixos   -> Git
source repos   -> Git
WIP progress   -> temporary WIP commit + push/fetch
HANDOFF/docs   -> Syncthing
credentials    -> local only
agent state    -> local only
Orca sessions  -> local/remote runtime, never Syncthing
```

### Before switching machines

1. Update `HANDOFF.md`.
2. Ensure all repos/active branches are listed correctly.
3. Commit/push meaningful progress.
4. If unfinished work must move, create/push a temporary `WIP: ...` commit.
5. Wait for Syncthing to finish the handoff/docs sync.

### On the destination Mac

1. Wait for the workspace handoff to sync.
2. Run `workspace status`.
3. Fetch the listed repos.
4. Checkout the listed active branches.
5. Continue.

Before PR review/audit/merge:

- clean/squash WIP commits;
- produce meaningful reviewable history.

## 11. Keeping the Mac configuration updated

Normal configuration updates:

```sh
cd "$HOME/Workspace/personal/repos/config-nixos"
git fetch origin
git switch main
git pull --ff-only

# validate first
nix flake check --no-build --no-write-lock-file

# then activate reviewed main
sudo darwin-rebuild switch --flake .#macbook
```

The final implementation should provide a Darwin equivalent to the fleet's
current `nix-update`/doctor workflow so the user does not have to remember
platform-specific commands.

Do not use application self-updaters for binaries owned by Nix/nix-darwin.

Native applications explicitly owned by Homebrew/platform policy follow their
documented update path.

## 12. Health check

After onboarding or a significant update:

```sh
workspace-context doctor
identity-doctor
ai-doctor
fleet-info --json
tailscale status
syncthing --version
```

Also validate manually:

- work Git push/fetch;
- personal Git push/fetch;
- neutral commit refusal;
- GitHub/AWS context separation;
- one Syncthing handoff change;
- one workspace reconstructed from handoff;
- one local agent session;
- one Orca remote session against Desktop;
- one project `nix develop`.

## 13. Recovery/reinstall principle

A fresh Mac should require only:

```text
macOS
-> Tailscale
-> Nix
-> clone config-nixos
-> nix-darwin activation
-> local credential logins
-> Syncthing pairing
-> HANDOFF sync
-> Git clone/fetch
-> continue
```

If reinstalling the Mac requires copying hidden agent state or Git repositories
from another workstation, the design has regressed.

## References

- nix-darwin: https://github.com/nix-darwin/nix-darwin
- Home Manager nix-darwin module:
  https://nix-community.github.io/home-manager/installation/nix-darwin.html
- Nix installer: https://github.com/NixOS/nix-installer
- Tailscale macOS:
  https://tailscale.com/docs/install/mac
- Syncthing macOS autostart:
  https://docs.syncthing.net/users/autostart.html
- Orca install:
  https://www.onorca.dev/docs/install
