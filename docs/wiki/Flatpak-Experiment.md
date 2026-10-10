# Flatpak Distribution Experiment — OpenBangla Keyboard Shanti

> **Project status:** Highly Experimental · Vibe-Coded  
> **Phase:** Planning and feasibility assessment  
> **Working branch:** `experiment/flatpak-ibus`  
> **Project goal:** Easy, reliable, safe installation and maintenance of Shanti on its target Linux systems  
> **Experiment:** Evaluate Flatpak as one possible distribution format  
> **Flathub:** Out of scope

## 1. Overview

OpenBangla Keyboard Shanti's broader goal is to make the keyboard easy to install, update, and remove safely on its target Linux systems, while preserving reliable Bengali input and package/download integrity. The project is aimed particularly at **modern atomic Linux operating systems**, including **Bluefin/Dakota, Bazzite, and similar systems**.

**Flatpak is only a candidate distribution format—not the project's main goal and not a predetermined replacement for the existing installer.** This page records a bounded technical investigation to determine whether Flatpak is a useful additional option. The portable, user-local installer remains an existing distribution path and must not be silently replaced or disrupted. A conventional Linux desktop can be used as a comparison environment where practical; compatibility on any target remains unproven until tested.

## 2. Installer GUI requirement

The Flatpak deliverable must include a **dedicated graphical frontend for the installation/maintenance script**, shipped as a compiled application binary. Do not confuse this installer frontend with the existing `openbangla-gui`, which is the keyboard's runtime/configuration application.

The intended user-facing workflow is to launch the Rust + GTK4/libadwaita installer GUI and use it for installation, configuration, update, status, and removal of the host-side Shanti installation. The Flatpak is a lifecycle/configuration frontend, not the runtime keyboard engine itself; the existing script remains responsible for the underlying installation logic. The GUI and script must be packaged together, with a defined and testable interface for passing actions, progress, diagnostics, and exit status. Do not duplicate installation logic in the GUI.

Design assumption: the target host already has its normal input-method framework installed—IBus or Fcitx5. The Shanti Flatpak must not package or replace that framework. It manages the user-local Shanti engine installation and its registration with the existing host framework. This requirement still leaves a host-integration question: Flatpak does not automatically gain permission to write host installation paths or invoke host-side registration/restart tools. Evaluate narrowly scoped filesystem access and the documented host-command mechanism, and grant only what the chosen lifecycle design demonstrably needs.

The frontend's initial scope should be limited to clear, auditable lifecycle actions (install, update, remove, status, and manager-owned configuration), progress/output reporting, and actionable error messages. The selected frontend direction is Rust with GTK4 and libadwaita. A proposed host-operation contract is recorded in [Flatpak-Installer-Protocol.md](./Flatpak-Installer-Protocol.md); it is not yet implemented.

## 3. Why investigate Flatpak?

The reason to investigate Flatpak is to assess whether it can improve distribution and lifecycle management for some users. It is one option alongside the existing portable installer; it should be adopted only if evidence shows it is practical and worth maintaining. An input method is not an ordinary standalone GUI application: its engine, registration files, session services, and desktop input-method framework must work together.

A GUI that launches successfully inside a sandbox is therefore not sufficient evidence that the keyboard works. The key feasibility question is whether a Flatpak-based package can make Bengali typing work reliably in **ordinary host applications**, with permissions that are limited and documented.

No compatibility, security, or maintenance benefit should be assumed before it has been tested.

## 4. Target and scope

### Overall project target

- Make Shanti easier to install, update, and remove safely on modern atomic Linux operating systems, especially Bluefin/Dakota, Bazzite, and similar systems.
- Preserve reliable Bengali input and strengthen installation/package integrity.
- Keep the existing portable installer available unless evidence and a separate decision justify changing that approach.

### This experiment's scope

- Evaluate Flatpak as an optional additional distribution format, not as the project goal.
- If feasible, use GitHub Releases with a hosted Flatpak repository and a `.flatpakref`.

### Validation target

- At least one conventional Linux desktop environment, where available, to identify which behaviours are specific to the primary target systems.

### Input-method backends to investigate

- **IBus:** investigate and test independently.
- **Fcitx5:** investigate and test independently.

Support for one backend must not be taken as proof of support for the other. The project must explicitly document any backend that cannot be made to work.

### Distribution boundaries

