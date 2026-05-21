# Test images are for running Android emulators and Appium tests only.
# They do not require .NET MAUI workloads since no MAUI building happens on these images.
# The purpose is to provide a quick emulator for the specified API level.

Param(
    [String]$DockerRepository="ghcr.io/maui-containers/maui-emulator-linux",
    [String]$DockerPlatform="linux/amd64",
    [String]$AndroidSdkApiLevel=35,
    [String]$Version="latest",
    [String]$DotnetVersion="10.0",
    [String]$DotnetSdkImageTag="",
    [String]$DotnetRuntimeImageTag="",
    [String]$AndroidSdkBuildToolsVersion="36.0.0",
    [String]$AndroidSdkCmdLineToolsVersion="19.0",
    [String]$AndroidAvdDeviceType="Nexus 5",
    [String]$AndroidAvdSystemImageType="google_apis",
    [String]$JdkMajorVersion="21",
    [String]$WorkloadSetVersion="",
    [String]$AppiumVersion="",
    [String]$AppiumUIAutomator2DriverVersion="",
    [String]$BuildSha="",
    [switch]$Load,
    [switch]$Push,
    [switch]$UseBuildx) 

if ($DockerPlatform.StartsWith('linux/')) {
    $dockerTagBase = "appium-emulator-linux"
} else {
    # Error not supported platform
    Write-Error "Unsupported Docker platform: $DockerPlatform"
    exit 1
}

# Import common functions for Appium version detection and .NET base image tags.
$commonFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\common-functions.ps1" -Resolve -ErrorAction SilentlyContinue

if ($commonFunctionsPath -and (Test-Path -Path $commonFunctionsPath -PathType Leaf)) {
    . $commonFunctionsPath
    Write-Host "Imported common functions from $commonFunctionsPath"
} else {
    Write-Error "Could not find common functions file at expected path: ..\..\common-functions.ps1"
    exit 1
}

# Get latest Appium versions if not provided
if ([string]::IsNullOrEmpty($AppiumVersion) -or [string]::IsNullOrEmpty($AppiumUIAutomator2DriverVersion)) {
    Write-Host "Getting latest Appium versions from npm..."
    $latestAppiumVersions = Get-LatestAppiumVersions

    if ([string]::IsNullOrEmpty($AppiumVersion)) {
        if ($latestAppiumVersions.AppiumVersion) {
            $AppiumVersion = $latestAppiumVersions.AppiumVersion
            Write-Host "Using latest Appium version: $AppiumVersion"
        } else {
            $AppiumVersion = "2.11.0"  # Fallback version
            Write-Warning "Could not get latest Appium version, using fallback: $AppiumVersion"
        }
    }

    if ([string]::IsNullOrEmpty($AppiumUIAutomator2DriverVersion)) {
        if ($latestAppiumVersions.UIAutomator2DriverVersion) {
            $AppiumUIAutomator2DriverVersion = $latestAppiumVersions.UIAutomator2DriverVersion
            Write-Host "Using latest Appium UIAutomator2 driver version: $AppiumUIAutomator2DriverVersion"
        } else {
            $AppiumUIAutomator2DriverVersion = "3.6.0"  # Fallback version
            Write-Warning "Could not get latest Appium UIAutomator2 driver version, using fallback: $AppiumUIAutomator2DriverVersion"
        }
    }
} else {
    Write-Host "Using provided Appium versions:"
    Write-Host "  Appium: $AppiumVersion"
    Write-Host "  UIAutomator2 Driver: $AppiumUIAutomator2DriverVersion"
}

# Emulator images are not MAUI build images, so keep Android SDK inputs explicit
# instead of coupling emulator tags and builds to .NET workload set versions.
if (-not [string]::IsNullOrWhiteSpace($WorkloadSetVersion)) {
    Write-Warning "WorkloadSetVersion is ignored for emulator images. Android SDK components are configured directly."
}

$requiredSettings = @{
    AndroidSdkBuildToolsVersion   = $AndroidSdkBuildToolsVersion
    AndroidSdkCmdLineToolsVersion = $AndroidSdkCmdLineToolsVersion
    AndroidAvdDeviceType          = $AndroidAvdDeviceType
    AndroidAvdSystemImageType     = $AndroidAvdSystemImageType
    JdkMajorVersion               = $JdkMajorVersion
}

foreach ($setting in $requiredSettings.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace($setting.Value)) {
        Write-Error "$($setting.Key) is required."
        exit 1
    }
}

$androidBuildToolsVersion = $AndroidSdkBuildToolsVersion
$androidCmdLineToolsVersion = $AndroidSdkCmdLineToolsVersion
$androidJdkMajorVersion = $JdkMajorVersion
$androidAvdSystemImageType = $AndroidAvdSystemImageType
$androidAvdDeviceType = $AndroidAvdDeviceType

$dotnetImageTags = Get-DotnetContainerImageTags -DotnetVersion $DotnetVersion -DockerPlatform $DockerPlatform

if (-not [string]::IsNullOrWhiteSpace($DotnetSdkImageTag)) {
    $dotnetImageTags.Sdk = $DotnetSdkImageTag
}

if (-not [string]::IsNullOrWhiteSpace($DotnetRuntimeImageTag)) {
    $dotnetImageTags.Runtime = $DotnetRuntimeImageTag
}

Write-Host "Using .NET SDK image tag: $($dotnetImageTags.Sdk)"
Write-Host "Using .NET runtime image tag: $($dotnetImageTags.Runtime)"

Write-Host "Using Android SDK settings:"
Write-Host "  API Level: $AndroidSdkApiLevel"
Write-Host "  Build Tools Version: $androidBuildToolsVersion"
Write-Host "  Command Line Tools Version: $androidCmdLineToolsVersion"
Write-Host "  JDK Major Version: $androidJdkMajorVersion"
Write-Host "  System Image Type: $androidAvdSystemImageType"
Write-Host "  AVD Device Type: $androidAvdDeviceType"

