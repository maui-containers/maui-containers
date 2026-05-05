# MAUI Docker Images

This directory contains Docker images that provide a complete .NET MAUI development environment. These images are designed to be used as standalone development environments or as base images for custom tooling.

## Structure

- `linux/` - Linux MAUI development images
- `windows/` - Windows MAUI development images  
- `test/` - Android emulator + Appium test images (Linux only)
- `build.ps1` - Cross-platform build script for Linux and Windows images

## What's Included

### Both Linux and Windows images include:
- **.NET SDK** - Latest .NET SDK with MAUI workloads
- **Android SDK** - Complete Android development environment
- **Java/OpenJDK** - Required Java runtime for Android development
- **PowerShell** - Cross-platform PowerShell (Linux images)
- **Development Tools** - Git, build tools, and other essential development utilities

### Linux-specific additions:
- **Standard development tools** - curl, wget, unzip, etc.

### Windows-specific additions:
- **Chocolatey** - Package manager for Windows
- **Windows development tools** - Essential Windows development utilities

## Usage

These base images can be used for local development or extended with your own startup scripts and tooling.

### As a Development Container

```bash
docker run -it ghcr.io/maui-containers/maui-linux:dotnet9.0 bash
```

### Example Dockerfile using the base image:

```dockerfile
FROM ghcr.io/maui-containers/maui-linux:dotnet9.0

# Add your custom requirements here
COPY your-app /app
WORKDIR /app

# Your custom commands
RUN dotnet restore
RUN dotnet build

CMD ["dotnet", "run"]
```

## Building the Images

### Using the unified build script (recommended):
```powershell
# Build Linux
./build.ps1 -DockerPlatform "linux/amd64" -DockerRepository "your-repo/maui-build"

# Build Windows  
./build.ps1 -DockerPlatform "windows/amd64" -DockerRepository "your-repo/maui-build"
```

### Using platform-specific scripts:
```powershell
# Linux
./linux/build.ps1 -DockerRepository "your-repo/maui-build" -Version "your-tag"

# Windows
./windows/build.ps1 -DockerRepository "your-repo/maui-build" -Version "your-tag"
```

## Environment Variables

### Development Environment Variables

- `INIT_BASH_SCRIPT` - Path to custom bash initialization script (Linux)
- `INIT_PWSH_SCRIPT` - Path to custom PowerShell initialization script (Both)
- `ANDROID_HOME` - Android SDK location (set automatically)
- `JAVA_HOME` - Java installation location (set automatically)
- `LOG_PATH` - Logging directory (set automatically)

## Default Command

- **Linux**: `tail -f /dev/null` (keeps container running)
- **Windows**: PowerShell infinite loop (keeps container running)

These commands allow the containers to stay alive for interactive use or as base images for other services.
