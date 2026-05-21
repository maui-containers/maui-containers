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

1. **Development Images** (`docker/linux/`, `docker/windows/`) - Complete MAUI development environment
   - Use as standalone development containers
   - Provide custom startup behavior with `INIT_PWSH_SCRIPT` and, on Linux, `INIT_BASH_SCRIPT`
2. **Test Images** (`docker/test/`) - Ready-to-use testing environment with Appium and Android Emulator (Linux only)

## macOS Virtual Machines (Tart)
Located in `tart/` directory:

3. **macOS VM Images** (`tart/macos/`) - Complete macOS MAUI development VMs with iOS/macOS/Android support
   - Published to GitHub Container Registry (ghcr.io)
   - Supports custom startup behavior through a mounted `config/init.sh`
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

**Pattern:** `{platform-identifier}-dotnet{X.Y}[-preview|-previewN|-rc|-rcN][-workloads{exact-or-band}][-v{sha}]`

**Tag Variants:**

1. **`{platform}-dotnet{X.Y}`** - Latest stable workload set for this .NET version
2. **`{platform}-dotnet{X.Y}-preview`** - Latest prerelease workload set for this .NET version
3. **`{platform}-dotnet{X.Y}-previewN`** - Latest workload set for a specific preview wave
4. **`{platform}-dotnet{tag}-workloads{X.Y.Z}`** - Specific workload version
5. **`{platform}-dotnet{tag}-workloads{X.Y.Nxx}`** - Rolling workload-band tag for minor updates in a hundreds range
6. **`{platform}-dotnet{specific-tag}-workloads{X.Y.Z}-v{sha}`** - SHA-pinned build (optional)

### Examples by Platform

#### Linux Base Images
```
# .NET 10.0
maui-containers/maui-linux:dotnet10.0
maui-containers/maui-linux:dotnet10.0-workloads10.0.300.3
maui-containers/maui-linux:dotnet10.0-workloads10.0.3xx
maui-containers/maui-linux:dotnet10.0-workloads10.0.300.3-vsha256abc

# .NET 11.0 Preview
maui-containers/maui-linux:dotnet11.0-preview
maui-containers/maui-linux:dotnet11.0-preview4
maui-containers/maui-linux:dotnet11.0-preview-workloads11.0.100-preview.4.26261.2
maui-containers/maui-linux:dotnet11.0-preview-workloads11.0.1xx
maui-containers/maui-linux:dotnet11.0-preview4-workloads11.0.100-preview.4.26261.2
maui-containers/maui-linux:dotnet11.0-preview4-workloads11.0.100-preview.4.26261.2-vsha256abc
```

#### Windows Base Images
```
# .NET 10.0
maui-containers/maui-windows:dotnet10.0
maui-containers/maui-windows:dotnet10.0-workloads10.0.300.3
maui-containers/maui-windows:dotnet10.0-workloads10.0.300.3-vsha256abc

# .NET 11.0 Preview
maui-containers/maui-windows:dotnet11.0-preview
maui-containers/maui-windows:dotnet11.0-preview4
maui-containers/maui-windows:dotnet11.0-preview-workloads11.0.100-preview.4.26261.2
maui-containers/maui-windows:dotnet11.0-preview-workloads11.0.1xx
maui-containers/maui-windows:dotnet11.0-preview4-workloads11.0.100-preview.4.26261.2
maui-containers/maui-windows:dotnet11.0-preview4-workloads11.0.100-preview.4.26261.2-vsha256abc
```

#### macOS VM Images (includes OS version)
```
# .NET 10.0
maui-containers/maui-macos:tahoe-dotnet10.0
maui-containers/maui-macos:tahoe-dotnet10.0-workloads10.0.300.3
maui-containers/maui-macos:tahoe-dotnet10.0-workloads10.0.3xx
maui-containers/maui-macos:tahoe-dotnet10.0-workloads10.0.300.3-vsha256abc

# .NET 11.0 Preview
maui-containers/maui-macos:tahoe-dotnet11.0-preview
maui-containers/maui-macos:tahoe-dotnet11.0-preview4
maui-containers/maui-macos:tahoe-dotnet11.0-preview-workloads11.0.100-preview.4.26261.2
maui-containers/maui-macos:tahoe-dotnet11.0-preview-workloads11.0.1xx
maui-containers/maui-macos:tahoe-dotnet11.0-preview4-workloads11.0.100-preview.4.26261.2
maui-containers/maui-macos:tahoe-dotnet11.0-preview4-workloads11.0.100-preview.4.26261.2-vsha256abc
```

#### Emulator/Test Images (includes Android API level)
```
# Android 35 emulator
maui-containers/maui-emulator-linux:android35
maui-containers/maui-emulator-linux:android35-vsha256abc

# Compatibility alias for existing consumers
maui-containers/maui-emulator-linux:android35-dotnet10.0
```

### Platform Identifiers

| Platform | Identifier | Notes |
|----------|-----------|-------|
| Linux | (none) | No OS version needed |
| Windows | (none) | No OS version needed |
| macOS | `tahoe`, `sequoia` | OS version included for Xcode compatibility |
| Android Emulator | `android{XX}` | API level number (23-36) |