# Build tags. The API-level tag is primary; dotnet-suffixed tags are kept as
# compatibility aliases for existing consumers.
$tags = @()
$primaryTag = "${DockerRepository}:android${AndroidSdkApiLevel}"
$legacyDotnetTag = "${DockerRepository}:android${AndroidSdkApiLevel}-dotnet${DotnetVersion}"
$tags += $primaryTag
$tags += $legacyDotnetTag

if ($BuildSha) {
    $shaTag = "${DockerRepository}:android${AndroidSdkApiLevel}-v${BuildSha}"
    $legacyShaTag = "${DockerRepository}:android${AndroidSdkApiLevel}-dotnet${DotnetVersion}-v${BuildSha}"
    $tags += $shaTag
    $tags += $legacyShaTag
}

if ($Version -ne "latest") {
    $customTag = "${DockerRepository}:android${AndroidSdkApiLevel}-${Version}"
    $legacyCustomTag = "${DockerRepository}:android${AndroidSdkApiLevel}-dotnet${DotnetVersion}-${Version}"
    $tags += $customTag
    $tags += $legacyCustomTag
}

$tags = $tags | Select-Object -Unique

Write-Host "Docker tags that will be created:"
foreach ($tag in $tags) {
    Write-Host "  $tag"
}

# Define docker arguments
$commonArgs = @(
    "--build-arg", "ANDROID_SDK_API_LEVEL=$AndroidSdkApiLevel",
    "--build-arg", "ANDROID_SDK_BUILD_TOOLS_VERSION=$androidBuildToolsVersion",
    "--build-arg", "ANDROID_SDK_CMDLINE_TOOLS_VERSION=$androidCmdLineToolsVersion",
    "--build-arg", "ANDROID_SDK_AVD_DEVICE_TYPE=$androidAvdDeviceType",
    "--build-arg", "ANDROID_SDK_AVD_SYSTEM_IMAGE_TYPE=$androidAvdSystemImageType",
    "--build-arg", "APPIUM_VERSION=$AppiumVersion",
    "--build-arg", "APPIUM_UIAUTOMATOR2_DRIVER_VERSION=$AppiumUIAutomator2DriverVersion",
    "--build-arg", "JDK_MAJOR_VERSION=$androidJdkMajorVersion",
    "--build-arg", "DOTNET_VERSION=$DotnetVersion",
    "--build-arg", "DOTNET_SDK_IMAGE_TAG=$($dotnetImageTags.Sdk)",
    "--build-arg", "DOTNET_RUNTIME_IMAGE_TAG=$($dotnetImageTags.Runtime)",
    "--label", "org.opencontainers.image.version=android$AndroidSdkApiLevel",
    "--label", "org.opencontainers.image.created=$(Get-Date -Format 'o')",
    "--label", "org.opencontainers.image.revision=$BuildSha",
    "--label", "dev.maui-containers.dotnet-base=$DotnetVersion",
    "-f", "Dockerfile",
    "."
)

# Add all tags
foreach ($tag in $tags) {
    $commonArgs += @("-t", $tag)
}

$dockerArgs = @()
if ($UseBuildx) {
    $dockerArgs += @("buildx", "build", "--platform", "linux/amd64")
    if ($Load) {
        Write-Host "Adding --load flag for Linux build"
        $dockerArgs += "--load"
    }
} else {
    $dockerArgs += "build"
}

$dockerArgs += $commonArgs

# Change to the test directory to ensure correct build context
Push-Location $PSScriptRoot

try {
    # Execute the docker command with all arguments
    Write-Host "Running docker $($dockerArgs -join ' ')"
    & docker $dockerArgs
    Write-Host "Docker build command completed with exit code: $LASTEXITCODE"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # Output version information for CI build summaries
    if ($env:GITHUB_OUTPUT) {
        Write-Host "Writing version info to GITHUB_OUTPUT for build summary..."
        "dotnet_version=$DotnetVersion" >> $env:GITHUB_OUTPUT
        "dotnet_sdk_image_tag=$($dotnetImageTags.Sdk)" >> $env:GITHUB_OUTPUT
        "dotnet_runtime_image_tag=$($dotnetImageTags.Runtime)" >> $env:GITHUB_OUTPUT
        "android_api_level=$AndroidSdkApiLevel" >> $env:GITHUB_OUTPUT
        "android_build_tools=$androidBuildToolsVersion" >> $env:GITHUB_OUTPUT
        "android_cmdline_tools=$androidCmdLineToolsVersion" >> $env:GITHUB_OUTPUT
        "android_avd_device=$androidAvdDeviceType" >> $env:GITHUB_OUTPUT
        "android_system_image=$androidAvdSystemImageType" >> $env:GITHUB_OUTPUT
        "jdk_version=$androidJdkMajorVersion" >> $env:GITHUB_OUTPUT
        "appium_version=$AppiumVersion" >> $env:GITHUB_OUTPUT
        "appium_uiautomator2_version=$AppiumUIAutomator2DriverVersion" >> $env:GITHUB_OUTPUT
        "docker_platform=$DockerPlatform" >> $env:GITHUB_OUTPUT
        "image_tags=$($tags -join '|')" >> $env:GITHUB_OUTPUT
    }
} finally {
    # Always return to original directory
    Pop-Location
}



if ($Push) {
    # Push the image to the Docker repository
    $pushArgs = @(
        "push",
        "--all-tags",
        "${DockerRepository}"
    )

    & docker $pushArgs
    Write-Host "Docker push command completed with exit code: $LASTEXITCODE"
}
