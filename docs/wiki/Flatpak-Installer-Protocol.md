# Flatpak Installer and Host-Operation Protocol — Shanti

> **Status:** Proposed contract; not implemented  
> **Branch:** `experiment/flatpak-ibus`  
> **Frontend:** Rust + GTK4 + libadwaita  
> **Host prerequisite:** The target session already uses IBus or Fcitx5

This document defines how the Flatpak manager should request safe, user-local Shanti lifecycle operations from the host. It is a design contract, not evidence that the commands or JSON events already exist.

## 1. Responsibility boundary

The Flatpak contains the compiled manager frontend and a versioned copy of the maintenance scripts. It does not contain or start a private IBus/Fcitx5 daemon. The host already supplies the input-method framework; the manager installs and registers the matching Shanti payload for that framework.

- **Frontend:** displays status, release/backend choices, the exact changes planned, confirmations, progress, logs, and outcomes.
- **In-sandbox lifecycle bridge (planned):** accepts a fixed set of lifecycle operations, validates choices, inspects permitted host paths and invokes the packaged maintenance logic from inside the sandbox.
- **Existing scripts:** should remain the authority for archive verification, safe staging, user-local installation, backups, registration, and removal after they are adapted to work inside the sandbox with packaged tools and reviewed filesystem grants. The GUI must not duplicate those filesystem rules.
- **Host framework:** IBus or Fcitx5 remains a host service and must discover and load the installed Shanti engine.

No system-wide package installation, root access, or framework replacement is part of this design.

## 2. Current script gaps found in source review

The existing scripts need a GUI-compatible interface before the manager can call them safely.

### `tools/install.sh`

- Supports `--version TAG` and `--verify-provenance`, but has no explicit backend argument and no non-interactive mode.
- Chooses Fcitx5 for KDE/Plasma and IBus for other desktop-name values. This is not reliable enough for a manager that should verify which framework is present and active.
- May ask on a TTY whether to migrate legacy XDG resources, replace existing paths, and back up or replace the existing bundled runtime. Those questions fail closed when stdin is not a TTY.
- Reads `release-tag.txt` when no version was requested. The checked-in file currently contains `shanti-alpha.1`; therefore, the manager must not treat the existing no-argument behaviour as “install latest.”
- Installs a prebuilt release; the host GUI install path should not call the separate build workflow or bootstrap a package manager/container builder.

### `tools/uninstall.sh`

- Has `--purge-cache` and `--purge-data`, but both require TTY confirmations; removal itself always requires another TTY confirmation.
- Defaults to preserving keyboard data, including custom layouts and autocorrect files. The manager must preserve this default.
- Shows a path list and searches for matching Fcitx files before removal. The GUI needs a read-only plan that surfaces the exact intended targets before a separate apply request.

### Compatibility requirement

Do not simply pipe “yes” into either script. The GUI must provide explicit decisions through validated arguments or a structured request. Missing decisions, unknown options, stale plans, and failed prerequisite checks must stop before modifying the installation.

## 3. Preferred model: narrow filesystem permissions, not host command execution

**Do not make `flatpak-spawn --host` the default installation path.** The preferred proof of concept is for the manager and its maintenance code to run inside the Flatpak sandbox while Flatpak grants access only to the host user directories Shanti actually owns. File operations do not inherently require an out-of-sandbox process.

Flatpak supports specific home-relative paths with read/write/create access. Candidate permission scope (to be tested in a real manifest) is limited to Shanti's program/runtime location, the user-local IBus/Fcitx5 registration directories, the Shanti resource directory, the installer-owned desktop/icon metadata, the small IBus environment configuration file, the relevant Fcitx profile when needed, and the Shanti cache. Examples of the *form* of permissions are `--filesystem=~/.local/share/openbangla-keyboard:create` and `--filesystem=~/.local/share/ibus/component:create`; this is not yet a final list. Avoid `--filesystem=home`, `--filesystem=host`, and blanket writable access to `~/.local` if the exact paths can be granted.

The current portable installer writes to these general areas:

