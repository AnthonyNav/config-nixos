{
  config,
  lib,
  pkgs,
  ...
}:

let
  policy = import ../../inventory/identities.nix;
  inherit (policy) identities;
  inherit (identities) work;
  inherit (identities) personal;
  homeDir = config.home.homeDirectory;
  sshKeyPath = identity: "${homeDir}/${identity.sshKey}";
  rootPath = root: "${homeDir}/${root}";

  personalChecks = lib.concatStringsSep "\n" (
    map (
      root:
      "probe_identity ${lib.escapeShellArg (rootPath root)} ${lib.escapeShellArg personal.git.email}"
    ) personal.roots
  );

  identityDoctor = pkgs.writeShellApplication {
    name = "identity-doctor";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.gnused
      pkgs.openssh
    ];
    text = ''
      failures=0

      ok() { printf '✓ %s\n' "$1"; }
      fail() { printf '✗ %s\n' "$1" >&2; failures=$((failures + 1)); }
      check_eq() {
        local label="$1" actual="$2" expected="$3"
        if [[ "$actual" == "$expected" ]]; then
          ok "$label"
        else
          fail "$label (expected: $expected; actual: ''${actual:-<empty>})"
        fi
      }
      check_readable() {
        local label="$1" path="$2"
        if [[ -r "$path" ]]; then ok "$label"; else fail "$label is missing or unreadable: $path"; fi
      }
      check_ssh_alias() {
        local label="$1" alias="$2" expected="$3" actual
        actual="$(ssh -G "$alias" 2>/dev/null | sed -n 's/^identityfile //p' | head -n1)"
        check_eq "$label" "$actual" "$expected"
      }
      probe_identity() {
        local root="$1" expected="$2" probe actual
        if [[ ! -d "$root" ]]; then fail "personal identity root does not exist: $root"; return; fi
        probe="$(mktemp -d "$root/.identity-doctor.XXXXXX")"
        git -C "$probe" init -q
        actual="$(git -C "$probe" config user.email 2>/dev/null || true)"
        rm -rf "$probe"
        check_eq "personal commit identity under $root" "$actual" "$expected"
      }

      printf 'Work-context identity policy\n'
      check_eq "default commit email" "$(git config --global user.email 2>/dev/null || true)" ${lib.escapeShellArg work.git.email}
      check_eq "useConfigOnly remains enabled" "$(git config --global --bool user.useConfigOnly 2>/dev/null || true)" "true"

      check_readable "work SSH key" ${lib.escapeShellArg (sshKeyPath work)}
      check_readable "personal SSH key" ${lib.escapeShellArg (sshKeyPath personal)}
      check_ssh_alias "generic github.com defaults to work" github.com ${lib.escapeShellArg (sshKeyPath work)}
      check_ssh_alias "explicit work alias" github.com-work ${lib.escapeShellArg (sshKeyPath work)}
      check_ssh_alias "explicit personal alias" github.com-personal ${lib.escapeShellArg (sshKeyPath personal)}

      rewritten="$(git ls-remote --get-url https://github.com/NixOS/nixpkgs.git 2>/dev/null || true)"
      check_eq "GitHub HTTPS normalizes to generic SSH" "$rewritten" "git@github.com:NixOS/nixpkgs.git"

      ${personalChecks}

      if (( failures > 0 )); then
        printf '\nidentity-doctor: %d check(s) failed.\n' "$failures" >&2
        exit 1
      fi
      printf '\nidentity-doctor: policy is consistent.\n'
    '';
  };
in
{
  home.packages = [ identityDoctor ];
}
