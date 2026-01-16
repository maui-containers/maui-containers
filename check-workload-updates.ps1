#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Checks for new .NET workload set versions and determines if builds should be triggered.

.DESCRIPTION
    This script checks for the latest .NET workload set version using the Find-LatestWorkloadSet function,
    then queries Docker Hub to see if we already have builds for that version. It outputs GitHub Actions
    variables to indicate whether new builds should be triggered.

.PARAMETER DotnetVersion
    The .NET version to check for workload sets. Defaults to "9.0".

.PARAMETER LinuxDockerRepository
    The Linux Docker repository to check for existing tags. Defaults to "ghcr.io/maui-containers/maui-linux".

.PARAMETER WindowsDockerRepository
    The Windows Docker repository to check for existing tags. Defaults to "ghcr.io/maui-containers/maui-windows".

.PARAMETER TestDockerRepository
    The test Docker repository to check for existing tags. Defaults to "ghcr.io/maui-containers/maui-emulator-linux".

.PARAMETER TagPattern
    The tag pattern to look for. The script will replace placeholders with actual values:
    - {platform}: 'linux' or 'windows' 
    - {dotnet_version}: The .NET version (e.g., '9.0')
    - {workload_version}: The workload set version (e.g., '9.0.301.1')
    Defaults to "{platform}-dotnet{dotnet_version}-workloads{workload_version}".

.PARAMETER TestTagPattern
    The test tag pattern to look for. Includes Android API level support:
    - {platform}: 'appium-emulator-linux'
    - {dotnet_version}: The .NET version (e.g., '9.0')
    - {workload_version}: The workload set version (e.g., '9.0.301.1')
    - {api_level}: Android API level (e.g., '35')
    Defaults to "{platform}-dotnet{dotnet_version}-workloads{workload_version}-android{api_level}".

.PARAMETER OutputFormat
    The output format. Use "github-actions" for GitHub Actions environment variables,
    or "object" for PowerShell object output. Defaults to "github-actions".

.PARAMETER ForceBuild
    Force building and pushing of all images regardless of existing tags with the latest workload set versions.
    When true, the script will always trigger builds even if the tags already exist.

.EXAMPLE
    .\check-workload-updates.ps1
    
.EXAMPLE
    .\check-workload-updates.ps1 -DotnetVersion "9.0" -LinuxDockerRepository "ghcr.io/myorg/maui-linux" -WindowsDockerRepository "ghcr.io/myorg/maui-windows" -OutputFormat "object"

.EXAMPLE
    .\check-workload-updates.ps1 -ForceBuild -DotnetVersion "9.0"
#>

param(
    [Parameter(Position = 0)]
    [string]$DotnetVersion = "9.0",

    [Parameter(Position = 1)]
    [string]$LinuxDockerRepository = "ghcr.io/maui-containers/maui-linux",

    [Parameter(Position = 2)]
    [string]$WindowsDockerRepository = "ghcr.io/maui-containers/maui-windows",

    [Parameter(Position = 3)]
    [string]$TestDockerRepository = "ghcr.io/maui-containers/maui-emulator-linux",
    
    [Parameter(Position = 4)]
    [string]$TagPattern = "{platform}-dotnet{dotnet_version}-workloads{workload_version}",
    
    [Parameter(Position = 5)]
    [string]$TestTagPattern = "{platform}-dotnet{dotnet_version}-workloads{workload_version}-android{api_level}",
    
    [Parameter(Position = 6)]
    [ValidateSet("github-actions", "object")]
    [string]$OutputFormat = "github-actions",
    
    [Parameter()]
    [switch]$ForceBuild
)

# Import common functions
$commonFunctionsPath = Join-Path $PSScriptRoot "common-functions.ps1"
if (-not (Test-Path $commonFunctionsPath)) {
    Write-Error "Cannot find common-functions.ps1 at: $commonFunctionsPath"
    exit 1
}

. $commonFunctionsPath

