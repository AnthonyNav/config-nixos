{ username }:

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
        ip = [
          "tcp:22" # Tailscale SSH / OpenSSH break-glass.
          "tcp:22000" # Syncthing fleet transport.
          "udp:4242" # Lan Mouse input-sharing transport.
        ];
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
