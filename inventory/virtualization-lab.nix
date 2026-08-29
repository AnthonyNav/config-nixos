{
  uri = "qemu:///system";

  storage = {
    pool = "virtualization-lab";
    path = "/var/lib/libvirt/images/virtualization-lab";
  };

  network = {
    name = "lab-nat";
    bridge = "virbr-lab";
    gateway = "192.168.252.1";
    netmask = "255.255.255.0";
    dhcpStart = "192.168.252.100";
    dhcpEnd = "192.168.252.200";
  };

  profiles.almalinux = {
    domain = "uni-almalinux";
    guestUser = "student";
    guestIp = "192.168.252.10";
    guestMac = "52:54:00:61:6c:6d";

    resources = {
      vcpus = 2;
      memoryMiB = 4096;
      diskGiB = 40;
    };

    image = {
      version = "9.8";
      build = "20260810";
      filename = "AlmaLinux-9-GenericCloud-9.8-20260810.x86_64.qcow2";
      url = "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-9.8-20260810.x86_64.qcow2";
      sha256 = "5cf9788088b3079540ea2cc160a52d9daba6fa973fad94e75f3b8e6516c295db";
    };
  };
}
