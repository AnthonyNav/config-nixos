{
  pkgs,
  lib,
  self,
  username,
  workstationNames,
}:
let
  homes = map (host: self.homeConfigurations."${username}@${host}".config) workstationNames;
  api = import ../packages/api-tools.nix { inherit pkgs lib; };
  orca = pkgs.callPackage ../packages/orca-ide.nix { };
  fixtures = pkgs.writeText "workflow-packages.json" (
    builtins.toJSON {
      posting = toString api.posting;
      postman = toString api.postman;
      schemas = api.schemaDirectory;
      hurl = "${pkgs.hurl}/bin/hurl";
      orca = toString orca;
      orcaNative = toString orca.unwrapped;
    }
  );
in
{
  portable-workspace =
    pkgs.runCommand "portable-workspace-check"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.git
        ];
      }
      ''
        export PYTHONDONTWRITEBYTECODE=1
        python ${../scripts/tests/check-portable-workspace.py} ${../scripts}
        touch "$out"
      '';
  workspace-sync =
    pkgs.runCommand "workspace-sync-check"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.syncthing
        ];
      }
      ''
        export PYTHONDONTWRITEBYTECODE=1
        python ${../scripts/tests/check-workspace-sync.py} ${../scripts/syncthing-ignores.py} ${pkgs.writeText "workspace-sync-policy.json" (builtins.toJSON (import ../inventory/syncthing.nix))} ${pkgs.syncthing}/bin/syncthing
        touch "$out"
      '';
  workspace-context =
    pkgs.runCommand "workspace-context-check"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.git
        ];
      }
      ''
        export PYTHONDONTWRITEBYTECODE=1
        python ${../scripts/tests/check-workspace-context.py} ${../scripts/workspace-context.py}
        touch "$out"
      '';
  workflow-packages =
    pkgs.runCommand "workflow-packages-check"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.glib
          pkgs.bash
        ];
      }
      ''
        export PYTHONDONTWRITEBYTECODE=1
        python ${../scripts/tests/check-workflow-packages.py} ${fixtures} ${../examples/api/health.hurl}
        touch "$out"
      '';
  platform-policy =
    assert lib.all (home: builtins.elem "platform" home.fleet.home.profiles) homes;
    assert lib.all (
      home:
      lib.all (package: builtins.any (p: toString p == toString package) home.home.packages) [
        api.bruno
        api.posting
        api.postman
      ]
    ) homes;
    assert api.bruno.version == "4.2.1" && api.posting.version == "2.11.0";
    pkgs.runCommand "platform-policy-check"
      {
        nativeBuildInputs =
          map lib.getBin
            (import ../profiles/home/platform.nix { inherit pkgs; }).home.packages;
      }
      ''
        for command in tofu terragrunt kubectl helm k9s kustomize kubectx kubens stern \
          trivy syft grype cosign dive gitleaks sops age nmap mtr iperf3 dig host \
          tcpdump fd yq just watchexec hyperfine nvd; do
        if ! command -v "$command" >/dev/null; then
          printf 'Missing platform command: %s\n' "$command" >&2
          exit 1
        fi
        done
        touch "$out"
      '';
}
