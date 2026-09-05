# Workstation resource policy

The policy reduces build contention and gives ThinkPad a disk-backed emergency
buffer. It does not promise a fixed amount of free RAM or faster source builds.
It trades build throughput for interactive headroom.

| Setting | Desktop | Victus | ThinkPad |
|---|---|---|---|
| Concurrent Nix builds | 2 | 2 | 1 |
| Suggested cores per build | 2 | 2 | 2 |
| Nix daemon CPU / I/O weight | 50 / 50 | 50 / 50 | 25 / 25 |
| Zram | zstd, 50% logical RAM size | same | same |
| Disk swap added | none | none | 8 GiB, ephemeral encryption |
| Docker at boot | enabled | enabled | socket activation |

Nix uses the batch CPU scheduler. Weekly garbage collection keeps the existing
30-day retention with lower CPU and I/O priority. Weights are relative to sibling
cgroups during contention, not reservations or hard caps; I/O weighting also
depends on kernel and device support. The interactive Nix evaluator runs in the
calling session and is not covered by the daemon's weights. `cores` is a request
to build scripts, not a CPU limit. Project builds outside Nix need their own
concurrency settings.

## Baseline and rationale

Read-only observations on 2026-09-05 found:

- ThinkPad E14 Gen 7, Core Ultra 5 226V: about 15 GiB usable RAM, 8 CPUs.
  During an update the Nix evaluator had about 3.5 GiB RSS and the daemon cgroup
  about 6.4 GiB, including Rust compilation. Available memory was 5.8 GiB and
  memory PSI was near zero at that instant: this is a baseline, not proof of OOM.
  The running Nix configuration allowed 8 builds with `cores = 0` (all CPUs).
- Desktop: about 15 GiB usable RAM, 12 CPUs, with K3s and CI workloads.
- Victus: about 22 GiB usable RAM, 12 CPUs.
- ThinkPad's zram stored about 252 MiB in 90 MiB of allocated RAM. Its existing
  50% logical size was not exhausted, so increasing it or changing swappiness
  is not justified by this sample.
- ThinkPad had no running Docker containers, but its Docker cgroup used about
  162 MiB. Socket activation avoids that startup cost until something calls the
  Docker API. Even `docker ps` starts the daemon; it stays running afterward.

Installed IDEs and SDKs primarily cost disk space while closed. Removing them
does not address the observed compiler memory usage. Existing Bluetooth, audio,
VPN, remote workspace, Lan Mouse, VMs and desktop features are retained.

## Deployment and verification

Build and review the PR first, then deploy only clean, published `main` using
the maintainer workflow. Finish active builds before updating the Nix daemon.

On ThinkPad, first check `df -h /` and verify that
`/var/lib/nixos-memory-swapfile` is absent, or is already the swap file managed by
this policy. The initial creation writes 8 GiB; leave that space plus operating
headroom available. The observed filesystem had 44 GiB available. Do not reuse
this path for user files: NixOS creates/resizes and formats the backing file.
The random encryption key is not persisted. Hibernation, hybrid sleep and
suspend-then-hibernate are disabled; ordinary suspend remains available.

After rollout, collect the following before and during the same representative
workload, on AC power and with comparable applications open:

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

On ThinkPad expect zram at priority 5 and a `/dev/mapper/` swap device at
priority 0. Verify both exist; disk swap is slower emergency capacity, not extra
physical RAM. Persistent swap-in/out and rising PSI under steady load mean the
working set still exceeds comfortable capacity. Record build duration and
interactive responsiveness along with memory figures; RSS includes shared pages
and cannot be summed as exact physical usage.

Docker is enabled on Desktop and Victus for infrastructure and CI. On ThinkPad
the socket is enabled but the daemon has no boot target. A container restart
policy only takes effect once the daemon starts. If a future ThinkPad workload
must start at boot, restore `virtualisation.docker.enableOnBoot = true` in a PR.

No real-session performance gains or swap activation are claimed by evaluation
or closure builds. Verify these after rollout. Do not stress a live workstation
into OOM merely to test the configuration.

## Alternatives if memory remains tight

1. Keep consuming the signed binary caches already configured in PR #42. An
   unbootstrapped daemon may still compile the AI tools from source; follow the
   first-deployment instructions in `maintainer.md`.
2. Move heavy project builds or IDE backends to Desktop/Victus using the existing
   remote workspace. A Nix remote builder is a separate follow-up requiring
   explicit builder identity, SSH trust and capacity limits; Desktop also has
   only 16 GiB nominal RAM and hosts K3s.
3. Limit project-specific Gradle workers, JVM heaps, Cargo jobs and VM memory in
   each project. Use browser tab suspension and close unused IDE instances;
   measure the actual workload before imposing global application limits.
4. Tune zram size/compression or swappiness only after recording compression,
   PSI and swap I/O. Larger zram still consumes physical RAM and handles
   incompressible working sets poorly.
5. For sustained workloads that exceed physical memory, verify RAM upgrade
   support against Lenovo's exact machine-type specification before buying
   memory, or select a higher-memory host. The model name alone is insufficient.

No new hard memory limits, aggressive OOM killers, cache-dropping cron jobs,
automatic Docker pruning, or kernel security tradeoffs are introduced.

## Rollback

Revert the policy in a PR and deploy the resulting `main` during a quiet period.
Removing active swap requires enough RAM or alternate swap to receive its pages;
use a planned reboot if necessary. NixOS does not delete the 8 GiB backing file
when its declaration is removed. Reclaim it manually only after verifying that
both swap and its encryption mapping are inactive. Do not delete it while active.

## References

- [Nix: cores and jobs](https://nix.dev/manual/nix/2.32/advanced-topics/cores-vs-jobs)
- [Linux: zram](https://docs.kernel.org/admin-guide/blockdev/zram.html)
- [Linux: swappiness](https://docs.kernel.org/admin-guide/sysctl/vm.html#swappiness)
- [systemd resource control](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)
- The pinned Nixpkgs modules `nixos/modules/config/swap.nix` and
  `nixos/modules/virtualisation/docker.nix` define encrypted file swap and Docker
  socket activation used here.
