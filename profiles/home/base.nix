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

  home.activation.configureClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        claude_dir="$HOME/.claude"
        settings_file="$claude_dir/settings.json"
        mkdir -p "$claude_dir"

        if [ -f "$settings_file" ] && ${pkgs.jq}/bin/jq -e . "$settings_file" >/dev/null 2>&1; then
          tmp_file="$(mktemp)"
          ${pkgs.jq}/bin/jq '. + {"forceLoginMethod":"claudeai"}' "$settings_file" > "$tmp_file"
          install -m 600 "$tmp_file" "$settings_file"
          rm -f "$tmp_file"
        elif [ -f "$settings_file" ]; then
          mv "$settings_file" "$settings_file.hm-backup-invalid"
          cat > "$settings_file" <<'EOF'
    {"forceLoginMethod":"claudeai"}
    EOF
          chmod 600 "$settings_file"
        else
          cat > "$settings_file" <<'EOF'
    {"forceLoginMethod":"claudeai"}
    EOF
          chmod 600 "$settings_file"
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
    ];
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
