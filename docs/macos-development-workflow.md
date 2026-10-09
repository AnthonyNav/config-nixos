# Daily macOS development workflow

Use this guide after the [Mac onboarding runbook](macos-onboarding.md).
It describes how to prepare and validate a workspace; it does not certify
that any application, remote peer or database is currently running. Keep
project fixes and SDK migrations in their own repositories.

## Ownership and project entry

| Layer | Owns |
| --- | --- |
| nix-darwin | System policy, declared native apps, the Colima installation and platform service policy |
| Home Manager | Shared CLI tools, shell/editor configuration, identity adapters and user LaunchAgents |
| Project | SDK versions, dependency locks, `.envrc`, build tasks and required external services |
| Local platform state | Xcode and Apple SDKs, Android SDK packages/licenses/AVDs, VPN logins, credentials and signing material |

Start in the workspace's canonical `~/Workspace/work` or `~/Workspace/personal`
root. Run `fleet-info --json` and `workspace-context status`; read the resolved
`HANDOFF.md` and repository instructions, and inspect the current branch and
working tree. External Git worktrees inherit their primary repository's identity.
One explicit account scope applies to each process/session; these adapters do
not isolate arbitrary same-user programs, ports, databases or containers.

Inspect existing `flake.nix`, `flake.lock`, `.envrc`, CI and version files before
choosing tools. The [project environment procedure](project-environments.md)
includes Linux and Apple Silicon examples. Publish reviewed project declarations
in the project repository; a shared machine-local `.toolchains` directory alone
cannot reconstruct a checkout on another host. Keep SDKs project-selected,
rather than upgrading every application by changing the fleet's global PATH.

Review `.envrc` and every script it executes before `direnv allow`, including
after a change. Enter with direnv or `nix develop`; verify executable versions
inside the shell and after leaving it. Ignore `.direnv/`, dependency caches and
virtual environments. Package installation must be an explicit project action,
not an automatic `shellHook` side effect.

For tools that clone private dependencies into caches outside the workspace,
scope the complete process, for example:

```sh
workspace-context exec work -- nix develop --command pnpm install --frozen-lockfile
workspace-context exec work -- nix develop --command fvm flutter pub get
```

Use the owning project's package manager and lockfile; these examples are not
universal bootstrap commands. Stop the process before changing accounts.

## Flutter, Java and platform SDKs

