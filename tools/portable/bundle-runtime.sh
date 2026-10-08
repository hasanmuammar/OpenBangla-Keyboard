#!/usr/bin/env bash
set -Eeuo pipefail

runtime_lib_dir="$1"
runtime_plugin_dir="$2"
stage_dir="$3"

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

changed=1
while [[ "$changed" -eq 1 ]]; do
    changed=0

    for library in \
        "$stage_dir$HOME/.local/bin/openbangla-gui" \
        "$stage_dir$HOME/.local/libexec/ibus-engine-openbangla" \
        "$runtime_lib_dir"/*.so* \
        "$runtime_plugin_dir"/platforms/*.so*; do
        [[ -f "$library" ]] || continue

        while IFS= read -r dependency_line; do
            dependency="${dependency_line##*=> }"
            [[ "$dependency" == /* ]] || continue
            dependency="${dependency%% *}"
            [[ -f "$dependency" ]] || continue

            dependency_name="${dependency##*/}"
            host_library "$dependency_name" && continue

            target="$runtime_lib_dir/$dependency_name"
            if [[ ! -e "$target" ]]; then
                cp -a "$dependency" "$target"
                changed=1
            fi
        done < <(ldd "$library" 2>/dev/null)
    done
done
