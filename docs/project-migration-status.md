# Project migration status

Validated locally on Victus on 2026-09-27. These changes span independent
project repositories and are not included in the fleet commit. No project
changes were published, no existing development branch was switched, and no
fleet generation was activated.

Each migrated checkout now contains `nix/flake.nix`, `nix/flake.lock`, `.envrc`,
`docs/nix-development.md` and an ignore rule for `.direnv/`. Use
`nix develop path:./nix` from that checkout. The explicit path source keeps
application files and datasets outside the flake source. The locks are
independent; existing project/workspace pins were reused where available.

| Project | Environment | Executed validation |
| --- | --- | --- |
| FIRA/EDA | Python 3.14.7, uv, native runtime libraries | 44 pytest tests; Jupyter kernel with NumPy, pandas, GeoPandas, rasterio, shapely and pyproj imports and synthetic calculation, without inherited LD_LIBRARY_PATH |
| Estoma frontend | Node 22, Corepack honoring packageManager, Chromium | Production build; 167 Karma tests |
| Estoma services | Temurin 25, Maven, existing workspace clients | 214 users-service unit tests on a temporary copy of current source plus its schema document |
| FEPRO | Existing Python/infra environment, .NET 8, explicit Node 22 | 40 .NET unit tests |
| K-resources/go-utils | Go 1.25.14, gotestsum, mockgen, GCC | Tests for errors, events, geospatial and validators packages |
| Kigo app, txn-lazy-detail worktree | FVM 3.44.0 project SDK, Android Studio JBR, native build tools | SDK version and 15 phone-number normalization tests with --no-pub |

FIRA used a temporary virtual environment, preserving its existing `.venv`.
A temporary direnv project proved entry sets the project libraries and exit
restores both the original PATH and LD_LIBRARY_PATH. No real project's `.envrc`
was automatically allowed.

The first backend test attempt found non-writable existing `target` artifacts.
Permissions and those artifacts were left untouched; validation used a temporary
copy instead. All 214 tests passed once the copy included the schema document
required by the tests. This validates the toolchain, not every backend service
or its database/message-broker integration.

## Remaining gates

- Review/publish each project's environment changes with that project's work;
  existing application changes remain separate and uncommitted by this work.
- Verify Android builds, Linux desktop builds where supported, emulator/device
  access and Gradle cleanup before retiring host Flutter infrastructure.
- Other Kigo worktrees and legacy projects still use their existing environment.
  Do not duplicate a migration across worktrees or claim all consumers are covered.
- The existing CUDA transcription experiment is already flake-based but has
  uncommitted setup and an entry-time pip install. It was not modified or run;
  GPU/audio validation and dependency locking remain separate work.
- Keep global compatibility switches enabled until remaining consumers on each
  host are validated. No global SDK or Jupyter fallback was removed in this slice.
- AI runtime rollout and Desktop service verification remain main-only operational
  work. macOS and distributed builders remain outside the current scope.

## Fleet validation

Formatting, flake evaluation, the project-environments behavior check and all
the six then-current NixOS/Home outputs (including the now-retired ThinkPad)
passed without
activation. The new check covers legacy defaults, selective Go removal, all
SDK switches disabled, native-library opt-out and repeated shell initialization.
