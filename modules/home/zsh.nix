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
      export PATH="$HOME/.local/bin:$HOME/.local/share/pnpm:$HOME/.npm-global/bin:$PATH"

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
    settings = {
      add_newline = true;

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
