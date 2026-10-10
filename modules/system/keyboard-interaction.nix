{ pkgs, ... }:
let
  inputAccess = pkgs.writeTextFile {
    name = "fleet-keyboard-input-access";
    destination = "/lib/udev/rules.d/65-fleet-keyboard-input.rules";
    # Apply before systemd's 73-seat-late ACL helper. Only physical keyboard
    # buses qualify; virtual Lan Mouse and xremap inputs must not be captured.
    text = ''
      SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", SUBSYSTEMS=="usb", TAG+="uaccess"
      SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", SUBSYSTEMS=="serio", TAG+="uaccess"
      SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", SUBSYSTEMS=="i2c", TAG+="uaccess"
      SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", ENV{ID_BUS}=="bluetooth", TAG+="uaccess"
      SUBSYSTEM=="misc", KERNEL=="uinput", TAG+="uaccess", OPTIONS+="static_node=uinput"
    '';
  };
in
{
  # logind grants ACLs to the active seat user. Do not grant the broad input
  # group or run the application-aware remapper as root.
  hardware.uinput.enable = true;
  services.udev.packages = [ inputAccess ];
}
