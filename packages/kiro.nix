{ pkgs }:

let
  cliVersion = "2.25.0";
  cliUnwrapped = pkgs.kiro-cli-unwrapped.overrideAttrs (_: {
    version = cliVersion;
    src = pkgs.fetchurl {
      url = "https://desktop-release.q.us-east-1.amazonaws.com/${cliVersion}/kirocli-x86_64-linux.tar.gz";
      hash = "sha256-rC84lpJR0aOC+zzvA+Rj43sbAfEoAohMPr64yu/sMyM=";
    };
  });
in
{
  cli = pkgs.kiro-cli.override { kiro-cli-unwrapped = cliUnwrapped; };
  ide = pkgs.callPackage ./kiro-ide.nix { };
}
