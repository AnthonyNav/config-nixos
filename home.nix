{ lib, pkgs, username, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/waybar.nix
    ./modules/home/kitty.nix
    ./modules/home/rofi.nix
    ./modules/home/zsh.nix
    ./modules/home/swaync.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [
    libnotify
    firefox
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

    # Utilidades Base
    unzip
    wget
    curl
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

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
