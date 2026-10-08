#!/usr/bin/env bash

detect_desktop_backend() {
    case "${XDG_CURRENT_DESKTOP:-}:${XDG_SESSION_DESKTOP:-}:${DESKTOP_SESSION:-}" in
        *KDE*|*kde*|*PLASMA*|*plasma*)
            OBK_BACKEND=fcitx
            ;;
        *)
            OBK_BACKEND=ibus
            ;;
    esac
    export OBK_BACKEND
}

detect_host_distro() {
    local distro_name=""

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release

        case "${ID:-}" in
            debian|ubuntu|linuxmint)
                distro_name=debian
                ;;
            fedora|rhel|centos|rocky|almalinux)
                distro_name=fedora
                ;;
            arch|manjaro|endeavouros)
                distro_name=arch
                ;;
            opensuse*|sles)
                distro_name=opensuse
                ;;
        esac
    fi

    if [[ -z "$distro_name" && -e /etc/arch-release ]]; then
        distro_name=arch
    fi

    printf "%s\\n" "$distro_name"
}

run_host_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        command -v sudo >/dev/null 2>&1 ||
            die "sudo is required to install the host build environment."
        sudo "$@"
    fi
}

bootstrap_podman() {
    local distro
    distro="$(detect_host_distro)"

    log "No isolated build environment found. Installing Podman automatically."

    case "$distro" in
        debian)
            log "Detected Debian/Ubuntu-based host."
            run_host_root apt-get update
            run_host_root env DEBIAN_FRONTEND=noninteractive apt-get install -y podman
            ;;
        fedora)
            log "Detected Fedora/RHEL-based host."
            run_host_root dnf install -y podman
            ;;
        arch)
            log "Detected Arch-based host."
            run_host_root pacman -Sy --needed --noconfirm podman
            ;;
        opensuse)
            log "Detected openSUSE/SUSE-based host."
            run_host_root zypper --non-interactive install podman
            ;;
        *)
            die "No supported build environment was found, and the host distribution could not be recognised for automatic Podman installation. Install Podman, Toolbx, Distrobox, or Docker and rerun this installer."
            ;;
    esac

    command -v podman >/dev/null 2>&1 ||
        die "Podman installation completed but the podman command is still unavailable."

    log "Podman is now available."
}

select_builder() {
    if command -v toolbox >/dev/null 2>&1; then
        OBK_BUILDER=toolbox
    elif command -v distrobox >/dev/null 2>&1; then
        OBK_BUILDER=distrobox
    elif command -v podman >/dev/null 2>&1; then
        OBK_BUILDER=podman
    elif command -v docker >/dev/null 2>&1; then
        OBK_BUILDER=docker
    else
        bootstrap_podman
        OBK_BUILDER=podman
    fi
    export OBK_BUILDER
}

ensure_builder() {
    case "$OBK_BUILDER" in
        toolbox)
            if ! toolbox list 2>/dev/null | grep -q 'openbangla-builder'; then
                toolbox create --container openbangla-builder
            fi
            ;;
        distrobox)
            if ! distrobox list 2>/dev/null | grep -q 'openbangla-builder'; then
                distrobox create --name openbangla-builder --image ubuntu:24.04
            fi
            ;;
    esac
}

run_builder() {
    local command="$1"
    local env_prefix

    ensure_builder

    printf -v env_prefix         'export OBK_WORKSPACE=%q OBK_BUILD=%q OBK_STAGE=%q OBK_CACHE=%q OBK_BACKEND=%q OBK_JOBS=%q; '         "$OBK_WORKSPACE" "$OBK_BUILD" "$OBK_STAGE" "$OBK_CACHE" "$OBK_BACKEND" "$OBK_JOBS"

    case "$OBK_BUILDER" in
        toolbox)
            toolbox run --container openbangla-builder bash -lc "$env_prefix$command"
            ;;
        distrobox)
            distrobox enter --name openbangla-builder -- bash -lc "$env_prefix$command"
            ;;
        podman)
            podman run --rm                 -v "$OBK_WORKSPACE:/workspace:rw"                 -v "$HOME:$HOME:rw"                 -v "$OBK_CACHE:/cache:rw"                 -v "$OBK_STAGE:/stage:rw"                 -e HOME="$HOME"                 -e OBK_WORKSPACE=/workspace                 -e OBK_BUILD=/cache/build                 -e OBK_STAGE=/stage                 -e OBK_CACHE=/cache                 -e OBK_BACKEND="$OBK_BACKEND"                 -e OBK_JOBS="$OBK_JOBS"                 ubuntu:24.04 bash -lc "$command"
            ;;
        docker)
            docker run --rm                 -v "$OBK_WORKSPACE:/workspace:rw"                 -v "$HOME:$HOME:rw"                 -v "$OBK_CACHE:/cache:rw"                 -v "$OBK_STAGE:/stage:rw"                 -e HOME="$HOME"                 -e OBK_WORKSPACE=/workspace                 -e OBK_BUILD=/cache/build                 -e OBK_STAGE=/stage                 -e OBK_CACHE=/cache                 -e OBK_BACKEND="$OBK_BACKEND"                 -e OBK_JOBS="$OBK_JOBS"                 ubuntu:24.04 bash -lc "$command"
            ;;
        *)
            die "Unknown build environment: $OBK_BUILDER"
            ;;
    esac

    if [[ "$OBK_BUILDER" == docker ]]; then
        docker run --rm             -v "$OBK_CACHE:/cache:rw"             -v "$OBK_STAGE:/stage:rw"             ubuntu:24.04             chown -R "$(id -u):$(id -g)" /cache /stage
    fi
}
