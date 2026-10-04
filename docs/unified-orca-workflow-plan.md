# Unified Orca, workspace, identity and tooling plan

## Status

Implementation plan for one feature branch and **one pull request**.

This supersedes the intent of the stale `feat/orca-shared-workspace-skill`
branch. Do not merge that branch into this work; reimplement the useful ideas
against current `main`.

The managed workstation fleet is **Desktop + Victus**. ThinkPad is retired and
must not be reintroduced by this change.

## Goal

Make the development environment predictable regardless of whether work starts
from a normal terminal, VS Code, Kiro, OpenCode, Codex, Claude Code or Orca.

The final model should have:

- one canonical workspace layout;
- deterministic work/personal/neutral identity routing;
- two Syncthing roots, one for work and one for personal data;
- one canonical fleet skill source consumable by every supported agent;
- one MCP registry and policy layer rather than hand-maintained copies;
- Orca as the main orchestration/worktree surface, without making Orca the
  source of truth for fleet policy;
- clear ownership of runtime credentials and secrets;
- a smaller, more deliberate development toolset;
- a separate platform profile for cloud/DevOps/security tooling;
- no automatic deletion or migration of local user data.

## Baseline findings

Current `main` already provides useful foundations:

- Desktop and Victus share one daily Home Manager environment and the same
  development/data-science/creative profiles.
- Work is currently the default identity.
- Personal Git identity is selected for `~/projects/` and `~/nixos-config/`.
- GitHub defaults to the work SSH key.
- HTTPS GitHub URLs are globally rewritten to SSH using that work default.
- The AWS wrapper allows only the two declared read-only profiles, but defaults
  to the work profile.
- Shell context switching is currently driven by a Zsh `chpwd` hook.
- The fleet AI environment manages context, skills and optional MCP entries for
  Codex, Claude Code and Kiro.
- OpenCode is intentionally left user-owned.
- Orca is installed on both current workstations and inherits the available
  agent binaries, but does not own fleet skills/MCP policy.
- Syncthing currently declares one `Sync/Fleet` folder.
- Nixpkgs/Home Manager/AI tooling received a recent targeted refresh, so this
  work should avoid an unrelated blanket lockfile update.
- `profiles/home/database-tools.nix` appears orphaned and the README claims
  Insomnia is installed although the active development profile does not install
  it. Normalize documentation and remove dead configuration only after
  confirming there is no consumer.

## Design principles

1. **Unknown is not work.** The default authenticated context becomes
   `neutral`, not `work`.
2. **Policy must be enforced by wrappers, not only agent prose or shell hooks.**
3. **One source, many adapters.** Skills and MCP metadata are canonical; tool
   specific files are generated/reconciled.
4. **Orca orchestrates; Nix owns fleet policy.**
5. **Mutable credentials never enter Git or the Nix store.**
6. **Syncthing is for user/shared state, not Git repositories or build caches.**
7. **Project toolchains stay project-owned whenever practical.**
8. **Installed software is not assumed to consume RAM while closed.** Resource
   changes require measurements rather than package-count intuition.
9. **No feature branch is activated.** Build/check on branches, deploy only
   reviewed/published `main`.

---

# 1. Canonical workspace layout

Replace the current loose roots with:

```text
~/Workspace/
├── work/
│   ├── repos/
│   ├── worktrees/
│   └── shared/
└── personal/
    ├── repos/
    ├── worktrees/
    └── shared/
```

Use the word `personal`, not `own`, because the repository and existing
identity model already use `personal`.

### Ownership

- `repos/`: primary Git checkouts.
- `worktrees/`: user-created worktrees when a tool allows choosing a path.
- `shared/`: documents and state that should actually travel between Desktop
  and Victus.
- Orca may keep a worktree outside these paths. Identity resolution must still
  work for such worktrees; see context resolution below.

### Existing repositories

Do not move, delete or reclone repositories automatically during Home Manager
activation.

Provide a documented runtime migration procedure. `~/nixos-config` remains an
explicit personal compatibility root until the user moves the checkout to
`~/Workspace/personal/repos/config-nixos`. The normal configuration tooling
must support `NIXOS_CONFIG_DIR` throughout the transition.

