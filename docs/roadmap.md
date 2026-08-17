# Declarative Fleet Roadmap

This roadmap keeps cross-cutting changes in reviewable stacked pull requests.
Each layer builds on the declarative inventory introduced at the base of the
stack. A child PR must not merge before its parent.

## Current stack

1. **Fleet inventory and Git identities** — PR #9
   - canonical workstation inventory
   - capability-driven service enablement
   - fail-closed personal/work Git identity policy
   - GitHub namespace routing (`AnthonyNav` personal, `kigo` work)

2. **Declarative Syncthing topology** — PR #11
   - fleet-derived peer topology
   - Tailscale-only transport
   - managed shared folders with runtime device identity discovery

3. **Tailscale and SSH fleet access** — PR #13
   - versioned desired tailnet policy
   - Tailscale SSH and stable fleet host names
   - standard SSH forced through the Tailscale transport
   - diagnostics for live fleet reachability

4. **Secure remote OpenCode Web** — `agent/secure-opencode-remote-web`
   - persistent OpenCode Web backend on each declared host
   - localhost-only backend with an independent runtime password
   - private HTTPS publication through Tailscale Serve
   - Android/browser access without moving execution to the client
   - user service persistence through systemd linger

## Planned follow-up layers

5. **Remote workspace and session ergonomics**
   - explicit workspace/session discovery instead of ad-hoc project paths
   - standardized tmux fallback for terminal jobs that must survive SSH clients
   - diagnostics that distinguish OpenCode session state from terminal process
     state

6. **Mobile completion/error notifications**
   - bridge selected OpenCode lifecycle events to an Android-capable notification
     service
   - notify only on meaningful completion/error states, not every agent event
   - keep notification credentials outside Git/Nix store

7. **Fleet deployment**
   - `nix-config fleet status`
   - `nix-config fleet check`
   - `nix-config fleet deploy HOST`
   - guarded `nix-config fleet deploy all`
   - exact Git revision and target host recorded for every deployment
   - transport through the declared Tailscale/OpenSSH fleet path

8. **OpenCode validation from inventory**
   - remove duplicated host names from managed OpenCode validation allowlists
   - derive trusted host/build targets from `fleetInventory`

9. **Agent skills as a pinned external input**
   - move reusable skills to the dedicated skills repository
   - consume the repository as a pinned flake input
   - keep NixOS as the declarative selector of installed skill packs

10. **External control-plane policy automation**
    - Tailscale policy application without committing API credentials
    - GitHub repository/ruleset settings as code where practical
    - preserve explicit separation between desired policy and secret/runtime state

11. **Remaining reproducibility work**
    - pin/fix-output themed wallpapers
    - move the standalone Blender artifact into a Nix derivation
    - reduce the mutable Kiro Python bootstrap where it provides real value
    - add managed-vs-runtime drift reporting

12. **DevOps and security capability profiles**
    - add host-selectable DevOps tooling
    - add small baseline security profile
    - keep specialized/offensive tools in explicit dev shells or labs rather
      than every workstation

## Stacking rule

While the base PRs are open, create each new branch from the exact head of its
parent PR and target the parent branch. After a parent lands, retarget or rebase
the direct child onto the new parent (`main` or the next surviving branch)
without merging unrelated layers together.
