#!/usr/bin/env bash
set -Eeuo pipefail

PREFIX="${HOME}/.local"

xdg_home() {
    local variable="$1"
    local fallback="$2"
    local value="${!variable:-}"
    [[ "$value" == /* && "$value" != "/" ]] || value=""
    printf '%s\\n' "${value:-$fallback}"
}

DATA_HOME="$(xdg_home XDG_DATA_HOME "$HOME/.local/share")"
CONFIG_HOME="$(xdg_home XDG_CONFIG_HOME "$HOME/.config")"
CACHE_HOME="$(xdg_home XDG_CACHE_HOME "$HOME/.cache")"

PURGE_CACHE=0

usage() {
    cat <<'EOF'
Usage: tools/uninstall.sh [--purge-cache]

Remove the current user's OpenBangla Keyboard installation.

Options:
  --purge-cache   Also remove the build/staging cache at
                  ~/.cache/openbangla-keyboard (or XDG_CACHE_HOME).
  -h, --help      Show this help.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '==> %s\n' "$*"
}

remove_path() {
    local path="$1"

    if [[ -e "$path" || -L "$path" ]]; then
        rm -rf -- "$path"
        log "Removed $path"
    fi
}

remove_matching_file() {
    local root="$1"
    local relative="$2"
    local path="$root/$relative"

    if [[ -e "$path" || -L "$path" ]]; then
        rm -f -- "$path"
        log "Removed $path"
    fi
}

remove_dconf_tuple() {
    local key="$1"
    local tuple="$2"
    local value cleaned

    command -v dconf >/dev/null 2>&1 || return 0

    value="$(dconf read "$key" 2>/dev/null || true)"
    [[ -n "$value" && "$value" != "[]" ]] || return 0
    [[ "$value" == *"$tuple"* ]] || return 0

    cleaned="${value//"$tuple"/}"
    cleaned="${cleaned//, ,/, }"
    cleaned="${cleaned//, ]/]}"
    cleaned="${cleaned//[, /[}"

    if [[ -z "$cleaned" ]]; then
        cleaned="[]"
    fi

    dconf write "$key" "$cleaned"
    log "Updated $key"
}

remove_fcitx_profile_entry() {
    local profile="$CONFIG_HOME/fcitx5/profile"
    local tmp

    [[ -f "$profile" ]] || return 0
    grep -q '^Name=openbangla$' "$profile" || return 0

    tmp="$(mktemp)"

    awk '
        function flush() {
            if (section != "" && !drop)
                printf "%s", block
        }

        /^\[/ {
            flush()
            section = $0
            block = $0 ORS
            drop = 0
            next
        }

        {
            block = block $0 ORS
            if (section ~ /^\[Groups\/[0-9]+\/Items\/[0-9]+\]$/ &&
                $0 == "Name=openbangla")
                drop = 1
        }

        END {
            flush()
        }
    ' "$profile" > "$tmp"

    sed -i 's/^DefaultIM=openbangla$/DefaultIM=keyboard-us/' "$tmp"

    if ! cmp -s "$profile" "$tmp"; then
        mv -- "$tmp" "$profile"
        log "Removed OpenBangla from $profile"
    else
        rm -f -- "$tmp"
    fi
}

remove_ibus_registration() {
    local component_dir="$DATA_HOME/ibus/component"

    remove_path "$component_dir/openbangla.xml"

    if command -v ibus >/dev/null 2>&1; then
        IBUS_COMPONENT_PATH="$component_dir:/usr/share/ibus/component" \
            ibus write-cache >/dev/null 2>&1 || true
        ibus restart >/dev/null 2>&1 || true
    fi

    remove_dconf_tuple \
        "/org/gnome/desktop/input-sources/sources" \
        "('ibus', 'OpenBangla')"

    remove_dconf_tuple \
        "/org/gnome/desktop/input-sources/mru-sources" \
        "('ibus', 'OpenBangla')"

    remove_path "$CONFIG_HOME/environment.d/90-openbangla-ibus.conf"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user unset-environment IBUS_COMPONENT_PATH >/dev/null 2>&1 || true
    fi
}

remove_fcitx_registration() {
    find "$PREFIX" -type f \
        \( -path '*/fcitx5/openbangla.so' -o \
           -path '*/fcitx5/inputmethod/openbangla.conf' -o \
           -path '*/fcitx5/addon/openbangla.conf' \) \
        -print -delete 2>/dev/null || true

    remove_fcitx_profile_entry

    if command -v fcitx5-remote >/dev/null 2>&1; then
        fcitx5-remote -r >/dev/null 2>&1 || true
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --purge-cache)
                PURGE_CACHE=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
        shift
    done

    printf 'Review these OpenBangla-specific paths before continuing:\n'
    for path in \
        "$PREFIX/bin/openbangla-gui" \
        "$PREFIX/bin/openbangla-gui.bin" \
        "$PREFIX/libexec/ibus-engine-openbangla" \
        "$PREFIX/libexec/ibus-engine-openbangla.bin" \
        "$PREFIX/lib/openbangla" \
        "$DATA_HOME/openbangla-keyboard" \
        "$DATA_HOME/applications/openbangla-keyboard.desktop" \
        "$DATA_HOME/fcitx5/addon/openbangla.conf" \
        "$DATA_HOME/fcitx5/inputmethod/openbangla.conf" \
        "$DATA_HOME/metainfo/io.github.openbangla.keyboard.metainfo.xml" \
        "$DATA_HOME/pixmaps/openbangla-keyboard.png" \
        "$CONFIG_HOME/environment.d/90-openbangla-ibus.conf"; do
        printf '  %s\n' "$path"
    done
    for size in 16 32 48 128 512 1024; do
        printf '  %s\n' "$DATA_HOME/icons/hicolor/${size}x${size}/apps/openbangla-keyboard.png"
    done
    if [[ $PURGE_CACHE -eq 1 ]]; then
        printf '  %s\n' "$CACHE_HOME/openbangla-keyboard"
    fi
    if [[ -d "$PREFIX" ]]; then
        printf 'Matching Fcitx files under %s:\n' "$PREFIX"
        find "$PREFIX" -type f \
            \( -path '*/fcitx5/openbangla.so' -o \
               -path '*/fcitx5/inputmethod/openbangla.conf' -o \
               -path '*/fcitx5/addon/openbangla.conf' \) -print 2>/dev/null || true
    fi
    printf 'The script will also remove OpenBangla registrations from input-method settings.\n'
    read -r -p 'Proceed with these removals? [y/N] ' reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] ||
        exit 0

    remove_path "$PREFIX/bin/openbangla-gui"
    remove_path "$PREFIX/bin/openbangla-gui.bin"
    remove_path "$PREFIX/libexec/ibus-engine-openbangla"
    remove_path "$PREFIX/libexec/ibus-engine-openbangla.bin"
    remove_path "$PREFIX/lib/openbangla"

    remove_path "$DATA_HOME/openbangla-keyboard"
    remove_path "$DATA_HOME/applications/openbangla-keyboard.desktop"
    remove_path "$DATA_HOME/fcitx5/addon/openbangla.conf"
    remove_path "$DATA_HOME/fcitx5/inputmethod/openbangla.conf"
    remove_path "$DATA_HOME/metainfo/io.github.openbangla.keyboard.metainfo.xml"
    remove_path "$DATA_HOME/pixmaps/openbangla-keyboard.png"

    for size in 16 32 48 128 512 1024; do
        remove_path "$DATA_HOME/icons/hicolor/${size}x${size}/apps/openbangla-keyboard.png"
    done

    remove_ibus_registration
    remove_fcitx_registration

    if [[ $PURGE_CACHE -eq 1 ]]; then
        remove_path "$CACHE_HOME/openbangla-keyboard"
    fi

    printf 'OpenBangla Keyboard was removed for the current user.\n'
}

main "$@"
