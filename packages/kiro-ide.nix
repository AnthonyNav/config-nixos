{
  lib,
  buildVscode,
  fetchurl,
  libcap,
}:

(buildVscode {
  pname = "kiro";
  version = "1.1.70";
  vscodeVersion = "1.131.0";

  src = fetchurl {
    url = "https://prod.download.desktop.kiro.dev/releases/stable/linux-x64/signed/1.1.70/tar/kiro-ide-1.1.70-stable-linux-x64.tar.gz";
    hash = "sha256-ev50WJtx9MnPFx4uKh9wEroFyuFYTxNgcumxzKGEf1Q=";
  };

  commandLineArgs = "";
  executableName = "kiro";
  longName = "Kiro";
  shortName = "kiro";
  libraryName = "kiro";
  iconName = "kiro";
  sourceRoot = "Kiro";
  patchVSCodePath = true;
  tests = { };
  updateScript = null;

  meta = {
    description = "IDE for agentic AI workflows based on VS Code";
    homepage = "https://kiro.dev";
    license = lib.licenses.amazonsl;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "kiro";
    platforms = [ "x86_64-linux" ];
  };
}).overrideAttrs
  (oldAttrs: {
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ libcap ];
  })
