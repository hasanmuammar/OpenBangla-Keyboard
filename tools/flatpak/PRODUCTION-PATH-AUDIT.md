# Production Flatpak path audit

Status: design review only. This is not a production Flatpak manifest and does not authorize filesystem grants.

## Scope

The current portable installer targets a conventional user-local Linux installation. A Flatpak package should not reproduce those install paths mechanically. Flatpak-owned application binaries and immutable resources belong inside the sandbox deployment; only genuine user state and explicitly designed host integration should use host-facing paths.

The project currently documents both IBus and Fcitx5 support. The installer selects IBus by default and selects Fcitx5 for KDE Plasma. The host diagnostic script can detect either active backend, but neither that probe nor the disposable filesystem-permission probe proves that a sandboxed engine can be discovered or can receive text from host applications.

## Path inventory

| Path or path family | Current portable-installer use | Production Flatpak decision |
|---|---|---|
| `/app/bin`, `/app/lib`, `/app/libexec` | Not the current host installer targets | Preferred locations for packaged executables, bundled libraries, and engine launchers, subject to the build layout. Do not grant host access for these. |
| `$HOME/.local/bin/openbangla-gui`, `qt.conf`, `openbangla-gui.bin` | GUI launcher and bundled GUI executable | Replace with Flatpak deployment paths; do not grant `~/.local/bin`. |
| `$HOME/.local/lib/openbangla` | Bundled runtime libraries | Package within the Flatpak; do not grant `~/.local/lib`. |
| `$HOME/.local/libexec/ibus-engine-openbangla` and `.bin` | IBus engine launcher and executable | Package the engine in the sandbox. Host IBus must still be able to discover and launch it; this is an integration design question, not solved by a data-directory grant. |
| `$HOME/.local/lib/fcitx5/openbangla.so` | Fcitx5 module | Important path missing from a generic `~/.local/lib` listing. Do not write this host module from Flatpak by default; determine whether the host Fcitx5 ABI/module-loading model can support the intended design. |
| `$XDG_DATA_HOME/openbangla-keyboard` | Layouts, dictionaries, icons, and application data; migration preserves user edits | Bundle shipped read-only data where possible. Put mutable user data in an app-specific writable data location only if runtime code requires it. Avoid broad host data access. |
| `$XDG_DATA_HOME/ibus/component/openbangla.xml` | IBus component metadata; installer rewrites the engine and icon paths | Host integration candidate, not an automatic permission requirement. Confirm how host IBus discovers metadata and whether it can launch the sandboxed engine. |
| `$XDG_DATA_HOME/fcitx5/addon/openbangla.conf` | Fcitx5 addon metadata | Host integration candidate; verify host discovery and compatibility before granting access. |
| `$XDG_DATA_HOME/fcitx5/inputmethod/openbangla.conf` | Fcitx5 input-method metadata | Host integration candidate; verify host discovery and compatibility before granting access. |
| `$XDG_CONFIG_HOME/environment.d/90-openbangla-ibus.conf` | Writes `IBUS_COMPONENT_PATH` for host-session discovery and attempts to import it into the session | Do not assume a Flatpak app can or should modify host session configuration. A filesystem grant alone will not ensure the environment is applied to an already-running session. |
| `$XDG_CACHE_HOME/openbangla-keyboard/downloads`, `build`, `stage.*` | Installer downloads, builds, and stages release files | These are installer/build caches, not established runtime requirements. Do not grant them to the production app unless a separately designed in-sandbox operation needs a narrowly scoped cache path. |
| `$XDG_DATA_HOME/applications`, `metainfo`, `pixmaps`, `icons/hicolor/*` | Installs desktop entry, metadata, pixmap, and icons to host XDG data directories | Use Flatpak packaging/export mechanisms rather than writable host-directory grants where possible. |
| `$XDG_DATA_HOME/.openbangla-keyboard-backups` and migration marker | Preserves existing data and records legacy migration | Portable-installer migration behaviour. Not a reason to grant host data access to the Flatpak app. |