If FVM owns Flutter, commit the selected `.fvmrc`, ignore generated `.fvm/`, and
use `fvm flutter` for commands. Point VS Code's `dart.flutterSdkPath` and Android
Studio's project Flutter SDK to `.fvm/flutter_sdk`, rather than an absolute
machine cache path. Restore that link using the project's pinned version if
missing. FVM can also run dependency installation when selecting an SDK; review
its settings before bootstrap. See [FVM configuration](https://fvm.app/documentation/getting-started/configuration).

Select Java against the project's Gradle wrapper and Android Gradle Plugin.
Java 17 runs Gradle 8.14.x; Java 25 requires Gradle 9.1 or later, so a newer
Android Studio JBR is not automatically a valid replacement for that project.
Check the [Gradle compatibility matrix](https://docs.gradle.org/current/userguide/compatibility.html)
and the plugin's own requirements before changing either version.
A project requiring Java 17 can select `pkgs.jdk17` in its devShell; verify the
resulting `JAVA_HOME` rather than committing a machine's absolute store path.

There are three independent Java selectors to inspect: the project shell's
`JAVA_HOME`, Flutter's explicit JDK configuration, and Android Studio's Gradle
JDK setting. `java -version` alone does not prove Flutter or the IDE uses it.
The local Flutter settings may retain a Java 17 override in
`~/.config/flutter/settings`; inspect the selected JDK without exposing other
local settings, and verify its path still exists after a generation change.

From the project environment, inspect:

```sh
java -version
fvm flutter config --list
fvm flutter doctor -v
(cd android && ./gradlew --version)
```

Flutter can prefer its configured JDK or Android Studio over `JAVA_HOME`.
If an explicit selection is needed, `fvm flutter config --jdk-dir "$JAVA_HOME"`
sets persistent user configuration for Flutter, affecting other projects too;
use it only with the selected project JDK and recheck other consumers. Keep
machine-specific Nix store/JDK paths out of committed project files. Configure
the IDE's Gradle JDK to the same compatible runtime. See
[Flutter's Java selection guidance](https://docs.flutter.dev/release/breaking-changes/android-java-gradle-migration-guide).

After Android builds, run `(cd android && ./gradlew --stop)` with that compatible
JDK once other builds using the wrapper version have finished. Stopping Gradle
can affect other projects using the same Gradle version. The fleet's Linux
`flutter-stop` alias must not be assumed to exist or select Java correctly on Mac.

Xcode installation, license acceptance, the selected developer directory and
simulator runtimes remain Apple platform state. Check `xcode-select -p`,
`xcodebuild -version` and `xcrun simctl list devices available`. Android Studio
owns the mutable Android SDK, licenses and emulator images; check the SDK path
reported by Flutter, `adb devices -l` and the project's required API levels.
Nix evaluation does not install Apple SDKs or accept Android licenses.

Validate an Android debug build and an iOS simulator build in the actual
application branch, followed by its representative runtime flows. Plugins can
require separate ARM64, UIScene, permissions or native dependency changes;
successful startup does not establish camera, payments, BLE or authentication
coverage. Those fixes need application PRs; do not copy experimental patches
from another workspace as fleet policy.

## Private inputs and account access

Git brings code; Syncthing brings deliberately shared documents/assets.
Neither should distribute `.env`, signing keystores, `.p12` certificates,
provisioning profiles, private npm configuration or mutable agent/database state.
Restore authorized private inputs through the approved secret channel into
local, ignored paths, with restrictive permissions. Do not place their contents
in Nix files, derivation arguments, `/nix/store`, logs or `HANDOFF.md`.

Managed signing exclusions prevent subsequent synchronization after deployment;
they do not remove copies previously synchronized. If such copies are found,
review them locally on every affected peer, preserve required private originals
outside shared paths, and agree on manual cleanup, version-history handling and
credential replacement when warranted. This policy does not establish whether
any private material was previously shared, and activation performs no deletion.

List required filenames and their provisioning procedure in the project without
secret values. Review ignore rules before restoring them, and verify they are
not tracked. A debug build can still require signing files if Gradle loads them
unconditionally; check that project's build scripts before treating release
signing as optional. Each checkout needs its own correct local inputs.

Private npm packages require access to the package and the correct registry
under the owning account. Confirm that access before dependency installation;
do not solve `401`/`404` by embedding a token in a lockfile, URL or shared shell.
AWS tooling availability is separate from login: use `aws-profile-setup work`
or `personal`, then `aws-login` and `aws-whoami` for that context when needed.
Credentials/caches stay local; IAM must enforce the intended read-only policy.
See [workspace identities](workspace-workflow.md#accounts).

## Containers, databases and private networking

Docker/Compose clients do not provide a running Linux engine. Colima is the
Mac's on-demand runtime; check `colima status`, `docker context show` and
`docker info` before a container-dependent task. Start it deliberately when
needed, for example `colima start --cpu 2 --memory 4` as an initial budget on
a 16 GiB host, then adjust for measured workload needs. Stop owned workloads
and `colima stop` after use; coordinate shared containers before stopping them.
Avoid simultaneously running unnecessary VMs, emulators and build daemons.
The [Colima usage guide](https://github.com/abiosoft/colima#usage) documents its
runtime configuration and lifecycle.

DbGate/usql and MCPs are database clients, not PostgreSQL/MySQL/Redis servers.
Use the project's Compose/service declarations or its authorized remote
database. Keep connection state local, use the intended least-privilege account
and validate TLS according to the database's deployment policy. Check both
health and the application's actual connection without logging credentials.
On Apple Silicon, match image architecture to binaries compiled inside it;
an AMD64 build or test needs an explicit compatible platform/emulation choice.
See [Docker multi-platform builds](https://docs.docker.com/build/building/multi-platform/).

Tailscale's native application and Pritunl's native client have separate login
and connection state. Inspect `tailscale status` and Pritunl, then test the
required host, DNS name and service port. If both VPNs are needed, compare route
and DNS behavior before/after each connection; overlapping routes, DNS policy
or an exit node can conflict. See [Tailscale's other-VPN guidance](https://tailscale.com/docs/reference/faq/other-vpns).
Do not install a second Tailscale daemon to repair native app connectivity.

Use Syncthing's peer/folder status and a harmless document transfer to establish
cross-host synchronization. An idle folder with zero pending files while its
peers are disconnected is not proof that it matches the Victus. Runtime
connectivity is separate from fleet eligibility and a successful Nix build.

## Receiving code and validating readiness

`workspace-sync` is opt-in, starts with an empty registry and receives published
Git commits only. Register dedicated receiving copies under their owning
account; keep active agent worktrees unregistered. Hold a receiving checkout
before opening it for edits, including unsaved GUI buffers. Review branch/SHA
and the handoff before resuming on another machine. See
[automatic Git receivers](workspace-workflow.md#automatic-git-receivers).

After a project migration, record the tested commit, host, SDK versions and
these results in its handoff/PR without secrets:

- A fresh terminal and the IDE agree on project SDKs and account context.
- Locked dependency installation succeeds under that account.
- Required local environment/signing files exist and remain untracked/private.
- Required containers or remote services are reachable; unrelated services
  remain under their owners' control.
- Representative tests, Android/iOS builds and runtime flows succeed on the
  platforms the project supports; failures and untested flows are recorded.
- Leaving the shell restores its prior environment; finished owned workloads
  and Gradle daemons are stopped when appropriate.

Fleet changes still follow [the maintainer workflow](maintainer.md): build and
validate locally, review/publish a PR, and activate only reviewed published
`main`. Neither a project bootstrap nor automatic Git receipt deploys Nix.
