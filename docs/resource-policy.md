# Workstation resource policy

The policy reduces build contention and preserves interactive headroom. ThinkPad and Victus use disk-backed emergency swap in addition to ZRAM; Desktop keeps more resources available for K3s and CI. These settings do not promise a fixed amount of free RAM or faster source builds.

| Setting | Desktop | Victus | ThinkPad |
|---|---|---|---|
| Concurrent Nix builds | 1 | 2 | 1 |
| Suggested cores per build | 1 | 2 | 2 |
| Nix daemon CPU / I/O weight | 50 / 50 | 50 / 50 | 25 / 25 |
| ZRAM | zstd, 50% logical RAM size | same | same |
| Disk swap added | none | 8 GiB, ephemeral encryption | 8 GiB, ephemeral encryption |
| Docker at boot | enabled | socket activation | socket activation |
| Remote Workspace | enabled | disabled | disabled |

Nix uses the batch CPU scheduler. Weekly garbage collection keeps the 30-day retention window with lower CPU and I/O priority. Weights are relative to sibling cgroups during contention, not reservations or hard caps; I/O weighting also depends on kernel and device support. The interactive Nix evaluator runs in the calling session and is not covered by the daemon's weights. `cores` is a request to build scripts, not a CPU limit. Project builds outside Nix need their own concurrency settings.

## Baseline and rationale

Read-only observations on 2026-09-05 found:

- ThinkPad E14 Gen 7, Core Ultra 5 226V: about 15 GiB usable RAM, 8 CPUs. During an update the Nix evaluator had about 3.5 GiB RSS and the daemon cgroup about 6.4 GiB, including Rust compilation. Available memory was 5.8 GiB and memory PSI was near zero at that instant: this is a baseline, not proof of OOM.
- Desktop: about 15 GiB usable RAM, 12 CPUs, with K3s and CI workloads.
- Victus: about 22 GiB usable RAM, 12 CPUs. It is now treated as an interactive creative/ML workstation rather than a CI host.
- ThinkPad's ZRAM stored about 252 MiB in 90 MiB of allocated RAM. Its existing 50% logical size was not exhausted, so increasing ZRAM or changing swappiness is not justified by that sample.
- A Docker daemon can consume resources even with no user containers. ThinkPad and Victus therefore use socket activation; calling the Docker API starts the daemon and it remains running afterward.

Installed IDEs and SDKs primarily cost disk space while closed. Removing them does not address compiler or ML working-set memory usage. Bluetooth, audio, VPN, Lan Mouse and explicitly enabled virtualization remain available.

## ThinkPad and Victus fallback swap

Both interactive workstations use ZRAM as the fast first tier and an encrypted disk-backed swap file only as an emergency buffer:

- ThinkPad: `/var/lib/nixos-memory-swapfile`
- Victus: `/var/lib/nixos-victus-memory-swapfile`

Each file is 8 GiB with priority below ZRAM and uses an ephemeral random encryption key. Hibernation, hybrid sleep and suspend-then-hibernate are disabled because the swap encryption key is not persistent. Ordinary suspend remains available.

Before the first deployment that creates either file, check available disk space with `df -h /`. Do not reuse these paths for user data. NixOS creates/resizes and formats the backing files.

## Verification

After rollout, collect the following before and during a representative workload, preferably on AC power:

```sh
free -h
swapon --show
zramctl
cat /proc/pressure/memory
vmstat 1 10
ps -eo comm,rss --sort=-rss | head -20
nix config show | rg '^(max-jobs|cores) ='
systemctl show nix-daemon.service -p MemoryCurrent -p CPUWeight -p IOWeight -p CPUSchedulingPolicy
systemctl is-enabled docker.service docker.socket
```

On ThinkPad and Victus expect ZRAM at the higher priority and an encrypted `/dev/mapper/` swap device at the lower priority. Persistent swap-in/out and rising memory PSI under a steady workload mean the working set still exceeds comfortable capacity. Disk swap is a stability buffer, not additional physical RAM.

On Victus, also verify the GPU path used by creative and ML workloads:

