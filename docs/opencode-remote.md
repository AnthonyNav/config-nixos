# Secure Remote OpenCode Web

This layer lets an authenticated tailnet device, including an Android phone,
continue working against OpenCode processes that live on a NixOS workstation.
The phone is only a client: OpenCode, Git, builds, agents, Kiro Gateway, files,
and process state remain on `desktop`, `thinkpad`, or `victus`.

## Architecture

```text
Android / another tailnet client
            |
            | private HTTPS :443
            v
      Tailscale Serve
            |
            | localhost only
            v
     127.0.0.1:4096
            |
            v
       OpenCode Web
```

`inventory/workstations.nix` decides which hosts have
`features.opencodeRemote.enable = true`. Shared listener/authentication policy
lives in `inventory/opencode-remote.nix`.

The OpenCode backend is deliberately bound to `127.0.0.1`. Port `4096` is not
opened in the NixOS firewall. Tailscale Serve is the only network-facing path
and publishes private HTTPS on port `443` to the tailnet.

## Authentication

There are two independent boundaries:

1. the Tailscale grant permits port `443` only to devices owned by the same
   authenticated tailnet user (`autogroup:self`)
2. OpenCode itself requires HTTP Basic Authentication

Home Manager creates the second credential locally at:

```text
~/.config/opencode-remote/server.env
```

The file is mode `0600` and contains only a randomly generated
`OPENCODE_SERVER_PASSWORD`. It is runtime secret state: it is never rendered by
Nix, committed to Git, or synchronized by the declared Syncthing fleet folder.

View the URL and credential when enrolling a phone:

```bash
opencode-remote credentials
```

Store the result in the phone's password manager. Do not place it in a project,
Git configuration, shell history, chat message, or repository.

Rotate it when a client should lose access:

```bash
opencode-remote rotate-password
```

## Persistence

Remote OpenCode is a `systemd --user` service. NixOS enables linger for the
fleet user on hosts that declare the remote capability, so the user manager and
OpenCode service start at boot and remain alive without an active graphical or
SSH login.

Closing the Android browser, changing networks, losing mobile data, or closing
an SSH client does not stop the OpenCode service. Rebooting, shutting down, or
suspending the workstation still makes that host unavailable and can interrupt
in-flight work.

The service uses the normal Nix-managed `opencode` wrapper, so it keeps the same
managed configuration, skills/plugins, and runtime Kiro Gateway integration as
an ordinary local OpenCode session.

## Tailscale HTTPS bootstrap

Tailscale Serve needs HTTPS certificates enabled for the tailnet. This is an
external control-plane consent and is intentionally not represented as a secret
inside this repository.

After applying the configuration locally on a host, inspect:

```bash
opencode-remote status
sudo systemctl status opencode-remote-serve.service
```

If Tailscale reports that HTTPS/certificates require approval, complete the
one-time consent using the URL/instructions printed by Tailscale, then retry:

```bash
sudo systemctl restart opencode-remote-serve.service
```

Enabling Tailscale HTTPS certificates causes the machine name and tailnet DNS
suffix used for the certificate to be published through Certificate
Transparency. Keep fleet machine names generic and non-sensitive.

No Funnel configuration is used. The service is private to the tailnet.

## Daily use from Android

On a workstation, get the endpoint once:

```bash
opencode-remote credentials
```

On Android:

1. connect the Tailscale client to the same tailnet
2. open the printed `https://...` URL in the browser
3. authenticate with username `opencode` and the generated password
4. select or continue the required OpenCode session/project

The browser can then disconnect without owning the service lifetime.

## Local/TUI interoperability

The same backend can be inspected from the host without traversing the network:

```bash
opencode-remote attach
```

For administrative work or a full terminal, use the independent fleet SSH path:

```bash
fleet-ssh thinkpad
ssh thinkpad
```

A later PR can add a standardized tmux/workspace layer for long-running terminal
jobs. This PR deliberately does not couple OpenCode Web to tmux.

## Diagnostics

```bash
opencode-remote status
opencode-remote url
opencode-remote logs
systemctl --user status opencode-remote.service
sudo systemctl status opencode-remote-serve.service
tailscale serve status
```

`opencode-remote status` verifies the local authenticated health endpoint as
well as Tailscale state. A healthy local backend with a failing Serve unit
usually indicates that the tailnet HTTPS consent/certificate setup is still
missing.

## Trust and state ownership

| State | Owner |
|---|---|
| enabled hosts | `inventory/workstations.nix` |
| backend port/auth username/Serve port | `inventory/opencode-remote.nix` |
| OpenCode service definition | Home Manager |
| persistent user manager (`linger`) | NixOS |
| private HTTPS publication | Tailscale Serve + NixOS |
| tailnet network authorization | `inventory/tailscale.nix` desired policy |
| OpenCode password | local runtime secret file |
| OpenCode sessions/data | local OpenCode runtime state |
| Kiro credentials/API key | existing local Kiro Gateway runtime state |
| Tailscale node identity/private key | local Tailscale runtime state |

Do not synchronize OpenCode state directories through Syncthing. The remote Web
client is the supported way to continue a session from another device while the
owning workstation remains the execution environment.
