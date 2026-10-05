# Orca Remote Workspace Plan

## Status

Documental proposal for the phase **after PR #77**.

This plan does not implement services, open ports, move repositories, or change
credentials. It defines the target workflow so a later implementation can be
reviewed against one contract.

The managed fleet remains:

- Desktop
- Victus

ThinkPad remains retired.

## Goal

Make development resumable from Desktop, Victus or Android without repeatedly
explaining the environment to each agent.

The target experience is:

1. Desktop is normally online and acts as the **primary Orca runtime**.
2. Android can supervise and continue the same Orca sessions remotely.
3. Victus can connect to that same runtime or continue working locally.
4. Every logical project lives in one simple workspace directory.
5. Every workspace carries a durable `HANDOFF.md` so any agent can resume the
   work without depending on the memory of the previous process.
6. Git remains the source of truth for source code; Syncthing is not used to
   replicate active Git repositories.
7. The design remains optional: if Orca Server is unavailable, local development
   on either workstation still works.

---

# 1. Workspace model

The user-facing model is intentionally small:

```text
~/Workspace/
├── work/
│   └── <workspace>/
│       ├── HANDOFF.md
│       ├── docs/
│       ├── assets/
│       └── repos/
│           ├── repo-a/
│           └── repo-b/
└── personal/
    └── <workspace>/
        ├── HANDOFF.md
        ├── docs/
        ├── assets/
        └── repos/
```

A **workspace** is a logical project or initiative. It can contain one or many
Git repositories.

Examples:

```text
~/Workspace/work/cello
~/Workspace/work/estoma
~/Workspace/personal/finance-app
~/Workspace/personal/nixos
```

No additional required `project.json`, `.code-workspace`, metadata database,
or custom project manifest is needed for the first version.

## Syncthing boundary

Synchronize workspace-level files such as:

- `HANDOFF.md`
- `docs/`
- `assets/`
- notes
- PDFs
- screenshots and other non-Git project resources

Do not synchronize:

- `repos/`
- Orca worktrees
- `.git/`
- `.direnv/`
- `node_modules/`
- `.venv/`
- build outputs
- caches
- secrets
- agent runtime/session state

Git transports source code. Syncthing transports the non-Git workspace context.

---

# 2. HANDOFF.md is the durable project memory

Every workspace has exactly one root `HANDOFF.md`.

Its purpose is to make progress recoverable across:

- Codex
- Claude Code
- OpenCode
- Kiro
- Orca restarts
- workstation changes
- mobile sessions
- agent replacement

Recommended structure:

```markdown
# Workspace Handoff

## Objective
What this workspace is trying to achieve.

## Repositories
- repos/mobile — role
- repos/backend — role

## Current state
What currently works and what has already been completed.

## Current focus
The task or milestone currently being worked on.

## Decisions
Important architectural/business decisions that future agents must preserve.

## Pending
Concrete next steps, blockers and verification still required.

## Last update
Date and short summary.
```

Rules:

- keep it concise and operational;
- update it when project-level state changes;
- do not store secrets;
- do not copy full logs/transcripts into it;
- repository-specific coding rules continue to live in each repository's own
  `AGENTS.md`, `CLAUDE.md`, docs or equivalent.

## Orca checkpoints

Use Orca task/worktree comments/checkpoints only for short-lived task state.

```text
HANDOFF.md       = durable workspace memory
Orca checkpoint  = current task/worktree status
```

A crashed agent does not need to be resurrected as the exact same process.
A replacement agent reads the persistent handoff, repository state and current
worktree and continues.

---

# 3. Orca model

Map concepts as follows:

```text
User workspace
~/Workspace/work/cello

        ↓

Orca project group
Cello

        ↓

Orca tasks/workspaces/worktrees
- fix-referral-flow
- posthog-refactor
- english-support
```

The root workspace may contain several repositories. Orca can group those
repositories and create independent worktrees/tasks above them.

The user should think primarily in terms of:

1. workspace;
2. handoff;
3. task.

Worktree mechanics remain an Orca/Git implementation detail unless manual
intervention is required.

---

# 4. Simple workspace commands

Provide a small command surface instead of requiring knowledge of directory
layout or Orca internals.

Target UX:

```sh
workspace new work cello
workspace repo add cello <git-url>
workspace open cello
workspace status
```

Possible behavior:

## `workspace new <context> <name>`

Creates only safe local structure:

```text
~/Workspace/<context>/<name>/
├── HANDOFF.md
├── docs/
├── assets/
└── repos/
```

It must not:

- clone arbitrary repositories without being asked;
- create credentials;
- authenticate services;
- publish code;
- create remote infrastructure.

## `workspace repo add`

Clones or registers a repository beneath the selected workspace using the
workspace identity policy from PR #77.

