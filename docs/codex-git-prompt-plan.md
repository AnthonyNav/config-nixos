# Codex Git Prompt Correction

Historical incident analysis. PR #77 removes the global work identity and
HTTPS-to-SSH rewrite described below. Current invocation-scoped routing is in
[work-context.md](work-context.md); the noninteractive Codex wrapper remains.
The fleet now requires two system and two Home builds. Real TUI acceptance
still requires a separately deployed session.

## Reported problem

Opening a Codex session on Victus produced raw escape sequences when moving
the mouse or typing. The report reproduced this with Codex 0.151.0, 0.159.1
and 0.160.0 and confirmed that loading the work key with
`ssh-add ~/.ssh/id_work` before starting Codex avoided the problem.

## SSH prompt collision

1. The local Codex configuration registers the PostHog marketplace with
   `source = "https://github.com/PostHog/ai-plugin.git"`. Its Git synchronization
   happens during startup.
2. The shared Git configuration rewrites `https://github.com/` to
   `git@github.com:`, so the synchronization uses SSH.
3. `github.com` uses the work SSH identity by default. A personal-context shell
   exports `GIT_SSH_COMMAND` with the fleet's personal identity wrapper instead.
4. An encrypted key absent from the SSH agent can trigger a terminal passphrase
   prompt while the Codex TUI is also reading terminal input.

The marketplace configuration, keys and agent state remain local; this
repository manages the Codex wrapper and the shared Git/SSH identity policy.

## Wrapper behavior

[`packages/codex.nix`](../packages/codex.nix) retains
`-c features.daemon_auto_start=false`, sets `GIT_TERMINAL_PROMPT=0` and appends
`-o BatchMode=yes` to the inherited `GIT_SSH_COMMAND`. Without an inherited
command, it uses the pinned OpenSSH executable.

Using `--set-default GIT_SSH_COMMAND "ssh -o BatchMode=yes"` alone would leave
the personal identity wrapper unchanged and still able to prompt. Extending
the command at runtime preserves the identity and applies the non-interactive
option to both fleet contexts. Custom SSH commands must accept and honor the
forwarded OpenSSH options; an earlier explicit `BatchMode=no` can override an
appended option.

These environment variables apply to Codex and its child processes, including
marketplace synchronization and Git tools. Remote operations such as
`git push` require available non-interactive authentication. With an encrypted
key absent from the agent, they fail instead of requesting its passphrase.
With the correct key loaded, authentication remains available. Authentication
errors may still be displayed; the correction does not promise silent failures.

## Validation before review

Run from the feature worktree after adding new files to Git:

```sh
nix fmt
nix flake check --no-build --no-write-lock-file
nix-check all
```

The wrapper is shared by Desktop and Victus. `nix-check all` builds
the executable flake checks and all four NixOS/Home Manager workstation outputs without
activation. Keep `flake.lock` unchanged.

Inspect the wrapper in the Codex package output selected by Home Manager.
Home Manager's activation package does not provide `result/bin/codex`.

Behavioral validation must cover an unset, empty and inherited
`GIT_SSH_COMMAND`, forced `GIT_TERMINAL_PROMPT=0`, both SSH identity contexts,
and Git child processes with an empty agent and with an authenticated agent.
Use temporary test identities and an isolated agent; never empty the user's
agent with `ssh-add -D`.

## Real-session follow-up

After the PR is reviewed, merged and separately deployed from published
`main`, open Codex in a new Kitty session. Use an isolated empty SSH agent,
move the mouse and type, then repeat with the intended key loaded in that
agent. Verify that startup and Git commands never request a passphrase or
corrupt terminal input, and that authentication works with the key loaded.

A successful build or subprocess authentication test does not establish the
health of the graphical terminal session. Record this manual result separately
from build evidence; do not activate the feature branch to obtain it.
