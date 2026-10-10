#!/usr/bin/env bash

merge_openbangla_data() {
    local source="$1"
    local destination="$2"
    local item name layout

    mkdir -p "$destination"
    shopt -s nullglob
    for item in "$source"/*; do
        [[ -e "$item" || -L "$item" ]] || continue
        name="${item##*/}"

        case "$name" in
            layouts)
                mkdir -p "$destination/layouts"
                for layout in "$item"/*; do
                    [[ -e "$layout" || -L "$layout" ]] || continue
                    # Do not overwrite user-created/custom layouts on upgrade.
                    [[ -e "$destination/layouts/${layout##*/}" ]] ||
                        cp -a "$layout" "$destination/layouts/"
                done
                ;;
            data|icons)
                mkdir -p "$destination/$name"
                cp -a "$item/." "$destination/$name/"
                ;;
            *)
                # Preserve user-owned state files such as autocorrect.json.
                [[ -e "$destination/$name" || -L "$destination/$name" ]] ||
                    cp -a "$item" "$destination/"
                ;;
        esac
    done
    shopt -u nullglob
    # Keep the source tree; installation must not silently delete directories.
}

relocate_xdg_resource() {
    local relative="$1"
    local source="$OBK_PREFIX/share/$relative"
    local destination="$OBK_DATA_HOME/$relative"

    [[ "$source" != "$destination" ]] || return 0
    [[ -e "$source" || -L "$source" ]] || return 0

    if [[ -d "$source" && ! -L "$source" ]]; then
        if [[ "$relative" == "openbangla-keyboard" ]]; then
            merge_openbangla_data "$source" "$destination"
        else
            mkdir -p "$destination"
            cp -a "$source/." "$destination/"
            # Preserve the source until the user chooses to remove it.
        fi
    else
        mkdir -p "$(dirname "$destination")"
        cp -a "$source" "$destination"
        # Preserve the source file until the user chooses to remove it.
    fi
}

install_xdg_resources() {
    [[ "$OBK_DATA_HOME" == "$OBK_PREFIX/share" ]] && return 0

    local relative size
    for relative in         openbangla-keyboard         applications/openbangla-keyboard.desktop         metainfo/io.github.openbangla.keyboard.metainfo.xml         pixmaps/openbangla-keyboard.png         ibus/component/openbangla.xml         fcitx5/addon/openbangla.conf         fcitx5/inputmethod/openbangla.conf; do
        relocate_xdg_resource "$relative"
    done

    for size in 16 32 48 128 512 1024; do
        relocate_xdg_resource "icons/hicolor/${size}x${size}/apps/openbangla-keyboard.png"
    done
}

xml_escape() {
    local value="$1"
    value="${value//&/\&amp;}"
    value="${value//</\&lt;}"
    value="${value//>/\&gt;}"
    value="${value//\"/\&quot;}"
    value="${value//\'/\&apos;}"
    printf '%s' "$value"
}

sed_escape_replacement() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//&/\\&}"
    value="${value//|/\\|}"
    printf '%s' "$value"
}

rewrite_install_metadata() {
    local component="$OBK_DATA_HOME/ibus/component/openbangla.xml"
    local desktop="$OBK_DATA_HOME/applications/openbangla-keyboard.desktop"
    local engine icon gui

    if [[ -f "$component" ]]; then
        engine="$(xml_escape "$OBK_PREFIX/libexec/ibus-engine-openbangla")"
        icon="$(xml_escape "$OBK_DATA_HOME/openbangla-keyboard/icons/OpenBangla-Keyboard.png")"
        engine="$(sed_escape_replacement "$engine")"
        icon="$(sed_escape_replacement "$icon")"
        sed -i -E             -e "s|<exec>[^<]*</exec>|<exec>\"$engine\" --ibus</exec>|"             -e "s|<icon>[^<]*</icon>|<icon>$icon</icon>|"             "$component"
    fi

    if [[ -f "$desktop" ]]; then
        gui="$OBK_PREFIX/bin/openbangla-gui"
        # Desktop Entry arguments support quoted executable paths.
        gui="${gui//\\/\\\\}"
        gui="${gui//\"/\\\"}"
        gui="$(sed_escape_replacement "$gui")"
        sed -i -E "s|^Exec=.*$|Exec=\"$gui\" %f|" "$desktop"
    fi
}

