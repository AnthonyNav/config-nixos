{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;       # Sugerencias tipo Fish shell en gris claro
    syntaxHighlighting.enable = true;   # Comandos correctos en Verde, errores en Rojo

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

  # 🚀 PROMPT ESTÉTICO MINIMALISTA (STARSHIP)
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      
      # Estilo de la línea de comandos principal
      format = "$directory$git_branch$git_status$nix_shell$character";
      
      directory = {
        style = "bold cyan";
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
      };

      git_status = {
        style = "bold red";
      };

      nix_shell = {
        symbol = " ";
        style = "bold blue";
        format = "via [$symbol\\($name\\)]($style) ";
      };

      character = {
        success_symbol = "[ ➜ ](bold magenta)";
        error_symbol = "[ ➜ ](bold red)";
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
