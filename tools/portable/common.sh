#!/usr/bin/env bash

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '==> %s\n' "$*"
}

require_linux() {
    [[ "$(uname -s)" == "Linux" ]] || die "This experimental installer supports Linux only."
}

xdg_dir() {
    local variable="$1"
    local fallback="$2"
    local value="${!variable:-}"
    printf '%s\n' "${value:-$fallback}"
}

prepare_paths() {
    local data_home cache_home
    data_home="$(xdg_dir XDG_DATA_HOME "$HOME/.local/share")"
    cache_home="$(xdg_dir XDG_CACHE_HOME "$HOME/.cache")"

    OBK_PREFIX="$HOME/.local"
    OBK_CACHE="$cache_home/openbangla-keyboard"
    OBK_BUILD="$OBK_CACHE/build"
    OBK_STAGE="$OBK_CACHE/stage"
    OBK_WORKSPACE="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

    export OBK_PREFIX OBK_CACHE OBK_BUILD OBK_STAGE OBK_WORKSPACE

    mkdir -p "$OBK_BUILD" "$OBK_STAGE" "$data_home/ibus/component"
}
