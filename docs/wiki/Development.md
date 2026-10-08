# Development — OpenBangla Keyboard Linux Fork

Use the develop branch for fork development.

## Update and rebuild

```bash
git pull --recurse-submodules
bash tools/build.sh
```

The installer uses a persistent build cache. For a clean CMake configuration, remove the cached build directory.

```bash
rm -rf "$HOME/.cache/openbangla-keyboard/build"
```

## Manual CMake build

Configure exactly one backend.

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
  -DENABLE_IBUS=ON \
  -DENABLE_FCITX=OFF

cmake --build build --parallel 2
cmake --install build
```

For Fcitx5, switch the two backend options accordingly.

## Installer code

Main components are `tools/install.sh`, `tools/uninstall.sh` and `tools/portable/`.

The source-build workflow integrates with Toolbx, Distrobox, Podman or Docker for isolated builds, CMake for configuration, Qt5 for the GUI, Corrosion for Rust/CMake integration, and either IBus or Fcitx5 for Linux input-method integration.

## Testing

For IBus installations, verify OpenBangla with ibus list-engine. The installer also verifies that openbangla-gui --version starts with the bundled runtime.
## Release builds

The GitHub Actions release workflow builds prebuilt Linux archives for x86_64 and ARM64, with separate IBus and Fcitx5 builds.

Test local release packaging with:

```bash
bash tools/build.sh --backend ibus --package
bash tools/build.sh --backend fcitx --package
```
