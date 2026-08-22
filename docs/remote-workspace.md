# Generic Remote Workspace

The remote workspace is deliberately independent from any AI provider.

## Architecture

```text
Claude Code / Codex / OpenCode / Kiro CLI / any terminal program
                           |
                       Zellij PTY
                           |
                    127.0.0.1:8082
                           |
                    Tailscale Serve
                           |
                       HTTPS 443
                           |
                    authenticated tailnet
```

Zellij owns terminal sessions and its web authentication. Tailscale owns private
network reachability and HTTPS publication. NixOS only declares installation,
service lifetime, firewall policy, and integration with the workstation fleet.

No Claude, Codex, OpenCode, Kiro, GitHub, or model-provider credential is copied
into this layer.

## Why Zellij

Zellij provides the universal fallback needed for terminal coding agents:

- persistent terminal sessions
- browser access
- mobile-specific controls
- authenticated login tokens
- session resurrection
- remote terminal attach

Provider-native APIs can be added later as optional adapters without changing
the baseline. A future Agent Hub can therefore enrich OpenCode, Claude, or
Codex sessions while every CLI remains usable through its terminal PTY.

## Network boundary

The Zellij web server listens only on `127.0.0.1:8082`. Port 8082 is not opened
by the NixOS firewall. Tailscale Serve is the only network-facing path and
publishes the local backend over private HTTPS on port 443.

The tailnet policy remains self-scoped. Funnel is not enabled.

## First use

After activating the configuration on a workstation:

```bash
remote-workspace status
remote-workspace url
remote-workspace create-token
```

The login token is displayed once. Zellij stores only its hash locally, so keep
the displayed token in an appropriate private credential store if it needs to
be reused.

Open the URL reported by `remote-workspace url` from an authenticated Tailscale
device and sign in with the Zellij token.

## Sessions

From a workstation terminal, normal Zellij usage remains available:

```bash
zellij --session backend
zellij --session mobile
zellij --session nixos
```

Inside those sessions run whichever CLI is appropriate:

```bash
claude
codex
opencode
kiro-cli
```

The browser or phone is a client. Closing it does not own the lifetime of the
Zellij session or the coding-agent process.

Useful diagnostics:

```bash
remote-workspace status
remote-workspace sessions
remote-workspace list-tokens
```

A read-only login can be generated with:

```bash
remote-workspace create-read-only-token
```

## Host lifetime

The user systemd manager uses linger so the web service can start at boot and
survive logout. Host shutdown, reboot, suspension, or explicit session/process
termination remain execution boundaries.

## Future Agent Hub

The planned Agent Hub belongs in a separate Linux-oriented repository. Its core
must not depend on NixOS or Tailscale. This repository will eventually consume
Agent Hub as one integration and keep Zellij/PTTY as the universal fallback.

Candidate optional adapters:

- OpenCode API / ACP
- Claude Code native remote capabilities
- Codex app-server
- generic command / PTY

No provider adapter may become a prerequisite for basic remote terminal access.
