# OpenBangla Keyboard Fork — Shanti Project Checklist

**Codename: Shanti**

Last verified: 2026-10-09  
Branch: `develop`  
Current commit: `bd4e0c739d8619f6afa83342328fe343239bdc1e`

This checklist separates what is implemented, what is verified, what is configured but not yet exercised end-to-end, and what remains before the first public prebuilt release.

## 1. Project direction and scope

- [x] Linux-only fork established.
- [x] Conventional Linux and immutable/image-based Linux are the primary targets.
- [x] User-local installation under `~/.local`.
- [x] System-wide package installation is no longer the normal installation model.
- [x] Cross-platform packaging/code that is not needed for the Linux fork was removed.
- [x] IBus and Fcitx5 are supported as separate backend builds.
- [x] x86_64 and ARM64/aarch64 are the target prebuilt architectures.
- [x] Prebuilt releases are treated as complete runtime bundles, not single standalone executables.
- [ ] Public release/versioning policy is finalised and used for the first fork release.

## 2. User-facing installation architecture

- [x] `tools/install.sh` is now the normal user installer.
- [x] Installer detects x86_64 versus ARM64/aarch64.
- [x] Installer selects IBus outside KDE/Plasma and Fcitx5 on KDE/Plasma.
- [x] Installer downloads a matching prebuilt release archive.
- [x] Installer downloads and verifies a SHA-256 checksum.
- [x] Installer installs the staged tree into the current user's `~/.local`.
- [x] Specific-version installation is supported with `--version`.
- [x] `curl` and `wget` download paths are supported.
- [x] Unsupported CPU architectures fail with a clear error.
- [ ] End-to-end installer test against an actual published release.
- [ ] Installer test on a real ARM64 user system.
- [ ] Installer test on a real non-KDE/IBus system.
- [ ] Installer test on a real KDE/Fcitx5 system using a published archive.

## 3. Source-build/developer architecture

- [x] `tools/build.sh` is the explicit source-build entry point.
- [x] `--backend ibus` and `--backend fcitx` are supported.
- [x] `--package` creates a prebuilt release archive.
- [x] `-y/--yes` supports non-interactive source builds.
- [x] Host builds can be selected for release CI.
- [x] Toolbx, Distrobox, Podman and Docker builder paths are implemented.
- [x] Podman fallback/bootstrap logic is implemented.
- [x] Persistent Podman builder support is implemented.
- [x] Build dependency caching is implemented.
- [x] Temporary build-environment confirmation is implemented for source builds.
- [x] Temporary builder cleanup is implemented after successful source builds.
- [ ] Final developer-build documentation reviewed against the actual current script behaviour.

## 4. Runtime bundling and installation integration

- [x] Qt5 runtime libraries are bundled.
- [x] Required Linux runtime dependencies are collected into the staged installation.
- [x] Runtime dependency scanning/bundling logic has been separated into portable tooling.
- [x] libproxy runtime/backend handling was added to the bundle.
- [x] Bundled runtime launchers are implemented.
- [x] GUI and input-method launchers are made executable.
- [x] Bundled runtime paths are configured so the application can use its staged libraries.
- [x] IBus component registration and cache regeneration are implemented.
- [x] User-local IBus component path persistence is implemented.
- [x] Fcitx5 addon metadata is installed and validated.
- [x] User-local uninstallation is implemented.
- [ ] Verify the complete runtime bundle by installing and running a release archive outside the build environment.
- [ ] Verify actual text input through IBus after a clean install.
- [ ] Verify actual text input through Fcitx5 after a clean install.
- [ ] Verify the GUI and input engine on both supported CPU architectures.

## 5. Current build issue / CI status

- [x] The previous GUI linker failure was identified: `SingleInstance.cpp` was not part of the GUI target.
- [x] `SingleInstance.cpp` and `SingleInstance.h` were added to `src/frontend/CMakeLists.txt`.
- [x] Fix committed as `bd4e0c739d8619f6afa83342328fe343239bdc1e`.
- [x] Latest CI run #82 completed successfully.
- [x] x86_64 + GCC + IBus passed.
- [x] x86_64 + GCC + Fcitx5 passed.
- [x] x86_64 + Clang + IBus passed.
- [x] x86_64 + Clang + Fcitx5 passed.
- [x] ARM64 + GCC + IBus passed.
- [x] ARM64 + GCC + Fcitx5 passed.
- [x] CMake configuration passed for all six latest CI variants.
- [x] Compilation passed for all six latest CI variants.
- [ ] Runtime/functional input testing is not yet covered by CI.

