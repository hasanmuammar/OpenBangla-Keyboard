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
        die "No supported build environment found. Install Toolbox, Distrobox, Podman, or Docker."
    fi
    export OBK_BUILDER
}

ensure_builder() {
    case "$OBK_BUILDER" in
        toolbox)
            if ! toolbox list 2>/dev/null | grep -q 'openbangla-builder'; then
                toolbox create --container openbangla-builder --image fedora:latest
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
            podman run --rm --userns=keep-id                 -v "$OBK_WORKSPACE:/workspace:rw"                 -v "$HOME:$HOME:rw"                 -v "$OBK_CACHE:/cache:rw"                 -v "$OBK_STAGE:/stage:rw"                 -e HOME="$HOME"                 -e OBK_WORKSPACE=/workspace                 -e OBK_BUILD=/cache/build                 -e OBK_STAGE=/stage                 -e OBK_CACHE=/cache                 -e OBK_BACKEND="$OBK_BACKEND"                 -e OBK_JOBS="$OBK_JOBS"                 ubuntu:24.04 bash -lc "$command"
            ;;
        docker)
            docker run --rm --user "$(id -u):$(id -g)"                 -v "$OBK_WORKSPACE:/workspace:rw"                 -v "$HOME:$HOME:rw"                 -v "$OBK_CACHE:/cache:rw"                 -v "$OBK_STAGE:/stage:rw"                 -e HOME="$HOME"                 -e OBK_WORKSPACE=/workspace                 -e OBK_BUILD=/cache/build                 -e OBK_STAGE=/stage                 -e OBK_CACHE=/cache                 -e OBK_BACKEND="$OBK_BACKEND"                 -e OBK_JOBS="$OBK_JOBS"                 ubuntu:24.04 bash -lc "$command"
            ;;
        *)
            die "Unknown build environment: $OBK_BUILDER"
            ;;
    esac
}
