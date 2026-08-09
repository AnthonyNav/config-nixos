{ pkgs, ... }:

{
  imports = [ ../../modules/home/creative-suite.nix ];

  # Victus combina iGPU AMD y RTX NVIDIA PRIME; estas herramientas no tienen
  # sentido en el perfil base ni en desktop/thinkpad.
  home.packages = [ pkgs.nvtopPackages.amd ];
}