function Write-GitHubOutput {
    param(
        [string]$Name,
        [string]$Value
    )
    
    if ($OutputFormat -eq "github-actions") {
        if ($env:GITHUB_OUTPUT) {
            Write-Output "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        } else {
            Write-Host "::set-output name=$Name::$Value"
        }
    }
}

function Write-HostWithPrefix {
    param([string]$Message)
    Write-Host "🔍 $Message"
}

# Function to get tags from a container registry (Docker Hub or GHCR)
function Get-RegistryTags {
    param(
        [string]$Repository
    )

    # Check if this is a GHCR repository
    if ($Repository -match '^ghcr\.io/([^/]+)/(.+)$') {
        $owner = $Matches[1]
        $packageName = $Matches[2]

        # Use GitHub API for GHCR
        $ghcrUri = "https://api.github.com/orgs/$owner/packages/container/$packageName/versions?per_page=100"
        Write-HostWithPrefix "Querying GitHub Container Registry API: $ghcrUri"

        $headers = @{
            Accept = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }

        # Add auth token if available
        if ($env:GITHUB_TOKEN) {
            $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
        }

        $response = Invoke-RestMethod -Uri $ghcrUri -Headers $headers -TimeoutSec 30

        # Extract all tags from the response - each version can have multiple tags
        $tags = @()
        foreach ($version in $response) {
            if ($version.metadata -and $version.metadata.container -and $version.metadata.container.tags) {
                $tags += $version.metadata.container.tags
            }
        }

        # Remove duplicates and return
        return $tags | Sort-Object -Unique

    } else {
        # Use Docker Hub API for non-GHCR repositories
        $dockerHubUri = "https://registry.hub.docker.com/v2/repositories/$Repository/tags?page_size=100"
        Write-HostWithPrefix "Querying Docker Hub API: $dockerHubUri"

        $response = Invoke-RestMethod -Uri $dockerHubUri -TimeoutSec 30
        $tags = $response.results | ForEach-Object { $_.name }

        return $tags
    }
}

# Function to check for existing test builds with Android API levels
function Test-TestRepositoryBuilds {
    param(
        [string]$Repository,
        [string]$TagPattern,
        [string]$DotnetVersion,
        [string]$WorkloadVersion
    )
    
    Write-HostWithPrefix "Checking test repository: $Repository"

    try {
        # Get tags from registry
        $existingTags = Get-RegistryTags -Repository $Repository

        Write-HostWithPrefix "Found $($existingTags.Count) test repository tags"
        
        # Create test tag patterns for common API levels (we check for any Android API level)
        # The test tag pattern is: appium-emulator-linux-dotnet{version}-workloads{workload}-android{api}
        $testPlatform = "appium-emulator-linux"
        $testTagPattern = $TagPattern -replace '\{platform\}', $testPlatform -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $WorkloadVersion
        
        # Check if any tag matches the pattern with any API level
        $matchingTags = $existingTags | Where-Object { 
            $_ -match "^$($testTagPattern -replace '\{api_level\}', '\d+')" 
        }
        
        $hasTestBuilds = $matchingTags.Count -gt 0
        
        Write-HostWithPrefix "Test tag pattern (with API level): $($testTagPattern -replace '\{api_level\}', 'XX')"
        Write-HostWithPrefix "Matching test tags found: $($matchingTags.Count)"
        if ($matchingTags.Count -gt 0 -and $matchingTags.Count -le 5) {
            Write-HostWithPrefix "Sample matching tags: $($matchingTags -join ', ')"
        } elseif ($matchingTags.Count -gt 5) {
            Write-HostWithPrefix "Sample matching tags: $($matchingTags[0..4] -join ', ')..."
        }
        
        return $hasTestBuilds
        
    } catch {
        Write-HostWithPrefix "Warning: Could not check test repository $Repository - $($_.Exception.Message)"
        return $false
    }
}

