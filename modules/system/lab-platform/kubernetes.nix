{
  config,
  hostFeatures,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fleet.lab.kubernetes;
  inherit (lib) mkOption types;
in
{
  options.fleet.lab.kubernetes = {
    enable = lib.mkEnableOption "the selected Kubernetes lab instance";
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Start the selected instance at boot.";
    };
    role = mkOption {
      type = types.enum [
        "server"
        "agent"
      ];
      default = "server";
    };
    clusterInit = mkOption {
      type = types.bool;
      default = false;
    };
    serverAddr = mkOption {
      type = types.str;
      default = "";
    };
    tokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime join-token path, never a store path or token value.";
    };
    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    memoryHigh = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    memoryMax = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hostFeatures.capabilities.kubernetes or false;
        message = "This host must declare Kubernetes capability before enabling a lab instance.";
      }
      {
        assertion =
          cfg.role != "agent" || (cfg.serverAddr != "" && cfg.tokenFile != null && !cfg.clusterInit);
        message = "A K3s agent requires a server address and runtime token file, without clusterInit.";
      }
      {
        assertion =
          cfg.tokenFile == null
          || (lib.hasPrefix "/" cfg.tokenFile && !lib.hasPrefix "/nix/store/" cfg.tokenFile);
        message = "K3s tokens must be read from an absolute runtime path outside the Nix store.";
      }
    ];
    environment.systemPackages = [ pkgs.kubectl ];
    services.k3s = {
      enable = true;
      package = pkgs.k3s_1_36;
      inherit (cfg)
        role
        clusterInit
        serverAddr
        extraFlags
        ;
      tokenFile = lib.mkIf (cfg.tokenFile != null) cfg.tokenFile;
    };
    systemd.services.k3s = {
      wantedBy = lib.mkIf (!cfg.autoStart) (lib.mkForce [ ]);
      serviceConfig =
        lib.optionalAttrs (cfg.memoryHigh != null) { MemoryHigh = cfg.memoryHigh; }
        // lib.optionalAttrs (cfg.memoryMax != null) { MemoryMax = cfg.memoryMax; };
    };
  };
}
