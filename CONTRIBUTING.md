# Contributing

`main` is the only deployment branch. Every workstation updates from it with
`nix-update`; do not deploy a host-specific or feature branch directly.
Machines predating that command need one final `git pull --ff-only` plus
`nix-switch` migration before using it.

## Workflow

1. Start from current `main` and create a short-lived branch with one purpose.
2. Keep generated hardware configuration in its host directory. Put shared
   behavior in shared modules, never in a host as a workaround.
3. Run `nix fmt` and the validations required by the affected scope.
4. Open a pull request to `main`. Do not push directly to `main`.
5. Wait for CI and review, then merge the PR. Machines receive the change with
   `nix-update`.

Use concise commit messages in the existing style, for example
`feat(home): add a shared command` or `fix(victus): restore suspend`.
Keep flake input updates in their own PR; they affect every host.

## Validation

Run for every Nix change:

```sh
nix-format
nix-check
```

Build every host after changing shared profiles, `flake.nix`, a desktop style,
or a common module:

```sh
nix-check all
```

For a host-only change, build that host. For NVIDIA or creative changes, build
both `victus` and `desktop`. Test graphical changes in a real session.

## Secrets And Local State

Never commit `.env` files, credentials, tokens, private keys, or generated
local application and agent state. Runtime credentials stay outside Git and
the Nix store.

## Repository Settings

Enable branch protection for `main` in GitHub: require a pull request, one
approval, and the Actions check contexts `check` and `full-build-gate`. CI executes
every repository check and builds NixOS plus Home Manager for every workstation.
The aggregate gate fails if inventory discovery or any build fails/is skipped.
Local full builds remain required. Disallow deletion, force pushes and direct
pushes to main.

The desired ruleset is `.github/main-ruleset.json`, targeting `refs/heads/main`.
Changing this file does not change GitHub settings. Apply it through the ruleset
API/UI under explicitly authorized repository administration. Verify effective
rules and match the check names to actual Actions runs. Publication, merge and
deployment are distinct actions.
