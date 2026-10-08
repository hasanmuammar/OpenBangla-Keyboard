# Portable user-local build

This directory contains the fork-specific Linux build and installation implementation.

- `common.sh` defines user-local paths and cache locations.
- `environment.sh` selects IBus or Fcitx5 and chooses Toolbox, Distrobox, Podman, or Docker automatically.
- `build.sh` installs build dependencies inside the selected environment, configures CMake, builds the selected backend, stages the installation, and prepares the bundled Qt/runtime libraries.
- `bundle-runtime.sh` handles the Linux shared-library closure and runtime modules such as the libproxy backend.
- `install.sh` copies the staged tree into the user-local prefix and registers the selected input method.
- `launch-bundled.sh` supplies the bundled library directory to the installed GUI and IBus engine.
