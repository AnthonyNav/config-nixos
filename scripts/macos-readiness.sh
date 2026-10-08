#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: fleet-macos-readiness [--preflight|--runtime]

--preflight  Verify host identity, Nix, Homebrew and Apple developer tools.
--runtime    Also verify that shared Home Manager CLI entry points are present.

Read-only: no installation, app startup, login or credential access.
Before activation: nix run .#macos-readiness-<registered-host>
EOF
}

mode="${1:---preflight}"
case "$mode" in
  -h|--help)
    usage
    exit 0
    ;;
  --preflight|--runtime)
    [[ $# -le 1 ]] || {
      usage >&2
      exit 64
    }
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

expected_host="${FLEET_EXPECTED_HOST:-}"
expected_user="${FLEET_EXPECTED_USER:-}"
expected_home="${FLEET_EXPECTED_HOME:-}"
if [[ -z "$expected_host" || -z "$expected_user" || -z "$expected_home" ]]; then
  printf 'Run this check using its host-specific Nix package.\n' >&2
  exit 64
fi

failures=0
warnings=0

report() {
  printf '[%-4s] %-19s %s\n' "$1" "$2" "$3"
}

fail() {
  report FAIL "$1" "$2"
  failures=$((failures + 1))
}

warn() {
  report WARN "$1" "$2"
  warnings=$((warnings + 1))
}

ok() {
  report OK "$1" "$2"
}

match_fact() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    ok "$label" "$expected"
  else
    fail "$label" "expected '$expected', got '$actual'"
  fi
}

required_cli() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1" "available"
  else
    fail "$1" "not on PATH"
  fi
}

optional_cli() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1" "available"
  else
    warn "$1" "$2"
  fi
}

printf 'Fleet macOS readiness (%s; no changes made)\n' "$mode"
match_fact "Operating system" "$(uname -s 2>/dev/null || true)" "Darwin"
match_fact "Architecture" "$(uname -m 2>/dev/null || true)" "arm64"
match_fact "LocalHostName" "$(scutil --get LocalHostName 2>/dev/null || true)" "$expected_host"
match_fact "Login user" "$(id -un 2>/dev/null || true)" "$expected_user"
match_fact "HOME" "$HOME" "$expected_home"

required_cli git
if command -v nix >/dev/null 2>&1; then
  if nix store ping >/dev/null 2>&1; then
    ok "Nix store" "daemon reachable"
  else
    fail "Nix store" "nix store ping failed; check the installed Nix daemon"
  fi
else
  fail "Nix" "install Nix before nix-darwin bootstrap"
fi

if command -v brew >/dev/null 2>&1; then
  ok "Homebrew" "available on PATH"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  warn "Homebrew PATH" 'found at /opt/homebrew/bin/brew; enable brew shellenv'
else
  fail "Homebrew" "install Homebrew natively before nix-darwin activation"
fi

if command -v xcode-select >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
  ok "Developer tools" "xcode-select -p succeeds"
else
  fail "Developer tools" "install or select Apple Command Line Tools"
fi

if [[ "$mode" == "--runtime" ]]; then
  for cli in \
    gh aws workspace workspace-context workspace-sync nix-config \
    direnv nvim fleet-ui fleet-info ai-doctor \
    codex claude opencode rtk orca-ide fleet-ssh; do
    required_cli "$cli"
  done
  optional_cli tailscale "enable the native App Store app's CLI integration"
  optional_cli orca "register the Orca CLI from the app's Settings"
  optional_cli xcodebuild "full Xcode and simulators are managed in macOS"
  optional_cli fvm "select the optional mobile profile and project SDK"
fi

printf 'Summary: %d failure(s), %d warning(s)\n' "$failures" "$warnings"
if ((failures > 0)); then
  exit 1
fi
