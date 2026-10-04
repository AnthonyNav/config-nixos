{ pkgs, ... }:

{
  # Compatibility only for the existing data profile; portable daily shells
  # do not inherit native Jupyter libraries. Migrate projects before disabling.
  fleet.development.legacyJupyterLibraries = true;
  # Keep a small workstation-level data stack. Project-specific libraries such
  # as PyTorch, TensorFlow, NumPy or Pandas belong in per-project environments.
  home.packages = with pkgs; [
    micromamba
    duckdb
    python3Packages.jupyterlab
  ];
}
