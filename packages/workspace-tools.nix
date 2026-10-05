{
  pkgs,
  lib ? pkgs.lib,
  homeDirectory,
  policy ? import ../inventory/identities.nix,
}:
let
  configuration = pkgs.writeText "workspace-policy.json" (
    builtins.toJSON {
      inherit policy homeDirectory;
      binaries = {
        git = "${pkgs.git}/bin/git";
        gh = "${pkgs.gh}/bin/gh";
        aws = "${pkgs.awscli2}/bin/aws";
        ssh = "${pkgs.openssh}/bin/ssh";
      };
    }
  );
  wrappers = pkgs.runCommand "workspace-tools" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p "$out/bin"
    for command in git gh aws workspace workspace-context work-context identity-doctor \
      aws-work aws-personal aws-login aws-profile-setup aws-whoami gh-login gh-whoami; do
      makeWrapper ${pkgs.python3}/bin/python3 "$out/bin/$command" \
        --add-flags "-B" \
        --add-flags ${lib.escapeShellArg "${../scripts}/workspace-context.py"} \
        --add-flags "--config ${configuration} $command" \
        --set FLEET_WRAPPER_BIN "$out/bin"
    done
  '';
  wrapPackage =
    name: original:
    pkgs.symlinkJoin {
      name = "workspace-${name}-${original.version}";
      inherit (original) version meta;
      paths = [ original ];
      postBuild = ''ln -sf ${wrappers}/bin/${name} "$out/bin/${name}"'';
    };
in
{
  inherit configuration wrappers;
  git = wrapPackage "git" pkgs.git;
  gh = wrapPackage "gh" pkgs.gh;
  helpers = pkgs.symlinkJoin {
    name = "workspace-helpers";
    paths = [ wrappers ];
    postBuild = ''rm "$out/bin/git" "$out/bin/gh"'';
  };
}