- GitHub Releases are the intended distribution channel for this experiment.
- A hosted Flatpak repository must provide the actual application and repository metadata.
- The `.flatpakref` is a reference that tells Flatpak where to find a remote and which application to install; it is not, by itself, the application bundle or repository.
- Repository signing, update behaviour, and removal instructions must be addressed before distribution is considered ready.
- **Flathub submission is not part of this plan.**

## 5. Goals

1. **Serve the overall project goal.** Any packaging format must make installation, updates, removal, and integrity more reliable for the target systems; Flatpak is worthwhile only if it helps achieve that goal.
2. **Establish feasibility first.** Map the current application layout, executable, bundled Qt/runtime libraries, resources, configuration and data paths, and native dependencies before choosing a packaging design.
3. **Keep the existing installer intact.** Do not replace, silently modify, or make Flatpak a prerequisite for the portable build and installer.
4. **Prove host typing works.** Determine how the engine and its registration communicate with the host IBus or Fcitx5 session, and test Bengali typing in host applications.
5. **Use the smallest workable package.** Start with the narrowest proof of concept that answers a real technical question; do not add a full packaging and release pipeline before feasibility is understood.
6. **Minimise sandbox permissions.** Grant only the access supported by demonstrated requirements. Document any unavoidable exceptions.
7. **Make builds reproducible.** If feasible, build from a clean checkout in a controlled environment and automate the relevant checks in GitHub Actions.
8. **Plan safe distribution and maintenance.** Evaluate repository hosting, signing, releases, updates, application removal, and remote removal.
9. **Make claims match evidence.** Keep the package labelled experimental until the stated acceptance checks have been completed.

## 6. Non-goals

This experiment does not currently aim to:

- Submit the application to Flathub.
- Make Flatpak the project's primary goal or assume it should replace the existing portable installer.
- Redesign the application UI.
- Claim support for every Linux distribution or desktop environment.
- Assume that launching the GUI proves input-method integration.
- Add broad host filesystem or session-bus access merely to make a test pass.
- Publish a user-facing Flatpak release before build, host-typing, installation, update, and removal behaviour have been evaluated.

## 7. Current status

### Completed

- [x] Created the separate `experiment/flatpak-ibus` branch from the validated `develop` revision.
- [x] Recorded the intended GitHub Releases distribution route.
- [x] Recorded that Flathub submission is out of scope.
- [x] Established a staged plan so feasibility is assessed before implementation.

### Not started or not yet verified

- [ ] Source/runtime/resource/configuration path mapping.
- [x] Review the existing installer/uninstaller CLI, its TTY-only choices, release pinning, and host dependencies.
- [x] Review `pmim-ibus` as an input-method packaging precedent and distinguish its Flatpak-contained process from its separately installed host IBus adapter.
- [x] Draft a versioned GUI-to-host-operation contract in [Flatpak-Installer-Protocol.md](./Flatpak-Installer-Protocol.md); it remains a proposal until implemented and tested.
- [ ] Implement the host bridge and non-interactive script support behind tests.
- [ ] Finalise the proof-of-concept permission model and test host execution on target systems.
- [ ] Flatpak runtime and SDK selection.
- [ ] Flatpak manifest and build.
- [ ] Sandboxed application smoke test.
- [ ] Host IBus integration test.
- [ ] Host Fcitx5 integration test.
- [ ] GitHub-hosted Flatpak repository, signing, and `.flatpakref`.
- [ ] Clean installation, update, and removal tests.
- [ ] Flatpak release publication.

**Current evidence boundary:** A read-only host probe and a local regression test now exist. No Flatpak manifest/build, inside-Flatpak host-spawn test, modifying bridge operation, Rust frontend, or host-typing test has been run. The project remains experimental.

## 8. Work plan and checklist

Work through the stages in order. Complete and review one focused task at a time; do not treat the checklist as permission to implement every stage at once.

### Stage 1 — Feasibility and design

- [ ] Map the existing executable, bundled runtime/Qt libraries, resources, engine files, configuration paths, and user data paths.
- [ ] Identify native dependencies and how the current installer arranges files.
- [ ] Determine which parts would run inside Flatpak and which must integrate with the host session.
- [ ] Assume the host already provides either IBus or Fcitx5; map the exact user-local engine/module and registration paths for each backend.
- [ ] Assess required host commands or narrow D-Bus interactions to refresh/restart the existing framework, plus environment propagation and host-visible files.
- [ ] Keep the input-method framework out of the Flatpak; decide how the host-compatible Shanti engine payload is installed and registered by the GUI.
- [ ] Select a suitable GNOME runtime/SDK and define initial architecture and test-environment coverage.
- [ ] Record technical blockers and a minimal design before writing a manifest.

