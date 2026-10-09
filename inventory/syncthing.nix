{
  managedDevicePrefix = "fleet:";
  managedFolderPrefix = "fleet-";
  reconcileInterval = "10m";

  # These manually configured roots transported live Git checkouts. Pause only
  # the observed ID/path pairs; retain their data, peers and local preferences.
  legacyFolders = [
    {
      id = "mprez-tcw5e";
      relativePath = "Projects";
      hosts = [
        "desktop"
        "victus"
      ];
    }
    {
      id = "syf74-ywg9t";
      relativePath = "kigo";
      hosts = [
        "desktop"
        "victus"
      ];
    }
  ];

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
    # Signing stores, provisioning profiles and their local password properties
    # stay on each device, including inside shared/docs/assets allowlisted paths.
    # Explicit case folding also protects case-sensitive Linux workspaces.
    "(?i)*.jks"
    "(?i)*.keystore"
    "(?i)*.p12"
    "(?i)*.pfx"
    "(?i)*.mobileprovision"
    "(?i)*.provisionprofile"
    "(?i)key.properties"
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
