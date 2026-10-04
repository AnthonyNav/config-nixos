{
  codex,
  makeWrapper,
  openssh,
  symlinkJoin,
}:

# The Nix build lacks codex-package.json, so Codex cannot install the shared
# app-server daemon it starts by default since 0.159; run it embedded instead.
symlinkJoin {
  pname = "codex";
  inherit (codex) version meta passthru;
  paths = [ codex ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    # Keep the inherited SSH identity command, including the personal-context
    # wrapper, while preventing Git/SSH prompts from competing with the TUI.
    wrapProgram $out/bin/codex \
      --add-flags "-c features.daemon_auto_start=false" \
      --set GIT_TERMINAL_PROMPT 0 \
      --run 'export GIT_SSH_COMMAND="''${GIT_SSH_COMMAND:-${openssh}/bin/ssh} -o BatchMode=yes"'
  '';
}
