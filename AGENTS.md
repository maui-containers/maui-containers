# Repository Guidelines

## Project Structure & Module Organization
- `docker/` hosts Docker container images organized by platform
  - `docker/linux/` - Linux MAUI development images
  - `docker/windows/` - Windows MAUI development images
  - `docker/test/` - Appium-enabled Android emulator images (Linux only)
  - `docker/build.ps1` - Unified cross-platform build script
- `tart/` hosts macOS VM images
  - `tart/macos/` - macOS MAUI development VMs
- `provisioning/` contains shared provisioning scripts for all platforms
- Shared PowerShell utilities sit in `common-functions.ps1`; transient build artifacts land in `_temp/`.

## Build, Test, and Development Commands
- `pwsh docker/build.ps1 -DockerPlatform linux/amd64 -Version <tag>` builds and tags the Linux base image.
- `pwsh docker/build.ps1 -DockerPlatform windows/amd64 -Version <tag> [-Push]` builds and tags the Windows base image.
- `pwsh docker/test/build.ps1 -AndroidSdkApiLevel 35 [-Load]` prepares the Android emulator image; add `-Load` to keep it locally.
- `pwsh docker/test/run.ps1 -AndroidSdkApiLevel 35` starts the emulator container with Appium and ADB ports exposed.

## Coding Style & Naming Conventions
- PowerShell scripts begin with `Param` blocks, use PascalCase parameter names, and four-space indentation.
- Prefer splatted hashtables for longer command invocations and guard shared imports with `Join-Path` + `Test-Path`.
- Dockerfiles keep uppercase instructions, group related `RUN` steps, and expose overrides through paired `ARG` and `ENV` values.

## Testing Guidelines
- Rebuild the affected image before merging; follow with `docker/test/run.ps1` to verify emulator, ADB, and Appium endpoints.
- When editing shared helpers, execute at least one Linux and one Windows build path to confirm tool discovery.
- Keep test utilities in verb-form (`build.ps1`, `run.ps1`) and mirror existing naming when adding scripts.

## Commit & Pull Request Guidelines
- Write imperative commit subjects without trailing punctuation (e.g., "Update Android SDK cache").
- Group related Dockerfile and script updates in the same commit and explain version bumps in the body.
- Pull requests must list touched image families, required env vars, and include relevant build or runtime logs.

## Security & Configuration Tips
- Do not bake credentials into images; supply secrets at runtime via `--env-file` or mounted configuration.
- Prefer environment variables such as `INIT_PWSH_SCRIPT` for runtime customization and keep `_temp/` out of version control.
