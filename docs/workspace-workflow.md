# Workspace, identity and Orca workflow

Desktop and Victus share this workflow. ThinkPad remains retired; its data is
retained. Backup jobs and rootless Docker remain disabled. This implements
[PR #77](https://github.com/AnthonyNav/config-nixos/pull/77); activation is a
separate action from reviewed, published `main`.

## Layout and ownership

```text
~/Workspace/
├── work/
│   ├── repos/       primary work repositories
│   ├── worktrees/   branches and agent worktrees
│   └── shared/      deliberately shared work documents
└── personal/
    ├── repos/       primary personal repositories
    ├── worktrees/   branches and agent worktrees
    └── shared/      deliberately shared personal documents
```

Home Manager creates directories without moving files, cloning repositories or
logging in. `~/projects/` and `~/nixos-config/` remain personal compatibility
roots. Work repositories elsewhere are neutral until deliberately moved or
invoked in an explicit work scope.

NixOS owns Syncthing and existing network/container services. Home Manager owns
identity launchers, user applications and named fleet links. Project flakes and
direnv own dependencies. Credentials, Orca sessions, user AI configuration and
database connections remain local mutable state.

## Invocation context

```sh
workspace-context status
workspace-context doctor
identity-doctor
workspace-context exec work -- direnv exec . pnpm install
workspace-context exec personal -- nix develop --command make
```

The default is neutral. Physical paths under work/personal roots select that
context. External linked Git worktrees inherit their primary repository's
`git-common-dir`. Conflicting work/personal worktree and primary roots fail.
Git's repeated `-C`, explicit Git directory/worktree options and corresponding
environment variables are considered; symlinks resolve to physical paths.

Zsh's `WORK_CONTEXT` is informational. Authentication ignores it and stale
profile variables. Use explicit process scope for SDKs that clone private
dependencies through their own Git in caches outside the roots. End that
process before switching accounts. Review `.envrc` before authorizing direnv.
Worktrees and launchers do not isolate ports, containers, databases or arbitrary
same-user programs; use separate OS identities/VMs for security isolation.

## Accounts

Managed Git selects the author and GitHub key. Neutral reads/public HTTPS clones
work; commits without a selected identity and authenticated GitHub SSH fail.
Global work identity, default GitHub key and HTTPS-to-SSH rewrites are removed.
Conditional includes cover primary/linked repositories for clients using their
own Git. Explicit `github.com-work`, `github.com-kigo` and `github.com-personal`
aliases remain; managed Git refuses a mismatched alias. Other SSH hosts retain
their configuration. HTTPS credentials use the selected `gh` helper.

```sh
gh-login work
gh-login personal
gh-whoami work
gh-whoami personal
aws-profile-setup work
aws-profile-setup personal
aws-login work
aws-login personal
aws-whoami work
aws-whoami personal
```

GitHub CLI uses `~/.config/gh/work` or `~/.config/gh/personal` and removes inherited
token/config overrides. Neutral allows help/version; other operations require
context. No old tokens, keys or login configuration are copied automatically.
AWS selects `work-readonly` or `personal-readonly`, removes inherited credentials,
profile/endpoint overrides and rejects `--profile`. `aws-work`/`aws-personal`
explicitly select those profiles. IAM must enforce read-only access; the local
operation-name allowlist cannot enforce IAM permissions. Setup/login mutate
local configuration/cache only. See [work-context.md](work-context.md).

## Shared-only synchronization and migration

The managed IDs are `fleet-work` at `~/Workspace/work` and `fleet-personal` at
`~/Workspace/personal`. Only `shared/` is eligible. Local `.stignore` places
mandatory exclusions first, preserved positive user exclusions next, and the
shared-only allowlist last. Repos, worktrees, caches, build outputs, agent state,
keys, token/secret files and live databases remain excluded inside `shared/`.
Names cannot identify every secret: place only reviewed documents/assets there.

The reconciler validates all ignore files and installs exclusions before REST
folder registration. `.stignore.fleet-state` records owned blocks;
`.stignore.fleet-backup` retains the previous file. Symlinked paths, user
negations/`#include`, conflicting owned edits and malformed state fail before
API writes. Review such rules manually instead of removing them to force a run.
Positive user exclusions are retained. Local ignore/state files are not synced.

The old `fleet-shared` declaration is retired with a private local configuration
snapshot in Syncthing's config directory; its data directory remains. Only pause,
scan and versioning preferences migrate. Old manual peer access is not granted
to new work/personal folders. Existing unrelated folders/devices/shares remain.
Tailnet-only discovery, no auto-accept and no introducer behavior are retained.

Before a separately authorized deployment, pause Syncthing on **both** machines,
retain its configuration and ignore files, and inventory `~/Sync/Fleet`.
After applying reviewed main, inspect IDs, paths, peers and exclusions in the
local Syncthing UI and with `syncthing-fleet-reconcile --check`. Resume only after
verification; test one harmless file
in each `shared/` directory. Manually copy selected old shared data, compare both
machines and retain the source. Review worktrees, remotes, Orca/editor and direnv
paths before moving repositories. No automatic file migration/pruning occurs.

## AI, Orca and tools

Six canonical `fleet-*` skills are linked into Codex, Claude, Kiro and universal
`~/.agents/skills` discovery. Only those named links belong to Home Manager.
`fleet-orca-workspaces` covers this workflow. Orca-owned stubs remain mutable:

```sh
orca-skills-sync --dry-run
orca-skills-sync
# Android automation is optional:
orca-skills-sync --android --dry-run
```

The explicit helper installs/updates approved core `orca-cli`, `orchestration`
and `computer-use` stubs through Orca's upstream commands, potentially downloading
them. Activation never calls it. Read-only/symlinked Orca placements require
manual reconciliation. See [orca.md](orca.md) for Manual permissions, Android
acceptance and the known Codex async-question fallback.

OpenCode adds fleet instructions/MCPs in process-local `OPENCODE_CONFIG_CONTENT`.
JSON/JSONC files are read to reject reserved-ID collisions; providers, models,
permissions, user MCPs and files are preserved. Positional project and `run --dir`
arguments select the project context. Wrong-context fleet MCPs are disabled in
the overlay and guarded at startup. Restart the harness to change context.

The MCP catalog/policy are canonical in `ai/mcp/`. All connection defaults remain
empty, including Artemis. STDIO and restricted connections check context before
reading credentials. Restricted HTTP OAuth is rejected pending a supported
adapter; native OAuth is eligible only for `context = "any"`. Runtime Bearer HTTP
uses pinned `mcp-proxy` client mode without a listening service. See
[ai-environment.md](ai-environment.md) for the runtime secret contract.

`ai-doctor` reports context, common directory, profile selection, fleet/Orca skills,
agent/platform availability and declared synchronization paths without login,
credential reading or network calls. Availability does not prove service health.

Orca is pinned to 1.4.220, Bruno to 4.2.1 and Posting to 2.11.0. Postman 12.20.1
has scoped GTK schemas/default XWayland launching and remains a compatibility
client. Posting history defaults off; existing user YAML can override it, so
review that setting before sensitive requests. Hurl provides repeatable assertions:

```sh
hurl --test --variable base_url=http://127.0.0.1:PORT examples/api/health.hurl
```

DbGate/usql remain primary database clients; `nix run .#dbeaver` is optional.
The shared `platform` profile supplies infrastructure, Kubernetes, supply-chain,
secret-management, network and developer CLI tools. It starts no workloads and
grants no capture privileges. Existing global SDK compatibility remains.
Catppuccin/Caelestia, Nix 2/2 parallelism, ZRAM, weighted builds, bounded journal
and Docker socket activation remain. Start with one agent; measure two with
distinct ports/databases/container resources before increasing concurrency.

## Acceptance and rollback

Build tests cover real Git/worktrees, auth refusal/sanitation, AI preservation,
write-failure rollback, MCP guards, Syncthing migration, platform binaries,
Posting headless startup, Postman schemas, a loopback Hurl API and Orca CLI/skill
dry-run. They use temporary homes and fake credentials; no real account login
or host activation occurs.

After deployment from reviewed main, record this checklist for **both** hosts:

- [ ] Fresh external/Orca terminals agree on context and agent binaries.
- [ ] Work/personal commits, private Git access and external linked worktrees
      select the intended identity; neutral commits and mismatched aliases fail.
- [ ] Independent `gh-whoami`/`aws-whoami` logins select the intended accounts.
- [ ] Shared roots sync harmless files, excluding repos/keys/.env/caches/databases;
      old data and manual folders remain present.
- [ ] New Codex/Claude/Kiro/OpenCode sessions discover skills and preserve user
      configuration; selected MCPs obey context and secret scope.
- [ ] Orca starts/restarts/restores sessions and project environments; record
      CPU/memory pressure with one and two agents.
- [ ] Bruno/Posting/Hurl test a local API and Postman imports/opens its chooser.
      Docker is idle before its first API use.
- [ ] Manual permissions and the real Android phone exercise Claude questions,
      supported Codex approvals, reconnection and the documented async fallback.

Retain local mutable AI/Orca/Syncthing backups first. AI ordinary write failures
compensate completed writes; power loss/SIGKILL still requires checking ownership
state and private backups. Disable managed AI while retaining its module before
removing it entirely. Package rollback cannot reverse Orca database migrations.
Revert through a reviewed PR and deploy that main revision if needed. Older
generations can restore default-work identity, legacy shares or retired
declarations: review them first. Restore Syncthing declarations/ignores from local
snapshots while paused, verify peers/paths, and retain all user data.
