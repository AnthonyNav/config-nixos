# Orca on the workstations

Orca is an optional Home Manager application, enabled on Victus, Desktop and
ThinkPad with `fleet.ai.orca.enable = true` in each host's Home Manager overlay.
The module defaults to `false`; the installer and headless hosts do not acquire
a GUI dependency.

## Package and ownership

`packages/orca-ide.nix` pins the upstream Linux x86_64 `.deb` by version and
SHA-256. Nix extracts its contents without running Debian maintainer scripts.
`autoPatchelfHook` links the vendor Electron and native modules to Nix libraries.
`dpkg` is a build dependency only. The package runs natively: an FHS user
namespace makes root-owned Home Manager store links appear owned by nobody,
which causes OpenSSH to reject `~/.ssh/config`. Native execution preserves
SSH alias resolution and the selected Git identity. No Chromium `--no-sandbox`
override is added.

The Electron archive is repacked with its members unpacked so native modules
remain available to autoPatchelf. A version-specific, match-count-checked patch
selects the Nix Bash executable for local hooks and terminal profiles. Remote
hook shell paths are deliberately unchanged. Review these matches on upgrades.

The desktop entry launches `orca-ide-gui`; `orca-ide` is the bundled CLI.
Neither command claims the GNOME screen reader's `orca` name. Both launchers
set `ORCA_TELEMETRY_DISABLED=1` and inherit the user's agent installations.
No extra agent, SDK, account, permission policy, MCP connection, autostart or
network service is provisioned by this module.

The `.deb` retains its `resources/package-type` marker. In upstream 1.4.216,
the absence of apt/dpkg in trusted system directories identifies an externally
managed installation: Orca may check for and report new releases, but refuses
update downloads and installation. The launcher refuses to run if those package
managers appear in trusted system directories. This is not an offline mode. Updates belong
in a reviewed change to the Nix version/hash; recheck this upstream contract
on every update. Reverting the package does not reverse application-state
migrations, so retain a local backup before upgrading an established profile.

Home Manager does not own Orca's mutable settings, sessions or credentials.
Keep them outside Git, Nix expressions and `Sync/Fleet`. Preserve the existing
fleet-managed agent context, hooks and skills; do not import or overwrite
personal agent settings during onboarding without inspecting the changes.
The package already supplies the CLI; skip Orca's optional CLI registration.
If a prior manual installation shadows it, inspect `type -a orca-ide` before
removing or changing anything.

## Development checks

From a short-lived branch based on current main:

```sh
nix build .#orca-ide --no-link
nix fmt
nix flake check --no-build --no-write-lock-file
nix-check all
```

The shared AI profile imports the optional module, so evaluate and build system
and Home Manager outputs for Victus, Desktop and ThinkPad. Package CLI checks
can use the built store path's `bin/orca-ide --version` and `--help` without
activating the branch. They do not prove GUI, authentication or agent health.

Publication and deployment remain separate actions. Activate only reviewed,
published main through the normal `nix-update` / `nix-switch` workflow.

## Local acceptance after deployment

1. Launch **Orca** from the application menu on the workstation being validated.
   Check rendering, resizing, clipboard, terminal and browser under its normal
   Hyprland session. Do not force NVIDIA PRIME offload for routine IDE work.
2. Check `orca-ide --version`, `type -a claude codex opencode kiro-cli` and
   `ai-doctor` inside an Orca terminal. Compare with a fresh external terminal.
   Verify existing fleet context/skills and the Claude RTK hook remain intact.
3. Add one development repository, fetch its base and create two short-lived
   branches/worktrees from the updated base. Run at most two agents initially.
   Do not launch installers or agent self-updaters from Orca.
4. Review each worktree's `.envrc` before authorizing direnv. Confirm the shell
   loads the project's locked environment. For noninteractive commands use
   `direnv exec . <command>` with an authorized environment, or
   `nix develop --command <command>`. Check actual SDK versions and run the
   project's relevant tests; a terminal prompt alone is insufficient.
5. Keep `.direnv`, `.venv`, `node_modules`, build outputs and secrets out of
   Orca's shared-path setup. Worktrees do not isolate ports, Docker resources,
   databases or credentials: allocate distinct resources for concurrent tests.
6. Review both diffs, exercise browser preview and restart Orca to check session
   restoration. Observe RAM/CPU pressure during the two-agent workload before
   increasing concurrency. Publish changes only with the repository's required
   authorization, and never activate a nixos-config feature branch.
7. Confirm update UI identifies the installation as externally managed when
   a newer release is available. Do not treat an unavailable update as a
   successful exercise of the update guard.

Run and record this acceptance separately on each workstation after deployment.
Herdr and the existing editors remain available.

## Remote and mobile follow-up

SSH, Orca Server, mobile pairing, computer use and scheduled automations are
outside this desktop application rollout. In particular, upstream's SSH mode
installs a remote relay and may build node-pty: validate NixOS dependencies and
the existing Tailscale ProxyCommand before adopting it. Check disconnect/session lease behavior rather
than assuming indefinite persistence. Desktop's existing Zellij Remote Workspace
remains independent; no ports, firewall rules or Tailscale policy change here.

## Disable

Remove the target host's opt-in or set `fleet.ai.orca.enable = false`, validate
and deploy reviewed main. This removes the managed application while preserving
local Orca data and Git worktrees. Close running Orca sessions separately when
safe.

## References

- [Upstream release](https://github.com/stablyai/orca/releases/tag/v1.4.216)
- [Install and Linux CLI](https://www.onorca.dev/docs/install)
- [Pinned external package ownership detection](https://github.com/stablyai/orca/blob/v1.4.216/src/main/linux-update-package-type.ts)
- [Pinned updater tests](https://github.com/stablyai/orca/blob/v1.4.216/src/main/updater.linux-externally-managed.test.ts)
- [Telemetry control](https://www.onorca.dev/docs/telemetry)
- [SSH relay requirements](https://www.onorca.dev/docs/ssh)
- [Project environments](project-environments.md)
- [Fleet AI environment](ai-environment.md)
- [Remote Workspace](remote-workspace.md)
