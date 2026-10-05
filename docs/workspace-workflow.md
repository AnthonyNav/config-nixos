# Workspace, identity and Orca workflow

Desktop and Victus share this workflow. ThinkPad remains retired; its data is
retained. Backup jobs and rootless Docker remain disabled. This implements
[PR #77](https://github.com/AnthonyNav/config-nixos/pull/77) and the portable phase
of [PR #79](https://github.com/AnthonyNav/config-nixos/pull/79); activation is a
separate action from reviewed, published `main`.

## Layout and ownership

```text
~/Workspace/
├── work/
│   └── <project>/
│       ├── HANDOFF.md   portable recovery contract
│       ├── docs/        deliberately shared documents
│       ├── assets/      deliberately shared assets
│       └── repos/       one or several Git repositories
└── personal/
    └── <project>/       same structure
```

Home Manager retains legacy root-level repos/, worktrees/ and shared/ without
moving data. The workspace CLI creates project folders on explicit request:

```sh
workspace new work cello
workspace repo add cello git@github.com:ORG/backend.git --context work
workspace repo add cello git@github.com:ORG/frontend.git --context work
workspace open cello --context work
workspace status cello --context work --json
fleet-info --json
```

Names resolve within the current identity, or across both contexts from a neutral
location. Ambiguous names require --context. Repo names come from the URL, with
optional --repo-name. SSH/HTTPS remotes must contain no credentials. Local Git
sources work for testing but require the same source path on another host.
Creation is idempotent; existing handoff text/repos are preserved. Managed writes
reject symlink traversal, reserved legacy names and unresolved handoff conflicts.
A local per-project lock serializes CLI writes and is excluded from sync.

Home Manager creates compatibility directories without cloning repositories or
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

## Document synchronization and migration

The managed IDs are `fleet-work` at `~/Workspace/work` and `fleet-personal` at
`~/Workspace/personal`. Eligible content is each project's HANDOFF.md,
HANDOFF.sync-conflict files, docs/ and assets/, plus legacy root shared/.
Local `.stignore` places
mandatory exclusions first, preserved positive user exclusions next, and the
document allowlist last. Entire repos/ and worktrees/ directories are denied at
every depth before reinclusions. Caches, build outputs, agent state, keys,
token/secret files and live databases remain excluded inside allowed paths.
Names cannot identify every secret: place only reviewed documents/assets there.

The reconciler validates all ignore files and installs exclusions before REST
folder registration. `.stignore.fleet-state` records owned blocks;
`.stignore.fleet-backup` retains the previous file. Symlinked paths, user
negations/`#include`, conflicting owned edits and malformed state fail before
API writes. Review such rules manually instead of removing them to force a run.
Positive user exclusions are retained. Local ignore/state files are not synced.
The reconciler migrates its recorded old shared-only scope without moving data.
In inventory/syncthing.nix, folder hosts = null selects all eligible hosts; []
opts out; an explicit list limits replication (work hosts = [ "desktop" ] is
local-only). Review employer requirements before sharing work documents.
Syncthing is not a backup.

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

## Portable handoff and WIP

HANDOFF.md is plain Markdown. The generated bounded repo table records remote,
relative path, base/active branch and the last observed remote commit; adding a
repo appends one row and preserves other text. Keep the registry markers if using
workspace repo add. Agents maintain objective, bootstrap/dependency order,
decisions, pending work and publication observations throughout the task.
Review .envrc before allowing it; no CLI command executes handoff/bootstrap text.

Before switching hosts, verify each active branch and published SHA through
authorized Git operations. A cached tracking ref does not prove current remote
state. Record local-only changes explicitly. WIP task commits can preserve
authorized progress; clean them before requesting PR review/audit/merge and
coordinate shared-history rewrites. workspace status reports WIP commits since
the clone's origin/HEAD base and history readiness. With no base the result is
unknown. This is advisory, not branch protection or automatic history rewriting.

Assign one handoff writer. HANDOFF.sync-conflict files are preserved/synchronized
for reconciliation and stop further CLI updates. On another host, read the
handoff, clone repos into the stated paths, fetch/switch verified branches, read
repo instructions and enter their project environments. A new agent resumes from
Git plus the handoff after a host restart; RAM, uncommitted files and running
processes are not restored by that contract.

## AI, Orca and tools

Eight canonical `fleet-*` skills are linked into Codex, Claude, Kiro and universal
`~/.agents/skills` discovery. Only those named links belong to Home Manager.
fleet-workspace and fleet-agent-orchestration cover recovery and coordination.
Codex/Kiro receive startup instructions to resolve/read the handoff; Claude's
SessionStart hook injects one bounded handoff; OpenCode adds its resolved path to
the instruction overlay. Live model behavior remains a post-deployment check.
Orca-owned stubs remain mutable:

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

workspace open launches the supported Orca CLI and registers individual repos.
The shared folder/handoff supplies the multi-repo logical group; native grouping
or task creation is not fabricated by editing Orca state. Offline/no-Orca use
continues through local paths and Git. Remote preparation defaults off; see
[orca.md](orca.md).

fleet-info [--json] reports host policy, workspace/handoff age/conflicts, repo
branches/commits/worktrees, declared project environments, tools and sandbox
dependencies. It does not read handoff content, remotes or credential values,
authenticate, start Orca or assert runtime health. JSON carries schema_version.
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
