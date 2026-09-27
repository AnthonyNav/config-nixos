# Platform Evolution Roadmap

This document is the entry point for the planned evolution of this repository.
It documents future work only; it does not authorize activation or deployment.

## Goals

- Keep system, user, AI and project responsibilities separate.
- Give Desktop and Victus the same logical CI/CD, Kubernetes and lab capabilities.
- Add an older IdeaPad as a minimal headless deployment laboratory.
- Treat Tailscale SSH reachability as a critical IdeaPad invariant.
- Move project-specific SDKs toward devShell + nix-direnv.
- Maintain one declarative source for global AI context, skills, MCP definitions
  and RTK policy.
- Prepare shared configuration for future Apple Silicon macOS via nix-darwin.

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

## Recommended implementation phases

### Phase 1 — platform foundation

- modularize root flake responsibilities;
- make host platform/system explicit;
- allow headless hosts;
- remove shared path assumptions that block server/Darwin portability.

### Phase 2 — fleet model

- split common/workstation/server concerns;
- introduce host kinds and capabilities;
- derive feature-specific host sets from inventory.

### Phase 3 — laboratory platform

- extract reusable K3s/CI/lab behavior from Desktop;
- give Desktop and Victus equivalent lab capability;
- preserve their different GPU/power implementations.

### Phase 4 — IdeaPad server

- inspect hardware first;
- add the minimal headless host;
- apply measured low-resource policy;
- enforce and validate Tailscale SSH;
- verify remote access after reboot before relying on headless operation.

### Phase 5 — global AI environment

- canonical global/platform/host context;
- canonical Agent Skills;
- harness adapters;
- RTK hooks/plugins where supported;
- MCP registry/policy;
- diagnostics and CI validation.

### Phase 6 — project isolation

- standardize per-project devShell patterns;
- move language/toolchain versions incrementally;
- remove the global Jupyter library workaround only after replacement;
- validate Flutter/Android behavior before changing working tooling.

### Phase 7 — macOS

- add nix-darwin only while onboarding a real Mac;
- reuse shared Home Manager/AI layers;
- add a Darwin-compatible build/validation path.

### Phase 8 — fleet build optimization

- evaluate distributed Nix builders;
- add a binary cache only when repeated private builds justify it;
- keep the low-resource IdeaPad out of heavy-build scheduling by default.

Do not combine all phases in one PR.

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
