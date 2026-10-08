# Fork tooling

The fork-specific installation workflow is under `tools/portable/`.

`tools/install.sh` is the normal user-facing installer. It detects the desktop environment and CPU architecture, downloads the matching prebuilt Linux release, verifies its checksum, and installs it for the current user.

`tools/uninstall.sh` removes the user-local installation and backend registration. Use `--purge-cache` to remove the build and staging cache as well.

The portable installer is the primary installation path for this fork.

## External build and desktop projects

The installer integrates with [Toolbx](https://github.com/containers/toolbox), [Distrobox](https://github.com/89luca89/distrobox), [Podman](https://github.com/containers/podman) or [Docker](https://github.com/moby/moby) for isolated builds, and with [IBus](https://github.com/ibus/ibus) or [Fcitx5](https://github.com/fcitx/fcitx5) for Linux input-method integration.

## Source builds

`tools/build.sh` is the developer-facing source-build entry point. It can use Toolbx, Distrobox, Podman or Docker to isolate build dependencies and can also create release archives.
