---
name: fleet-change-review
description: Review a change to this NixOS fleet for host regressions, secret exposure and deployment readiness.
---

Compare the entire branch diff with its actual base. Trace affected modules
through inventory, NixOS and Home Manager consumers. Check effective options,
not just declarations: module priority and list ordering can change behavior.

Verify all affected host/Home builds, SSH/firewall boundaries, resource policy,
GPU-specific behavior and main-only activation guards. Secrets must remain
runtime-owned. A new server must not inherit desktop profiles or input peers.
Distinguish evaluation/build evidence from untested graphics or service health.
Report concrete blockers with file references; do not invent runtime success
or treat stylistic preferences as merge blockers.
