# .NET MAUI Docker Repository - Copilot Instructions

## Repository Overview

This repository provides development environments for .NET MAUI across multiple platforms:
1. **Docker Images** (`docker/`) - Container images
   - `docker/linux/` - Linux MAUI development images
   - `docker/windows/` - Windows MAUI development images  
   - `docker/test/` - Testing environment with Appium and Android Emulator (Linux only)
2. **Tart VM Images** (`tart/macos/`) - macOS virtual machine images

**Repository Size**: Small (~50 files)  
**Languages**: PowerShell (primary), Dockerfile, YAML  
**Platforms**: Linux (amd64), Windows (amd64)  
**Target Runtimes**: .NET 9.0, Docker containers  
**Published Images**: GitHub Container Registry (`maui-containers/maui-linux`, `maui-containers/maui-windows`, `maui-containers/maui-macos`, `maui-containers/maui-emulator-linux`)

## Build Instructions - CRITICAL REQUIREMENTS

### Prerequisites
- **Docker**: Required for all builds
- **PowerShell 7+**: All build scripts use PowerShell Core
- **Internet access**: Scripts download workload versions from NuGet and npm APIs

### Key Commands That ALWAYS Work

**ALWAYS run PowerShell scripts from the repository root:**
```bash
cd /path/to/maui-docker
pwsh ./script-name.ps1 [parameters]
```

**Test PowerShell Functions (Validates Environment):**
```bash
pwsh -Command ". ./common-functions.ps1; Get-LatestAppiumVersions"
pwsh -Command ". ./common-functions.ps1; Find-LatestWorkloadSet -DotnetVersion '9.0'"
```

**Build Docker Images (Linux - Works in Docker environments):**
```bash
pwsh ./docker/build.ps1 -DotnetVersion "9.0" -DockerPlatform "linux/amd64" -DockerRepository "test/maui-build" -Load
```

**Build Emulator Images:**
```bash
pwsh ./docker/test/build.ps1 -AndroidSdkApiLevel 35 -DockerRepository "test/maui-testing" -Load
```

### Build Sequence
1. **Docker images** and **emulator images** are independent and can be built in any order
2. **Windows builds** require Windows runners in CI
3. **Test images** are Linux-only and require `/dev/kvm` device for emulator

### Common Build Failures & Solutions

**PowerShell Switch Parameters:**
- Boolean parameters are defined as `[switch]` and work as simple flags
- Use `-Load` to enable, omit the parameter to disable
- Example: `pwsh ./docker/build.ps1 -Load` (not `-Load:$true`)

**Network Dependencies:**
- Workload detection requires internet access to NuGet and npm APIs
- In isolated environments, builds may fail during workload detection phase
- Scripts include fallback versions when API calls fail

**Docker Build Context Issues:**
- All Docker builds use platform-specific subdirectories (`docker/linux/`, `docker/windows/`)
- Build scripts automatically change to correct directory

**Workload Set Detection Failures:**
- Internet access required for NuGet API calls
- Scripts have fallback versions if APIs fail
- Timeouts normal for first workload detection (can take 2-3 minutes)

## Project Layout & Architecture

### Core Directories
```
.github/workflows/     # CI/CD - builds triggered by schedule or dispatch
docker/                # Docker container images
├── build.ps1          # Cross-platform Docker image builder
├── linux/             # Linux MAUI images
│   ├── build.ps1      # Linux-specific build script
│   ├── Dockerfile     # Linux image definition
│   └── scripts/       # Init scripts
├── windows/           # Windows MAUI images
│   ├── build.ps1      # Windows-specific build script
│   ├── Dockerfile     # Windows image definition
│   └── scripts/       # Init scripts
└── test/              # Testing images with Appium + Android emulator
    ├── build.ps1      # Test image builder (Linux only)
    ├── run.ps1        # Container runner helper
    └── Dockerfile     # Test image definition
tart/                  # Tart VM images
└── macos/             # macOS MAUI VMs
    └── scripts/       # Bootstrap and management scripts
provisioning/          # PowerShell module for native macOS provisioning
common-functions.ps1   # CRITICAL: Shared PowerShell functions
check-workload-updates.ps1  # Automated version checking
```

### Configuration Files
- **GitHub Workflows**: `.github/workflows/*.yml` - Complex matrix builds
- **Docker**: `*/Dockerfile` - Multi-stage, parameterized builds
- **VSCode**: `.vscode/launch.json` - PowerShell debugging setup

### Dependencies & Architecture
**Image Hierarchy:**
```
Microsoft .NET SDK Image
    ↓
Docker Base Image (MAUI Dev)
    ↓
Test Image (Base + Appium/Emulator)
```

**External Dependencies:**
- NuGet API for .NET workload versions
- npm registry for Appium versions  
- Docker Hub for base Microsoft images
- Android SDK packages (dynamically determined)

### GitHub Workflows - Validation Pipeline

**Primary Workflows:**
- `check-workload-updates.yml` - Automated version monitoring and build triggering
- `build-docker-linux.yml` - Linux Docker images
- `build-docker-windows.yml` - Windows Docker images
- `build-emulators.yml` - Android emulator images (with Appium)
- `build-tart-vms.yml` - macOS Tart VM images
- `pr-validation.yml` - PR validation builds

**Critical Workflow Features:**
- Matrix builds across .NET versions and Android API levels
- Automatic workload version detection
- Multi-platform support (Linux/Windows/macOS)
- Independent parallel builds (base and test images build separately)

### Key Source Files

**common-functions.ps1** (Most Important):
- `Find-LatestWorkloadSet()` - Gets latest .NET workload versions
- `Get-WorkloadInfo()` - Comprehensive workload dependency analysis
- `Get-AndroidWorkloadInfo()` - Android SDK requirements extraction
- `Get-LatestAppiumVersions()` - npm package version detection

**Build Entry Points:**
- `docker/build.ps1` - Main Docker image builder
- `docker/test/build.ps1` - Test image builder
- `tart/macos/scripts/build.ps1` - Tart VM builder

## Validation Steps for Changes

**Before Making Changes:**
1. Test PowerShell functions: `pwsh -Command ". ./common-functions.ps1; Find-LatestWorkloadSet -DotnetVersion '9.0'"`
2. Verify Docker: `docker --version`
3. Check workflow syntax: GitHub Actions validates on push

**After Making Changes:**  
1. **ALWAYS test build scripts locally** before committing
2. For Dockerfile changes: Build locally with `-Load`
3. For PowerShell changes: Test functions individually
4. For workflow changes: Use workflow_dispatch to test

**Trust These Instructions:** The build processes are complex with dynamic version detection. Only search for additional information if these instructions are incomplete or incorrect.