## `workspace open`

Opens/registers the workspace in Orca when available.

If Orca is unavailable, it should still provide the local workspace path and
remain useful.

## `workspace status`

Reports without secrets:

- workspace name/path;
- work/personal context;
- repositories;
- HANDOFF freshness;
- current Git branches/worktrees;
- Orca availability;
- relevant current Orca task if detectable.

---

# 5. Agent bootstrap: understand the environment from the first turn

Agents should not depend on the user explaining the machine every time.

Use four context layers:

```text
1. Fleet context
2. Host context
3. Workspace context
4. Project/repository context
```

## Fleet context

Always-loaded, small and stable:

- NixOS is declarative;
- NixOS owns system services;
- Home Manager owns user tools/config;
- project dependencies belong in project dev environments;
- Git transports source code;
- Syncthing does not synchronize active repos;
- Orca orchestrates agents/worktrees;
- Tailscale is the private connectivity layer;
- feature branches may build/check but are never deployed;
- managed tools must not self-update outside the reviewed Nix flow.

## Host context

Generated from evaluated inventory, never maintained manually.

Example Desktop facts:

```text
Host: desktop
OS: NixOS
Kind: workstation
Role: creative-ml-workstation
Orca: installed
Remote role: primary-runtime-capable
Connectivity: tailscale, ssh, syncthing
```

Victus receives its own evaluated facts.

## Workspace context

Resolved dynamically:

```text
~/Workspace/work/...      -> work
~/Workspace/personal/...  -> personal
other                     -> neutral
```

For an Orca-created Git worktree outside these roots, resolve the primary
repository through Git common-dir metadata and then locate its owning workspace.

The context determines the credential policy defined by PR #77.

## Project/repository context

Agents then read:

1. workspace `HANDOFF.md`;
2. repository `AGENTS.md` / equivalent instructions;
3. relevant project documentation;
4. current branch/diff/tests;
5. relevant skills.

---

# 6. Skills

Do not copy Orca documentation into fleet instructions.

Use:

```text
Official Orca skills
- orca-cli
- orchestration
- computer-use

Fleet skills
- fleet-orca-workspaces
- fleet-workspace
- fleet-nixos-maintenance
- fleet-identity / context behavior
- existing review/debug skills
```

## `fleet-workspace`

Teach agents the workspace convention:

1. resolve work/personal/neutral context;
2. locate workspace root;
3. read `HANDOFF.md`;
4. discover repositories;
5. read repo instructions;
6. inspect current Git/Orca task;
7. continue work;
8. update `HANDOFF.md` only when durable project state changes;
9. update an Orca checkpoint for task-local progress when appropriate.

## `fleet-orca-workspaces`

Teach agents how this fleet expects Orca to be used while delegating actual Orca
CLI syntax to the official version-matched `orca-cli` skill.

---

# 7. Remote Orca architecture

Desktop is the **primary Orca runtime**, not the source of truth for all data.

```text
                        Git remotes
                     source of truth
                          for code

                              │
                ┌─────────────┴─────────────┐
                │                           │
            Desktop                      Victus
        primary Orca runtime        independent workstation
                │                           │
                └──────── Tailscale ────────┘
                              │
                         Orca Mobile
```

Responsibilities:

```text
Git          -> committed source code
HANDOFF.md   -> durable workspace context
Syncthing    -> non-Git workspace files
Orca         -> tasks, terminals, worktrees, agent sessions
Desktop      -> preferred persistent Orca runtime
Victus       -> autonomous workstation + remote client
Android      -> supervision/continuation UI
Tailscale    -> private transport
NixOS        -> declarative machine/tool configuration
Restic       -> backup/recovery when enabled and validated
```

Desktop must never become a hard dependency for Victus development.

---

# 8. Remote Server rollout

Do not jump directly to a permanent `orca serve` systemd service.

## Phase A — Desktop App Remote Server

Use the supported Orca Desktop Remote Server mode manually on Desktop.

Validate:

- Desktop -> Victus connection over Tailscale;
- Desktop -> Android connection;
- same agent/session visible from clients;
- temporary network loss/reconnection;
- Android background/resume;
- Claude/Codex questions and approvals;
- work/personal credential boundaries;
- multi-repo workspace behavior;
- HANDOFF-based agent replacement.

No public Internet port exposure.

## Phase B — evaluate persistence

After stable real use, decide whether a headless runtime is needed.

Possible inventory capability:

```nix
features.orcaRemote.mode = "off" | "desktop-app" | "headless";
```

This is a capability flag, not a new server host type.

## Phase C — optional `orca serve`

Only after Phase A acceptance and backup/recovery validation, evaluate a user
systemd service around `orca serve`.

Requirements:

