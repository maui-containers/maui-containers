# Tart VM Images for MAUI Development

This directory contains scripts and templates for building custom macOS VM images using [Cirrus Labs Tart](https://tart.run/) for .NET MAUI development.

## Overview

Tart VMs provide a Docker-like experience for macOS, allowing you to:
- Create reproducible development environments
- Run CI/CD pipelines on macOS
- Provision multiple macOS versions with different tool configurations
- Share development environments across teams

## Directory Structure

```
tart/
├── templates/          # Packer templates for VM creation
│   └── maui.pkr.hcl   # MAUI development and CI helper image
├── scripts/           # Build and automation scripts
│   ├── build.ps1      # Main build script
│   ├── provision.sh   # VM provisioning script
│   └── test.ps1       # Image testing script
├── ansible/           # Ansible playbooks for configuration
│   ├── base.yml       # Base system configuration
│   ├── maui.yml       # MAUI tooling setup
│   └── xcode.yml      # Xcode installation
├── config/            # Configuration files
│   ├── platform-matrix.json # macOS/.NET/Xcode target matrix
│   ├── variables.json      # Shared resource/tool defaults
│   └── .cirrus.yml         # Optional Cirrus CI example
└── README.md          # This file
```

## Prerequisites

1. **Tart**: Install via Homebrew
   ```bash
   brew install cirruslabs/cli/tart
   ```

2. **Packer**: For automated image building
   ```bash
   brew install packer
   ```

3. **Ansible** (optional): For advanced configuration
   ```bash
   brew install ansible
   ```

## Quick Start

### 1. Build MAUI Development Image (Sequoia)
```bash
pwsh ./scripts/build.ps1 -ImageType maui -MacOSVersion sequoia -DotnetChannel 10.0
```
> The script resolves `-BaseXcodeVersion` from `config/platform-matrix.json` when you omit it.

### 2. Build MAUI Preview Image (Tahoe + Xcode 26)
```bash
# Uses pinned SHA256 digest from platform-matrix.json
pwsh ./scripts/build.ps1 -ImageType maui -MacOSVersion tahoe -DotnetChannel 10.0
```

### 3. Run a VM
```bash
tart run maui-dev-sequoia
```

### 4. Test Built Image
```bash
pwsh ./scripts/test.ps1 -ImageName maui-dev-sequoia -TestType maui
```

### 5. (Optional) Run custom startup logic
Mount a config folder containing `init.sh` to run your own bootstrap after the VM starts:
```bash
tart run maui-dev-sequoia --dir config:/path/to/config
```

## Image Types

### MAUI Development Image (`maui.pkr.hcl`)
- Built directly on Cirrus Labs `macos-<version>-xcode:<tag>` VMs
- Installs .NET SDK and MAUI workloads
- Adds Xcode tooling, iOS simulators, Android SDK, and VS Code
- Supports custom startup logic through a mounted `config/init.sh`

## Configuration

- `config/platform-matrix.json`: source of truth for macOS keys, the Xcode tags to install, and the .NET channel mappings used by `scripts/build.ps1`.
- `config/variables.json`: shared resource and tooling defaults (CPU, memory, disk size, tool switches) that the Packer templates consume.
- `config/.cirrus.yml`: optional Cirrus CI example; safe to ignore if you are not using their hosted service.

## Usage Examples

### Development Workflow
```bash
# Build and start development environment
pwsh ./scripts/build.ps1 -ImageType maui -MacOSVersion sequoia -DotnetChannel 10.0
tart run maui-dev-sequoia --dir project:/path/to/your/project

# Inside VM - access project at /Volumes/My Shared Files/project
cd "/Volumes/My Shared Files/project"
dotnet build
```

To target the Tahoe preview stack, use `-MacOSVersion tahoe` when calling `build.ps1`. The base Xcode version is pinned via SHA256 digest in `platform-matrix.json`.

### CI/CD Integration
```yaml
# .cirrus.yml
task:
  name: maui-build
  macos_instance:
    image: your-registry/maui-dev-sequoia:latest
  build_script:
    - dotnet restore
    - dotnet build
    - dotnet test
```

## Best Practices

1. **Version Pinning**: Pin specific versions in templates
2. **Resource Management**: Allocate appropriate CPU/memory
3. **Directory Mounting**: Use `--dir` for project access
4. **Custom Automation**: Use a mounted `config/init.sh` for project-specific startup or runner setup
5. **SSH Access**: Configure for automation and debugging
6. **Image Registry**: Push to container registry for sharing

## Troubleshooting

### Common Issues
- **SSH Connection**: Ensure VM has SSH enabled
- **Directory Mounting**: Requires macOS 13+ on host and guest
- **Performance**: Allocate sufficient resources for Xcode builds
- **Networking**: Configure bridge networking for external access

### Debugging
```bash
# SSH into running VM
tart ip <vm-name>
ssh admin@<ip-address>

# View VM logs
tart log <vm-name>

# List running VMs
tart list
```

## Integration with Existing Provisioning

The Tart images can use the same `MauiProvisioning` module:
```bash
# Inside VM
pwsh /path/to/provision.ps1 -DotnetChannel 10.0
```

This ensures consistency between containerized Docker environments and Tart VMs.
