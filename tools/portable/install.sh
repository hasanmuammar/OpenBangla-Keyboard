#!/usr/bin/env bash

install_openbangla() {
    [[ -d "$OBK_STAGE$OBK_PREFIX" ]] ||
        die "Build completed without producing an install tree."

    mkdir -p "$OBK_PREFIX"

    if [[ -d "$OBK_PREFIX/lib/openbangla" ]]; then
        rm -rf "$OBK_PREFIX/lib/openbangla"
    fi

    cp -a "$OBK_STAGE$OBK_PREFIX/." "$OBK_PREFIX/"

    if [[ -x "$OBK_PREFIX/bin/openbangla-gui" ]]; then
        mv -f "$OBK_PREFIX/bin/openbangla-gui" "$OBK_PREFIX/bin/openbangla-gui.bin"
        cp "$OBK_WORKSPACE/tools/portable/launch-bundled.sh" "$OBK_PREFIX/bin/openbangla-gui"
        chmod +x "$OBK_PREFIX/bin/openbangla-gui"
    fi

    if [[ -x "$OBK_PREFIX/libexec/ibus-engine-openbangla" ]]; then
        mv -f "$OBK_PREFIX/libexec/ibus-engine-openbangla" "$OBK_PREFIX/libexec/ibus-engine-openbangla.bin"
        cp "$OBK_WORKSPACE/tools/portable/launch-bundled.sh" "$OBK_PREFIX/libexec/ibus-engine-openbangla"
        chmod +x "$OBK_PREFIX/libexec/ibus-engine-openbangla"
    fi

    if [[ "$OBK_BACKEND" == ibus ]] &&
       command -v dconf >/dev/null 2>&1; then
        "$OBK_PREFIX/bin/openbangla-gui" --setup-system || true
    fi
}

verify_installation() {
    [[ -x "$OBK_PREFIX/bin/openbangla-gui" ]] ||
        die "openbangla-gui was not installed."

    "$OBK_PREFIX/bin/openbangla-gui" --version >/dev/null 2>&1 ||
        die "openbangla-gui cannot start with the installed runtime."

    case "$OBK_BACKEND" in
        ibus)
            [[ -x "$OBK_PREFIX/libexec/ibus-engine-openbangla" ]] ||
                die "The IBus engine was not installed."
            ;;
        fcitx)
            [[ -f "$OBK_PREFIX/share/fcitx5/addon/openbangla.conf" ]] ||
                die "The Fcitx5 addon was not installed."
            ;;
    esac
}
