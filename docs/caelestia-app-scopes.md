# Caelestia application scopes

The shared shell package patches `modules/launcher/services/Apps.qml` to launch
application entries through `systemd-run --user --scope --slice=app.slice
--collect --quiet --expand-environment=no --`. The executable is pinned to the
Nix systemd package. Arguments remain an array, including the configured terminal
and upstream terminal wrapper for `Terminal=true` entries. Quickshell sets the
entry's working directory; scope mode inherits that directory and the launcher's
environment. No shell command string is assembled or expanded by systemd-run.

Detached processes normally inherit `caelestia.service`'s cgroup. The new scopes
are siblings under `app.slice`, so launched applications no longer count toward
the shell's 2 GiB memory and 512 MiB swap caps or stop with that service. Other
shell helpers still belong to the shell's cgroup. Theme and Wi-Fi patches remain
in the same custom package.

## Development verification

Build the package and exercise its patched launcher without activation:

```sh
nix build --no-link --print-out-paths '.#homeConfigurations."anthony@victus".config.programs.caelestia.package'
node scripts/test-caelestia-app-scopes.mjs /nix/store/<built-package>/share/caelestia-shell/modules/launcher/services/Apps.qml
```

Also run `nix fmt`, `nix flake check --no-build --no-write-lock-file`, and the
NixOS and Home Manager builds for Victus, ThinkPad, and Desktop (`nix-check all`).

## After merge and deployment

Start validation on Victus after the reviewed PR reaches `main` and is applied
with `nix-update`. Do not activate the development branch.

1. Record the start time (`date --iso-8601=seconds`). Close Chrome completely,
   including background processes, then launch Chrome and a terminal from
   Caelestia. Chrome can reuse an existing browser process and its old cgroup;
   opening another window is not sufficient to test a fresh launch.
2. Find the new browser and terminal PIDs, then inspect `/proc/<PID>/cgroup` and
   `systemctl --user status <PID>`. Each application must belong to a distinct
   `app.slice/run-*.scope`, outside `caelestia.service`. For a desktop entry with
   `Terminal=true`, also verify its program runs inside the terminal's scope.
3. Inspect the shell with:

   ```sh
   systemctl --user show caelestia.service -p ControlGroup -p MemoryMax -p MemorySwapMax -p NRestarts
   systemd-cgls --user-unit caelestia.service
   ```

4. Repeat the usual browser tab workload. Inspect the journal since the recorded
   time (`journalctl --user -u caelestia.service --since '<start time>'`) and the
   kernel log (`journalctl -k --since '<start time>'`). Confirm no new shell
   `oom-kill` events. This checks the workload; it does not prove the shell's
   underlying memory growth is fixed.
5. Run `systemctl --user restart caelestia.service`; confirm the browser and
   terminal remain open and their scopes persist. Repeat on the other hosts
   after their normal `nix-update` rollout.