```sh
nvidia-smi
nvtop
powerprofilesctl get
systemctl status nvidia-container-toolkit-cdi-generator.service
```

The normal desktop remains on the AMD iGPU. PRIME offload and the NVIDIA CDI specification expose the RTX 4050 only to workloads that request it.

## Docker policy

Desktop keeps Docker enabled at boot because it still hosts infrastructure/CI workloads. ThinkPad and Victus keep Docker installed but use socket activation so the daemon starts only when an application calls the Docker API.

A container restart policy takes effect only after the daemon has started. If a future workload must start at boot, that requirement should be declared explicitly for the affected host instead of restoring boot-time Docker fleet-wide.

## Performance profiles

Victus exposes three explicit helpers through Home Manager:

```sh
work-balanced
work-performance
work-save
```

Use `balanced` for normal work, `performance` for sustained builds/render/training on AC power, and `power-saver` when battery life matters. The configuration does not force performance mode globally because doing so would trade battery life and thermals for little benefit during light work.

## If memory remains tight

1. Keep consuming the signed binary caches configured by the repository so large Nix builds are not unnecessarily repeated from source.
2. Limit project-specific Gradle workers, JVM heaps, ML data-loader workers, VM memory and build concurrency at the project level. Global limits cannot know each workload's needs.
3. Use Victus for heavy interactive workloads and Desktop for infrastructure. Remote compilation remains a separate follow-up; Tailscale SSH is available on every workstation, while the Zellij Web Remote Workspace is now Desktop-only.
4. Tune ZRAM size/compression or swappiness only after measuring compression, PSI and swap I/O. Larger ZRAM still consumes physical RAM and helps little with incompressible data.
5. Consider `earlyoom` only if measured workloads still cause sustained thrashing or an unresponsive desktop after the fallback swap is active. Do not introduce aggressive OOM policy preemptively.
6. For sustained workloads larger than physical memory, hardware RAM capacity is preferable to relying on swap.

No hard application memory limits, cache-dropping cron jobs, automatic Docker pruning, aggressive OOM killers or kernel security tradeoffs are introduced by this policy.

## Planned follow-up: remote Nix builders

Remote compilation remains a useful future improvement. The ThinkPad rollout of PR #43 already demonstrated that store paths built elsewhere can be transferred instead of recompiling everything locally.

A production remote-builder design should define builder selection and concurrency, SSH identity and trust, offline fallback, cache/GC retention, and observability. Victus can be considered as a builder when idle, but its primary role is now interactive creative/ML work and remote builds must not steal resources from active user workloads.

## Rollback

Revert the policy in a PR and deploy the resulting `main` during a quiet period. Removing active swap requires enough RAM or alternate swap to receive its pages; use a planned reboot if necessary. NixOS does not delete the backing files automatically when their declarations are removed. Reclaim them manually only after verifying that both swap and their encryption mappings are inactive.

## References

- [Nix: cores and jobs](https://nix.dev/manual/nix/2.32/advanced-topics/cores-vs-jobs)
- [Linux: zram](https://docs.kernel.org/admin-guide/blockdev/zram.html)
- [Linux: swappiness](https://docs.kernel.org/admin-guide/sysctl/vm.html#swappiness)
- [systemd resource control](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)
- The pinned Nixpkgs modules `nixos/modules/config/swap.nix` and `nixos/modules/virtualisation/docker.nix` define encrypted file swap and Docker socket activation used here.

## Desktop integration workload follow-up (2026-09-07)

A live Desktop sample during Nix compilation showed 452 MiB available RAM, full 7.7 GiB swap, load 66 and I/O PSI some avg60 about 96%. After the compilation was cancelled, available memory recovered to 4.6 GiB, swap usage fell to 523 MiB and memory PSI avg60 returned to zero. These are point observations, not an SLO.

Desktop therefore keeps one Nix job with one suggested core and constrained CI concurrency. Keep Nix maintenance out of backend-heavy execution windows until cross-agent scheduling or relocation is implemented. Victus is no longer a Woodpecker runner and should not be used as implicit CI capacity.
