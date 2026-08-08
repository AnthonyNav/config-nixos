{ lib, pkgs, username, ... }:

{
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/kitty.nix
    ./modules/home/rofi.nix        # se conserva solo como backend dmenu (cliphist, cheatsheet)
    ./modules/home/zsh.nix
    ./modules/home/night-light.nix
    ./modules/home/lock-idle.nix
    ./modules/home/caelestia.nix
    ./modules/home/caelestia-scheme.nix # interceptor: switch claro/oscuro del panel funcione con Catppuccin
    ./modules/home/theme-mode.nix       # comandos theme-light/dark/toggle
    ./modules/home/monitors.nix         # comando set-monitor (posición/rotación de monitores externos)
    ./modules/home/theme-sync.nix
    ./modules/home/wallpapers.nix
    ./modules/home/kiro-gateway.nix # herramienta desacoplada/temporal, ver el propio archivo
    # NOTA: modules/home/creative-suite.nix (davinci-resolve, kdenlive, blender,
    # krita, gimp, inkscape, ffmpeg-full, blender-gpu.nix, gpu-launchers.nix) NO
    # se importa aquí — es opt-in por host vía flake.nix (hostExtraHomeModules),
    # solo para máquinas con GPU dedicada capaz de PRIME offload (hoy: victus).
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [
    libnotify
    firefox
    google-chrome
    nerd-fonts.jetbrains-mono

    # Fuentes — cobertura completa (emoji, CJK, idiomas)
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans

    # Fuentes/herramientas requeridas por Caelestia Shell (rama de prueba)
    material-symbols          # iconografía del launcher/bar/dashboard
    nerd-fonts.caskaydia-cove # fuente mono usada por la shell
    rubik                     # fuente del reloj/workspaces
    swappy                    # anotar capturas (usado por el area picker)

    # Gestor de archivos gráfico
    thunar
    tumbler               # miniaturas de imágenes/video en thunar

    # --- CONECTIVIDAD Y MULTIMEDIA ---
    brightnessctl
    nvtopPackages.amd
    bottom
    nvidia-vaapi-driver
    imv
    mpv

    # Puente de audio bidireccional teléfono <-> NixOS (mic/bocina) sobre
    # PipeWire (ya declarado en modules/system/core.nix). qpwgraph permite
    # enrutar visualmente qué app suena hacia el teléfono, y viceversa hacia
    # un mic virtual (pactl module-null-sink + module-remap-source, no
    # declarativo — ver README para los comandos de sesión). `pulseaudio` va
    # solo por su CLI (pactl/pacmd) — pipewire NO la incluye, aunque su
    # servidor pulse ya reemplaza al daemon real de pulseaudio.
    sonobus
    qpwgraph
    pavucontrol
    pulseaudio

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
    fvm
    android-tools
    docker-compose
    bruno
    postman
    insomnia
    gotestsum
    mockgen
    kiro
    kiro-cli
    opencode # respaldo/reproducible; la versión primaria es la autoactualizable
             # en ~/.opencode/bin (PATH la prioriza, ver modules/home/zsh.nix) —
             # `opencode upgrade` no puede escribir en este paquete (store RO).
    codex
    claude-code
    rtk # CLI que comprime salidas de comandos (git, grep, pytest, etc.) antes
        # de que lleguen al contexto de agentes IA, para ahorrar tokens.

    # Ciencia de Datos y Python
    python3
    python3Packages.pip
    micromamba
    uv # gestor de paquetes/venvs de Python; usado aquí para `uv tool install
       # graphifyy` (Graphify no está en nixpkgs).

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
    # Compresión / descompresión
    zip unzip   # .zip
    p7zip       # .7z (también descomprime .zip, .tar, .gz, .rar, .iso)
    gzip        # .gz
    bzip2       # .bz2
    xz          # .xz / .lzma
    zstd        # .zst (moderno, muy rápido)
    lz4         # .lz4
    rar         # .rar (pack + unpack, requiere allowUnfree)

    wget
    curl
    wl-clipboard
  ];

  # Tema GTK — Thunar es GTK3 (no GTK4), así que solo necesita `gtk.theme`
  # (adw-gtk3-dark instalado + fijado) para dejar de verse con fondo oscuro y
  # texto negro ilegible. catppuccin.enable ya NO tematiza GTK (catppuccin/gtk
  # fue archivado upstream), solo cubre íconos vía catppuccin.gtk.icon.
  # iconTheme NO se declara aquí: catppuccin.enable ya fija gtk.iconTheme
  # (papirus-folders con acento catppuccin) — declararlo de nuevo choca
  # ("defined multiple times").
  #
  # gtk4.theme = null: ese submódulo de home-manager gestiona
  # ~/.config/gtk-4.0/gtk.css como symlink al store, pero Caelestia YA posee
  # ese archivo (y gtk-3.0/gtk.css, con un thunar.css dedicado) — su propio
  # motor de theming (`caelestia scheme set` → apply_gtk()) lo regenera en
  # cada cambio de esquema y fija el tema real vía dconf. Con
  # home.stateVersion < 26.05, el default legado de gtk4.theme sigue siendo
  # config.gtk.theme (NO null) aunque no se declare explícitamente, así que
  # hay que forzar null; de lo contrario choca contra ese archivo
  # (home-manager-anthony.service falla: "gtk.css.hm-backup would be
  # clobbered") sin aportar nada que Caelestia no cubra ya dinámicamente.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk3.extraConfig."gtk-application-prefer-dark-theme" = 1;
    gtk4.theme = null;
    gtk4.extraConfig."gtk-application-prefer-dark-theme" = 1;
  };

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
      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };
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
