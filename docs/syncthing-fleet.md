# Declarative Syncthing Fleet

Syncthing is managed as a fleet capability rather than as three independent
machine configurations.

## Source of truth

`inventory/workstations.nix` decides which hosts participate by setting:

```nix
connectivity.syncthing = true;
```

`inventory/syncthing.nix` owns the shared-folder policy and reconciliation
parameters. Host names are not duplicated there: `hosts = null` means every
Syncthing-enabled workstation from the fleet inventory.

The initial managed folder is intentionally isolated from repositories and from
Syncthing's historical default folder:

```text
~/Sync/Fleet
```

Its Syncthing folder ID is `fleet-shared`.

## Network model

Peer traffic is constrained to Tailscale:

- TCP port `22000` is opened only on `tailscale0`.
- Syncthing listens on TCP only.
- Global discovery is disabled.
- LAN discovery is disabled.
- Relays are disabled.
- UPnP/NAT traversal is disabled.

Syncthing's GUI/API remains local to the host. The reconciler talks to the local
API using the API key already generated in Syncthing's runtime configuration.

## Device identity without committing device IDs

Syncthing's private key and certificate remain runtime state. The repository
does not copy or generate them.

For each declared peer, `syncthing-fleet-reconcile`:

1. resolves the peer's IPv4 address from `tailscale status --json`;
2. connects to that peer's Syncthing TCP port over the tailnet;
3. reads the peer certificate presented by Syncthing;
4. derives the certificate SHA-256 based Device ID;
5. asks the local Syncthing API to normalize that ID;
6. configures the peer with the explicit `tcp://<tailscale-ip>:22000` address.

This makes the trust boundary explicit: Tailscale authenticates which node owns
the resolved tailnet IP, and the Syncthing certificate observed on that node is
then pinned as the application identity. A rebuilt host may receive a new
Syncthing certificate; the reconciler will learn the new Device ID for the same
declared Tailscale host.

Device IDs themselves are not secret, but avoiding a static registry means a
host can be rebuilt without manually copying public identifiers between
machines. The private `key.pem` never leaves its host.

## Reconciliation

The service runs at boot and a timer reconciles again every ten minutes. The
operation is transactional at the discovery stage: every peer must resolve and
expose a valid Syncthing certificate before any fleet configuration is changed.
If a peer is unavailable, the service exits temporarily and systemd retries.

Only objects owned by this mechanism are pruned:

```text
devices: fleet:*
folders: fleet-*
```

Existing manually managed devices and folders with other names/IDs are kept
intact during the migration.

## Verification

Inspect the topology without mutating Syncthing:

```bash
syncthing-fleet-reconcile --check
```

Inspect the systemd reconciliation state:

```bash
systemctl status syncthing-fleet-reconcile.service
systemctl status syncthing-fleet-reconcile.timer
journalctl -u syncthing-fleet-reconcile.service
```

The normal reconciliation can also be requested manually:

```bash
syncthing-fleet-reconcile
```

## Adding folders

Add another entry under `inventory/syncthing.nix`:

```nix
folders.notes = {
  id = "fleet-notes";
  label = "Notes";
  relativePath = "Documents/Notes";
  type = "sendreceive";
  hosts = null;
};
```

To share with only a subset of the fleet, use explicit host names:

```nix
hosts = [ "desktop" "thinkpad" ];
```

The module asserts that every referenced host exists and has Syncthing enabled.
Folder paths remain relative to the managed user's home directory.

## What remains runtime state

The following are intentionally not placed in Git or the Nix store:

- Syncthing `key.pem`;
- Syncthing `cert.pem`;
- local database/index state;
- the GUI/API key;
- transient Tailscale IP addresses.

Their ownership and reconstruction paths are defined, while their mutable or
secret values remain local to each machine.
