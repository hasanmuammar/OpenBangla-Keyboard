# Shanti Flatpak filesystem-permission probe

This is a disposable test application, not the Shanti manager and not a production manifest. It tests whether Flatpak can expose four narrowly scoped, Shanti-specific test roots:

- `~/.local/shanti-flatpak-permission-probe`
- `$HOST_XDG_DATA_HOME/shanti-flatpak-permission-probe` (or the default host data directory)
- `$HOST_XDG_CONFIG_HOME/shanti-flatpak-permission-probe` (or the default host config directory)
- `$HOST_XDG_CACHE_HOME/shanti-flatpak-permission-probe` (or the default host cache directory)

The probe creates a temporary child directory and marker file inside each root, reads the marker back, then removes the marker and temporary child. It never writes to Shanti's actual install, resource, IBus, Fcitx5, or configuration paths. Flatpak may pre-create the permission roots before launching the app, so empty `shanti-flatpak-permission-probe` directories can remain after a run.

The manifest deliberately grants only those test paths. It has no network, host-command, system-bus, home-wide, or host-wide permission. Do not copy its test grants into the production manifest as a substitute for reviewing the real install paths.

## Build and run

Install the matching Freedesktop SDK/runtime 26.08 from the configured Flatpak remote if not already installed. Then, from the repository root:

```sh
flatpak-builder --user --install --force-clean /tmp/shanti-fs-probe-build tools/flatpak/permission-probe.yml
flatpak run io.github.hasanmuammar.ShantiFilesystemProbe
```

The probe prints the sandbox XDG data path, the resolved host XDG paths, and one PASS/FAIL result per test root. A passing result establishes only that these disposable path grants can create directories and read/write a marker in this environment. It does not establish that the eventual production paths, IBus/Fcitx5 registration, module ABI, host typing, or daemon refresh will work.

## Custom XDG test

For a second test, launch Flatpak with the host's XDG variables pointing to an empty scratch directory. This verifies that the `xdg-data`, `xdg-config`, and `xdg-cache` permission aliases follow the host XDG roots rather than writing into the app-private Flatpak directories. Keep the scratch directory outside the Shanti install and registration paths, and inspect the reported paths before proceeding. Use a disposable test account where possible.

## Current limitation

The automated test script does not invoke `flatpak-builder` itself. The build and real-sandbox run must be performed on a machine with Flatpak/flatpak-builder and the required runtime/SDK installed; do not mark the integration acceptance checks complete from a source review alone.
