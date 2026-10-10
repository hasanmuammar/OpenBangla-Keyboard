#!/bin/sh
# Disposable Flatpak filesystem-permission test. Never touches production paths.
set -e
LC_ALL=C
export LC_ALL

app_data=$HOME/.local/share
app_config=$HOME/.config
app_cache=$HOME/.cache
if [ -n "$HOST_XDG_DATA_HOME" ]; then app_data=$HOST_XDG_DATA_HOME; fi
if [ -n "$HOST_XDG_CONFIG_HOME" ]; then app_config=$HOST_XDG_CONFIG_HOME; fi
if [ -n "$HOST_XDG_CACHE_HOME" ]; then app_cache=$HOST_XDG_CACHE_HOME; fi

check_base() {
    name=$1
    value=$2
    case "$value" in
        /*) ;;
        *)
            printf '[FAIL] %s is not an absolute host path: %s\n' "$name" "$value"
            return 1
            ;;
    esac
    if [ "$value" = "/" ]; then
        printf '[FAIL] refusing filesystem root for %s\n' "$name"
        return 1
    fi
    return 0
}

check_base HOME "$HOME"
check_base HOST_XDG_DATA_HOME "$app_data"
check_base HOST_XDG_CONFIG_HOME "$app_config"
check_base HOST_XDG_CACHE_HOME "$app_cache"

printf 'Shanti Flatpak filesystem-permission probe\n'
if [ -n "$FLATPAK_ID" ]; then
    printf 'App ID: %s\n' "$FLATPAK_ID"
else
    printf 'App ID: not-running-under-flatpak\n'
fi
printf 'Sandbox XDG_DATA_HOME: %s\n' "$XDG_DATA_HOME"
printf 'Host XDG data home: %s\n' "$app_data"
printf 'Host XDG config home: %s\n' "$app_config"
printf 'Host XDG cache home: %s\n' "$app_cache"
printf '\nOnly the disposable shanti-flatpak-permission-probe paths below will be written.\n\n'

overall_status=0
probe_root=
probe_dir=
probe_marker=
probe_root_created=0

cleanup_current() {
    if [ -n "$probe_marker" ]; then
        rm -f -- "$probe_marker" 2>/dev/null || true
    fi
    if [ -n "$probe_dir" ]; then
        rmdir -- "$probe_dir" 2>/dev/null || true
    fi
    if [ "$probe_root_created" -eq 1 ] && [ -n "$probe_root" ]; then
        # Non-recursive: this succeeds only if the test root is empty.
        rmdir -- "$probe_root" 2>/dev/null || true
    fi
    probe_root=
    probe_dir=
    probe_marker=
    probe_root_created=0
}
trap cleanup_current 0 HUP INT TERM

probe_path() {
    label=$1
    root=$2

    case "$root" in
        /*) ;;
        *)
            printf '[FAIL] %s: test path is not absolute: %s\n' "$label" "$root"
            overall_status=1
            return 0
            ;;
    esac
    if [ "$root" = "/" ] || [ -L "$root" ]; then
        printf '[FAIL] %s: refusing root or symlinked test directory: %s\n' "$label" "$root"
        overall_status=1
        return 0
    fi

    probe_root=$root
    if [ ! -e "$probe_root" ]; then
        probe_root_created=1
    elif [ ! -d "$probe_root" ]; then
        printf '[FAIL] %s: test path exists but is not a directory: %s\n' "$label" "$probe_root"
        overall_status=1
        probe_root=
        return 0
    fi

    if ! mkdir -p -- "$probe_root"; then
        printf '[FAIL] %s: cannot create the granted test directory: %s\n' "$label" "$probe_root"
        overall_status=1
        cleanup_current
        return 0
    fi

    probe_dir="$probe_root/.run-$$"
    if [ -e "$probe_dir" ] || [ -L "$probe_dir" ] || ! mkdir -- "$probe_dir"; then
        printf '[FAIL] %s: cannot create a unique test directory under: %s\n' "$label" "$probe_root"
        overall_status=1
        cleanup_current
        return 0
    fi

    probe_marker="$probe_dir/probe.txt"
    expected="shanti-flatpak-probe:$label:$$"
    if ! printf '%s\n' "$expected" > "$probe_marker"; then
        printf '[FAIL] %s: cannot write test marker: %s\n' "$label" "$probe_marker"
        overall_status=1
        cleanup_current
        return 0
    fi

    actual=
    IFS= read -r actual < "$probe_marker" || true
    if [ "$actual" = "$expected" ]; then
        printf '[PASS] %s: directory create + file write/read succeeded (%s)\n' "$label" "$probe_root"
    else
        printf '[FAIL] %s: marker read-back did not match (%s)\n' "$label" "$probe_marker"
        overall_status=1
    fi
    cleanup_current
}

probe_path "user-local install area" "$HOME/.local/shanti-flatpak-permission-probe"
probe_path "host XDG data area" "$app_data/shanti-flatpak-permission-probe"
probe_path "host XDG config area" "$app_config/shanti-flatpak-permission-probe"
probe_path "host XDG cache area" "$app_cache/shanti-flatpak-permission-probe"

if [ "$overall_status" -eq 0 ]; then
    printf '\nPASS: all disposable filesystem permission checks succeeded.\n'
else
    printf '\nFAIL: one or more filesystem permission checks failed. No production Shanti paths were touched.\n'
fi

exit "$overall_status"
