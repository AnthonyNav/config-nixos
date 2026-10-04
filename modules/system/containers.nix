{
  config,
  lib,
  username,
  ...
}:
let
  rootless = config.fleet.containers.rootless;
in
{
  options.fleet.containers.rootless = lib.mkEnableOption "user-owned Docker after an explicit data/GPU migration";
  config = {
    virtualisation.docker = {
      enable = !rootless;
      rootless = {
        enable = rootless;
        setSocketVariable = rootless;
      };
    };
    users.users.${username}.extraGroups = lib.optionals (!rootless) [ "docker" ];
    # Preserve the on-demand resource policy in rootless mode too. The daemon
    # can be started explicitly; enabling a capability must not start a load.
    systemd.user.services.docker = lib.mkIf rootless { wantedBy = lib.mkForce [ ]; };
  };
}
