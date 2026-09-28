{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.fleet.development.globalToolchains;
  compatibility =
    description:
    lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = description + " Disable only after validating project devShell replacements.";
    };
in
{
  options.fleet.development.globalToolchains = {
    node = compatibility "Install the legacy global Node.js toolchain.";
    go = compatibility "Install global Go, gotestsum and mockgen.";
    c = compatibility "Install the legacy global GCC compiler.";
    python = compatibility "Install the legacy global Python interpreter.";
  };

  config.home.packages =
    with pkgs;
    lib.optional cfg.node nodejs_22
    ++ lib.optionals cfg.go [
      go
      gotestsum
      mockgen
    ]
    ++ lib.optional cfg.c (lib.hiPrio gcc)
    ++ lib.optional cfg.python python3
    # uv remains available to provision locked project environments.
    ++ [ uv ];
}
