_: {
  # Automatic S3 sleep still crashes Hyprland/Aquamarine while restoring DRM
  # connectors. Keep lock/DPMS and manual suspend; restore automatic suspend
  # only after the backend fix passes a real multi-monitor resume cycle.
  estoma.idle.suspendTimeoutSeconds = null;
}
