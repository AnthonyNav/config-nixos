#!/usr/bin/env bash

set -euo pipefail

readonly config_user="${NIX_CONFIG_USER:?NIX_CONFIG_USER is not set}"
readonly supported_hosts="${NIX_CONFIG_HOSTS:?NIX_CONFIG_HOSTS is not set}"
read -r -a host_names <<<"$supported_hosts"
readonly host_names
readonly home_hosts="${NIX_CONFIG_HOME_HOSTS?NIX_CONFIG_HOME_HOSTS is not set}"

repo=""
flake=""
ahead=""
behind=""

usage() {
  cat <<'EOF'
Usage: nix-config <command> [arguments]

Commands:
  status                         Show repository and generation status
  fmt [--check]                  Format Nix files or verify formatting
  check [current|all]            Run checks and build the selected scope
  build system [HOST|all]        Build native NixOS/nix-darwin output(s)
  build home [HOST|all]          Build Home Manager output(s)
  build all [HOST|all]           Build NixOS and Home Manager output(s)
  build iso                      Build the installer ISO
  test system                    Test the published system generation
  switch system                  Activate the published system generation
  switch home                    Activate the published Home Manager generation
  deploy                         Fast-forward, validate, and activate this host
  inputs update                  Update inputs on a clean feature branch
  generations [system|home]      List available generations
  rollback system                Roll back the native system generation
  rollback home GENERATION_PATH  Activate an older Home Manager generation
  gc [AGE]                       Delete generations older than AGE (default: 30d)
EOF
}

die() {
  printf 'nix-config: %s\n' "$*" >&2
  exit 1
}

resolve_repo() {
  local candidate current_repo

  if [[ -n "${NIXOS_CONFIG_DIR:-}" ]]; then
    candidate="$NIXOS_CONFIG_DIR"
  else
    candidate="$HOME/nixos-config"
    current_repo="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -f "$current_repo/modules/home/nix-config-packages.nix" ]]; then
      candidate="$current_repo"
    fi
  fi

  repo="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)" ||
    die "cannot resolve the configuration repository from $candidate"
  [[ -f "$repo/flake.nix" ]] || die "$repo does not contain flake.nix"
  flake="."
}

resolve_host() {
  local candidate="${1:-}"
  local allowed

  if [[ -z "$candidate" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      candidate="$(scutil --get LocalHostName)"
    else
      candidate="$(hostnamectl --static)"
    fi
  fi

  for allowed in "${host_names[@]}"; do
    if [[ "$candidate" == "$allowed" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  die "$candidate is not a declared fleet host"
}

host_property() {
  local host="$1" kind="$2" data="" fallback=""
  case "$kind" in
    platform) data="${NIX_CONFIG_HOST_PLATFORMS_JSON:-}"; fallback=nixos ;;
    user) data="${NIX_CONFIG_HOST_USERS_JSON:-}"; fallback="$config_user" ;;
    system) data="${NIX_CONFIG_HOST_SYSTEMS_JSON:-}"; fallback="${NIX_CONFIG_NATIVE_SYSTEM:-x86_64-linux}" ;;
    *) die "unknown host property: $kind" ;;
  esac
  if [[ -z "$data" ]]; then printf '%s\n' "$fallback"; return; fi
  jq -er --arg host "$host" '.[$host] // error("missing inventory host property")' <<<"$data"
}

is_native_host() {
  [[ "$(host_property "$1" system)" == "${NIX_CONFIG_NATIVE_SYSTEM:-x86_64-linux}" ]]
}

require_clean_main() {
  local branch

  [[ -z "$(git -C "$repo" status --porcelain)" ]] ||
    die "$repo has uncommitted changes"

  branch="$(git -C "$repo" branch --show-current)"
  [[ "$branch" == "main" ]] || die "expected branch main, found ${branch:-detached HEAD}"

  [[ "$(git -C "$repo" config --get branch.main.remote || true)" == "origin" ]] ||
    die "main must track origin"
  [[ "$(git -C "$repo" config --get branch.main.merge || true)" == "refs/heads/main" ]] ||
    die "main must track origin/main"
}

require_visible_worktree() {
  local untracked

  untracked="$(git -C "$repo" ls-files --others --exclude-standard)"
  [[ -z "$untracked" ]] ||
    die "untracked paths are invisible to pure flake evaluation; add or mark them intent-to-add before validation"
}

fetch_main() {
  git -C "$repo" fetch --prune origin main
}

read_main_relation() {
  local counts

  counts="$(git -C "$repo" rev-list --left-right --count HEAD...origin/main)" ||
    die "cannot compare HEAD with origin/main"
  read -r ahead behind <<<"$counts"
  [[ "$ahead" =~ ^[0-9]+$ && "$behind" =~ ^[0-9]+$ ]] ||
    die "invalid Git ahead/behind counts: $counts"
}

