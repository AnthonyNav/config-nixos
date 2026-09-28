---
name: fleet-mcp-management
description: Register or enable MCP services in the fleet AI catalog while preserving user-owned connections and credentials.
---

Read ai/mcp/registry.nix, ai/mcp/policy.nix and docs/ai-environment.md in the
configuration repository. Register metadata separately from explicit host/harness
enablement. Verify the upstream transport, owner and authentication contract.
Use unique IDs; fleet-managed connections use the fleet- prefix.

This implementation only enables credential-free HTTPS services. Authenticated
entries may be cataloged, but require a separately reviewed runtime credential
mechanism before enablement. Never copy tokens, OAuth state or local settings
into Nix. Do not connect to a service just to validate generated syntax.
Use ai-doctor to inspect local integration state. It does not verify external
authentication or grant authority to call every registered service.
