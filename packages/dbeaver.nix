{ pkgs }:

let
  version = "26.2.1";
in
pkgs.dbeaver-bin.overrideAttrs (_: {
  inherit version;
  src = pkgs.fetchurl {
    url = "https://github.com/dbeaver/dbeaver/releases/download/${version}/dbeaver-ce-${version}-linux-x86_64.tar.gz";
    hash = "sha256-Fte9AehPjNj0bWl2rBJ/olZ47AEJU8m03OQZM68gZ+g=";
  };
})
