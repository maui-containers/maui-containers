#!/usr/bin/env pwsh

Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("maui", "ci")]
    [string]$ImageType,

    [ValidateNotNullOrEmpty()]
    [string]$MacOSVersion = "",

    # .NET 9.0 is retired from active MAUI support; re-add it here and to
    # DotnetChannels in platform-matrix.json if it needs to be revived.
    [ValidateSet("10.0", "11.0")]
    [string]$DotnetChannel = "10.0",

    [string]$WorkloadSetVersion = "",
    [string]$BaseXcodeVersion = "",
    [string[]]$AdditionalXcodeVersions = @(),
    [string]$ImageName = "",
    [string]$RegistryImageName = "",
    [string]$BaseImage = "",
    [string]$Registry = "",
    [string]$BuildSha = "",
    [int]$CPUCount = 4,
    [int]$MemoryGB = 8,
    [ValidateRange(0, 4096)]
    [int]$DiskSizeGB = 0,
    [switch]$Push,
    [switch]$PushOnly,
    [switch]$DryRun,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Directory locations
$scriptDir = Split-Path -Parent $PSScriptRoot
$templatesDir = Join-Path $scriptDir "templates"
$configDir = Join-Path $scriptDir "config"
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

# Load common functions for workload resolution
$commonFunctionsPath = Join-Path $repoRoot "common-functions.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    Write-Warning "common-functions.ps1 not found at: $commonFunctionsPath"
    Write-Warning "Workload version resolution will not be available"
}

# Load configuration
$variablesFile = Join-Path $configDir "variables.json"
if (Test-Path $variablesFile) {
    $config = Get-Content $variablesFile -Raw | ConvertFrom-Json
} else {
    $config = @{}
}

$matrixFile = Join-Path $configDir "platform-matrix.json"
if (Test-Path $matrixFile) {
    $script:PlatformMatrix = Get-Content $matrixFile -Raw | ConvertFrom-Json
} else {
    throw "Platform mapping file not found: $matrixFile"
}

# Version mapping and validation
function Get-PlatformMatrixEntry {
    param(
        [pscustomobject]$Section,
        [string]$Key
    )

    if (-not $Section -or -not $Key) {
        return $null
    }

    $property = $Section.PSObject.Properties | Where-Object { $_.Name -eq $Key } | Select-Object -First 1
    return $property.Value
}

function Get-MacOSVersionInfo {
    param([string]$MacOSVersion)

    $macOSInfo = Get-PlatformMatrixEntry -Section $script:PlatformMatrix.MacOSVersions -Key $MacOSVersion

    if ($macOSInfo) {
        return $macOSInfo
    }

    return [pscustomobject]@{
        FullName = "macOS $MacOSVersion"
        MinXcodeVersion = ""
        RecommendedXcodeVersion = ""
    }
}

function Get-DotnetChannelInfo {
    param([string]$DotnetChannel)

    $channelInfo = Get-PlatformMatrixEntry -Section $script:PlatformMatrix.DotnetChannels -Key $DotnetChannel

    if (-not $channelInfo) {
        $availableChannels = @()
        if ($script:PlatformMatrix.DotnetChannels) {
            $availableChannels = $script:PlatformMatrix.DotnetChannels.PSObject.Properties.Name
        }
        throw "Unsupported .NET channel: $DotnetChannel. Supported channels: $($availableChannels -join ', ')"
    }

    return $channelInfo
}


function Test-VersionCompatibility {
    param([string]$MacOSVersion, [string]$DotnetChannel)

    $dotnetInfo = Get-DotnetChannelInfo -DotnetChannel $DotnetChannel

    # Check minimum macOS version for .NET
    $macOSVersionOrder = @('monterey', 'ventura', 'sonoma', 'sequoia', 'tahoe')
    $normalizedMacOSVersion = $MacOSVersion.ToLowerInvariant()
    $currentIndex = $macOSVersionOrder.IndexOf($normalizedMacOSVersion)
    $minIndex = $macOSVersionOrder.IndexOf($dotnetInfo.MinMacOSVersion)

    if ($currentIndex -eq -1) {
        Write-Verbose "Skipping compatibility check for unrecognized macOS version '$MacOSVersion'."
        return $true
    }

    if ($currentIndex -lt $minIndex) {
        Write-Warning ".NET $DotnetChannel requires at least $($dotnetInfo.MinMacOSVersion), but you selected $MacOSVersion"
        return $false
    }

    return $true
}

