# Lab Platform and IdeaPad Server Plan

## Scope

This document defines the target laboratory capabilities for Desktop, Victus
and the future IdeaPad server. The reusable foundation is implemented by PR 1;
real IdeaPad onboarding is deferred until the final stage and hardware inspection.
The address suggested during planning is not a verified hardware identity.

## Implemented module interface

Modules live under `modules/system/lab-platform/` and are disabled unless
configured. No current workstation enables a K3s, CI or publication instance.
Desktop's former instances have been retired; see
[desktop-workstation.md](desktop-workstation.md). Both Desktop
and Victus declare `capabilities.kubernetes` and `capabilities.ci`; ThinkPad
does not. Capability is permission to configure a workload, not an instruction
to start it. Both use Docker on demand and retain their hardware-specific GPU policy.

An independent Victus experiment could add this to its host module:

```nix
fleet.lab.kubernetes = {
  enable = true;
  clusterInit = true;
  autoStart = false;
};
```

An agent instead needs `role = "agent"`, a `serverAddr`, and an absolute
runtime `tokenFile` outside the Nix store. Do not put the token into Nix.
Kubernetes memory limits are optional per-instance `memoryHigh`/`memoryMax`.
A CI instance is keyed by systemd name:

```nix
fleet.lab.ci.agents.woodpecker-agent-lab = {
  description = "Victus lab CI agent";
  environmentFile = "/run/secrets/woodpecker-agent";
  server = "lab-server:9000";
  hostname = "victus-lab";
  labels = "repo=owner/project";
  containerName = "woodpecker-agent-lab";
  configVolume = "woodpecker-agent-lab-config";
  autoStart = false;
};
```

CI requires enabled Docker and a dedicated root-owned runtime secret file.
The agent has one workflow slot by default. Docker bridge gRPC/Testcontainers
firewall exceptions are explicit options, not defaults for every runner.

`fleet.lab.publication.privateUis` maps service names to Kubernetes namespace,
service, servicePort, localPort and tailscalePort. It requires an auto-started
local K3s server and Tailscale. Forwarding binds localhost; publication uses
Tailscale Serve. Woodpecker Funnel requires the additional explicit
`woodpecker.public.enable` opt-in. Update `inventory/endpoints.nix` and review
the rendered tailnet policy whenever adding a published instance on another
host. The current endpoint registry contains only workstation connectivity;
examples such as `lab-server:9000` are not deployed hosts.

Validation covers all three real system/Home outputs and an undeployed server
fixture with no Home Manager, desktop, audio, Bluetooth, Docker or Kubernetes.
That fixture verifies SSH hardening, Tailscale settings, endpoint membership,
exclusion from input sharing and server sleep defaults. It cannot prove actual
hardware support, authentication, runtime workloads or reboot reachability.
After the Desktop retirement rollout, verify the absence of K3s/CI/Serve/Funnel
services, both GPU paths, and workstation sessions. No activation occurs during
development.

## Desktop and Victus parity

Desktop and Victus must expose the same logical lab capabilities:

- container workloads;
- Kubernetes experimentation;
- CI/CD experimentation;
- deployment testing;
- virtualization lab;
- Tailscale connectivity;
- reusable infrastructure modules.

Hardware remains different:

- Desktop uses direct NVIDIA graphics.
- Victus uses AMD + NVIDIA PRIME/offload and laptop power behavior.

GPU topology must not determine whether a host can experiment with Kubernetes
or CI/CD.

### Migration direction

Reusable infrastructure is already extracted under
`modules/system/lab-platform/`. It includes:

- K3s configuration;
- Woodpecker-compatible runner/agent definitions;
- Kubernetes UI forwarding/publication helpers;
- CI network/firewall helpers;
- shared resource controls.

Do not copy Desktop services directly into Victus. Extract a capability first,
then choose which service instances each host enables.

### Topology is policy, not capability

The architecture should support different experiments without redefining hosts.

Examples:

```text
Desktop -> independent K3s lab
Victus  -> independent K3s lab
IdeaPad -> deployment target
```

or:

```text
Desktop -> K3s server
Victus  -> K3s agent
IdeaPad -> K3s agent
```

No topology is selected by this plan.

## Fleet inventory changes

The fleet model should distinguish host kind from capabilities.

Illustrative shape:

```nix
desktop = {
  kind = "workstation";
  resourceClass = "high";
  capabilities = {
    development = true;
    labPlatform = true;
    kubernetes = true;
    ci = true;
    virtualization = true;
    gpuCompute = true;
    inputSharing = true;
  };
};
```

```nix
victus = {
  kind = "workstation";
  resourceClass = "high";
  capabilities = {
    development = true;
    labPlatform = true;
    kubernetes = true;
    ci = true;
    virtualization = true;
    gpuCompute = true;
    inputSharing = true;
  };
};
```

