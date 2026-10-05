# Work context: GitHub and AWS

Desktop and Victus use `neutral`, `work` and `personal` context at each command
invocation. The default is **neutral**, with no selected account. The complete
layout, migration and acceptance guide is [workspace-workflow.md](workspace-workflow.md).

## Context selection

`~/Workspace/work/` selects work. `~/Workspace/personal/`, `~/projects/` and
`~/nixos-config/` select personal. External linked Git worktrees inherit the
primary repository's common directory. Physical paths, repeated Git `-C` and
explicit Git directories/worktrees are considered; conflicting roots fail.
Zsh's `WORK_CONTEXT` is informational and never selects authentication.

```sh
workspace-context status
workspace-context doctor
work-context                  # compatibility name for the same interface
workspace-context exec work -- direnv exec . pnpm install
workspace-context exec personal -- nix develop --command make
```

Use explicit scope for SDKs that invoke their own Git from dependency caches
outside the roots. It ends with that process; start a separate process to change
context. Review project environments before authorizing them.

## Git and GitHub

Managed Git selects the declared author and key, independent of interactive
shell hooks. Neutral permits reads/public HTTPS access but refuses commits
without a selected identity and authenticated GitHub SSH. There is no global
author, default GitHub key or global HTTPS-to-SSH rewrite. Conditional includes
also cover primary/linked repositories for clients using their own Git.

GitHub SSH uses the existing `id_work` or `id_personal` key. A mismatched explicit
alias is refused by managed Git. Direct diagnostic aliases remain available:
`github.com-work`, `github.com-kigo` and `github.com-personal`. Other SSH hosts
retain their normal configuration. HTTPS credentials use the selected context's
GitHub CLI helper without changing public clone URLs.

```sh
gh-login work
gh-login personal
gh-whoami work
gh-whoami personal
identity-doctor
```

GitHub CLI uses separate local `~/.config/gh/work` and `~/.config/gh/personal`
directories and removes inherited token/config overrides. Neutral allows help
and version; other operations require a selected context. Logins are
explicit and no previous token/key/configuration is copied automatically.

## AWS

The managed `aws` command selects `work-readonly` or `personal-readonly`.
Neutral requires explicit scope or an `aws-work`/`aws-personal` command. It
removes inherited credentials, endpoint and profile overrides and rejects
`--profile`. Setup/login are explicit local configuration/cache exceptions:

```sh
aws-profile-setup work
aws-profile-setup personal
aws-login work
aws-login personal
aws-whoami work
aws-whoami personal
aws-work ec2 describe-instances
aws-personal s3api list-buckets
```

The operation allowlist permits read-shaped operations (`get-*`, `list-*`,
`describe-*`, `head-*`, `query`, `scan`, `tail`, `s3 ls` and related forms).
AWS IAM must enforce read-only roles/permission sets; an operation's name alone
does not establish its permissions or impact. Do not configure write-capable
credentials under these profiles. Account IDs, SSO details and credentials remain
local, outside Git and the Nix store.

These launchers prevent accidental account mixing in managed commands. Arbitrary
programs running as the same Unix user can still access that user's local files;
use separate OS accounts/VMs when security isolation is required.
