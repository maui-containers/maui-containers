# maui-containers

[![maui-linux](https://img.shields.io/badge/ghcr.io-maui--linux-blue?logo=docker)](https://github.com/maui-containers/maui-containers/pkgs/container/maui-linux)
[![maui-windows](https://img.shields.io/badge/ghcr.io-maui--windows-blue?logo=docker)](https://github.com/maui-containers/maui-containers/pkgs/container/maui-windows)
[![maui-macos](https://img.shields.io/badge/ghcr.io-maui--macos-blue?logo=docker)](https://github.com/maui-containers/maui-containers/pkgs/container/maui-macos)
[![maui-emulator-linux](https://img.shields.io/badge/ghcr.io-maui--emulator--linux-blue?logo=docker)](https://github.com/maui-containers/maui-containers/pkgs/container/maui-emulator-linux)

Docker images and macOS VMs for MAUI development/building/testing. See the [Repository Guidelines](AGENTS.md) for contributor instructions.

This repository provides comprehensive tooling for .NET MAUI development, organized by container platform type:

## Repository Structure

```
maui-containers/
├── docker/               # Docker container images
│   ├── linux/           # Linux MAUI development images
│   ├── windows/         # Windows MAUI development images
│   ├── test/            # Android emulator + Appium test images (Linux)
│   └── build.ps1        # Cross-platform Docker build script
├── tart/                # macOS VM images
│   └── macos/           # macOS MAUI development VMs (Tart)
└── provisioning/        # Provisioning scripts for all platforms
```

## Docker Images (Linux/Windows)
Located in `docker/` directory:

1. **Development Images** (`docker/linux/`, `docker/windows/`) - Complete MAUI development environment with integrated runner support
   - Use as standalone development containers (no runner configuration needed)
   - Enable GitHub Actions runner by setting `GITHUB_TOKEN`, `GITHUB_ORG`, and optionally `GITHUB_REPO`
   - Enable Gitea Actions runner by setting `GITEA_INSTANCE_URL` and `GITEA_RUNNER_TOKEN`
   - Run both GitHub and Gitea runners simultaneously on the same container
   - Runners start automatically when environment variables are present
2. **Test Images** (`docker/test/`) - Ready-to-use testing environment with Appium and Android Emulator (Linux only)

## macOS Virtual Machines (Tart)
Located in `tart/` directory:

3. **macOS VM Images** (`tart/macos/`) - Complete macOS MAUI development VMs with iOS/macOS/Android support
   - Published to GitHub Container Registry (ghcr.io)
   - Includes both GitHub and Gitea Actions runners (optional, enabled via environment variables)
   - Supports multiple Xcode versions

## Image Naming & Tag Format

All images follow a unified naming scheme for consistency across Docker and Tart platforms.

### Repository Organization

Images are published under the `maui-containers` organization:

**Docker Hub / GHCR:**
- `maui-containers/maui-linux` - Linux development images
- `maui-containers/maui-windows` - Windows development images
- `maui-containers/maui-macos` - macOS VM images (Tart)
- `maui-containers/maui-emulator-linux` - Linux images with Android Emulator + Appium

### Tag Format

All images use a consistent tag format with platform/OS identifiers and version information:

**Pattern:** `{platform-identifier}-dotnet{X.Y}-workloads{X.Y.Z}[-v{sha}]`

**Tag Variants:**

1. **`{platform}-dotnet{X.Y}`** - Latest workload set for this .NET version
2. **`{platform}-dotnet{X.Y}-workloads{X.Y.Z}`** - Specific workload version
3. **`{platform}-dotnet{X.Y}-workloads{X.Y.Z}-v{sha}`** - SHA-pinned build (optional)

### Examples by Platform

#### Linux Base Images
```
# .NET 10.0
maui-containers/maui-linux:dotnet10.0
maui-containers/maui-linux:dotnet10.0-workloads10.0.100-rc.2.25024.3
maui-containers/maui-linux:dotnet10.0-workloads10.0.100-rc.2.25024.3-vsha256abc

# .NET 9.0
maui-containers/maui-linux:dotnet9.0
maui-containers/maui-linux:dotnet9.0-workloads9.0.305
maui-containers/maui-linux:dotnet9.0-workloads9.0.305-vsha256abc
```

#### Windows Base Images
```
# .NET 10.0
maui-containers/maui-windows:dotnet10.0
maui-containers/maui-windows:dotnet10.0-workloads10.0.100-rc.2.25024.3
maui-containers/maui-windows:dotnet10.0-workloads10.0.100-rc.2.25024.3-vsha256abc

# .NET 9.0
maui-containers/maui-windows:dotnet9.0
maui-containers/maui-windows:dotnet9.0-workloads9.0.305
maui-containers/maui-windows:dotnet9.0-workloads9.0.305-vsha256abc
```

#### macOS VM Images (includes OS version)
```
# .NET 10.0
maui-containers/maui-macos:tahoe-dotnet10.0
maui-containers/maui-macos:tahoe-dotnet10.0-workloads10.0.100-rc.2.25024.3
maui-containers/maui-macos:tahoe-dotnet10.0-workloads10.0.100-rc.2.25024.3-vsha256abc

# .NET 9.0
maui-containers/maui-macos:tahoe-dotnet9.0
maui-containers/maui-macos:tahoe-dotnet9.0-workloads9.0.305
maui-containers/maui-macos:tahoe-dotnet9.0-workloads9.0.305-vsha256abc
```

#### Emulator/Test Images (includes Android API level)
```
# Android 35 with .NET 10.0
maui-containers/maui-emulator-linux:android35-dotnet10.0
maui-containers/maui-emulator-linux:android35-dotnet10.0-workloads10.0.100-rc.2.25024.3

# Android 34 with .NET 9.0
maui-containers/maui-emulator-linux:android34-dotnet9.0
maui-containers/maui-emulator-linux:android34-dotnet9.0-workloads9.0.305
```

### Platform Identifiers

| Platform | Identifier | Notes |
|----------|-----------|-------|
| Linux | (none) | No OS version needed |
| Windows | (none) | No OS version needed |
| macOS | `tahoe`, `sequoia` | OS version included for Xcode compatibility |
| Android Emulator | `android{XX}` | API level number (23-35) |

### Why This Format?

- **Always includes .NET version** - No ambiguity about which .NET version is installed
- **Workload versions explicit** - Pin to specific workload sets for reproducible builds
- **SHA pinning optional** - For maximum reproducibility when needed
- **Platform-aware** - macOS includes OS version for Xcode; emulator includes API level
- **No redundant tags** - Removed ambiguous `:latest` and platform-only tags

## Development Images

Development images provide a complete .NET MAUI development environment with integrated runner support. Use them as standalone development containers, self-hosted CI/CD runners, or as foundation images for custom containers.

- Linux: `maui-containers/maui-linux`
- Windows: `maui-containers/maui-windows`

### Usage Examples:

**As Development Container (No Runners):**
```bash
# Run a Linux development container (.NET 10.0)
docker run -it maui-containers/maui-linux:dotnet10.0 bash

# Run a Windows development container (.NET 9.0)
docker run -it maui-containers/maui-windows:dotnet9.0 powershell
```

**As GitHub Actions Self-Hosted Runner:**
```bash
# Linux runner
docker run -d \
  -e GITHUB_TOKEN=your_token \
  -e GITHUB_ORG=your-org \
  -e GITHUB_REPO=your-repo \
  maui-containers/maui-linux:dotnet10.0

# Windows runner
docker run -d `
  -e GITHUB_TOKEN=your_token `
  -e GITHUB_ORG=your-org `
  -e GITHUB_REPO=your-repo `
  maui-containers/maui-windows:dotnet10.0
```

**As Gitea Actions Runner:**
```bash
# Linux runner
docker run -d \
  -e GITEA_INSTANCE_URL=https://gitea.example.com \
  -e GITEA_RUNNER_TOKEN=your_token \
  maui-containers/maui-linux:dotnet10.0
```

**Run Both Runners Simultaneously:**
```bash
docker run -d \
  -e GITHUB_TOKEN=your_github_token \
  -e GITHUB_ORG=your-org \
  -e GITEA_INSTANCE_URL=https://gitea.example.com \
  -e GITEA_RUNNER_TOKEN=your_gitea_token \
  maui-containers/maui-linux:dotnet10.0
```

**As Base Image for Custom Containers:**
```dockerfile
FROM maui-containers/maui-linux:dotnet10.0-workloads10.0.100-rc.2.25024.3
# Add your custom requirements here
```

### What's Included:
- **.NET SDK** with MAUI workloads
- **Android SDK** with latest tools and API levels
- **Java/OpenJDK** for Android development
- **PowerShell** (cross-platform)
- **GitHub Actions runner** (v2.323.0)
- **Gitea Actions runner** (act_runner)
- **Development tools** (Git, build tools, etc.)

### Runner Environment Variables:

**GitHub Actions Runner:**
- `GITHUB_TOKEN` - GitHub access token with runner permissions (required)
- `GITHUB_ORG` - GitHub organization name (required)
- `GITHUB_REPO` - Repository name (optional, defaults to org-level)
- `RUNNER_NAME` - Custom runner name
- `RUNNER_NAME_PREFIX` - Prefix for auto-generated runner names
- `RANDOM_RUNNER_SUFFIX` - Add random suffix to name (default: true)
- `LABELS` - Custom runner labels
- `RUNNER_GROUP` - Runner group name
- `RUNNER_WORKDIR` - Working directory for runner

**Gitea Actions Runner:**
- `GITEA_INSTANCE_URL` - Gitea instance URL (required)
- `GITEA_RUNNER_TOKEN` - Runner registration token (required)
- `GITEA_RUNNER_NAME` - Custom runner name
- `GITEA_RUNNER_LABELS` - Custom labels (comma-separated)

**General:**
- `INIT_PWSH_SCRIPT` - PowerShell script to run before starting runners (Linux/Windows)
- `INIT_BASH_SCRIPT` - Bash script to run before starting runners (Linux only)

**.NET SDK location (advanced):**
The images keep the .NET SDK at the base-image default location
(`/usr/share/dotnet` on Linux, `C:\Program Files\dotnet` on Windows) but make
it writable for the runtime user, so `dotnet workload update`,
`dotnet workload install`, and `dotnet tool install -g` all succeed from CI
without elevation. The following are set image-wide and usually don't need
overriding:
- `DOTNET_ROOT` / `DOTNET_INSTALL_DIR` — point at the SDK tree
- `DOTNET_MULTILEVEL_LOOKUP=0` — stop probing for secondary installs
- `NUGET_PACKAGES` — pinned under the runtime user's profile
- `DOTNET_CLI_TELEMETRY_OPTOUT=1`, `DOTNET_NOLOGO=1`, `DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1`

See [docker/linux/README.md](docker/linux/README.md) and [docker/windows/README.md](docker/windows/README.md) for detailed documentation.

### macOS Host Provisioning
- Run `pwsh ./provisioning/provision.ps1` to mirror the base image tooling directly on a macOS workstation.
- Installs .NET, MAUI workloads, Android SDK, and helper tools without Docker.
- Review [provisioning/README.md](provisioning/README.md) for prerequisites and customization options.
- Provisioning logic lives in the reusable `MauiProvisioning` PowerShell module under `provisioning/` for advanced scripting scenarios.
- When Apple workloads are requested, the script also provisions the recommended Xcode build plus matching iOS/tvOS simulator runtimes.



## Emulator/Test Images

Emulator images are designed to help quickly stand up containers that are ready to use for running UI Tests with Appium on the Android Emulator. They come setup with Appium Server and the Android Emulator (for the given API level) both running and waiting when the container is started.

**Repository:** `maui-containers/maui-emulator-linux`

> NOTE: Only `linux/amd64` is available.

### Usage:

```bash
docker run \
    -v /path/to/app/bin/Debug/net10.0-android35.0/:/app \
    --device /dev/kvm \
    -p 5554:5554 \
    -p 5555:5555 \
    -p 4723:4723 \
    maui-containers/maui-emulator-linux:android35-dotnet10.0
```

> NOTE: Ports are mapped for the emulator, ADB, and Appium in this example.

> NOTE: Device passthrough of `/dev/kvm` is required for the emulator

### Volumes:
The host folder with the built apk's can be mapped to a folder in the container.  You can then specify the location of the apk to install to appium using the container's path to it (eg: `/app/my.companyname.app-Signed.apk`).

### Environment Variables:
- `INIT_PWSH_SCRIPT` Optionally (linux or windows images) specify a path to a .ps1 script file to run before starting the runner agent (Default path is `/config/init.ps1` on linux and `C:\\config\\init.ps1` on windows - you would need to bind a volume for the script to use)
- `INIT_BASH_SCRIPT` Optionally (linux image only) specify a path to a .ps1 script file to run before starting the runner agent (Default path is `/config/init.sh` on linux - you would need to bind a volume for the script to use)

### Variants

Each Android API Level (23 through latest) has its own image variant.  You can specify different ones to use by the tag name (eg: `maui-emulator-linux:android23-dotnet10.0` or `maui-emulator-linux:android35-dotnet10.0`).

![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android35-dotnet10.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)

<details>

<summary>Show All Variants...</summary>

- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android23-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android24-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android25-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android26-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android28-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android29-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android30-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android31-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android32-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android33-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android34-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android35-dotnet10.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
 
</details>

### Docker and Nested Virtualization
The emulator on this image requires nested virtualization to work correctly.  This is done by passing the `--device /dev/kvm` from the host device to the docker container.

#### Windows
Windows may have mixed results with Docker running in Hyper-V mode.  It seems recent Windows and/or Docker updates makes this less reliable.  Instead it's recommended to have [Docker run in WSL2](https://docs.docker.com/desktop/features/wsl/) mode and launch the docker image from WSL2 in order to pass through the KVM device.

#### macOS
Apple Silicon based Macs will require an M3 or newer to use nested virtualization with Docker.

#### Linux
Linux should work fine as long as you have [kvm virtualization support](https://docs.docker.com/desktop/setup/install/linux/#kvm-virtualization-support) enabled.

--------------------

## Tart VM Images (macOS)

Tart VM images provide complete macOS virtual machines for .NET MAUI development, including iOS, macOS, and Android support. These VMs are pre-configured with Xcode, .NET SDK, Android SDK, and both GitHub and Gitea Actions runners.

**Repository:** `ghcr.io/maui-containers/maui-macos`

**Available Tags:**
- `tahoe-dotnet10.0` - .NET 10.0 on macOS Tahoe
- `tahoe-dotnet10.0-workloads10.0.100-rc.2.25024.3` - Specific workload version
- `tahoe-dotnet9.0` - .NET 9.0 on macOS Tahoe
- `tahoe-dotnet9.0-workloads9.0.305` - Specific workload version

Images are automatically built and published to GitHub Container Registry (ghcr.io) when workload updates are detected or when manually triggered.

### Quick Start

Pull and run a Tart VM:

```bash
# Pull and run .NET 10.0 image
tart clone ghcr.io/maui-containers/maui-macos:tahoe-dotnet10.0 maui-dev
tart run maui-dev

# Or run directly without cloning
tart run ghcr.io/maui-containers/maui-macos:tahoe-dotnet10.0

# Pin to a specific workload version
tart clone ghcr.io/maui-containers/maui-macos:tahoe-dotnet10.0-workloads10.0.100-rc.2.25024.3 maui-dev
```

### Using with GitHub Actions

```bash
# Set environment variables and run
GITHUB_TOKEN=your_token \
GITHUB_ORG=your-org \
GITHUB_REPO=your-repo \
tart run ghcr.io/maui-containers/maui-macos:tahoe-dotnet10.0
```

The VM will automatically:
1. Register as a GitHub Actions self-hosted runner
2. Wait for jobs from your repository
3. Execute workflows with full iOS/macOS/Android build capabilities

### Using with Gitea Actions

```bash
# Set environment variables and run
GITEA_INSTANCE_URL=https://gitea.example.com \
GITEA_RUNNER_TOKEN=your_token \
tart run ghcr.io/maui-containers/maui-macos:tahoe-dotnet10.0
```

### Environment Variables

**GitHub Actions Runner:**
- `GITHUB_TOKEN` - GitHub access token with runner permissions
- `GITHUB_ORG` - GitHub organization name
- `GITHUB_REPO` - Repository name (optional, defaults to org-level)
- `GITHUB_RUNNER_NAME` - Custom runner name
- `GITHUB_RUNNER_LABELS` - Custom labels (comma-separated)

**Gitea Actions Runner:**
- `GITEA_INSTANCE_URL` - Gitea instance URL
- `GITEA_RUNNER_TOKEN` - Runner registration token
- `GITEA_RUNNER_NAME` - Custom runner name
- `GITEA_RUNNER_LABELS` - Custom labels (comma-separated)

> NOTE: If both GitHub and Gitea variables are set, both runners will be started.

### What's Included:
- **macOS Tahoe** (macOS 15) base system
- **Xcode** with recommended version for .NET workloads
- **iOS and tvOS Simulators** matching Xcode version
- **.NET SDK** with MAUI workloads
- **Android SDK** with latest tools and API levels
- **Microsoft OpenJDK** for Android development
- **PowerShell** for cross-platform scripting
- **GitHub Actions runner** (act_runner binary)
- **Gitea Actions runner** (act_runner binary)
- **Development tools** (Git, build tools, etc.)

### Supported Configurations:
- **.NET 9.0**: Stable workloads with Xcode 16.1
- **.NET 10.0**: Preview/RC workloads with latest Xcode

### Building Custom Images

See [macos/tart/README.md](macos/tart/README.md) for instructions on building custom Tart VM images with specific .NET versions, workload sets, or Xcode versions.

------------------


## Building

The images can be built with their respective `build.ps1` files.  See the GitHub workflow yml files for examples.


-------------------


## Roadmap

- Windows container for Test images
