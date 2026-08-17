{
  hostFeatures,
  lib,
  pkgs,
  username,
  ...
}:

let
  connectivity = hostFeatures.connectivity or { };
  tailscaleEnabled = connectivity.tailscale or false;
  sshEnabled = connectivity.ssh or false;
  syncthingEnabled = connectivity.syncthing or false;
in
{
  imports = [ ./pritunl.nix ];

  assertions = [
    {
      assertion = !sshEnabled || tailscaleEnabled;
      message = "connectivity.ssh requires connectivity.tailscale because SSH is exposed only on tailscale0.";
    }
    {
      assertion = !syncthingEnabled || tailscaleEnabled;
      message = "connectivity.syncthing requires connectivity.tailscale because Syncthing is exposed only on tailscale0.";
    }
  ];

  networking.networkmanager.enable = true;
  networking.firewall.interfaces.tailscale0 = lib.mkIf tailscaleEnabled {
    allowedTCPPorts = lib.optionals sshEnabled [ 22 ] ++ lib.optionals syncthingEnabled [ 22000 ];
    allowedUDPPorts = lib.optionals syncthingEnabled [
      22000
      21027
    ];
  };

  time.timeZone = "America/Mexico_City";

  # UI en inglés; formatos regionales (fecha/moneda/unidades) en estilo MX.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "es_MX.UTF-8";
    LC_MONETARY = "es_MX.UTF-8";
    LC_MEASUREMENT = "es_MX.UTF-8";
    LC_PAPER = "es_MX.UTF-8";
  };
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "es_MX.UTF-8/UTF-8"
    "C.UTF-8/UTF-8"
  ];

  # La consola hereda el layout xkb definido en display-manager.nix (us,latam).
  # console.keyMap se elimina para que no entre en conflicto con useXkbConfig.

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    substituters = lib.mkAfter [
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;

  programs.zsh = {
    enable = true;
    # Home Manager inicializa completions una sola vez despues de deduplicar
    # las rutas equivalentes que NIX_PROFILES agrega a fpath.
    enableGlobalCompInit = false;
    # Starship define el prompt del usuario; evita preparar primero el de SUSE.
    promptInit = "";
  };
  programs.ssh.startAgent = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "docker"
      "kvm"
    ];
    packages = with pkgs; [
      fastfetch
      neovim
    ];
    # Solo se versiona la llave pública; la llave privada vive fuera del repo.
    # El comentario de la llave no contiene correo personal para que el repo
    # pueda publicarse sin añadir PII innecesaria.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSZBAoRb/gxevgsIFbtcg/hPx+gvv0tfj25KtubL0xd anthony@config-nixos"
    ];
  };

  # sshd puede escuchar en el host, pero el firewall no abre 22 globalmente:
  # solo tailscale0 lo acepta. Además se deshabilitan contraseña, keyboard-
  # interactive y login de root en los hosts instalados.
  services.openssh = lib.mkIf sshEnabled {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.tailscale.enable = tailscaleEnabled;

  services.syncthing = lib.mkIf syncthingEnabled {
    enable = true;
    user = username;
    group = "users";
    dataDir = "/home/${username}";
    configDir = "/home/${username}/.config/syncthing";
    openDefaultPorts = false;
  };

  hardware.bluetooth.enable = true;
  services.power-profiles-daemon.enable = true;
  virtualisation.docker.enable = true;

  # Audio (PipeWire) — declarado explícitamente para que sea reproducible
  # en cualquier host nuevo (thinkpad/desktop). Ya corre en runtime.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Rendimiento y vida útil del SSD
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  services.fstrim.enable = true;

  # Actualizaciones de firmware/BIOS vía LVFS (fwupdmgr update)
  services.fwupd.enable = true;

  environment.systemPackages = with pkgs; [
    google-chrome
    nh
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  environment.variables = {
    FLAKE = "/home/${username}/nixos-config";
  };

  environment.sessionVariables = {
    FLAKE = "/home/${username}/nixos-config";
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
