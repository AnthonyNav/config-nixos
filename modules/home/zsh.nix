{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true; # Sugerencias tipo Fish shell en gris claro
    syntaxHighlighting.enable = true; # Comandos correctos en Verde, errores en Rojo

    # Autocompletado case-insensitive + menú navegable
    completionInit = ''
      # NixOS expone las funciones estandar de Zsh mediante varios perfiles que
      # resuelven al mismo store path. Conserva una copia y todas las
      # site/vendor completions para evitar escanear miles de duplicados.
      fpath=(
        ${pkgs.zsh}/share/zsh/$ZSH_VERSION/functions
        ''${fpath:#*/share/zsh/$ZSH_VERSION/functions}
      )

      autoload -Uz compinit
      compinit -d "$HOME/.zcompdump"

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

      # Comodidad diaria
      v = "nvim";
      c = "clear";
      ff = "fastfetch";
      # Claude Code sigue disponible, pero la versión de Nix evita que una
      # instalación local autoactualizable desincronice los workstations.
      claude = "${pkgs.claude-code}/bin/claude";

      # Pritunl VPN: el cliente real (CLI + daemon + GUI) se instala a nivel
      # de sistema, reproducible desde nixpkgs (ver modules/system/pritunl.nix)
      # — ya no es el AppImage manual que este alias reemplaza. `pritunl` abre
      # la GUI (Electron); la CLI real es `pritunl-client`
      # (ver `pritunl-client --help`).
      pritunl = "pritunl-client-electron";
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

      export PATH="$HOME/.local/bin:$HOME/.local/share/pnpm:$HOME/.npm-global/bin:$PATH"

      if [ -S "$XDG_RUNTIME_DIR/ssh-agent" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"
      fi

      source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey '^[[1;5D' backward-word
      bindkey '^[[1;5C' forward-word
      bindkey '^[[5D' backward-word
      bindkey '^[[5C' forward-word
      bindkey '^[OD' backward-word
      bindkey '^[OC' forward-word
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh

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

      # theme-light / theme-dark / theme-toggle: NO son funciones zsh a
      # propósito (ver modules/home/theme-mode.nix) — son ejecutables reales
      # en el PATH del perfil, porque también se invocan desde el atajo de
      # Hyprland (Super+Shift+T), y `exec` de Hyprland corre el comando vía
      # `sh -c`, no zsh: una función de zsh ahí no existiría (mismo bug que
      # ya se documentó para rofi/.desktop en gpu-launchers.nix).

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
    enableZshIntegration = false; # Se inicializa manualmente en initContent con ruta Nix
    settings = {
      add_newline = false;

      # Línea 1: contexto completo  /  Línea 2: cursor
      format = "$directory$git_branch$git_status$python$conda$nodejs$golang$nix_shell$cmd_duration$line_break$character";

      directory = {
        style = "bold #89b4fa"; # blue
        truncate_to_repo = true;
        read_only = " 󰌾";
      };

      git_branch = {
        symbol = " ";
        style = "bold #cba6f7"; # mauve
        format = "on [$symbol$branch]($style) ";
      };

      git_status = {
        style = "bold #f38ba8"; # red
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
        style = "bold #f9e2af"; # yellow
        format = "[$symbol($virtualenv )]($style)";
        detect_extensions = [ "py" ];
        detect_files = [
          ".python-version"
          "requirements.txt"
          "pyproject.toml"
          "setup.py"
          "Pipfile"
        ];
      };

      # Micromamba / Conda — aparece cuando hay un env activado
      conda = {
        symbol = "󱔎 ";
        style = "bold #a6e3a1"; # green
        format = "[$symbol$environment ]($style)";
        ignore_base = false;
      };

      # Node.js — aparece solo dentro de proyectos JS/TS
      nodejs = {
        symbol = " ";
        style = "bold #a6e3a1"; # green
        format = "[$symbol$version ]($style)";
        detect_extensions = [
          "js"
          "ts"
          "mjs"
          "cjs"
        ];
        detect_files = [
          "package.json"
          ".nvmrc"
          ".node-version"
        ];
      };

      # Go — aparece solo dentro de proyectos Go
      golang = {
        symbol = " ";
        style = "bold #89dceb"; # sky
        format = "[$symbol$version ]($style)";
        detect_extensions = [ "go" ];
        detect_files = [
          "go.mod"
          "go.sum"
        ];
      };

      # Nix devshell — muestra nombre del shell al hacer `nix develop` o con direnv
      nix_shell = {
        symbol = " ";
        style = "bold #74c7ec"; # sapphire
        format = "[$symbol$name ]($style)";
        impure_msg = "[impure](#fab387)";
        pure_msg = "[pure](#a6e3a1)";
      };

      # Duración del último comando — solo si tardó más de 2 s
      cmd_duration = {
        min_time = 2000;
        style = "bold #fab387"; # peach
        format = "[⏱ $duration ]($style)";
      };

      character = {
        success_symbol = "[❯](bold #a6e3a1)"; # green
        error_symbol = "[❯](bold #f38ba8)"; # red
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
