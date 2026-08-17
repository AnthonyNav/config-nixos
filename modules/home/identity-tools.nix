{
  lib,
  pkgs,
  username,
  ...
}:

let
  policy = import ../../inventory/identities.nix;
  identities = policy.identities;
  homeDir = "/home/${username}";

  sshKeyPath = identity: "${homeDir}/${identity.sshKey}";
  rootPath = root: "${homeDir}/${root}";

  keyChecks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: identity: ''check_readable "SSH key ${name}" ${lib.escapeShellArg (sshKeyPath identity)}''
    ) identities
  );

  routeChecks = lib.concatStringsSep "\n" (
    lib.concatLists (
      lib.mapAttrsToList (
        name: identity:
        map (
          namespace:
          let
            probe = "identity-doctor-probe.git";
            expected = "git@${identity.github.alias}:${namespace}/${probe}";
          in
          ''
            check_url "${name} HTTPS namespace ${namespace}" \
              "https://github.com/${namespace}/${probe}" \
              ${lib.escapeShellArg expected}
            check_url "${name} SCP namespace ${namespace}" \
              "git@github.com:${namespace}/${probe}" \
              ${lib.escapeShellArg expected}
            check_url "${name} SSH namespace ${namespace}" \
              "ssh://git@github.com/${namespace}/${probe}" \
              ${lib.escapeShellArg expected}
          ''
        ) identity.github.namespaces
      ) identities
    )
  );

  identityChecks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: identity:
      let
        probeRoot = rootPath (builtins.head identity.roots);
      in
      "probe_identity ${lib.escapeShellArg name} ${lib.escapeShellArg probeRoot} ${lib.escapeShellArg identity.git.email}"
    ) identities
  );

  aliasChecks = lib.concatStringsSep "\n" (
    lib.concatLists (
      lib.mapAttrsToList (
        name: identity:
        map (
          alias:
          "check_ssh_alias ${lib.escapeShellArg "${name} alias ${alias}"} ${lib.escapeShellArg alias} ${lib.escapeShellArg (sshKeyPath identity)}"
        ) ([ identity.github.alias ] ++ identity.github.compatibilityAliases)
      ) identities
    )
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

      ok() {
        printf '✓ %s\n' "$1"
      }

      fail() {
        printf '✗ %s\n' "$1" >&2
        failures=$((failures + 1))
      }

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
        if [[ -r "$path" ]]; then
          ok "$label"
        else
          fail "$label is missing or unreadable: $path"
        fi
      }

      check_url() {
        local label="$1" source="$2" expected="$3" actual
        actual="$(git ls-remote --get-url "$source" 2>/dev/null || true)"
        check_eq "$label" "$actual" "$expected"
      }

      check_ssh_alias() {
        local label="$1" alias="$2" expected="$3" actual
        actual="$(ssh -G "$alias" 2>/dev/null | sed -n 's/^identityfile //p' | head -n1)"
        check_eq "$label" "$actual" "$expected"
      }

      probe_identity() {
        local label="$1" root="$2" expected="$3" probe actual
        if [[ ! -d "$root" ]]; then
          fail "$label identity root does not exist: $root"
          return
        fi
        probe="$(mktemp -d "$root/.identity-doctor.XXXXXX")"
        if ! git -C "$probe" init -q; then
          rm -rf "$probe"
          fail "$label identity probe could not initialize a temporary repository"
          return
        fi
        actual="$(git -C "$probe" config user.email 2>/dev/null || true)"
        rm -rf "$probe"
        check_eq "$label commit identity" "$actual" "$expected"
      }

      printf 'Git identity policy\n'
      use_config_only="$(git config --global --bool user.useConfigOnly 2>/dev/null || true)"
      check_eq "fail-closed commit identity" "$use_config_only" "true"

      ${keyChecks}
      ${identityChecks}
      ${aliasChecks}
      ${routeChecks}

      check_url "unknown public HTTPS stays HTTPS" \
        "https://github.com/NixOS/nixpkgs.git" \
        "https://github.com/NixOS/nixpkgs.git"
      check_url "unknown public SCP falls back to HTTPS" \
        "git@github.com:NixOS/nixpkgs.git" \
        "https://github.com/NixOS/nixpkgs.git"
      check_url "unknown public SSH falls back to HTTPS" \
        "ssh://git@github.com/NixOS/nixpkgs.git" \
        "https://github.com/NixOS/nixpkgs.git"

      generic_identity="$(ssh -G github.com 2>/dev/null | sed -n 's/^identityfile //p' | head -n1)"
      check_eq "generic github.com SSH is blocked" "$generic_identity" "none"

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
