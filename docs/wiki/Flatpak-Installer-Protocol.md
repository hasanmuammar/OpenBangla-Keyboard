# Flatpak Installer and Host-Operation Protocol — Shanti

> **Status:** Proposed contract; not implemented  
> **Branch:** `experiment/flatpak-ibus`  
> **Frontend:** Rust + GTK4 + libadwaita  
> **Host prerequisite:** The target session already uses IBus or Fcitx5

This document defines how the Flatpak manager should request safe, user-local Shanti lifecycle operations from the host. It is a design contract, not evidence that the commands or JSON events already exist.

## 1. Responsibility boundary

The Flatpak contains the compiled manager frontend and a versioned copy of the maintenance scripts. It does not contain or start a private IBus/Fcitx5 daemon. The host already supplies the input-method framework; the manager installs and registers the matching Shanti payload for that framework.

- **Frontend:** displays status, release/backend choices, the exact changes planned, confirmations, progress, logs, and outcomes.
- **Host bridge:** accepts a fixed set of lifecycle operations, validates choices, probes prerequisites, and invokes the existing maintenance scripts.
- **Existing scripts:** remain the authority for archive verification, safe staging, user-local installation, backups, registration, and removal. The GUI must not duplicate those filesystem rules.
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

## 3. Host invocation model

### Proposed proof of concept

Use the documented `flatpak-spawn --host` mechanism to run a fixed, shipped host bridge, with `org.freedesktop.Flatpak` as the required D-Bus permission. Use a process argument vector; never construct a shell command by concatenating version strings, paths, or GUI input.

A conceptual invocation is:

```text
flatpak-spawn --host /usr/bin/bash <host-visible-bridge-path> --protocol 1 ...
```

The bridge and its script tree must be staged under the app's own persistent data directory, which maps to the host path under `~/.var/app/<APP_ID>/data/`. The bridge must confirm that this staged path is visible and executable in the host environment before running any modifying action. Do not try to execute a path that exists only under the Flatpak's `/app` mount.

This grants the trusted Flatpak code the ability to invoke host commands as the current user; it is not a script-only capability. Document that trust boundary. Do not add `--filesystem=host`, `--filesystem=home`, a system-bus grant, or root elevation as a shortcut.

### Host environment and XDG paths

Flatpak redirects `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` to app-private directories. A host command must **not** inherit those app-private values as the destinations for Shanti's real user-local install. Flatpak exposes host values as `HOST_XDG_DATA_HOME`, `HOST_XDG_CONFIG_HOME` and `HOST_XDG_CACHE_HOME` when those variables exist on the host. The bridge must use those values when present and otherwise apply the XDG defaults:

- data: `$HOME/.local/share`
- config: `$HOME/.config`
- cache: `$HOME/.cache`

Validate all resolved paths as absolute, non-root paths. Pass the resolved host values explicitly to the host process using `flatpak-spawn --env=...`; don't forward the Flatpak's private `XDG_*_HOME` values as host paths. This environment mapping and the session D-Bus/runtime variables must be verified on Bluefin/Dakota and Bazzite before lifecycle operations are considered supported.

References: [Flatpak environment conventions](https://docs.flatpak.org/en/latest/conventions.html), [sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html), and [`flatpak-spawn` options](https://man7.org/linux/man-pages/man1/flatpak-spawn.1.html).

### Host prerequisites

The bridge performs a read-only dependency check before any modifying operation. At minimum, check the tools the current scripts use: Bash, curl or wget, Python 3, `sha256sum`, tar, `realpath`, `find`, `mountpoint`, and standard file utilities. Check backend-specific tools such as `ibus`, `dbus-update-activation-environment`, `systemctl --user`, `dconf`, or `fcitx5-remote` only where applicable. `gh` is optional unless provenance verification is requested.

Do not install host packages automatically. If a required command is missing, report the exact dependency and leave the existing installation untouched.

## 4. Protocol version 1: plan, then apply

Use JSON Lines (one JSON object per line) on stdout for machine-readable events. Diagnostic text from tools may be captured and exposed as a `log` event; stderr from the bridge is reserved for bridge-level failures. Every object carries `protocol: 1`. The frontend must handle unknown event fields and must fail closed on an unknown protocol version.

The bridge interface has four operation groups:

| Operation | Purpose | Filesystem changes |
|---|---|---|
| `probe` | Detect host framework(s), required commands, current installation and supported actions | None |
| `plan` | Calculate an install/update/remove/configuration plan and list exact targets, conflicts and choices | None |
| `apply` | Execute a previously reviewed plan with all required explicit choices | Only the targets permitted by the reviewed plan |
| `status` | Report installed version, backend, engine/registration status and actionable warnings | None |

The initial CLI shape is proposed as:

```text
host-bridge --protocol 1 probe
host-bridge --protocol 1 status
host-bridge --protocol 1 plan --action install --backend ibus --version latest
host-bridge --protocol 1 plan --action update --backend ibus --version latest
host-bridge --protocol 1 plan --action remove
host-bridge --protocol 1 apply --plan-id PLAN_ID --choice NAME=VALUE ...
```

The supported action and choice values are closed enumerations in the bridge; no generic command, arbitrary destination path, or arbitrary script name may be supplied by the UI. The backend value is `ibus` or `fcitx5`, never guessed solely from a desktop-name string. If both frameworks are present and the active session cannot be determined confidently, ask the user to select one and show the detected evidence.

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

- [ ] Host path for the staged bridge resolves correctly from inside the Flatpak, including on Bluefin/Dakota where home is commonly under `/var/home`.
- [ ] Host XDG values are correct when default and custom XDG paths are used; app-private XDG paths are never used for the host install.
- [ ] Probe detects IBus, Fcitx5, both, or neither without modifying files; the UI handles ambiguous cases by asking.
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

- `tools/flatpak/host-bridge.sh` implements only `--protocol 1 probe`. It emits one JSON report and deliberately rejects other operations.
- `tests/flatpak/test-host-bridge.sh` covers the report shape, absolute path resolution, custom XDG paths containing quotes/backslashes, mock IBus/Fcitx5 sessions, ambiguous-backend handling, and rejection of an unimplemented `apply` operation.
- The test script was run against the local bridge copy in a Linux shell and passed. This is a local shell/mock test, not a test inside Flatpak or on Bluefin/Dakota or Bazzite.

### Still unverified or not implemented

- Calling the staged bridge through `flatpak-spawn --host` from inside the actual Flatpak.
- Confirming that the staged bridge path resolves from both the sandbox and host, and that the spawned process receives host XDG values rather than app-private XDG values.
- Live IBus/Fcitx5 discovery on the target desktop sessions.
- Plan/apply, non-interactive install/update/remove support, the Rust frontend, and the Flatpak manifest.

**Next task:** verify the bridge staging and host-environment boundary in a minimal Flatpak on a target system. Keep modifying actions disabled until this is demonstrated. After that, add non-interactive plan/apply support behind tests while retaining the existing interactive CLI behaviour for current users.