# Function to check for existing base builds
function Test-BaseRepositoryBuilds {
    param(
        [string]$LinuxRepository,
        [string]$WindowsRepository,
        [string]$DotnetVersion,
        [string]$WorkloadVersion
    )
    
    # Build the expected tag format (without platform prefix)
    # Actual tags are: dotnet{version}-workloads{workload_version}
    $expectedTag = "dotnet$DotnetVersion-workloads$WorkloadVersion"
    
    Write-HostWithPrefix "Checking Linux repository: $LinuxRepository"
    $hasLinuxBase = $false
    try {
        $linuxTags = Get-RegistryTags -Repository $LinuxRepository
        Write-HostWithPrefix "Found $($linuxTags.Count) tags in Linux repository"
        $hasLinuxBase = $linuxTags -contains $expectedTag
        Write-HostWithPrefix "Linux base tag '$expectedTag' - Exists: $hasLinuxBase"
    } catch {
        Write-HostWithPrefix "Warning: Could not check Linux repository $LinuxRepository - $($_.Exception.Message)"
    }
    
    Write-HostWithPrefix "Checking Windows repository: $WindowsRepository"
    $hasWindowsBase = $false
    try {
        $windowsTags = Get-RegistryTags -Repository $WindowsRepository
        Write-HostWithPrefix "Found $($windowsTags.Count) tags in Windows repository"
        $hasWindowsBase = $windowsTags -contains $expectedTag
        Write-HostWithPrefix "Windows base tag '$expectedTag' - Exists: $hasWindowsBase"
    } catch {
        Write-HostWithPrefix "Warning: Could not check Windows repository $WindowsRepository - $($_.Exception.Message)"
    }
    
    $hasAnyBase = $hasLinuxBase -or $hasWindowsBase
    Write-HostWithPrefix "Has any base builds: $hasAnyBase"
    
    return @{
        HasLinuxBase = $hasLinuxBase
        HasWindowsBase = $hasWindowsBase
        HasAnyBase = $hasAnyBase
        LinuxBaseTag = $expectedTag
        WindowsBaseTag = $expectedTag
    }
}

