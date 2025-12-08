# Set build arguments that need to be available before FROM
ARG DOTNET_VERSION=9.0

# Use .NET SDK base image with dynamic version
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}-windowsservercore-ltsc2022

# Set build arguments
ARG JDK_MAJOR_VERSION=17
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG DOTNET_WORKLOADS_VERSION=9.0.203
ARG GITHUB_ACTIONS_RUNNER_VERSION=2.323.0

ENV JDK_MAJOR_VERSION=$JDK_MAJOR_VERSION
ENV ANDROID_SDK_API_LEVEL=$ANDROID_SDK_API_LEVEL
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=$ANDROID_SDK_BUILD_TOOLS_VERSION
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=$ANDROID_SDK_CMDLINE_TOOLS_VERSION
ENV DOTNET_VERSION=$DOTNET_VERSION
ENV DOTNET_WORKLOADS_VERSION=$DOTNET_WORKLOADS_VERSION
ENV GITHUB_ACTIONS_RUNNER_VERSION=$GITHUB_ACTIONS_RUNNER_VERSION

ENV INIT_PWSH_SCRIPT="C:/config/init.ps1"

# GitHub Actions Runner environment variables
ENV GITHUB_ORG=""
ENV GITHUB_REPO=""
ENV GITHUB_TOKEN=""
ENV RUNNER_NAME_PREFIX="maui-runner"
ENV RANDOM_RUNNER_SUFFIX=""
ENV RUNNER_GROUP=""
ENV RUNNER_WORKDIR=""
ENV LABELS=""
ENV DISABLE_AUTO_UPDATE=""
ENV NO_DEFAULT_LABELS=""
ENV EPHEMERAL=""

# Gitea Actions Runner environment variables
ENV GITEA_INSTANCE_URL=""
ENV GITEA_RUNNER_TOKEN=""
ENV GITEA_RUNNER_NAME=""
ENV GITEA_RUNNER_NAME_PREFIX="gitea-runner"
ENV GITEA_RUNNER_LABELS="maui,windows,amd64"

# Set core environment variables
ENV ANDROID_HOME="C:/android-sdk"
ENV ANDROID_SDK_ROOT="C:/android-sdk"
ENV LOG_PATH="C:\\logs\\"

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

# Install openjdk
RUN choco install microsoft-openjdk$($env:JDK_MAJOR_VERSION) -y

# Install the Workloads
RUN dotnet workload install maui wasm-tools --version $env:DOTNET_WORKLOADS_VERSION

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

# Copy the init script and runner script
COPY scripts/init.ps1 C:/init.ps1
COPY scripts/runner.ps1 C:/runner.ps1
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

# Install GitHub Actions Runner
RUN New-Item -ItemType Directory -Path C:/actions-runner -Force
WORKDIR C:/actions-runner
RUN $zipUrl = 'https://github.com/actions/runner/releases/download/v' + $env:GITHUB_ACTIONS_RUNNER_VERSION + '/actions-runner-win-x64-' + $env:GITHUB_ACTIONS_RUNNER_VERSION + '.zip' ; \
    Invoke-WebRequest -Uri $zipUrl -OutFile actions-runner-windows.zip
RUN $zipFile = $PWD.Path + '\\actions-runner-windows.zip' ; \
    Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $PWD) ; \
    Remove-Item -Path $zipFile -Force

# Install Gitea Actions Runner
RUN New-Item -ItemType Directory -Path C:/gitea-runner -Force
WORKDIR C:/gitea-runner
RUN $releases = Invoke-RestMethod -Uri 'https://gitea.com/api/v1/repos/gitea/act_runner/releases' ; \
    $latestVersion = $releases[0].tag_name ; \
    $versionNoPrefix = if ($latestVersion.StartsWith('v')) { $latestVersion.Substring(1) } else { $latestVersion } ; \
    Write-Host \"Downloading act_runner version: $latestVersion\" ; \
    $downloadUrl = \"https://gitea.com/gitea/act_runner/releases/download/$latestVersion/act_runner-$versionNoPrefix-windows-amd64.exe\" ; \
    Invoke-WebRequest -Uri $downloadUrl -OutFile act_runner.exe

# Return to root
WORKDIR C:/

# Use ENTRYPOINT to start runners in background, CMD is user-overridable
ENTRYPOINT ["powershell.exe", "-File", "C:/entrypoint.ps1"]
CMD ["powershell.exe", "-Command", "while ($true) { Start-Sleep -Seconds 30 }"]
