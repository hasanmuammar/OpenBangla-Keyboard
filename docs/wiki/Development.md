# Development

Use the develop branch for fork development.

## Update and rebuild

```bash
git pull --recurse-submodules
bash tools/install.sh
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

Main components are tools/install.sh, tools/uninstall.sh and tools/portable/.

## Testing

For IBus installations, verify OpenBangla with ibus list-engine. The installer also verifies that openbangla-gui --version starts with the bundled runtime.