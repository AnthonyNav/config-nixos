{
  config,
  lib,
  pkgs,
  ...
}:
let
  enabled =
    pkgs.stdenv.hostPlatform.isLinux && builtins.elem "development" config.fleet.home.profiles;
  helper = pkgs.writeShellApplication {
    name = "fleet-editor-bindings";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../../scripts/editor-bindings.py} \
        --jsonc-parser ${../../scripts/ai-opencode.py} \
        --bindings ${../../dotfiles/vscode/fleet-linux-keybindings.json} \
        --home ${lib.escapeShellArg config.home.homeDirectory} \
        --target ${lib.escapeShellArg "${config.xdg.configHome}/Code/User/keybindings.json"} \
        --state ${lib.escapeShellArg "${config.xdg.stateHome}/fleet/editor-bindings/ownership.json"} \
        "$@"
    '';
  };
in
{
  # Linux aliases are merged into the mutable default VSCode profile. Darwin
  # keeps Code's native Command bindings; no user JSON is imported into Nix.
  config = lib.mkIf enabled {
    home.packages = [ helper ];
    home.activation.checkFleetEditorBindings = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      ${helper}/bin/fleet-editor-bindings check
    '';
    home.activation.reconcileFleetEditorBindings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${helper}/bin/fleet-editor-bindings apply
    '';
  };
}
