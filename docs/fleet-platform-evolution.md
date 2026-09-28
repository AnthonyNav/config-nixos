# Platform Evolution Roadmap

This document is the entry point for the planned evolution of this repository.
It tracks the implementation sequence; it does not authorize activation or deployment.

## Goals

- Keep system, user, AI and project responsibilities separate.
- Give Desktop and Victus the same logical CI/CD, Kubernetes and lab capabilities.
- Add an older IdeaPad as a minimal headless deployment laboratory.
- Treat Tailscale SSH reachability as a critical IdeaPad invariant.
- Move project-specific SDKs toward devShell + nix-direnv.
- Maintain one declarative source for global AI context, skills, MCP definitions
  and RTK policy.
- Defer macOS until a real Mac and a dedicated validation path are available.

## Target ownership model

```text
Fleet
  -> Host
      -> System
      -> User
          -> AI environment
          -> Project environment
```

Use capabilities rather than host-name conditionals whenever behavior is shared.

## Planned documents

- [Lab platform and IdeaPad server](lab-platform-plan.md)
- [Global AI environment](ai-environment-plan.md)
- [Project environments and macOS](project-darwin-plan.md)

## Structural prerequisites

1. Reduce the responsibilities owned directly by `flake.nix`.
2. Make host platform/system explicit instead of using one global
   `x86_64-linux` value.
3. Support a headless host without a desktop style.
4. Split shared system behavior into common, workstation, server and
   lab-platform responsibilities.
5. Replace the single workstation-oriented host set with capability-derived
   sets such as SSH hosts, input-sharing hosts, lab hosts and server hosts.
6. Replace inappropriate hardcoded Linux home paths with platform-aware values
   before adding Darwin.

A possible future boundary is:

```text
flake/
modules/system/{common,workstation,server,lab-platform}/
modules/home/{common,linux,darwin}/
hosts/{nixos,darwin}/
ai/{context,skills,mcp}/
```

Do not move files solely for aesthetics; introduce boundaries incrementally.

## Implementation sequence (three PRs)

### PR 1 — fleet foundation and reusable laboratory

Combine the structural and fleet changes with the extraction of K3s, CI agents
and publication modules. Preserve the current three workstations, including
their GPU, power, firewall and running-service configuration. Desktop and
Victus declare equivalent lab capabilities; enabling an instance is a separate
host policy decision. Validate an undeployed synthetic headless host so the
foundation does not depend on access to the IdeaPad.

Operational fixes to existing Desktop instances are also deferred until the final
stage; this PR only extracts their current declarations.

The implementation uses `inventory/hosts.nix`, derived sets in
`inventory/fleet.nix`, composition in `flake/hosts.nix`, and
`modules/system/{common,workstation,server,lab-platform}`. Home Manager and
desktop selection are optional. Commands and CI skip absent Home outputs.

### PR 2 — global AI environment

Implement canonical context, skills, harness adapters, RTK policy, MCP registry
and diagnostics as one coherent change. Follow [ai-environment-plan.md](ai-environment-plan.md).
Do not reintroduce the removed custom OpenCode configuration or kiro-gateway.

PR 2 is implemented in #65. Native harness/runtime validation remains a
post-deployment check; see [ai-environment.md](ai-environment.md).

### PR 3 — project isolation and final server onboarding

Standardize project devShell patterns, migrate toolchains incrementally, and
replace global workarounds only after validating their project replacements.
Preserve working Flutter/Android tooling during the transition.

The first project-isolation slice adds per-language compatibility switches and
a separate switch for the global Jupyter library workaround. All remain enabled
until project validation; see [project-environments.md](project-environments.md).
Six local project migrations and their validation are tracked in
[project-migration-status.md](project-migration-status.md). Remaining consumers
and Flutter hardware/runtime checks still gate global fallback removal.

Leave IdeaPad onboarding until the end. Inspect hardware and confirm identity
and remote access before adding a real host, selecting a Kubernetes role or
setting resource limits. If access remains unavailable, finish project isolation
and keep onboarding explicitly pending; do not invent hardware configuration.
First activation and reboot/access verification happen only from reviewed main
with a recovery path, following [lab-platform-plan.md](lab-platform-plan.md).

macOS and distributed builders/cache work are outside these three PRs.
Revisit them only with concrete hardware and measured build needs.

## Rules for implementation agents

Every implementation PR derived from this roadmap must:

1. start from current `main`;
2. state the phase/workstream being implemented;
3. preserve unrelated host behavior;
4. prefer reusable capabilities over duplicated host code;
5. keep secrets and generated runtime state out of Git/Nix store outputs;
6. run formatting and relevant flake checks;
7. build every affected NixOS/Home Manager output without activation;
8. document runtime/manual validation when evaluation cannot prove behavior;
9. never deploy or activate from the feature branch;
10. update these documents if a deliberate architectural decision changes.

If an implementation request conflicts with current repository invariants or
this roadmap, surface the conflict instead of silently inventing a new design.