---

# 2. Context model: neutral, work, personal

Replace the current two-state/default-work model with:

```text
neutral
work
personal
```

`neutral` is the default.

## Context resolver

Implement one canonical resolver used by all wrappers and shell presentation.
It must not depend only on Zsh.

Resolution order:

1. If the current path is under `~/Workspace/work`, resolve `work`.
2. If it is under `~/Workspace/personal`, resolve `personal`.
3. If it is a Git worktree outside those roots, call the **real managed Git
   binary** and inspect `git rev-parse --path-format=absolute --git-common-dir`.
   If the common Git directory belongs to a primary checkout under one of the
   canonical roots, inherit that context.
4. During migration, recognize explicit compatibility roots such as
   `~/nixos-config` as personal.
5. Otherwise resolve `neutral`.

The Git-common-dir rule is required for Orca because Orca-created worktrees are
not guaranteed to live below the primary repository path.

Expose a small command surface:

```sh
workspace-context status
workspace-context doctor
workspace-context exec work -- <command>
workspace-context exec personal -- <command>
```

Keep `work-context` only as a temporary compatibility alias if existing local
automation uses it.

The shell hook may export a visible `WORK_CONTEXT` value for prompts and
interactive convenience, but authorization must not depend on that hook.

---

# 3. Git and SSH identity enforcement

## Git

Remove the assumption that a global Git identity is work.

Target behavior:

- work context -> work name/email + work SSH identity;
- personal context -> personal name/email + personal SSH identity;
- neutral context -> no commit identity; `user.useConfigOnly=true` makes a
  commit fail instead of silently using either account.

Provide a managed Git wrapper that resolves context at invocation time and then
executes the real Nix-managed Git.

This is important for:

- Orca agents;
- GUI-launched tools;
- dependency managers;
- noninteractive Codex/Claude/OpenCode commands;
- shells that did not run the Zsh `chpwd` hook.

Do not globally rewrite every GitHub HTTPS URL to the work identity.

Public HTTPS dependency access must continue to work from neutral context.
Private Git access should use the context-selected SSH command or explicit
aliases.

## SSH

Retain explicit aliases:

```text
github.com-work
github.com-personal
```

The generic `github.com` host must no longer silently select the work key in
neutral context.

The context-aware Git wrapper supplies an explicit `GIT_SSH_COMMAND` with the
correct key and `IdentitiesOnly=yes` for work/personal operations.

Direct SSH users may still use the explicit aliases.

---

# 4. GitHub CLI separation

GitHub CLI currently lacks the same path-level context contract.

Manage separate runtime directories:

```text
~/.config/gh/work/
~/.config/gh/personal/
```

A managed `gh` wrapper resolves the workspace context and exports the matching
`GH_CONFIG_DIR`.

Target behavior:

- work path -> work GitHub login/config;
- personal path -> personal GitHub login/config;
- neutral -> no authenticated GitHub CLI context; fail authenticated operations
  with a clear message.

Provide helpers such as:

```sh
gh-login work
gh-login personal
gh-whoami
```

Never copy tokens between contexts and never place `hosts.yml` in the Nix
store or Syncthing.

---

# 5. AWS context enforcement

Keep the current read-only operation allowlist and the requirement that the
underlying IAM role is itself read-only.

Change selection behavior:

- work path -> `work-readonly`;
- personal path -> `personal-readonly`;
- neutral -> refuse AWS operations unless the user explicitly uses a context
  command such as `aws-work` or `aws-personal`.

Do not default an unset context to work.

Keep:

```text
aws-work
aws-personal
aws-login
aws-profile-setup
aws-whoami
```

Update diagnostics so the resolved workspace context and AWS profile are shown
together.

---

# 6. Syncthing: exactly two user roots

Replace the single managed `Sync/Fleet` folder with two folders:

```text
~/Workspace/work
~/Workspace/personal
```

Both are shared between Desktop and Victus.

Use separate Syncthing folder IDs, for example:

```text
fleet-work
fleet-personal
```

## Ignore policy

Do **not** replicate Git repositories, Orca worktrees or rebuildable caches just
because the parent directory is synchronized.

