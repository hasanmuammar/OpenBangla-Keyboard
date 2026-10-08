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
    if command -v apt-get >/dev/null 2>&1; then
        log "No isolated build environment found. Installing Podman with apt."
        run_host_root apt-get update
        run_host_root env DEBIAN_FRONTEND=noninteractive apt-get install -y podman
    elif command -v dnf >/dev/null 2>&1; then
        log "No isolated build environment found. Installing Podman with dnf."
        run_host_root dnf install -y podman
    elif command -v pacman >/dev/null 2>&1; then
        log "No isolated build environment found. Installing Podman with pacman."
        run_host_root pacman -Sy --needed --noconfirm podman
    elif command -v zypper >/dev/null 2>&1; then
        log "No isolated build environment found. Installing Podman with zypper."
        run_host_root zypper --non-interactive install podman
    elif command -v apk >/dev/null 2>&1; then
        log "No isolated build environment found. Installing Podman with apk."
        run_host_root apk add podman
    else
        die "No supported build environment or host package manager found. Install Toolbx, Distrobox, Podman, or Docker manually and rerun this installer."
    fi

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
        podman)
            if ! podman container exists openbangla-builder 2>/dev/null; then
                podman create                     --name openbangla-builder                     -v "$OBK_WORKSPACE:/workspace:rw"                     -v "$HOME:$HOME:rw"                     -v "$OBK_CACHE:/cache:rw"                     -v "$OBK_STAGE:/stage:rw"                     -e HOME="$HOME"                     ubuntu:24.04 sleep infinity
            fi

            if [[ "$(podman inspect -f '{{.State.Running}}' openbangla-builder 2>/dev/null)" != true ]]; then
                podman start openbangla-builder >/dev/null
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
            podman exec                 -e OBK_WORKSPACE=/workspace                 -e OBK_BUILD=/cache/build                 -e OBK_STAGE=/stage                 -e OBK_CACHE=/cache                 -e OBK_BACKEND="$OBK_BACKEND"                 -e OBK_JOBS="$OBK_JOBS"                 openbangla-builder                 bash -lc "$env_prefix$command"
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
