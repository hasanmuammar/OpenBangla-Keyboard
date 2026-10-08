# Fork tooling

The fork-specific installation workflow is under `tools/portable/`.

`tools/install.sh` is the main installation entry point. It detects the desktop environment, selects IBus or Fcitx5, chooses an isolated build environment, builds the current source tree, bundles the required runtime, and installs the result for the current user.

`tools/uninstall.sh` removes the user-local installation and backend registration. Use `--purge-cache` to remove the build and staging cache as well.

The portable installer is the primary installation path for this fork.
