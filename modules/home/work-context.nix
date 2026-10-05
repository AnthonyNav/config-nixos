{
  config,
  lib,
  pkgs,
  ...
}:
let
  tools = import ../../packages/workspace-tools.nix {
    inherit pkgs lib;
    inherit (config.home) homeDirectory;
  };
in
{
  home.packages = [ tools.helpers ];
  programs.zsh.initContent = lib.mkAfter ''
    _update_work_context() {
      # Presentation only. Wrappers resolve the effective directory themselves.
      export WORK_CONTEXT="$(${tools.wrappers}/bin/workspace-context status --name)"
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _update_work_context
    _update_work_context
  '';
}