require_published_main() {
  require_clean_main
  fetch_main
  read_main_relation

  if ((ahead != 0 || behind != 0)); then
    die "HEAD must exactly match origin/main (ahead=$ahead, behind=$behind); use nix-config deploy when behind"
  fi
}

prepare_deploy() {
  require_clean_main
  fetch_main
  read_main_relation

  if ((ahead != 0)); then
    die "local main contains unpublished or divergent commits (ahead=$ahead, behind=$behind)"
  fi

  if ((behind != 0)); then
    git -C "$repo" merge --ff-only origin/main
  fi

  [[ "$(git -C "$repo" rev-parse HEAD)" == "$(git -C "$repo" rev-parse origin/main)" ]] ||
    die "HEAD does not match origin/main after fast-forward"
}

format_check() {
  (cd "$repo" && nix fmt --no-write-lock-file -- --ci)
}

static_checks() {
  local lock_before lock_after

  require_visible_worktree
  lock_before="$(sha256sum "$repo/flake.lock")"
  format_check
  (cd "$repo" && nix flake check --no-write-lock-file)
  lock_after="$(sha256sum "$repo/flake.lock")"
  [[ "$lock_before" == "$lock_after" ]] || die "validation modified flake.lock"
}

system_installable() {
  local host="$1"
  if [[ "$(host_property "$host" platform)" == "darwin" ]]; then
    printf '%s#darwinConfigurations.%s.system\n' "$flake" "$host"
  else
    printf '%s#nixosConfigurations.%s.config.system.build.toplevel\n' "$flake" "$host"
  fi
}

home_installable() {
  local host="$1"
  printf '%s#homeConfigurations."%s@%s".activationPackage\n' "$flake" "$(host_property "$host" user)" "$host"
}

build_system() {
  local host="$1"
  (cd "$repo" && nix build --no-link --no-write-lock-file "$(system_installable "$host")")
}

has_home() {
  local host="$1" allowed
  for allowed in $home_hosts; do
    [[ "$host" != "$allowed" ]] || return 0
  done
  return 1
}

build_home() {
  local host="$1"
  has_home "$host" || die "$host has no Home Manager output"
  (cd "$repo" && nix build --no-link --no-write-lock-file "$(home_installable "$host")")
}

build_host() {
  local target="$1"
  local host="$2"

  case "$target" in
    system) build_system "$host" ;;
    home) build_home "$host" ;;
    all)
      build_system "$host"
      if has_home "$host"; then build_home "$host"; fi
      ;;
    *) die "unknown build target: $target" ;;
  esac
}

build_scope() {
  local target="$1"
  local selection="$2"
  local host

  if [[ "$selection" == "all" ]]; then
    for host in "${host_names[@]}"; do
      if ! is_native_host "$host"; then continue; fi
      if [[ "$target" == "home" ]] && ! has_home "$host"; then continue; fi
      build_host "$target" "$host"
    done
  else
    host="$(resolve_host "$selection")"
    build_host "$target" "$host"
  fi
}

run_check() {
  local scope="$1"
  local host

  [[ "$scope" == "current" || "$scope" == "all" ]] ||
    die "check scope must be current or all"
  static_checks
  if [[ "$scope" == "all" ]]; then
    build_scope all all
  else
    host="$(resolve_host)"
    build_host all "$host"
  fi
}

switch_system() {
  local action="$1"
  local host="$2"
  if [[ "$(host_property "$host" platform)" == "darwin" ]]; then
    [[ "$action" == "switch" ]] || die "nix-darwin has no NixOS test activation"
    (cd "$repo" && sudo darwin-rebuild switch --flake "$flake#$host")
  else
    (cd "$repo" && sudo nixos-rebuild "$action" --no-write-lock-file --flake "$flake#$host")
  fi
}

switch_home() {
  local host="$1"
  local generation result_link state_dir

  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nix-config"
  result_link="$state_dir/home-generation"
  mkdir -p "$state_dir"
  generation="$(
    cd "$repo" &&
      nix build --out-link "$result_link" --print-out-paths --no-write-lock-file \
        "$(home_installable "$host")"
  )"
  [[ -x "$generation/activate" ]] || die "Home Manager activation script was not built"
  "$generation/activate"
}

show_status() {
  local branch dirty head counts system_generation

  branch="$(git -C "$repo" branch --show-current)"
  head="$(git -C "$repo" rev-parse --short HEAD)"
  if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    dirty="dirty"
  else
    dirty="clean"
  fi

  printf 'Repository: %s\n' "$repo"
  printf 'Branch: %s (%s, %s)\n' "${branch:-detached}" "$head" "$dirty"
  if git -C "$repo" rev-parse --verify origin/main >/dev/null 2>&1; then
    counts="$(git -C "$repo" rev-list --left-right --count HEAD...origin/main)"
    read -r ahead behind <<<"$counts"
    printf 'origin/main: ahead=%s behind=%s\n' "$ahead" "$behind"
  fi

  if [[ -e /run/current-system ]]; then
    system_generation="$(readlink /run/current-system)"
    printf 'System: %s\n' "$system_generation"
  fi
  if [[ "$(uname -s)" == "Darwin" && -e /nix/var/nix/profiles/system ]]; then
    printf 'Darwin system: %s\n' "$(readlink /nix/var/nix/profiles/system)"
  fi
}

