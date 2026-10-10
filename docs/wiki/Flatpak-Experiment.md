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

## 2. Why investigate Flatpak?

The reason to investigate Flatpak is to assess whether it can improve distribution and lifecycle management for some users. It is one option alongside the existing portable installer; it should be adopted only if evidence shows it is practical and worth maintaining. An input method is not an ordinary standalone GUI application: its engine, registration files, session services, and desktop input-method framework must work together.

A GUI that launches successfully inside a sandbox is therefore not sufficient evidence that the keyboard works. The key feasibility question is whether a Flatpak-based package can make Bengali typing work reliably in **ordinary host applications**, with permissions that are limited and documented.

No compatibility, security, or maintenance benefit should be assumed before it has been tested.

## 3. Target and scope

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

## 4. Goals

1. **Serve the overall project goal.** Any packaging format must make installation, updates, removal, and integrity more reliable for the target systems; Flatpak is worthwhile only if it helps achieve that goal.
2. **Establish feasibility first.** Map the current application layout, executable, bundled Qt/runtime libraries, resources, configuration and data paths, and native dependencies before choosing a packaging design.
3. **Keep the existing installer intact.** Do not replace, silently modify, or make Flatpak a prerequisite for the portable build and installer.
4. **Prove host typing works.** Determine how the engine and its registration communicate with the host IBus or Fcitx5 session, and test Bengali typing in host applications.
5. **Use the smallest workable package.** Start with the narrowest proof of concept that answers a real technical question; do not add a full packaging and release pipeline before feasibility is understood.
6. **Minimise sandbox permissions.** Grant only the access supported by demonstrated requirements. Document any unavoidable exceptions.
7. **Make builds reproducible.** If feasible, build from a clean checkout in a controlled environment and automate the relevant checks in GitHub Actions.
8. **Plan safe distribution and maintenance.** Evaluate repository hosting, signing, releases, updates, application removal, and remote removal.
9. **Make claims match evidence.** Keep the package labelled experimental until the stated acceptance checks have been completed.

## 5. Non-goals

This experiment does not currently aim to:

- Submit the application to Flathub.
- Make Flatpak the project's primary goal or assume it should replace the existing portable installer.
- Redesign the application UI.
- Claim support for every Linux distribution or desktop environment.
- Assume that launching the GUI proves input-method integration.
- Add broad host filesystem or session-bus access merely to make a test pass.
- Publish a user-facing Flatpak release before build, host-typing, installation, update, and removal behaviour have been evaluated.

## 6. Current status

### Completed

- [x] Created the separate `experiment/flatpak-ibus` branch from the validated `develop` revision.
- [x] Recorded the intended GitHub Releases distribution route.
- [x] Recorded that Flathub submission is out of scope.
- [x] Established a staged plan so feasibility is assessed before implementation.

### Not started or not yet verified

- [ ] Source/runtime/resource/configuration path mapping.
- [ ] Decision on the smallest viable proof of concept.
- [ ] Flatpak runtime and SDK selection.
- [ ] Flatpak manifest and build.
- [ ] Sandboxed application smoke test.
- [ ] Host IBus integration test.
- [ ] Host Fcitx5 integration test.
- [ ] GitHub-hosted Flatpak repository, signing, and `.flatpakref`.
- [ ] Clean installation, update, and removal tests.
- [ ] Flatpak release publication.

**Current evidence boundary:** No Flatpak manifest or packaging implementation has been added, and no Flatpak build or host-typing test has been run. The project is still in the planning phase.

## 7. Work plan and checklist

Work through the stages in order. Complete and review one focused task at a time; do not treat the checklist as permission to implement every stage at once.

### Stage 1 — Feasibility and design

- [ ] Map the existing executable, bundled runtime/Qt libraries, resources, engine files, configuration paths, and user data paths.
- [ ] Identify native dependencies and how the current installer arranges files.
- [ ] Determine which parts would run inside Flatpak and which must integrate with the host session.
- [ ] Assess IBus and Fcitx5 registration, D-Bus/session interaction, environment propagation, and required host-visible files.
- [ ] Decide whether the first proof of concept should package only the GUI or include an input-method engine.
- [ ] Select a suitable runtime/SDK and define initial architecture and test-environment coverage.
- [ ] Record technical blockers and a minimal design before writing a manifest.

**Stage 1 exit condition:** A reviewed design that describes the package contents, host/sandbox responsibilities, required permissions, and a credible test for sending Bengali keystrokes into host applications.

**Next task:** Map the current executable, runtime, resource, configuration, and data paths. No manifest should be added before this assessment is recorded.

### Stage 2 — Minimal buildable proof of concept

- [ ] Add a manifest for the smallest target justified by Stage 1.
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

## 8. Acceptance criteria

Do not describe the Flatpak experiment as successful until the relevant claims are backed by recorded test results.

- [ ] Build succeeds reproducibly from a clean checkout.
- [ ] The application starts in the sandbox and finds its required resources.
- [ ] Bengali typing works in ordinary host applications for every backend claimed as supported.
- [ ] Required host integration and sandbox permissions are documented and minimised.
- [ ] Installation, update, application removal, and remote removal have been tested.
- [ ] The GitHub-hosted repository metadata and `.flatpakref` are reachable and correctly configured; repository signing is verified.
- [ ] Instructions clearly state supported environments and limitations, and do not imply Flathub availability.
- [ ] Existing portable installation and build workflows remain unaffected.

A checklist item should only be marked complete when there is concrete evidence, such as a CI run, a reproducible test procedure, or recorded manual test results.

## 9. Safety and maintenance constraints

- Keep all Flatpak work isolated on `experiment/flatpak-ibus` until a separate integration decision is made.
- Do not change the existing portable installer as a side effect of this experiment.
- Keep generated files and build outputs in clearly scoped locations.
- Do not use broad cleanup or destructive filesystem operations as a packaging shortcut.
- Avoid permissions that expose unnecessary host files or services.
- Do not publish a release or claim backend support without corresponding evidence.
- Record failures and limitations rather than silently working around them.

## 10. Decision record

| Item | Current decision |
|---|---|
| Project status | Highly Experimental · Vibe-Coded |
| Overall project goal | Easy, reliable, safe installation, updates, removal, and package integrity on target systems |
| Target environments | Modern atomic Linux operating systems, especially Bluefin/Dakota, Bazzite, and similar systems |
| Comparison target | A conventional Linux desktop, where practical |
| Input methods | Investigate IBus and Fcitx5 separately |
| Flatpak's possible distribution route | GitHub Releases with a hosted Flatpak repository and `.flatpakref`, if the experiment justifies it |
| Flathub | Out of scope |
| Existing portable installer | Retain; no replacement decision has been made |
| Implementation status | Planning only; no manifest or Flatpak build yet |
| Immediate next task | Map current executable, runtime, resource, configuration, and data paths |

## 11. Progress log

| Date | Update |
|---|---|
| 2026-10-10 | Created the isolated experiment branch and initial plan. No Flatpak packaging implementation was added. |
| 2026-10-10 | Expanded the page to clarify targets, scope, non-goals, stage exit conditions, acceptance criteria, and current evidence boundaries. |
| 2026-10-10 | Clarified that Flatpak is only a candidate distribution format; the broader goal is easy, safe installation and maintenance on the target systems. |
