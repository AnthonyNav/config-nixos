# Virtualization lab

The workstation fleet provides an opt-in KVM/QEMU lab for disposable or isolated operating-system work. University exercises and future security/DevOps experiments stay inside guest VMs instead of modifying the NixOS host.

## Architecture

```text
NixOS host
└── libvirt + QEMU/KVM
    ├── dedicated NAT: lab-nat (virbr-lab)
    └── uni-almalinux
        ├── verified AlmaLinux base image
        ├── thin qcow2 guest overlay
        ├── cloud-init seed
        └── snapshots
```

The host layer lives in `modules/system/virtualization-lab.nix`. Fleet-wide guest policy lives in `inventory/virtualization-lab.nix`, while lifecycle operations are implemented by `scripts/lab.sh` and exposed through the `lab` command.

All three workstations opt in through `features.virtualizationLab.enable`. Rebuilding NixOS installs the tooling only: it does not download AlmaLinux, create a VM, reserve 40 GiB, or start a guest.

## AlmaLinux profile

The initial university profile is intentionally pinned instead of following a mutable `latest` image:

```text
profile:       almalinux
domain:        uni-almalinux
image:         AlmaLinux 9.8 Generic Cloud
build:         20260810
vCPU:          2
RAM:           4 GiB
virtual disk:  40 GiB qcow2 (thin/dynamic)
network:       lab-nat
address:       192.168.252.10
user:          student
```

The declared SHA-256 is checked before the image is imported. Updating to another AlmaLinux build therefore requires an explicit change to the URL, build and checksum in `inventory/virtualization-lab.nix`.

AlmaLinux Generic Cloud contains cloud-init. The lab uses it only to set the hostname and create the local `student` account with the host-specific lab SSH public key.

## First activation

After this change is merged, update from clean `main` through the normal workflow:

```bash
nix-update
```

Log out and back in (or reboot) if this is the first deployment of the virtualization stack so the `libvirtd` group membership is active. Then run:

```bash
lab doctor
```

It should report `/dev/kvm` and libvirt access as available. If `/dev/kvm` is missing, enable Intel VT-x/VT-d or AMD-V/AMD-Vi in firmware before creating a guest.

Create the university VM with:

```bash
lab create almalinux
```

The first creation downloads the pinned image (currently about 562 MiB), verifies its SHA-256, imports one local base volume, creates a thin 40 GiB overlay, generates a tiny cloud-init seed, and starts `uni-almalinux`. The temporary download cache is removed after a successful import so the image is not stored twice.

First boot/cloud-init can take a short time before SSH is ready:

```bash
lab ssh almalinux
```

For boot diagnostics or the graphical Virt-Manager console:

```bash
lab open almalinux
```

## Daily commands

```bash
lab status almalinux
lab start almalinux
lab stop almalinux
lab ssh almalinux
lab open almalinux
```

Run one remote command without entering an interactive shell:

```bash
lab ssh almalinux -- uname -a
```

## Snapshots and disposable work

Create a checkpoint before a risky exercise:

```bash
lab snapshot almalinux clean
lab snapshots almalinux
```

Snapshots are created while the guest is stopped to avoid filesystem-consistency ambiguity; if it was running, `lab` starts it again afterwards.

Restore a checkpoint:

```bash
lab revert almalinux clean
```

Erase the entire guest overlay and recreate it from the verified base:

```bash
lab reset almalinux
```

`reset` is destructive and asks for confirmation. Non-interactive use requires `--force`.

Delete the VM and recover the space consumed by its overlay, seed and snapshots:

```bash
lab delete almalinux
```

The verified base remains local so creating the VM again does not need another download. To remove that base too:

```bash
lab purge-image almalinux
```

## Storage model

A declared 40 GiB virtual disk is not a 40 GiB reservation. The guest uses qcow2 copy-on-write storage:

```text
verified AlmaLinux base     ~562 MiB
            │
            └── uni-almalinux.qcow2
                  starts small
                  grows only as guest blocks change
                  snapshots add changed blocks
```

Actual consumption depends on packages, coursework and snapshots. `lab delete almalinux` removes guest-specific storage while retaining the reusable base; `lab purge-image almalinux` removes the base as well.

VM storage is managed by libvirt under `/var/lib/libvirt/images/virtualization-lab`, not inside the Git repository. SSH keys and known-host state stay under the user's local XDG data directory.

## Isolation and security

The default boundary is deliberately restrictive:

- no host directories are mounted into the guest;
- SPICE USB redirection is disabled;
- the guest uses the dedicated `lab-nat` NAT network instead of joining the LAN directly;
- `virbr-lab` is not marked as a trusted firewall interface; only DHCP/DNS services required for NAT are opened to the guest;
- SSH password authentication is disabled by cloud-init;
- root login is disabled;
- a dedicated Ed25519 key is generated locally per host and never committed;
- the guest receives only that public key;
- VM disks, snapshots, ISOs and guest credentials remain local runtime state and are ignored by Git.

`student` has passwordless sudo inside the VM because this guest is explicitly an administrative sandbox. That privilege does not grant sudo on the NixOS host.

## Updating the image

Do not silently follow upstream `latest`. To move to a newer AlmaLinux build:

1. choose the exact Generic Cloud image;
2. verify its official checksum;
3. update `version`, `build`, `filename`, `url` and `sha256` in `inventory/virtualization-lab.nix`;
4. validate the change through the normal repository checks;
5. remove the old local base only when desired with `lab purge-image almalinux` after deleting the guest.
