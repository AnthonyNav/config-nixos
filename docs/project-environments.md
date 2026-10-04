# Project environment migration

The fleet supplies direnv/nix-direnv, editors, AI clients, Git, containers and
host drivers. A project's own flake and lock select its SDK versions. Existing
projects must be tested before removing their global fallback. This migration
is not complete merely because a shell evaluates.

## Fleet compatibility switches

After validating all consumers on a host, set these Home Manager options in
an explicit module referenced by `homeModules` in the inventory, one language
at a time:

```nix
fleet.development = {
  globalToolchains = {
    node = false;
    go = false;
    c = false;
    python = false;
  };
  legacyJupyterLibraries = false;
};
```

Global SDK switches remain true in the development profile. The Jupyter library
option defaults to false and is explicitly enabled only by the data-science
profile to preserve current projects. The Go switch also controls
`gotestsum` and `mockgen`. These switches only remove packages contributed by
`development/web-backend.nix`; an IDE, Flutter, another profile or manual
installation may still expose an interpreter/compiler. `uv` remains available
for provisioning project environments. Android Studio, Flutter, FVM, Android
SDK tools, Desktop's .NET and data tools are unchanged.

Check resolution with `type -a node go gcc python python3 flutter` in a fresh
terminal after an authorized deployment. Do not infer removal from package
names alone. Existing shells retain old PATH and library variables.

Disabling `legacyJupyterLibraries` stops new Zsh shells adding GCC runtime,
zlib and expat to `LD_LIBRARY_PATH`. It does not erase an inherited variable
or affect the separate Blender GPU launcher. Start a fresh login session to
verify the resulting environment. Restore a switch to `true` and deploy reviewed
main to restore the compatibility contribution.

## Per-project procedure

1. Inspect the project's existing flake, lockfiles, CI and tool version files.
   Reuse its current environment rather than replacing it with a generic one.
2. Add only the SDKs needed by that project. Keep `flake.lock` in its repository;
   do not make projects follow this fleet's lock.
3. Use `use flake` in `.envrc`, preserving any existing project setup. Review
   the file before `direnv allow`; it executes code. Ignore `.direnv/` and local
   virtual environments, and keep credentials out of both Git and Nix outputs.
4. Verify actual builds/tests using `nix develop --command ...`, with the global
   workaround absent. Record SDK versions and results in the project's PR.
5. In an interactive shell, compare PATH and library variables before entry,
   inside the project and after exit. Leaving restores the prior environment;
   a legacy global SDK can remain visible until its fleet switch is disabled.
6. Remove a host fallback only after every affected project has a replacement.

## Python/data projects with uv

For a project already owning `pyproject.toml` and `uv.lock`, a starting point is:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.python313 pkgs.uv ];
        UV_PYTHON = "${pkgs.python313}/bin/python3";
        UV_PYTHON_DOWNLOADS = "never";
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
          pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.expat
        ];
      };
    };
}
```

Choose Python against the project's declared constraints and locked packages;
3.13 above is an example, not fleet policy. Add native libraries only as the
project requires. Then generate/review its Nix lock and test, for example:

```sh
env -u LD_LIBRARY_PATH nix develop --command uv sync --locked
env -u LD_LIBRARY_PATH nix develop --command uv run --locked pytest
```

Also test native imports and a representative notebook/kernel using synthetic
or explicitly authorized data. A passing Python import does not prove Jupyter
or geospatial/GPU workloads work. Do not automatically activate `.venv` or run
package installs in `shellHook`; keep dependency changes explicit.

## Flutter and Android

Keep the current host setup until a project migration proves its replacement.
Read `.fvmrc`, Gradle wrapper and Android plugin versions before selecting Java
or Flutter. If FVM owns the project's Flutter version, use `fvm flutter` and
configure the IDE's SDK path accordingly. Do not add a second project Flutter
installation merely to match a template.

Validate Java/Gradle compatibility, Android SDK discovery, `flutter doctor`,
an Android build, Linux desktop build where supported, emulator/device access,
and stopping Gradle after use. Host drivers, virtualization and device permissions
stay in the fleet. SDK licenses and credentials remain local.

## Current completion boundary

The fleet now allows retiring the web/backend SDKs separately and opting out
of global Jupyter library injection. The selected development/data-science profiles preserve both current workstations.
Six local project checkouts now have independent environments; see the
[validation record](project-migration-status.md) for exact coverage and remaining
gates. Their changes belong to their own repositories. No global SDK fallback
has been removed; remaining consumers must pass before changing host switches.

Reusable templates remain a separate future repository, as specified in the
[plan](project-darwin-plan.md). macOS and distributed builders remain outside the current workstation scope. Desktop service rollout and AI runtime checks require a separate
main-only deployment; these build-time controls do not perform it.

## References

- [nix-direnv flake integration](https://github.com/nix-community/nix-direnv#flakes-support)
- [uv Python version selection](https://docs.astral.sh/uv/concepts/python-versions/)
