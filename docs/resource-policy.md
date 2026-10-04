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
