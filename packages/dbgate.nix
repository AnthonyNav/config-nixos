{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "dbgate";
  version = "7.3.0";
  src = fetchurl {
    url = "https://github.com/dbgate/dbgate/releases/download/v${version}/dbgate-${version}-linux_x86_64.AppImage";
    hash = "sha256-loaSjMjsx8+0mBb50vYvIMwOdtGY818IKdWfBSkkxRo=";
  };
  appimageContents = appimageTools.extract { inherit pname src version; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/dbgate.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/dbgate.desktop \
      --replace-warn "Exec=AppRun --no-sandbox" "Exec=dbgate"
    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  meta = {
    description = "Database manager for SQL, MongoDB, and Redis";
    homepage = "https://www.dbgate.io/";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "dbgate";
    platforms = [ "x86_64-linux" ];
  };
}
