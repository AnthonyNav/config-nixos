# Repository Rules

- Work from current `main` on a short-lived branch and open a PR to `main`; do not deploy feature branches.
- Never commit secrets, credentials, tokens, private keys, `.env` files, or generated OpenCode catalog state.
- Never publish to GitHub automatically; show the exact remote operation and obtain explicit user approval through the primary workflow agent first.
- For shared changes, run `nix fmt`, `nix flake check --no-build --no-write-lock-file`, and the required host and Home Manager activation builds for all affected workstations.
- Do not activate or deploy while developing. Follow `docs/maintainer.md` and `docs/nixos-development-guide.md` for `nix-switch`, `hm-switch`, and `nixos-update` boundaries.
