#!/usr/bin/env bash

merge_openbangla_data() {
    local source="$1"
    local destination="$2"
    local item name layout target

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
                    # Never overwrite user-created/custom layouts on upgrade.
                    [[ -e "$destination/layouts/${layout##*/}" || -L "$destination/layouts/${layout##*/}" ]] ||
                        cp -a "$layout" "$destination/layouts/"
                done
                ;;
            data)
                mkdir -p "$destination/data"
                for layout in "$item"/*; do
                    [[ -e "$layout" || -L "$layout" ]] || continue
                    name="${layout##*/}"
                    target="$destination/data/$name"
                    # Autocorrect can contain user edits; retain it if present.
                    if [[ "$name" == autocorrect.json && ( -e "$target" || -L "$target" ) ]]; then
                        continue
                    fi
                    case "$name" in
                        dictionary.json|suffix.json|regex.json)
                            # These are shipped application databases and may be updated.
                            cp -a "$layout" "$target"
                            ;;
                        *)
                            # Preserve user-added data files.
                            [[ -e "$target" || -L "$target" ]] || cp -a "$layout" "$target"
                            ;;
                    esac
                done
                ;;
            icons)
                mkdir -p "$destination/icons"
                cp -a "$item/." "$destination/icons/"
                ;;
            *)
                # Preserve user-owned state files and other custom additions.
                [[ -e "$destination/$name" || -L "$destination/$name" ]] ||
                    cp -a "$item" "$destination/"
                ;;
        esac
    done
    shopt -u nullglob
}

relocate_xdg_resource() {
    local relative="$1"
    local source_root="$2"
    local source="$source_root/$relative"
    local destination="$OBK_DATA_HOME/$relative"

    [[ -e "$source" || -L "$source" ]] || return 0

    [[ ! -L "$destination" ]] ||
        die "Refusing to write through a symlinked XDG resource path: $destination"
    if [[ -e "$destination" ]]; then
        if [[ -d "$source" && ! -L "$source" && ! -d "$destination" ]]; then
            die "Resource destination has the wrong type; preserving source: $destination"
        fi
        if [[ ( ! -d "$source" || -L "$source" ) && -d "$destination" ]]; then
            die "Resource destination is a directory; preserving source: $destination"
        fi
    fi

    if [[ -d "$source" && ! -L "$source" ]]; then
        if [[ "$relative" == "openbangla-keyboard" ]]; then
            merge_openbangla_data "$source" "$destination"
        else
            mkdir -p "$destination"
            cp -a "$source/." "$destination/"
        fi
    else
        mkdir -p "$(dirname "$destination")"
        cp -a "$source" "$destination"
    fi
}

xdg_resource_relatives() {
    printf '%s\n' \
        openbangla-keyboard \
        applications/openbangla-keyboard.desktop \
        metainfo/io.github.openbangla.keyboard.metainfo.xml \
        pixmaps/openbangla-keyboard.png \
        ibus/component/openbangla.xml \
        fcitx5/addon/openbangla.conf \
        fcitx5/inputmethod/openbangla.conf
    for size in 16 32 48 128 512 1024; do
        printf '%s\n' "icons/hicolor/${size}x${size}/apps/openbangla-keyboard.png"
    done
}

confirm_legacy_xdg_migration() {
    [[ "$OBK_DATA_HOME" != "$OBK_PREFIX/share" ]] || return 0

    local migration_marker="$OBK_DATA_HOME/.openbangla-keyboard-xdg-migration-v1-complete"
    if [[ -e "$migration_marker" || -L "$migration_marker" ]]; then
        [[ -f "$migration_marker" && ! -L "$migration_marker" ]] ||
            die "Refusing to trust an unexpected legacy-migration marker path: $migration_marker"
        return 0
    fi

    local relative source destination found=0 reply
    while IFS= read -r relative; do
        source="$OBK_PREFIX/share/$relative"
        [[ -e "$source" || -L "$source" ]] || continue
        [[ ! -L "$source" ]] ||
            die "Refusing to migrate a symlinked legacy resource path: $source"
        if [[ "$found" -eq 0 ]]; then
            printf 'An existing installation stores these resources in the legacy location:\n'
        fi
        printf '  %s\n' "$source"
        printf '    destination: %s\n' "$OBK_DATA_HOME/$relative"
        found=1
    done < <(xdg_resource_relatives)

    [[ "$found" -eq 1 ]] || return 0

    printf 'To honour XDG_DATA_HOME, the legacy paths above must be moved or merged into the listed destinations. User layouts and existing autocorrect data are preserved where they already exist at the destination.\n'
    if [[ ! -t 0 ]]; then
        die "Legacy XDG resources need an explicit migration choice. Rerun interactively."
    fi
    read -r -p 'Migrate these legacy OpenBangla resources now? [y/N] ' reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] ||
        die "Installation cancelled; legacy resources were left untouched."
}

