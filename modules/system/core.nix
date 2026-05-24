{ pkgs, username, ... }:

{
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "es_MX.UTF-8";
  console.keyMap = "us";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  programs.zsh.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      fastfetch
      neovim
    ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