- `~/.local/bin`, `~/.local/lib/openbangla`, and `~/.local/libexec` for launchers, bundled runtime and the IBus engine.
- The host data directory (normally `~/.local/share`) for Shanti resources, IBus component metadata, Fcitx5 addon/input-method metadata, desktop entries, icons, and metainfo.
- The host config directory (normally `~/.config`) for `environment.d/90-openbangla-ibus.conf` and possibly Fcitx5 profile updates.
- The host cache directory (normally `~/.cache/openbangla-keyboard`) for downloads, staging, and build/install state.

The final manifest must grant subpaths only after confirming that Flatpak can create absent target directories safely and that the existing script only writes to the reviewed target list. Some parent directories may also need permission for create/rename operations; don't broaden permissions silently.

### Host XDG paths

Flatpak overrides `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_CACHE_HOME` to use the manager's private per-application storage. It also exposes `HOST_XDG_CONFIG_HOME`, `HOST_XDG_DATA_HOME`, and `HOST_XDG_CACHE_HOME` when host values exist. See [Flatpak conventions](https://docs.flatpak.org/en/latest/conventions.html).

The manager must not confuse its private `XDG_*` values with the user's real host directories. It should resolve the host values from `HOST_XDG_*` where present and otherwise use the standard host defaults. Then it must check that each destination is actually exposed by the declared filesystem permissions. If a user has a custom XDG directory outside the granted locations, the first version should stop with an actionable explanation rather than silently writing into private Flatpak data or requesting broad access.

### No host tools required for file placement

The bridge/install code can use tools shipped inside the Flatpak to download, verify, stage, copy, back up, and remove Shanti files in the specifically exposed directories. These operations don't need host `bash`, `ibus`, `fcitx5-remote`, `systemctl`, or `dconf` just to make file changes. Required utilities must be included in the runtime/build or replaced with tested Rust implementations; do not assume arbitrary host commands are available inside Flatpak.

The installed engine itself must be a host-runnable payload. For IBus, the host component descriptor launches the host-visible engine executable. For Fcitx5, the native module and metadata must be host-visible, and the module must match the host Fcitx5 ABI. The Flatpak is the manager, not the runtime framework or the input-method engine's private execution environment.

### Refresh, status, and backend detection

Directory permissions do not automatically grant visibility into host processes, host executables, or D-Bus methods. Flatpak's process namespace only exposes the app's processes; a sandbox probe must not use `pgrep` or `/proc` to claim it has detected the host IBus/Fcitx5 daemon. The UI can present a backend choice and ask the user to confirm it, and may use session indicators as a *suggestion*, not authoritative detection.

For the first iteration, prefer writing the correct files and telling the user clearly when a logout/login or framework restart is needed. Avoid calling host refresh commands as a requirement for successful file installation. Later, if immediate refresh is worth the complexity, evaluate a narrowly named D-Bus permission/interface or an explicit optional host-command capability on its own merits.

### When `flatpak-spawn --host` might still be useful

Keep host command execution as an **optional fallback**, not a prerequisite, for a future feature that genuinely needs a host-only CLI or immediate refresh and has no suitable D-Bus API. It requires access to `org.freedesktop.Flatpak` and allows trusted application code to execute arbitrary host commands as the logged-in user; it is a significant trust grant. Do not add that permission just to copy files.

## 4. Protocol version 1: plan, then apply

Use JSON Lines (one JSON object per line) on stdout for machine-readable events. Diagnostic text from tools may be captured and exposed as a `log` event; stderr from the bridge is reserved for bridge-level failures. Every object carries `protocol: 1`. The frontend must handle unknown event fields and must fail closed on an unknown protocol version.

The bridge interface has four operation groups. In the preferred filesystem-only model these operations execute inside the Flatpak; read-only framework process detection is not claimed unless implemented through a separately authorised host integration:

| Operation | Purpose | Filesystem changes |
|---|---|---|
| `probe` | Inspect permitted host paths, check packaged tools, report installed files, and capture the user's backend selection where needed; do not claim host-daemon visibility | None |
| `plan` | Calculate an install/update/remove/configuration plan and list exact targets, conflicts and choices | None |
| `apply` | Execute a previously reviewed plan with all required explicit choices | Only the targets permitted by the reviewed plan |
| `status` | Report installed version/backend from managed metadata and verify permitted files; label live daemon status as unknown unless a separately authorised API is used | None |

