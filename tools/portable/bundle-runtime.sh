#!/usr/bin/env bash
set -Eeuo pipefail

runtime_lib_dir="$1"
runtime_plugin_dir="$2"
stage_dir="$3"
qt_lib_dir="$4"

host_library() {
    case "$1" in
        libc.so*|libm.so*|libpthread.so*|libdl.so*|librt.so*|libresolv.so*|libcrypt.so*|libutil.so*|libanl.so*|libnss_*.so*|libgcc_s.so*|libstdc++.so*|ld-linux*.so*|ld-musl-*.so*|libGL.so*|libEGL.so*|libGLX.so*|libX11.so*|libX11-xcb.so*|libxcb*.so*|libXau.so*|libXdmcp.so*|libXext.so*|libXfixes.so*|libXi.so*|libXrender.so*|libXrandr.so*|libXcursor.so*|libXdamage.so*|libXcomposite.so*|libwayland*.so*|libdecor*.so*|libdrm.so*|libinput.so*|libudev.so*|libfontconfig.so*|libfreetype.so*|libexpat.so*|libdbus-1.so*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

queue=()
declare -A seen=()

enqueue() {
    local library="$1"
    [[ -f "$library" ]] || return 0
    [[ "${seen[$library]:-0}" -eq 1 ]] && return 0
    seen["$library"]=1
    queue+=("$library")
}

enqueue "$stage_dir$HOME/.local/bin/openbangla-gui"
enqueue "$stage_dir$HOME/.local/libexec/ibus-engine-openbangla"
for library in "$runtime_lib_dir"/*.so* "$runtime_plugin_dir"/platforms/*.so*; do
    enqueue "$library"
done

while ((${#queue[@]})); do
    library="${queue[0]}"
    queue=("${queue[@]:1}")

    while IFS= read -r dependency_line; do
        dependency="${dependency_line##*=> }"
        [[ "$dependency" == /* ]] || continue
        dependency="${dependency%% *}"
        [[ -f "$dependency" ]] || continue

        dependency_name="${dependency##*/}"
        host_library "$dependency_name" && continue

        resolved_dependency="$(readlink -f "$dependency")"
        [[ -f "$resolved_dependency" ]] || continue

        target="$runtime_lib_dir/$dependency_name"
        if [[ -L "$target" ]]; then
            rm -f "$target"
        fi
        if [[ ! -e "$target" ]]; then
            cp -a "$resolved_dependency" "$target"
        fi

        enqueue "$target"
    done < <(LD_LIBRARY_PATH="$runtime_lib_dir:$qt_lib_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ldd "$library" 2>/dev/null)
done
