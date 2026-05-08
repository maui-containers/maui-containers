# Set build arguments that need to be available before FROM
ARG DOTNET_VERSION=9.0

# Use .NET SDK base image with dynamic version
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}-windowsservercore-ltsc2022

# Set build arguments
ARG JDK_MAJOR_VERSION=21
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG DOTNET_WORKLOADS_VERSION=9.0.203

ENV JDK_MAJOR_VERSION=$JDK_MAJOR_VERSION
ENV ANDROID_SDK_API_LEVEL=$ANDROID_SDK_API_LEVEL
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=$ANDROID_SDK_BUILD_TOOLS_VERSION
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=$ANDROID_SDK_CMDLINE_TOOLS_VERSION
ENV DOTNET_VERSION=$DOTNET_VERSION
ENV DOTNET_WORKLOADS_VERSION=$DOTNET_WORKLOADS_VERSION

# OCI Image labels for registry metadata and discoverability
LABEL org.opencontainers.image.title="MAUI Windows Development Container" \
      org.opencontainers.image.description=".NET MAUI development environment for Windows with Android SDK" \
      org.opencontainers.image.vendor="MAUI Containers" \
      org.opencontainers.image.source="https://github.com/maui-containers/maui-containers" \
      org.opencontainers.image.documentation="https://github.com/maui-containers/maui-containers/blob/main/README.md" \
      org.opencontainers.image.url="https://github.com/maui-containers/maui-containers" \
      org.opencontainers.image.licenses="MIT" \
      dev.maui-containers.dotnet-version="$DOTNET_VERSION" \
      dev.maui-containers.workload-set-version="$DOTNET_WORKLOADS_VERSION" \
      dev.maui-containers.android-api-level="$ANDROID_SDK_API_LEVEL" \
      dev.maui-containers.android-build-tools="$ANDROID_SDK_BUILD_TOOLS_VERSION" \
      dev.maui-containers.android-cmdline-tools="$ANDROID_SDK_CMDLINE_TOOLS_VERSION" \
      dev.maui-containers.jdk-version="$JDK_MAJOR_VERSION"

ENV INIT_PWSH_SCRIPT="C:/config/init.ps1"

# Set core environment variables
ENV ANDROID_HOME="C:/android-sdk"
ENV ANDROID_SDK_ROOT="C:/android-sdk"
ENV LOG_PATH="C:\\logs\\"

# .NET CLI environment — grant the Users group modify rights on the SDK tree
# (see icacls step below) so CI can install/update workloads and global tools
# whether the container runs as ContainerAdministrator or ContainerUser. Pin
# NUGET_PACKAGES under the user profile to avoid a machine-wide cache getting
# layered in from a future base image.
ENV DOTNET_INSTALL_DIR="C:\\Program Files\\dotnet"
ENV DOTNET_MULTILEVEL_LOOKUP="0"
ENV DOTNET_CLI_TELEMETRY_OPTOUT="1"
ENV DOTNET_NOLOGO="1"
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE="1"
ENV NUGET_PACKAGES="C:\\Users\\ContainerUser\\.nuget\\packages"

