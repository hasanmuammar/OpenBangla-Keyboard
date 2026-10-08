#!/usr/bin/env bash

package_openbangla() {
    run_builder '
        set -Eeuo pipefail

        install_root="$OBK_STAGE$HOME/.local"
        [[ -d "$install_root" ]] ||
            { echo "Build completed without producing an install tree." >&2; exit 1; }

        version="$(head -n1 "$OBK_WORKSPACE/version.txt")"
        arch="$(uname -m)"

        if [[ -x "$install_root/bin/openbangla-gui" ]]; then
            mv -f "$install_root/bin/openbangla-gui" "$install_root/bin/openbangla-gui.bin"
            cp "$OBK_WORKSPACE/tools/portable/launch-bundled.sh" "$install_root/bin/openbangla-gui"
            chmod +x "$install_root/bin/openbangla-gui"
        fi

        if [[ -x "$install_root/libexec/ibus-engine-openbangla" ]]; then
            mv -f "$install_root/libexec/ibus-engine-openbangla" "$install_root/libexec/ibus-engine-openbangla.bin"
            cp "$OBK_WORKSPACE/tools/portable/launch-bundled.sh" "$install_root/libexec/ibus-engine-openbangla"
            chmod +x "$install_root/libexec/ibus-engine-openbangla"
        fi

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

        tar -C "$install_root" -czf "$output_dir/$artifact_name" .

        (
            cd "$output_dir"
            sha256sum "$artifact_name" > "$artifact_name.sha256"
        )

        printf "Created %s\n" "$output_dir/$artifact_name"
    '
}