- Tailscale-only reachability;
- fixed reviewed port if required;
- restart behavior documented;
- mutable Orca state stays outside the Nix store;
- no simultaneous Desktop sharing + headless server mode;
- no claim that restarting the server restores dead agent processes.

A service restart restores **server availability**, not the exact in-memory
process that was running before a crash/power loss.

---

# 9. Failure semantics

## Client/network failure

If Victus or Android disconnects but Desktop remains running:

- the agent process on Desktop may continue;
- reconnect to the same runtime/session after connectivity returns.

## Desktop/Orca process failure

If the Desktop runtime stops:

- running agent processes may terminate;
- written files/worktrees remain on disk;
- committed code remains in Git;
- durable workspace context remains in `HANDOFF.md`;
- a new agent can resume from persistent state.

Do not design around restoring RAM/process state.

## Power loss

Recovery target:

```text
machine returns
-> NixOS/Tailscale/Orca become available
-> workspace/worktree still exists
-> read HANDOFF + Git state
-> resume with a new/restarted agent
```

A UPS may improve availability later but is not an architectural dependency.

---

# 10. Security and recovery constraints

The audit identified these mandatory boundaries:

- Remote Orca stays behind Tailscale/LAN.
- Do not publish its port directly to the Internet.
- Mobile/remote approval must not bypass work/personal/neutral credential policy.
- Workspace handoffs contain no secrets.
- Syncthing is not a backup.
- Restic should be configured and restore-tested before treating Desktop as a
  long-lived store of important unpushed state.
- Desktop and Victus currently do not use LUKS for root/home; physical-device
  encryption remains a separate security project and must not be silently mixed
  into this implementation.
- Work data synchronization/backup must remain configurable in case employer
  policy restricts replication to personal devices or destinations.

---

# 11. Diagnostics

Extend the fleet diagnostics with a stable human/agent interface.

Target:

```sh
fleet-info
fleet-info --json
```

Report:

- host;
- NixOS/fleet role;
- current workspace;
- workspace context;
- workspace root;
- repositories;
- HANDOFF path and last modification;
- current Git repo/worktree;
- project dev environment presence;
- Orca CLI availability;
- local/remote Orca runtime availability where safely detectable;
- installed agent tools;
- relevant fleet skills.

Never print:

- tokens;
- private keys;
- AWS credentials;
- GitHub credentials;
- secret environment values.

`ai-doctor` should verify that the context/skill adapters needed by this flow
are installed correctly.

---

# 12. Validation

## Workspace

- create personal workspace;
- create work workspace;
- add one and multiple repos;
- detect owning workspace from repo;
- detect owning workspace from an external Git worktree;
- HANDOFF template is created once and preserved;
- workspace commands do not require Orca to function.

## Agents

From a fresh Codex/Claude/OpenCode/Kiro session:

- agent identifies host without user explanation;
- agent resolves workspace context;
- agent reads `HANDOFF.md`;
- agent reads repository instructions;
- agent discovers appropriate fleet/Orca skills;
- agent can explain current project state without the user repeating it.

## Orca

- import/open a multi-repo workspace as one logical group;
- create independent task/worktree;
- connect Victus to Desktop runtime;
- connect Android to Desktop runtime;
- temporary client/network disconnect does not require creating a duplicate
  workspace/session;
- agent replacement after an intentional session termination resumes correctly
  from HANDOFF + Git/worktree state.

## Isolation

- Desktop offline does not prevent local Victus development;
- Orca unavailable does not prevent workspace commands or Git;
- Syncthing disabled does not affect source code correctness;
- no repositories/worktrees are added to managed Syncthing folders.

---

# 13. Implementation dependency

This plan assumes PR #77 first establishes or finalizes:

- `~/Workspace/{work,personal}` context policy;
- neutral/work/personal identity routing;
- universal Agent Skills integration;
- Orca update and CLI/skill integration;
- MCP/credential boundaries;
- Syncthing ignore policy foundation.

Before implementing this plan, rebase on the then-current `main` and adapt to
the actual merged #77 implementation instead of reproducing its modules.

---

# Acceptance criteria

The follow-up implementation is complete when:

- one directory represents one logical workspace;
- every workspace has a durable `HANDOFF.md`;
- multiple repos can belong to one workspace without extra mandatory metadata;
- creating/opening a workspace is simple through the `workspace` command;
- any supported fresh agent can discover machine + workspace + project context
  without the user re-explaining the environment;
- Desktop can act as an optional primary Orca runtime over Tailscale;
- Victus remains fully autonomous;
- Android can continue/supervise Desktop-hosted Orca work;
- source repositories are not synchronized by Syncthing;
- agent/process loss is recoverable through persistent handoff + Git/worktree
  state rather than relying on in-memory process restoration;
- disabling Orca Remote functionality leaves the normal NixOS development
  environment intact.
