{
  codex,
  makeWrapper,
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
    wrapProgram $out/bin/codex --add-flags "-c features.daemon_auto_start=false"
  '';
}
