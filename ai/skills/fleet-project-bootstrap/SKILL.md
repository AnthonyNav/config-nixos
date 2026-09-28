---
name: fleet-project-bootstrap
description: Set up a project-local Nix development environment on this fleet when the user requests project bootstrapping or SDK isolation.
---

Inspect the project's lockfiles, CI and existing flake/.envrc before selecting
toolchain versions. Reuse an existing devShell when available. Put project-only
SDKs in that project's flake and pin inputs; keep host drivers/services in the
fleet repository. Do not move working global tools until their consumers have
working replacements.

Add use flake to .envrc only within the requested project. direnv allow executes
the project's environment: inspect it first and respect the requested scope.
Verify tool versions and the project's actual build/test command inside
nix develop. Flutter/Android requires checking Java, SDK location, emulator/device
access and cleanup behavior, not merely finding flutter on PATH.
