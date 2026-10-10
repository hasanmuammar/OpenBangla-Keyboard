#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/portable/common.sh"
source "$SCRIPT_DIR/portable/install.sh"

REPOSITORY="hasanmuammar/OpenBangla-Keyboard-Shanti"
REQUESTED_VERSION="${OPENBANGLA_VERSION:-}"
RELEASE_VERSION="latest"
RELEASE_BASE=""
VERIFY_PROVENANCE=0
RELEASE_TAG_FILE="$SCRIPT_DIR/../release-tag.txt"

usage() {
    cat <<'EOF'
Usage: tools/install.sh [options]

Install the prebuilt OpenBangla Keyboard build specified by release-tag.txt for this fork.

Options:
  --version TAG      Install a specific Shanti release tag.
  --verify-provenance Verify signed build provenance (requires gh and a versioned tag).
  -h, --help          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            [[ $# -ge 2 ]] || die "--version requires a release tag."
            REQUESTED_VERSION="$2"
            shift 2
            ;;
        --verify-provenance)
            VERIFY_PROVENANCE=1
            shift
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
        RELEASE_VERSION="$REQUESTED_VERSION"
    fi
    if [[ ! "$RELEASE_VERSION" =~ ^[A-Za-z0-9._-]+$ ]]; then
        die "Invalid release tag: $RELEASE_VERSION. Use only letters, numbers, dots, underscores, and hyphens."
    fi
    if [[ "$VERIFY_PROVENANCE" -eq 1 ]]; then
        [[ -n "$REQUESTED_VERSION" && "$RELEASE_VERSION" != "latest" ]] ||
            die "--verify-provenance requires a specific release tag (use --version TAG or set release-tag.txt)."
        command -v gh >/dev/null 2>&1 ||
            die "--verify-provenance requires the GitHub CLI (gh). Install it separately and retry."
    fi
    if [[ -n "$REQUESTED_VERSION" ]]; then
        RELEASE_BASE="https://github.com/$REPOSITORY/releases/download/$RELEASE_VERSION"
    else
        RELEASE_BASE="https://github.com/$REPOSITORY/releases/latest/download"
    fi
    OBK_ASSET="$asset"
    OBK_DOWNLOAD_URL="$RELEASE_BASE/$asset"
    OBK_CHECKSUM_URL="$OBK_DOWNLOAD_URL.sha256"
    export RELEASE_VERSION OBK_ASSET OBK_DOWNLOAD_URL OBK_CHECKSUM_URL
}

download_release() {
    local download_root="$OBK_CACHE/downloads"
    local download_dir
    mkdir -p "$download_root"
    download_dir="$(mktemp -d "$download_root/$RELEASE_VERSION.XXXXXXXX")" ||
        die "Could not create a fresh download directory."
    local archive="$download_dir/$OBK_ASSET"
    local checksum="$archive.sha256"

    log "Downloading the prebuilt OpenBangla Keyboard for $OBK_ARCH / $OBK_BACKEND."

    download "$OBK_DOWNLOAD_URL" "$archive" ||
        die "Could not download the OpenBangla Keyboard release."
    download "$OBK_CHECKSUM_URL" "$checksum" ||
        die "Could not download the release checksum."

    (
        cd "$download_dir"
        sha256sum -c "$(basename "$checksum")"
    ) || die "The downloaded release failed checksum verification."

    # OBK_STAGE was created uniquely by prepare_paths. Keep older staging
    # data intact instead of recursively deleting a fixed path.
    mkdir -p "$OBK_STAGE$OBK_PREFIX"
    tar -xzf "$archive" -C "$OBK_STAGE$OBK_PREFIX"

    [[ -x "$OBK_STAGE$OBK_PREFIX/bin/openbangla-gui" ]] ||
        die "The downloaded release is incomplete."

    export OBK_STAGE
}

main() {
    require_linux

    if [[ -z "$REQUESTED_VERSION" && -f "$RELEASE_TAG_FILE" ]]; then
        REQUESTED_VERSION="$(tr -d '[:space:]' < "$RELEASE_TAG_FILE")"
    fi
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