migrate_legacy_xdg_resources() {
    [[ "$OBK_DATA_HOME" != "$OBK_PREFIX/share" ]] || return 0

    local relative source destination preserved_legacy=0
    local migration_marker="$OBK_DATA_HOME/.openbangla-keyboard-xdg-migration-v1-complete"
    if [[ -e "$migration_marker" || -L "$migration_marker" ]]; then
        [[ -f "$migration_marker" && ! -L "$migration_marker" ]] ||
            die "Refusing to trust an unexpected legacy-migration marker path: $migration_marker"
        return 0
    fi

    while IFS= read -r relative; do
        source="$OBK_PREFIX/share/$relative"
        [[ -e "$source" || -L "$source" ]] || continue
        destination="$OBK_DATA_HOME/$relative"

        [[ ! -L "$destination" ]] ||
            die "Refusing to migrate over a symlinked XDG resource path: $destination"
        if [[ -e "$destination" ]]; then
            if [[ -d "$source" && ! -d "$destination" ]]; then
                die "Resource destination has the wrong type; source was preserved: $destination"
            fi
            if [[ ! -d "$source" && -d "$destination" ]]; then
                die "Resource destination is a directory; source was preserved: $destination"
            fi
        fi

        if [[ ! -e "$destination" && ! -L "$destination" ]]; then
            mkdir -p "$(dirname "$destination")"
            mv -- "$source" "$destination"
            continue
        fi

        # A destination exists, so merge/copy into it, but preserve the source.
        # The merge intentionally skips some duplicate custom layouts/autocorrect
        # files; deleting the whole source here could destroy those user edits.
        if [[ -d "$source" && ! -L "$source" ]]; then
            if [[ "$relative" == "openbangla-keyboard" ]]; then
                merge_openbangla_data "$source" "$destination"
            else
                mkdir -p "$destination"
                cp -a "$source/." "$destination/"
            fi
        else
            cp -a "$source" "$destination"
        fi
        preserved_legacy=1
    done < <(xdg_resource_relatives)

    if [[ "$preserved_legacy" -eq 1 ]]; then
        if [[ ! -e "$migration_marker" && ! -L "$migration_marker" ]]; then
            printf '%s\n' 'Legacy XDG resources were copied/merged; original sources were preserved.' > "$migration_marker"
        elif [[ ! -f "$migration_marker" || -L "$migration_marker" ]]; then
            die "Refusing to overwrite an unexpected migration marker: $migration_marker"
        fi
        printf 'Some legacy resources were copied/merged and their original paths were preserved for review. Migration will not repeat automatically. Marker: %s\n' "$migration_marker"
    fi
}