function Get-OptionalPropertyValue {
    param(
        [object]$InputObject,
        [string]$Name
    )

    if (-not $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($property) {
        return $property.Value
    }

    return $null
}

# Normalize inputs
if ($DotnetChannel) {
    $DotnetChannel = $DotnetChannel.Trim()
}

# Load .NET channel info
$dotnetInfo = $null
if ($DotnetChannel) {
    $dotnetInfo = Get-DotnetChannelInfo -DotnetChannel $DotnetChannel
}

# Auto-resolve macOS version from .NET channel if not explicitly specified
if (-not $PSBoundParameters.ContainsKey('MacOSVersion') -or -not $MacOSVersion) {
    if ($dotnetInfo -and $dotnetInfo.MacOSVersion) {
        $MacOSVersion = $dotnetInfo.MacOSVersion
    }
}

# Normalize macOS version
if ($MacOSVersion) {
    $MacOSVersion = $MacOSVersion.Trim().ToLowerInvariant()
}

# Load macOS version info
$macOSInfo = $null
if ($MacOSVersion) {
    $macOSInfo = Get-MacOSVersionInfo -MacOSVersion $MacOSVersion
}

# Auto-resolve Xcode versions if not explicitly specified
if (-not $PSBoundParameters.ContainsKey('BaseXcodeVersion') -and -not $BaseXcodeVersion) {
    # Try dynamic resolution from workload requirements first
    $dynamicResolutionSucceeded = $false

    if ($DotnetChannel) {
        try {
            Write-Host "Attempting dynamic Xcode version resolution from workload requirements..."

            # Get iOS workload requirements
            $workloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetChannel -IncludeiOS -DockerPlatform "osx-arm64"

            if ($workloadInfo -and $workloadInfo.Workloads -and $workloadInfo.Workloads.ContainsKey("Microsoft.NET.Sdk.iOS")) {
                $iosDetails = $workloadInfo.Workloads["Microsoft.NET.Sdk.iOS"].Details

                if ($iosDetails -and ($iosDetails.XcodeVersionRange -or $iosDetails.XcodeRecommendedVersion)) {
                    # Find best matching Cirrus Labs image
                    $baseImageInfo = Find-BestCirrusLabsImage `
                        -MacOSVersion $MacOSVersion `
                        -XcodeVersionRange $iosDetails.XcodeVersionRange `
                        -XcodeRecommendedVersion $iosDetails.XcodeRecommendedVersion `
                        -IncludeDigest

                    if ($baseImageInfo -and $baseImageInfo.Digest) {
                        # Use digest for pinning
                        $BaseXcodeVersion = "@$($baseImageInfo.Digest)"
                        $dynamicResolutionSucceeded = $true
                        Write-Host "Dynamic resolution succeeded:"
                        Write-Host "  Xcode version: $($baseImageInfo.XcodeVersion)"
                        Write-Host "  Cirrus tag: $($baseImageInfo.Tag)"
                        Write-Host "  Using digest: $($baseImageInfo.Digest)"
                    }
                }
            }
        } catch {
            Write-Warning "Dynamic Xcode resolution failed: $($_.Exception.Message)"
            Write-Warning "Falling back to static configuration..."
        }
    }

    # Fall back to static configuration from platform-matrix.json
    if (-not $dynamicResolutionSucceeded) {
        if ($dotnetInfo -and $dotnetInfo.BaseXcodeVersion) {
            $BaseXcodeVersion = $dotnetInfo.BaseXcodeVersion
            Write-Host "Using static BaseXcodeVersion from platform-matrix.json: $BaseXcodeVersion"
        } elseif ($macOSInfo -and $macOSInfo.RecommendedXcodeVersion) {
            $BaseXcodeVersion = $macOSInfo.RecommendedXcodeVersion
            Write-Host "Using RecommendedXcodeVersion from platform-matrix.json: $BaseXcodeVersion"
        } else {
            throw 'Base Xcode version is required when no platform matrix recommendation is available.'
        }
    }
}

# Auto-resolve additional Xcode versions if not explicitly specified
if (-not $PSBoundParameters.ContainsKey('AdditionalXcodeVersions') -and $dotnetInfo -and $dotnetInfo.AdditionalXcodeVersions) {
    $AdditionalXcodeVersions = $dotnetInfo.AdditionalXcodeVersions
}

if ($MacOSVersion -and $DotnetChannel) {
    [void](Test-VersionCompatibility -MacOSVersion $MacOSVersion -DotnetChannel $DotnetChannel)
}

# Set default image name if not provided
if (-not $ImageName) {
    # Always use standardized image name for consistency
    $ImageName = switch ($ImageType) {
        "maui" { "maui-macos" }
        "ci" { "maui-ci-macos" }
    }
}

if ($DiskSizeGB -eq 0) {
    $buildSettings = Get-OptionalPropertyValue -InputObject $config -Name "build_settings"
    $diskSizePropertyName = switch ($ImageType) {
        "maui" { "maui_image_disk_size_gb" }
        "ci" { "ci_image_disk_size_gb" }
    }
    $configuredDiskSizeGB = Get-OptionalPropertyValue -InputObject $buildSettings -Name $diskSizePropertyName

    if ($configuredDiskSizeGB) {
        $DiskSizeGB = [int]$configuredDiskSizeGB
    } else {
        $DiskSizeGB = 160
    }
}

# Set base image for layered builds (not needed for push-only mode)
if (-not $PushOnly -and -not $BaseImage) {
    $BaseImage = switch ($ImageType) {
        "maui" {
            if (-not $BaseXcodeVersion) {
                throw 'Base Xcode version is required for maui image builds.'
            }
            # Handle digest format (@sha256:...) vs tag format (26)
            if ($BaseXcodeVersion.StartsWith("@")) {
                "ghcr.io/cirruslabs/macos-$MacOSVersion-xcode$BaseXcodeVersion"
            } else {
                "ghcr.io/cirruslabs/macos-$MacOSVersion-xcode:$BaseXcodeVersion"
            }
        }
        "ci" { "maui-dev-$MacOSVersion" }
    }
}

if ($PushOnly) {
    Write-Host "Pushing Tart VM Image"
    Write-Host "====================="
} else {
    Write-Host "Building Tart VM Image"
    Write-Host "======================"
}
Write-Host "Image Type: $ImageType"
Write-Host "macOS Version: $MacOSVersion"
Write-Host ".NET Channel: $DotnetChannel"
if ($BaseXcodeVersion -and -not $PushOnly) {
    Write-Host "Base Xcode Version: $BaseXcodeVersion"
}
if ($AdditionalXcodeVersions -and $AdditionalXcodeVersions.Count -gt 0 -and -not $PushOnly) {
    Write-Host "Additional Xcode Versions: $($AdditionalXcodeVersions -join ', ')"
}
Write-Host "Image Name: $ImageName"
if (-not $PushOnly) {
    Write-Host "Base Image: $BaseImage"
    Write-Host "CPU Count: $CPUCount"
    Write-Host "Memory: ${MemoryGB}GB"
    Write-Host "Disk: ${DiskSizeGB}GB"
}
if ($Registry) {
    Write-Host "Registry: $Registry"
}
if ($BuildSha) {
    Write-Host "Build SHA: $BuildSha"
}
Write-Host "Dry Run: $($DryRun.IsPresent)"
Write-Host ""

# Check prerequisites
function Test-Prerequisites {
    $missing = @()

    if (-not (Get-Command tart -ErrorAction SilentlyContinue)) {
        $missing += "tart (install with: brew install cirruslabs/cli/tart)"
    }

    if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
        $missing += "packer (install with: brew install packer)"
    }

    if ($missing.Count -gt 0) {
        Write-Error "Missing prerequisites:`n$($missing -join "`n")"
        exit 1
    }
}

function Start-TartBuild {
    param(
        [string]$TemplatePath,
        [hashtable]$Variables
    )

    if (-not (Test-Path $TemplatePath)) {
        throw "Template not found: $TemplatePath"
    }

    $varArgs = @()
    foreach ($key in $Variables.Keys) {
        $value = $Variables[$key]
        # Convert complex objects to JSON for Packer
        if ($value -is [hashtable] -or $value -is [PSCustomObject]) {
            $jsonValue = $value | ConvertTo-Json -Compress
            $varArgs += "-var", "$key=$jsonValue"
        } else {
            $varArgs += "-var", "$key=$value"
        }
    }

    if ($DryRun) {
        Write-Host "[DryRun] Would run: packer init $TemplatePath"
        Write-Host "[DryRun] Would run: packer build $($varArgs -join ' ') $TemplatePath"
        return
    }

    # Change to the templates directory so Packer resolves file paths correctly
    # File provisioner paths in templates are relative to the working directory
    $originalLocation = Get-Location
    $templateDir = Split-Path -Parent $TemplatePath
    $templateFile = Split-Path -Leaf $TemplatePath

    try {
        Set-Location $templateDir

        Write-Host "Initializing Packer plugins..."
        & packer init $templateFile

        if ($LASTEXITCODE -ne 0) {
            throw "Packer init failed with exit code $LASTEXITCODE"
        }

        Write-Host "Running Packer build..."
        & packer build @varArgs $templateFile

        if ($LASTEXITCODE -ne 0) {
            throw "Packer build failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Set-Location $originalLocation
    }
}

function Get-TartRegistryTags {
    param(
        [string]$ImageName,
        [string]$RegistryImageName,
        [string]$Registry,
        [string]$WorkloadSetVersion,
        [string]$MacOSVersion,
        [string]$DotnetChannel,
        [string]$BaseXcodeVersion,
        [string]$BuildSha
    )

    if (-not $MacOSVersion -or -not $DotnetChannel) {
        throw "MacOSVersion and DotnetChannel are required for image tagging"
    }

    if (-not $Registry) {
        return @()
    }

    $registryName = if ($RegistryImageName) { $RegistryImageName } else { $ImageName }
    $registryPrefix = "$Registry/${registryName}:"
    $tags = [System.Collections.Generic.List[string]]::new()

    function Add-RegistryTag {
        param([string]$TagName)

        $tagRef = "$registryPrefix$TagName"
        if (-not $tags.Contains($tagRef)) {
            [void]$tags.Add($tagRef)
        }
    }

    $xcodeVersionTag = ""
    if ($BaseXcodeVersion) {
        if (-not $BaseXcodeVersion.StartsWith("@")) {
            $xcodeVersionTag = $BaseXcodeVersion -replace '[^0-9.]', ''
        }
    }

    $dotnetTagPrefixInfo = Get-DotnetTagPrefixInfo -DotnetVersion $DotnetChannel -WorkloadVersion $WorkloadSetVersion -Prefix "$MacOSVersion-"
    $workloadBandTagVersion = Get-WorkloadBandTag -WorkloadVersion $WorkloadSetVersion

    Add-RegistryTag -TagName $dotnetTagPrefixInfo.Channel
    if ($dotnetTagPrefixInfo.Specific -ne $dotnetTagPrefixInfo.Channel) {
        Add-RegistryTag -TagName $dotnetTagPrefixInfo.Specific
    }

    if ($xcodeVersionTag) {
        $xcodeChannelTag = "$($dotnetTagPrefixInfo.Channel)-xcode$xcodeVersionTag"
        $xcodeSpecificTag = "$($dotnetTagPrefixInfo.Specific)-xcode$xcodeVersionTag"

        Add-RegistryTag -TagName $xcodeChannelTag
        if ($xcodeSpecificTag -ne $xcodeChannelTag) {
            Add-RegistryTag -TagName $xcodeSpecificTag
        }

        if ($WorkloadSetVersion) {
            Add-RegistryTag -TagName "$xcodeChannelTag-workloads$WorkloadSetVersion"

            if ($workloadBandTagVersion) {
                Add-RegistryTag -TagName "$xcodeChannelTag-workloads$workloadBandTagVersion"
            }

            if ($xcodeSpecificTag -ne $xcodeChannelTag) {
                Add-RegistryTag -TagName "$xcodeSpecificTag-workloads$WorkloadSetVersion"
            }

            if ($BuildSha) {
                Add-RegistryTag -TagName "$xcodeSpecificTag-workloads$WorkloadSetVersion-v$BuildSha"
            }
        }
    } elseif ($WorkloadSetVersion) {
        Add-RegistryTag -TagName "$($dotnetTagPrefixInfo.Channel)-workloads$WorkloadSetVersion"

        if ($workloadBandTagVersion) {
            Add-RegistryTag -TagName "$($dotnetTagPrefixInfo.Channel)-workloads$workloadBandTagVersion"
        }

        if ($dotnetTagPrefixInfo.Specific -ne $dotnetTagPrefixInfo.Channel) {
            Add-RegistryTag -TagName "$($dotnetTagPrefixInfo.Specific)-workloads$WorkloadSetVersion"
        }

        if ($BuildSha) {
            Add-RegistryTag -TagName "$($dotnetTagPrefixInfo.Specific)-workloads$WorkloadSetVersion-v$BuildSha"
        }
    }

    return $tags.ToArray()
}

function Push-TartImage {
    param(
        [string]$ImageName,
        [string]$RegistryImageName,
        [string]$Registry,
        [string]$WorkloadSetVersion,
        [string]$MacOSVersion,
        [string]$DotnetChannel,
        [string]$BaseXcodeVersion,
        [string]$BuildSha
    )

    if (-not $Registry) {
        Write-Host "No registry specified, skipping push"
        return
    }

    $tags = Get-TartRegistryTags -ImageName $ImageName -RegistryImageName $RegistryImageName -Registry $Registry -WorkloadSetVersion $WorkloadSetVersion -MacOSVersion $MacOSVersion -DotnetChannel $DotnetChannel -BaseXcodeVersion $BaseXcodeVersion -BuildSha $BuildSha

    if ($DryRun) {
        Write-Host "[DryRun] Would push image with tags:"
        foreach ($tag in $tags) {
            Write-Host "  - $tag"
        }
        return
    }

    Write-Host "Pushing image to registry with multiple tags..."
    $pushCount = 0
    foreach ($tag in $tags) {
        Write-Host "  Pushing: $tag"
        & tart push $ImageName $tag

        if ($LASTEXITCODE -eq 0) {
            $pushCount++
            Write-Host "    ✓ Success"
        } else {
            Write-Warning "    ✗ Failed to push tag: $tag"
        }
    }

    if ($pushCount -eq 0) {
        throw "Failed to push image to registry - all tags failed"
    } elseif ($pushCount -lt $tags.Count) {
        Write-Warning "Some tags failed to push ($pushCount/$($tags.Count) succeeded)"
    } else {
        Write-Host "Successfully pushed all $pushCount tags"
    }
}

function Test-ImageExists {
    param([string]$ImageName)

    $images = & tart list | Out-String
    return $images -match [regex]::Escape($ImageName)
}

# Main execution
try {
    # Validate PushOnly mode
    if ($PushOnly) {
        if (-not $Registry) {
            throw "-PushOnly requires -Registry to be specified"
        }
        Write-Host "Push-only mode: Skipping build, will push existing image"
        Write-Host ""
    }

    Test-Prerequisites

    # Resolve workload set version if not explicitly provided
    # This allows us to tag the image with the specific workload version
    $resolvedWorkloadSetVersion = $WorkloadSetVersion
    if (-not $resolvedWorkloadSetVersion -and (Get-Command Get-WorkloadSetInfo -ErrorAction SilentlyContinue)) {
        Write-Host "Resolving workload set version for .NET $DotnetChannel..."
        try {
            $workloadInfo = Get-WorkloadSetInfo -DotnetVersion $DotnetChannel
            if ($workloadInfo -and $workloadInfo.DotnetCommandWorkloadSetVersion) {
                $resolvedWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion
                Write-Host "Resolved workload set version: $resolvedWorkloadSetVersion"
            }
        } catch {
            Write-Warning "Could not auto-resolve workload version: $_"
            Write-Warning "Image will only be tagged with :latest"
        }
    }

    # Check if image already exists
    if ($PushOnly) {
        # In push-only mode, image MUST exist
        if (-not (Test-ImageExists $ImageName)) {
            throw "Image '$ImageName' does not exist locally. Build it first without -PushOnly."
        }
        Write-Host "✓ Found local image: $ImageName"
    } elseif ((Test-ImageExists $ImageName) -and -not $Force) {
        Write-Warning "Image '$ImageName' already exists. Use -Force to rebuild."
        exit 1
    }

    # Only build if not in push-only mode
    if (-not $PushOnly) {
        # Prepare template path
        $templateFile = "$ImageType.pkr.hcl"
        $templatePath = Join-Path $templatesDir $templateFile

        # Prepare build variables
        # Use the original WorkloadSetVersion parameter for the build (can be empty for auto-detect)
        # but use resolvedWorkloadSetVersion for tagging
        $buildVars = @{
            "image_name" = $ImageName
            "base_image" = $BaseImage
            "macos_version" = $MacOSVersion
            "dotnet_channel" = $DotnetChannel
            "workload_set_version" = $WorkloadSetVersion
            "base_xcode_version" = $BaseXcodeVersion
            "additional_xcode_versions" = ($AdditionalXcodeVersions -join ",")
            "cpu_count" = $CPUCount
            "memory_gb" = $MemoryGB
            "disk_size_gb" = $DiskSizeGB
        }

        # Add any additional variables from config file
        if ($config.PSObject.Properties) {
            foreach ($prop in $config.PSObject.Properties) {
                if (-not $buildVars.ContainsKey($prop.Name)) {
                    $buildVars[$prop.Name] = $prop.Value
                }
            }
        }

        Write-Host "Build variables:"
        $buildVars.GetEnumerator() | Sort-Object Key | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)"
        }
        Write-Host ""

        # Build the image
        Start-TartBuild -TemplatePath $templatePath -Variables $buildVars
    }

    # Push to registry if requested
    if ($Push -or $PushOnly) {
        Push-TartImage -ImageName $ImageName -RegistryImageName $RegistryImageName -Registry $Registry -WorkloadSetVersion $resolvedWorkloadSetVersion -MacOSVersion $MacOSVersion -DotnetChannel $DotnetChannel -BaseXcodeVersion $BaseXcodeVersion -BuildSha $BuildSha
    }

    Write-Host ""
    if ($PushOnly) {
        Write-Host "✅ Push completed successfully!"
    } else {
        Write-Host "✅ Build completed successfully!"
    }
    Write-Host "Local image name: $ImageName"

    $publishedTags = if ($Registry) {
        Get-TartRegistryTags -ImageName $ImageName -RegistryImageName $RegistryImageName -Registry $Registry -WorkloadSetVersion $resolvedWorkloadSetVersion -MacOSVersion $MacOSVersion -DotnetChannel $DotnetChannel -BaseXcodeVersion $BaseXcodeVersion -BuildSha $BuildSha
    } else { @() }

    if (($Push -or $PushOnly) -and $Registry) {
        Write-Host ""
        Write-Host "Published tags:"
        foreach ($tag in $publishedTags) {
            Write-Host "  $tag"
        }
    }

    if (-not $DryRun) {
        Write-Host ""
        Write-Host "To run the VM locally:"
        Write-Host "  tart run $ImageName"
        Write-Host ""
        Write-Host "To run with directory mounting:"
        Write-Host "  tart run $ImageName --dir project:/path/to/your/project"

        if ($Registry) {
            Write-Host ""
            Write-Host "To pull from registry:"
            foreach ($tag in $publishedTags) {
                Write-Host "  tart pull $tag"
            }
        }
    }

} catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}
