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

| Repository | Remote | Local path | Base | Active branch | Role |
| --- | --- | --- | --- | --- | --- |
| mobile | <clone URL> | repos/mobile | develop | feat/example | Flutter app |
| backend | <clone URL> | repos/backend | main | feat/example-api | Go API |

## Resume on another machine
Exact minimal steps needed to clone/fetch the repositories, check out the
current branches, load the project environment, and continue safely.

## Current state
What currently works and what has already been completed.

## Current focus
The task or milestone currently being worked on.

## Decisions
Important architectural/business decisions that future agents must preserve.

## Pending
Concrete next steps, blockers and verification still required.

## WIP sync state
Temporary WIP commits/branches that were pushed only to transfer unfinished work
between machines, including the repository and latest pushed commit when relevant.

## Last update
Date and short summary.
```

## Golden rule: the handoff must be portable

A valid `HANDOFF.md` must contain enough non-secret information for a fresh
agent on the other workstation to reconstruct the workspace without asking the
user which repositories or branches are involved.

At minimum it must identify, for every active repository:

- repository name and role;
- clone/fetch remote URL or an unambiguous remote name already defined by policy;
- expected local path under `repos/`;
- base branch/ref;
- active task branch when work is in progress;
- project bootstrap/environment command when it is not obvious;
- any required ordering/dependency between repositories;
- whether unfinished work has been pushed as temporary WIP commits.

The handoff may include commands such as:

```sh
git clone <remote> repos/mobile
git -C repos/mobile fetch --all --prune
git -C repos/mobile switch <active-branch>
direnv allow repos/mobile
```

but must never embed credentials, access tokens, private keys, secret URLs or
machine-specific authentication material.

The target is:

```text
new machine
-> sync HANDOFF.md
-> clone/fetch listed repos
-> checkout listed branches
-> load repo instructions/dev environment
-> continue
```

## WIP commits as transport, not history

Temporary commits are allowed to move incomplete work safely between Desktop and
Victus when the work is not ready to represent a meaningful reviewable commit.

Convention:

```text
WIP: <short description>
```

Rules:

- WIP commits live only on a task/feature branch, never on protected/base branches;
- push them only when needed to preserve/transfer unfinished work;
- record the relevant branch/repository in `HANDOFF.md`;
- another machine may fetch that branch and continue from the WIP state;
- do not treat a WIP commit as an architectural milestone or completed feature;
- before requesting PR review, technical audit, merge approval or similar final
  review, remove WIP commits from the reviewable history;
- cleanup may use interactive rebase, squash/fixup, reset/recommit or an
  equivalent safe history rewrite;
- never rewrite a branch that another person/process is actively consuming
  without coordination;
- never force-push `main`, `develop` or another protected/shared base branch.

The desired lifecycle is:

```text
unfinished work
-> WIP commit
-> push task branch
-> continue on another machine
-> finish/validate
-> clean/squash WIP history
-> meaningful commits
-> request review
```

Rules:

- keep it concise and operational;
- update it when project-level state changes;
- update repository/branch/WIP information before handing work to another machine;
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
- fleet-agent-orchestration
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
8. update `HANDOFF.md` when durable project state changes or when a
   cross-machine handoff needs refreshed repository/branch/WIP information;
9. before leaving work for another machine, ensure all active repositories and
   resumable branches are documented and unfinished local-only changes are
   either intentionally retained on the current runtime or safely checkpointed
   through a temporary WIP commit;
10. before requesting PR review/audit/merge approval, clean WIP commits from the
    reviewable history;
11. update an Orca checkpoint for task-local progress when appropriate.

## `fleet-orca-workspaces`

Teach agents how this fleet expects Orca to be used while delegating actual Orca
CLI syntax to the official version-matched `orca-cli` skill.

## Agent orchestration policy

Add a fleet-owned `fleet-agent-orchestration` skill that defines **when** and
under which constraints an agent may orchestrate other agents.

The official Orca `orchestration` skill remains responsible for **how** to use
Runs, tasks, workers and gates. Fleet policy decides whether orchestration is
appropriate in the first place.

### Golden rule

Do not spawn additional agents by default.

Orchestrate only when the expected benefit from parallelism or specialization
clearly exceeds the coordination cost.

### Good candidates for orchestration

Use multiple agents when one or more of these are true:

- two or more independent tasks can progress in parallel;
- separate repositories/components can be worked on independently;
- research and implementation can proceed in parallel;
- an implementation benefits from an independent review/security/test pass;
- comparing multiple approaches is valuable before choosing one;
- a large task has clear ownership boundaries between workers.

### Avoid orchestration when

Do not create a multi-agent run for:

- small fixes;
- one or two tightly coupled files;
- strongly sequential tasks;
- work where several agents would edit the same area concurrently;
- tasks where coordination is more expensive than implementation.

### Lead-agent contract

One lead agent owns the final outcome.

The lead must:

1. understand the task and workspace before delegating;
2. split work into independent, clearly scoped units;
3. assign each worker a repository/worktree, goal and completion criteria;
4. prevent workers from making final merge/publication decisions;
5. integrate worker results and resolve overlaps/conflicts;
6. run the complete final validation after integration;
7. update the workspace `HANDOFF.md` for durable cross-task state;
8. keep task-local worker progress in Orca checkpoints where appropriate;
9. clean WIP history before review;
10. preserve all approval/security boundaries defined by the fleet.

Workers must not recursively spawn more workers unless the lead explicitly
delegates that authority and the task still satisfies this policy.

### Concurrency

Start conservatively with at most 2-3 active coding/review workers per
workstation.

Increase concurrency only after measuring CPU, RAM, disk pressure, build
contention and agent quality on Desktop and Victus.

### Worktree isolation

When workers modify code concurrently, prefer one Git worktree per worker/task.

Remember that worktrees isolate files, not:

- ports;
- containers;
- databases;
- emulators/devices;
- caches;
- credentials.

The lead must allocate or serialize those shared resources explicitly.

### Review independence

When orchestration includes a review/test/security worker, that worker should
inspect the integrated behavior rather than merely approve another worker's
summary.

Final review/audit readiness still requires the normal fleet engineering rules
and clean non-WIP history.

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
- HANDOFF lists every active repository with remote/path/base/active-branch data;
- a clean second-machine fixture can reconstruct the repos and active branches
  using only the handoff plus normal configured credentials;
- a WIP branch can be pushed/fetched/resumed across machines;
- WIP commits are absent from the final reviewable history;
- workspace commands do not require Orca to function.

## Agents

From a fresh Codex/Claude/OpenCode/Kiro session:

- agent identifies host without user explanation;
- agent resolves workspace context;
- agent reads `HANDOFF.md`;
- agent reads repository instructions;
- agent discovers appropriate fleet/Orca skills;
- agent does not spawn workers for a trivial/small task;
- agent can identify a task that benefits from parallel workers and explain the
  proposed split before orchestration;
- lead agent integrates worker output and performs final validation;
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
- the handoff is sufficient for a fresh agent on another workstation to
  identify, clone/fetch and check out every active repository/branch needed to
  continue;
- temporary WIP commits may transport unfinished work between machines but are
  cleaned from history before PR review/audit/merge approval;
- multiple repos can belong to one workspace without extra mandatory metadata;
- creating/opening a workspace is simple through the `workspace` command;
- any supported fresh agent can discover machine + workspace + project context
  without the user re-explaining the environment;
- agents follow a shared orchestration policy: no unnecessary workers, one lead
  owns integration/final validation, and parallel workers have isolated scopes;
- Desktop can act as an optional primary Orca runtime over Tailscale;
- Victus remains fully autonomous;
- Android can continue/supervise Desktop-hosted Orca work;
- source repositories are not synchronized by Syncthing;
- agent/process loss is recoverable through persistent handoff + Git/worktree
  state rather than relying on in-memory process restoration;
- disabling Orca Remote functionality leaves the normal NixOS development
  environment intact.
