{ pkgs, ... }:

{
  imports = [ ./project-environments.nix ];

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

      ${builtins.readFile ../../scripts/development-path.zsh}

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
    settings = builtins.fromTOML (builtins.readFile ../../dotfiles/starship/starship.toml);
  };

  # Herramientas de soporte visual activas
  programs.eza.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

}