**Stage 1 exit condition:** A reviewed design that describes the package contents, host/sandbox responsibilities, required permissions, and a credible test for sending Bengali keystrokes into host applications.

**Next task:** Stage the read-only probe under the Flatpak's persistent app data, invoke it from inside the sandbox through `flatpak-spawn --host`, and verify the host path and host XDG values on a target system. Keep modifying operations disabled until this passes.

### Stage 2 — Minimal buildable proof of concept

- [ ] Add a manifest for the smallest target justified by Stage 1, including the compiled installer GUI and script where justified.
- [ ] Build from a clean checkout in a reproducible environment.
- [ ] Verify application startup and resource lookup inside the sandbox.
- [ ] Inspect the resulting package contents and permissions.
- [ ] Add focused build and smoke tests to GitHub Actions.

**Stage 2 exit condition:** A repeatable build and passing sandbox smoke test. This does **not** establish that host input-method integration works.

### Stage 3 — Host input-method integration

- [ ] Test IBus independently in a real desktop session.
- [ ] Test Fcitx5 independently if the feasibility assessment supports it.
- [ ] Verify Bengali typing in ordinary host applications outside the Flatpak sandbox.
- [ ] Check session startup, environment propagation, and behaviour after logout/login or restart.
- [ ] Record results and desktop-specific differences.
- [ ] Remove unjustified permissions and document any necessary exceptions.

**Stage 3 exit condition:** Reproducible host-typing evidence for each backend declared supported. Mark any unverified or unsupported backend clearly.

### Stage 4 — GitHub distribution and lifecycle

- [ ] Define how the Flatpak repository and metadata will be published with GitHub Releases.
- [ ] Configure and verify repository signing.
- [ ] Generate and validate a `.flatpakref` with the correct application ID and repository details.
- [ ] Test installation using only the published instructions on a clean test account/system.
- [ ] Test updating from one build to another.
- [ ] Test removing the application and removing the remote as separate actions.
- [ ] Ensure an interrupted or failed publication cannot silently replace known-good repository metadata.
- [ ] Document prerequisites, supported environments, limitations, updates, and removal.

**Stage 4 exit condition:** A clean test system can install, update, and remove the application through the documented GitHub distribution route.

### Stage 5 — Review and decision

- [ ] Summarise test evidence and known compatibility limits.
- [ ] Review permissions, maintenance burden, signing, update reliability, and user experience.
- [ ] Compare the result with the existing portable installation method.
- [ ] Decide whether to continue, narrow the supported scope, or stop the experiment.

**Stage 5 exit condition:** A decision based on recorded evidence. A GUI launch alone is not grounds to replace the portable installer.

## 9. Acceptance criteria

Do not describe the Flatpak experiment as successful until the relevant claims are backed by recorded test results.

- [ ] Build succeeds reproducibly from a clean checkout.
- [ ] The compiled installer GUI starts in the sandbox and finds its required resources.
- [ ] The GUI invokes the packaged script through a defined interface and reports exit status/errors correctly.
- [ ] Bengali typing works in ordinary host applications for every backend claimed as supported.
- [ ] Required host integration and sandbox permissions are documented and minimised.
- [ ] Installation, update, application removal, and remote removal have been tested.
- [ ] The GitHub-hosted repository metadata and `.flatpakref` are reachable and correctly configured; repository signing is verified.
- [ ] Instructions clearly state supported environments and limitations, and do not imply Flathub availability.
- [ ] Existing portable installation and build workflows remain unaffected.

A checklist item should only be marked complete when there is concrete evidence, such as a CI run, a reproducible test procedure, or recorded manual test results.

## 10. Safety and maintenance constraints

- Keep all Flatpak work isolated on `experiment/flatpak-ibus` until a separate integration decision is made.
- Do not change the existing portable installer as a side effect of this experiment.
- Keep generated files and build outputs in clearly scoped locations.
- Do not use broad cleanup or destructive filesystem operations as a packaging shortcut.
- Avoid permissions that expose unnecessary host files or services.
- Do not publish a release or claim backend support without corresponding evidence.
- Record failures and limitations rather than silently working around them.

