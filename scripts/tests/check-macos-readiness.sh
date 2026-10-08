#!/usr/bin/env bash
set -euo pipefail

script="${1:?usage: check-macos-readiness.sh SCRIPT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
mkdir -p "$bin" "$tmp/home"

cat >"$bin/uname" <<'EOF'
#!/bin/sh
if [ "$1" = "-s" ]; then printf 'Darwin\n'; else printf 'arm64\n'; fi
EOF
cat >"$bin/scutil" <<'EOF'
#!/bin/sh
[ "$1" = "--get" ] && [ "$2" = "LocalHostName" ] && printf 'MacBook-Pro-de-Antonio\n'
EOF
cat >"$bin/id" <<'EOF'
#!/bin/sh
[ "$1" = "-un" ] && printf 'test-user\n'
EOF
cat >"$bin/nix" <<'EOF'
#!/bin/sh
[ "$1" = "store" ] && [ "$2" = "ping" ]
EOF
cat >"$bin/xcode-select" <<'EOF'
#!/bin/sh
[ "$1" = "-p" ] && printf '/Library/Developer/CommandLineTools\n'
EOF
printf '#!/bin/sh\nexit 0\n' >"$bin/brew"
chmod +x "$bin"/*

export HOME="$tmp/home"
export FLEET_EXPECTED_HOST=MacBook-Pro-de-Antonio
export FLEET_EXPECTED_USER=test-user
export FLEET_EXPECTED_HOME="$HOME"
export PATH="$bin:/usr/bin:/bin"

bash "$script" --preflight >"$tmp/preflight"
grep -q '0 failure(s), 0 warning(s)' "$tmp/preflight"

# Host-specific package must reject an unregistered/renamed Mac.
if FLEET_EXPECTED_HOST=other-host bash "$script" --preflight >"$tmp/mismatch"; then
  printf 'readiness accepted an unexpected Mac hostname\n' >&2
  exit 1
fi
grep -q 'LocalHostName' "$tmp/mismatch"

# An unavailable Nix store must stop the preflight.
cat >"$bin/nix" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$bin/nix"
if bash "$script" --preflight >"$tmp/nix-failed"; then
  printf 'readiness accepted an unavailable Nix store\n' >&2
  exit 1
fi
grep -q 'nix store ping failed' "$tmp/nix-failed"
cat >"$bin/nix" <<'EOF'
#!/bin/sh
[ "$1" = "store" ] && [ "$2" = "ping" ]
EOF
chmod +x "$bin/nix"

for cli in \
  gh aws workspace workspace-context workspace-sync nix-config \
  direnv nvim fleet-ui fleet-info ai-doctor \
  codex claude opencode rtk orca-ide fleet-ssh; do
  printf '#!/bin/sh\nexit 0\n' >"$bin/$cli"
  chmod +x "$bin/$cli"
done
bash "$script" --runtime >"$tmp/runtime"
grep -q '0 failure(s)' "$tmp/runtime"

# Do not introduce install/login side effects into the diagnostic.
grep -q 'no changes made' "$tmp/preflight"
