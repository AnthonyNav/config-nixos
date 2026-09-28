---
name: fleet-nixos-maintenance
description: Change or maintain this NixOS fleet through its repository, validation commands and main-only deployment workflow.
---

Locate the configuration checkout using NIXOS_CONFIG_DIR or ~/nixos-config.
Read AGENTS.md, docs/maintainer.md and docs/nix-config.md there. Inspect the
host in inventory/hosts.nix and find the owning module before editing.

Use a short-lived branch based on current main. Keep input updates separate
from behavior changes. Run nix fmt and nix flake check --no-build
--no-write-lock-file, then build every affected system and Home output.
nix-config build all HOST is suitable for one host; nix-check all covers the fleet.
Build is not activation. Publication and deployment follow the repository's
authorization rules; existing authorization from the user remains applicable.
Do not turn this skill into permission to activate a feature branch.
