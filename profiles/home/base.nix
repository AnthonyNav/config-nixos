{
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