## 11. Decision record

| Item | Current decision |
|---|---|
| Project status | Highly Experimental · Vibe-Coded |
| Overall project goal | Easy, reliable, safe installation, updates, removal, and package integrity on target systems |
| Target environments | Modern atomic Linux operating systems, especially Bluefin/Dakota, Bazzite, and similar systems |
| Comparison target | A conventional Linux desktop, where practical |
| Host prerequisite | Existing host IBus or Fcitx5 installation; Shanti Flatpak does not install either framework |
| Input methods | Support/registration for IBus and Fcitx5 assessed separately |
| Flatpak's possible distribution route | GitHub Releases with a hosted Flatpak repository and `.flatpakref`, if the experiment justifies it |
| Flathub | Out of scope |
| Existing portable installer | Retain; no replacement decision has been made |
| Installer frontend | Rust + GTK4/libadwaita compiled binary; lifecycle/configuration GUI, separate from the existing Qt keyboard GUI |
| Host operations | Evaluate documented `flatpak-spawn --host` / `org.freedesktop.Flatpak` with a fixed script interface; not yet tested |
| Host-operation contract | Drafted in `docs/wiki/Flatpak-Installer-Protocol.md`; lifecycle plan/apply not implemented |
| Read-only host probe | Implemented at `tools/flatpak/host-bridge.sh`; local regression test at `tests/flatpak/test-host-bridge.sh` passed |
| Inside-Flatpak host bridge | Not tested; host-spawn path and host XDG inheritance remain unverified |
| Host execution candidate | `flatpak-spawn --host` with host XDG paths explicitly restored; trust and runtime environment remain test requirements |
| Implementation status | Source review + read-only probe/test only; no manifest, Flatpak build, or GUI yet |
| Immediate next task | Test staged probe invocation through `flatpak-spawn --host` and verify host path/XDG mapping inside an actual Flatpak |

## 12. Progress log

| Date | Update |
|---|---|
| 2026-10-10 | Created the isolated experiment branch and initial plan. No Flatpak packaging implementation was added. |
| 2026-10-10 | Expanded the page to clarify targets, scope, non-goals, stage exit conditions, acceptance criteria, and current evidence boundaries. |
| 2026-10-10 | Clarified that Flatpak is only a candidate distribution format; the broader goal is easy, safe installation and maintenance on the target systems. |
| 2026-10-10 | Reviewed established Flatpak host-operation patterns, including ProtonUp-Qt host-spawn use and targeted permissions, Flatseal's permission-provider model, and GTK4/libadwaita lifecycle UI references. Proposed a Rust installer frontend and recorded host-command security/dependency constraints. |
| 2026-10-10 | Added requirement for a compiled installer GUI shipped with the script; distinguished it from the existing keyboard GUI and recorded the sandbox/host boundary as unresolved. |
| 2026-10-10 | Selected Rust + GTK4/libadwaita as the installer frontend direction and reviewed PMIM IBus Flatpak's split sandbox/host adapter model. Documented that PMIM is not a general host-access bypass and still requires separate host-side IBus integration. |
| 2026-10-10 | Clarified the target architecture: IBus or Fcitx5 is already installed on the host; the Flatpak manages Shanti's host-compatible user-local engine payload and registration rather than shipping a private input-method framework. |
| 2026-10-10 | Added `Flatpak-Installer-Protocol.md` with a proposed plan/apply JSONL contract, host-environment/XDG handling, explicit decisions for install and removal, current CLI gaps, and bridge acceptance tests. No script or runtime code was changed. |
| 2026-10-10 | Added the read-only `tools/flatpak/host-bridge.sh` probe and `tests/flatpak/test-host-bridge.sh`. Local syntax, JSON, custom-XDG escaping, mocked backend-ambiguity, and fail-closed tests passed. No modifying action is implemented; actual Flatpak host-spawn behaviour remains unverified. |

## 13. Related projects and implementation precedents

This is an initial source review of existing projects. Their existence shows that input-method packaging has been attempted with Flatpak or AppImage; it does not establish that Shanti can use the same integration model.

### Fcitx5 Flatpak and engine extensions