# Set PowerShell as the default shell
SHELL ["powershell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Create log directory
RUN New-Item -ItemType Directory -Path $env:LOG_PATH -Force

# Install chocolatey (winget won't install on server core)
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    choco install git -y;

# Install Node.js and npm
RUN choco install nodejs-lts -y

# Install OpenJDK. Chocolatey has version-specific packages for some JDK majors
# (for example microsoft-openjdk17) but JDK 21 is published under the generic
# microsoft-openjdk package with versioned releases.
RUN $specificJdkPackage = 'microsoft-openjdk' + $env:JDK_MAJOR_VERSION; \
    $specificJdkPackageMatch = choco search $specificJdkPackage --exact --limit-output | Where-Object { $_.StartsWith($specificJdkPackage + '|') } | Select-Object -First 1; \
    if ($specificJdkPackageMatch) { \
        choco install $specificJdkPackage -y; \
    } else { \
        $jdkPackageVersion = choco search microsoft-openjdk --exact --all-versions --limit-output | ForEach-Object { $packageParts = $_.Split('|'); if ($packageParts.Length -eq 2 -and $packageParts[0] -eq 'microsoft-openjdk' -and $packageParts[1].StartsWith($env:JDK_MAJOR_VERSION + '.')) { $packageParts[1] } } | Sort-Object { [version]$_ } -Descending | Select-Object -First 1; \
        if (-not $jdkPackageVersion) { throw ('Could not find Microsoft OpenJDK package version for JDK ' + $env:JDK_MAJOR_VERSION) } \
        choco install microsoft-openjdk --version=$jdkPackageVersion -y; \
    }

# Grant the Users group modify rights on the .NET SDK tree so non-admin
# container users can install/update workloads and global tools without
# elevation. This is a no-op for ContainerAdministrator but unblocks CI
# scenarios that run as ContainerUser.
RUN icacls 'C:\Program Files\dotnet' /grant '*S-1-5-32-545:(OI)(CI)M' /T /C | Out-Null

# Install the Workloads
RUN dotnet workload install maui android ios maccatalyst macos wasm-tools tvos --version $env:DOTNET_WORKLOADS_VERSION

# Install Android SDK Tool & AppleDev Tool
RUN dotnet tool install -g AndroidSdk.Tool
RUN dotnet tool install -g AppleDev.Tools

# Install and configure Android SDK
RUN android sdk download --home="$env:ANDROID_HOME"

RUN android sdk install --package="platform-tools"
RUN $buildToolsPackage = 'build-tools;' + $env:ANDROID_SDK_BUILD_TOOLS_VERSION; \
    android sdk install --package=$buildToolsPackage
RUN $cmdlineToolsPackage = 'cmdline-tools;' + $env:ANDROID_SDK_CMDLINE_TOOLS_VERSION; \
    android sdk install --package=$cmdlineToolsPackage
RUN $platformsPackage = 'platforms;' + $env:ANDROID_SDK_API_LEVEL; \
    android sdk install --package=$platformsPackage

RUN android sdk info --format=json > $env:LOG_PATH/sdk_info.json
RUN android sdk list --installed --format=json > $env:LOG_PATH/sdk_list.json

# Accept Android Licenses
RUN android sdk accept-licenses --force --home="$env:ANDROID_HOME"

# Copy the init and entrypoint scripts
COPY scripts/init.ps1 C:/init.ps1
COPY scripts/entrypoint.ps1 C:/entrypoint.ps1

# Copy software manifest generation scripts
COPY scripts/Generate-SoftwareManifest.ps1 C:/temp/Generate-SoftwareManifest.ps1
COPY scripts/Generate-SpdxManifest.ps1 C:/temp/Generate-SpdxManifest.ps1
COPY scripts/Generate-CycloneDxManifest.ps1 C:/temp/Generate-CycloneDxManifest.ps1

# Generate software manifests (JSON, SPDX, CycloneDX)
RUN New-Item -ItemType Directory -Path C:/ProgramData -Force -ErrorAction SilentlyContinue; \
    & C:/temp/Generate-SoftwareManifest.ps1 -OutputFile C:/ProgramData/installed-software.json; \
    & C:/temp/Generate-SpdxManifest.ps1 -SourceJson C:/ProgramData/installed-software.json -OutputFile C:/ProgramData/installed-software.spdx.json; \
    & C:/temp/Generate-CycloneDxManifest.ps1 -SourceJson C:/ProgramData/installed-software.json -OutputFile C:/ProgramData/installed-software.cdx.json

# Return to root
WORKDIR C:/

# Use ENTRYPOINT to run initialization hooks, CMD is user-overridable
ENTRYPOINT ["powershell.exe", "-File", "C:/entrypoint.ps1"]
CMD ["powershell.exe", "-Command", "while ($true) { Start-Sleep -Seconds 30 }"]
