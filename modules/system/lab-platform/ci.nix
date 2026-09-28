{
  config,
  hostFeatures,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fleet.lab.ci;
  inherit (lib) mkOption types;
  agentType = types.submodule {
    options = {
      description = mkOption { type = types.str; };
      environmentFile = mkOption {
        type = types.str;
        description = "Root-owned mode 0600 runtime secret file.";
      };
      server = mkOption { type = types.str; };
      hostname = mkOption { type = types.str; };
      labels = mkOption { type = types.str; };
      containerName = mkOption { type = types.str; };
      configVolume = mkOption { type = types.str; };
      maxWorkflows = mkOption {
        type = types.ints.positive;
        default = 1;
      };
      autoStart = mkOption {
        type = types.bool;
        default = true;
      };
      image = mkOption {
        type = types.str;
        default = "woodpeckerci/woodpecker-agent:v3.18.0";
      };
    };
  };
  mkAgent = _: agent: {
    inherit (agent) description;
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = lib.optional agent.autoStart "multi-user.target";
    unitConfig.ConditionPathExists = agent.environmentFile;
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      TimeoutStopSec = "45s";
      ExecStartPre = "-${pkgs.docker}/bin/docker rm --force ${agent.containerName}";
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name=${agent.containerName} --init --env-file ${agent.environmentFile} --env WOODPECKER_SERVER=${agent.server} --env WOODPECKER_HOSTNAME=${agent.hostname} --env WOODPECKER_AGENT_CONFIG_FILE=/etc/woodpecker/agent.conf --env WOODPECKER_BACKEND=docker --env WOODPECKER_AGENT_LABELS=${agent.labels} --env WOODPECKER_MAX_WORKFLOWS=${toString agent.maxWorkflows} --mount type=volume,src=${agent.configVolume},dst=/etc/woodpecker --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock ${agent.image} agent";
      ExecStop = "${pkgs.docker}/bin/docker stop --time=30 ${agent.containerName}";
    };
  };
in
{
  options.fleet.lab.ci = {
    agents = mkOption {
      type = types.attrsOf agentType;
      default = { };
      description = "Agent instances keyed by their systemd unit name (without .service).";
    };
    dockerBridgeGrpcPort = mkOption {
      type = types.nullOr types.port;
      default = null;
    };
    testcontainers = lib.mkEnableOption "the Docker bridge ephemeral-port allowance used by Testcontainers";
  };
  config = lib.mkIf (cfg.agents != { }) {
    assertions = [
      {
        assertion = hostFeatures.capabilities.ci or false;
        message = "CI agent instances require CI capability.";
      }
      {
        assertion = config.virtualisation.docker.enable;
        message = "Woodpecker Docker agents require Docker.";
      }
      {
        assertion = lib.all (
          agent: lib.hasPrefix "/" agent.environmentFile && !lib.hasPrefix "/nix/store/" agent.environmentFile
        ) (builtins.attrValues cfg.agents);
        message = "CI secrets must use absolute runtime paths outside the Nix store.";
      }
      {
        assertion =
          let
            names = map (a: a.containerName) (builtins.attrValues cfg.agents);
          in
          builtins.length names == builtins.length (lib.unique names);
        message = "CI container names must be unique.";
      }
    ];
    systemd.services = lib.mapAttrs mkAgent cfg.agents;
    networking.firewall.interfaces.docker0 = {
      allowedTCPPorts = lib.optional (cfg.dockerBridgeGrpcPort != null) cfg.dockerBridgeGrpcPort;
      allowedTCPPortRanges = lib.optional cfg.testcontainers {
        from = 32768;
        to = 60999;
      };
    };
  };
}