confirm_install_replacements() {
    local path found=0 reply

    for path in \
        "$OBK_PREFIX/bin/openbangla-gui" \
        "$OBK_PREFIX/bin/openbangla-gui.bin" \
        "$OBK_PREFIX/libexec/ibus-engine-openbangla" \
        "$OBK_PREFIX/libexec/ibus-engine-openbangla.bin" \
        "$OBK_PREFIX/lib/openbangla" \
        "$OBK_PREFIX/share/openbangla-keyboard" \
        "$OBK_DATA_HOME/openbangla-keyboard" \
        "$OBK_DATA_HOME/applications/openbangla-keyboard.desktop" \
        "$OBK_DATA_HOME/ibus/component/openbangla.xml" \
        "$OBK_DATA_HOME/fcitx5/addon/openbangla.conf" \
        "$OBK_DATA_HOME/fcitx5/inputmethod/openbangla.conf"; do
        if [[ -e "$path" || -L "$path" ]]; then
            if [[ "$found" -eq 0 ]]; then
                printf 'These existing OpenBangla paths may be replaced by the installation:\n'
            fi
            printf '  %s\n' "$path"
            found=1
        fi
    done

    [[ "$found" -eq 1 ]] || return 0

    if [[ ! -t 0 ]]; then
        die "Existing OpenBangla files need review. Rerun interactively to choose whether to replace them."
    fi
    read -r -p 'Continue and replace the listed OpenBangla paths? [y/N] ' reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] ||
        die "Installation cancelled; existing OpenBangla files were preserved."
}

install_openbangla() {
    [[ -d "$OBK_STAGE$OBK_PREFIX" ]] ||
        die "Build completed without producing an install tree."

    confirm_install_replacements
    mkdir -p "$OBK_PREFIX"

    # Replacing the existing library bundle is allowed only after the explicit
    # confirmation above. Other unrelated paths are not recursively removed.
    if [[ -d "$OBK_PREFIX/lib/openbangla" ]]; then
        rm -rf -- "$OBK_PREFIX/lib/openbangla"
    fi

    cp -a "$OBK_STAGE$OBK_PREFIX/." "$OBK_PREFIX/"
    install_xdg_resources

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

    rewrite_install_metadata

    if [[ "$OBK_BACKEND" == ibus ]] && command -v ibus >/dev/null 2>&1; then
        local ibus_component_path="$OBK_DATA_HOME/ibus/component"
        local ibus_component_env="$ibus_component_path:/usr/share/ibus/component"
        local xdg_config_home

        xdg_config_home="$(xdg_dir XDG_CONFIG_HOME "$HOME/.config")"
        mkdir -p "$xdg_config_home/environment.d"
        printf "%s\n" "IBUS_COMPONENT_PATH=$ibus_component_env" > "$xdg_config_home/environment.d/90-openbangla-ibus.conf"

        if command -v dbus-update-activation-environment >/dev/null 2>&1; then
            dbus-update-activation-environment --systemd "IBUS_COMPONENT_PATH=$ibus_component_env" || true
        elif command -v systemctl >/dev/null 2>&1; then
            IBUS_COMPONENT_PATH="$ibus_component_env" systemctl --user import-environment IBUS_COMPONENT_PATH || true
        fi

        IBUS_COMPONENT_PATH="$ibus_component_env" ibus write-cache || die "Failed to register the IBus component."

        IBUS_COMPONENT_PATH="$ibus_component_env" ibus restart >/dev/null 2>&1 || true
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

    "$OBK_PREFIX/bin/openbangla-gui" --check-data >/dev/null 2>&1 ||
        die "The installed runtime cannot locate its layout and dictionary data files."

    case "$OBK_BACKEND" in
        ibus)
            [[ -x "$OBK_PREFIX/libexec/ibus-engine-openbangla" ]] ||
                die "The IBus engine was not installed."
            [[ -f "$OBK_DATA_HOME/ibus/component/openbangla.xml" ]] ||
                die "The IBus component metadata was not installed under XDG_DATA_HOME."
            ;;
        fcitx)
            [[ -f "$OBK_DATA_HOME/fcitx5/addon/openbangla.conf" ]] ||
                die "The Fcitx5 addon was not installed under XDG_DATA_HOME."
            ;;
    esac
}
