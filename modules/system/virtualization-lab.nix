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
  policy = import ../../inventory/virtualization-lab.nix;
  alma = policy.profiles.almalinux;

  lab = pkgs.writeShellApplication {
    name = "lab";
    runtimeInputs = with pkgs; [
      cloud-utils
      coreutils
      curl
      gawk
      gnugrep
      jq
      libvirt
      openssh
      qemu_kvm
      virt-manager
    ];
    text = ''
      export LAB_URI=${lib.escapeShellArg policy.uri}
      export LAB_POOL_NAME=${lib.escapeShellArg policy.storage.pool}
      export LAB_POOL_PATH=${lib.escapeShellArg policy.storage.path}
      export LAB_NETWORK_NAME=${lib.escapeShellArg policy.network.name}
      export LAB_NETWORK_BRIDGE=${lib.escapeShellArg policy.network.bridge}
      export LAB_NETWORK_GATEWAY=${lib.escapeShellArg policy.network.gateway}
      export LAB_NETWORK_NETMASK=${lib.escapeShellArg policy.network.netmask}
      export LAB_NETWORK_DHCP_START=${lib.escapeShellArg policy.network.dhcpStart}
      export LAB_NETWORK_DHCP_END=${lib.escapeShellArg policy.network.dhcpEnd}
      export LAB_DOMAIN=${lib.escapeShellArg alma.domain}
      export LAB_GUEST_USER=${lib.escapeShellArg alma.guestUser}
      export LAB_GUEST_IP=${lib.escapeShellArg alma.guestIp}
      export LAB_GUEST_MAC=${lib.escapeShellArg alma.guestMac}
      export LAB_VCPUS=${toString alma.resources.vcpus}
      export LAB_MEMORY_MIB=${toString alma.resources.memoryMiB}
      export LAB_DISK_GIB=${toString alma.resources.diskGiB}
      export LAB_IMAGE_VERSION=${lib.escapeShellArg alma.image.version}
      export LAB_IMAGE_BUILD=${lib.escapeShellArg alma.image.build}
      export LAB_IMAGE_FILENAME=${lib.escapeShellArg alma.image.filename}
      export LAB_IMAGE_URL=${lib.escapeShellArg alma.image.url}
      export LAB_IMAGE_SHA256=${lib.escapeShellArg alma.image.sha256}
      export LAB_BASE_VOLUME=${lib.escapeShellArg "base-${alma.image.filename}"}
      export LAB_GUEST_VOLUME=${lib.escapeShellArg "${alma.domain}.qcow2"}
      export LAB_SEED_VOLUME=${lib.escapeShellArg "${alma.domain}-seed.iso"}
      ${builtins.readFile ../../scripts/lab.sh}
    '';
  };
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

    # The dedicated lab bridge is not trusted wholesale. Guests may reach host
    # DHCP/DNS services required by libvirt NAT, while ordinary inbound traffic
    # from the VM remains subject to the host firewall.
    networking.firewall.interfaces.${policy.network.bridge} = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [
        53
        67
      ];
    };
    networking.networkmanager.unmanaged = lib.mkAfter [
      "interface-name:${policy.network.bridge}"
    ];

    environment.systemPackages = with pkgs; [
      dnsmasq
      lab
      libvirt
    ];
  };
}
