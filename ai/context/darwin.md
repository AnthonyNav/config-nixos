# macOS workflow

Work from reviewed main on a short-lived branch. Put macOS system policy and
native application ownership in nix-darwin, user tools and dotfiles in Home
Manager, and SDK versions in project development environments. Use launchd and
launchctl for services. Xcode, its license and Apple SDKs remain platform-owned.

Use nix-config build / nix-check without activation during development. Darwin
builds require a compatible Mac builder. Linux evaluation does not demonstrate
macOS runtime health. Never activate a feature branch. Deployment uses nix-update
or nix-switch from reviewed, published main, following repository instructions.

Use the agent's native macOS sandbox; do not install Linux Bubblewrap/nsjail or
claim Linux sandbox guarantees on macOS. Keep native Orca/Tailscale applications
under their declared Darwin ownership. Credentials and agent state stay local.

Compare declared configuration, built system and active /run/current-system or
the system profile separately. Use launchctl and macOS logs for runtime evidence.
Capabilities describe eligibility; they do not imply a running workload.