Manage/seed an ignore policy that excludes at minimum:

```text
repos/
worktrees/
.git/
.direnv/
node_modules/
.venv/
build/
dist/
coverage/
.gradle/
.dart_tool/
target/
__pycache__/
*.lock.tmp
```

Also exclude:

- agent sessions/state;
- Orca mutable state;
- AWS/GitHub/SSH credentials;
- MCP tokens;
- secret files;
- VM/container storage;
- database data directories.

Git remains the source of truth for source repositories. Syncthing carries the
human/shared files around them.

Changing the declared folders must not delete the previous `Sync/Fleet`
contents. Document a manual migration/checklist and let the reconciler only
retire its managed Syncthing declaration.

---

# 7. Universal AI skill layer

## Canonical source

Keep fleet-owned skills under:

```text
ai/skills/<skill>/SKILL.md
```

Publish the same sources into the Agent Skills compatible root:

```text
~/.agents/skills/fleet-*
```

This becomes the preferred universal discovery layer.

Retain assistant-specific links/adapters where a supported harness still needs
them:

```text
~/.codex/skills/
~/.claude/skills/
~/.kiro/skills/
```

Do not duplicate skill bodies.

## OpenCode

The previous repository decision intentionally left OpenCode configuration
unmanaged. This requirement changes that boundary.

OpenCode now supports both global `~/.agents/skills` and
`~/.claude/skills` discovery. Integrate it conservatively:

- fleet skills are visible through the shared Agent Skills root;
- preserve providers, models, permissions and credentials;
- manage only bounded `fleet-*` MCP/config entries if an adapter is needed;
- never overwrite user-owned OpenCode settings wholesale.

## Orca-owned skills

Do not make Home Manager own the files that Orca itself updates.

Install/update Orca's own thin skills through Orca's supported skill flow:

- `orca-cli`;
- `orchestration`;
- `computer-use`;
- optionally `orca-emulator-android` when Android automation is explicitly
  enabled.

Provide a helper such as:

```sh
orca-skills-sync --dry-run
orca-skills-sync
```

It may invoke the version-matched Orca CLI, but it must not perform network
mutation automatically during Home Manager activation.

## Fleet Orca skill

Promote the useful idea from the stale Orca branch into the canonical skill
tree, e.g.:

```text
ai/skills/fleet-orca-workspaces/SKILL.md
```

It should teach agents to:

- inspect existing Orca repo/worktree/terminal state before creating duplicates;
- resolve the current workspace context;
- respect project `nix develop`/direnv environments;
- keep concurrent agents in separate Git worktrees;
- remember that worktrees isolate files, not ports, containers, databases or
  credentials;
- load Orca's version-matched `orca-cli` or orchestration guide before using
  unfamiliar/mutating commands;
- never self-update managed agent binaries;
- never deploy a NixOS feature branch.

---

# 8. MCP: one registry, context-aware adapters

Keep:

```text
ai/mcp/registry.nix
ai/mcp/policy.nix
```

as the canonical source.

Extend supported consumers to include OpenCode.

Do not make Orca Settings a second independent MCP source of truth. Agents
launched by Orca should receive the same fleet-managed MCP configuration they
receive outside Orca.

If Orca exposes a stable supported CLI/config API for MCP reconciliation, add an
adapter later in this same implementation only after validating its ownership
contract. Do not patch opaque mutable Orca state.

## Registry metadata

Extend entries as needed with non-secret metadata such as:

```text
context = any | work | personal
authentication = none | oauth | runtime-env | runtime-file
requiredSecrets = [...]
```

The generated adapter must refuse a context-restricted MCP in the wrong
workspace.

A registry entry means "known", not "enabled".

## Secrets

Install `sops` and `age` as tooling, but do not commit work or personal
credential material to this public repository.

Define a runtime secret contract outside the store, separated by context.
Harness-native OAuth is preferred when appropriate. File/env secrets must be
resolved only at runtime.

---

# 9. Orca as the primary orchestration surface

Orca remains an application managed by Nix/Home Manager, while its sessions,
credentials and mutable state stay user-owned.

## Update

