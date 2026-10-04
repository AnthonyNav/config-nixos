_: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;
    initLua = builtins.readFile ../../dotfiles/neovim/options.lua;
  };
}
