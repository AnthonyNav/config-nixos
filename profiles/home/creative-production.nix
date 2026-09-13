{ pkgs, ... }:

{
  imports = [ ../../modules/home/creative-suite.nix ];

  home.packages = with pkgs; [
    kdePackages.glaxnimate
    nvtopPackages.full
  ];
}
