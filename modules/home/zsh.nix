{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;       # Sugerencias tipo Fish shell en gris claro
    syntaxHighlighting.enable = true;   # Comandos correctos en Verde, errores en Rojo

    # Autocompletado case-insensitive + menú navegable
    completionInit = ''
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' menu select
    '';

    # 🚀 ALIASES INDISPENSABLES PARA TU PRODUCTIVIDAD
    shellAliases = {
      # Reemplazo estético de listado con iconos usando eza
      ls = "eza --icons=always --color=always --group-directories-first";
      ll = "eza -l --icons=always --color=always --group-directories-first";
      la = "eza -a --icons=always --color=always --group-directories-first";
      lla = "eza -la --icons=always --color=always --group-directories-first";
      tree = "eza --tree --icons=always";

      # Atajos maestros para NixOS y tu Flake
      nix-clean = "sudo nix-collect-garbage -d && nix-collect-garbage -d && nix-store --optimize";

      # Comodidad diaria
      v = "nvim";
      c = "clear";
      ff = "fastfetch";
    };

    # Configuración inteligente del historial
    history = {
      size = 10000;
      save = 10000;
      share = true;
    };

    initContent = ''
      # Inicializar starship explícitamente usando la ruta del store de Nix
      eval "$(${pkgs.starship}/bin/starship init zsh)"

      # $HOME/.opencode/bin primero: es la versión standalone/autoactualizable
      # de opencode (gestionada por su propio `opencode upgrade`), que debe
      # ganarle en PATH a la de Nix (home.nix, solo de respaldo/reproducible —
      # el store es de solo lectura, por eso `opencode upgrade` no puede
      # aplicarse ahí). Mismo patrón que ya existe para `claude` más abajo.
      #
      # $HOME/.local/opt/blender: build oficial de blender.org con CUDA/OptiX
      # reales (el `blender` de nixpkgs es CPU-only, ver blender-gpu.nix) —
      # mismo patrón, gana en PATH sobre el de Nix.
      export PATH="$HOME/.opencode/bin:$HOME/.local/opt/blender:$HOME/.local/bin:$HOME/.local/share/pnpm:$HOME/.npm-global/bin:$PATH"

      nix-switch() {
        sudo nixos-rebuild switch --flake "path:$HOME/nixos-config#$(hostnamectl --static)"
      }

      hm-switch() {
        if command -v home-manager >/dev/null 2>&1; then
          home-manager switch --flake "path:$HOME/nixos-config#$(id -un)"
        else
          nix run github:nix-community/home-manager -- switch --flake "path:$HOME/nixos-config#$(id -un)"
        fi
      }

      night-soft() {
        pkill wlsunset 2>/dev/null || true
        wlsunset -S 00:00 -s 23:59 -T 6500 -t 4200 >/dev/null 2>&1 &
      }

      night-warm() {
        pkill wlsunset 2>/dev/null || true
        wlsunset -S 00:00 -s 23:59 -T 6500 -t 3200 >/dev/null 2>&1 &
      }

      night-off() {
        pkill wlsunset 2>/dev/null || true
      }

      night-auto() {
        pkill wlsunset 2>/dev/null || true
        systemctl --user restart wlsunset.service
      }

      pritunl() {
        local appimage="$HOME/.local/bin/pritunl-client.AppImage"
        if [ ! -f "$appimage" ]; then
          echo "Pritunl Client no está instalado. Descárgalo con:" >&2
          echo "  curl -fsSL https://github.com/pritunl/pritunl-client-electron/releases/latest/download/Pritunl.AppImage -o $appimage && chmod +x $appimage" >&2
          return 127
        fi
        appimage-run "$appimage" "$@" &
      }

      # --- Stack de creación 3D/video (ver README.md, "Edición 3D / Video") ---
      # `nvidia-offload` viene de hosts/victus/default.nix
      # (hardware.nvidia.prime.offload.enableOffloadCmd) — fuerza a la app a
      # correr en la RTX 4050 en vez del iGPU AMD.

      # DaVinci Resolve: Qt sobre Wayland nativo da problemas en Hyprland,
      # se fuerza XWayland. Recuerda: la versión gratis no importa/exporta
      # H.264/H.265 — usa to-dnxhr/to-h264 para eso.
      resolve() {
        nvidia-offload env QT_QPA_PLATFORM=xcb davinci-resolve "$@"
      }

      # Blender (standalone, ver blender-gpu.nix) forzado a la RTX. El
      # LD_LIBRARY_PATH es necesario: el loader interno de Blender (CUEW)
      # hace dlopen("libcuda.so") en runtime, y NixOS no lo expone en una
      # ruta estándar de librerías — vive en /run/opengl-driver/lib
      # (confirmado: sin esto, Preferences > System solo lista "None", con
      # esto lista OptiX y CUDA con la RTX 4050 real). Además, activar OptiX
      # en Preferences > System > CUDA/OptiX es config de GUI, no de Nix.
      #
      # Ruta absoluta a propósito (no confiar en PATH): el mismo binario se
      # invoca así también desde el .desktop de rofi (gpu-launchers.nix),
      # cuya sesión gráfica no ve el PATH de zsh — usar la misma ruta
      # absoluta en ambos lados evita que se dupliquen criterios distintos.
      blender-gpu() {
        nvidia-offload env LD_LIBRARY_PATH="/run/opengl-driver/lib:$LD_LIBRARY_PATH" "$HOME/.local/opt/blender/blender" "$@"
      }

      # Ingesta para Resolve gratis: H.264/H.265 (típico de cámara/celular)
      # -> DNxHR HQ, formato que sí puede importar/editar sin problemas.
      to-dnxhr() {
        if [ "$#" -eq 0 ]; then
          echo "Uso: to-dnxhr archivo1.mp4 [archivo2.mp4 ...]" >&2
          return 1
        fi
        local f
        for f in "$@"; do
          ffmpeg -i "$f" -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p \
            -c:a pcm_s16le "''${f%.*}_dnxhr.mov"
        done
      }

      # Entrega: master DNxHR/ProRes exportado de Resolve -> H.264 vía NVENC
      # (rápido, en la GPU) listo para subir/compartir.
      to-h264() {
        if [ "$#" -eq 0 ]; then
          echo "Uso: to-h264 master.mov" >&2
          return 1
        fi
        ffmpeg -i "$1" -c:v h264_nvenc -preset p5 -cq 19 -c:a aac -b:a 192k \
          "''${1%.*}_h264.mp4"
      }

      # theme-light / theme-dark / theme-toggle: NO son funciones zsh a
      # propósito (ver modules/home/theme-mode.nix) — son ejecutables reales
      # en el PATH del perfil, porque también se invocan desde el atajo de
      # Hyprland (Super+Shift+T), y `exec` de Hyprland corre el comando vía
      # `sh -c`, no zsh: una función de zsh ahí no existiría (mismo bug que
      # ya se documentó para rofi/.desktop en gpu-launchers.nix).

      claude() {
        if [ -x "$HOME/.local/bin/claude" ]; then
          command "$HOME/.local/bin/claude" "$@"
          return
        fi

        local npm_root
        npm_root="$(npm root -g 2>/dev/null)" || {
          echo "Claude Code no está instalado todavía." >&2
          return 127
        }

        if [ -f "$npm_root/@anthropic-ai/claude-code/cli.js" ]; then
          command node "$npm_root/@anthropic-ai/claude-code/cli.js" "$@"
        else
          echo "Claude Code no está instalado todavía." >&2
          return 127
        fi
      }
    '';
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Prompt Starship — Catppuccin Mocha + indicadores de contexto
  programs.starship = {
    enable = true;
    enableZshIntegration = false;  # Se inicializa manualmente en initContent con ruta Nix
    settings = {
      add_newline = false;

      # Línea 1: contexto completo  /  Línea 2: cursor
      format = "$directory$git_branch$git_status$python$conda$nodejs$golang$nix_shell$cmd_duration$line_break$character";

      directory = {
        style = "bold #89b4fa";       # blue
        truncate_to_repo = true;
        read_only = " 󰌾";
      };

      git_branch = {
        symbol = " ";
        style = "bold #cba6f7";       # mauve
        format = "on [$symbol$branch]($style) ";
      };

      git_status = {
        style = "bold #f38ba8";       # red
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        modified = "!$count";
        staged = "+$count";
        untracked = "?$count";
        deleted = "✘$count";
      };

      # Entorno virtual Python — aparece solo cuando hay un .venv activo
      python = {
        symbol = " ";
        style = "bold #f9e2af";       # yellow
        format = "[$symbol($virtualenv )]($style)";
        detect_extensions = ["py"];
        detect_files = [".python-version" "requirements.txt" "pyproject.toml" "setup.py" "Pipfile"];
      };

      # Micromamba / Conda — aparece cuando hay un env activado
      conda = {
        symbol = "󱔎 ";
        style = "bold #a6e3a1";       # green
        format = "[$symbol$environment ]($style)";
        ignore_base = false;
      };

      # Node.js — aparece solo dentro de proyectos JS/TS
      nodejs = {
        symbol = " ";
        style = "bold #a6e3a1";       # green
        format = "[$symbol$version ]($style)";
        detect_extensions = ["js" "ts" "mjs" "cjs"];
        detect_files = ["package.json" ".nvmrc" ".node-version"];
      };

      # Go — aparece solo dentro de proyectos Go
      golang = {
        symbol = " ";
        style = "bold #89dceb";       # sky
        format = "[$symbol$version ]($style)";
        detect_extensions = ["go"];
        detect_files = ["go.mod" "go.sum"];
      };

      # Nix devshell — muestra nombre del shell al hacer `nix develop` o con direnv
      nix_shell = {
        symbol = " ";
        style = "bold #74c7ec";       # sapphire
        format = "[$symbol$name ]($style)";
        impure_msg = "[impure](#fab387)";
        pure_msg = "[pure](#a6e3a1)";
      };

      # Duración del último comando — solo si tardó más de 2 s
      cmd_duration = {
        min_time = 2000;
        style = "bold #fab387";       # peach
        format = "[⏱ $duration ]($style)";
      };

      character = {
        success_symbol = "[❯](bold #a6e3a1)";   # green
        error_symbol = "[❯](bold #f38ba8)";     # red
      };
    };
  };

  # Herramientas de soporte visual activas
  programs.eza.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
