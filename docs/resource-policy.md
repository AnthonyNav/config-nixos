# Workstation resource policy

Desktop and Victus share a conservative interactive policy. Removing installed
apps is not a RAM optimization while those apps are closed; Nix also deduplicates
identical store paths. Changes are based on declared behavior and measurements.

| Setting | Desktop | Victus |
| --- | --- | --- |
| Nix concurrent jobs / suggested cores | 2 / 2 | 2 / 2 |
| Nix daemon CPU / I/O weight | 50 / 50, batch scheduler | same |
| ZRAM | zstd, 50% logical RAM size | same |
| Emergency disk swap | none added | 8 GiB, ephemeral encryption |
| Docker | socket activation, not boot-started | same |
| Journal retention | 1 GiB persistent, 128 MiB runtime, 14 days | same |
| Power profile | explicit balanced/performance/save helpers | same |

Weights are relative, not CPU/memory reservations. Build scripts may ignore the
suggested core count; the interactive evaluator is outside daemon weighting.
Weekly GC keeps 30-day generations with lower CPU/I/O priority; fstrim and signed
binary caches stay enabled. No automatic Docker prune/cache dropping is added.

## Measurement and changes

Read-only Desktop observations during this PR: approximately 15 GiB usable RAM,
6.4 GiB available and 1.2 GiB ZRAM swap used before compilation; persistent
journals occupied 3.9 GiB. These are point samples, not an idle benchmark.
The new journal bound limits future disk retention; it does not reclaim app RAM.
Older journal entries can be removed by journald after deployment, so export
needed diagnostic logs before the authorized rollout. No vacuum ran here.

Monitor automation blocks on events instead of polling. Neovim does not add
unused Ruby/Python providers. The daily-only profile does not inject Jupyter
libraries or reference Android Studio; the data profile retains the existing
compatibility workaround until its projects are migrated.

Docker starts on the first API request and stays running afterward. Local
libvirt/virt-manager remains optional; onBoot=ignore does not create/start guests.
Existing libvirt autostart selections can still start their own guests: inspect
local state before attributing resource use to the declarative capability.

ZRAM size/compression, swappiness, OOM thresholds and Victus PRIME fine-grained
power management are unchanged. No measured evidence currently justifies tuning
them or adding another OOM daemon. NixOS already declares systemd-oomd; changing
which user slices it may kill needs separate workload validation.

## Verification after authorized rollout

Collect before/during/after the same workload, on AC power where possible:

```sh
free -h
swapon --show
zramctl
cat /proc/pressure/memory
vmstat 1 10
systemctl show nix-daemon.service -p MemoryCurrent -p CPUWeight -p IOWeight
systemctl is-active docker.service
systemctl is-enabled docker.service docker.socket
journalctl --disk-usage
nvidia-smi
powerprofilesctl get
```

Check Docker before invoking its API: even `docker ps` starts the daemon.
Victus uses an AMD desktop renderer and NVIDIA PRIME offload; Desktop uses
NVIDIA directly. GUI/GPU and battery improvements are not proven by a build.

Victus's encrypted swap file is lower priority than ZRAM. Hibernation,
hybrid sleep and suspend-then-hibernate stay disabled; ordinary suspend stays
available. Disk swap is an emergency buffer, not extra physical RAM.
Limit Gradle workers/JVM heaps, render workers, VM RAM and ML batches at project
level. Use `flutter-stop` only after relevant Android builds finish.

## NVIDIA suspend/resume

Desktop and Victus enable `hardware.nvidia.powerManagement.enable` so NVIDIA
preserves video memory across ordinary suspend. This is suspend/resume
integration, not PRIME fine-grained power management or a driver update.
The `nvidia-suspend` flake check covers preservation and hook ordering on
NVIDIA workstations that allow suspend, including the kernel-notifier path
when supported by the selected driver and open kernel modules.

The Desktop correction follows a recorded suspend at 01:35 and NVIDIA Xid 13
errors with a Hyprland SIGABRT on resume at 10:24 on 2026-10-04. The evaluated
configuration and builds verify integration; they do not prove runtime recovery.
Victus already had this setting enabled and its hardware configuration is unchanged.

A second Desktop cycle on 2026-10-04 exposed a separate failure after the first
correction was deployed and rebooted. Idle suspend started at 22:26:50; S3
returned at 22:35:12. NVIDIA's suspend and resume hooks both succeeded and
`PreserveVideoMemoryAllocations` was already `1`. At 22:35:16 Hyprland crashed:
`hyprlandCrashReport2244.txt` records SIGSEGV in Aquamarine 0.15.1's
`CDRMAtomicRequest::restateConnectors`, reached through a monitor mode retry.
Its log repeats atomic DRM `EINVAL` commits on DP-3. The compositor's crash
handler then produced the journal's SIGABRT; portal, Caelestia and Hypridle
failed after the graphical session disappeared. The user rebooted from a TTY.

Desktop therefore disables **automatic idle suspension** through
`hosts/desktop/home.nix`, for both integrated and standalone Home Manager.
Locking and DPMS remain active; manual suspend remains available with NVIDIA's
VRAM preservation and hooks. This contains the automatic trigger; it does not
claim the graphics backend is repaired. Restore the idle timeout only after
a reviewed backend/driver correction passes real multi-monitor suspend/resume.
Victus retains its existing idle suspend policy.

After an authorized rollout from clean, reviewed `main`, reboot before testing
or leaving the machine idle. A live switch does not reload the NVIDIA module
and its new memory-preservation parameter. Save work before suspend testing.

```sh
rg '^PreserveVideoMemoryAllocations:' /proc/driver/nvidia/params
systemctl show nvidia-suspend.service nvidia-resume.service -p LoadState -p Before -p After -p RequiredBy
journalctl -b -u nvidia-suspend.service -u nvidia-resume.service -u systemd-suspend.service
journalctl -b -k -g 'NVRM|Xid|PM: suspend'
```

The proprietary-driver path should report `PreserveVideoMemoryAllocations: 1`
and loaded suspend/resume units. These are event-triggered oneshot services;
`inactive` between sleep cycles is normal. Do not start them manually.
Verify locking, display restoration and GPU applications after a real
suspend/resume cycle; hibernation and its variants remain disabled.

Reference: [Hyprland NVIDIA suspend/wakeup guidance](https://wiki.hypr.land/Nvidia/#suspendwakeup-issues).

## Recovery

Revert through a PR and deploy reviewed main, or use a retained generation under
the documented recovery flow. A package rollback cannot restore application
state migrations or journal entries already expired. Removing a swap declaration
does not erase its backing file; never reclaim it until the swap/mapping is
inactive and there is enough memory for a safe transition.

## References

- [Linux zram](https://docs.kernel.org/admin-guide/blockdev/zram.html)
- [Linux swappiness](https://docs.kernel.org/admin-guide/sysctl/vm.html#swappiness)
- [Nix build jobs/cores](https://nix.dev/manual/nix/2.32/advanced-topics/cores-vs-jobs)
- [systemd resource control](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)
