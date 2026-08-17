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

`inventory/identities.nix` is the canonical Git identity and GitHub-routing
policy. Home Manager consumes it; modules must not duplicate account names,
email addresses, namespaces, SSH aliases or key paths.

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

Commit identity and repository authentication are independent policies.

### Commit identity

Commit author selection is directory-scoped and fail-closed:

- `~/personal/` uses the personal Git identity.
- `~/nixos-config/` is an explicit personal exception.
- `~/work/` uses the work Git identity.
- repositories outside those roots receive no default `user.name` or
  `user.email`; `user.useConfigOnly=true` prevents an accidental commit with a
  fallback identity.

### GitHub authentication

Repository access is namespace-scoped and is deliberately independent of the
checkout directory. This is required because package managers may clone private
Git dependencies into caches or temporary directories outside `~/work/`.

The declared policy is:

```text
github.com/AnthonyNav/* -> github.com-personal -> ~/.ssh/id_personal
github.com/kigo/*       -> github.com-work     -> ~/.ssh/id_work
all other GitHub repos  -> HTTPS
```

`github.com-kigo` remains as a compatibility SSH alias for existing corporate
remotes, but new configuration should use canonical GitHub URLs rather than
embedding local aliases into project files.

The URL rewrite policy accepts standard HTTPS, SCP-style SSH and `ssh://` GitHub
forms. Git selects the longest matching `insteadOf` prefix, so the declared
`AnthonyNav/` and `kigo/` routes take precedence over the generic SSH-to-HTTPS
fallback.

Projects and dependency manifests should therefore retain portable URLs such as:

```text
https://github.com/kigo/private-sdk.git
https://github.com/AnthonyNav/example.git
https://github.com/NixOS/nixpkgs.git
```

No `github.com-work` or `github.com-personal` alias needs to be committed to a
`package.json`, `go.mod`, `pubspec.yaml`, `.gitmodules` or similar project file.
The same routing applies when Git is invoked from a package-manager cache or a
temporary directory.

### Daily Git usage

Normal Git commands do not change:

```sh
cd ~/personal
git clone https://github.com/AnthonyNav/REPOSITORY.git

git pull
git commit -m "feat: example"
git push
```

```sh
cd ~/work
git clone https://github.com/kigo/REPOSITORY.git

git pull
git commit -m "feat: example"
git push
```

The URL chooses the authentication identity; the checkout root chooses the
commit identity.

### Verification

Run after activating Home Manager:

```sh
identity-doctor
```

The command performs local checks only. It verifies required SSH key paths,
commit identity selection under the canonical roots, SSH aliases, namespace URL
rewrites, the public HTTPS fallback and the fail-closed Git identity setting.
It uses `git ls-remote --get-url` to expand `insteadOf` rules without contacting
the remote repository.

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
