# Tailscale Fleet Access

This layer makes Tailscale and SSH access part of the declared fleet state while
keeping node credentials and control-plane credentials outside Git and the Nix
store.

## Source of truth

`inventory/tailscale.nix` owns the intended tailnet access policy. Host
participation still comes from `inventory/workstations.nix` through the
`connectivity.tailscale` and `connectivity.ssh` capabilities.

The current network policy is deliberately narrow:

- a tailnet member may reach only devices owned by that same user
  (`autogroup:self`)
- TCP `22` is allowed for SSH
- TCP `22000` is allowed for the declared Syncthing fleet
- UDP `4242` is allowed for Lan Mouse input sharing
- incoming Tailscale connections are explicitly enabled on fleet nodes instead
  of depending on the mutable `shields-up` client preference
- Tailscale SSH uses `check` mode, requires periodic reauthentication and permits
  only the local `anthony` account
- root login remains disabled in the fallback OpenSSH daemon

No Tailscale auth key, API token, node private key or node state is stored in the
repository.

## Local desired state

For every host with `connectivity.tailscale = true`, NixOS enables `tailscaled`
and reapplies the declared machine name and incoming-connection policy with:

```text
tailscale set --hostname=<fleet-host> --shields-up=false
```

For every host with `connectivity.ssh = true`, it also reapplies:

```text
tailscale set --ssh
```

The generated `tailscaled-set` unit retries after failure. This matters on a new
machine because the first NixOS activation can happen before the node has joined
the tailnet. After the one-time Tailscale login succeeds, the desired hostname,
incoming-connection policy and SSH mode are applied without requiring another
NixOS activation.

## Tailnet control-plane policy

The policy stored in Nix can be rendered with:

```bash
nix run .#tailscale-policy
```

The output is strict JSON and can be used as the tailnet policy document in the
Tailscale admin console.

Applying the document is currently an explicit external control-plane action.
The repo does not contain a Tailscale API credential. A later secrets/control-
plane layer may automate that write while keeping the credential outside Git.

Apply or verify the tailnet policy before enabling Tailscale SSH on machines you
can reach only through an existing remote SSH session.

## First activation on an existing host

Prefer activating this change from the host's local session. Enabling Tailscale
SSH causes `tailscaled` to take ownership of connections to port 22 on the
Tailscale IP, so an existing SSH session over the tailnet may be interrupted on
the first transition.

After activation:

```bash
fleet-ssh --check
fleet-ssh --list
fleet-ssh thinkpad
```

`fleet-ssh HOST` uses `tailscale ssh`, which checks the destination SSH host key
against the key advertised by the Tailscale coordination server.

Normal OpenSSH client usage is also generated from the fleet inventory:

```bash
ssh thinkpad
ssh desktop
ssh victus
```

Those aliases use `tailscale nc` as their `ProxyCommand`, so the standard SSH
client is still forced through the local Tailscale daemon rather than depending
on system DNS, a stored Tailscale IP or an alternate network path. This exists
for tools that expect the standard `ssh` executable, including future
`nixos-rebuild --target-host` fleet deployment.

## New machine bootstrap

A fresh host still needs a one-time tailnet login because the node identity is
runtime secret state:

```bash
sudo tailscale up
```

Complete the browser authentication. The retrying `tailscaled-set` unit then
converges the declared machine name, incoming-connection policy and Tailscale SSH
setting automatically.

No machine-specific Tailscale IP is recorded in Git. Fleet access uses the
canonical declared host names (`desktop`, `thinkpad`, `victus`) and lets the
Tailscale daemon resolve them at runtime.

## Break-glass OpenSSH

The hardened system OpenSSH daemon remains enabled but is not exposed globally.
Port 22 is allowed only on `tailscale0`.

If Tailscale SSH itself must be disabled from a physical/local console:

```bash
sudo tailscale set --ssh=false
```

Standard OpenSSH can then receive tailnet port 22 using the versioned authorized
public key. Password authentication, keyboard-interactive authentication and
root login remain disabled. The generated SSH aliases still traverse Tailscale
through `tailscale nc`.

Re-enable the declared state afterwards with:

```bash
sudo systemctl restart tailscaled-set.service
```

or by activating the NixOS configuration again.

## State ownership

| State | Owner |
|---|---|
| fleet host names and connectivity capabilities | `inventory/workstations.nix` |
| allowed tailnet ports, incoming policy and SSH policy | `inventory/tailscale.nix` |
| Tailscale daemon/SSH desired state | NixOS |
| SSH client host aliases and Tailscale proxying | Home Manager |
| node identity/private key | local Tailscale runtime state |
| tailnet policy API credential | external secret, not currently required by repo |
| control-plane policy application | explicit external action |
