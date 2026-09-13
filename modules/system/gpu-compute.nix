{ hostFeatures, lib, ... }:

let
  gpuCompute = hostFeatures.gpuCompute or { };
  enabled = gpuCompute.enable or false;
  graphics = hostFeatures.graphics or "";
in
{
  assertions = lib.optionals enabled [
    {
      assertion = builtins.elem graphics [
        "nvidia"
        "nvidia-prime"
      ];
      message = "features.gpuCompute requires an NVIDIA graphics capability.";
    }
  ];

  # Generate a CDI specification so Docker/Podman can expose the GPU with
  # --device=nvidia.com/gpu=all without globally installing a CUDA toolkit.
  hardware.nvidia-container-toolkit.enable = lib.mkIf enabled true;
}