The repository currently pins Orca 1.4.216. Update to the current reviewed
stable release during implementation and revalidate:

- the native shell patch match count;
- Electron/native module patching;
- CLI behavior;
- externally-managed updater detection;
- SSH ownership behavior;
- application start/restart;
- skill commands.

Verified on 2026-10-04, GitHub's latest non-prerelease release is **v1.4.220**
(published 2026-10-04). The repository pin at plan creation remains 1.4.216, so
an update is available and is part of this implementation.

Do not enable Orca's own self-updater to mutate Nix-managed application files.

## Permissions

Set **Settings -> Agents -> Agent Permissions -> Manual** as the recommended
fleet mode for uncustomized Codex/Claude launches. Orca's built-in default
otherwise pre-fills approval-bypass flags for supported agents.

Manual mode keeps the agent's native approval/question flow available so a
human can review sensitive decisions locally or from Orca Mobile.

The fleet credential wrappers remain authoritative regardless of Orca's agent
permission mode. A mobile approval must never be able to bypass the
work/personal/neutral credential boundary.

## Mobile control and approvals

Treat Orca Mobile as a first-class control surface for long-running agent work,
not as the execution host. Desktop/Victus remains the source of truth for the
agent session.

For recognized chat-capable agents such as Claude and Codex, validate Orca
Mobile Chat UI with:

- readable session transcript and status;
- sending follow-up prompts from the phone;
- Claude structured questions such as `AskUserQuestion`;
- Codex structured approval/question requests that Orca currently supports;
- approving/rejecting agent permission prompts from the phone where exposed;
- switching a session between Chat UI and Terminal View;
- using Terminal View as the fallback when a prompt is not represented as a
  structured mobile card;
- reconnecting to the same paired workstation without starting a duplicate
  agent session.

Do not rely on push notifications as a correctness mechanism for every pending
approval. The workflow must remain recoverable by opening Orca Mobile and
checking sessions that are `waiting on input`.

Record the known upstream limitation: open issue
`stablyai/orca#20073` reports that Codex `request_user_input_async` questions
may show their prose on mobile without the expected decision card. This is not
a reason to use YOLO mode globally. Validate the installed Orca/Codex versions
after the update and keep Terminal View as the fallback until upstream closes
or supersedes that issue.

The E2E acceptance must use the user's Android phone paired to each workstation
being validated. At plan update time, the releases page lists
`mobile-android-v0.0.52` as the newest Android companion release; prefer that
release (or a newer reviewed mobile release) for acceptance rather than relying
on the older APK version mentioned in static documentation. No automated build
check can prove the mobile interaction.

## Remote use

Do not reintroduce a permanent server role merely for Orca.

After local context routing is stable, validate Orca SSH worktrees between
Desktop and Victus over the existing Tailscale/SSH boundary. Both machines
remain autonomous workstations.

Remote execution is optional and must not make either machine a required
dependency for normal local work.

---

# 10. Development toolchain audit

The recent lock refresh means this PR should perform **targeted upgrades**, not
blindly update every input.

## API tooling

Current active profile contains Bruno, Postman, HTTPie, grpcurl, cloudflared,
Harlequin and usql.

### Bruno: primary GUI API client

Pinned Nixpkgs currently provides Bruno 4.0.0 while upstream 4.2.1 was released
with security fixes and explicitly recommends upgrading.

Upgrade Bruno to 4.2.1 in this PR. If the pinned nixpkgs revision has not caught
up, add a small reviewed package override/pin rather than refreshing unrelated
inputs.

Treat Bruno as the normal GUI client because collections live well alongside
Git/project workflows.

### Postman: compatibility client, fix NixOS integration

Pinned Nixpkgs already provides Postman 12.20.1. Do **not** treat the reported
local instability as simply an old-version problem.

Nixpkgs has a known Postman issue where opening the file chooser can hang with:

```text
No GSettings schemas are installed on the system
```

Implement a narrow wrapper that supplies the GTK GSettings schema directory
required by the pinned package. Validate import/file chooser, login, request
send, clipboard and restart under the actual Hyprland session.

Do not introduce Snap into the NixOS architecture merely because upstream
recommends it on conventional distributions.

