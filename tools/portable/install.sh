#!/usr/bin/env bash

install_openbangla() {
    local data_home
    data_home="$(xdg_dir XDG_DATA_HOME "$HOME/.local/share")"

    [[ -d "$OBK_STAGE$OBK_PREFIX" ]] ||
        die "Build completed without producing an install tree."

    mkdir -p "$OBK_PREFIX"
    cp -a "$OBK_STAGE$OBK_PREFIX/." "$OBK_PREFIX/"

    if [[ "$OBK_BACKEND" == ibus ]] &&
       [[ -f "$OBK_PREFIX/share/ibus/component/openbangla.xml" ]]; then
        mkdir -p "$data_home/ibus/component"
        cp -f "$OBK_PREFIX/share/ibus/component/openbangla.xml"             "$data_home/ibus/component/openbangla.xml"
    fi

    if [[ "$OBK_BACKEND" == ibus ]] &&
       command -v dconf >/dev/null 2>&1; then
        "$OBK_PREFIX/bin/openbangla-gui" --setup-system || true
    fi
}

verify_installation() {
    [[ -x "$OBK_PREFIX/bin/openbangla-gui" ]] ||
        die "openbangla-gui was not installed."

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
