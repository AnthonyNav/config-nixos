# Repository Rules

- Work from current `main` on a short-lived branch and open a PR to `main`; do not deploy feature branches.
- Never commit secrets, credentials, tokens, private keys, `.env` files, or generated OpenCode catalog state.
- Never publish to GitHub automatically. The managed `/work` workflow may show an exact publication proposal but never executes it; publication requires a separate explicit user request and approval.
- For shared changes, run `nix fmt`, `nix flake check --no-build --no-write-lock-file`, and the required host and Home Manager activation builds for all affected workstations.
- Do not activate or deploy while developing. Follow `docs/maintainer.md` and `docs/nixos-development-guide.md` for `nix-switch`, `nix-home-switch`, and `nix-update` boundaries.