- **Main project:** [fcitx/flatpak-fcitx5](https://github.com/fcitx/flatpak-fcitx5)
- **Main manifest:** [org.fcitx.Fcitx5.yaml](https://github.com/fcitx/flatpak-fcitx5/blob/master/org.fcitx.Fcitx5.yaml)
- **Rime extension manifest:** [org.fcitx.Fcitx5.Addon.Rime.yaml](https://github.com/fcitx/flatpak-fcitx5/blob/master/org.fcitx.Fcitx5.Addon.Rime.yaml)
- **Official setup notes:** [Install Fcitx 5 from Flatpak](https://fcitx-im.org/wiki/Install_Fcitx_5/en)

The Fcitx project packages the Fcitx5 framework as a Flatpak and distributes engines as extension packages. The main manifest declares an extension point under `/app/addons`; the Rime manifest is an extension built against that framework and supplies its own dependencies and data. The framework manifest grants session-bus, Wayland/X11 and other explicit permissions, and gives Fcitx its configuration directories.

**Important limitation:** this model packages the framework and its engine extensions together within the Flatpak environment. The Fcitx documentation explicitly warns that a Flatpak Fcitx installation cannot supply the input-method module libraries required by host applications; a suitable host-side input-method module is still needed. Therefore, it is not proof that a separately packaged Shanti engine can be discovered by a host-installed IBus or Fcitx5.

### Fcitx5 Chinese-engine extension example

- **Project:** [Brli/flatpak.fcitx5-mcbopomofo](https://github.com/Brli/flatpak.fcitx5-mcbopomofo)

This repository describes a Flatpak build for the Chinese Bopomofo engine, based on the extension layout from the main Fcitx Flatpak project. Its README demonstrates building an extension into a local Flatpak repository and exporting it as a bundle. This is a useful reference for extension packaging, but it targets the Flatpak Fcitx ecosystem rather than directly proving host integration for a third-party standalone engine.


### Related Flatpak applications and host-integration patterns

These examples are implementation precedents, not a claim that their exact permissions are appropriate for Shanti.

- **[ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt)** is a Flatpak-distributed installer/updater for compatibility tools. Its Flathub manifest, [`net.davidotek.pupgui2.json`](https://github.com/flathub/net.davidotek.pupgui2/blob/master/net.davidotek.pupgui2.json), grants `--talk-name=org.freedesktop.Flatpak` and several specifically named launcher/data paths rather than simply requesting `--filesystem=host`. Its code contains a concrete `flatpak-spawn --host rm -r …` call for a host-side cleanup case. This demonstrates the supported host-command mechanism in a real installer. Its manifest also grants `--device=all` and has permissions for shell configuration files; these are specific to ProtonUp-Qt's use cases and should **not** be copied into Shanti's manifest.
- **[ProtonPlus](https://github.com/Vysp3r/ProtonPlus)** is a GTK4/libadwaita installer, updater, and remover. Its architecture is a relevant UI and lifecycle reference for a native Linux maintenance app; its current project is primarily Vala, not Rust. Review the current release manifest and actual file access before treating it as a permission precedent.
- **[Flatseal](https://github.com/tchx84/Flatseal)** is a configuration-provider precedent, but for Flatpak permissions rather than keyboard configuration. Its manifest uses targeted read-only access to Flatpak app directories, write access to Flatpak overrides, and named D-Bus interfaces including `org.freedesktop.impl.portal.PermissionStore`; its documentation distinguishes static sandbox permissions from dynamic portal grants. It shows that configuration management can use narrow paths and documented APIs instead of blanket host access.
- **[Warehouse](https://github.com/flattool/warehouse)** is another relevant lifecycle-management UI for Flatpak apps and their user data. It explicitly describes itself as a frontend that facilitates Flatpak operations, rather than replacing Flatpak itself. It is a useful UX reference, but its operations and authorization model are not equivalent to installing a host IBus/Fcitx engine.

Official references: [Flatpak sandbox-permission guidance](https://docs.flatpak.org/en/latest/sandbox-permissions.html), [`flatpak-spawn` command reference](https://docs.flatpak.org/en/latest/flatpak-command-reference.html), and [libflatpak `HostCommand` API](https://docs.flatpak.org/en/latest/libflatpak-api-reference.html).

### What “host access” actually means

Flatpak does not require an unofficial exploit to run a host-side operation. The documented `flatpak-spawn --host` mechanism uses the Flatpak session-bus interface and requires permission to talk to `org.freedesktop.Flatpak`. The corresponding host-command API deliberately lets a trusted application run a command outside its sandbox. This is a supported escape hatch, but it is a **major trust boundary**, not a narrow permission to run only Shanti's installer script: a compromised or misused GUI could launch other commands as the logged-in user. It does not, by itself, grant root access or bypass ordinary Unix user permissions.

For Shanti, the recommended proof of concept is therefore:

1. Build a dedicated Rust + GTK4 + libadwaita installer frontend as the Flatpak's primary binary. Do not confuse it with the existing Qt `openbangla-gui`, which is the keyboard's runtime/configuration application.
2. Keep the existing host lifecycle script as the authority for install/uninstall behaviour initially; do not reimplement its file-management logic in parallel in the GUI.
3. Stage the complete required script tree and companion files into the Flatpak's writable per-application data directory, preserving the layout expected by the scripts. The current `tools/install.sh` sources `tools/portable/common.sh` and `tools/portable/install.sh`, reads `release-tag.txt`, and relies on other repository files, so copying only `install.sh` is not enough. Invoke the staged script as a host process through the documented `flatpak-spawn --host` mechanism, using an argument vector rather than interpolating input into a shell command.
4. The host script must install only the user-local Shanti engine and registration files for the already-installed IBus or Fcitx5 framework. It must not install/replace IBus or Fcitx5, use system paths, or request root privileges for this design.
5. Verify host-side tools and ABI requirements. The existing script uses tools including Bash, curl or wget, Python 3, SHA-256 utilities, and archive/file-management utilities. Run it with the host's tools, not binaries assumed to be available from the Flatpak runtime. Confirm that the downloaded engine can run as a host process, and that the Fcitx5 module matches the host Fcitx5 ABI.
6. Replace terminal-only prompts with explicit, validated operation flags or a structured request/response protocol before wiring the script to a GUI. Existing scripts can ask questions on a TTY when replacing an installation or handling user data; the GUI must present these choices directly and pass an unambiguous answer.
7. Treat installation, update, configuration, status, and removal as distinct operations. Removal should preserve user data by default; cache/data purging must be an explicit separate choice. Updating the Flatpak frontend itself remains a Flatpak remote operation and is separate from updating the host-installed keyboard.

### Initial permission policy

- Do not request `--filesystem=host`, `--filesystem=home`, `--device=all`, system-bus access, or broad session-bus access just to make the host script work.
- The host-command permission must be explicitly documented to users. Treat the Flatpak as high-trust because the host helper runs with the user's normal host permissions.
- Keep host actions fixed to the shipped maintenance scripts and validated operation arguments. Do not provide a generic “run command” or “open terminal as host” feature.
- No `sudo` and no system-wide installation are required for the existing user-local design; do not silently elevate privileges.
- The host IBus/Fcitx5 service is an expected prerequisite, not something this Flatpak should install. Host-side Shanti registration and framework refresh still require validation. The installer frontend's ability to launch does not prove that either engine works in host applications.

**Important evidence boundary:** The projects above demonstrate real Flatpak patterns, and the Flatpak documentation describes the host-command mechanism. They do not yet prove that Shanti's existing script can run successfully from the sandbox boundary or that its external host dependencies are consistently present on Bluefin/Dakota and Bazzite.

### PMIM IBus Flatpak: split sandbox/host integration

- **Flathub package:** [`io.github.fm_elpac.pmim_ibus`](https://github.com/flathub/io.github.fm_elpac.pmim_ibus)
- **Application source and installation instructions:** [`fm-elpac/pmim-ibus`](https://github.com/fm-elpac/pmim-ibus)
- **Manifest:** [`io.github.fm_elpac.pmim_ibus.yml`](https://github.com/flathub/io.github.fm_elpac.pmim_ibus/blob/master/io.github.fm_elpac.pmim_ibus.yml)
- **Host IBus setup instructions:** [`doc/安装.md`](https://github.com/fm-elpac/pmim-ibus/blob/main/doc/%E5%AE%89%E8%A3%85.md)

PMIM is a particularly relevant input-method precedent, but it does **not** simply switch off the Flatpak sandbox. Its manifest grants IPC, X11, PulseAudio, network, DRI and creation access to `xdg-run/pmim`; it does not request `org.freedesktop.Flatpak` or use `flatpak-spawn --host` for general host command execution.

Its published installation instructions explicitly say that the IBus interface module (`librush`) must be installed separately. The host IBus component XML then launches the `ibrus` executable with `--flatpak`; the packaged example points to a binary under the Flatpak app's per-application configuration directory, while the manual instructions describe placing the component XML under the host IBus component directory. The shared `xdg-run/pmim` path is the intended communication boundary between the Flatpak app and the host-side adapter. The exact host setup varies by distribution and may require a package or system configuration step.

**What this teaches Shanti:** split the product into an unprivileged Flatpak frontend/data/configuration side and a minimal host-side integration layer when needed. It is a useful pattern for IBus engine execution. However, PMIM's README and installation instructions show that the Flatpak alone is **not** a fully self-contained, one-click host input-method installation. Its manual/AUR/RPM host setup is an explicit prerequisite, so it does not by itself solve Shanti's desired install/update/remove lifecycle.

For Shanti's proposed installer, compare two different models rather than calling either a sandbox bypass:

1. **Flatpak host command:** the installer invokes its staged lifecycle scripts using the documented `flatpak-spawn --host` mechanism. This can keep the UI and shipped script in one Flatpak, but permission to talk to `org.freedesktop.Flatpak` lets trusted app code launch host commands as the current user. It is a broad trust grant even if the UI exposes only fixed operations.
2. **Separate host adapter:** install/register a narrowly scoped helper or IBus/Fcitx module on the host, then communicate with it through a defined IPC interface. This can make the engine boundary clearer, like PMIM's `librush`, but requires a separate trustworthy way to install/update that helper and adds lifecycle complexity.

PMIM proves that a Flatpak GUI/data process can participate in an input-method design alongside a host-side engine adapter. It does **not** prove that host registration files, IBus modules, Fcitx5 modules, or a user's `~/.local` installation can be changed automatically from a normal Flatpak without a host integration mechanism.

### IBus Rime AppImage

- **Project:** [hchunhui/ibus-rime.AppImage](https://github.com/hchunhui/ibus-rime.AppImage)

This project packages the Chinese Rime engine as an AppImage. Its documented flow runs the AppImage to install/register the engine, then restarts IBus and adds Rime through the input-method settings. The README notes that some distributions may request administrator authentication. This is a useful comparison for portable packaging, but it is **not a Flatpak solution** and does not meet a requirement to avoid host-side installation or privileged integration.

### What these precedents mean for Shanti

1. The closest Flatpak precedent is the Fcitx5 framework plus extension architecture—not a generic Flatpak application that automatically registers an engine with any host input-method framework.
2. We must distinguish a fully Flatpak-contained input-method stack from an engine intended to integrate with the host's existing IBus/Fcitx5 session. They have different boundaries and compatibility requirements.
3. Shanti's current IBus build installs a component descriptor plus an engine executable. Its Fcitx5 build installs a native module plus metadata. These are not interchangeable packaging shapes, so each backend needs its own feasibility result.
4. The host's IBus or Fcitx5 is an assumed prerequisite. Shanti's Flatpak is a manager for a host-compatible, user-local engine payload—not a replacement input-method framework. PMIM provides an alternative precedent using a separately installed host IBus adapter and a narrow shared runtime directory. For Shanti, compare limited host filesystem access plus narrowly scoped framework refresh mechanisms with the documented `flatpak-spawn --host` approach; choose only after testing which host actions are actually required.

### Sources reviewed

- Fcitx Flatpak main manifest and extension point: [org.fcitx.Fcitx5.yaml](https://github.com/fcitx/flatpak-fcitx5/blob/master/org.fcitx.Fcitx5.yaml)
- Rime extension manifest: [org.fcitx.Fcitx5.Addon.Rime.yaml](https://github.com/fcitx/flatpak-fcitx5/blob/master/org.fcitx.Fcitx5.Addon.Rime.yaml)
- Fcitx documentation: [Install Fcitx 5](https://fcitx-im.org/wiki/Install_Fcitx_5/en)
- Chinese engine extension example: [flatpak.fcitx5-mcbopomofo](https://github.com/Brli/flatpak.fcitx5-mcbopomofo)
- IBus Rime AppImage: [ibus-rime.AppImage](https://github.com/hchunhui/ibus-rime.AppImage)

