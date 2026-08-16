{
  hostFeatures,
  lib,
  pkgs,
  workstationNames,
  ...
}:

let
  inputSharing = hostFeatures.inputSharing or { };
  enabled = inputSharing.enable or false;
  peers = inputSharing.peers or [ ];
  peerHosts = map (peer: peer.host) peers;
  peerPositions = map (peer: peer.position) peers;
  allowedPositions = [
    "left"
    "right"
    "top"
    "bottom"
  ];
  lanMouse = lib.getExe pkgs.lan-mouse;
  inputShareReconcile = pkgs.writeShellApplication {
    name = "input-share-reconcile";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      jq
      lan-mouse
      tailscale
    ];
    text = ''
      export INPUT_SHARE_PEERS_JSON=${lib.escapeShellArg (builtins.toJSON peers)}
      ${builtins.readFile ../../scripts/input-share-reconcile.sh}
    '';
  };
in

{
  assertions = lib.optionals enabled [
    {
      assertion = builtins.all (peer: builtins.elem peer.host workstationNames) peers;
      message = "inputSharing.peers may only reference declared workstations.";
    }
    {
      assertion = builtins.all (peer: builtins.elem peer.position allowedPositions) peers;
      message = "inputSharing peer positions must be one of left, right, top, or bottom.";
    }
    {
      assertion = builtins.length peerHosts == builtins.length (lib.unique peerHosts);
      message = "inputSharing.peers must not contain duplicate hosts.";
    }
    {
      assertion = builtins.length peerPositions == builtins.length (lib.unique peerPositions);
      message = "Lan Mouse supports a single outgoing peer per screen edge.";
    }
  ];

  home.packages = lib.optionals enabled [
    pkgs.lan-mouse
    inputShareReconcile
  ];

  systemd.user.services = lib.mkIf enabled {
    lan-mouse = {
      Unit = {
        Description = "Lan Mouse software KVM over Tailscale";
        After = [ "graphical-session.target" ];
        BindsTo = [ "graphical-session.target" ];
      };
      Service = {
        # layer-shell avoids the known wlroots modifier-key limitation when
        # desktop sends input to another Hyprland host. wlroots emulation keeps
        # the receiving hosts independent from the RemoteDesktop portal.
        ExecStart = "${lanMouse} --capture-backend layer-shell --emulation-backend wlroots daemon";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    input-share-reconcile = {
      Unit = {
        Description = "Reconcile Lan Mouse peers with the declared workstation topology";
        After = [ "lan-mouse.service" ];
        Requires = [ "lan-mouse.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe inputShareReconcile;
        # Tailscale may become usable a few seconds after the graphical session.
        # Exit 75 from the reconciler leaves the old topology untouched; systemd
        # retries until the peer list can be resolved successfully.
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  home.shellAliases = lib.mkIf enabled {
    input-share-status = "systemctl --user status lan-mouse input-share-reconcile";
    input-share-logs = "journalctl --user -u lan-mouse -u input-share-reconcile -f";
  };
}
