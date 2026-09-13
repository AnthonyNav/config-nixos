# Generic Remote Workspace

The remote workspace is deliberately independent from any AI provider and is currently enabled only on `desktop`.

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
                       HTTPS 8448
                           |
                    authenticated tailnet
```

Zellij owns terminal sessions and its web authentication. Tailscale owns private network reachability and HTTPS publication. NixOS only declares installation, service lifetime, firewall policy, and integration with the workstation fleet.

No Claude, Codex, OpenCode, Kiro, GitHub, or model-provider credential is copied into this layer.

## Host scope

`desktop` is the only current Remote Workspace host. It publishes the localhost backend through private Tailscale HTTPS on port `8448`; port `8082` is never opened by the NixOS firewall.

ThinkPad and Victus deliberately set `features.remoteWorkspace.enable = false`. They remain normal interactive workstations reachable through Tailscale SSH without running a persistent Zellij Web service.

The tailnet policy remains self-scoped. Funnel is not used for the remote workspace; Desktop's separate Woodpecker endpoint remains the only public Funnel.

## First use

After activating the configuration on Desktop:

```bash
remote-workspace status
remote-workspace url
remote-workspace create-token
```

The login token is displayed once. Zellij stores only its hash locally, so keep the displayed token in an appropriate private credential store if it needs to be reused.

Open the URL reported by `remote-workspace url` from an authenticated Tailscale device and sign in with the Zellij token.

## Sessions

Normal Zellij usage remains available on Desktop:

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

The browser or phone is a client. Closing it does not own the lifetime of the Zellij session or the coding-agent process.

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

The Desktop user systemd manager uses linger so the web service can start at boot and survive logout. Host shutdown, reboot, suspension, or explicit session/process termination remain execution boundaries.

## Future Agent Hub

The planned Agent Hub belongs in a separate Linux-oriented repository. Its core must not depend on NixOS or Tailscale. This repository can consume Agent Hub as an integration while keeping the generic PTY path isolated to hosts that explicitly enable it.

Candidate optional adapters:

- OpenCode API / ACP
- Claude Code native remote capabilities
- Codex app-server
- generic command / PTY

No provider adapter may become a prerequisite for ordinary Tailscale SSH access.