command="${1:-help}"
case "$command" in
  help|-h|--help)
    usage
    ;;
  status)
    [[ $# -eq 1 ]] || die "status takes no arguments"
    resolve_repo
    show_status
    ;;
  fmt)
    [[ $# -le 2 ]] || die "fmt accepts only --check"
    resolve_repo
    require_visible_worktree
    case "${2:-}" in
      "") (cd "$repo" && nix fmt --no-write-lock-file) ;;
      --check) format_check ;;
      *) die "fmt accepts only --check" ;;
    esac
    ;;
  check)
    [[ $# -le 2 ]] || die "check accepts only current or all"
    resolve_repo
    run_check "${2:-current}"
    ;;
  build)
    resolve_repo
    require_visible_worktree
    target="${2:-}"
    if [[ "$target" == "iso" ]]; then
      [[ $# -eq 2 ]] || die "build iso takes no additional arguments"
      (
        cd "$repo" &&
          nix build --no-link --no-write-lock-file \
            "$flake#nixosConfigurations.installer.config.system.build.isoImage"
      )
    else
      [[ "$target" == "system" || "$target" == "home" || "$target" == "all" ]] ||
        die "build target must be system, home, all, or iso"
      [[ $# -le 3 ]] || die "build accepts one host or all"
      selection="${3:-$(resolve_host)}"
      build_scope "$target" "$selection"
    fi
    ;;
  test)
    [[ "${2:-}" == "system" && $# -eq 2 ]] || die "usage: nix-config test system"
    resolve_repo
    host="$(resolve_host)"
    [[ "$(host_property "$host" platform)" != "darwin" ]] || die "nix-darwin has no NixOS test activation; use build system"
    require_published_main
    static_checks
    build_host all "$host"
    require_published_main
    switch_system test "$host"
    ;;
  switch)
    [[ $# -le 2 ]] || die "usage: nix-config switch [system|home]"
    resolve_repo
    target="${2:-system}"
    host="$(resolve_host)"
    require_published_main
    static_checks
    case "$target" in
      system)
        build_host all "$host"
        require_published_main
        switch_system switch "$host"
        ;;
      home)
        build_home "$host"
        require_published_main
        switch_home "$host"
        ;;
      *) die "switch target must be system or home" ;;
    esac
    ;;
  deploy)
    [[ $# -eq 1 ]] || die "deploy takes no arguments"
    resolve_repo
    host="$(resolve_host)"
    prepare_deploy
    run_check current
    require_published_main
    switch_system switch "$host"
    ;;
  inputs)
    [[ "${2:-}" == "update" && $# -eq 2 ]] || die "usage: nix-config inputs update"
    resolve_repo
    [[ -z "$(git -C "$repo" status --porcelain)" ]] || die "$repo has uncommitted changes"
    branch="$(git -C "$repo" branch --show-current)"
    [[ -n "$branch" && "$branch" != "main" ]] || die "input updates require a feature branch"
    (cd "$repo" && nix flake update --flake "$flake")
    run_check all
    ;;
  generations)
    [[ $# -le 2 ]] || die "usage: nix-config generations [system|home]"
    case "${2:-system}" in
      system)
        if [[ "$(uname -s)" == "Darwin" ]]; then
          nix-env --list-generations --profile /nix/var/nix/profiles/system
        else
          nixos-rebuild list-generations
        fi
        ;;
      home)
        command -v home-manager >/dev/null 2>&1 || die "home-manager is not available"
        home-manager generations
        ;;
      *) die "generation target must be system or home" ;;
    esac
    ;;
  rollback)
    case "${2:-}" in
      system)
        [[ $# -eq 2 ]] || die "rollback system takes no additional arguments"
        if [[ "$(uname -s)" == "Darwin" ]]; then
          sudo darwin-rebuild --rollback
        else
          sudo nixos-rebuild switch --rollback
        fi
        ;;
      home)
        [[ $# -eq 3 ]] || die "usage: nix-config rollback home GENERATION_PATH"
        [[ -x "$3/activate" ]] || die "$3 is not a Home Manager generation"
        "$3/activate"
        ;;
      *) die "rollback target must be system or home" ;;
    esac
    ;;
  gc)
    [[ $# -le 2 ]] || die "usage: nix-config gc [AGE]"
    age="${2:-30d}"
    [[ "$age" =~ ^[1-9][0-9]*d$ ]] || die "AGE must be a positive number of days, such as 30d"
    sudo nix-collect-garbage --delete-older-than "$age"
    nix-collect-garbage --delete-older-than "$age"
    nix store optimise
    ;;
  *)
    usage >&2
    die "unknown command: $command"
    ;;
esac
