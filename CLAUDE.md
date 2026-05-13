# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository provides development environments for .NET MAUI across multiple platforms:

1. **Docker Images** (`docker/`) - Container images for Linux and Windows
   - `docker/linux/` - Linux MAUI development images
   - `docker/windows/` - Windows MAUI development images
   - `docker/test/` - Testing environment with Appium and Android Emulator (Linux only)
2. **Tart VM Images** (`tart/macos/`) - macOS virtual machine images
3. **Provisioning Module** (`provisioning/`) - PowerShell module for provisioning native macOS hosts

Images provide MAUI development tooling and generic startup hooks so users can add their own runner or automation setup after the image starts.

## Build Commands

### Building Docker Images
```powershell
# Linux image
./docker/build.ps1 -DockerPlatform "linux/amd64" -DotnetVersion "9.0" -DockerRepository "your-repo/maui-build"

# Windows image
./docker/build.ps1 -DockerPlatform "windows/amd64" -DotnetVersion "9.0" -DockerRepository "your-repo/maui-build"

# Individual platform build scripts are also available
./docker/linux/build.ps1 -DotnetVersion "9.0" -DockerRepository "your-repo/maui-build" -Version "latest"
./docker/windows/build.ps1 -DotnetVersion "9.0" -DockerRepository "your-repo/maui-build" -Version "latest"
```

### Building Emulator Images
```powershell
# Build emulator images with specific Android API level
./docker/test/build.ps1 -DotnetVersion "9.0" -AndroidSdkApiLevel 35 -DockerRepository "your-repo/maui-testing"
./docker/test/build.ps1 -DotnetVersion "10.0" -AndroidSdkApiLevel 35 -DockerRepository "your-repo/maui-testing"

# Run a test container
./docker/test/run.ps1 -AndroidSdkApiLevel 35
```

### Checking for Workload Updates
```powershell
# Check for .NET workload updates
./check-workload-updates.ps1 -DotnetVersion "9.0"
./check-workload-updates.ps1 -DotnetVersion "10.0"
```

## Architecture and Key Components

### Workload Management System
The repository uses a sophisticated workload management system (`common-functions.ps1`) that:
- Automatically discovers the latest .NET workload sets from NuGet
- **Auto-detects** when prerelease versions are needed (when no stable versions exist)
- Extracts Android SDK requirements, Java versions, and API levels from workload manifests
- Converts between NuGet package versions and dotnet CLI workload versions
- Downloads and parses workload dependency information

**Smart Prerelease Detection**: The system first searches for stable workload sets using precise SDK band pattern matching. If none are found (like with .NET 10), it automatically enables prerelease search. This ensures:
- .NET 9: Always uses stable versions (9.305.0)
- .NET 10: Automatically uses prerelease versions (RC1, previews, etc.)
- Future versions: Automatically adapts when stable versions become available

**Precise Package Filtering**: Uses SDK band pattern matching (`Microsoft.NET.Workloads.{major}.{band}(-{prerelease})?`) to correctly identify workload sets while excluding architecture-specific packages like `.Msi.x64`.

Key functions:
- `Find-LatestWorkloadSet` - Finds latest workload set with intelligent prerelease auto-detection
- `Get-WorkloadSetInfo` - Gets complete workload set information
- `Get-AndroidWorkloadInfo` - Extracts Android-specific requirements
- `Get-LatestAppiumVersions` - Gets latest Appium versions from npm

### Docker Image Hierarchy
```
Docker Base Image (MAUI Dev)
    ↓
Test Image (Base + Appium + Android Emulator)
```

### Platform Support
- **Linux**: `linux/amd64` - Full support for all image types
- **Windows**: `windows/amd64` - Base images only (Test images Linux-only)

### .NET Version Support
- **.NET 8**: Stable release workloads (8.414.0)
- **.NET 9**: Stable release workloads (9.305.0)
- **.NET 10**: Prerelease workloads (RC1, previews) - automatically detected
- **Future versions**: Auto-adapts when stable versions become available

### Android API Level Management
The build system:
- Automatically detects required API levels from workload dependencies
- Supports building images for API levels 23-35
- Uses workload-recommended API levels by default but allows overrides

### GitHub Actions Integration
Comprehensive CI/CD workflows in `.github/workflows/`:
- `check-workload-updates.yml` - Monitors for workload updates and triggers builds
- `build-docker-linux.yml` - Builds Linux Docker images
- `build-docker-windows.yml` - Builds Windows Docker images
- `build-emulators.yml` - Builds Android emulator images for multiple API levels
- `build-tart-vms.yml` - Builds macOS Tart VM images
- `pr-validation.yml` - Validates PRs with test builds

## Common Parameters

Most build scripts accept these common parameters:
- `DotnetVersion` - .NET version (e.g., "9.0")
- `WorkloadSetVersion` - Specific workload set version (optional, auto-detected if not specified)
- `DockerRepository` - Docker repository name
- `DockerPlatform` - Target platform (linux/amd64 or windows/amd64)
- `Version` - Docker tag version
- `Push` - Whether to push to registry
- `Load` - Whether to load image locally

## Development Workflow

