{ hostFeatures, lib, ... }:
{
  imports = [
    ./common.nix
    ./lab-platform
  ]
  ++ lib.optional (hostFeatures.kind == "workstation") ./workstation.nix
  ++ lib.optional (hostFeatures.kind == "server") ./server.nix;
}
