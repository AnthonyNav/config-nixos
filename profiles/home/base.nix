{
  lib,
  pkgs,
  username,
  ...
}:

{
  imports = [
    ../../modules/home/browsers.nix
    ../../modules/home/media.nix
    ../../modules/home/shell-tools.nix
    ../../modules/home/neovim.nix
    ../../modules/home/orca.nix
  ];
  fleet.ai.orca.enable = true;
  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
  ];

  # One-time cleanup for the legacy Claude Code setting previously written by
  # this repository. Preserve every other user-managed Claude setting/state.
  home.activation.cleanupLegacyClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_file="$HOME/.claude/settings.json"

    if [ -f "$settings_file" ] && ${pkgs.jq}/bin/jq -e . "$settings_file" >/dev/null 2>&1; then
      if ${pkgs.jq}/bin/jq -e 'has("forceLoginMethod")' "$settings_file" >/dev/null; then
        tmp_file="$(mktemp)"
        ${pkgs.jq}/bin/jq 'del(.forceLoginMethod)' "$settings_file" > "$tmp_file"

        if [ "$(${pkgs.jq}/bin/jq 'length' "$tmp_file")" -eq 0 ]; then
          rm -f "$settings_file" "$tmp_file"
        else
          install -m 600 "$tmp_file" "$settings_file"
          rm -f "$tmp_file"
        fi
      fi
    fi
  '';

  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
