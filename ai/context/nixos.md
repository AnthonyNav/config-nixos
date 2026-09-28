# NixOS workflow

For this fleet, work from current main on a short-lived branch. Format, evaluate
and build affected system and Home Manager outputs before review. Shared changes
cover every affected workstation. Use nix-config build / nix-check without
activation while developing; never activate a feature branch. Deployment from
reviewed, published main is a separate action using nix-update or nix-switch /
nix-home-switch as documented in the configuration repository.

Diagnose the declared configuration, built output and active generation
separately. Use nix log, journalctl and systemctl for evidence. A successful
build does not prove runtime service health, graphics or remote access.
Capabilities describe eligibility; they do not imply a running workload.
