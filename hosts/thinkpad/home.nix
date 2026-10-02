{ hostFeatures, ... }:

{
  imports = [ ../../profiles/home/roles/mobile-development.nix ];

  fleet.ai.orca.enable = true;

  assertions = [
    {
      assertion = !hostFeatures.creativeNvidia;
      message = "ThinkPad is a development-only host and must not enable creative NVIDIA tools.";
    }
  ];
}
