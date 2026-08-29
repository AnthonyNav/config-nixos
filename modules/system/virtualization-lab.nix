{
  hostFeatures,
  lib,
  pkgs,
  username,
  ...
}:

let
  virtualizationLab = hostFeatures.virtualizationLab or { };
  enabled = virtualizationLab.enable or false;
in

{
  config = lib.mkIf enabled {
    programs.virt-manager.enable = true;

    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      qemu.package = pkgs.qemu_kvm;
    };

    # Keep guest access explicit. The host does not provision shared folders or
    # USB redirection; those can be added later per use case if they are needed.
    virtualisation.spiceUSBRedirection.enable = false;

    users.users.${username}.extraGroups = lib.mkAfter [ "libvirtd" ];

    # dnsmasq backs libvirt's default NAT network; libvirt provides virsh and
    # related administration tools alongside the graphical virt-manager UI.
    environment.systemPackages = with pkgs; [
      dnsmasq
      libvirt
    ];
  };
}