Do not force native Wayland as part of this fix. Keep the packaging behavior
conservative and test XWayland/default behavior first.

If the wrapped desktop application remains unreliable, keep Postman available
as a compatibility/optional tool rather than the primary local client and
document the web-app fallback.

### Posting: terminal client

Add Posting for fast keyboard/SSH/API work.

At plan creation the pinned Nixpkgs package is 2.10.0 while upstream 2.11.0 adds
local request/response history and improved environment handling. Prefer 2.11.0
if it can be pinned cleanly; otherwise use the current Nixpkgs package and note
the version difference.

### Hurl: reproducible API tests

Add Hurl to the development profile.

Use it for repository-owned integration/API tests that should run identically
from a developer shell and CI. GUI collections remain useful for exploration;
Hurl files are the preferred automation artifact when a project needs
repeatable request/assertion flows.

### Insomnia

The README currently says Insomnia is installed, but the active profile does
not install it.

Do not add another always-installed GUI client merely to make the README true.
Remove the stale claim or expose Insomnia only as an optional `nix run`/flake
package if there is a concrete use case.

## Database tools

Keep the deliberate split:

- DbGate -> primary general GUI client;
- DBeaver -> optional fallback;
- Harlequin/usql -> terminal workflows.

Confirm `profiles/home/database-tools.nix` is unreferenced and remove it if it
is truly dead. Do not resurrect MySQL Workbench globally just because that stale
file mentions it.

## Editors/agent surfaces

Keep:

- Orca -> orchestration/worktrees/agent-centric primary surface;
- VS Code -> general editor fallback;
- Kiro -> Kiro-specific IDE/agent workflows;
- Neovim -> terminal-native editor.

Do not remove useful editors only to reduce package count.

## Global SDK compatibility

The current Node/Go/GCC/Python switches already describe themselves as legacy
global compatibility.

Keep them for existing projects in this PR, but make new project documentation
prefer:

```text
nix develop + direnv + project lockfiles
```

Migrate projects individually before disabling global compatibility switches.

Flutter/Android remains workstation-level because it is an active daily
workflow; do not remove it solely for purity.

---

# 11. Small high-value developer utilities

Add lightweight general utilities where they improve many workflows:

- `fd` — filesystem search complement to ripgrep;
- `yq` — YAML processing complement to jq;
- `just` — repository command recipes;
- `watchexec` — repeat tests/builds on changes;
- `hyperfine` — reproducible command benchmarks;
- `nvd` — inspect Nix generation/package differences.

Evaluate `nix-index` with a prebuilt database approach before enabling it;
avoid making every machine build a large index locally just to support
`comma`.

Do not add another replacement for the repository's existing `nix-config`
workflow unless it solves a measured problem.

---

# 12. Platform profile: cloud, DevOps, security and networking

Create a separate Home profile such as:

```text
platform
```

Desktop and Victus may both select it. Keeping it separate makes ownership clear
and allows future lighter machines to omit it.

Suggested baseline:

## Infrastructure

- OpenTofu;
- Terragrunt;
- kubectl;
- Helm;
- k9s;
- Kustomize;
- kubectx/kubens;
- stern.

Prefer OpenTofu globally. Projects that specifically require HashiCorp Terraform
must pin the required Terraform version in their own devShell rather than
silently substituting it.

## Containers / supply chain

- Trivy;
- Syft;
- Grype;
- Cosign;
- Dive;
- gitleaks.

Docker remains socket-activated and must not start merely because these tools are
installed.

## Secrets

- sops;
- age.

## Network/security diagnostics

Add CLI diagnostics useful for labs and development:

- nmap;
- mtr;
- iperf3;
- DNS utilities (`dig`/host);
- tcpdump.

Wireshark may be installed separately if desired, but do not grant additional
capture privileges globally without an explicit security decision.

## Keep project/lab-specific

Do not put every possible lab runtime in the global profile.

Keep these project-specific unless repeated use proves otherwise:

- kind/k3d/minikube;
- local Kubernetes clusters;
- GitHub Actions `act`;
- Semgrep rule packs;
- language-specific security scanners;
- heavy ML frameworks;
- project Terraform versions;
- databases/queues/cluster daemons.