### Why This Format?

- **Always includes .NET version** - No ambiguity about which .NET version is installed
- **Workload versions explicit** - Pin to specific workload sets for reproducible builds
- **Rolling band tags available** - Follow updates like `10.0.3xx` or `11.0.1xx` without jumping across bands
- **Prerelease tags are explicit** - Preview and RC channels always include `-preview`, `-previewN`, `-rc`, or `-rcN`
- **SHA pinning optional** - For maximum reproducibility when needed
- **Platform-aware** - macOS includes OS version for Xcode; emulator includes API level
- **No redundant tags** - Removed ambiguous `:latest` and platform-only tags

## Development Images

Development images provide a complete .NET MAUI development environment. Use them as standalone development containers or as foundation images for custom containers.

- Linux: `maui-containers/maui-linux`
- Windows: `maui-containers/maui-windows`

### Usage Examples:

**As Development Container:**
```bash
# Run a Linux development container (.NET 10.0)
docker run -it maui-containers/maui-linux:dotnet10.0 bash

# Run a Windows development container (.NET 11.0 Preview)
docker run -it maui-containers/maui-windows:dotnet11.0-preview powershell
```

**With Custom Startup Logic:**
```bash
docker run -it \
  -v "$PWD/config:/config" \
  -e INIT_BASH_SCRIPT=/config/init.sh \
  maui-containers/maui-linux:dotnet10.0
```

**As Base Image for Custom Containers:**
```dockerfile
FROM maui-containers/maui-linux:dotnet10.0-workloads10.0.300.3
# Add your custom requirements here
```

### What's Included:
- **.NET SDK** with MAUI workloads
- **Android SDK** with latest tools and API levels
- **Java/OpenJDK** for Android development
- **PowerShell** (cross-platform)
- **Development tools** (Git, build tools, etc.)

### Startup Environment Variables:

- `INIT_PWSH_SCRIPT` - PowerShell script to run before the container command (Linux/Windows)
- `INIT_BASH_SCRIPT` - Bash script to run before the container command (Linux only)

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

The container uses a deterministic startup sequence: the emulator boots first and is validated via `adb`, then Appium starts only after the emulator is confirmed ready. A built-in Docker `HEALTHCHECK` reports the combined readiness of both services.

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
    maui-containers/maui-emulator-linux:android35
```

> NOTE: Ports are mapped for the emulator, ADB, and Appium in this example.

> NOTE: Device passthrough of `/dev/kvm` is required for the emulator

### Volumes:
The host folder with the built apk's can be mapped to a folder in the container.  You can then specify the location of the apk to install to appium using the container's path to it (eg: `/app/my.companyname.app-Signed.apk`).

### Environment Variables

#### Initialization hooks
| Variable | Default | Description |
|----------|---------|-------------|
| `INIT_PWSH_SCRIPT` | `/config/init.ps1` | Path to a PowerShell script to run before services start. Bind a volume to supply the script. |
| `INIT_BASH_SCRIPT` | `/config/init.sh` | Path to a bash script to run before services start. Bind a volume to supply the script. |
| `PRE_EMULATOR_LAUNCH_SCRIPT` | _(none)_ | Path to a bash script that runs after init but before the emulator starts. Useful for patching AVD config or preloading state. |
| `POST_BOOT_SCRIPT` | _(none)_ | Path to a bash script that runs after the emulator has booted and device tuning is applied. |

#### Emulator configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `EMULATOR_BOOT_TIMEOUT` | `600` | Maximum seconds to wait for `sys.boot_completed`. Container exits with an error if exceeded. |
| `EMULATOR_PORT` | `5554` | Emulator console port. ADB port is automatically `EMULATOR_PORT + 1`. |
| `EMULATOR_WIPE_DATA` | `true` | Pass `-wipe-data` to the emulator for a clean boot each time. Set to `false` to preserve data between restarts. |
| `EMULATOR_SNAPSHOT_MODE` | `none` | Snapshot behavior: `none` (no load/save), `load` (load existing, don't save), `save` (don't load, save on exit), `full` (load and save). |
| `EMULATOR_EXTRA_ARGS` | _(none)_ | Additional flags appended to the emulator command line. |
| `AVD_NAME` | `Emulator_{API_LEVEL}` | Name of the AVD to launch. Matches the AVD created at image build time by default. |

#### Post-boot device tuning
| Variable | Default | Description |
|----------|---------|-------------|
| `DISABLE_ANIMATIONS` | `true` | Disable window, transition, and animator animations via `adb shell settings`. Recommended for UI testing. |
| `DISABLE_SPELLCHECKER` | `false` | Disable Android spellchecker to avoid input-field interference during tests. |
| `ENABLE_HW_KEYBOARD` | `false` | Suppress the soft keyboard by enabling hardware keyboard mode. Useful for automation that types via `adb` input. |

#### Appium configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `APPIUM_LOG_LEVEL` | `debug` | Appium server log verbosity: `debug`, `info`, `warn`, `error`. |
| `APPIUM_PORT` | `4723` | Port for the Appium HTTP server. |

### Snapshot Reuse (Fast Warm Start)

By default the container wipes emulator data and disables snapshots, giving a clean, deterministic boot every time. For faster iteration you can opt into snapshot reuse:

**Create a snapshot (first run):**
```bash
docker run \
    --device /dev/kvm \
    -e EMULATOR_WIPE_DATA=false \
    -e EMULATOR_SNAPSHOT_MODE=save \
    -v emulator-avd:/home/mauiusr/.android/avd \
    -p 4723:4723 \
    maui-containers/maui-emulator-linux:android35
