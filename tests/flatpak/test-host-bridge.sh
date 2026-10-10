#!/usr/bin/env bash
# Small regression test for the read-only Shanti Flatpak host probe.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BRIDGE="$ROOT/tools/flatpak/host-bridge.sh"
command -v python3 >/dev/null 2>&1 || {
    printf 'SKIP: python3 is required to validate probe JSON.\n' >&2
    exit 77
}

work="$(mktemp -d "${TMPDIR:-/tmp}/shanti-host-probe-test.XXXXXXXX")"
cleanup() {
    rm -f -- "$work/mockbin/ibus" "$work/mockbin/fcitx5" \
        "$work/mockbin/fcitx5-remote" "$work/mockbin/pgrep" "$work/probe.json" "$work/probe-both.json" "$work/probe-inactive.json" \
        "$work/probe-invalid.json" 2>/dev/null || true
    rmdir -- "$work/mockbin" 2>/dev/null || true
    rmdir -- "$work" 2>/dev/null || true
}
trap cleanup EXIT

# Real-host probe: valid JSON and resolved absolute paths.
bash "$BRIDGE" --protocol 1 probe > "$work/probe.json"
python3 - "$work/probe.json" <<'PY'
import json, pathlib, sys
with open(sys.argv[1], encoding="utf-8") as f:
    report = json.load(f)
assert report["protocol"] == 1
assert report["event"] == "report" and report["operation"] == "probe"
assert pathlib.Path(report["host"]["home"]).is_absolute()
assert pathlib.Path(report["host"]["install_prefix"]).is_absolute()
for name in ("data_home", "config_home", "cache_home"):
    value = report["host"]["xdg"][name]
    assert pathlib.Path(value).is_absolute() and value != "/"
assert isinstance(report["missing_required"], list)
assert report["suggested_backend"] in (None, "ibus", "fcitx5")
assert set(report["backends"]) == {"ibus", "fcitx5"}
PY

# Mock both framework clients. The probe must not guess a backend when both
# sessions respond, and paths containing JSON-special characters must parse.
mkdir -- "$work/mockbin"
cat > "$work/mockbin/ibus" <<'MOCK'
#!/usr/bin/env bash
[[ "${1:-}" == engine ]] && { printf '%s\n' 'mock-engine'; exit 0; }
exit 2
MOCK
cat > "$work/mockbin/fcitx5" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
cat > "$work/mockbin/fcitx5-remote" <<'MOCK'
#!/usr/bin/env bash
[[ "${1:-}" == -n ]] && { printf '%s\n' 'keyboard-us'; exit 0; }
exit 2
MOCK
cat > "$work/mockbin/pgrep" <<'MOCK'
#!/usr/bin/env bash
[[ "${SHANTI_TEST_NO_PROCESSES:-0}" == 1 ]] && exit 1
case " $* " in
    *" ibus-daemon "*) exit 0 ;;
    *" fcitx5 "*) exit 0 ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$work/mockbin/ibus" "$work/mockbin/fcitx5" "$work/mockbin/fcitx5-remote" "$work/mockbin/pgrep"
PATH="$work/mockbin:$PATH" \
XDG_DATA_HOME="$work/data \"quoted\" \\ backslash" \
XDG_CONFIG_HOME="$work/config custom" \
XDG_CACHE_HOME="$work/cache custom" \
bash "$BRIDGE" --protocol 1 probe > "$work/probe-both.json"
python3 - "$work/probe-both.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    report = json.load(f)
assert report["host"]["xdg"]["data_home_source"] == "environment"
assert '"quoted"' in report["host"]["xdg"]["data_home"]
assert "backslash" in report["host"]["xdg"]["data_home"]
assert report["backends"]["ibus"]["process_active"] is True
assert report["backends"]["ibus"]["session_reachable"] is True
assert report["backends"]["ibus"]["current_engine"] == "mock-engine"
assert report["backends"]["fcitx5"]["process_active"] is True
assert report["backends"]["fcitx5"]["session_reachable"] is True
assert report["backends"]["fcitx5"]["current_im"] == "keyboard-us"
assert report["suggested_backend"] is None
assert any("Both IBus and Fcitx5" in msg for msg in report["warnings"])
PY

# When the clients exist but their daemons are absent, the bridge must not query
# them; their mocked response must not make either session look active.
PATH="$work/mockbin:$PATH" SHANTI_TEST_NO_PROCESSES=1 \
XDG_DATA_HOME="$work/data inactive" \
bash "$BRIDGE" --protocol 1 probe > "$work/probe-inactive.json"
python3 - "$work/probe-inactive.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    report = json.load(f)
assert report["backends"]["ibus"]["client_available"] is True
assert report["backends"]["ibus"]["process_active"] is False
assert report["backends"]["ibus"]["session_reachable"] is False
assert report["backends"]["ibus"]["current_engine"] is None
assert report["backends"]["fcitx5"]["daemon_available"] is True
assert report["backends"]["fcitx5"]["process_active"] is False
assert report["backends"]["fcitx5"]["session_reachable"] is False
assert report["backends"]["fcitx5"]["current_im"] is None
PY

# Modifying operations are intentionally not implemented; they must fail closed.
if bash "$BRIDGE" --protocol 1 apply > "$work/probe-invalid.json" 2>/dev/null; then
    printf 'FAIL: unsupported apply operation unexpectedly succeeded.\n' >&2
    exit 1
fi

printf 'PASS: host bridge read-only probe tests.\n'
