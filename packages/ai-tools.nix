{ pkgs, llmAgents }:

llmAgents
// {
  codex = pkgs.callPackage ./codex.nix { inherit (llmAgents) codex; };
}
