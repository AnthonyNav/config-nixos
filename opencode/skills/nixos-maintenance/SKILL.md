---
name: nixos-maintenance
description: Use when changing this NixOS flake, profiles, hosts, inputs, or Home Manager modules. Validates every affected host before activation.
---

# NixOS Maintenance

1. Identify whether the change is shared, host-specific, or desktop-style
   specific before editing.
2. Run `nix fmt` after Nix edits.
3. Run `nix flake check --no-build --no-write-lock-file` before switching.
4. For host-specific changes, build the corresponding NixOS and Home Manager
   activation outputs before activation.
5. Test NVIDIA behavior on both `victus` and `desktop`; PRIME and direct NVIDIA
   are different paths.
6. Do not activate a configuration solely to test evaluation. Use
   `nix-switch` only after validation succeeds.

Read `docs/maintainer.md` for ownership boundaries and
`docs/nixos-development-guide.md` for the validation commands.
