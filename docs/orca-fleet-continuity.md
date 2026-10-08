# Desktop, phone and laptop continuity

Desktop hosts the persistent Orca runtime; Pixel, Victus and Mac can connect as
clients over the private tailnet. Local laptop work remains available while
Desktop is offline. Git receives published code, Syncthing carries project
handoffs/docs/assets, and live agent sessions remain on their execution host.

## Reviewed-main rollout

Build and review the PR first. Do not activate its branch. After merging and
publishing main, deployment is a separately authorized action following
[maintainer.md](maintainer.md) and [nixos-development-guide.md](nixos-development-guide.md).
Build both Linux systems and all three daily Homes; build the registered Mac's
Darwin system/Home natively on Apple Silicon or through the PR build matrix.

Before updating Desktop's Home, checkpoint active agent work, record its branch
and published SHA in HANDOFF, and disconnect clients. Inspect
`orca-server-status --json`. An older runtime may be in `app-orca-<pid>.scope`
while the service owns only a CLI supervisor. Do not restart that unit and assume
the app or its listener stopped. Preserve private Orca state and Syncthing
configuration outside Git; never copy credentials into a shared folder.

If the old runtime is detached, stop it explicitly only after the checkpoint,
using the supported Orca quit/close flow, or use a separately authorized reboot
after deploying reviewed main. Verify TCP 6768 is free before starting the new
service. A reboot ends running terminals/agents; Git plus HANDOFF resumes the task.
Do not kill a PID or scope from an old diagnostic record.

After deployment, on Desktop:

```sh
orca-server-status --json
orca-server-logs
syncthing-fleet-reconcile --check
workspace-sync status --json
```

Require `healthy = true`, `service_owns_runtime = true`, the declared port 6768,
the current Tailscale address, a matching runtime ID and verified daemon scope
before testing a guarded restart. In a private terminal request
`orca-server-logs --pairing`; treat its output as a password. Enter it through
Orca's supported client/server pairing flow. Never put pairing links or raw
journal/auth output in Git, HANDOFF, the PR or chat.

Check Syncthing's `fleet-work`/`fleet-personal` IDs, paths, exclusions and shares.
Leave the old Projects/kigo folders paused. Their files are retained and active
legacy folders receive a private configuration snapshot. Select and clone/move
projects deliberately; do not resume synchronization of live Git directories.

## One-time laptop registration

Read HANDOFF and clone each missing repo into its recorded relative path using
the correct work/personal context. Select the published receiving branch and
register that clean copy with `workspace-sync register PATH --branch BRANCH`.
Do this locally on each laptop; registration and authentication are never
synchronized. See [workspace-workflow.md](workspace-workflow.md#automatic-git-receivers)
for holds, branch changes and receipt results.

The runtime services do not auto-commit/push source work. Publication uses the
active task's authorization and account. Following a successful push, clean idle
receivers update on the next two-minute poll when their network and credentials
are available. Continue local work in a separate worktree or hold the receiving
copy before editing it.

## End-to-end acceptance

Record deployed desktop/mobile versions and actual results rather than treating
a successful build as phone or runtime acceptance:

1. Boot Desktop without graphical login. Verify linger, service ownership,
   listener/readiness and persistence of previously paired clients.
2. With Tailscale active on Pixel, pair Orca mobile and open a harmless test
   project on Desktop. Send a task and a follow-up; confirm the host, project
   environment and identity. Test Claude and Codex approval, rejection and
   questions in Manual mode, including the documented async-question fallback.
3. Disconnect/reconnect Wi-Fi, switch to cellular, background/resume the app and
   return to the original session. Check pending input in the app; pinned
   headless Orca does not send renderer-dependent agent-completion notifications.
4. Publish one harmless change in an authorized test branch. Keep Victus/Mac
   offline, reconnect them, and verify `workspace-sync status --json` reports
   `updated` with the exact published SHA. Verify the file and HANDOFF locally.
5. Repeat with a dirty checkout, local commit, different branch and an explicit
   hold. Verify receipt defers and preserves the local files/history. Resume the
   hold after checkpointing; do not force a divergence through automation.
6. Keep the Mac offline and verify Syncthing still reconciles Linux peers and
   retains the Mac device/share. Reconnect the Mac and verify a harmless allowed
   document transfers with no pending items/errors. A new unknown offline peer
   should join after certificate discovery when it becomes available.
7. After checkpointing the test task, exercise the guarded service restart with
   an isolated test terminal, then a separately authorized reboot and recovery.
   Verify tailnet reachability and denial from ordinary LAN/public interfaces.

## Rollback

Hold or unregister receivers first; registration/receipts remain private local
state. A prior reviewed system/Home generation restores launchers and scheduling
but does not undo Git fast-forwards, upstream Orca state migrations or Syncthing
REST changes. Reconcile Git through normal authorized history operations.

Retain source folders and private Syncthing snapshots. Restoring a legacy
snapshot or unpausing a Git-containing folder requires deliberate review on both
peers; rolling back the package must not silently reenable that transfer.
Keep Desktop clients paused while reconciling a detached legacy runtime. Never
erase mutable Orca/Syncthing state to force service health.
