{
  lib,
  pkgs,
  username,
  ...
}:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [
    libnotify
    firefox
    google-chrome
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
    thunar
    tumbler
    bottom
    imv
    mpv
    sonobus
  ];

  programs.btop = {
    enable = true;
    settings = {
      theme_background = false;
      truecolor = true;
    };
  };

  programs.bat = {
    enable = true;
    config.style = "numbers,changes,header";
  };

  # One-time cleanup for the legacy Claude Code setting previously written by
  # this repository. Preserve every other user-managed Claude setting/state.
  home.activation.cleanupLegacyClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file="$HOME/.claude/settings.json"

    if [ -f "$settings_file" ] && ${pkgs.jq}/bin/jq -e . "$settings_file" >/dev/null 2>&1; then
      if ${pkgs.jq}/bin/jq -e 'has("forceLoginMethod")' "$settings_file" >/dev/null; then
        tmp_file="$(mktemp)"
        ${pkgs.jq}/bin/jq 'del(.forceLoginMethod)' "$settings_file" > "$tmp_file"

        if [ "$(${pkgs.jq}/bin/jq 'length' "$tmp_file")" -eq 0 ]; then
          rm -f "$settings_file" "$tmp_file"
        else
          install -m 600 "$tmp_file" "$settings_file"
          rm -f "$tmp_file"
        fi
      fi
    fi
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*".AddKeysToAgent = "yes";
      "github.com" = {
        HostName = "github.com";
        IdentityFile = "/home/${username}/.ssh/id_work";
        IdentitiesOnly = true;
        User = "git";
      };
      "github.com-kigo" = {
        HostName = "github.com";
        IdentityFile = "/home/${username}/.ssh/id_work";
        IdentitiesOnly = true;
        User = "git";
      };
      "github.com-personal" = {
        HostName = "github.com";
        IdentityFile = "/home/${username}/.ssh/id_personal";
        IdentitiesOnly = true;
        User = "git";
      };
      "debian-server" = {
        HostName = "192.168.1.250";
        IdentityFile = "/home/${username}/.ssh/debian13-server-192.168.1.250";
        IdentitiesOnly = true;
        User = "anthony";
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Antonio Zempoaltecatl";
        email = "antonio.zempoaltecatl@cargomovil.com";
      };
      url."git@github.com:".insteadOf = "https://github.com/";
    };
    includes = [
      {
        condition = "gitdir:/home/${username}/personal/";
        contents.user = {
          name = "Antonio Zempoaltecatl";
          email = "anthonydevxp@gmail.com";
        };
      }
      {
        condition = "gitdir:/home/${username}/nixos-config/";
        contents.user = {
          name = "Antonio Zempoaltecatl";
          email = "anthonydevxp@gmail.com";
        };
      }
    ];
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
