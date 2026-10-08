# Uninstallation

Remove the current-user OpenBangla installation:

```bash
bash tools/uninstall.sh
```

The uninstaller removes the OpenBangla GUI, IBus engine, bundled runtime libraries, application data, desktop entry, icons, metadata, input-method registration and fork-specific environment configuration.

It also removes the OpenBangla entry from the user Fcitx5 profile when present.

The source tree is not removed.

To remove the build and staging cache as well:

```bash
bash tools/uninstall.sh --purge-cache
```

The uninstaller does not remove system IBus, Fcitx5, Qt, compilers, or other shared packages.