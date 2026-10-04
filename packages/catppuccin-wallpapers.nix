{ fetchurl, linkFarm }:
let
  revision = "3f9a052e0ff14bd680742f1927a6e8dbf1e030a8";
  image = name: hash: {
    inherit name;
    path = fetchurl {
      url = "https://raw.githubusercontent.com/yukazakiri/themed-wallpapers/${revision}/catppuccin/${name}";
      inherit hash;
    };
  };
in
linkFarm "fleet-catppuccin-wallpapers" [
  (image "wallhaven-1qdmj3.jpg" "sha256-AMZlpGHEt2TL6pcdTnoiC56JA/ZZFskpxjuP4Bun7fI=")
  (image "wallhaven-1qxwq1.jpg" "sha256-qJxCq40BEQB6rlnTMFV55FJjPfNAVqWRWNBwPaobAd4=")
  (image "wallhaven-21996g.jpg" "sha256-6IUIun07lSTKJtScUl0I6jYmOHczEUWBCm93v24nyb4=")
]
