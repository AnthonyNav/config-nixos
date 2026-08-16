# Input sharing: desktop → Victus / ThinkPad

The workstations use Lan Mouse as a software KVM while keeping every machine
fully independent. Desktop is the only configured sender:

```text
[ Victus ]  <----  [ Desktop ]  ---->  [ ThinkPad ]
    left                                  right
```

Victus and ThinkPad still accept their own keyboard, touchpad and USB mouse at
all times. Their applications, CPU/GPU/RAM, storage and session remain local;
Lan Mouse only injects additional input events.

## Network and security model

- Lan Mouse runs on all three Hyprland sessions.
- UDP 4242 is opened only on `tailscale0`; it is not opened on the normal LAN.
- The desktop reconciler obtains peer IPv4 addresses from `tailscale status
  --json`, so the KVM traffic is explicitly addressed over Tailscale rather
  than relying on LAN DNS/mDNS.
- Lan Mouse still uses its own DTLS peer fingerprint authorization on top of
  Tailscale.
- Runtime DTLS key material and authorized fingerprints remain in
  `~/.config/lan-mouse/`; they are deliberately not stored in this repository.
- Desktop uses the `layer-shell` capture backend and all hosts use `wlroots`
  emulation. This avoids the known wlroots modifier-key limitation for a sender
  using a non-layer-shell backend.

## First activation

Do not activate this feature from the PR branch. After the PR is merged, update
all three machines from a clean `main` using the repository's normal workflow:

```bash
nix-update
```

Check the user services:

```bash
input-share-status
lan-mouse cli list
```

On Desktop the list should contain `victus` on the left and `thinkpad` on the
right. The topology is declared in `flake.nix`; `input-share-reconcile` derives
their current Tailscale IPv4 addresses and persists them into Lan Mouse's local
runtime configuration.

## First-time pairing

The receiver must explicitly trust Desktop once per Lan Mouse identity:

1. Ensure all three machines are connected to the same tailnet (`tailscale
   status`).
2. Open `lan-mouse` on Desktop and note its DTLS fingerprint.
3. Open `lan-mouse` on ThinkPad and Victus.
4. Move the Desktop pointer against the corresponding screen edge to create an
   incoming connection attempt.
5. On each receiver, compare the presented fingerprint with Desktop and choose
   **Authorize** only when it matches.
6. Move through the edge again. Keyboard and pointer input from Desktop should
   now control that receiver.

Authorization is persisted locally on the receiver. It is not committed to Git
and rebuilding NixOS does not make another machine trusted automatically.

## Operations

```bash
input-share-reconcile   # re-apply the declared peers/Tailscale addresses
input-share-status      # systemd status for daemon + reconciler
input-share-logs        # follow both user-service logs
lan-mouse               # graphical pairing/status frontend
lan-mouse cli list      # outgoing peers seen by the local daemon
```

If a Tailscale node identity/IP changes, run `input-share-reconcile` on Desktop.
If the physical layout changes, update the `position` fields in `flake.nix` and
merge/deploy normally rather than editing Lan Mouse clients by hand.

## Clipboard

Clipboard synchronization is intentionally not part of this first integration.
Lan Mouse 0.11 does not provide clipboard support. Automatically forwarding
`wl-paste` over SSH on every screen transition would also copy sensitive
clipboard contents (passwords, tokens, private snippets) without an explicit
user action. A later implementation should therefore be opt-in and define MIME,
size, secret-filtering and direction rules before it is enabled.
