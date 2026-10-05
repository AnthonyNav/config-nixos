# Desktop creative + ML workstation

Desktop consumes the same daily and development/data-science/creative/platform profiles
as Victus, through the inventory. Its i5-12400F has no iGPU; the RTX 3060 Ti
remains the direct desktop renderer. Generated disks, boot and GPU settings stay
under `hosts/desktop/`; no hardware configuration is generalized across machines.

NVIDIA Container Toolkit supplies CDI for explicitly requested GPU containers.
Local VMs, Tailscale SSH, Syncthing, Lan Mouse, audio, Bluetooth and Pritunl
remain available. No headless/server workload is provisioned by this repository.

See [architecture](workstation-architecture.md), [monitors](monitors.md) and
[resource policy](resource-policy.md). Profiles are based on connected monitor
identities, not the name Desktop. The workstation retains ordinary suspend and
Caelestia locking/DPMS; hibernation stays disabled.

The [workspace workflow](workspace-workflow.md) covers invocation-scoped work,
personal and neutral identities, shared-only Syncthing roots and Orca acceptance.
Platform tools install clients without starting infrastructure services.

## Preservation and rollout

Removing retired modules does not remove VM disks, Docker volumes, credentials,
projects or old workload data. Do not run uninstall scripts or system/volume
pruning as part of this PR. Removing a machine from the inventory also does not
revoke its external Tailscale/Syncthing/DTLS identity.

Build and review first. Publication and deployment are separate authorized
actions; activate only reviewed published main with `nix-update`.
Inspect the active generation, residual publications/autostart local state and
retained data separately. Previous generations may restore retired declarations;
consider that effect before rollback.

After authorized deployment, validate direct NVIDIA rendering, a CDI GPU
container, audio, VPN, fleet SSH/Syncthing, Lan Mouse, lock/DPMS and suspend.
Run the physical monitor matrix in [monitors.md](monitors.md). Successful
evaluation/builds do not prove those runtime behaviors.
