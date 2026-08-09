# Contributing

`main` is the only deployment branch. Every workstation updates from it with
`nixos-update`; do not deploy a host-specific or feature branch directly.

## Workflow

1. Start from current `main` and create a short-lived branch with one purpose.
2. Keep generated hardware configuration in its host directory. Put shared
   behavior in shared modules, never in a host as a workaround.
3. Run `nix fmt` and the validations required by the affected scope.
4. Open a pull request to `main`. Do not push directly to `main`.
5. Wait for CI and review, then merge the PR. Machines receive the change with
   `nixos-update`.

Use concise commit messages in the existing style, for example
`feat(home): add a shared command` or `fix(thinkpad): restore Wi-Fi roaming`.
Keep flake input updates in their own PR; they affect every host.

## Validation

Run for every Nix change:

```sh
nix fmt
nix flake check --no-build --no-write-lock-file
```

Build every host after changing shared profiles, `flake.nix`, a desktop style,
or a common module:

```sh
nix build --no-write-lock-file .#nixosConfigurations.victus.config.system.build.toplevel
nix build --no-write-lock-file .#nixosConfigurations.desktop.config.system.build.toplevel
nix build --no-write-lock-file .#nixosConfigurations.thinkpad.config.system.build.toplevel
```

For a host-only change, build that host. For NVIDIA or creative changes, build
both `victus` and `desktop`. Test graphical changes in a real session.

## Secrets And Local State

Never commit `.env` files, credentials, tokens, private keys, or generated
OpenCode catalog state. Kiro Gateway secrets belong in
`~/.config/kiro-gateway/.env`; its Python environment belongs in
`~/.local/share/kiro-gateway/`. The source revision is pinned by `flake.lock`
and the Python constraints live in `modules/home/kiro-gateway-requirements.txt`.

## Repository Settings

Enable branch protection for `main` in GitHub: require a pull request, one
approval, and the `Flake checks / check` plus all `Flake checks / plan-host-build`
jobs. CI evaluates and plans a build for every NixOS host; full NixOS host
builds remain required local validation. Disallow force pushes and direct
pushes.