The initial CLI shape is proposed as:

```text
host-bridge --protocol 1 probe
host-bridge --protocol 1 status
host-bridge --protocol 1 plan --action install --backend ibus --version latest
host-bridge --protocol 1 plan --action update --backend ibus --version latest
host-bridge --protocol 1 plan --action remove
host-bridge --protocol 1 apply --plan-id PLAN_ID --choice NAME=VALUE ...
```

The supported action and choice values are closed enumerations in the bridge; no generic command, arbitrary destination path, or arbitrary script name may be supplied by the UI. The backend value is `ibus` or `fcitx5`, never guessed solely from a desktop-name string. If the manager cannot authoritatively identify the active host backend without extra privileges, ask the user to select one and show any non-authoritative session indicators.

A plan ID binds the apply request to the exact plan shown to the user. Apply must re-check the current installation state and reject an expired or stale plan rather than apply changes to a filesystem state different from the one reviewed. The plan mechanism itself is to be implemented; it does not currently exist.

## 5. Event envelope

The first event for `probe`, `status`, and `plan` is a `report` containing the relevant structured data. An apply operation emits zero or more progress/log events and exactly one terminal result event.

Example plan:

```json
{"protocol":1,"event":"report","operation":"plan","plan_id":"opaque-id","action":"install","backend":"ibus","version":"tag-or-latest","changes":[{"kind":"create","path":"..."}],"warnings":[],"choices":[{"id":"legacy-migration","options":["copy","cancel"],"default":"cancel"}]}
```

Example execution events:

```json
{"protocol":1,"event":"progress","stage":"download","message":"Downloading release"}
{"protocol":1,"event":"log","level":"info","message":"SHA-256 checksum verified"}
{"protocol":1,"event":"result","status":"success","exit_code":0,"message":"Shanti was installed"}
```

Terminal result status is one of `success`, `cancelled`, or `failed`. A failed action includes a stable error code and a user-readable message; detailed diagnostic output can be attached as logs. Do not report success merely because the subprocess exited: run the existing installation verification and a separate backend-registration status check. GUI cancellation must terminate the host operation when it is safe to do so; otherwise warn that the current transaction cannot be interrupted safely.

The concrete field schema and JSON encoder need tests before implementation. Never emit unescaped shell output as if it were JSON.

## 6. Required decisions and action semantics

### Install/update

- Require an explicit backend and version policy. Support a specific validated release tag and a true `latest` policy. Add a distinct installer option or bridge behaviour for “latest” that bypasses the pinned `release-tag.txt`; never assume the existing default means latest.
- The plan lists existing Shanti paths that may be replaced and legacy XDG resources that would be migrated. Preserve original legacy paths when copying/migrating, matching the existing script's intent.
- For an existing runtime bundle, offer backup-and-replace or cancel as the default choices. If no-backup replacement is retained, require a separate explicit warning/confirmation. Never default to permanent deletion.
- Install only to the current user's local prefix and applicable host XDG directories. Do not install IBus/Fcitx5 themselves or invoke package managers.
- Verify download checksum before extraction as today. Provenance verification is an explicit optional action and needs a tag plus host `gh`; the GUI must state when it is not performed.

### Remove

- `plan` displays the exact program, metadata, registration, configuration, and possible Fcitx module paths that would be removed.
- `apply` requires an explicit `confirm-remove=yes` choice even if every path is owned by Shanti.
- Preserve user data by default. Purging user data or build/cache data requires independent choices and separate explicit confirmations (for example, `purge-data=yes` plus `confirm-purge-data=yes`). A missing confirmation is an error, not an implicit “no” followed by partial removal.
- Never delete the Flatpak's own app data as a side effect of uninstalling the host-side Shanti installation. Removing the manager Flatpak is a separate Flatpak operation.

### Configuration and status

The manager may configure its own lifecycle preferences—selected backend, release selection, provenance policy, and data-preservation choices—inside its private app configuration. Do not store these manager preferences in Shanti's host XDG directories.

