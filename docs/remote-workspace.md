# Generic Remote Workspace

The optional remote workspace is independent from any AI provider. It is currently disabled on all fleet workstations. Desktop's former instance is retired as part of its [return to interactive workstation use](desktop-workstation.md); runtime tokens and session data are retained.

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

## Host scope and explicit opt-in

Desktop, ThinkPad and Victus set `features.remoteWorkspace.enable = false`.
They remain interactive workstations reachable through Tailscale SSH while
awake. The declared fleet has no Serve/Funnel publications or remote workspace
endpoints. The diagram above shows the former example port, not an active
endpoint.

The reusable system and Home Manager modules remain available. A future
reviewed opt-in must enable the host feature, add its HTTPS endpoint and tailnet
grant in `inventory/endpoints.nix`, and import `modules/home/remote-workspace.nix`
in that host's Home configuration. Its backend remains localhost-only on port
`8082`. Publication is private Tailscale Serve; the tailnet policy remains
self-scoped. The system module enables user linger only for an enabled host.
Re-enabling it on retired Desktop also requires removing that host's explicit
`users.users.${username}.linger = false` retirement setting.

## First use

After explicitly enabling the feature and deploying reviewed `main` on the selected host:

```bash
remote-workspace status
remote-workspace url
remote-workspace create-token
```

The login token is displayed once. Zellij stores only its hash locally, so keep the displayed token in an appropriate private credential store if it needs to be reused.

Open the URL reported by `remote-workspace url` from an authenticated Tailscale device and sign in with the Zellij token.

## Sessions

On an enabled host, normal Zellij usage remains available:

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

An enabled host uses user systemd linger so the web service can start at boot and survive logout. The current workstations do not enable linger. Host shutdown, reboot, suspension, or explicit session/process termination remain execution boundaries.

## Future Agent Hub

The planned Agent Hub belongs in a separate Linux-oriented repository. Its core must not depend on NixOS or Tailscale. This repository can consume Agent Hub as an integration while keeping the generic PTY path isolated to hosts that explicitly enable it.

Candidate optional adapters:

- OpenCode API / ACP
- Claude Code native remote capabilities
- Codex app-server
- generic command / PTY

No provider adapter may become a prerequisite for ordinary Tailscale SSH access.
