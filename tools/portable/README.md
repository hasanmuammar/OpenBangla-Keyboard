# Portable user-local build

This tooling is specific to the experimental fork. It builds OpenBangla Keyboard in an isolated development environment and installs the result under the current user's home directory.

The installer automatically selects Toolbox, Distrobox, Podman, or Docker, in that order.

For the input-method backend, KDE/Plasma uses Fcitx5 and other desktop environments use IBus.

Build state is cached under XDG cache storage. The default build parallelism is two jobs and can be overridden with `OPENBANGLA_BUILD_JOBS`.

The host is not used as a package-installation target. The installer does not require sudo and does not write to system directories.
