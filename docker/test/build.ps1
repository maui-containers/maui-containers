# Test images are for running Android emulators and Appium tests only.
# They do not require .NET MAUI workloads since no MAUI building happens on these images.
# The purpose is to provide a quick emulator for the specified API level.

Param(
    [String]$DockerRepository="ghcr.io/maui-containers/maui-emulator-linux",
    [String]$DockerPlatform="linux/amd64",
    [String]$AndroidSdkApiLevel=35,
    [String]$Version="latest",
    [String]$WorkloadSetVersion="",
    [String]$DotnetVersion="9.0",
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

# Import common functions for Appium version detection
# NOTE: We only use this for Get-LatestAppiumVersions, not for workload detection
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

# Default Android SDK component versions (will be overridden by workload detection)
# These values are used as fallbacks if workload detection fails
$androidBuildToolsVersion = "35.0.0"
$androidCmdLineToolsVersion = "13.0"
$androidJdkMajorVersion = "17"
$androidAvdSystemImageType = "google_apis"
$androidAvdDeviceType = "Nexus 5X"

# Get comprehensive workload information with a single call
Write-Host "Getting workload information for Android SDK dependencies..."
$workloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetVersion -WorkloadSetVersion $WorkloadSetVersion -IncludeAndroid -DockerPlatform $DockerPlatform

if (-not $workloadInfo) {
    Write-Error "Failed to get workload information."
    exit 1
}

# Extract Android-specific information
$androidWorkload = $workloadInfo.Workloads["Microsoft.NET.Sdk.Android"]
if (-not $androidWorkload) {
    Write-Error "Could not find Android workload in the workload set."
    exit 1
}

# Extract Android details if available
$androidDetails = $androidWorkload.Details
if (-not $androidDetails) {
    Write-Error "Could not extract Android details from workload."
    exit 1
}

Write-Host "Android workload details retrieved successfully:"
Write-Host "  API Level: $($androidDetails.ApiLevel)"
Write-Host "  Build Tools Version: $($androidDetails.BuildToolsVersion)"
Write-Host "  Command Line Tools Version: $($androidDetails.CmdLineToolsVersion)"
Write-Host "  JDK Major Version: $($androidDetails.JdkMajorVersion)"
Write-Host "  System Image Type: $($androidDetails.SystemImageType)"
Write-Host "  AVD Device Type: $($androidDetails.AvdDeviceType)"

# Use workload-detected values for Android SDK components (override hardcoded values)
$androidBuildToolsVersion = $androidDetails.BuildToolsVersion
$androidCmdLineToolsVersion = $androidDetails.CmdLineToolsVersion
$androidJdkMajorVersion = $androidDetails.JdkMajorVersion
$androidAvdSystemImageType = $androidDetails.SystemImageType
$androidAvdDeviceType = $androidDetails.AvdDeviceType

# Extract the dotnet command version for Docker tags
$dotnetCommandWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion

# Determine which Android SDK API level to use
# Use the parameter provided, which could be from the matrix or a specific override
Write-Host "Using Android SDK API Level: $AndroidSdkApiLevel (from parameter/matrix)"
Write-Host "Workload default API Level: $($androidDetails.ApiLevel) (will be available in the built image)"

# Build tags following the unified naming scheme:
# - android{XX}-dotnet{X.Y} - Latest workload for this .NET version
# - android{XX}-dotnet{X.Y}-workloads{X.Y.Z} - Specific workload version
# - android{XX}-dotnet{X.Y}-workloads{X.Y.Z}-v{sha} - SHA-pinned version (optional)
# If Version is not "latest", also add a custom version tag
$tags = @()

# 1. android{XX}-dotnet{X.Y} tag (this is the "latest" for this .NET version + API level)
$dotnetTag = "${DockerRepository}:android${AndroidSdkApiLevel}-dotnet${DotnetVersion}"
$tags += $dotnetTag

# 2. android{XX}-dotnet{X.Y}-workloads{X.Y.Z} tag
$workloadTag = "${DockerRepository}:android${AndroidSdkApiLevel}-dotnet${DotnetVersion}-workloads${dotnetCommandWorkloadSetVersion}"
$tags += $workloadTag

# 3. Optional: android{XX}-dotnet{X.Y}-workloads{X.Y.Z}-v{sha} tag
if ($BuildSha) {
    $shaTag = "${DockerRepository}:android${AndroidSdkApiLevel}-dotnet${DotnetVersion}-workloads${dotnetCommandWorkloadSetVersion}-v${BuildSha}"
    $tags += $shaTag
}

# 4. Optional: Custom version tag (for PR builds, etc.)
if ($Version -ne "latest") {
    $customTag = "${DockerRepository}:android${AndroidSdkApiLevel}-dotnet${DotnetVersion}-${Version}"
    $tags += $customTag
}

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
