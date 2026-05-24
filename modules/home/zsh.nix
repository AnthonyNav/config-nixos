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
      nix-switch = "cd ~/nixos-config && git add . && sudo nixos-rebuild switch --flake .#victus";
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