Keyboard runtime settings are currently handled by the existing Qt `openbangla-gui`; its actual QSettings path and the full configuration interface have not yet been mapped. Do not invent new locations or directly edit settings files until that review is complete. The first manager milestone should report status and provide safe lifecycle controls; keyboard-setting editing can be added only after a separate settings-path review.

## 7. Acceptance tests for the bridge

- [ ] The disposable manifest builds successfully against Freedesktop SDK/runtime 26.08.
- [ ] The probe runs inside Flatpak (verifies `FLATPAK_ID` and `/.flatpak-info`) and succeeds on its four exact test-only filesystem grants.
- [ ] The probe reports sandbox-private `XDG_DATA_HOME` separately from resolved host XDG paths.
- [ ] A dedicated disposable user with custom XDG paths confirms that the `xdg-data`, `xdg-config`, and `xdg-cache` aliases follow those host XDG roots.
- [ ] Production install paths are not touched by the probe; only temporary child files under `shanti-flatpak-permission-probe` roots are created and removed.
- [ ] Probe reports readable/accessible registration paths and current installed-file status without claiming to detect host daemon processes through sandbox `/proc`.
- [ ] The UI asks the user to confirm IBus or Fcitx5 when the active host backend cannot be determined through a narrow, validated signal.
- [ ] Missing dependencies prevent all modifications and produce an actionable report.
- [ ] Plan lists exact target paths and choices, and does not change the filesystem.
- [ ] Stale plans, unknown arguments, unsupported backends and missing decisions fail closed.
- [ ] Install/update verifies the payload before replacement, preserves user-owned layouts/autocorrect data, and checks installed engine/registration state.
- [ ] Removal shows the path plan and preserves user data/cache unless separately confirmed.
- [ ] GUI cancellation, child-process errors, signals and partial failure are shown accurately.
- [ ] Test real Bengali typing in host applications after applying each backend, then test status and removal.
- [ ] Validate on at least Bluefin/Dakota and Bazzite; a sandbox startup test alone is insufficient.

## 8. Implementation status

### Implemented in the repository

- `tools/flatpak/permission-probe.yml` is a disposable manifest for app ID `io.github.hasanmuammar.ShantiFilesystemProbe`, using Freedesktop SDK/runtime `26.08`.
- Its only filesystem grants are the test-only `~/.local/shanti-flatpak-permission-probe`, `xdg-data/shanti-flatpak-permission-probe`, `xdg-config/shanti-flatpak-permission-probe`, and `xdg-cache/shanti-flatpak-permission-probe` roots, each with `:create`. The manifest has no network, host-command, system-bus, home-wide, or host-wide permission.
- `tools/flatpak/filesystem-permission-probe.sh` writes and reads one marker under each disposable root, removes its marker and temporary child non-recursively, prints both sandbox-private and host XDG paths, and refuses to run unless `FLATPAK_ID` and `/.flatpak-info` confirm it is inside Flatpak.
- `tools/flatpak/README.md` provides build/run guidance; `.github/workflows/flatpak-permission-probe.yml` builds and runs the probe on GitHub Actions for matching pushes or manual dispatch.
- The script's file operations were smoke-tested in an isolated temporary-directory simulation, but **that is not a Flatpak sandbox test**. This environment did not have `flatpak` or `flatpak-builder` available, so the real sandbox build/run result must be checked in GitHub Actions.

### Still unverified or not implemented

- Whether the manifest builds and all four declared filesystem grants work in a real Flatpak sandbox.
- Whether `xdg-data`, `xdg-config`, and `xdg-cache` aliases follow custom host XDG locations on target systems.
- Whether production paths such as `~/.local/bin`, `~/.local/lib/openbangla`, IBus registration, Fcitx5 metadata/modules, and user configuration can each be granted without broader access.
- The manager's ability to create/replace/back up/remove only Shanti-owned production files under tested grants.
- Backend refresh and host registration behavior after file placement, including relogin/restart requirements.
- Plan/apply, non-interactive install/update/remove support, the Rust frontend, and the production Flatpak manifest.

**Next task:** inspect the CI run for the disposable manifest, fix any real sandbox failures, then refine a production path-grant list from the actual installer targets. Keep modifying lifecycle operations disabled until grant behavior and path ownership are demonstrated.
