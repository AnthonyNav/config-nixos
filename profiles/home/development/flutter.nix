{ pkgs, ... }:

{
  programs.zsh.shellAliases.flutter-stop = ''(cd android && JAVA_HOME="${pkgs.android-studio.unwrapped}/jbr" ./gradlew --stop)'';
  home.packages = with pkgs; [
    android-studio
    flutter
    fvm
    android-tools
    clang
    cmake
    ninja
    pkg-config
  ];
}
