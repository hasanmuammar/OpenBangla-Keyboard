#!/usr/bin/env bash

build_openbangla() {
    local jobs="${OPENBANGLA_BUILD_JOBS:-2}"

    [[ "$jobs" =~ ^[1-9][0-9]*$ ]] ||
        die "OPENBANGLA_BUILD_JOBS must be a positive integer."

    export OBK_JOBS="$jobs"

    run_builder '
        set -Eeuo pipefail

        if command -v apt-get >/dev/null 2>&1; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y --no-install-recommends                 build-essential clang cmake ninja-build pkg-config                 rustc cargo libibus-1.0-dev libzstd-dev                 qtbase5-dev qtbase5-dev-tools libqt5svg5-dev                 libfcitx5core-dev ca-certificates
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y                 gcc gcc-c++ clang cmake ninja-build pkgconf-pkg-config                 rust cargo ibus-devel libzstd-devel                 qt5-qtbase-devel qt5-qtsvg-devel fcitx5-devel
        else
            echo "Unsupported package manager in build environment." >&2
            exit 1
        fi

        case "$OBK_BACKEND" in
            ibus)
                ibus=ON
                fcitx=OFF
                ;;
            fcitx)
                ibus=OFF
                fcitx=ON
                ;;
            *)
                echo "Unsupported input-method backend: $OBK_BACKEND" >&2
                exit 1
                ;;
        esac

        if [[ -d /workspace ]]; then
            source_dir=/workspace
            build_dir=/cache/build
            stage_dir=/stage
        else
            source_dir="$HOME/.local/share/openbangla-keyboard/source"
            build_dir="$HOME/.cache/openbangla-keyboard/build"
            stage_dir="$HOME/.cache/openbangla-keyboard/stage"
        fi

        mkdir -p "$build_dir" "$stage_dir"

        cmake -S "$source_dir" -B "$build_dir"             -GNinja             -DCMAKE_BUILD_TYPE=Release             -DCMAKE_INSTALL_PREFIX="$HOME/.local"             -DENABLE_IBUS="$ibus"             -DENABLE_FCITX="$fcitx"             -DENABLE_BOTH=OFF

        cmake --build "$build_dir" --parallel "$OBK_JOBS"

        rm -rf "$stage_dir"/*
        DESTDIR="$stage_dir" cmake --install "$build_dir"
    '
}
