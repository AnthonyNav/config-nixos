{ lib, ... }:
{
  imports = [
    ../../modules/home/browsers.nix
    ../../modules/home/media.nix
    ../../modules/home/orca.nix
    ../../modules/home/orca-remote.nix
    ./performance-workstation.nix
  ];
  fleet.ai.orca.enable = lib.mkDefault true;
  programs.zsh.shellAliases.pritunl = "pritunl-client-electron";
  programs.zsh.initContent = lib.mkAfter ''
    if [[ -n "''${XDG_RUNTIME_DIR:-}" && -S "$XDG_RUNTIME_DIR/ssh-agent" ]]; then
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"
    fi
    night-soft() {
      pkill wlsunset 2>/dev/null || true
      wlsunset -S 00:00 -s 23:59 -T 6500 -t 4200 >/dev/null 2>&1 &
    }
    night-warm() {
      pkill wlsunset 2>/dev/null || true
      wlsunset -S 00:00 -s 23:59 -T 6500 -t 3200 >/dev/null 2>&1 &
    }
    night-off() { pkill wlsunset 2>/dev/null || true; }
    night-auto() {
      pkill wlsunset 2>/dev/null || true
      systemctl --user restart wlsunset.service
    }
  '';
}
