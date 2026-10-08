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
The application module does not provision accounts, SDKs or MCP connections.
The separate `orca-remote.nix` modules own the explicitly selected runtime,
user service, linger and private firewall boundary described below.

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

Victus and the registered Mac remain autonomous. SSH worktrees use the existing
Tailscale/SSH boundary. Remote acceptance must verify the original host, project
environment and account context separately.

## Persistent Desktop runtime

`features.orcaRemote.mode` accepts `off`, `desktop-app` and `headless` on NixOS.
Desktop selects **headless**, `preferredRuntime = true`; Victus selects **off**.
The Darwin template remains off and does not create a macOS server. These are
declarations for the next reviewed-main deployment, not proof of active health.

`modules/system/orca-remote.nix` enables linger for the ordinary managed user
only in headless mode. `modules/home/orca-remote.nix` installs
`orca-serve.service`, wanted by the user's `default.target`. At boot the user
manager starts without graphical login. The service uses the user's existing
home, projects, managed AI tools, workspace identity wrappers and local Orca
state; it does not copy credentials into a separate account or the Nix store.
Provider authentication and encrypted SSH key unlocking remain owned by the user.

`scripts/orca-serve-fleet.sh` waits until Tailscale reports Running/online and a
valid current tailnet IPv4 address, then execs the pinned absolute
`orca-ide-server` with `--serve-port 6768 --serve-pairing-address <current-ip>
--serve-json`. This launcher execs Electron directly with `--serve`; the unit's
MainPID must be the live runtime/listener PID. The package checks
these upstream flags when rebuilding the payload. No address is
hardcoded. The wrapper clears inherited graphical display/profile overrides,
provides Xvfb on PATH and uses `LIBGL_ALWAYS_SOFTWARE=1`. Orca owns its virtual
display lifecycle. The service does not depend on a graphical session target.

The firewall admits TCP 6768 only on `tailscale0`, through the existing endpoint
registry. `--pairing-address` advertises an address; it does not constrain the
listener, which may bind wildcard interfaces. The wrapper refuses an occupied
port; health requires the current invocation's bound/advertised port to remain
6768, the advertised address to match Tailscale, and the actual listener PID to
match the reachable local Orca runtime. Readiness also matches its live runtime
ID. Chromium can move that same MainPID into `app-orca-<pid>.scope` for
[desktop portal identity](https://github.com/chromium/chromium/blob/main/components/dbus/xdg/systemd.cc);
the helper verifies its actual kernel unit and reads readiness there. systemd
still signals the directly launched MainPID. A different runtime PID or an
upstream fallback port is unhealthy.
The server launcher selects `--ozone-platform=x11` for its Xvfb display and
clears inherited Wayland preferences. It keeps Chromium's sandbox enabled.
Tailnet policy publication is still a separate operation.

The unit uses `Restart=on-failure`, `RestartSec=5`, `KillMode=mixed`,
`RestartPreventExitStatus=3`, `StartLimitIntervalSec=300` and `StartLimitBurst=5`.
Exit 3 means another process owns the profile and must not cause a restart loop.
The managed GUI launcher refuses to open Desktop's headless-owned profile;
use Victus/Mac/Mobile as a client or change the host mode through review.
`desktop-app` prepares the same private firewall without a service or linger.

After separately deploying reviewed main, use:

```sh
orca-server-status --json
orca-server-logs
orca-server-logs --follow
ai-doctor
fleet-info --json
```

These commands separate policy from bounded, local runtime probes. They never
print bootstrap auth tokens or pairing codes by default. For the first pairing,
explicitly request the sensitive link in a private terminal:

```sh
orca-server-logs --pairing
```

Treat that output as a password; add the server on Victus/Mac or pair Android
through the supported mobile flow with both devices on the tailnet. The raw
user journal also contains the upstream readiness event and its private link.
Do not paste raw journal or pairing output into Git, HANDOFF, tickets or chats.
Client grants remain mutable under the user's Orca profile.

An older installation can have an active CLI service while the server lives in
`app-orca-<pid>.scope`. The diagnostic helper recovers that scope's endpoint and
pairing offer only after checking the same user's managed executable, listener and
runtime ID; it reports `service_owns_runtime = false`. It refuses an implicit
restart of the detached runtime. See [the migration and mobile runbook](orca-fleet-continuity.md)
before deploying the launcher change to that profile.

`orca-server-restart` checks service ownership and live daemon isolation before
restarting. Pinned version **1.4.220**'s readiness publisher does not
populate main's optional `health.terminalDaemon` payload. We therefore verify
the profile's `daemon/daemon-v*.pid` records against `/proc` boot ID, process start
ticks, user, command and actual `orca-daemon-*.scope` membership. A persisted
scope claim alone is insufficient. If isolation is unverified, the helper
requires a fresh, explicitly untruncated empty terminal census covering local
execution with no affected/unknown omitted SSH hosts. Otherwise it defers the
restart. Pause clients before a census-based restart; upstream has no atomic
census-and-stop fence. Service recovery uses `systemctl --user reset-failed
orca-serve.service` if the start limit has tripped.

A verified isolated daemon can preserve terminal/agent processes across a
service restart, subject to real-machine acceptance. A physical reboot ends
those processes. Repositories, worktrees, handoffs and persisted client grants
remain local; a new agent resumes through Git plus HANDOFF. Restic remains
prepared/off as requested. Headless mode does not send renderer-dependent
agent-completion push notifications to mobile.

Published code can be received automatically by registered clean checkouts on
Victus/Mac through `workspace-sync`; handoff/docs/assets use Syncthing. The server
keeps the phone's active execution on Desktop. See
[workspace-workflow.md](workspace-workflow.md#automatic-git-receivers) for local
registration, holds and the publication boundary.

Acceptance after deployment: boot without graphical login, current endpoint and
pairing, tailnet reachability/LAN denial, isolated-daemon restart with a test
terminal, reboot recovery, Tailscale loss/reconnect, Android background/resume,
Claude/Codex questions/rejection, work/personal identities and autonomous Victus
use while Desktop is unavailable. An IP change during an existing invocation is
reported as unhealthy and needs a guarded restart. Builds cannot prove these
runtime results. See [upstream headless reference](https://github.com/stablyai/orca/blob/main/docs/reference/headless-linux-server.md),
the [published release](https://github.com/stablyai/orca/releases/tag/v1.4.220)
and [Remote Servers](https://www.onorca.dev/docs/remote-servers).

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

1. On Victus (or a reviewed `desktop-app` host), launch **Orca** from the application menu.
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
