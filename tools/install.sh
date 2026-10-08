#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/portable/common.sh"
source "$SCRIPT_DIR/portable/environment.sh"
source "$SCRIPT_DIR/portable/build.sh"
source "$SCRIPT_DIR/portable/install.sh"

main() {
    require_linux
    detect_desktop_backend
    select_builder
    prepare_paths

    log "Backend: $OBK_BACKEND"
    log "Build environment: $OBK_BUILDER"
    log "Install prefix: $OBK_PREFIX"

    build_openbangla
    install_openbangla
    verify_installation

    log "OpenBangla Keyboard was installed for the current user."
}

main "$@"
