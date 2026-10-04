{
  hostFeatures,
  lib,
  pkgs,
  username,
  ...
}:
{
  # Local desktop VMs only. No guest images, bridges or server provisioning.
  config = lib.mkIf (hostFeatures.virtualization.enable or false) {
    programs.virt-manager.enable = true;
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      qemu.package = pkgs.qemu_kvm;
    };
    virtualisation.spiceUSBRedirection.enable = false;
    users.users.${username}.extraGroups = lib.mkAfter [ "libvirtd" ];
  };
}
