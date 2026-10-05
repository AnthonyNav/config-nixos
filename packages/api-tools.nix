{
  pkgs,
  lib ? pkgs.lib,
}:
let
  posting = pkgs.posting.overridePythonAttrs (old: {
    version = "2.11.0";
    src = pkgs.fetchFromGitHub {
      owner = "darrenburns";
      repo = "posting";
      tag = "2.11.0";
      hash = "sha256-2mLcHBynA5QmA70XSiuoJz7xpzMFAIY1frqNclU7HHs=";
    };
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postFixup = (old.postFixup or "") + ''
      # A deliberate user YAML setting can opt in. Otherwise history stays off.
      wrapProgram "$out/bin/posting" --set-default POSTING_HISTORY__ENABLED false
    '';
  });
  schemaDirectory = "${pkgs.gtk3}/share/gsettings-schemas/gtk+3-${pkgs.gtk3.version}/glib-2.0/schemas";
  postman = pkgs.postman.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      test -f ${lib.escapeShellArg "${schemaDirectory}/gschemas.compiled"}
      wrapProgram "$out/bin/postman" \
        --set GSETTINGS_SCHEMA_DIR ${lib.escapeShellArg schemaDirectory} \
        --unset NIXOS_OZONE_WL --unset ELECTRON_OZONE_PLATFORM_HINT
      substituteInPlace "$out/share/applications/postman.desktop" \
        --replace-fail 'Exec=postman ' "Exec=$out/bin/postman "
    '';
  });
in
{
  inherit posting postman schemaDirectory;
  bruno = import ./bruno.nix { inherit pkgs lib; };
}
