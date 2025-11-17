Param([String]$DotnetVersion="9.0",
    [String]$WorkloadSetVersion="",
    [String]$DockerRepository="",
    [String]$DockerPlatform="linux/amd64",
    [String]$Version="latest",
    [String]$BuildSha="",
    [switch]$Load,
    [switch]$Push)

if ($DockerPlatform.StartsWith('linux/')) {
    $dockerTagBase = "linux"
    if (-not $DockerRepository) {
        $DockerRepository = "ghcr.io/maui-containers/maui-linux"
    }
} else {
    $dockerTagBase = "windows"
    if (-not $DockerRepository) {
        $DockerRepository = "ghcr.io/maui-containers/maui-windows"
    }
}

# Use a more reliable method to import the common functions module
# This handles paths with spaces better and is more explicit
$commonFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\common-functions.ps1" -Resolve -ErrorAction SilentlyContinue

if ($commonFunctionsPath -and (Test-Path -Path $commonFunctionsPath -PathType Leaf)) {
    # Import as a module using the source command for better scoping
    . $commonFunctionsPath
    Write-Host "Imported common functions from $commonFunctionsPath"
} else {
    Write-Error "Could not find common functions file at expected path: ..\common-functions.ps1"
    exit 1
}

# Get comprehensive workload information with a single call
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

# Get the latest GitHub Actions runner version
$githubActionsRunnerVersion = Get-LatestGitHubActionsRunnerVersion

# Extract Android details if available
$androidDetails = $androidWorkload.Details
if (-not $androidDetails) {
    Write-Error "Could not extract Android details from workload."
    exit 1
}

# Extract the dotnet command version for Docker tags
$dotnetCommandWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion

Write-Host "Building MAUI Base Image for $DockerPlatform"
Write-Host "=============================================="
Write-Host ".NET Version: $DotnetVersion"
Write-Host "Workload Set Version: $($workloadInfo.WorkloadSetVersion)"
Write-Host "Dotnet Command Workload Set Version: $dotnetCommandWorkloadSetVersion"
Write-Host "Android SDK API Level: $($androidDetails.ApiLevel)"
Write-Host "Android SDK Build Tools Version: $($androidDetails.BuildToolsVersion)"
Write-Host "Android SDK Command Line Tools Version: $($androidDetails.CmdLineToolsVersion)"
Write-Host "JDK Major Version: $($androidDetails.JdkMajorVersion)"
Write-Host "GitHub Actions Runner Version: $githubActionsRunnerVersion"
Write-Host "Docker Repository: $DockerRepository"
Write-Host "Docker Platform: $DockerPlatform"
Write-Host "Version: $Version"

# Determine the build context path based on the platform
$contextPath = Join-Path -Path $PSScriptRoot -ChildPath $dockerTagBase

if (-not (Test-Path -Path $contextPath -PathType Container)) {
    Write-Error "Build context path does not exist: $contextPath"
    exit 1
}

Write-Host "Using build context: $contextPath"

# Build tags following the unified naming scheme:
# - dotnet{X.Y} - Latest workload for this .NET version
# - dotnet{X.Y}-workloads{X.Y.Z} - Specific workload version
# - dotnet{X.Y}-workloads{X.Y.Z}-v{sha} - SHA-pinned version (optional)
# If Version is not "latest", also add a custom version tag
$tags = @()

# 1. dotnet{X.Y} tag (this is the "latest" for this .NET version)
$dotnetTag = "$DockerRepository`:dotnet$DotnetVersion"
$tags += $dotnetTag

# 2. dotnet{X.Y}-workloads{X.Y.Z} tag
$workloadTag = "$DockerRepository`:dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion"
$tags += $workloadTag

# 3. Optional: dotnet{X.Y}-workloads{X.Y.Z}-v{sha} tag
if ($BuildSha) {
    $shaTag = "$DockerRepository`:dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion-v$BuildSha"
    $tags += $shaTag
}

# 4. Optional: Custom version tag (for PR builds, etc.)
if ($Version -ne "latest") {
    $customTag = "$DockerRepository`:dotnet$DotnetVersion-$Version"
    $tags += $customTag
}

Write-Host "Building Docker image with tags:"
foreach ($tag in $tags) {
    Write-Host "  $tag"
}

# Prepare Docker build arguments
$buildArgs = @(
    "--build-arg", "DOTNET_VERSION=$DotnetVersion",
    "--build-arg", "JDK_MAJOR_VERSION=$($androidDetails.JdkMajorVersion)",
    "--build-arg", "ANDROID_SDK_API_LEVEL=$($androidDetails.ApiLevel)",
    "--build-arg", "ANDROID_SDK_BUILD_TOOLS_VERSION=$($androidDetails.BuildToolsVersion)",
    "--build-arg", "ANDROID_SDK_CMDLINE_TOOLS_VERSION=$($androidDetails.CmdLineToolsVersion)",
    "--build-arg", "DOTNET_WORKLOADS_VERSION=$dotnetCommandWorkloadSetVersion",
    "--build-arg", "GITHUB_ACTIONS_RUNNER_VERSION=$githubActionsRunnerVersion",
    "--platform", $DockerPlatform
)

# Add all tags
foreach ($tag in $tags) {
    $buildArgs += @("--tag", $tag)
}

# Add load flag if specified (only supported by buildx, not regular docker build)
# Regular docker build automatically makes images available locally
if ($Load) {
    # Only add --load flag for Linux builds where buildx might be available
    # Windows runners typically use regular docker build which doesn't support --load
    if ($DockerPlatform.StartsWith('linux/')) {
        Write-Host "Adding --load flag for Linux build"
        $buildArgs += @("--load")
    } else {
        Write-Host "Skipping --load flag for Windows build (not supported by regular docker build)"
        # Windows builds use regular docker build - images are automatically loaded
    }
}

# Change to the build context directory
Push-Location $contextPath

try {
    # Execute the Docker build command
    Write-Host "Executing: docker build $($buildArgs -join ' ') ."
    & docker build @buildArgs .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    
    Write-Host "Docker build completed successfully!"
    
    # Push if requested
    if ($Push) {
        foreach ($tag in $tags) {
            Write-Host "Pushing image: $tag"
            & docker push $tag

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Docker push failed for $tag with exit code $LASTEXITCODE"
                exit $LASTEXITCODE
            }
        }

        Write-Host "Docker push completed successfully!"
    }
    
} finally {
    # Return to the original directory
    Pop-Location
}
