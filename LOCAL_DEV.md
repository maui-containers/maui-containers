# Local Development Guide

This guide provides commands for building Docker images and Tart VM images locally for development and testing.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Docker Images](#docker-images)
  - [Linux Images (with Integrated Runner Support)](#linux-images-with-integrated-runner-support)
  - [Windows Images (with Integrated Runner Support)](#windows-images-with-integrated-runner-support)
  - [Test Images](#test-images)
  - [Using Runners in Docker Images](#using-runners-in-docker-images)
- [Tart VM Images](#tart-vm-images)
  - [Building VMs](#building-vms)
  - [Running VMs](#running-vms)
  - [Testing VMs](#testing-vms)
- [Viewing Software Manifests](#viewing-software-manifests)
  - [Docker Manifests](#docker-manifests)
  - [Tart VM Manifests](#tart-vm-manifests)
- [SBOM Formats](#sbom-formats)

---

## Prerequisites

### For Docker Images

**Linux/macOS:**
- Docker Desktop or Docker Engine
- PowerShell Core (`brew install powershell`)

**Windows:**
- Docker Desktop with Windows containers enabled
- PowerShell 7+

### For Tart VM Images

**macOS only:**
- Tart: `brew install cirruslabs/cli/tart`
- Packer: `brew install packer`
- PowerShell: `brew install powershell`

---

## Docker Images

### Linux Images (with Integrated Runner Support)

#### .NET 9.0
```bash
# Build with default settings
pwsh ./docker/linux/build.ps1 -DotnetVersion "9.0" -DockerRepository "maui-build" -Load

# Build with specific workload version
pwsh ./docker/linux/build.ps1 \
  -DotnetVersion "9.0" \
  -WorkloadSetVersion "9.0.203" \
  -DockerRepository "maui-build" \
  -Load

# Build with specific Android API level
pwsh ./docker/linux/build.ps1 \
  -DotnetVersion "9.0" \
  -AndroidSdkApiLevel 35 \
  -DockerRepository "maui-build" \
  -Load
```

#### .NET 10.0 (Preview)
```bash
# Build with auto-detected preview workloads
pwsh ./docker/linux/build.ps1 -DotnetVersion "10.0" -DockerRepository "maui-build" -Load
```

#### Unified Build Script
```bash
# Build for current platform
pwsh ./docker/build.ps1 \
  -DockerPlatform "linux/amd64" \
  -DockerRepository "maui-build" \
  -Load
```

### Windows Images (with Integrated Runner Support)

**Note:** Requires Windows with Docker Desktop set to Windows containers mode.

#### .NET 9.0
```powershell
# Build Windows image
pwsh ./docker/windows/build.ps1 -DotnetVersion "9.0" -DockerRepository "maui-build" -Load
```

#### .NET 10.0 (Preview)
```powershell
pwsh ./docker/windows/build.ps1 -DotnetVersion "10.0" -DockerRepository "maui-build" -Load
```

### Test Images

**Note:** Test images are Linux-only and include Appium + Android Emulator.

```bash
# Build with specific Android API level
pwsh ./docker/test/build.ps1 \
  -DotnetVersion "9.0" \
  -AndroidSdkApiLevel 35 \
  -DockerRepository "maui-testing" \
  -Load

# Run test container with emulator
pwsh ./docker/test/run.ps1 -AndroidSdkApiLevel 35
```

### Using Runners in Docker Images

All Docker images support both GitHub Actions and Gitea Actions runners through environment variables:

#### GitHub Actions Runner
```bash
docker run -e GITHUB_TOKEN=ghp_xxx -e GITHUB_ORG=your-org maui-build:latest
```

#### Gitea Actions Runner
```bash
docker run -e GITEA_INSTANCE_URL=https://gitea.example.com -e GITEA_RUNNER_TOKEN=your-token maui-build:latest
```

#### Development Mode (No Runners)
```bash
docker run -it maui-build:latest pwsh
```

---

## Tart VM Images

### Building VMs

#### Quick Start (Recommended)
```bash
# Build with all prerequisites check
pwsh ./macos/tart/scripts/quick-start.ps1 \
  -BuildType maui \
  -DotnetChannel 10.0
```

#### Standard Build - .NET 10.0
```bash
# Auto-resolves to macOS Tahoe + Xcode 26
pwsh ./macos/tart/scripts/build.ps1 \
  -ImageType maui \
  -DotnetChannel 10.0
```

#### Standard Build - .NET 9.0
```bash
pwsh ./macos/tart/scripts/build.ps1 \
  -ImageType maui \
  -DotnetChannel 9.0
```

#### With Additional Xcode Versions
```bash
# Install multiple Xcode versions
pwsh ./macos/tart/scripts/build.ps1 \
  -ImageType maui \
  -DotnetChannel 10.0 \
  -AdditionalXcodeVersions "16.4","16.1"
```

#### Override macOS/Xcode Versions
```bash
# Use specific versions (advanced)
pwsh ./macos/tart/scripts/build.ps1 \
  -ImageType maui \
  -DotnetChannel 10.0 \
  -MacOSVersion sequoia \
  -BaseXcodeVersion 16.4
```

#### Custom Configuration
```bash
# Custom CPU, memory, and disk
pwsh ./macos/tart/scripts/build.ps1 \
  -ImageType maui \
  -DotnetChannel 10.0 \
  -CPUCount 8 \
  -MemoryGB 16 \
  -DiskSizeGB 160
```

### Running VMs

#### Basic Run
```bash
# Start VM (with auto-registration if env vars set)
tart run maui-dev-tahoe-dotnet10.0

# Start in background
tart run maui-dev-tahoe-dotnet10.0 &
```

#### With Project Directory Mounted
```bash
# Mount a directory into the VM
tart run maui-dev-tahoe-dotnet10.0 --dir myproject:/path/to/project

# Access in VM at: /Volumes/My Shared Files/myproject
```

#### SSH Access
```bash
# Get VM IP address
tart ip maui-dev-tahoe-dotnet10.0

# SSH into VM (password: admin)
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0)
```

#### With GitHub Actions Runner Auto-Registration
```bash
# Set environment variables for auto-registration
export GITHUB_ORG='your-org'
export GITHUB_TOKEN='ghp_xxx'

# Run VM - runner will auto-register
tart run maui-dev-tahoe-dotnet10.0
```

#### With Gitea Actions Runner Auto-Registration
```bash
# Set environment variables for auto-registration
export GITEA_INSTANCE_URL='https://gitea.example.com'
export GITEA_RUNNER_TOKEN='your-registration-token'

# Run VM - runner will auto-register
tart run maui-dev-tahoe-dotnet10.0
```

### Testing VMs

```bash
# Test .NET 10.0 image
pwsh ./macos/tart/scripts/test.ps1 \
  -ImageName maui-dev-tahoe-dotnet10.0 \
  -TestType maui

# Test .NET 9.0 image
pwsh ./macos/tart/scripts/test.ps1 \
  -ImageName maui-dev-tahoe-dotnet9.0 \
  -TestType maui
```

### VM Management

```bash
# List all VMs
tart list

# Stop a running VM
tart stop maui-dev-tahoe-dotnet10.0

# Delete a VM
tart delete maui-dev-tahoe-dotnet10.0

# Clone a VM
tart clone maui-dev-tahoe-dotnet10.0 my-custom-vm

# Export a VM
tart export maui-dev-tahoe-dotnet10.0 maui-vm.tar.gz

# Import a VM
tart clone maui-vm.tar.gz imported-vm
```

### Pull Pre-built VMs from Registry

```bash
# Pull from GitHub Container Registry
tart clone ghcr.io/maui-containers/maui-macos:tahoe-dotnet10.0 maui-dev-tahoe-dotnet10.0

# Run the pulled VM
tart run maui-dev-tahoe-dotnet10.0
```

---

## Viewing Software Manifests

### Docker Manifests

All Docker images (Linux and Windows) include three manifest formats in:
- **Linux:** `/usr/local/share/`
- **Windows:** `C:\ProgramData\`

#### Linux Containers
```bash
# Start container
docker run -it maui-build:9.0-linux-amd64 bash

# View JSON manifest
cat /usr/local/share/installed-software.json | jq .

# View SPDX SBOM
cat /usr/local/share/installed-software.spdx.json | jq .

# View CycloneDX SBOM
cat /usr/local/share/installed-software.cdx.json | jq .

# Query specific packages
jq '.dotnet.workloads' /usr/local/share/installed-software.json
jq '.packages[] | select(.name == "dotnet-sdk")' /usr/local/share/installed-software.spdx.json
jq '.components[] | select(.type == "framework")' /usr/local/share/installed-software.cdx.json
```

#### Windows Containers
```powershell
# Start container
docker run -it maui-build:9.0-windows-amd64 powershell

# View JSON manifest
Get-Content C:\ProgramData\installed-software.json | ConvertFrom-Json

# View SPDX SBOM
Get-Content C:\ProgramData\installed-software.spdx.json | ConvertFrom-Json

# View CycloneDX SBOM
Get-Content C:\ProgramData\installed-software.cdx.json | ConvertFrom-Json
```

#### Copy Manifests from Container
```bash
# Linux container
docker cp <container-id>:/usr/local/share/installed-software.json ./
docker cp <container-id>:/usr/local/share/installed-software.spdx.json ./
docker cp <container-id>:/usr/local/share/installed-software.cdx.json ./

# Windows container
docker cp <container-id>:C:/ProgramData/installed-software.json ./
docker cp <container-id>:C:/ProgramData/installed-software.spdx.json ./
docker cp <container-id>:C:/ProgramData/installed-software.cdx.json ./
```

### Tart VM Manifests

All Tart VMs include four manifest formats in `/usr/local/share/` with symlinks in `~/`:

#### Inside a Running VM
```bash
# SSH into VM
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0)

# View markdown manifest (human-readable)
cat ~/installed-software.md
less ~/installed-software.md

# View JSON manifest
cat ~/installed-software.json | jq .

# View SPDX SBOM
cat ~/installed-software.spdx.json | jq .

# View CycloneDX SBOM
cat ~/installed-software.cdx.json | jq .

# Query specific information
jq '.dotnet.workloads' ~/installed-software.json
jq '.xcode.installedVersions' ~/installed-software.json
jq '.packages[] | select(.name == "Xcode")' ~/installed-software.spdx.json
jq '.components[] | select(.type == "operating-system")' ~/installed-software.cdx.json
```

#### Copy Manifests from VM
```bash
# Get VM IP
VM_IP=$(tart ip maui-dev-tahoe-dotnet10.0)

# Copy manifests to host
scp admin@${VM_IP}:installed-software.md ./
scp admin@${VM_IP}:installed-software.json ./
scp admin@${VM_IP}:installed-software.spdx.json ./
scp admin@${VM_IP}:installed-software.cdx.json ./

# Or using full paths
scp admin@${VM_IP}:/usr/local/share/installed-software.spdx.json ./
```

---

## SBOM Formats

All images include industry-standard SBOM formats for supply chain security and compliance.

### Format Comparison

| Format | Standard | Best For |
|--------|----------|----------|
| **JSON** | Custom | Internal automation, CI/CD scripts |
| **Markdown** | Custom | Human reading (Tart VMs only) |
| **SPDX 2.3** | ISO/IEC 5962:2021 | Compliance, government, enterprises |
| **CycloneDX 1.6** | ECMA-424 (OWASP) | DevSecOps, vulnerability management |

### Available Formats by Platform

| Platform | Markdown | JSON | SPDX | CycloneDX |
|----------|----------|------|------|-----------|
| Docker Linux | ❌ | ✅ | ✅ | ✅ |
| Docker Windows | ❌ | ✅ | ✅ | ✅ |
| Tart macOS | ✅ | ✅ | ✅ | ✅ |

### What's Included in SBOMs

**All Platforms:**
- Operating System (version, build, architecture)
- .NET SDK and workloads
- .NET global tools
- Android SDK (platforms and build tools)
- Java/JDK version
- Development tools

**Tart VMs (macOS) Only:**
- Xcode versions and build numbers
- iOS/macOS SDKs
- Homebrew packages
- Ruby, Python, Node.js

**Docker Containers:**
- Distribution-specific packages
- Container-specific tools

### Example Queries

**Find specific .NET workload:**
```bash
# JSON
jq '.dotnet.workloads | contains(["maui"])' installed-software.json

# SPDX
jq '.packages[] | select(.name | contains("workload-maui"))' installed-software.spdx.json

# CycloneDX
jq '.components[] | select(.name | contains("workload-maui"))' installed-software.cdx.json
```

**List all Android platforms:**
```bash
# JSON
jq '.android.platforms[]' installed-software.json

# SPDX
jq -r '.packages[] | select(.name | contains("platforms;android")) | .name' installed-software.spdx.json

# CycloneDX
jq -r '.components[] | select(.name | contains("android-platform")) | .name' installed-software.cdx.json
```

**Export for compliance:**
```bash
# Create compliance archive with all formats
mkdir compliance
cp installed-software.* compliance/
tar -czf sbom-$(date +%Y%m%d).tar.gz compliance/
```

---

## Checking for Workload Updates

Check for new .NET workload versions:

```bash
# Check .NET 9.0
pwsh ./check-workload-updates.ps1 -DotnetVersion "9.0"

# Check .NET 10.0
pwsh ./check-workload-updates.ps1 -DotnetVersion "10.0"
```

---

## Troubleshooting

### Docker Build Issues

**Linux containers not building:**
```bash
# Ensure Docker is running and set to Linux containers
docker info
```

**Windows containers not building:**
```powershell
# Switch Docker Desktop to Windows containers mode
# Right-click Docker tray icon → "Switch to Windows containers"

# Verify
docker version
```

**Permission issues:**
```bash
# Add your user to docker group (Linux/macOS)
sudo usermod -aG docker $USER
# Log out and back in
```

### Tart VM Issues

**Tart command not found:**
```bash
brew install cirruslabs/cli/tart
```

**VM won't start:**
```bash
# Check if VM exists
tart list

# Check for errors
tart run maui-dev-tahoe-dotnet10.0 --verbose
```

**Can't SSH into VM:**
```bash
# Wait for VM to fully boot (20-30 seconds)
sleep 30

# Verify VM is running
tart list

# Get IP and test
tart ip maui-dev-tahoe-dotnet10.0
ping $(tart ip maui-dev-tahoe-dotnet10.0)
```

### Manifest Generation Issues

**Manifests not generated in Docker images:**
```bash
# Check build logs for errors
docker build --progress=plain ...

# Manually test scripts
docker run -it <image> bash
/tmp/generate-software-manifest.json.sh /tmp/test.json
```

**Manifests not generated in Tart VMs:**
```bash
# SSH into VM and check
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0)
ls -la /usr/local/share/installed-software*
ls -la ~/installed-software*

# Manually regenerate
/tmp/generate-software-manifest.sh /tmp/test.md
```

---

## Additional Resources

- **Main README**: [README.md](README.md)
- **CLAUDE.md**: [CLAUDE.md](CLAUDE.md) - Repository overview for AI assistance
- **Tart Documentation**: [macos/tart/README.md](macos/tart/README.md)
- **Software Manifest Guide**: [macos/tart/SOFTWARE-MANIFEST.md](macos/tart/SOFTWARE-MANIFEST.md)
- **PR Validation**: [.github/PR-VALIDATION.md](.github/PR-VALIDATION.md)

---

## Quick Reference

### Build Everything Locally

```bash
# Docker Linux - .NET 9.0
pwsh ./docker/linux/build.ps1 -DotnetVersion "9.0" -DockerRepository "maui-build" -Load

# Docker Linux - .NET 10.0
pwsh ./docker/linux/build.ps1 -DotnetVersion "10.0" -DockerRepository "maui-build" -Load

# Tart VM - .NET 9.0
pwsh ./tart/macos/scripts/quick-start.ps1 -BuildType maui -DotnetChannel 9.0

# Tart VM - .NET 10.0
pwsh ./tart/macos/scripts/quick-start.ps1 -BuildType maui -DotnetChannel 10.0
```

### View All Manifests

```bash
# Docker Linux
docker run -it maui-build:latest bash -c "ls -la /usr/local/share/installed-software*"

# Tart VM
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) "ls -la ~/installed-software*"
```

### Export SBOMs for Compliance

```bash
# Docker
docker cp <container-id>:/usr/local/share/installed-software.spdx.json ./sbom-docker-$(date +%Y%m%d).spdx.json
docker cp <container-id>:/usr/local/share/installed-software.cdx.json ./sbom-docker-$(date +%Y%m%d).cdx.json

# Tart VM
scp admin@$(tart ip maui-dev-tahoe-dotnet10.0):installed-software.spdx.json ./sbom-macos-$(date +%Y%m%d).spdx.json
scp admin@$(tart ip maui-dev-tahoe-dotnet10.0):installed-software.cdx.json ./sbom-macos-$(date +%Y%m%d).cdx.json
```
