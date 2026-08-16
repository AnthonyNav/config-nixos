# Security policy

This repository is intended to be publishable without runtime credentials.
Configuration may describe public identifiers, but secrets must remain outside
both Git and the Nix store.

## Never commit

- SSH private keys or VPN client profiles containing credentials.
- `.env` files, API keys, access/refresh tokens, passwords, or session cookies.
- Tailscale auth keys or node state.
- Kiro IDE/CLI credential databases or JSON token caches.
- Syncthing private keys/configuration copied from a live machine.
- Secret-manager exports or cloud credential files.

The repository `.gitignore` blocks common accidental credential artifacts, but
ignore rules are only a safety net; they do not make committed secrets safe.

## Runtime secret locations

Current integrations deliberately keep their sensitive state outside the repo:

- Kiro Gateway: `~/.config/kiro-gateway/.env` plus the local Kiro credential
  stores discovered by its bootstrap.
- SSH: private keys under `~/.ssh/`; only an SSH public key is declared here.
- Tailscale: node identity/authentication is owned by `tailscaled` runtime
  state, not Nix source.
- Lan Mouse: its locally generated DTLS certificate/key and authorized peer
  fingerprints live in `~/.config/lan-mouse/` and are not managed by Git.

## Publication gate

Before making the repository public, run the same historical secret scan used
by CI:

```bash
nix run .#gitleaks -- git --redact --no-banner
```

The GitHub workflow checks out full history (`fetch-depth: 0`) so this scan
covers deleted/renamed historical content as well as the current tree.

If a real secret is found in any commit, removing the file in a later commit is
not sufficient. Revoke/rotate the credential first, then rewrite the affected
Git history before publication and scan again.

## Public metadata review

The following are not authentication secrets, but can reveal identity or local
infrastructure and should be reviewed intentionally before publication:

- Git author email addresses.
- Machine/user hostnames.
- RFC1918/LAN addresses used by SSH aliases.
- Hardware/filesystem UUIDs in generated NixOS hardware configuration.
- SSH public keys and their comments.

An SSH public key is safe to distribute cryptographically; its private key is
what must remain secret. Key comments should avoid unnecessary personal data.
