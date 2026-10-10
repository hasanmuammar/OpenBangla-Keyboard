# Flatpak Experiment — Shanti

**Status:** Planning and feasibility assessment  
**Branch:** `experiment/flatpak-ibus`  
**Distribution target:** GitHub Releases with a `.flatpakref` and a hosted Flatpak repository  
**Flathub submission:** Out of scope

This is a highly experimental, vibe-coded packaging experiment aimed at modern atomic Linux operating systems, including Bluefin, Bazzite, and similar systems. It must remain separate from the existing user-local installer until the experiment demonstrates a reliable installation and input-method workflow.

## Purpose

Determine whether OpenBangla Keyboard Shanti can be packaged and installed as a Flatpak without compromising Bengali input-method integration with the host desktop.

The experiment is successful only if the packaged application can be installed, updated, and removed predictably and the selected input method works in ordinary host applications—not merely inside the Flatpak sandbox.

## Targets and goals

1. **Prove feasibility before building a complete package.** Identify the runtime, build dependencies, application data paths, Qt requirements, and architecture constraints.
2. **Keep the current installer intact.** Flatpak work must not replace or silently change `tools/install.sh`, the portable build, or the uninstaller.
3. **Validate host input-method integration.** Investigate IBus and Fcitx5 separately. Determine which processes and D-Bus interfaces must run on the host, which files must be visible to the host, and what sandbox permissions are actually necessary.
4. **Test the target environments.** Start with Bluefin/Dakota, then test at least one conventional Linux desktop if available. Do not assume success on one desktop proves compatibility with the other.
5. **Support a practical release route.** The intended experiment is distributed from GitHub Releases using a `.flatpakref` and a reachable, signed Flatpak repository. A `.flatpakref` by itself is not the application bundle or repository; it points Flatpak to a repository from which the app and updates can be obtained.
6. **Keep updates and trust explicit.** Document repository signing, update behavior, release publication, and how users can remove the remote and application.
7. **Avoid unnecessary permissions.** Request only the filesystem, D-Bus, session, and host-integration access demonstrated to be necessary.
8. **Do not claim production readiness.** Treat this as a proof of concept until installation, updates, removal, and real host typing have been tested.

## Current progress

- [x] Created the isolated `experiment/flatpak-ibus` branch from the validated `develop` revision.
- [x] Recorded GitHub Releases plus `.flatpakref` as the intended distribution route.
- [x] Kept Flathub submission out of scope.
- [ ] No Flatpak manifest, build workflow, repository, or installable reference has been created yet.
- [ ] No Flatpak build or sandbox test has been run.
- [ ] Host IBus/Fcitx5 integration has not yet been demonstrated.
- [ ] No release has been published for this experiment.

## To-do list

Work through these stages in order. Do not skip ahead or implement every stage at once.

### Stage 1 — Feasibility and design

- [ ] Map the existing executable, bundled Qt/runtime libraries, resources, and configuration/data paths.
- [ ] Decide whether the first proof of concept should package the GUI only or include a host input-method engine.
- [ ] Document the host responsibilities versus sandbox responsibilities for IBus and Fcitx5.
- [ ] Choose a Flatpak runtime and SDK compatible with the project's Qt and native dependencies.
- [ ] Define the minimum supported architectures and test environments.
- [ ] Record any blockers before writing a manifest.

**Exit condition:** A reviewed, minimal packaging design with an explicit answer for how Bengali keystrokes reach host applications.

### Stage 2 — Minimal buildable proof of concept

- [ ] Add one manifest for the smallest useful target.
- [ ] Build it in a clean, reproducible environment.
- [ ] Confirm that the app starts and finds its resources inside the sandbox.
- [ ] Inspect permissions and generated package contents.
- [ ] Add focused build and smoke tests to GitHub Actions.

**Exit condition:** A repeatable CI build and a working sandboxed smoke test. This alone does not prove host input-method integration.

### Stage 3 — Host input-method integration

- [ ] Test IBus integration independently.
- [ ] Test Fcitx5 integration independently, if feasible.
- [ ] Confirm typing in host applications outside the Flatpak sandbox.
- [ ] Verify session startup, environment propagation, logout/login behavior, and desktop-specific differences.
- [ ] Reject broad permissions or host filesystem workarounds unless a test demonstrates they are necessary.

**Exit condition:** A documented host-typing test passes for each backend declared supported. Any unsupported backend must be clearly marked unsupported.

### Stage 4 — Distribution and updates

- [ ] Publish a Flatpak repository from the GitHub release workflow.
- [ ] Configure and verify repository signing.
- [ ] Generate a `.flatpakref` that points to the published repository and correct application ID.
- [ ] Test installation from a clean user account using only the documented release instructions.
- [ ] Test updating from one build to another.
- [ ] Test removing the app and, separately, removing its repository remote.
- [ ] Verify that failed publication does not silently replace the last known-good repository metadata.

**Exit condition:** A user can install, update, and uninstall from the documented GitHub release route on a clean test system.

### Stage 5 — Decision

- [ ] Summarize compatibility, maintenance cost, sandbox exceptions, and user experience.
- [ ] Compare the Flatpak route with the existing portable installer.
- [ ] Decide whether to continue, narrow the supported scope, or stop the experiment.

**Exit condition:** An evidence-based decision. Do not replace the portable installer merely because the GUI launches in Flatpak.

## Acceptance checklist

The experiment is not considered successful until the relevant items below have evidence attached to the wiki or CI:

- [ ] Reproducible build from a clean checkout.
- [ ] Application starts inside the sandbox and resolves its resources.
- [ ] Bengali typing works in host applications for every backend claimed as supported.
- [ ] No unneeded broad filesystem or session-bus permissions.
- [ ] Install, update, and removal tested on a clean account.
- [ ] GitHub-hosted repository metadata and `.flatpakref` are reachable and correctly signed/configured.
- [ ] Release instructions explain limitations and do not imply Flathub availability.
- [ ] Existing portable installation and workflows remain unaffected.

## Decisions and constraints

- **Separate branch:** `experiment/flatpak-ibus`
- **Distribution:** GitHub Releases, with a hosted Flatpak repository and `.flatpakref`
- **Flathub:** Not part of this experiment
- **Existing installer:** Must remain available and unchanged by default
- **Order of work:** Feasibility first, then a minimal proof of concept, then host integration, then distribution
- **Safety rule:** Do not perform broad cleanup or destructive filesystem operations as part of packaging experiments. Keep build outputs in isolated, clearly scoped directories.
- **Current decision:** Planning only. The next step is Stage 1, task 1: map the existing executable and runtime/resource paths. No manifest should be added until that assessment is recorded.

## Progress log

| Date | Update |
|---|---|
| 2026-10-10 | Created the isolated experiment branch and this planning page. No Flatpak packaging implementation has been added. |
