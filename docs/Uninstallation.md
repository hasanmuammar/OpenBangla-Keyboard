# Uninstallation

The portable installer installs OpenBangla Keyboard for the current user. No root privileges are required for removal.

## Remove OpenBangla

From the OpenBangla Keyboard source tree:

```bash
bash tools/uninstall.sh
```

The script asks for confirmation and removes the current-user installation.

It removes:

- `~/.local/bin/openbangla-gui`
- `~/.local/libexec/ibus-engine-openbangla`
- `~/.local/lib/openbangla`
- OpenBangla application data, desktop entry, icons and metadata under `~/.local/share`
- the user-local IBus component
- the OpenBangla IBus environment configuration
- OpenBangla entries added to the GNOME IBus input-source configuration
- OpenBangla entries in the user Fcitx5 profile, when present

The script does not remove the OpenBangla source tree.

## Remove the build cache too

The installer keeps its build and staging data under the XDG cache directory. To remove that cache at the same time:

```bash
bash tools/uninstall.sh --purge-cache
```

This removes:

```text
~/.cache/openbangla-keyboard/
```

or the corresponding `XDG_CACHE_HOME` location.

## Reinstalling later

The uninstaller does not remove the source tree, so the repository can be used again directly:

```bash
bash tools/install.sh
```

The installer recreates the required user-local files and registers the selected input-method backend again.

## Notes

The uninstaller only removes paths and configuration entries belonging to OpenBangla Keyboard. It does not remove system IBus, Fcitx5, Qt, or other shared packages.

IBus may print warnings about unrelated engines while its component cache is rebuilt. Those warnings do not indicate that unrelated IBus packages are being removed.