```nix
ideapad = {
  kind = "server";
  resourceClass = "legacy-low";
  capabilities = {
    labPlatform = true;
    deploymentLab = true;
    kubernetes = true;
    ci = true;
    inputSharing = false;
  };
};
```

The exact field names may change.

Derive independent sets for all fleet hosts, SSH hosts, Syncthing hosts,
input-sharing hosts, lab hosts, workstations and servers. Do not add the
IdeaPad to workstation-only peer logic.

## IdeaPad server purpose

The IdeaPad is an older laptop intended as a minimal headless NixOS server for:

- deployment experiments;
- lightweight Kubernetes/node experiments;
- CI runners/agents appropriate to its resources;
- remote services;
- isolated/destructive infrastructure experiments.

It is not another graphical workstation.

### Server defaults

Avoid by default:

- Hyprland/Caelestia;
- X11/Wayland sessions;
- browsers;
- Android Studio/Flutter;
- graphical editors;
- PipeWire/audio;
- Bluetooth;
- creative applications;
- workstation-only Home Manager profiles.

The target system layering should allow:

```text
Desktop = common + workstation + lab-platform
Victus  = common + workstation + lab-platform
ThinkPad = common + workstation
IdeaPad = common + server + selected lab-platform
```

## IdeaPad hardware gate

Before resource tuning, record:

- exact model;
- CPU and architecture;
- core/thread count;
- RAM;
- disk type/capacity/health;
- network interfaces;
- battery condition;
- virtualization support.

An implementation agent must not invent these values.

## Resource policy

After measurement, evaluate:

- zram as a fast swap tier;
- encrypted emergency disk-backed swap when justified;
- userspace OOM protection such as systemd-oomd;
- bounded Nix build parallelism;
- low CPU/IO priority for background Nix work;
- cgroup limits for CI/Kubernetes services;
- minimizing resident daemons;
- remote observability rather than a heavy local stack.

Do not copy limits from another host without evidence.

### Power/server behavior

When acting as infrastructure:

- lid close must not suspend;
- idle must not suspend required workloads;
- display/graphical services should remain absent;
- required services should recover after reboot according to policy.

The battery may provide short-term resilience but is not a guaranteed UPS.

### Kubernetes role

Choose the role from measured hardware and the current experiment:

- capable legacy hardware: lightweight independent K3s server;
- constrained memory: K3s agent;
- very constrained hardware: deployment target without resident cluster.

Do not force Grafana, Prometheus, Argo CD, CI server, registry and application
workloads to run locally just because the IdeaPad has lab capability.

## Tailscale SSH invariant

Remote administration of the headless IdeaPad must remain available through the
tailnet.

The inventory must declare:

```nix
connectivity = {
  tailscale = true;
  ssh = true;
};
```

Expected effective behavior:

- `tailscaled` enabled;
- deterministic Tailscale hostname `ideapad`;
- incoming Tailscale connectivity enabled;
- Tailscale SSH enabled;
- OpenSSH enabled;
- password authentication disabled;
- keyboard-interactive authentication disabled;
- root login disabled;
- OpenSSH does not globally open TCP/22;
- TCP/22 is explicitly allowed on `tailscale0`;
- IdeaPad appears in `fleet-ssh --list`;
- `fleet-ssh ideapad` uses the tailnet;
- the tailnet SSH endpoint set includes IdeaPad.

The existing invariant that SSH requires Tailscale should remain.

### Required checks

Extend flake checks so configuration fails if the IdeaPad loses one of these
declared guarantees.

Validate at least:

- SSH implies Tailscale;
- IdeaPad has Tailscale + SSH enabled;
- expected Tailscale hostname/SSH/incoming flags are effective;
- OpenSSH hardening remains enabled;
- TCP/22 is allowed on `tailscale0`;
- IdeaPad is generated into fleet SSH client configuration;
- IdeaPad exists in the derived SSH endpoint set;
- IdeaPad is not added to input-sharing peers.

### First activation safety

Declarative configuration cannot guarantee power, Internet, hardware health or
an external Tailscale outage.

For the first deployment:

1. keep local/physical access;
2. authenticate Tailscale;
3. verify `tailscale status`;
4. verify `fleet-ssh ideapad` from another fleet host;
5. reboot;
6. verify remote access again;
7. only then treat the machine as safely headless.

Do not remove the last local recovery path before remote access survives a
reboot.

## Acceptance criteria

- Desktop and Victus declare equivalent lab capabilities.
- Shared lab behavior is implemented once rather than duplicated.
- Direct NVIDIA vs PRIME remains hardware-specific.
- IdeaPad evaluates/builds without a desktop environment.
- IdeaPad resource limits are based on measured hardware.
- Tailscale SSH invariants are enforced by checks.
- A server host does not become an input-sharing peer merely by joining the
  fleet.