```

**Reuse the snapshot (subsequent runs):**
```bash
docker run \
    --device /dev/kvm \
    -e EMULATOR_WIPE_DATA=false \
    -e EMULATOR_SNAPSHOT_MODE=load \
    -v emulator-avd:/home/mauiusr/.android/avd \
    -p 4723:4723 \
    maui-containers/maui-emulator-linux:android35
```

> **Caution:** Snapshot reuse may leak state between test runs. Keep it opt-in and use the default `none` mode for CI pipelines that require isolation.

### Healthcheck

The image includes a built-in Docker `HEALTHCHECK` that validates:
1. The emulator has fully booted (`sys.boot_completed == 1`)
2. The Appium server is responding on its configured port

Use `docker inspect --format='{{.State.Health.Status}}'` or wait for `healthy` status in orchestrators like Docker Compose.

### Helper script

Use `docker/test/run.ps1` for a quick local launch:

```powershell
# Default: API 35
pwsh ./docker/test/run.ps1 -AndroidSdkApiLevel 35

# With runtime options
pwsh ./docker/test/run.ps1 -AndroidSdkApiLevel 35 -DisableSpellchecker -EnableHwKeyboard
```

### Variants

Each Android API Level (23 through latest) has its own image variant. You can specify different ones to use by the tag name (eg: `maui-emulator-linux:android23` or `maui-emulator-linux:android35`). The image uses a .NET runtime base internally for tooling, but emulator variants are not split by .NET or MAUI workload version.

![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android35?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)

<details>

<summary>Show Active Variant Examples...</summary>

- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android35?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/mauicontainers/maui-emulator-linux/android36?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fmauicontainers%2Fmaui-emulator-linux%2Ftags)
 
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

Tart VM images provide complete macOS virtual machines for .NET MAUI development, including iOS, macOS, and Android support. These VMs are pre-configured with Xcode, .NET SDK, and Android SDK.

**Repository:** `ghcr.io/maui-containers/maui-macos`

**Available Tags:**
- `tahoe-dotnet10.0` - .NET 10.0 on macOS Tahoe
- `tahoe-dotnet10.0-workloads10.0.300.3` - Specific workload version
- `tahoe-dotnet10.0-workloads10.0.3xx` - Rolling tag for the 10.0.300-399 workload band
- `tahoe-dotnet11.0-preview` - Latest .NET 11.0 preview on macOS Tahoe
- `tahoe-dotnet11.0-preview4` - Latest .NET 11.0 Preview 4 on macOS Tahoe
- `tahoe-dotnet11.0-preview-workloads11.0.100-preview.4.26261.2` - Specific workload version on the preview channel
- `tahoe-dotnet11.0-preview-workloads11.0.1xx` - Rolling tag for the 11.0.100 preview workload band
- `tahoe-dotnet11.0-preview4-workloads11.0.100-preview.4.26261.2` - Specific workload version pinned to Preview 4

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
tart clone ghcr.io/maui-containers/maui-macos:tahoe-dotnet11.0-preview4-workloads11.0.100-preview.4.26261.2 maui-dev
```

### Custom Startup

Mount a config directory containing `init.sh` to run your own bootstrap, including any runner setup you prefer:

```bash
tart run ghcr.io/maui-containers/maui-macos:tahoe-dotnet10.0 --dir config:/path/to/config
```

### What's Included:
- **macOS Tahoe** (macOS 16) base system
- **Xcode** with recommended version for .NET workloads
- **iOS and tvOS Simulators** matching Xcode version
- **.NET SDK** with MAUI workloads
- **Android SDK** with latest tools and API levels
- **Microsoft OpenJDK** for Android development
- **PowerShell** for cross-platform scripting
- **Development tools** (Git, build tools, etc.)

### Supported Configurations:
- **.NET 10.0**: Stable workloads with current Xcode
- **.NET 11.0 Preview**: Preview workloads starting with Preview 4 and Xcode 26.4 requirements
- **.NET 9.0**: Retired from active builds; legacy configuration is kept only for potential revival

### Building Custom Images

See [macos/tart/README.md](macos/tart/README.md) for instructions on building custom Tart VM images with specific .NET versions, workload sets, or Xcode versions.

------------------


## Building

The images can be built with their respective `build.ps1` files.  See the GitHub workflow yml files for examples.


-------------------


## Roadmap

- Windows container for Test images