Here, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` mean the host values resolved by the portable installer, usually under `~/.local/share`, `~/.config`, and `~/.cache` respectively.

## Backend-specific requirements

### IBus

Before defining production grants, validate all of the following in a real desktop session:

1. The host IBus daemon discovers the component metadata.
2. The metadata launches the packaged engine using a supported, stable mechanism.
3. The engine can access its required runtime and data files inside the sandbox.
4. The input method appears in the host input-method selector and accepts text in a host application.
5. Restart, logout/login, update, and uninstall behaviour do not leave stale host registration or configuration.

The current installer writes `IBUS_COMPONENT_PATH`, calls `ibus write-cache`, and may restart IBus. Those host-side effects are not made functional simply by granting access to the component directory.

### Fcitx5

Before defining production grants, validate all of the following in a real desktop session:

1. The host Fcitx5 daemon discovers the addon and input-method metadata.
2. The host can load or otherwise communicate with the engine using a supported architecture and compatible ABI.
3. The input method appears in the selector and accepts text in a host application.
4. Update and uninstall remove or refresh host-visible registration without damaging other Fcitx5 configuration.

The portable installer currently places a module at `$HOME/.local/lib/fcitx5/openbangla.so`. This is not interchangeable with the IBus executable approach and needs an explicit architecture decision for Flatpak.

## Permission-probe interpretation

`permission-probe.yml` intentionally tests only four disposable paths:

- `~/.local/shanti-flatpak-permission-probe`
- `xdg-data/shanti-flatpak-permission-probe`
- `xdg-config/shanti-flatpak-permission-probe`
- `xdg-cache/shanti-flatpak-permission-probe`

A passing run proves that those test grants support create/write/read operations in the tested environment. It does not validate any production path, backend registration, module ABI, or host text entry. Do not copy those grants into a production manifest.

## Decision

Do not add production filesystem grants based only on this inventory. First choose the supported Flatpak integration architecture for IBus and Fcitx5, then test actual discovery and text entry on representative host desktops. Keep app-owned files inside the sandbox and request host access only for a demonstrated, narrowly scoped integration requirement.


## Research finding: recommended integration architecture

External framework documentation confirms that the host integration problem is architectural, not a missing filesystem grant.

- The Fcitx project states that Flatpak cannot provide the input-method module required on the host; that module must be installed natively. Source: https://fcitx-im.org/wiki/Install_Fcitx_5/en (section “Install Fcitx 5 from Flatpak”).
- The current Fcitx5 Flatpak package itself is a separate deployment with its own runtime and addon-extension mechanism. Addons built for that Flatpak Fcitx5 instance are not automatically host-native modules. Source: https://github.com/fcitx/flatpak-fcitx5/blob/master/org.fcitx.Fcitx5.yaml
- Flatpak's historical IBus integration discussion describes host input-method support as a framework/runtime integration concern, not simply a filesystem write permission. Source: https://github.com/flatpak/flatpak/issues/675

### Recommended product split

1. **Flatpak GUI and configuration application:** package GUI, resources, and bundled libraries inside the Flatpak. Use app-private XDG state for genuinely mutable application data. Do not claim that this package alone installs a system-wide/host Bangla input method.
2. **Native input-method integration package:** for full host typing support, build and distribute a host-compatible engine integration separately. For Fcitx5, compile the module against the target distribution's Fcitx5 development ABI and package it natively. For IBus, provide a host-launchable engine plus component metadata using a documented host-compatible runtime strategy. Do not point host metadata at ephemeral or private Flatpak deployment paths.
3. **Distribution-specific delivery:** use native packages or a clearly documented user-local installer for the host engine components. On immutable systems, this may mean a supported layered package, distrobox/toolbox-assisted host packaging workflow, or a native package mechanism supported by that distribution; do not silently write into host framework directories from the GUI Flatpak.
4. **Optional separate all-Flatpak mode:** only claim this if the user runs a compatible Flatpak-hosted input-method daemon and installs the matching engine/addon into that same Flatpak runtime/extension model. This does not establish support for ordinary host-native IBus/Fcitx5 sessions.

### Decision for this branch

Do not implement a production filesystem-permission manifest for host IBus/Fcitx5 paths yet. The recommended architecture is a Flatpak GUI plus a separate native host integration package for full host typing. Treat IBus and Fcitx5 as separate integration targets, and gate support claims on end-to-end tests: discovery, engine launch/module load, selection, real text entry into host applications, restart/update, and clean uninstall.

The research sources establish the host-module constraint for Fcitx5 directly. The IBus recommendation is a conservative engineering conclusion from its external-engine/component model and the project's current installer behaviour; it still requires a proof-of-concept on a real desktop before implementation.
