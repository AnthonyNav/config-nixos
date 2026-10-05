# Orca on the workstations

Orca is an optional Home Manager application, enabled in the shared daily
profile for Desktop and Victus through `fleet.ai.orca.enable = true`.
The module defaults to false; the installer does not import the daily profile.

## Package and ownership

`packages/orca-ide.nix` pins the upstream **1.4.220** Linux x86_64 `.deb` by
version and SHA-256. Nix extracts it without running Debian maintainer scripts.
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

The new `resources/orcad-template` glibc/musl/ARM payloads are kept outside local
fixups and restored afterward. Rewriting their interpreters/native dependencies
to this workstation's Nix store would break remote SSH deployments. Build checks
inspect the remote native modules for accidental local store references.

The desktop entry launches `orca-ide-gui`; `orca-ide` is the bundled CLI.
Neither command claims the GNOME screen reader's `orca` name. Both launchers
set `ORCA_TELEMETRY_DISABLED=1`. The Home Manager desktop/CLI launchers put the
fleet identity wrappers on PATH, including noninteractive agent launches.
No extra agent, SDK, account, permission policy, MCP connection, autostart or
network service is provisioned by this module.

The `.deb` retains its `resources/package-type` marker. In the packaged updater,
the absence of apt/dpkg in trusted system directories identifies an externally
managed installation: Orca may check for and report new releases, but refuses
update downloads and installation. The launcher refuses to run if those package
managers appear in trusted system directories. This is not an offline mode. Updates belong
in a reviewed change to the Nix version/hash; recheck this upstream contract
on every update. Reverting the package does not reverse application-state
migrations, so retain a local backup before upgrading an established profile.

Home Manager does not own Orca's mutable settings, sessions or credentials.
Keep them outside Git, Nix expressions and synchronized `shared/` directories. Preserve the existing
fleet-managed agent context, hooks and skills; do not import or overwrite
personal agent settings during onboarding without inspecting the changes.
The package already supplies the CLI; skip Orca's optional CLI registration.
If a prior manual installation shadows it, inspect `type -a orca-ide` before
removing or changing anything.

## Workspace and skills

Use canonical work/personal roots and check `workspace-context status` inside
each primary repository/worktree. External linked worktrees inherit the primary
repository context. Explicit `workspace-context exec work -- COMMAND` also scopes
SDK dependency caches. See [workspace-workflow.md](workspace-workflow.md) for
account login, neutral refusal, migration and rollback.

Home Manager links only the eight `fleet-*` skills, including
`fleet-orca-workspaces`, into universal and harness-specific discovery. Upstream
Orca stubs stay mutable and are refreshed only by an explicit user action:

```sh
orca-skills-sync --dry-run
orca-skills-sync
orca-ide skills get orca-cli
# Optional Android automation, distinct from phone remote control:
orca-skills-sync --android --dry-run
```

