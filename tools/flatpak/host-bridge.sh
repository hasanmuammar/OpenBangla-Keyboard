#!/usr/bin/env bash
# Read-only host-context diagnostic for development only.
# This script must run in the host context; it cannot discover host processes
# from inside Flatpak's isolated process namespace. The preferred manager path
# uses scoped filesystem permissions and does not invoke this script by default.
# No install/update/remove command is exposed.
set -uo pipefail
export LC_ALL=C

usage() {
    cat <<'USAGE'
Usage: host-bridge.sh --protocol 1 probe

Read-only discovery of the current host's user paths, lifecycle dependencies,
and IBus/Fcitx5 availability. This command does not modify files or restart services.
USAGE
}

fail() {
    printf 'host-bridge: %s\n' "$*" >&2
    exit "${2:-64}"
}

[[ $# -eq 3 && "$1" == "--protocol" && "$2" == "1" && "$3" == "probe" ]] || {
    usage >&2
    fail 'unsupported operation or protocol; only --protocol 1 probe is implemented'
}

[[ "$(uname -s 2>/dev/null)" == Linux ]] || fail 'Linux is required' 69
[[ "${HOME:-}" == /* && -d "$HOME" ]] || fail 'HOME must be an existing absolute directory' 69
command -v realpath >/dev/null 2>&1 || fail 'required host command is missing: realpath' 69

host_home="$(realpath -e -- "$HOME" 2>/dev/null)" || fail 'could not resolve HOME safely' 69
[[ "$host_home" != / ]] || fail 'refusing to use filesystem root as HOME' 69
host_uid="$(id -u 2>/dev/null)" || fail 'could not determine the current user ID' 69

# Inspect process state before querying a framework client. Calling a client
# while its daemon is absent could trigger D-Bus activation on some systems.
process_is_active() {
    local expected="$1" procfile pid comm proc_uid
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -u "$host_uid" -x "$expected" >/dev/null 2>&1
        return $?
    fi
    for procfile in /proc/[0-9]*/comm; do
        [[ -r "$procfile" ]] || continue
        IFS= read -r comm < "$procfile" || continue
        [[ "$comm" == "$expected" ]] || continue
        pid="${procfile#/proc/}"
        pid="${pid%/comm}"
        proc_uid="$(awk '$1 == "Uid:" { print $2; exit }' "/proc/$pid/status" 2>/dev/null)" || continue
        [[ "$proc_uid" == "$host_uid" ]] && return 0
    done
    return 1
}

# Resolve a valid absolute XDG path without creating or changing any directory.
resolve_xdg() {
    local var="$1" fallback="$2" raw source resolved
    raw="${!var:-}"
    if [[ "$raw" == /* && "$raw" != / ]]; then
        source=environment
        resolved="$(realpath -m -- "$raw" 2>/dev/null)" || resolved=""
        if [[ "$resolved" != /* || "$resolved" == / ]]; then
            source=default
            resolved="$(realpath -m -- "$fallback" 2>/dev/null)" || resolved=""
        fi
    else
        source=default
        resolved="$(realpath -m -- "$fallback" 2>/dev/null)" || resolved=""
    fi
    [[ "$resolved" == /* && "$resolved" != / ]] || return 1
    XDG_RESOLVED="$resolved"
    XDG_SOURCE="$source"
}

resolve_xdg XDG_DATA_HOME "$host_home/.local/share" || fail 'could not resolve host XDG_DATA_HOME safely' 69
host_data_home="$XDG_RESOLVED"
host_data_source="$XDG_SOURCE"
resolve_xdg XDG_CONFIG_HOME "$host_home/.config" || fail 'could not resolve host XDG_CONFIG_HOME safely' 69
host_config_home="$XDG_RESOLVED"
host_config_source="$XDG_SOURCE"
resolve_xdg XDG_CACHE_HOME "$host_home/.cache" || fail 'could not resolve host XDG_CACHE_HOME safely' 69
host_cache_home="$XDG_RESOLVED"
host_cache_source="$XDG_SOURCE"

# JSON string encoder. LC_ALL=C makes substring iteration byte-based; UTF-8
# bytes are emitted unchanged, while JSON control characters are escaped.
json_quote() {
    local value="$1" out='' char code escaped i
    for ((i = 0; i < ${#value}; i++)); do
        char="${value:i:1}"
        case "$char" in
            '"') out+='\"' ;;
            "\\") out+='\\' ;;
            $'\b') out+='\b' ;;
            $'\f') out+='\f' ;;
            $'\n') out+='\n' ;;
            $'\r') out+='\r' ;;
            $'\t') out+='\t' ;;
            *)
                printf -v code '%d' "'$char"
                if (( code < 32 )); then
                    printf -v escaped '\\u%04x' "$code"
                    out+="$escaped"
                else
                    out+="$char"
                fi
                ;;
        esac
    done
    printf '"%s"' "$out"
}

json_command_path() {
    local p
    p="$(command -v -- "$1" 2>/dev/null || true)"
    json_quote "$p"
}

json_command_available() {
    if command -v -- "$1" >/dev/null 2>&1; then printf true; else printf false; fi
}

# Required for install/remove with the currently shipped shell implementation.
missing_required=()
for cmd in bash python3 sha256sum tar realpath find mountpoint cp mv rm install sed awk grep cmp mktemp uname id; do
    command -v -- "$cmd" >/dev/null 2>&1 || missing_required+=("$cmd")
done
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    missing_required+=("curl-or-wget")
fi

ibus_path="$(command -v ibus 2>/dev/null || true)"
ibus_client_available=false
ibus_process_active=false
ibus_session_reachable=false
ibus_current_engine=''
if [[ -n "$ibus_path" ]]; then ibus_client_available=true; fi
if [[ "$ibus_client_available" == true ]] && process_is_active ibus-daemon; then
    ibus_process_active=true
    ibus_current_engine="$(ibus engine 2>/dev/null)"
    ibus_rc=$?
    if (( ibus_rc == 0 )) && [[ -n "$ibus_current_engine" ]]; then
        ibus_session_reachable=true
    else
        ibus_current_engine=''
    fi
fi

fcitx5_path="$(command -v fcitx5 2>/dev/null || true)"
fcitx5_remote_path="$(command -v fcitx5-remote 2>/dev/null || true)"
fcitx5_daemon_available=false
fcitx5_remote_available=false
fcitx5_process_active=false
fcitx5_session_reachable=false
fcitx5_current_im=''
if [[ -n "$fcitx5_path" ]]; then fcitx5_daemon_available=true; fi
if [[ -n "$fcitx5_remote_path" ]]; then fcitx5_remote_available=true; fi
if [[ "$fcitx5_daemon_available" == true ]] && process_is_active fcitx5; then
    fcitx5_process_active=true
    if [[ "$fcitx5_remote_available" == true ]]; then
        fcitx5_current_im="$(fcitx5-remote -n 2>/dev/null)"
        fcitx5_rc=$?
        if (( fcitx5_rc == 0 )) && [[ -n "$fcitx5_current_im" ]]; then
            fcitx5_session_reachable=true
        else
            fcitx5_current_im=''
        fi
    fi
fi

suggested_backend=''
if [[ "$ibus_session_reachable" == true && "$fcitx5_session_reachable" != true ]]; then
    suggested_backend=ibus
elif [[ "$fcitx5_session_reachable" == true && "$ibus_session_reachable" != true ]]; then
    suggested_backend=fcitx5
fi

warnings=()
if [[ "$ibus_session_reachable" != true && "$fcitx5_session_reachable" != true ]]; then
    warnings+=("No active IBus or Fcitx5 session was confirmed by a read-only client query.")
elif [[ "$ibus_session_reachable" == true && "$fcitx5_session_reachable" == true ]]; then
    warnings+=("Both IBus and Fcitx5 sessions responded; the manager must ask the user to choose a backend.")
fi
if ((${#missing_required[@]} > 0)); then
    warnings+=("One or more commands used by the current maintenance scripts are missing; install/update/remove must remain disabled until they are resolved.")
fi

# Emit one JSON object so the Rust frontend can parse stdout as a single report.
printf '{"protocol":1,"event":"report","operation":"probe","host":{'
printf '"os":"linux","home":%s,"uid":%s,"install_prefix":%s,"xdg":{' \
    "$(json_quote "$host_home")" "$host_uid" "$(json_quote "$host_home/.local")"
printf '"data_home":%s,"data_home_source":%s,' "$(json_quote "$host_data_home")" "$(json_quote "$host_data_source")"
printf '"config_home":%s,"config_home_source":%s,' "$(json_quote "$host_config_home")" "$(json_quote "$host_config_source")"
printf '"cache_home":%s,"cache_home_source":%s}},' "$(json_quote "$host_cache_home")" "$(json_quote "$host_cache_source")"
printf '"tools":{"required":{' 
first=1
for cmd in bash python3 sha256sum tar realpath find mountpoint cp mv rm install sed awk grep cmp mktemp uname id; do
    (( first )) || printf ','
    printf '%s:%s' "$(json_quote "$cmd")" "$(json_command_available "$cmd")"
    first=0
done
printf ',"curl_or_wget":%s},"paths":{' \
    "$(if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then printf true; else printf false; fi)"
first=1
for cmd in bash python3 curl wget sha256sum tar realpath find mountpoint cp mv rm install sed awk grep cmp mktemp uname id ibus fcitx5 fcitx5-remote dbus-update-activation-environment systemctl dconf pgrep; do
    (( first )) || printf ','
    printf '%s:%s' "$(json_quote "$cmd")" "$(json_command_path "$cmd")"
    first=0
done
printf '}},"missing_required":['
for ((i=0; i<${#missing_required[@]}; i++)); do
    (( i == 0 )) || printf ','
    json_quote "${missing_required[i]}"
done
printf '],"backends":{"ibus":{"client_available":%s,"process_active":%s,"session_reachable":%s,"current_engine":' "$ibus_client_available" "$ibus_process_active" "$ibus_session_reachable"
if [[ -n "$ibus_current_engine" ]]; then json_quote "$ibus_current_engine"; else printf null; fi
printf ',"component_dir":%s},' "$(json_quote "$host_data_home/ibus/component")"
printf '"fcitx5":{"daemon_available":%s,"remote_available":%s,"process_active":%s,"session_reachable":%s,"current_im":' "$fcitx5_daemon_available" "$fcitx5_remote_available" "$fcitx5_process_active" "$fcitx5_session_reachable"
if [[ -n "$fcitx5_current_im" ]]; then json_quote "$fcitx5_current_im"; else printf null; fi
printf ',"user_module_dir":%s,"user_addon_dir":%s,"user_inputmethod_dir":%s}},' \
    "$(json_quote "$host_home/.local/lib/fcitx5")" \
    "$(json_quote "$host_data_home/fcitx5/addon")" \
    "$(json_quote "$host_data_home/fcitx5/inputmethod")"
printf '"suggested_backend":'
if [[ -n "$suggested_backend" ]]; then json_quote "$suggested_backend"; else printf null; fi
printf ',"warnings":['
for ((i=0; i<${#warnings[@]}; i++)); do
    (( i == 0 )) || printf ','
    json_quote "${warnings[i]}"
done
printf ']}\n'
