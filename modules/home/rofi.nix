{ config, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    
    extraConfig = {
      modi = "drun,run";
      show-icons = true;
      icon-theme = "Papirus";
      drun-display-format = "{name}";
      disable-history = false;
      sidebar-mode = false;
    };

    theme = let
      inherit (config.lib.formats.rasi) mkLiteral;
    in {
      "*" = {
        bg-col = mkLiteral "#1e1e2e";
        border-col = mkLiteral "#cba6f7";
        selected-col = mkLiteral "#313244";
        text-col = mkLiteral "#cdd6f4";
        fg-col = mkLiteral "#f38ba8";
        
        background-color = mkLiteral "@bg-col";
        font = "JetBrainsMono Nerd Font 11";
      };

      "window" = {
        height = mkLiteral "450px";
        width = mkLiteral "650px";
        border = mkLiteral "2px";
        border-color = mkLiteral "@border-col";
        border-radius = mkLiteral "12px";
      };

      "mainbox" = {
        background-color = mkLiteral "@bg-col";
        children = map mkLiteral [ "inputbar" "listview" ];
      };

      "inputbar" = {
        children = map mkLiteral [ "prompt" "entry" ];
        background-color = mkLiteral "@bg-col";
        padding = mkLiteral "12px";
      };

      "prompt" = {
        background-color = mkLiteral "@border-col";
        padding = mkLiteral "6px 10px";
        text-color = mkLiteral "#11111b";
        border-radius = mkLiteral "6px";
      };

      "entry" = {
        text-color = mkLiteral "@text-col";
        padding = mkLiteral "6px 10px";
      };

      "listview" = {
        border = mkLiteral "0px";
        padding = mkLiteral "6px 12px";
        columns = 1;
        lines = 8;
        background-color = mkLiteral "@bg-col";
      };

      "element" = {
        padding = mkLiteral "8px";
        background-color = mkLiteral "@bg-col";
        text-color = mkLiteral "@text-col";
        border-radius = mkLiteral "6px";
      };

      "element-text" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "inherit";
      };

      "element-icon" = {
        size = mkLiteral "24px";
        background-color = mkLiteral "transparent";
      };

      "element selected" = {
        background-color = mkLiteral "@selected-col";
        text-color = mkLiteral "@text-col";
      };
    };
  };
}
