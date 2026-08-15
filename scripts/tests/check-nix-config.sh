#!/usr/bin/env bash

set -euo pipefail

script="${1:?usage: check-nix-config.sh SCRIPT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

remote="$tmp/remote.git"
seed="$tmp/seed"
repo="$tmp/repo"
other="$tmp/other"
fake_bin="$tmp/bin"
log="$tmp/commands.log"

git init --initial-branch=main "$seed" >/dev/null
git -C "$seed" config user.name Test
git -C "$seed" config user.email test@example.com
printf '{ outputs = _: {}; }\n' >"$seed/flake.nix"
printf '{}\n' >"$seed/flake.lock"
git -C "$seed" add flake.nix flake.lock
git -C "$seed" commit -m baseline >/dev/null
git init --bare "$remote" >/dev/null
git -C "$seed" remote add origin "$remote"
git -C "$seed" push -u origin main >/dev/null
git clone --branch main "$remote" "$repo" >/dev/null
git -C "$repo" config user.name Test
git -C "$repo" config user.email test@example.com

mkdir -p "$fake_bin"
cat >"$fake_bin/hostnamectl" <<'EOF'
#!/bin/sh
printf '%s\n' thinkpad
EOF
cat >"$fake_bin/nix" <<'EOF'
#!/bin/sh
printf 'nix %s\n' "$*" >>"$NIX_CONFIG_TEST_LOG"
EOF
cat >"$fake_bin/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$NIX_CONFIG_TEST_LOG"
EOF
cat >"$fake_bin/kiro-gateway-bootstrap" <<'EOF'
#!/bin/sh
printf 'kiro %s\n' "$*" >>"$NIX_CONFIG_TEST_LOG"
EOF
chmod +x "$fake_bin"/*

export NIXOS_CONFIG_DIR="$repo"
export NIX_CONFIG_HOSTS="thinkpad victus desktop"
export NIX_CONFIG_TEST_LOG="$log"
export NIX_CONFIG_USER="anthony"
export PATH="$fake_bin:$PATH"

assert_deploys() {
  : >"$log"
  bash "$script" deploy
  grep -q '^sudo nixos-rebuild switch ' "$log"
  if grep -q 'path:' "$log"; then
    printf 'deployment used an unfiltered path flake reference\n' >&2
    exit 1
  fi
}

assert_rejected() {
  local expected="$1"

  : >"$log"
  if bash "$script" deploy >"$tmp/stdout" 2>"$tmp/stderr"; then
    printf 'expected deployment rejection containing: %s\n' "$expected" >&2
    exit 1
  fi
  grep -q "$expected" "$tmp/stderr"
  if [[ -s "$log" ]]; then
    printf 'rejected deployment executed external commands:\n' >&2
    cat "$log" >&2
    exit 1
  fi
}

# Exact published main deploys.
assert_deploys

# A local unpublished commit must be rejected before validation or activation.
printf 'local\n' >"$repo/local"
git -C "$repo" add local
git -C "$repo" commit -m local >/dev/null
assert_rejected 'unpublished or divergent commits'
git -C "$repo" reset --hard origin/main >/dev/null

# A remote fast-forward is accepted and updates the checkout before activation.
printf 'remote\n' >"$seed/remote"
git -C "$seed" add remote
git -C "$seed" commit -m remote >/dev/null
git -C "$seed" push origin main >/dev/null
assert_deploys
[[ "$(git -C "$repo" rev-parse HEAD)" == "$(git -C "$repo" rev-parse origin/main)" ]]

# Diverged local and remote histories are rejected.
printf 'local-diverged\n' >"$repo/local-diverged"
git -C "$repo" add local-diverged
git -C "$repo" commit -m local-diverged >/dev/null
git clone --branch main "$remote" "$other" >/dev/null
git -C "$other" config user.name Test
git -C "$other" config user.email test@example.com
printf 'remote-diverged\n' >"$other/remote-diverged"
git -C "$other" add remote-diverged
git -C "$other" commit -m remote-diverged >/dev/null
git -C "$other" push origin main >/dev/null
assert_rejected 'unpublished or divergent commits'

# A dirty tree is always rejected.
git -C "$repo" reset --hard origin/main >/dev/null
printf 'dirty\n' >>"$repo/flake.nix"
assert_rejected 'uncommitted changes'

# Activation never accepts a caller-selected host.
git -C "$repo" reset --hard origin/main >/dev/null
: >"$log"
if bash "$script" switch system desktop >"$tmp/stdout" 2>"$tmp/stderr"; then
  printf 'expected alternate-host activation to be rejected\n' >&2
  exit 1
fi
grep -q 'usage: nix-config switch' "$tmp/stderr"
[[ ! -s "$log" ]]

# Input updates use --flake rather than treating the flake URL as an input name.
git -C "$repo" switch -c update-inputs >/dev/null
: >"$log"
bash "$script" inputs update
grep -q '^nix flake update --flake \.$' "$log"
if grep -q 'path:' "$log"; then
  printf 'input update used an unfiltered path flake reference\n' >&2
  exit 1
fi
