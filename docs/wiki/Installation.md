# Installation — OpenBangla Keyboard for Linux

The normal installer uses prebuilt Linux releases. It does not require a compiler, CMake, Rust, Qt development packages, or a build container.

Supported architectures:

- x86_64
- ARM64 (aarch64)

KDE Plasma automatically selects Fcitx5. Other desktop environments select IBus.

## Install

```bash
git clone https://github.com/hasanmuammar/OpenBangla-Keyboard.git
cd OpenBangla-Keyboard
bash tools/install.sh
```

To install a specific release:

```bash
bash tools/install.sh --version 3.0.0
```

The installer downloads the matching release archive, verifies its SHA-256 checksum, extracts it, and installs it for the current user under `~/.local`.

## Build from source

Source compilation is a separate developer workflow:

```bash
bash tools/build.sh
```

The source build can use Toolbx, Distrobox, Podman, or Docker to isolate development dependencies. Release builds are produced for both x86_64 and ARM64.

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