1. Make changes to Dockerfiles or build scripts
2. Test locally using individual build scripts
3. **PR Validation**: Automatic build testing on pull requests (no publishing)
4. Use GitHub Actions workflows for full CI/CD pipeline
5. All builds use the workload management system to ensure consistent versions

### PR Testing
The repository includes a dedicated PR validation workflow (`pr-validation.yml`) that:
- Automatically runs on PRs targeting main branch
- Tests Docker image builds without publishing
- Validates workload discovery for all .NET versions
- Provides three test modes: `single-platform`, `base-only`, or `all`
- See `.github/PR-VALIDATION.md` for detailed usage guide

## Key Environment Variables

### Common Initialization Variables:
- `INIT_PWSH_SCRIPT` - Custom PowerShell initialization script
- `INIT_BASH_SCRIPT` - Custom bash initialization script (Linux only)

For test images:
- Android emulator and Appium are pre-configured and auto-started
- Requires `--device /dev/kvm` for nested virtualization
- Maps ports 5554, 5555 (emulator/ADB) and 4723 (Appium)

## Testing

The test images (`docker/test/`) are designed for UI testing with Appium and include:
- Pre-installed Android Emulator for specified API level
- Appium Server with UIAutomator2 driver
- Automatic service startup on container launch
- Support for mapping APK volumes for testing

## macOS Provisioning Module

### Overview
The `provisioning/` directory contains a PowerShell module (`MauiProvisioning`) that provisions macOS hosts with the same developer tooling available in the Docker base images. This allows developers to build and test MAUI applications directly on macOS hardware without containers.

### Module Architecture

The provisioning system is organized as a PowerShell module located at `provisioning/MauiProvisioning/` with:
- **Public/**: Contains the main entry point `Invoke-MauiProvisioning.ps1`
- **Private/**: Helper functions for internal use
- **MauiProvisioning.psd1**: Module manifest defining exports and metadata
- **MauiProvisioning.psm1**: Module loader that imports all functions

### Key Components Installed

1. **.NET SDK**: Latest SDK for the specified channel (e.g., 9.0, 10.0)
2. **MAUI Workloads**: `maui` and `wasm-tools` workloads with aligned workload set versions
3. **Microsoft OpenJDK**: Brew cask installation (e.g., `microsoft-openjdk@17`)
4. **Android SDK**:
   - Platform tools
   - Build tools (version aligned with workload requirements)
   - Command line tools
   - Target platform API
5. **Dotnet Tools**: `AndroidSdk.Tool` and `AppleDev.Tools` global tools
6. **Logging**: Provisioning logs saved to `~/Library/Logs/maui-macos-provisioning/`

### Usage

Basic provisioning:
```powershell
pwsh ./provisioning/provision.ps1 -DotnetChannel 9.0
```

Dry run to preview changes:
```powershell
pwsh ./provisioning/provision.ps1 -DotnetChannel 10.0 -DryRun
```

Advanced options:
```powershell
pwsh ./provisioning/provision.ps1 `
    -DotnetChannel 10.0 `
    -WorkloadSetVersion "10.0.100-preview.1.123" `
    -DotnetInstallDir "~/custom/.dotnet" `
    -AndroidHome "~/custom/android" `
    -SkipBrewUpdate `
    -DryRun
```

### Key Features

1. **Idempotent**: Safe to run multiple times - only installs missing components
2. **Workload Alignment**: Automatically resolves workload set versions to match Docker images
3. **Version Detection**: Inspects existing installations and upgrades when needed
4. **Dry Run Support**: Preview all changes with `-DryRun` flag
5. **Common Functions**: Reuses `common-functions.ps1` for workload resolution logic shared with Docker builds

### Helper Functions

The module includes several internal helper functions:
- `Get-WorkloadInfo`: Resolves workload metadata from NuGet
- `Ensure-BrewTap`: Manages Homebrew tap configuration
- `Get-InstalledDotnetSdkVersions`: Detects installed .NET SDKs
- `Get-AndroidInstalledPackages`: Lists Android SDK components
- `Ensure-AndroidPackage`: Installs missing Android packages
- `Invoke-ExternalCommand`: Wrapper for external command execution with dry run support

### Integration with Docker Build System

The macOS provisioning module shares code with the Docker build system:
- Uses `common-functions.ps1` from the parent directory
- Aligns workload versions using the same NuGet resolution logic
- Ensures parity between containerized and native macOS environments

### Testing

After provisioning, validate the installation:
```powershell
# Check installations
dotnet --info
android sdk list --installed
xcodebuild -version

# Build and run tests
pwsh ./docker/test/build.ps1 -AndroidSdkApiLevel 35 -Load
pwsh ./docker/test/run.ps1 -AndroidSdkApiLevel 35
```

### .NET Version Support

- **.NET 9.0**: Fully supported with stable workload sets
- **.NET 10.0**: Preview/RC versions available with automatic prerelease detection

### Environment Configuration

The script sets up the current session PATH. For permanent configuration, add to your shell profile:
```bash
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
```

## Build Commands

### Linting and Type Checking
Currently, this is a PowerShell-based project without explicit lint/typecheck commands. PowerShell scripts are validated at runtime.

### Testing
Run provisioning in dry-run mode to validate:
```powershell
pwsh ./provisioning/provision.ps1 -DotnetChannel 10.0 -DryRun
```