try {
    Write-HostWithPrefix "Checking for latest .NET $DotnetVersion workload set..."
    
    # Initialize variables
    $triggerBuilds = $false
    $newVersion = $false
    $errorMessage = $null
    $hasTestBuilds = $false
    $hasLinuxBaseBuild = $false
    $hasWindowsBaseBuild = $false
    $hasAnyBaseBuild = $false
    $linuxTag = ""
    $windowsTag = ""
    $latestVersion = ""
    $dotnetCommandWorkloadSetVersion = ""
    $xcodeVersionRange = ""
    $xcodeRecommendedVersion = ""
    $xcodeMajorVersion = ""
    $cirrusBaseTag = ""
    $cirrusBaseDigest = ""
    $cirrusXcodeVersion = ""
    $cirrusBaseImageUrl = ""
    $cirrusPinnedImageUrl = ""
    $detailedWorkloadInfo = $null
    
    # Get comprehensive workload information
    # First try the simple approach
    Write-HostWithPrefix "Trying to find latest workload set..."
    $latestWorkloadSet = Find-LatestWorkloadSet -DotnetVersion $DotnetVersion

    if ($latestWorkloadSet) {
        $latestVersion = $latestWorkloadSet.version
        $dotnetCommandWorkloadSetVersion = Convert-ToWorkloadVersion -NuGetVersion $latestVersion
        Write-HostWithPrefix "Using simple workload set approach"
    } else {
        Write-HostWithPrefix "Simple approach failed, trying comprehensive workload info..."
        $workloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetVersion -IncludeAndroid -IncludeiOS -DockerPlatform "linux/amd64"
        
        if (-not $workloadInfo) {
            Write-Error "Failed to get workload information for .NET $DotnetVersion"
            exit 1
        }
        
        Write-HostWithPrefix "Workload info retrieved successfully"
        Write-HostWithPrefix "Available properties: $($workloadInfo.Keys -join ', ')"
        
        $latestVersion = $workloadInfo.WorkloadSetVersion
        $dotnetCommandWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion
        $detailedWorkloadInfo = $workloadInfo
    }

    if (-not $latestVersion) {
        Write-Error "WorkloadSetVersion is null or empty in workload info"
        exit 1
    }
    
    if (-not $dotnetCommandWorkloadSetVersion) {
        Write-Error "DotnetCommandWorkloadSetVersion is null or empty in workload info"
        exit 1
    }
    
    Write-HostWithPrefix "Latest workload set version: $latestVersion"
    Write-HostWithPrefix "Dotnet command workload set version: $dotnetCommandWorkloadSetVersion"

    # Retrieve iOS workload dependency information for Xcode details
    if (-not $detailedWorkloadInfo) {
        try {
            Write-HostWithPrefix "Retrieving iOS workload dependency information..."
            $detailedWorkloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetVersion -WorkloadSetVersion $latestVersion -IncludeiOS -DockerPlatform "linux/amd64"
        } catch {
            Write-HostWithPrefix "Warning: Failed to retrieve iOS workload information - $($_.Exception.Message)"
        }
    }

    if ($detailedWorkloadInfo -and $detailedWorkloadInfo.Workloads -and $detailedWorkloadInfo.Workloads.ContainsKey("Microsoft.NET.Sdk.iOS")) {
        $iosWorkload = $detailedWorkloadInfo.Workloads["Microsoft.NET.Sdk.iOS"]
        if ($iosWorkload -and $iosWorkload.Details) {
            if ($iosWorkload.Details.XcodeVersionRange) {
                $xcodeVersionRange = $iosWorkload.Details.XcodeVersionRange
            }
            if ($iosWorkload.Details.XcodeRecommendedVersion) {
                $xcodeRecommendedVersion = $iosWorkload.Details.XcodeRecommendedVersion
            }
            if ($null -ne $iosWorkload.Details.XcodeMajorVersion) {
                $xcodeMajorVersion = $iosWorkload.Details.XcodeMajorVersion.ToString()
            }

            Write-HostWithPrefix "Xcode version range: $xcodeVersionRange"
            Write-HostWithPrefix "Xcode recommended version: $xcodeRecommendedVersion"
            Write-HostWithPrefix "Xcode major version: $xcodeMajorVersion"

            # Resolve best matching Cirrus Labs base image for Tart VMs
            if ($xcodeVersionRange -or $xcodeRecommendedVersion) {
                try {
                    Write-HostWithPrefix "Resolving best Cirrus Labs base image for macOS Tahoe..."
                    $cirrusBaseImageInfo = Find-BestCirrusLabsImage `
                        -MacOSVersion "tahoe" `
                        -XcodeVersionRange $xcodeVersionRange `
                        -XcodeRecommendedVersion $xcodeRecommendedVersion `
                        -IncludeDigest

                    if ($cirrusBaseImageInfo) {
                        $cirrusBaseTag = $cirrusBaseImageInfo.Tag
                        $cirrusBaseDigest = $cirrusBaseImageInfo.Digest
                        $cirrusXcodeVersion = $cirrusBaseImageInfo.XcodeVersion
                        $cirrusBaseImageUrl = $cirrusBaseImageInfo.BaseImageUrl
                        $cirrusPinnedImageUrl = $cirrusBaseImageInfo.PinnedImageUrl

                        Write-HostWithPrefix "Cirrus Labs base image resolved:"
                        Write-HostWithPrefix "  Tag: $cirrusBaseTag"
                        Write-HostWithPrefix "  Xcode version: $cirrusXcodeVersion"
                        Write-HostWithPrefix "  Digest: $cirrusBaseDigest"
                        Write-HostWithPrefix "  Pinned URL: $cirrusPinnedImageUrl"
                    }
                } catch {
                    Write-HostWithPrefix "Warning: Failed to resolve Cirrus Labs base image - $($_.Exception.Message)"
                }
            }
        } else {
            Write-HostWithPrefix "Warning: iOS workload details were not available for Xcode information"
        }
    } else {
        Write-HostWithPrefix "Warning: iOS workload information not found in workload set data"
    }

    # Create expected tag patterns for both platforms
    $linuxTag = $TagPattern -replace '\{platform\}', 'linux' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
    $windowsTag = $TagPattern -replace '\{platform\}', 'windows' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
    
    Write-HostWithPrefix "Looking for Linux tag: $linuxTag"
    Write-HostWithPrefix "Looking for Windows tag: $windowsTag"
    
    # Check existing registry tags
    Write-HostWithPrefix "Checking existing tags in registries..."

    try {
        # Also check test repository for builds
        $hasTestBuilds = Test-TestRepositoryBuilds -Repository $TestDockerRepository -TagPattern $TestTagPattern -DotnetVersion $DotnetVersion -WorkloadVersion $dotnetCommandWorkloadSetVersion
        Write-HostWithPrefix "Has test builds: $hasTestBuilds"
        
        # Check Docker repositories for builds (Linux and Windows are separate repos)
        $baseBuilds = Test-BaseRepositoryBuilds -LinuxRepository $LinuxDockerRepository -WindowsRepository $WindowsDockerRepository -DotnetVersion $DotnetVersion -WorkloadVersion $dotnetCommandWorkloadSetVersion
        $hasLinuxBaseBuild = $baseBuilds.HasLinuxBase
        $hasWindowsBaseBuild = $baseBuilds.HasWindowsBase
        $hasAnyBaseBuild = $baseBuilds.HasAnyBase
        Write-HostWithPrefix "Has Docker image builds: $hasAnyBaseBuild (Linux: $hasLinuxBaseBuild, Windows: $hasWindowsBaseBuild)"
        
        $hasAnyBuild = $hasTestBuilds -or $hasAnyBaseBuild
        Write-HostWithPrefix "Has any existing build (Docker images or test): $hasAnyBuild"
        
        # Check if we should force build regardless of existing tags
        if ($ForceBuild) {
            Write-HostWithPrefix "🔄 Force build parameter specified. Builds will be triggered regardless of existing tags."
            $triggerBuilds = $true
            $newVersion = $true
        } elseif (-not $hasAnyBuild) {
            Write-HostWithPrefix "✅ New workload set version found! Builds should be triggered."
            $triggerBuilds = $true
            $newVersion = $true
        } else {
            Write-HostWithPrefix "ℹ️ Workload set version $dotnetCommandWorkloadSetVersion already built. No action needed."
            if ($hasLinuxBaseBuild -and $hasWindowsBaseBuild) {
                Write-HostWithPrefix "   Both Linux and Windows builds exist."
            } elseif ($hasLinuxBaseBuild) {
                Write-HostWithPrefix "   Only Linux build exists, Windows build may be needed."
            } else {
                Write-HostWithPrefix "   Only Windows build exists, Linux build may be needed."
            }
            $triggerBuilds = $false
            $newVersion = $false
        }
        
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Warning "❌ Failed to check registry tags: $errorMessage"
        Write-HostWithPrefix "🔄 Assuming we need to build (fail-safe approach)"
        
        # In error case, still set the tag values if we have them
        if ($latestVersion -and $dotnetCommandWorkloadSetVersion) {
            $linuxTag = $TagPattern -replace '\{platform\}', 'linux' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
            $windowsTag = $TagPattern -replace '\{platform\}', 'windows' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
        }
        
        # Always trigger builds on error or when force build is specified
        $triggerBuilds = $true
        $newVersion = $true
    }
    
    # Create result object
    $result = [PSCustomObject]@{
        LatestVersion = $latestVersion
        DotnetCommandWorkloadSetVersion = $dotnetCommandWorkloadSetVersion
        LinuxTag = $linuxTag
        WindowsTag = $windowsTag
        HasTestBuilds = $hasTestBuilds
        HasLinuxBaseBuild = $hasLinuxBaseBuild
        HasWindowsBaseBuild = $hasWindowsBaseBuild
        HasAnyBaseBuild = $hasAnyBaseBuild
        TriggerBuilds = $triggerBuilds
        NewVersion = $newVersion
        ForceBuild = $ForceBuild.IsPresent
        XcodeVersionRange = $xcodeVersionRange
        XcodeRecommendedVersion = $xcodeRecommendedVersion
        XcodeMajorVersion = $xcodeMajorVersion
        CirrusBaseTag = $cirrusBaseTag
        CirrusBaseDigest = $cirrusBaseDigest
        CirrusXcodeVersion = $cirrusXcodeVersion
        CirrusBaseImageUrl = $cirrusBaseImageUrl
        CirrusPinnedImageUrl = $cirrusPinnedImageUrl
        ErrorMessage = $errorMessage
        LinuxDockerRepository = $LinuxDockerRepository
        WindowsDockerRepository = $WindowsDockerRepository
        TestDockerRepository = $TestDockerRepository
        DotnetVersion = $DotnetVersion
    }
    
    # Output results
    if ($OutputFormat -eq "github-actions") {
        Write-GitHubOutput "trigger-builds" $triggerBuilds.ToString().ToLower()
        Write-GitHubOutput "new-version" $newVersion.ToString().ToLower()
        Write-GitHubOutput "workload-set-version" $latestVersion
        Write-GitHubOutput "dotnet-command-workload-set-version" $dotnetCommandWorkloadSetVersion
        Write-GitHubOutput "linux-tag" $linuxTag
        Write-GitHubOutput "windows-tag" $windowsTag
        Write-GitHubOutput "has-test-builds" $hasTestBuilds.ToString().ToLower()
        Write-GitHubOutput "has-linux-base-build" $hasLinuxBaseBuild.ToString().ToLower()
        Write-GitHubOutput "has-windows-base-build" $hasWindowsBaseBuild.ToString().ToLower()
        Write-GitHubOutput "has-any-base-build" $hasAnyBaseBuild.ToString().ToLower()
        Write-GitHubOutput "force-build" $ForceBuild.IsPresent.ToString().ToLower()
        Write-GitHubOutput "xcode-version-range" $xcodeVersionRange
        Write-GitHubOutput "xcode-recommended-version" $xcodeRecommendedVersion
        Write-GitHubOutput "xcode-major-version" $xcodeMajorVersion
        Write-GitHubOutput "cirrus-base-tag" $cirrusBaseTag
        Write-GitHubOutput "cirrus-base-digest" $cirrusBaseDigest
        Write-GitHubOutput "cirrus-xcode-version" $cirrusXcodeVersion
        Write-GitHubOutput "cirrus-base-image-url" $cirrusBaseImageUrl
        Write-GitHubOutput "cirrus-pinned-image-url" $cirrusPinnedImageUrl

        Write-HostWithPrefix "GitHub Actions outputs set:"
        Write-HostWithPrefix "  trigger-builds: $($triggerBuilds.ToString().ToLower())"
        Write-HostWithPrefix "  new-version: $($newVersion.ToString().ToLower())"
        Write-HostWithPrefix "  workload-set-version: $latestVersion"
        Write-HostWithPrefix "  dotnet-command-workload-set-version: $dotnetCommandWorkloadSetVersion"
        Write-HostWithPrefix "  linux-tag: $linuxTag"
        Write-HostWithPrefix "  windows-tag: $windowsTag"
        Write-HostWithPrefix "  has-test-builds: $($hasTestBuilds.ToString().ToLower())"
        Write-HostWithPrefix "  has-linux-base-build: $($hasLinuxBaseBuild.ToString().ToLower())"
        Write-HostWithPrefix "  has-windows-base-build: $($hasWindowsBaseBuild.ToString().ToLower())"
        Write-HostWithPrefix "  has-any-base-build: $($hasAnyBaseBuild.ToString().ToLower())"
        Write-HostWithPrefix "  force-build: $($ForceBuild.IsPresent.ToString().ToLower())"
        Write-HostWithPrefix "  xcode-version-range: $xcodeVersionRange"
        Write-HostWithPrefix "  xcode-recommended-version: $xcodeRecommendedVersion"
        Write-HostWithPrefix "  xcode-major-version: $xcodeMajorVersion"
        Write-HostWithPrefix "  cirrus-base-tag: $cirrusBaseTag"
        Write-HostWithPrefix "  cirrus-base-digest: $cirrusBaseDigest"
        Write-HostWithPrefix "  cirrus-xcode-version: $cirrusXcodeVersion"
        Write-HostWithPrefix "  cirrus-base-image-url: $cirrusBaseImageUrl"
        Write-HostWithPrefix "  cirrus-pinned-image-url: $cirrusPinnedImageUrl"
    } else {
        return $result
    }
    
} catch {
    Write-Error "❌ Script failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    
    # Set default values for output
    if (-not $latestVersion) { $latestVersion = "unknown" }
    if (-not $dotnetCommandWorkloadSetVersion) { $dotnetCommandWorkloadSetVersion = "unknown" }
    if (-not $linuxTag) { $linuxTag = "unknown" }
    if (-not $windowsTag) { $windowsTag = "unknown" }
    if (-not $xcodeVersionRange) { $xcodeVersionRange = "" }
    if (-not $xcodeRecommendedVersion) { $xcodeRecommendedVersion = "" }
    if (-not $xcodeMajorVersion) { $xcodeMajorVersion = "" }

    $result = [PSCustomObject]@{
        LatestVersion = $latestVersion
        DotnetCommandWorkloadSetVersion = $dotnetCommandWorkloadSetVersion
        LinuxTag = $linuxTag
        WindowsTag = $windowsTag
        HasTestBuilds = $false
        HasLinuxBaseBuild = $false
        HasWindowsBaseBuild = $false
        HasAnyBaseBuild = $false
        TriggerBuilds = $true
        NewVersion = $true
        ForceBuild = $ForceBuild.IsPresent
        XcodeVersionRange = $xcodeVersionRange
        XcodeRecommendedVersion = $xcodeRecommendedVersion
        XcodeMajorVersion = $xcodeMajorVersion
        CirrusBaseTag = $cirrusBaseTag
        CirrusBaseDigest = $cirrusBaseDigest
        CirrusXcodeVersion = $cirrusXcodeVersion
        CirrusBaseImageUrl = $cirrusBaseImageUrl
        CirrusPinnedImageUrl = $cirrusPinnedImageUrl
        ErrorMessage = $_.Exception.Message
        LinuxDockerRepository = $LinuxDockerRepository
        WindowsDockerRepository = $WindowsDockerRepository
        TestDockerRepository = $TestDockerRepository
        DotnetVersion = $DotnetVersion
    }

    if ($OutputFormat -eq "github-actions") {
        Write-GitHubOutput "trigger-builds" "true"
        Write-GitHubOutput "new-version" "true"
        Write-GitHubOutput "workload-set-version" $latestVersion
        Write-GitHubOutput "dotnet-command-workload-set-version" $dotnetCommandWorkloadSetVersion
        Write-GitHubOutput "linux-tag" $linuxTag
        Write-GitHubOutput "windows-tag" $windowsTag
        Write-GitHubOutput "force-build" $ForceBuild.IsPresent.ToString().ToLower()
        Write-GitHubOutput "xcode-version-range" $xcodeVersionRange
        Write-GitHubOutput "xcode-recommended-version" $xcodeRecommendedVersion
        Write-GitHubOutput "xcode-major-version" $xcodeMajorVersion
        Write-GitHubOutput "cirrus-base-tag" $cirrusBaseTag
        Write-GitHubOutput "cirrus-base-digest" $cirrusBaseDigest
        Write-GitHubOutput "cirrus-xcode-version" $cirrusXcodeVersion
        Write-GitHubOutput "cirrus-base-image-url" $cirrusBaseImageUrl
        Write-GitHubOutput "cirrus-pinned-image-url" $cirrusPinnedImageUrl
    } else {
        return $result
    }
    
    exit 1
}