## 6. Release packaging

- [x] Release packaging entry point exists through `tools/build.sh --package`.
- [x] Release archives are gzip-compressed tar archives.
- [x] Archive names distinguish architecture and backend.
- [x] SHA-256 sidecar files are generated.
- [x] GitHub Actions release workflow exists.
- [x] Release workflow is configured for four artifacts:
  - x86_64 / IBus
  - x86_64 / Fcitx5
  - ARM64 / IBus
  - ARM64 / Fcitx5
- [x] Release workflow is configured to create a GitHub Release from `v*.*.*` tags.
- [x] Release workflow is configured to upload the generated archives and checksums.
- [ ] Successful GitHub release build has not yet been verified.
- [ ] First `v3.0.0` tag has not yet been created.
- [ ] First fork GitHub Release has not yet been published.
- [ ] Release assets have not yet been published.
- [ ] Prebuilt installer has not yet been tested against published release assets.
- [ ] First public release has not yet been deployed.

Current repository facts:
- `version.txt` is `3.0.0`.
- Existing inherited repository tags currently go only through `2.0.0`.
- There are currently no published Releases in the fork.

## 7. Documentation

- [x] English README updated for the fork.
- [x] Bangla README updated for the fork.
- [x] Installation documentation updated for prebuilt releases.
- [x] Development documentation updated for source builds.
- [x] Portable tooling documentation updated.
- [x] Architecture documentation exists.
- [x] Uninstallation documentation exists.
- [x] Troubleshooting documentation exists.
- [ ] Remove or consolidate any remaining duplicate manual-CMake instructions where they conflict with the preferred `tools/build.sh` workflow.
- [ ] Add a release-validation/test procedure to the documentation.

## 8. Repository cleanup and project structure

- [x] Obsolete cross-platform packaging/code was removed.
- [x] Linux-specific project structure is documented.
- [x] `tools/install.sh` is clearly separated from `tools/build.sh` in the documentation.
- [x] `docs/wiki/` contains fork-specific documentation.
- [x] `dist/` release output is ignored by Git.
- [x] Riti and Corrosion remain tracked as submodules.
- [ ] Review the repository once more before the first release for stale references to the old source-first installer model.

## 9. Known issues/blockers before first public release

- [ ] Resolve the prebuilt installation wrapping path before release. The current packaging step wraps the GUI/IBus binaries, while the generic installation step also wraps executable files; this needs a single, unambiguous wrapping stage.
- [ ] Add an archive-content validation step to release CI.
- [ ] Add a release smoke test that runs the packaged `openbangla-gui --version`.
- [ ] Add backend-specific smoke validation where practical.
- [ ] Verify that Fcitx5 registration behaves correctly after installing the published archive.
- [ ] Verify that IBus registration survives logout/reboot on a clean system.
- [ ] Confirm release workflow produces all four archives successfully on a real version tag.
- [ ] Test the final installer on at least one x86_64 system and one ARM64 system before publication.

## 10. Definition of done for the first public release

The first release should not be considered complete until all of the following are checked:

- [ ] Clean source checkout builds successfully in CI on all six CI variants.
- [ ] Release packaging succeeds on all four release variants.
- [ ] Four release archives and four checksum files are uploaded.
- [ ] A `v3.0.0` GitHub Release exists.
- [ ] `tools/install.sh` successfully downloads the correct archive on x86_64 and ARM64.
- [ ] IBus installation is functionally tested.
- [ ] Fcitx5 installation is functionally tested.
- [ ] GUI starts from the installed runtime bundle.
- [ ] Input engine works after a clean install.
- [ ] Uninstaller removes the user-local installation cleanly.
- [ ] Release documentation matches the final published assets.
