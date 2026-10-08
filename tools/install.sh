#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/portable/common.sh"
source "$SCRIPT_DIR/portable/install.sh"

REPOSITORY="hasanmuammar/OpenBangla-Keyboard"
REQUESTED_VERSION="${OPENBANGLA_VERSION:-}"
RELEASE_VERSION="latest"
RELEASE_BASE=""

usage() {
    cat <<'EOF'
Usage: tools/install.sh [options]

Install the latest prebuilt OpenBangla Keyboard for Linux.

Options:
  --version VERSION   Install a specific release version.
  -h, --help          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            [[ $# -ge 2 ]] || die "--version requires a release version."
            REQUESTED_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

detect_backend() {
    case "${XDG_CURRENT_DESKTOP:-}:${XDG_SESSION_DESKTOP:-}:${DESKTOP_SESSION:-}" in
        *KDE*|*kde*|*PLASMA*|*plasma*) OBK_BACKEND=fcitx ;;
        *) OBK_BACKEND=ibus ;;
    esac
    export OBK_BACKEND
}

detect_arch() {
    case "$(uname -m)" in
        x86_64) OBK_ARCH=x86_64 ;;
        aarch64|arm64) OBK_ARCH=aarch64 ;;
        *)
            die "Unsupported Linux architecture: $(uname -m). Prebuilt releases are currently available for x86_64 and ARM64."
            ;;
    esac
    export OBK_ARCH
}

download() {
    local url="$1" output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --retry-delay 2 "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --show-progress "$url" -O "$output"
    else
        die "curl or wget is required to download OpenBangla Keyboard."
    fi
}

build_urls() {
    local asset="openbangla-keyboard_linux_${OBK_ARCH}_${OBK_BACKEND}.tar.gz"
    if [[ -n "$REQUESTED_VERSION" ]]; then
        RELEASE_VERSION="${REQUESTED_VERSION#v}"
        RELEASE_BASE="https://github.com/$REPOSITORY/releases/download/v$RELEASE_VERSION"
    else
        RELEASE_BASE="https://github.com/$REPOSITORY/releases/latest/download"
    fi
    OBK_ASSET="$asset"
    OBK_DOWNLOAD_URL="$RELEASE_BASE/$asset"
    OBK_CHECKSUM_URL="$OBK_DOWNLOAD_URL.sha256"
    export RELEASE_VERSION OBK_ASSET OBK_DOWNLOAD_URL OBK_CHECKSUM_URL
}

download_release() {
    local download_dir="$OBK_CACHE/downloads/$RELEASE_VERSION"
    local archive="$download_dir/$OBK_ASSET"
    local checksum="$archive.sha256"

    mkdir -p "$download_dir"
    log "Downloading the prebuilt OpenBangla Keyboard for $OBK_ARCH / $OBK_BACKEND."

    download "$OBK_DOWNLOAD_URL" "$archive" ||
        die "Could not download the OpenBangla Keyboard release."
    download "$OBK_CHECKSUM_URL" "$checksum" ||
        die "Could not download the release checksum."

    (
        cd "$download_dir"
        sha256sum -c "$(basename "$checksum")"
    ) || die "The downloaded release failed checksum verification."

    OBK_STAGE="$download_dir/stage"
    rm -rf "$OBK_STAGE"
    mkdir -p "$OBK_STAGE$OBK_PREFIX"
    tar -xzf "$archive" -C "$OBK_STAGE$OBK_PREFIX"

    [[ -x "$OBK_STAGE$OBK_PREFIX/bin/openbangla-gui" ]] ||
        die "The downloaded release is incomplete."

    export OBK_STAGE
}

main() {
    require_linux
    detect_backend
    detect_arch
    prepare_paths
    build_urls

    log "Backend: $OBK_BACKEND"
    log "Architecture: $OBK_ARCH"
    log "Release: $RELEASE_VERSION"

    download_release
    install_openbangla
    verify_installation

    log "OpenBangla Keyboard was installed for the current user."
    log "Need to rebuild from source? Use: bash tools/build.sh"
}

main "$@"
