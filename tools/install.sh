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

validate_release_checksum() {
    local archive="$1" checksum="$2" expected_asset="$3"
    local digest filename extra actual_digest
    local -a lines=()

    mapfile -t lines < "$checksum"
    [[ "${#lines[@]}" -eq 1 ]] ||
        die "The release checksum file must contain exactly one SHA-256 record."
    read -r digest filename extra <<< "${lines[0]}"
    [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] ||
        die "The release checksum does not contain a valid 64-character SHA-256 digest."
    [[ "$filename" == "$expected_asset" || "$filename" == "*$expected_asset" ]] ||
        die "The release checksum names an unexpected file: $filename"
    [[ -z "${extra:-}" ]] ||
        die "The release checksum contains unexpected extra fields."

    actual_digest="$(sha256sum -- "$archive")"
    actual_digest="${actual_digest%% *}"
    [[ "${actual_digest,,}" == "${digest,,}" ]] ||
        die "The downloaded release failed SHA-256 checksum verification."
    log "SHA-256 checksum verified."
}

validate_release_archive_paths() {
    local archive="$1" listing="$2" member clean component
    local -a components=()
    local -A seen=()

    tar -tzf "$archive" > "$listing" ||
        die "The downloaded release is not a readable tar.gz archive."

    while IFS= read -r member || [[ -n "$member" ]]; do
        [[ "$member" != /* ]] ||
            die "Refusing an archive containing an absolute path: $member"
        clean="$member"
        while [[ "$clean" == ./* ]]; do clean="${clean#./}"; done
        clean="${clean%/}"
        [[ -z "$clean" || "$clean" == "." ]] && continue

        IFS=/ read -r -a components <<< "$clean"
        for component in "${components[@]}"; do
            [[ -n "$component" && "$component" != "." && "$component" != ".." ]] ||
                die "Refusing an archive containing a traversal path: $member"
        done

        case "$clean" in
            bin|bin/*|lib|lib/*|libexec|libexec/*|share|share/*) ;;
            *) die "Refusing an archive containing an unexpected top-level path: $member" ;;
        esac

        [[ -z "${seen[$clean]:-}" ]] ||
            die "Refusing an archive containing a duplicate path: $member"
        seen["$clean"]=1
    done < "$listing"
}

validate_extracted_symlinks() {
    local root="$1" link target resolved
    [[ -d "$root" && ! -L "$root" ]] ||
        die "Refusing to validate an unexpected extraction root: $root"
    while IFS= read -r -d '' link; do
        target="$(readlink -- "$link")" ||
            die "Could not inspect an extracted symbolic link: $link"
        [[ "$target" != /* ]] ||
            die "Refusing an archive containing an absolute symbolic link: $link -> $target"
        resolved="$(realpath -m -- "$(dirname -- "$link")/$target")" ||
            die "Could not resolve an extracted symbolic link safely: $link"
        [[ "$resolved" == "$root" || "$resolved" == "$root/"* ]] ||
            die "Refusing an archive containing a symbolic link that escapes the extraction root: $link -> $target"
    done < <(find "$root" -type l -print0)
}

download_release() {
    local download_root="$OBK_CACHE/downloads"
    local download_dir archive checksum listing staged_root
    mkdir -p "$download_root"
    assert_no_symlink_components "$download_root"
    download_dir="$(mktemp -d "$download_root/$RELEASE_VERSION.XXXXXXXX")" ||
        die "Could not create a fresh download directory."
    archive="$download_dir/$OBK_ASSET"
    checksum="$archive.sha256"
    listing="$download_dir/archive-list.txt"

    log "Downloading the prebuilt OpenBangla Keyboard for $OBK_ARCH / $OBK_BACKEND."
    download "$OBK_DOWNLOAD_URL" "$archive" ||
        die "Could not download the OpenBangla Keyboard release."
    download "$OBK_CHECKSUM_URL" "$checksum" ||
        die "Could not download the release checksum."
    validate_release_checksum "$archive" "$checksum" "$OBK_ASSET"

    if [[ "$VERIFY_PROVENANCE" -eq 1 ]]; then
        log "Verifying signed build provenance for release tag $RELEASE_VERSION."
        gh attestation verify "$archive" \
            --repo "$REPOSITORY" \
            --signer-workflow "$REPOSITORY/.github/workflows/release.yml" \
            --source-ref "refs/tags/$RELEASE_VERSION" ||
            die "Signed build provenance verification failed; the archive will not be installed."
    else
        log "SHA-256 detects corruption; use --verify-provenance to also verify the signed build workflow."
    fi

    validate_release_archive_paths "$archive" "$listing"
    staged_root="$OBK_STAGE$OBK_PREFIX"
    mkdir -p "$staged_root"
    assert_no_symlink_components "$staged_root"
    tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$staged_root"
    validate_extracted_symlinks "$staged_root"

    [[ -x "$staged_root/bin/openbangla-gui" ]] ||
        die "The downloaded release is incomplete: the GUI executable is missing."
    [[ -d "$staged_root/lib/openbangla" ]] ||
        die "The downloaded release is incomplete: the bundled runtime directory is missing."
    [[ -d "$staged_root/share/openbangla-keyboard" ]] ||
        die "The downloaded release is incomplete: application data is missing."
    case "$OBK_BACKEND" in
        ibus)
            [[ -x "$staged_root/libexec/ibus-engine-openbangla" && -f "$staged_root/share/ibus/component/openbangla.xml" ]] ||
                die "The downloaded IBus release is incomplete."
            ;;
        fcitx)
            [[ -f "$staged_root/share/fcitx5/addon/openbangla.conf" && -f "$staged_root/share/fcitx5/inputmethod/openbangla.conf" ]] ||
                die "The downloaded Fcitx release is incomplete."
            ;;
    esac
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