install_xdg_resources() {
    local source_root="${1:-$OBK_PREFIX/share}"
    local relative
    while IFS= read -r relative; do
        relocate_xdg_resource "$relative" "$source_root"
    done < <(xdg_resource_relatives)
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
    local config_home
    config_home="$(xdg_dir XDG_CONFIG_HOME "$HOME/.config")"

    for path in \
        "$OBK_PREFIX/bin/openbangla-gui" \
        "$OBK_PREFIX/bin/qt.conf" \
        "$OBK_PREFIX/bin/openbangla-gui.bin" \
        "$OBK_PREFIX/libexec/ibus-engine-openbangla" \
        "$OBK_PREFIX/libexec/ibus-engine-openbangla.bin" \
        "$OBK_PREFIX/lib/openbangla" \
        "$OBK_PREFIX/share/openbangla-keyboard" \
        "$OBK_PREFIX/share/applications/openbangla-keyboard.desktop" \
        "$OBK_PREFIX/share/ibus/component/openbangla.xml" \
        "$OBK_PREFIX/share/fcitx5/addon/openbangla.conf" \
        "$OBK_PREFIX/share/fcitx5/inputmethod/openbangla.conf" \
        "$OBK_PREFIX/share/metainfo/io.github.openbangla.keyboard.metainfo.xml" \
        "$OBK_PREFIX/share/pixmaps/openbangla-keyboard.png" \
        "$OBK_DATA_HOME/openbangla-keyboard" \
        "$OBK_DATA_HOME/applications/openbangla-keyboard.desktop" \
        "$OBK_DATA_HOME/ibus/component/openbangla.xml" \
        "$OBK_DATA_HOME/fcitx5/addon/openbangla.conf" \
        "$OBK_DATA_HOME/fcitx5/inputmethod/openbangla.conf" \
        "$OBK_DATA_HOME/metainfo/io.github.openbangla.keyboard.metainfo.xml" \
        "$OBK_DATA_HOME/pixmaps/openbangla-keyboard.png" \
        "$config_home/environment.d/90-openbangla-ibus.conf"; do
        if [[ -L "$path" ]]; then
            die "Refusing to overwrite a symlinked installation path: $path"
        fi
        if [[ -e "$path" ]]; then
            case "$path" in
                "$OBK_PREFIX/lib/openbangla"|"$OBK_PREFIX/share/openbangla-keyboard"|"$OBK_DATA_HOME/openbangla-keyboard")
                    [[ -d "$path" ]] ||
                        die "Existing installation path has the wrong type; refusing to replace it: $path"
                    ;;
                *)
                    [[ -f "$path" ]] ||
                        die "Existing installation path is not a regular file; refusing to replace it: $path"
                    ;;
            esac
            if [[ "$found" -eq 0 ]]; then
                printf 'These existing OpenBangla paths may be replaced by the installation:\n'
            fi
            printf '  %s\n' "$path"
            found=1
        fi
    done

    for size in 16 32 48 128 512 1024; do
        for icon_root in "$OBK_PREFIX/share/icons" "$OBK_DATA_HOME/icons"; do
            path="$icon_root/hicolor/${size}x${size}/apps/openbangla-keyboard.png"
            if [[ -L "$path" ]]; then
                die "Refusing to overwrite a symlinked icon path: $path"
            fi
            if [[ -e "$path" ]]; then
                [[ -f "$path" ]] ||
                    die "Existing icon path is not a regular file; refusing to replace it: $path"
                if [[ "$found" -eq 0 ]]; then
                    printf 'These existing OpenBangla paths may be replaced by the installation:\n'
                fi
                printf '  %s\n' "$path"
                found=1
            fi
        done
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
    local staged_root="$OBK_STAGE$OBK_PREFIX"
    local item name

    [[ -d "$staged_root" ]] ||
        die "Build completed without producing an install tree."
    [[ -d "$staged_root/share" ]] ||
        die "Build completed without producing the staged share resources."

    confirm_legacy_xdg_migration
    confirm_install_replacements
    migrate_legacy_xdg_resources
    mkdir -p "$OBK_PREFIX"

    # Copy executable/library trees only. Resources are installed directly into
    # XDG_DATA_HOME, avoiding a temporary old-location copy that shadows XDG.

    # Never replace an existing library bundle without a separate, explicit choice.
    if [[ -e "$OBK_PREFIX/lib/openbangla" || -L "$OBK_PREFIX/lib/openbangla" ]]; then
        if [[ -L "$OBK_PREFIX" || -L "$OBK_PREFIX/lib" || -L "$OBK_PREFIX/lib/openbangla" ]]; then
            die "Refusing to replace a bundled library through a symlinked install path."
        fi
        if [[ ! -t 0 ]]; then
            die "An existing library bundle needs a choice: keep a backup, replace without a backup, or cancel. Rerun interactively."
        fi
        printf 'Existing library bundle: %s\n' "$OBK_PREFIX/lib/openbangla"
        printf 'Choose what to do with it:\n'
        printf '  1) Replace and keep a timestamped backup\n'
        printf '  2) Replace without keeping a backup (old files will be deleted)\n'
        printf '  3) Cancel installation (default)\n'
        read -r -p 'Choice [3]: ' library_choice
        case "$library_choice" in
            1)
                backup="$OBK_PREFIX/lib/openbangla.backup.$(date +%Y%m%d%H%M%S)"
                if [[ -e "$backup" || -L "$backup" ]]; then
                    die "Backup path already exists; preserving all files: $backup"
                fi
                mv -- "$OBK_PREFIX/lib/openbangla" "$backup"
                printf 'Previous bundled libraries were preserved at: %s\n' "$backup"
                ;;
            2)
                printf 'This will permanently remove: %s\n' "$OBK_PREFIX/lib/openbangla"
                read -r -p 'Confirm deletion of this exact directory? [y/N] ' delete_reply
                [[ "$delete_reply" =~ ^[Yy]([Ee][Ss])?$ ]] ||
                    die "Replacement cancelled; previous bundled libraries were preserved."
                rm -rf -- "$OBK_PREFIX/lib/openbangla"
                ;;
            *)
                die "Installation cancelled; previous bundled libraries were preserved."
                ;;
        esac
    fi

    shopt -s nullglob dotglob
    for item in "$staged_root"/*; do
        name="${item##*/}"
        [[ "$name" == share ]] && continue
        cp -a "$item" "$OBK_PREFIX/"
    done
    shopt -u nullglob dotglob

    install_xdg_resources "$staged_root/share"

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
