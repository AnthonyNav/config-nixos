{
  managedDevicePrefix = "fleet:";
  managedFolderPrefix = "fleet-";
  reconcileInterval = "10m";

  # Denials precede user exclusions and the document allowlist. These files
  # are installed locally on BOTH hosts before registering a folder in the API.
  ignorePatterns = [
    "repos"
    "worktrees"
    ".fleet-*"
    ".git"
    ".stignore*"
    "node_modules"
    ".direnv"
    ".venv"
    "__pycache__"
    "build"
    "dist"
    "coverage"
    ".gradle"
    ".dart_tool"
    "target"
    ".cache"
    ".agents"
    ".codex"
    ".claude"
    ".kiro"
    ".opencode"
    ".orca"
    "orca-state"
    ".aws"
    ".ssh"
    ".gnupg"
    ".docker"
    ".env"
    ".env.*"
    "hosts.yml"
    "*.pem"
    "*.key"
    "id_*"
    "*credentials*"
    "*token*"
    "*secret*"
    "*.sqlite*"
    "*.db"
    "*.db-*"
    "containers"
    "virtual-machines"
  ];
  folders = {
    work = {
      id = "fleet-work";
      label = "Work Workspace Documents";
      relativePath = "Workspace/work";
      migrationFrom = "fleet-shared";
      type = "sendreceive";
      # null = eligible fleet; [] = opt out; ["desktop"] = local-only work data.
      hosts = null;
    };
    personal = {
      id = "fleet-personal";
      label = "Personal Workspace Documents";
      relativePath = "Workspace/personal";
      migrationFrom = "fleet-shared";
      type = "sendreceive";
      hosts = null;
    };
  };
}
