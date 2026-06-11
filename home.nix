{ lib, pkgs, username, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/waybar.nix
    ./modules/home/kitty.nix
    ./modules/home/rofi.nix
    ./modules/home/zsh.nix
    ./modules/home/swaync.nix
    ./modules/home/night-light.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [
    libnotify
    firefox
    google-chrome
    papirus-icon-theme
    nerd-fonts.jetbrains-mono

    # --- CONECTIVIDAD Y MULTIMEDIA ---
    networkmanager_dmenu
    overskride
    brightnessctl
    nvtopPackages.amd
    bottom
    nvidia-vaapi-driver
    imv
    mpv
    mpvpaper

    # --- PRODUCTIVIDAD ---
    grim
    slurp
    wl-clipboard
    cliphist
    hyprpicker

    # --- ENTORNO DE DESARROLLO E INGENIERÍA ---
    vscode
    vim
    nano
    neovim

    # Desarrollo Web, Móvil y Emuladores
    android-studio
    flutter
    nodejs_22            # 🛠️ Solución: Mantiene Node.js (que ya incluye corepack internamente)
    go
    kotlin
    docker-compose
    bruno
    gotestsum
    mockgen
    kiro
    kiro-cli
    opencode
    codex
    claude-code

    # Ciencia de Datos y Python
    python3
    python3Packages.pip
    micromamba

    # Ingeniería de Software C++
    gcc
    gnumake
    cmake
    gdb

    # Ecosistema C# y Backend .NET
    dotnet-sdk_8
    grpcurl
    httpie

    # Utilidades Base
    unzip
    wget
    curl
    wl-clipboard
  ];

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  programs.btop = {
    enable = true;
    settings = {
      theme_background = false;
      truecolor = true;
    };
  };

  programs.bat = {
    enable = true;
    config = {
      style = "numbers,changes,header"; # Personaliza qué bordes o decoraciones mostrar
    };
  };

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

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
      "*" = {
        AddKeysToAgent = "yes";
      };
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
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "Antonio Zempoaltecatl";
      email = "antonio.zempoaltecatl@cargomovil.com";
    };
    includes = [
      {
        condition = "gitdir:/home/${username}/personal/";
        contents = {
          user = {
            name = "Antonio Zempoaltecatl";
            email = "anthonydevxp@gmail.com";
          };
        };
      }
    ];
  };

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
