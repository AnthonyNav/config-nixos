# Desktop creative + ML workstation

Desktop uses the same `creative-ml-development` Home Manager role as Victus:
mobile and web/backend development, AI tools, API/database clients including
DbGate, Micromamba, DuckDB, JupyterLab, creative applications, and the
`work-balanced`, `work-performance`, and `work-save` helpers. Orca remains enabled.
Project-specific ML frameworks and CUDA SDKs belong in project environments.

The i5-12400F has no integrated GPU; the RTX 3060 Ti remains the direct renderer.
The existing three-monitor layout and generated disk/hardware configuration
are retained. NVIDIA Container Toolkit provides CDI for requested GPU
containers. Virtualization Lab, Tailscale SSH, Syncthing, Lan Mouse, audio,
Bluetooth and Pritunl remain available.

Desktop uses the shared two-job/two-core Nix policy, existing 50% zstd ZRAM,
and Docker socket activation. Caelestia locking and display power management
remain active; Hypridle can suspend after 30 minutes. Hibernation, hybrid sleep
and suspend-then-hibernate stay disabled. SSH reachability follows the host's
awake state.

## Retired infrastructure and retained state

The declared Desktop configuration no longer includes K3s, either Woodpecker
agent, infrastructure UI forwarding, Tailscale Serve/Funnel publication, or the
persistent Zellij web terminal. Kubernetes and CI capabilities still permit
future explicit experiments through the reusable lab modules.

Retirement does not delete server data. Preserve the K3s datastore and local
volumes under `/var/lib/rancher/k3s`, other persistent-volume paths discovered on
the host, `/var/lib/kubelet`, runtime credentials under `/etc/rancher/k3s` and
`/etc/woodpecker`, Docker volumes (including both Woodpecker agent config
volumes), Zellij token/session state, and user projects. Ephemeral agent
containers may disappear through their existing `--rm` lifecycle; their named
config volumes remain. Do not run uninstall scripts or volume/system pruning.

## Authorized rollout from published main

Publication and deployment require separate explicit authorization. Complete
the fleet builds and review first, merge to published `main`, then follow this
procedure on Desktop with authenticated sudo and local recovery access. Do not
activate the feature branch. Builds alone leave the old services running.

1. Record the active and booted system paths and the previous Home generation.
   Inspect active CI jobs, Kubernetes workloads and persistent-volume locations
   without printing credential files. Let active jobs finish and shut down
   stateful applications cleanly before retiring the runtime.
2. Stop both agents and the web terminal before the update to avoid new work:

   ```sh
   sudo systemctl stop woodpecker-agent-desktop.service woodpecker-agent-frontend.service
   systemctl --user stop remote-workspace.service
   ```

3. Inspect any other Docker infrastructure containers and remove their automatic
   restart policies, then stop only those containers. Use the actual recorded
   name in `docker update --restart=no NAME` and `docker stop --time=60 NAME`;
   keep their volumes and configuration. This prevents a later Docker API call
   from reviving the server workloads.
4. Run `nix-update` from the clean Desktop checkout of `main`. The new system
   and Home configuration remove the managed infrastructure units and their
   Serve/Funnel handlers. Check `tailscale serve status` and `tailscale funnel
   status` for residual handlers. The read-only audit also found an unmanaged
   server publication on HTTPS `8449`; withdraw it explicitly:

   ```sh
   sudo tailscale serve --https=8449 off
   ```

   Retired managed ports were HTTPS `443`, TCP `9000`, and HTTPS `8443`–`8448`.
   If a handler on one of those ports remains, turn off only that handler with
   the matching `tailscale serve` or `tailscale funnel` command. Preserve the
   node's Tailscale identity and ordinary connectivity.
5. Check `loginctl show-user anthony -p Linger`. If the old linger marker remains
   after activation, run `sudo loginctl disable-linger anthony`.
6. Reboot during the authorized rollout window. The pinned K3s unit uses
   `KillMode=process`, so stopping its main process alone may leave container
   workloads alive. A reboot after removal clears old runtimes and transient
   cluster networking without deleting their disk state.
7. After confirming that server publications are gone, render
   `nix run .#tailscale-policy`. A tailnet administrator reviews the active
   policy and removes obsolete server grants, preserving unrelated rules.
   The repository policy now grants only SSH TCP/22, Syncthing TCP/22000 and
   Lan Mouse UDP/4242. Review any external Desktop-specific Funnel permission
   at the same time. This repository does not mutate the tailnet policy.

## Runtime verification

After reboot, check Docker before invoking its API:

```sh
systemctl is-active docker.service
systemctl is-enabled docker.service docker.socket
loginctl show-user anthony -p Linger
systemctl --no-pager list-units --all 'k3s*' 'woodpecker*' '*-private-*' 'remote-workspace*'
systemctl --user --no-pager list-units --all 'remote-workspace*'
tailscale serve status
tailscale funnel status
ss -ltnup
nvidia-smi
systemctl status nvidia-container-toolkit-cdi-generator.service
```

Expect the Docker daemon to be inactive with its socket enabled, no active
retired workloads or server publications, and `Linger=no`. Retained data must
still be present. Connect again through Tailscale SSH from another machine,
check Syncthing and Lan Mouse, and inspect the real Hyprland/Caelestia session
with all three monitors. Test a GPU container, locking, display power management,
and suspend/resume with local access available. These runtime checks are
separate from evaluation and build validation.

If rollback is required, inspect `nix-generations` and use the documented
rollback commands. The previous generation can start the old infrastructure
again against its retained data; review that effect before selecting it.