---

# 13. Resource policy

Retain the current conservative resource policy unless new measurements justify
a change:

- Nix max-jobs/cores 2/2;
- weighted/batch Nix daemon;
- ZRAM;
- bounded journal;
- Docker socket activation;
- no permanent K3s/CI/server workload.

Adding command-line packages does not mean their processes run in the
background.

After the migration, measure Desktop and Victus under:

1. normal interactive development;
2. Orca with one agent;
3. Orca with two concurrent agents;
4. Android build;
5. Docker workload;
6. Nix build.

Only then consider changing Nix parallelism, agent concurrency or memory
policies.

---

# 14. Diagnostics

Extend `ai-doctor` or add a unified doctor that reports without leaking
credentials:

- host;
- resolved workspace context;
- canonical primary Git repository/common-dir;
- Git identity selected;
- GitHub CLI context selected;
- AWS profile selected;
- fleet skill count;
- Orca-owned skill discovery;
- supported agents installed;
- enabled MCP IDs for the current context;
- RTK integration;
- Syncthing folder declarations;
- Postman wrapper presence;
- important platform-tool availability.

Never print tokens, private keys or secret values.

---

# 15. Validation

## Static/build checks

At minimum:

```sh
nix fmt
nix flake check --no-build --no-write-lock-file
nix-check all
```

Add focused tests for:

- neutral/work/personal context resolver;
- Git-common-dir inheritance from an external worktree;
- work and personal commit identity;
- neutral commit refusal;
- correct work/personal SSH key;
- neutral GitHub authenticated refusal;
- separate GH_CONFIG_DIR selection;
- correct AWS profile;
- neutral AWS refusal;
- Syncthing folder IDs and ignore policy;
- no ThinkPad in managed inventory/peers;
- Agent Skills links;
- OpenCode preservation/reconciliation;
- MCP context allow/deny behavior;
- duplicate skill/MCP IDs;
- secret values absent from generated store-backed configuration;
- Postman wrapper arguments/environment;
- platform profile evaluation on both workstations.

## Runtime acceptance on both Desktop and Victus

After merge and deployment from clean `main`:

1. Run `workspace-context doctor` in neutral, work and personal directories.
2. Create test commits in temporary work/personal repos and verify identities.
3. Verify a neutral commit fails.
4. Verify work and personal GitHub access independently.
5. Verify `gh-whoami` for both contexts.
6. Verify `aws-whoami work` / personal and neutral refusal.
7. Confirm Syncthing exposes only the new managed work/personal folders and does
   not remove local data.
8. Start new Codex, Claude, Kiro and OpenCode sessions and confirm fleet skills
   are discoverable.
9. Run `orca skills installed --json`; install/update the approved Orca skills
   explicitly.
10. Register one work repo and one personal repo in Orca.
11. Create Orca worktrees and confirm the resolver inherits the correct context
    even if the worktree directory is outside `~/Workspace`.
12. Verify agents launched inside those worktrees use the correct Git/GitHub/AWS
    boundary.
13. Test Postman import/file chooser and a local API request.
14. Test Bruno, Posting and one Hurl test.
15. Verify Docker remains inactive before first Docker API use.
16. Set Orca Agent Permissions to Manual and pair the Android companion.
17. Start one Claude session that asks a structured question/permission and
    answer it from Orca Mobile Chat UI; verify the desktop session continues.
18. Start one Codex session that requests an approval/question and answer it
    from mobile when a structured card is available.
19. Exercise the Codex async-question edge case; if the installed version still
    reproduces upstream issue #20073, confirm Terminal View can unstick the
    session without restarting or duplicating the agent.
20. Repeat the mobile approval path against the second workstation or its
    paired/remote session, confirming the phone always controls the original
    Desktop/Victus agent rather than creating a cloud-side copy.
21. Observe CPU/RAM pressure with one and two simultaneous Orca agents.

---

# 16. Migration and rollback

## Migration

The PR may create declarations, wrappers and empty canonical directories.

It must **not** automatically:

- move repositories;
- move personal/work documents;
- delete `Sync/Fleet`;
- delete old worktrees;
- delete Orca state;
- reauthenticate GitHub/AWS;
- copy credentials;
- remove Tailscale nodes;
- prune Docker/VM data.

