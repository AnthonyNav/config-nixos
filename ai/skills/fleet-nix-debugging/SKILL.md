---
name: fleet-nix-debugging
description: Diagnose Nix evaluation, builds, activation or systemd failures on this fleet using declared and running state.
---

Identify whether failure occurs at evaluation, realization, activation or
runtime. Record the failing installable, host and relevant commit. Use
nix eval for effective options and nix log for failed derivations; inspect
journalctl -u UNIT and systemctl status UNIT for runtime failures.

Compare the built result with /run/current-system and Home Manager generations.
Do not infer deployment from the checkout branch. Inspect PATH with
zsh -lic 'whence -a COMMAND' when installed tools appear stale.
Prefer a targeted reproduction to updating every flake input. Do not delete
generations, state or caches as a first diagnostic action. Preserve a working
generation and remote recovery access before an authorized activation.
