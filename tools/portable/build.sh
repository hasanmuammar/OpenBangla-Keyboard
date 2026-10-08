#!/usr/bin/env bash

build_openbangla() {
    local jobs="${OPENBANGLA_BUILD_JOBS:-2}"

    [[ "$jobs" =~ ^[1-9][0-9]*$ ]] ||
        die "OPENBANGLA_BUILD_JOBS must be a positive integer."

    export OBK_JOBS="$jobs"

    run_builder '
        set -Eeuo pipefail

        if [[ "$(id -u)" -eq 0 ]]; then
            sudo_cmd=""
        else
            command -v sudo >/dev/null 2>&1 ||
                { echo "sudo is required inside the build environment." >&2; exit 1; }
            sudo_cmd=sudo
        fi

        if command -v apt-get >/dev/null 2>&1; then
            export DEBIAN_FRONTEND=noninteractive
            $sudo_cmd apt-get update
            $sudo_cmd apt-get install -y --no-install-recommends                 build-essential clang cmake ninja-build pkg-config                 rustc cargo libzstd-dev                 qtbase5-dev qtbase5-dev-tools libqt5svg5-dev                 ca-certificates

            if [[ "$OBK_BACKEND" == ibus ]]; then
                $sudo_cmd apt-get install -y --no-install-recommends libibus-1.0-dev
            else
                $sudo_cmd apt-get install -y --no-install-recommends libfcitx5core-dev
            fi
        elif command -v dnf >/dev/null 2>&1; then
            $sudo_cmd dnf install -y                 gcc gcc-c++ clang cmake ninja-build pkgconf-pkg-config                 rust cargo libzstd-devel                 qt5-qtbase-devel qt5-qtsvg-devel

            if [[ "$OBK_BACKEND" == ibus ]]; then
                $sudo_cmd dnf install -y ibus-devel
            else
                $sudo_cmd dnf install -y fcitx5-devel
            fi
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

        source_dir="$OBK_WORKSPACE"
        build_dir="$OBK_BUILD"
        stage_dir="$OBK_STAGE"

        mkdir -p "$build_dir" "$stage_dir"

        cmake -S "$source_dir" -B "$build_dir"             -GNinja             -DCMAKE_BUILD_TYPE=Release             -DCMAKE_INSTALL_PREFIX="$HOME/.local"             -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib/openbangla'             -DENABLE_IBUS="$ibus"             -DENABLE_FCITX="$fcitx"             -DENABLE_BOTH=OFF

        cmake --build "$build_dir" --parallel "$OBK_JOBS"

        rm -rf "$stage_dir"/*
        DESTDIR="$stage_dir" cmake --install "$build_dir"
        qt_lib_dir="$(qmake -query QT_INSTALL_LIBS)"
        qt_plugin_dir="$(qmake -query QT_INSTALL_PLUGINS)"
        runtime_lib_dir="$stage_dir$HOME/.local/lib/openbangla"
        runtime_plugin_dir="$runtime_lib_dir/qt5/plugins"

        mkdir -p "$runtime_lib_dir" "$runtime_plugin_dir"
        for library in \
            libQt5Core.so.5 \
            libQt5Gui.so.5 \
            libQt5Widgets.so.5 \
            libQt5Network.so.5 \
            libQt5Svg.so.5 \
            libQt5XcbQpa.so.5; do
            cp -a "$qt_lib_dir/$library"* "$runtime_lib_dir/"
        done
        cp -a "$qt_plugin_dir/platforms" "$runtime_plugin_dir/"

        cat > "$stage_dir$HOME/.local/bin/qt.conf" <<EOF
[Paths]
Plugins=../lib/openbangla/qt5/plugins
EOF
    '
}
