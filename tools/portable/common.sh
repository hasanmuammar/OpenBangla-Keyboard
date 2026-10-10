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
    # Ignore invalid XDG base directories, including filesystem root.
    [[ "$value" == /* && "$value" != "/" ]] || value=""
    printf '%s\n' "${value:-$fallback}"
}

prepare_paths() {
    local data_home cache_home
    data_home="$(xdg_dir XDG_DATA_HOME "$HOME/.local/share")"
    cache_home="$(xdg_dir XDG_CACHE_HOME "$HOME/.cache")"

    OBK_PREFIX="$HOME/.local"
    OBK_DATA_HOME="$data_home"
    OBK_CACHE="$cache_home/openbangla-keyboard"
    OBK_BUILD="$OBK_CACHE/build"
    OBK_WORKSPACE="$(cd -- "$SCRIPT_DIR/.." && pwd)"

    mkdir -p "$OBK_BUILD" "$OBK_DATA_HOME/ibus/component"

    # Never clear a possibly stale staging directory. Create a new one for
    # each invocation so a missing/unset path can never expand to /*.
    OBK_STAGE="$(mktemp -d "$OBK_CACHE/stage.XXXXXXXX")" ||
        die "Could not create a fresh OpenBangla staging directory."

    export OBK_PREFIX OBK_DATA_HOME OBK_CACHE OBK_BUILD OBK_STAGE OBK_WORKSPACE
}
