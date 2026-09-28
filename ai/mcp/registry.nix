# Metadata only. No tokens, headers with secret values, or runtime state.
[
  {
    id = "openai-docs";
    owner = "OpenAI";
    source = "https://developers.openai.com/resources/docs-mcp";
    transport = "http";
    url = "https://developers.openai.com/mcp";
    authentication = "none";
    requiredSecrets = [ ];
    harnesses = [
      "codex"
      "claude"
      "kiro"
    ];
    defaultEnabled = false;
    trust = "Public documentation service; queries leave the machine. Treat responses as reference data.";
  }
]
