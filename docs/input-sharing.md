# Input sharing across the workstation fleet

The workstations use Lan Mouse as a software KVM while keeping every machine
fully independent. Desktop and Victus can control each other; additional
workstations opt in explicitly through the inventory.

Every host still accepts its own keyboard, touchpad and USB mouse at all times.
Applications, CPU/GPU/RAM, storage and sessions remain local; Lan Mouse only
injects additional input events.

## Network and security model

- Lan Mouse runs on both Hyprland sessions.
- UDP 4242 is opened only on `tailscale0`; it is not opened on the normal LAN.
- Each reconciler obtains peer IPv4 addresses from `tailscale status --json`,
  so KVM traffic is explicitly addressed over Tailscale rather than relying on
  LAN DNS/mDNS.
- Lan Mouse still uses its own DTLS peer fingerprint authorization on top of
  Tailscale.
- Runtime DTLS key material and authorized fingerprints remain in
  `~/.config/lan-mouse/`; they are deliberately not stored in this repository.
- Every host uses the `layer-shell` capture backend and `wlroots` emulation.
  This avoids the known wlroots modifier-key limitation for a sender using a
  non-layer-shell backend.
- The selected profile is mutable local state under
  `~/.local/state/input-sharing/`; it contains no key or fingerprint.

## First activation

Do not activate this feature from the PR branch. After the PR is merged, update
the tailnet policy first. Render it with `nix run .#tailscale-policy`, compare it
with the active policy, and apply the reviewed result from the Tailscale Access
controls page. This repository validates and renders the policy but deliberately
does not publish it with unattended credentials.

Then update both machines from a clean `main` using the repository's normal
workflow:

```bash
nix-update
```

Check the user services:

```bash
input-share-status
lan-mouse cli list
```

The first run defaults to `all`, so every host configures the declared peer.
The allowed peers and their screen edges live in `inventory/hosts.nix`;
`input-share` derives their current Tailscale IPv4 addresses and persists the
selected topology into Lan Mouse's local runtime configuration.

## First-time pairing

Every receiver must explicitly trust each machine that will control it once per
Lan Mouse identity:

1. Ensure both machines are connected to the same tailnet (`tailscale
   status`).
2. On the sender, open `lan-mouse` and note its DTLS fingerprint.
3. On the receiver, open `lan-mouse` and select the sender profile with
   `input-share pair <receiver>` on the sender.
4. Move the pointer against the configured screen edge to create an incoming
   connection attempt.
5. Compare the presented fingerprint and choose **Authorize** only when it
   matches.
6. Repeat for the other directed pairs that you intend to use.

Authorization is persisted locally on the receiver. It is not committed to Git
and rebuilding NixOS does not make another machine trusted automatically.

## Operations

```bash
input-share status          # selected profile and active outgoing clients
input-share pair desktop    # control only Desktop from the current host
input-share pair victus     # control only Victus from the current host
input-share all             # activate all declared remote peers
input-share off             # disable outgoing control; keep incoming available
input-share reconcile       # re-resolve addresses and apply persisted selection
input-share-services        # systemd status for daemon + reconciler
input-share-logs            # follow both user-service logs
lan-mouse                   # graphical pairing/status frontend
```

`input-share pair` rejects the local host and any name outside the declared
peer allowlist. If a Tailscale node identity/IP changes, run `input-share
reconcile`. If the physical layout changes, update the `position` fields in
`inventory/hosts.nix` and merge/deploy normally rather than editing Lan
Mouse clients by hand.

## Clipboard

Clipboard synchronization is intentionally not part of this first integration.
Lan Mouse 0.11 does not provide clipboard support. Automatically forwarding
`wl-paste` over SSH on every screen transition would also copy sensitive
clipboard contents (passwords, tokens, private snippets) without an explicit
user action. A later implementation should therefore be opt-in and define MIME,
size, secret-filtering and direction rules before it is enabled.
