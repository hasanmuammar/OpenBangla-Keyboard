#!/usr/bin/env bash

package_openbangla() {
    run_builder '
        set -Eeuo pipefail

        install_root="$OBK_STAGE$HOME/.local"
        [[ -d "$install_root" ]] ||
            { echo "Build completed without producing an install tree." >&2; exit 1; }

        arch="$(uname -m)"

        case "$arch" in
            x86_64)
                artifact_arch=x86_64
                ;;
            aarch64|arm64)
                artifact_arch=aarch64
                ;;
            *)
                echo "Unsupported release architecture: $arch" >&2
                exit 1
                ;;
        esac

        artifact_name="openbangla-keyboard_linux_${artifact_arch}_${OBK_BACKEND}.tar.gz"
        output_dir="$OBK_WORKSPACE/dist"

        rm -rf "$output_dir"
        mkdir -p "$output_dir"

        component="$install_root/share/ibus/component/openbangla.xml"
        if [[ -f "$component" ]]; then
            sed -i -E \
                -e 's#<exec>[^<]*</exec>#<exec>@OBK_PREFIX@/libexec/ibus-engine-openbangla --ibus</exec>#' \
                -e 's#<icon>[^<]*</icon>#<icon>@OBK_DATA_HOME@/openbangla-keyboard/icons/OpenBangla-Keyboard.png</icon>#' \
                "$component"
        fi

        desktop="$install_root/share/applications/openbangla-keyboard.desktop"
        if [[ -f "$desktop" ]]; then
            sed -i -E 's#^Exec=.*$#Exec="@OBK_PREFIX@/bin/openbangla-gui" %f#' "$desktop"
        fi

        tar -C "$install_root" -czf "$output_dir/$artifact_name" .

        (
            cd "$output_dir"
            sha256sum "$artifact_name" > "$artifact_name.sha256"
        )

        printf "Created %s\n" "$output_dir/$artifact_name"
    '
}
