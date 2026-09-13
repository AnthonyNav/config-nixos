# Victus creative + ML workstation

Victus is the high-performance interactive workstation in this fleet. It combines the shared mobile-development role with data-science, GPU-compute, creative-production, virtualization, and explicit power-profile controls.

## Role

The host imports `profiles/home/roles/creative-ml-development.nix`, which composes:

- `mobile-development`: Flutter/Android, web/backend, AI tools, API/database tooling.
- `development/data-science.nix`: Micromamba, DuckDB, and JupyterLab.
- `creative-production.nix`: Resolve, Kdenlive, Blender, Krita, GIMP, Inkscape, Glaxnimate, FFmpeg/NVENC, and multi-GPU `nvtop`.
- `performance-workstation.nix`: `work-balanced`, `work-performance`, and `work-save`.

Project-specific ML frameworks are intentionally not installed globally. Keep PyTorch, TensorFlow, NumPy/Pandas/scikit-learn and CUDA development libraries in project-specific Nix/uv/Micromamba environments so versions remain reproducible and do not inflate every workstation generation.

## GPU model

The AMD iGPU remains the normal desktop renderer. The RTX 4050 is exposed through NVIDIA PRIME offload for GPU-heavy applications. The existing `gpu-launch`, `resolve`, and `blender-gpu` launchers continue to force creative workloads onto NVIDIA when appropriate.

`features.gpuCompute.enable = true` also enables the NixOS NVIDIA Container Toolkit. It generates a CDI specification at boot. Verify it with:

```sh
systemctl status nvidia-container-toolkit-cdi-generator.service
cat /var/run/cdi/nvidia-container-toolkit.json | jq -r '.devices[].name'
```

Docker can expose the RTX without a global CUDA toolkit:

```sh
docker run --rm --device=nvidia.com/gpu=all nvidia/cuda:12.8.1-base-ubuntu24.04 nvidia-smi
```

For native CUDA Nix projects, prefer an architecture-specific package set such as `pkgsForCudaArch.sm_89` instead of enabling `cudaSupport` globally.

## Memory and background services

The shared workstation policy keeps ZRAM at 50% with zstd. Victus adds an 8 GiB encrypted, low-priority disk swap file at `/var/lib/nixos-victus-memory-swapfile` as an emergency buffer for Android Studio, VMs, ML notebooks, Resolve, and Blender. It is not additional RAM and persistent swap activity should be treated as a signal to reduce the working set.

Docker no longer starts at boot. The socket starts the daemon on first Docker API use. Victus no longer runs a Woodpecker CI agent and no longer exposes the Zellij Web remote workspace. Virtualization Lab, Tailscale/SSH, Syncthing, Lan Mouse, and Pritunl remain available.

Useful checks:

```sh
free -h
zramctl
swapon --show
cat /proc/pressure/memory
nvidia-smi
nvtop
powerprofilesctl get
```

Use `work-balanced` for normal work, `work-performance` for sustained builds/render/training on AC power, and `work-save` when battery life matters.
