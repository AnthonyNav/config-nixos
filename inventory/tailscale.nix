{ username }:

{
  node = {
    forceHostname = true;
    enableSsh = true;
    allowIncoming = true;
  };

  # This is the desired tailnet control-plane policy. It is intentionally
  # expressed without account-specific email addresses: autogroup:self keeps
  # access scoped to devices owned by the same authenticated tailnet user.
  #
  # Applying this policy to Tailscale remains an external control-plane action;
  # the repo owns the desired document and can render/validate it without ever
  # storing a Tailscale API credential.
  tailnetPolicy = {
    grants = [
      {
        src = [ "autogroup:member" ];
        dst = [ "autogroup:self" ];
        ip = [
          "tcp:22" # Tailscale SSH / OpenSSH break-glass after disabling TS SSH.
          "tcp:443" # Private Tailscale Serve HTTPS for remote OpenCode Web.
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