Provide explicit post-deploy commands/checklists for those operations.

## Rollback

Rollback through a normal reviewed PR/main deployment.

Disabling the new AI adapters removes only entries recorded as fleet-owned.
User-owned agent configuration remains intact.

Retiring the new Syncthing declarations does not authorize deletion of files
already synchronized.

---

# 17. Implementation order inside the single PR

Although this is one PR, develop it in this order so every intermediate commit
has a clear purpose:

1. Context resolver and identity model.
2. Git/GitHub/AWS wrappers and tests.
3. Workspace directories and Syncthing policy.
4. Universal Agent Skills publication + OpenCode adapter.
5. Fleet Orca workspace skill and Orca skill helper.
6. MCP context model/runtime secret contract.
7. Orca package update.
8. API tool normalization and Postman fix.
9. Platform profile and lightweight developer utilities.
10. Dead config/docs cleanup.
11. Full checks/builds and migration documentation.

Do not activate intermediate feature-branch generations.

---

# Acceptance criteria

The PR is complete only when all of the following are true:

- Desktop and Victus are the only managed fleet members.
- `neutral` is the default credential context.
- Work and personal context is deterministic from both canonical paths and Orca
  external worktrees.
- Git, GitHub CLI and AWS enforce context independently of Zsh.
- There are exactly two managed Syncthing user roots: work and personal.
- Repositories/worktrees/caches/secrets are excluded from synchronization.
- Fleet skills have one canonical source and are visible to Codex, Claude,
  Kiro, OpenCode and Orca-discovered Agent Skills without copied bodies.
- Orca-owned skills remain Orca-owned/updatable rather than Home Manager-owned.
- MCP registry/policy is canonical and context-aware.
- No runtime secret value is written into Git or the Nix store.
- Orca is updated from 1.4.216 to the verified stable v1.4.220 (or a newer
  reviewed stable release if upstream publishes one before implementation) and
  its NixOS-specific package invariants are revalidated.
- Orca Agent Permissions is documented/validated in Manual mode for the
  supervised fleet workflow.
- Android Orca Mobile can answer at least one Claude structured
  question/permission and one supported Codex approval/question against the
  original workstation session.
- The Codex async-question limitation is explicitly tested and has a working
  Terminal View fallback while upstream issue #20073 remains unresolved.
- Bruno is updated to the reviewed 4.2.1 security release.
- Postman has the NixOS GSettings workaround and runtime acceptance evidence, or
  is explicitly documented as compatibility-only if it still fails.
- Posting/Hurl provide terminal and CI-friendly API workflows.
- README/tool documentation matches what is actually installed.
- A dedicated platform profile supplies the agreed cloud/DevOps/security tools.
- Existing project SDK compatibility remains intact.
- `nix-check all` and all focused policy tests pass.
- No automatic user-data deletion or unreviewed credential migration occurs.

## Research references

- Orca skills/MCP: https://www.onorca.dev/docs/cli/skills
- Orca CLI: https://www.onorca.dev/docs/cli/reference
- Orca worktrees: https://www.onorca.dev/docs/model/worktrees
- Orca releases: https://github.com/stablyai/orca/releases
- Orca Mobile: https://www.onorca.dev/docs/mobile
- Orca native Chat UI: https://www.onorca.dev/docs/agents/native-chat
- Orca agent permissions: https://www.onorca.dev/docs/agents/supported
- Codex mobile async-question bug: https://github.com/stablyai/orca/issues/20073
- OpenCode Agent Skills: https://opencode.ai/docs/skills
- Bruno releases: https://github.com/usebruno/bruno/releases
- Posting releases: https://github.com/darrenburns/posting/releases
- Hurl testing: https://hurl.dev/docs/running-tests.html
- Postman Linux requirements: https://learning.postman.com/docs/getting-started/installation/system-requirements
- Postman Linux install guidance: https://learning.postman.com/v11/docs/getting-started/installation/install-app
- Nixpkgs Postman GSettings issue: https://github.com/NixOS/nixpkgs/issues/504180
