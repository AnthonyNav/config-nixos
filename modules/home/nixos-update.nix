{ pkgs, ... }:

let
  nixosUpdate = pkgs.writeShellApplication {
    name = "nixos-update";
    runtimeInputs = [
      pkgs.git
      pkgs.nix
      pkgs.systemd
    ];
    text = ''
      repo="''${NIXOS_CONFIG_DIR:-$HOME/nixos-config}"
      repo="$(git -C "$repo" rev-parse --show-toplevel)"

      if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
        printf 'Refusing to update: %s has uncommitted changes.\n' "$repo" >&2
        exit 1
      fi

      branch="$(git -C "$repo" branch --show-current)"
      if [[ "$branch" != "main" ]]; then
        printf 'Refusing to update: expected branch main, found %s.\n' "$branch" >&2
        exit 1
      fi

      if [[ "$(git -C "$repo" config --get branch.main.remote)" != "origin" ]]; then
        printf 'Refusing to update: main must track origin.\n' >&2
        exit 1
      fi

      git -C "$repo" fetch --prune origin main

      ahead="$(git -C "$repo" rev-list --left-right --count HEAD...origin/main | cut -d ' ' -f 1)"
      if (( ahead != 0 )); then
        printf 'Refusing to update: local main diverges from origin/main.\n' >&2
        exit 1
      fi

      git -C "$repo" merge --ff-only origin/main

      host="$(hostnamectl --static)"
      case "$host" in
        victus|desktop|thinkpad) ;;
        *)
          printf 'Refusing to update: %s is not a declared workstation.\n' "$host" >&2
          exit 1
          ;;
      esac

      nix flake check --no-build --no-write-lock-file "path:$repo"
      sudo nixos-rebuild switch --no-write-lock-file --flake "path:$repo#$host"

      bootstrap="$HOME/.nix-profile/bin/kiro-gateway-bootstrap"
      if [[ -x "$bootstrap" ]]; then
        "$bootstrap" --if-configured
      fi
    '';
  };
in
{
  home.packages = [ nixosUpdate ];
}
