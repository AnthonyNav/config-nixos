{ username }:

let
  endpoints = import ./endpoints.nix;
  grantIps = builtins.map (
    endpoint: "${endpoint.protocol}:${toString endpoint.port}"
  ) endpoints.tailnet;
in

{
  node = {
    forceHostname = true;
    enableSsh = true;
    allowIncoming = true;
  };

  tailnetPolicy = {
    grants = [
      {
        src = [ "autogroup:member" ];
        dst = [ "autogroup:self" ];
        ip = grantIps;
      }
    ];

    ssh = [
      {
        action = "check";
        src = [ "autogroup:member" ];
        dst = [ "autogroup:self" ];
        users = [ username ];
        checkPeriod = "12h";
      }
    ];
  };
}
