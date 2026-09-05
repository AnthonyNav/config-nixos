# Keep inherited project/Nix paths ahead of manual global installations.
# Remove stale leading entries as well: a new terminal can inherit the old PATH.
path=("${(@)path:#$HOME/.local/bin}")
path=("${(@)path:#$HOME/.local/share/pnpm}")
path=("${(@)path:#$HOME/.npm-global/bin}")
path+=("$HOME/.local/bin" "$HOME/.local/share/pnpm" "$HOME/.npm-global/bin")
export PATH
