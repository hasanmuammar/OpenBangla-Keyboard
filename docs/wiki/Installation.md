# Installation — OpenBangla Keyboard for Linux

Clone the fork with its submodules:

```bash
git clone --recursive https://github.com/hasanmuammar/OpenBangla-Keyboard.git
cd OpenBangla-Keyboard
bash tools/install.sh
```

The installer detects the desktop environment. KDE/Plasma selects Fcitx5; other desktop environments select IBus.

The installer then selects the first available isolated build environment from Toolbx, Distrobox, Podman, or Docker. Build dependencies are installed inside that environment rather than into the host system.

Only the selected input-method backend is built.

The normal installation prefix is:

```text
~/.local
```

The build and staging cache is under XDG_CACHE_HOME/openbangla-keyboard or ~/.cache/openbangla-keyboard.

The Podman build environment is persistent and uses Debian 13 slim. The first build installs its development dependencies; later builds reuse the same environment.

The default build parallelism is two jobs. Change it with:

```bash
OPENBANGLA_BUILD_JOBS=4 bash tools/install.sh
```

## IBus

On GNOME and other non-KDE/Plasma desktops, the installer installs the IBus engine, registers the component under ~/.local/share/ibus/component, rebuilds the IBus cache and persists the user-local IBUS_COMPONENT_PATH.

Verify registration with:

```bash
ibus list-engine | grep -i -A3 -B2 openbangla
```

## Fcitx5

On KDE/Plasma, the installer builds only the Fcitx5 backend and installs its module and addon metadata under the user-local prefix.
## Related projects

The installer and Linux integration use or integrate with [Toolbx](https://github.com/containers/toolbox), [Distrobox](https://github.com/89luca89/distrobox), [Podman](https://github.com/containers/podman), [Docker](https://github.com/moby/moby), [IBus](https://github.com/ibus/ibus), [Fcitx5](https://github.com/fcitx/fcitx5), [Qt](https://github.com/qt/qtbase) and [CMake](https://github.com/Kitware/CMake).
