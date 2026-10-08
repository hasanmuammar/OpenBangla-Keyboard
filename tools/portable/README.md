# Portable user-local build

This directory contains the fork-specific Linux source-build, runtime-bundling and user-local installation implementation. The normal installer downloads prebuilt releases and does not use this build environment.

- `common.sh` defines user-local paths and cache locations.
- `environment.sh` selects IBus or Fcitx5 and chooses Toolbox, Distrobox, Podman, or Docker automatically.
- `build.sh` installs build dependencies inside the selected environment, configures CMake, builds the selected backend, stages the installation, and prepares the bundled Qt/runtime libraries.
- `bundle-runtime.sh` handles the Linux shared-library closure and runtime modules such as the libproxy backend.
- `install.sh` copies the staged tree into the user-local prefix and registers the selected input method.
- `launch-bundled.sh` supplies the bundled library directory to the installed GUI and IBus engine.

## Main integrations

The portable build uses [CMake](https://github.com/Kitware/CMake), [Qt5](https://github.com/qt/qtbase), [Corrosion](https://github.com/corrosion-rs/corrosion) and [Zstandard](https://github.com/facebook/zstd), with Toolbx, Distrobox, Podman or Docker providing the isolated build environment.

## Build environment selection

The installer prefers an existing Toolbx or Distrobox environment, then Podman or Docker. When no supported builder is installed, `environment.sh` detects the host package manager and attempts to install Podman automatically. The Podman builder is persistent, named `openbangla-builder`, and uses Debian 13 slim; its development dependencies are cached inside that container.

