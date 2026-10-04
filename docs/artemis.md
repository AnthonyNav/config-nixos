# Optional Android automation with Artemis

Artemis is an optional testing companion, not a prerequisite for Spec Kit,
Flutter, Codex, Claude or Kiro. Every host keeps it **disabled by default**.
No global testing rules, skills, Android services, ports or agent permissions
are added. OpenCode remains unmanaged. No other project repository is changed.

## Try the CLI without changing a host profile

From reviewed main, explicitly prepare the runtime:

```sh
nix run .#artemis -- prepare
nix run .#artemis -- status
nix run .#artemis -- run --help
```

`prepare` downloads Python dependencies; it does not start tasks, configure
assistants or invoke the upstream `start.sh` installer. Network access is needed
on first preparation. Subsequent CLI/MCP starts never install or update packages.
Missing preparation produces an error instead of a background download.

The launcher exposes only `prepare`, `status`, `run`, `doctor` and stdio `mcp`.
It does not expose upstream global MCP/rules installation or the setup wizard.
Use `run --standalone` for CLI tasks to avoid the upstream automatic web-daemon
path. Use absolute file/APK paths: the working directory is the runtime checkout.

## Optional persistent installation and MCP

To install the launcher on a selected host, add this to its Home Manager module
in a separate reviewed change:

```nix
fleet.ai.artemis.enable = true;
```

That only installs `fleet-artemis`; **it does not connect any assistant**.
Prepare it explicitly, configure provider credentials, and test the CLI before
selecting MCP clients:

```nix
fleet.ai.artemis = {
  enable = true;
  harnesses = [ "codex" "claude" ];
};
```

`kiro` is also accepted; its generated stdio adapter is tested, but native Kiro
login/discovery still needs manual validation. Home Manager reconciles only the
owned `fleet-artemis` entry and preserves unrelated MCPs, permissions and hooks.
No tool is automatically approved. Each selected assistant can start its own
MCP process; only explicit tool calls should dispatch device tasks.

An empty `harnesses` list disconnects Artemis without removing the launcher.
Stop running tasks first using `mobile_manage_task`; disconnecting an MCP client
is not cancellation of an already detached task. To return to the default,
set `enable = false; harnesses = [];` and deploy reviewed main. Existing context,
RTK hooks, skills and normal assistant use remain available. Runtime files are
retained deliberately; no activation hook deletes user data or credentials.

## Reproducibility and runtime ownership

`packages/artemis.nix` pins upstream revision
`371aa6df56880643da57b30da936e9812fb0ec66` and its source hash, plus Nix's Python 3.12,
uv, ADB, scrcpy, FFmpeg and native libraries. OpenCV's shared libraries are scoped
to the child process; the host's PATH and LD_LIBRARY_PATH are not modified.

The Python environment is prepared using upstream `uv.lock` with
`uv sync --frozen --no-dev`, Nix's interpreter and Python downloads disabled.
This is a locked runtime bootstrap, **not an entirely Nix-built/offline Python
closure**. Package availability and build dependencies still affect preparation.
The upstream editable checkout lives outside the store and can be modified by
its owner; such modifications are not configuration managed by this repository.

State is under `${XDG_DATA_HOME:-~/.local/share}/fleet-artemis/`:

- `<runtime-id>/source/`: pinned initial source and `.venv`;
- `<runtime-id>/ready`: successful preparation marker;
- `data/`: upstream runtime data and traces.

A source revision or Python store-path change selects a new runtime ID. Failed
preparation leaves no ready marker; rerun `prepare` after correcting the failure.
Old runtimes remain available for rollback. Never copy credentials into the
source template, Nix options, Git or store-backed files.

Provider keys belong in runtime-only configuration, such as
`${XDG_CONFIG_HOME:-~/.config}/artemis/.env` with mode 0600. Upstream also reads
runtime/workspace `.env` files. Review provider/model settings against your actual
access before a test. An assistant subscription is not provisioned as an Artemis
API credential. Screenshots and task content may be sent to the selected model
provider, so use test accounts and synthetic data.

The launcher sets `ARTEMIS_HELPER_AUTO_INSTALL=false` and
`ARTEMIS_KEEP_DEVICE_AWAKE=false`. Android automation still requires an authorized
test device/emulator and a working hierarchy backend; explicit tasks can mutate
the device. The helper/backend must be provisioned deliberately for a pilot.
It also suppresses desktop notifications and removes ambient webhook/script
notification variables from the child environment. Do not reintroduce them in
Artemis runtime dotenv files unless intentionally wanted.

## Validation boundary

Automated checks cover missing preparation, failed preparation/retry, idempotence,
command arguments, isolated native-library variables and rejection of upstream
installers. MCP adapter tests cover HTTPS and stdio, enable/disable preservation
of personal configuration and no auto-approved tools.

A temporary HOME smoke test prepares the real pinned environment, loads CLI help,
performs MCP initialization and lists its five tools without invoking device tools
or supplying provider credentials. This does not prove Android task accuracy,
provider authentication, model availability or native client runtime discovery.

Before wider use, run three bounded scenarios on a named test device, repeat them,
and record outcomes, false positives, duration and provider usage. Keep normal
unit/integration tests as the regression gate. Other repositories
remain outside this change.

Upstream: [Artemis](https://github.com/google/artemis),
[MCP server](https://github.com/google/artemis/tree/371aa6df56880643da57b30da936e9812fb0ec66/mcp_server).
