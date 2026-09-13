{ pkgs, ... }:

{
  # Keep a small workstation-level data stack. Project-specific libraries such
  # as PyTorch, TensorFlow, NumPy or Pandas belong in per-project environments.
  home.packages = with pkgs; [
    micromamba
    duckdb
    python3Packages.jupyterlab
  ];
}
