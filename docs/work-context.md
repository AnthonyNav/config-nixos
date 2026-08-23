# Work context: GitHub and AWS

The workstation uses a work-default context so package managers and child Git processes can access private work dependencies without knowing custom SSH aliases.

## Context selection

The default context is `work` everywhere.

The context switches to `personal` only under:

- `~/projects/**`
- `~/nixos-config/**`

Run:

```bash
work-context
```

to inspect the current context.

## Git and GitHub

Work is the default Git identity and `github.com` SSH key.

GitHub HTTPS URLs are normalized to generic SSH:

```text
https://github.com/org/repo.git -> git@github.com:org/repo.git
```

This matters for package managers such as pnpm, Flutter/Dart and Go that invoke Git themselves.

Inside a personal root the shell exports `GIT_SSH_COMMAND` with the personal key. Child processes inherit it, even if they clone a dependency into a cache or temporary directory outside `~/projects`.

Explicit diagnostic aliases remain available:

- `github.com-work`
- `github.com-kigo`
- `github.com-personal`

Run `identity-doctor` to validate the effective Git/SSH policy.

## AWS

The normal `aws` command is a read-only wrapper. It selects one of two local AWS CLI profiles:

- work: `work-readonly`
- personal: `personal-readonly`

The selected profile follows the same directory context as Git.

Useful commands:

```bash
aws-profile-setup work
aws-profile-setup personal

aws-login work
aws-login personal

aws-whoami
aws-whoami work
aws-whoami personal

aws ec2 describe-instances
aws sts get-caller-identity
aws logs tail /aws/lambda/example
aws s3 ls
```

Explicit profile wrappers are also available:

```bash
aws-work ec2 describe-instances
aws-personal s3api list-buckets
```

### Read-only boundary

The wrapper rejects `--profile` overrides and blocks operations whose names are not in an allowlist of read-oriented operations such as `get-*`, `list-*`, `describe-*`, `head-*`, `query`, `scan` and `tail`.

This wrapper is only the local safety layer. The actual security boundary must be AWS IAM.

Both profiles must authenticate to roles or IAM Identity Center permission sets that grant read-only permissions only. Prefer AWS IAM Identity Center/SSO and attach the AWS-managed `ReadOnlyAccess` policy (or a narrower custom read-only policy) to the corresponding permission set/role.

Do not configure administrator or write-capable credentials under the names `work-readonly` or `personal-readonly`.

No AWS account IDs, start URLs, role names, access keys or session tokens are stored in this repository or in the Nix store.

`aws-profile-setup` and `aws-login` are intentionally allowed to modify only local AWS CLI configuration/session cache; they do not provide a path for modifying AWS resources.
