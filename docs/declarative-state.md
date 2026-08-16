# Declarative State Model

This repository defines the desired state of the workstation fleet. The goal is
not to put every runtime file in Git, but to make every relevant piece of state
belong to an explicit ownership class.

## Source of truth

`inventory/workstations.nix` is the canonical fleet inventory. A workstation
entry owns its role, desktop style, connectivity capabilities and host feature
selection. `flake.nix` derives NixOS/Home Manager configurations and exposes the
path-free `lib.fleetInventory` view for modules that need information about
other declared hosts.

Connectivity is capability-driven:

- `connectivity.tailscale` enables the Tailscale service.
- `connectivity.ssh` enables hardened OpenSSH and port 22 only on `tailscale0`.
- `connectivity.syncthing` enables Syncthing and its transport ports only on
  `tailscale0`.
- SSH or Syncthing cannot be enabled without Tailscale.
- Input sharing requires the Tailscale capability because its Lan Mouse traffic
  is also restricted to `tailscale0`.

Adding a host or changing its role/capabilities must start in the inventory
instead of duplicating host names in another module.

## State ownership classes

### Declarative

State that defines how the machine should behave belongs in Nix whenever
possible: packages, services, firewall rules, user policy, desktop composition,
Git/SSH routing, host capabilities and validation rules.

### Declarative with runtime resolution

Some desired state is declared by logical identity but resolved from live state.
Lan Mouse is the current example: peer host names and positions are declared,
while current Tailscale IP addresses are resolved at runtime.

### Secrets

Private keys, tokens, passwords and application credentials never enter Git or
the Nix store. Nix may declare the expected location, permissions, dependent
service and bootstrap/verification flow without owning the secret value.

### Mutable runtime state

Application state that must remain writable stays outside the store when that
mutability is part of the application's contract. Examples include Tailscale
node identity, Syncthing private identity, Lan Mouse trust fingerprints and
Caelestia's user-editable shell state.

Mutable state is not unmanaged state: its owner, location and reconstruction or
pairing procedure must remain documented.

## Personal and work Git identities

Git identity selection is directory-scoped and fail-closed:

- `~/personal/` uses the personal Git identity and `~/.ssh/id_personal`.
- `~/nixos-config/` is an explicit personal exception.
- `~/work/` uses the work Git identity and `~/.ssh/id_work`.
- repositories outside those roots receive no default `user.name` or
  `user.email`; `user.useConfigOnly=true` prevents an accidental commit with a
  fallback identity.

The generic SSH host `github.com` intentionally has no usable identity. Managed
repositories rewrite common GitHub SSH/HTTPS remote forms to one of the
explicit aliases:

```text
github.com-personal -> ~/.ssh/id_personal
github.com-work     -> ~/.ssh/id_work
github.com-kigo     -> ~/.ssh/id_work  (compatibility alias)
```

For a new clone, select the account explicitly because the destination Git
repository does not exist yet when the initial network connection is made:

```sh
git clone git@github.com-personal:AnthonyNav/REPOSITORY.git ~/personal/REPOSITORY
git clone git@github.com-work:ORG/REPOSITORY.git ~/work/REPOSITORY
```

Existing work repositories outside `~/work/` should be moved into the canonical
root before applying this Home Manager generation. Existing remotes inside a
managed root do not need to be rewritten manually; the conditional Git config
maps standard `github.com` SSH/HTTPS forms to the correct alias.

Useful verification after activation:

```sh
git -C ~/nixos-config config user.email
git -C ~/nixos-config config --get-regexp '^url\..*\.insteadof$'
ssh -G github.com-personal | grep -Ei '^(hostname|user|identityfile) '
ssh -G github.com-work | grep -Ei '^(hostname|user|identityfile) '
```

## Change rule

When adding a feature, answer these questions before implementation:

1. What is the desired state?
2. Which part can be represented directly in Nix?
3. Which secret state is required and where does it live?
4. Which mutable runtime state is unavoidable?
5. How is the resulting state bootstrapped and verified?

A manual step is acceptable when it represents an intentional trust or secret
boundary. A manual step that merely duplicates deterministic configuration is a
candidate for future declarative automation.