The helper targets approved core stubs and skips unrelated skills. Install uses
universal discovery; update applies to existing upstream placements. Review
symlinked/read-only placements manually. The actual 1.4.220 CLI dry-run resolves
the installer without executing it. No activation hook installs/downloads stubs.
The [upstream skill commands](https://www.onorca.dev/docs/cli/skills) provide
version-matched guides rather than copying their contents into fleet skills.

## Supervised permissions and Android

Set **Settings → Agents → Agent Permissions → Manual** for supervised launches.
Orca preserves customized agent arguments; review those individually for bypass
flags. This is a user-owned UI setting, not an opaque state patch or build-time
assertion. [Upstream permission behavior](https://www.onorca.dev/docs/agents/supported)
documents the global switch. Mobile approval cannot change fleet context.

Pair the Android companion to the intended workstation using Orca's supported
pairing UI. The reviewed candidate as of 2026-10-04 is
[Android 0.0.52](https://github.com/stablyai/orca/releases/tag/mobile-android-v0.0.52),
which upstream marks **pre-release**. Record the actual desktop/mobile versions;
do not treat mobile support as proven by the Nix package build.

On each workstation, validate transcript/status, follow-up prompts, a Claude
structured question/permission, a supported Codex approval/question, rejection,
Chat UI/Terminal View switching and reconnection to the original session.
Check pending input directly; push notifications alone are insufficient.
An async Codex question can show prose without a decision card while
[issue #20073](https://github.com/stablyai/orca/issues/20073) remains open.
For that case send an ordinary reply with question/answer text through the
supported composer or Terminal View. An async display acknowledgement is not
an answer; never fabricate a blocking state or send the digit/Escape sequence
for a different blocking prompt. True blocking approvals still need their native
approval/Terminal View path. Record this fallback on the real phone.

Desktop and Victus stay autonomous. Optional SSH worktrees may use the existing
Tailscale/SSH boundary after local acceptance; no permanent Orca server or new
public service is provisioned. Remote acceptance must verify the original host,
project environment and account context separately.

## Optional Desktop App Remote Server

Both inventory features.orcaRemote.mode values default to "off". Desktop is the
preferred optional runtime; Victus stays autonomous. Evaluated AI facts and
fleet-info expose that policy without claiming a running server. The system
module supports only off/desktop-app, never starts Orca, provisions tokens or
enables linger. Headless is rejected until recovery is designed/tested.

For a separately authorized deployment of reviewed main, select "desktop-app"
on the intended host. The endpoint registry and per-interface firewall then
admit TCP 6768 only on tailscale0. Inspect/apply the reviewed tailnet policy
output separately. No public firewall port or public tailnet service is added.
The other workstation keeps working when Desktop is asleep or unavailable.

Before opting in, verify the actual app listener and access link's port against
inventory/endpoints.nix. 6768 is the explicit upstream CLI example, not evidence
about a running Desktop App listener. If the supported UI setup uses another
port, declare that verified port in reviewed configuration. An advertised
Tailscale address does not restrict the server's listening interface.

On Desktop, use Settings → Remote Orca Servers → Advertise this app as a server
→ New Link, select its Tailscale address and generate the access link. On Victus,
Add Server with that private link. Pair Android through the supported mobile
flow with the phone on the same tailnet. Pairing links/client grants stay in
user-owned runtime state, never HANDOFF.md, Git or Nix.

Remote agents use Desktop's repositories, tools and provider credentials, not
Victus's login cache. Verify each remote worktree's context. Use one host mode at
a time and preserve original-session questions/approvals.
[Upstream Remote Servers](https://www.onorca.dev/docs/remote-servers).

Real-device acceptance remains pending: connection, network loss/reconnect,
Android background/resume, Claude/Codex questions and rejection, work/personal
identity, multi-repo paths, handoff replacement and autonomous Victus use while
Desktop is unavailable. Record versions, actual listener and reachability from
tailnet and ordinary LAN paths. Package builds cannot establish these results.

After stable Phase A use, decide whether persistence is needed. An optional user
systemd service around orca-ide serve belongs to Phase C, after a backup destination
and restoration test exist. Restic remains prepared/off. A server restart does
not resurrect agent memory or recover unpublished work; Git plus HANDOFF.md remain
the recovery contract.

## Development checks

From a short-lived branch based on current main:

```sh
nix build .#orca-ide --no-link
nix fmt
nix flake check --no-build --no-write-lock-file
nix build --no-link .#checks.x86_64-linux.workflow-packages
nix-check all
```

The shared AI profile imports the optional module, so evaluate and build system
and Home Manager outputs for Desktop and Victus. Package CLI checks
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
3. Add one work and one personal repository; inspect context and selected Git
   identity. Fetch their bases and create short-lived branches/worktrees from
   the updated base. Validate an external linked worktree. Start with one agent,
   then at most two for the resource acceptance workload when authorized.
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
8. Complete the real Android/Manual-permission matrix above and record results
   for both hosts, including unsupported cards and the fallback used.

Run and record this acceptance separately on each workstation after deployment.
Herdr and the existing editors remain available.

## Disable

Override the option through an explicit Home exception or set `fleet.ai.orca.enable = false`, validate
and deploy reviewed main. This removes the managed application while preserving
local Orca data and Git worktrees. Close running Orca sessions separately when
safe.

## References

- [Pinned release](https://github.com/stablyai/orca/releases/tag/v1.4.220)
- [Install and Linux CLI](https://www.onorca.dev/docs/install)
- [Original package ownership contract](https://github.com/stablyai/orca/blob/v1.4.216/src/main/linux-update-package-type.ts) (recheck the bundled updater on upgrades)
- [Telemetry control](https://www.onorca.dev/docs/telemetry)
- [Project environments](project-environments.md)
- [Fleet AI environment](ai-environment.md)
