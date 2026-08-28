# Virtualization lab

The workstation fleet provides an opt-in KVM/QEMU lab for disposable or
isolated operating-system work. It is intended for university exercises,
experiments and future security/DevOps labs that should not modify the NixOS
host.

## Architecture

```text
NixOS host
└── libvirt + QEMU/KVM
    └── guest VM
        ├── independent filesystem
        ├── independent packages and services
        └── qcow2 virtual disk / snapshots
```

The hypervisor layer is declared by `modules/system/virtualization-lab.nix`.
Each machine opts in through `features.virtualizationLab.enable` in
`inventory/workstations.nix`.

The initial rollout enables the capability on `desktop`, `victus` and
`thinkpad`. Enabling the capability installs the virtualization stack but does
not create a VM, download an ISO, reserve a fixed guest disk, or start a guest.
Guest storage is therefore consumed only when a VM is created.

## Host behavior

When enabled, the module provides:

- libvirt with QEMU/KVM;
- Virt-Manager for graphical VM administration;
- `virsh`/libvirt CLI tools;
- `dnsmasq` for the normal libvirt NAT-network workflow;
- membership of the local `libvirtd` group for the configured user.

Guests that happened to be running are not automatically resumed by the
NixOS `libvirt-guests` policy after a host boot. Host shutdown requests a clean
ACPI shutdown of running guests instead of suspending them.

Shared folders and SPICE USB redirection are intentionally not provisioned by
this baseline. Add host/guest integration only when a concrete lab needs it.

## First activation

After the configuration is merged, deploy through the normal repository
workflow:

```bash
nix-update
```

Confirm that hardware virtualization is visible:

```bash
ls -l /dev/kvm
```

Then confirm libvirt and open the manager:

```bash
systemctl status libvirtd --no-pager
virsh list --all
virt-manager
```

If `/dev/kvm` is unavailable, verify Intel VT-x/VT-d or AMD-V/AMD-Vi in the
machine firmware before creating guests.

## AlmaLinux university VM

The hypervisor PR deliberately does not commit or automatically download an
AlmaLinux image. The first guest should be created after this base is deployed
and validated.

A reasonable starting profile for `uni-almalinux` is:

```text
vCPU:         2-4
RAM:          4 GiB
virtual disk: 30-40 GiB qcow2 (thin/dynamic)
network:      libvirt NAT
firmware:     UEFI or BIOS as required by the course
```

The qcow2 disk is sparse: its virtual capacity is not the same as physical SSD
usage. Keep a clean base snapshot before exercises and create additional
snapshots only when they are useful, because changed blocks consume real host
storage.

## Isolation policy

The VM boundary is used primarily to keep experimental packages, services,
users and system configuration out of NixOS. Treat guests as separate machines:

- do not mount arbitrary host project directories by default;
- do not enable USB passthrough unless a lab requires it;
- prefer NAT networking for ordinary university work;
- store VM disks outside this Git repository;
- never commit ISOs, qcow2 images, snapshots or guest credentials.

A later change may automate a reproducible AlmaLinux base image and disposable
per-lab overlays after the three hosts have validated this virtualization layer.
