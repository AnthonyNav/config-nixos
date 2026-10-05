{ pkgs }:
pkgs.writeShellApplication {
  name = "tailscale";
  text = ''
    binary=/Applications/Tailscale.app/Contents/MacOS/Tailscale
    [[ -x "$binary" ]] || {
      printf 'Install and sign into the standalone macOS Tailscale app first.\n' >&2
      exit 69
    }
    exec "$binary" "$@"
  '';
}
