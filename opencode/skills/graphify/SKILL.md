---
name: graphify
description: Use when the user asks to map, audit, trace, or explore a codebase or document collection. Builds or queries a persistent Graphify knowledge graph.
---

# Graphify

Use Graphify to turn a repository or document collection into a queryable
knowledge graph.

## Commands

```sh
graphify .
graphify . --update
graphify query "How does the deployment flow work?"
graphify path "Source node" "Target node"
graphify explain "Node name"
```

## Workflow

1. When `graphify-out/graph.json` exists and the user asks a question, query it
   instead of rebuilding it.
2. For a new graph, inspect corpus size first. If it is large, narrow the
   directory before extraction.
3. Keep generated `graphify-out/` artifacts out of Git unless the user asks to
   retain them.
4. Report only supported facts from the graph and distinguish extracted from
   inferred relationships.
5. For codebases with unsupported file extensions, complement graph output with
   direct inspection; do not claim the graph covers files it skipped.

## Installation

Graphify is intentionally run through `uv`, not committed as a secret-bearing
or mutable project dependency:

```sh
uv tool run --from graphifyy graphify .
```

Use that form when `graphify` is not already available in `PATH`.
