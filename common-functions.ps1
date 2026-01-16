# Common PowerShell functions for build scripts

# Function to compare semantic versions with prerelease support
function Compare-SemanticVersion {
    param (
        [string]$Version1,
        [string]$Version2,
        [bool]$Prefer1 = $true  # Return true if Version1 should be preferred over Version2
    )
    
    # Parse versions into components
    function Parse-SemanticVersion($version) {
        if ($version -match '^(\d+\.\d+\.\d+)(-(.+))?') {
            $baseVersion = $matches[1]
            $prerelease = $matches[3]
            
            # Parse prerelease components
            $prereleaseComponents = @()
            if ($prerelease) {
                $prereleaseComponents = $prerelease.Split('.')
            }
            
            return @{
                BaseVersion = [version]$baseVersion
                Prerelease = $prerelease
                PrereleaseComponents = $prereleaseComponents
                IsPrerelease = [bool]$prerelease
            }
        }
        throw "Invalid semantic version: $version"
    }
    
    try {
        $v1 = Parse-SemanticVersion $Version1
        $v2 = Parse-SemanticVersion $Version2
        
        # Compare base versions first
        if ($v1.BaseVersion -gt $v2.BaseVersion) {
            return $Prefer1
        } elseif ($v1.BaseVersion -lt $v2.BaseVersion) {
            return -not $Prefer1
        }
        
        # Base versions are equal, handle prerelease comparison
        if (-not $v1.IsPrerelease -and -not $v2.IsPrerelease) {
            return $false  # Both are release versions and equal
        } elseif (-not $v1.IsPrerelease -and $v2.IsPrerelease) {
            return $Prefer1  # v1 is release, v2 is prerelease - prefer release
        } elseif ($v1.IsPrerelease -and -not $v2.IsPrerelease) {
            return -not $Prefer1  # v1 is prerelease, v2 is release - prefer release
        }
        
        # Both are prerelease - compare prerelease identifiers
        # RC > preview > alpha/beta (RC should be preferred)
        function Get-PrereleaseRank($prerelease) {
            if ($prerelease -match '^rc') { return 3 }
            elseif ($prerelease -match '^preview') { return 2 }
            else { return 1 }  # alpha, beta, etc.
        }
        
        $rank1 = Get-PrereleaseRank $v1.Prerelease
        $rank2 = Get-PrereleaseRank $v2.Prerelease
        
        if ($rank1 -gt $rank2) {
            return $Prefer1
        } elseif ($rank1 -lt $rank2) {
            return -not $Prefer1
        }
        
        # Same rank - do lexical comparison of full prerelease string
        if ($v1.Prerelease -gt $v2.Prerelease) {
            return $Prefer1
        } elseif ($v1.Prerelease -lt $v2.Prerelease) {
            return -not $Prefer1
        }
        
        return $false  # Versions are identical
        
    } catch {
        Write-Warning "Error comparing versions $Version1 and $Version2`: $($_.Exception.Message)"
        return $false
    }
}

# Function to find the latest workload set version
function Find-LatestWorkloadSet {
    param (
        [string]$DotnetVersion,
        [string]$WorkloadSetVersion = "",
        [bool]$IncludePrerelease = $false,
        [bool]$AutoDetectPrerelease = $true
    )
    
    Write-Host "Finding latest workload set for .NET $DotnetVersion..."
    if ($WorkloadSetVersion) {
        Write-Host "Looking for specific workload set version: $WorkloadSetVersion"
    }
    
    # Extract major version (e.g., "9.0" from "9.0.100")
    $majorVersion = $DotnetVersion
    if ($DotnetVersion -match '^(\d+\.\d+)') {
        $majorVersion = $Matches[1]
    }
    
    # Auto-detect if prerelease is needed by first checking for stable versions
    $effectiveIncludePrerelease = $IncludePrerelease
    if ($AutoDetectPrerelease -and -not $WorkloadSetVersion) {
        Write-Host "Auto-detecting if prerelease versions are needed..."
        
        # First try to find stable versions
        $stableResponse = $null
        $searchPattern = "Microsoft.NET.Workloads.$majorVersion"
        
        try {
            # Try official search endpoint for stable versions
            $serviceIndex = Invoke-RestMethod -Uri "https://api.nuget.org/v3/index.json"
            $searchService = $serviceIndex.resources | Where-Object { $_.'@type' -eq 'SearchQueryService' } | Select-Object -First 1
            
            if ($searchService) {
                $searchUrl = "$($searchService.'@id')?q=$searchPattern&prerelease=false&semVerLevel=2.0.0"
                $stableResponse = Invoke-RestMethod -Uri $searchUrl
            }
        }
        catch {
            # Fallback to direct search endpoint for stable versions
            $stableResponse = Invoke-RestMethod -Uri "https://azuresearch-usnc.nuget.org/query?q=$searchPattern&prerelease=false&semVerLevel=2.0.0"
        }
        
        # Filter stable workload sets (match SDK band pattern exactly)
        $stableWorkloadSets = $stableResponse.data | Where-Object { 
            # Match: Microsoft.NET.Workloads.{major}.{band} or Microsoft.NET.Workloads.{major}.{band}-{prerelease}
            # Allow prerelease identifiers with one dot (e.g., rc.1, preview.7) but exclude .Msi.{arch}
            $_.id -match "^Microsoft\.NET\.Workloads\.$majorVersion\.\d+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)?)*$"
        }
        
        if ($stableWorkloadSets -and $stableWorkloadSets.Count -gt 0) {
            Write-Host "Found $($stableWorkloadSets.Count) stable workload sets - using stable versions only"
            $effectiveIncludePrerelease = $false
        } else {
            Write-Host "No stable workload sets found - enabling prerelease search"
            $effectiveIncludePrerelease = $true
        }
    }
    
    if ($effectiveIncludePrerelease) {
        Write-Host "Including prerelease versions in search"
    } else {
        Write-Host "Using stable versions only"
    }
    
    # Search for workload set packages using the official NuGet API
    $searchPattern = "Microsoft.NET.Workloads.$majorVersion"
    
    try {
        # First, get the NuGet service index
        $serviceIndex = Invoke-RestMethod -Uri "https://api.nuget.org/v3/index.json"
        
        # Find the package search service
        $searchService = $serviceIndex.resources | Where-Object { $_.'@type' -eq 'SearchQueryService' } | Select-Object -First 1
        
        if (-not $searchService) {
            Write-Error "Could not find NuGet search service in the service index."
            return $null
        }
        
        # Use the official search endpoint
        $prereleaseParam = if ($effectiveIncludePrerelease) { "true" } else { "false" }
        $searchUrl = "$($searchService.'@id')?q=$searchPattern&prerelease=$prereleaseParam&semVerLevel=2.0.0"
        Write-Host "Using NuGet search URL: $searchUrl"
        
        $response = Invoke-RestMethod -Uri $searchUrl
    }
    catch {
        Write-Warning "Error accessing official NuGet API, falling back to direct search endpoint"
        # Fallback to the direct search endpoint if the service index approach fails
        $prereleaseParam = if ($effectiveIncludePrerelease) { "true" } else { "false" }
        $response = Invoke-RestMethod -Uri "https://azuresearch-usnc.nuget.org/query?q=$searchPattern&prerelease=$prereleaseParam&semVerLevel=2.0.0"
    }
    
    # Filter to match only SDK band workload sets (e.g., Microsoft.NET.Workloads.9.0.100 or Microsoft.NET.Workloads.10.0.100-rc.1)
    # This matches the exact SDK band pattern and excludes architecture-specific packages
    $workloadSets = $response.data | Where-Object { 
        # Match SDK band pattern: Microsoft.NET.Workloads.{major}.{band} or Microsoft.NET.Workloads.{major}.{band}-{prerelease}
        # Allow prerelease identifiers with one dot (e.g., rc.1, preview.7) but exclude .Msi.{arch}
        $_.id -match "^Microsoft\.NET\.Workloads\.$majorVersion\.\d+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)?)*$"
    }
    
    # If a specific WorkloadSetVersion is provided, filter to only that version
    if ($WorkloadSetVersion) {
        $workloadSets = $workloadSets | Where-Object { $_.version -eq $WorkloadSetVersion }
        if (-not $workloadSets) {
            Write-Error "No workload set found for .NET $majorVersion with version $WorkloadSetVersion"
            return $null
        }
        # If we found a specific version, return it directly
        if ($workloadSets.Count -eq 1) {
            $foundWorkloadSet = $workloadSets[0]
            Write-Host "Found specific workload set: $($foundWorkloadSet.id) v$($foundWorkloadSet.version)"
            Write-Host "DEBUG: Package ID that will be used: $($foundWorkloadSet.id)"
            return $foundWorkloadSet
        } elseif ($workloadSets.Count -gt 1) {
            # Multiple workload sets with the same version (different bands), pick the highest band
            Write-Host "Found multiple workload sets with version $WorkloadSetVersion, selecting highest band..."
        }
    }
    
    if (-not $workloadSets) {
        Write-Error "No workload sets found for .NET $majorVersion"
        return $null
    }
    
    # Group by version band (e.g., 9.0.100, 9.0.200) and find the latest version in each band
    $versionBands = @{}
    
    foreach ($ws in $workloadSets) {
        # Extract base version band (e.g., "10.0.100" from "10.0.100-rc.1" or "10.0.100-preview.6")
        $fullBand = $ws.id -replace "Microsoft\.NET\.Workloads\.", ""
        $versionBand = $fullBand
        if ($fullBand -match '^(\d+\.\d+\.\d+)(-.*)?') {
            $versionBand = $matches[1]
        }
        
        if (-not $versionBands.ContainsKey($versionBand)) {
            $versionBands[$versionBand] = $ws
        } else {
            # Compare semantic versions properly (handles prerelease identifiers)
            if (Compare-SemanticVersion -Version1 $ws.version -Version2 $versionBands[$versionBand].version -Prefer1 $true) {
                $versionBands[$versionBand] = $ws
            }
        }
    }
    
    # Find the highest version band by parsing the band number
    $highestBand = $versionBands.Keys | ForEach-Object {
        # Extract the band part (e.g., "100" from "9.0.100" or "10.0.100-rc.1")
        if ($_ -match "$majorVersion\.(\d+)") {
            [PSCustomObject]@{
                FullBand = $_
                BandNumber = [int]$Matches[1]
            }
        }
    } | Sort-Object -Property BandNumber -Descending | Select-Object -First 1 -ExpandProperty FullBand
    
    if ($highestBand) {
        $latestWorkloadSet = $versionBands[$highestBand]
        Write-Host "Found latest workload set: $($latestWorkloadSet.id) v$($latestWorkloadSet.version)"
        Write-Host "DEBUG: Package ID that will be used: $($latestWorkloadSet.id)"
        return $latestWorkloadSet
    }
    
    Write-Error "Failed to determine the latest workload set version"
    return $null
}

# Function to download and extract a NuGet package
function Get-NuGetPackageContent {
    param (
        [string]$PackageId,
        [string]$Version,
        [string]$FilePath
    )
    
    $envTemp = $env:TEMP
    if (-not $envTemp) {
        $envTemp = "./_temp"
    }

    $tempDir = Join-Path $envTemp "nuget_extract_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    $nupkgPath = Join-Path $tempDir "$PackageId.$Version.nupkg"
    $extractPath = Join-Path $tempDir "extracted"
    
    try {
        # Download the package
        $nugetUrl = "https://www.nuget.org/api/v2/package/$PackageId/$Version"
        Write-Host "Downloading $PackageId v$Version..."
        Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath
        
        # Extract the package (nupkg files are zip files)
        # Rename to .zip for compatibility with PowerShell 5.1's Expand-Archive
        $zipPath = $nupkgPath -replace '\.nupkg$', '.zip'
        if ($nupkgPath -ne $zipPath) {
            Move-Item -Path $nupkgPath -Destination $zipPath -Force
        }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Check if the requested file exists
        $targetFile = Join-Path $extractPath $FilePath
        Write-Host "Looking for file: $targetFile"
        if (Test-Path $targetFile) {
            $content = Get-Content -Path $targetFile -Raw
            return $content
        } else {
            Write-Error "File '$FilePath' not found in package $PackageId v$Version"
            return $null
        }
    }
    catch {
        Write-Error "Error processing NuGet package $PackageId v${Version}: $_"
        return $null
    }
    finally {
        # Clean up
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}

# Function to convert NuGet-compatible version to dotnet workload CLI version format
# 
# IMPORTANT: .NET CLI uses different version formats than NuGet packages:
#
# For STABLE versions:
#   NuGet Package: Microsoft.NET.Workloads.9.0.300 v9.305.0
#   CLI Command:   dotnet workload install --version 9.0.305
#   Conversion:    9.305.0 → 9.0.305 (major.0.patch[.additional])
#
# For PRERELEASE versions:  
#   NuGet Package: Microsoft.NET.Workloads.10.0.100-rc.1 v10.100.0-rc.1.25458.2
#   CLI Command:   dotnet workload install --version 10.0.100-rc.1.25458.2  
#   Conversion:    10.100.0-rc.1.25458.2 → 10.0.100-rc.1.25458.2
#
# The key insight is that:
# 1. Package IDs include prerelease suffix: microsoft.net.workloads.10.0.100-rc.1
# 2. CLI versions keep prerelease suffix but convert base version: 10.0.100-rc.1.25458.2
# 3. The CLI looks for the package with prerelease suffix in the name
function Convert-ToWorkloadVersion {
    param (
        [string]$NuGetVersion
    )
    
    if ([string]::IsNullOrEmpty($NuGetVersion)) {
        return $null
    }
    
    Write-Host "Converting NuGet version '$NuGetVersion' to dotnet workload CLI format"
    
    # Check if this is a prerelease version (contains hyphen)
    if ($NuGetVersion -match '^([^-]+)-(.+)$') {
        $baseVersion = $matches[1]
        $prereleaseIdentifier = $matches[2]
        Write-Host "Detected prerelease version: base='$baseVersion' prerelease='$prereleaseIdentifier'"
        
        # Convert the base version and append prerelease
        $convertedBase = Convert-BaseVersionToCliFormat -BaseVersion $baseVersion
        $workloadVersion = "$convertedBase-$prereleaseIdentifier"
        
        Write-Host "Converted to: $workloadVersion"
        return $workloadVersion
    } else {
        # This is a stable version - use existing logic
        $workloadVersion = Convert-BaseVersionToCliFormat -BaseVersion $NuGetVersion
        Write-Host "Converted to: $workloadVersion"
        return $workloadVersion
    }
}

# Helper function to convert base version from NuGet to CLI format
function Convert-BaseVersionToCliFormat {
    param (
        [string]$BaseVersion
    )
    
    # Split the version by dots
    $parts = $BaseVersion.Split('.')
    
    # NuGet versions are typically in format like 9.203.0 or 10.100.0
    # Dotnet CLI expects format like 9.0.203 or 10.0.100
    if ($parts.Count -ge 3) {
        $major = $parts[0]
        $minor = "0"  # Always 0 in dotnet CLI format for the second component
        $patch = $parts[1]  # The third component in CLI format is from the second in NuGet
        
        # Start building the dotnet CLI version
        $workloadVersion = "$major.$minor.$patch"
        
        # If there are additional components, add them to the end
        if ($parts.Count -gt 3) {
            for ($i = 2; $i -lt $parts.Count; $i++) {
                $workloadVersion += ".$($parts[$i])"
            }
        }
        # If we have exactly 3 parts and the last one is not 0, add it
        elseif ($parts[2] -ne "0") {
            $workloadVersion += ".$($parts[2])"
        }
        
        return $workloadVersion
    }
    
    # If the format doesn't match our expectations, return the original version
    Write-Host "Could not convert version, using original: $BaseVersion"
    return $BaseVersion
}

# Parse the version information (format is "version/sdk-band")
function Parse-VersionInfo {
    param (
        [string]$VersionString,
        [string]$WorkloadName
    )
    
    if ($VersionString -match '(.+)/(.+)') {
        $Version = $Matches[1]
        $SdkBand = $Matches[2]
        
        return @{
            Version = $Version
            SdkBand = $SdkBand
        }
    } else {
        Write-Error "Failed to parse version information for ${WorkloadName} : $VersionString"
        return $null
    }
}

# Function to extract Android SDK and JDK information from workload dependencies
function Get-AndroidWorkloadInfo {
    param (
        [PSObject]$Dependencies,
        [string]$DockerPlatform
    )
    
    # Initialize variables to store extracted information
    $androidJdkRecommendedVersion = $null
    $androidJdkVersionRange = $null
    $androidJdkMajorVersion = $null
    $androidSdkPackages = @()
    $buildToolsVersion = $null
    $cmdLineToolsVersion = $null
    $apiLevel = $null
    $systemImageType = $null
    $avdDeviceType = $null
    $systemImageArch = $null
    
    if ($DockerPlatform.StartsWith("linux/")) {
        $targetPlatform = "linux-x64"
    } elseif ($DockerPlatform.StartsWith("windows/")) {
        $targetPlatform = "win-x64"
    } else {
        Write-Error "Unsupported Docker platform: $DockerPlatform"
        return $null
    }
    Write-Host "Target platform: $targetPlatform"
    
    # Extract Android SDK information from the proper structure
    $androidInfo = $Dependencies."microsoft.net.sdk.android"
    if ($androidInfo) {
        # Extract JDK information
        if ($androidInfo.jdk) {
            if ($androidInfo.jdk -isnot [string]) {
                $jdkObject = $androidInfo.jdk.PSObject
                $versionProperty = $jdkObject.Properties['version']
                if ($versionProperty) {
                    $androidJdkVersionRange = $versionProperty.Value
                }
                $recommendedProperty = $jdkObject.Properties['recommendedVersion']
                if ($recommendedProperty) {
                    $androidJdkRecommendedVersion = $recommendedProperty.Value
                }
            }
            
            Write-Host "Found Android JDK info:"
            Write-Host "  Version Range: $androidJdkVersionRange"
            Write-Host "  Recommended Version: $androidJdkRecommendedVersion"
            
            # Extract major version from recommended version
            if ($androidJdkRecommendedVersion -match '^(\d+)') {
                $androidJdkMajorVersion = $Matches[1]
                Write-Host "  Extracted JDK major version: $androidJdkMajorVersion"
            }
        }
        
        # Extract Android SDK packages
        if ($androidInfo.androidsdk -and $androidInfo.androidsdk.packages) {
            $packages = $androidInfo.androidsdk.packages
            
            foreach ($package in $packages) {
                $desc = $package.desc
                $optional = [bool]::Parse($package.optional)
                
                # Get the package ID (handling platform-specific IDs)
                $packageId = $null
                if ($package.sdkPackage.id -is [string]) {
                    $packageId = $package.sdkPackage.id
                } elseif ($package.sdkPackage.id.$targetPlatform) {
                    $packageId = $package.sdkPackage.id.$targetPlatform
                }
                
                # Get recommended version if available
                $recommendedVersion = $null
                if ($package.sdkPackage -isnot [string]) {
                    $sdkPackageObject = $package.sdkPackage.PSObject
                    $recommendedProperty = $sdkPackageObject.Properties['recommendedVersion']
                    if ($recommendedProperty) {
                        $recommendedVersion = $recommendedProperty.Value
                    }
                }
                
                # Create a structured object with detailed package info
                if ($packageId) {
                    $packageInfo = [PSCustomObject]@{
                        Id = $packageId
                        Description = $desc
                        Optional = $optional
                        RecommendedVersion = $recommendedVersion
                    }
                    
                    $androidSdkPackages += $packageInfo
                    
                    Write-Host "Found Android SDK package: $($packageId) ($(if($optional){'Optional'}else{'Required'}))"
                }
            }
        }
    }
    
    # Output summary of found packages
    Write-Host "Found $($androidSdkPackages.Count) Android SDK packages"
    
    # Extract key information for Docker build arguments
    $buildToolsPackage = $androidSdkPackages | Where-Object { $_.Id -match "^build-tools;" } | Select-Object -First 1
    $cmdLineToolsPackage = $androidSdkPackages | Where-Object { $_.Id -match "^cmdline-tools;" } | Select-Object -First 1
    $platformPackage = $androidSdkPackages | Where-Object { $_.Id -match "^platforms;android-" } | Select-Object -First 1
    
    # Find the best system image package based on platform and preference for Google APIs
    $systemImagePackages = $androidSdkPackages | Where-Object { $_.Id -match "^system-images;" }
    $systemImagePackage = $systemImagePackages | Select-Object -First 1

    # Log the selected system image package
    if ($systemImagePackage) {
        Write-Host "Selected system image package: $($systemImagePackage.Id)"
    } else {
        Write-Warning "No system image package found"
    }
    
    # Extract specific versions from package IDs
    if ($buildToolsPackage -and $buildToolsPackage.Id -match 'build-tools;(\d+\.\d+\.\d+)') {
        $buildToolsVersion = $Matches[1]
    }
    
    if ($cmdLineToolsPackage -and $cmdLineToolsPackage.Id -match 'cmdline-tools;(\d+\.\d+)') {
        $cmdLineToolsVersion = $Matches[1]
    }
    
    if ($platformPackage -and $platformPackage.Id -match 'platforms;android-(\d+)') {
        $apiLevel = $Matches[1]
    }
    
    # Extract system image type and device type information
    if ($systemImagePackage) {
        # Extract system image type (e.g., google_apis, google_apis_playstore)
        if ($systemImagePackage.Id -match 'system-images;android-\d+;([^;]+);([^;]+)') {
            $systemImageType = $Matches[1]
            $systemImageArch = $Matches[2]
            Write-Host "Selected system image type: $systemImageType, architecture: $systemImageArch"
        }
        
        $avdDeviceType = "Nexus 5" # Default device type
        
        Write-Host "Selected AVD device type: $avdDeviceType"
    }
    
    # Return the collected information
    return @{
        JdkMajorVersion = $androidJdkMajorVersion
        JdkRecommendedVersion = $androidJdkRecommendedVersion
        JdkVersionRange = $androidJdkVersionRange
        BuildToolsVersion = $buildToolsVersion
        CmdLineToolsVersion = $cmdLineToolsVersion
        ApiLevel = $apiLevel
        SystemImageType = $systemImageType
        AvdDeviceType = $avdDeviceType
        AvdSystemImageArch = $systemImageArch
        SystemImagePackage = $systemImagePackage
        Packages = $androidSdkPackages
    }
}

# Function to get iOS workload information from dependencies
function Get-iOSWorkloadInfo {
    param (
        [PSObject]$Dependencies,
        [string]$DockerPlatform
    )

    # Initialize variables to store extracted information
    $xcodeVersionRange = $null
    $xcodeRecommendedVersion = $null
    $xcodeMajorVersion = $null
    $iOSSdkVersion = $null

    Write-Host "Processing dependency information for Microsoft.NET.Sdk.iOS"

    # Extract iOS SDK information from the proper structure
    $iOSInfo = $Dependencies."microsoft.net.sdk.ios"
    if ($iOSInfo) {
        # Extract Xcode information
        if ($iOSInfo.xcode) {
            if ($iOSInfo.xcode -isnot [string]) {
                $xcodeObject = $iOSInfo.xcode.PSObject
                $versionProperty = $xcodeObject.Properties['version']
                if ($versionProperty) {
                    $xcodeVersionRange = $versionProperty.Value
                }
                $recommendedProperty = $xcodeObject.Properties['recommendedVersion']
                if ($recommendedProperty) {
                    $xcodeRecommendedVersion = $recommendedProperty.Value
                }
            }

            Write-Host "Found Xcode info:"
            Write-Host "  Version Range: $xcodeVersionRange"
            Write-Host "  Recommended Version: $xcodeRecommendedVersion"

            # Extract major version from recommended version
            if ($xcodeRecommendedVersion -match '^(\d+)') {
                $xcodeMajorVersion = [int]$Matches[1]
                Write-Host "  Extracted Xcode major version: $xcodeMajorVersion"
            }
        }

        # Extract iOS SDK version
        if ($iOSInfo.sdk -and $iOSInfo.sdk.version) {
            $iOSSdkVersion = $iOSInfo.sdk.version
            Write-Host "Found iOS SDK version: $iOSSdkVersion"
        }
    } else {
        Write-Warning "No iOS workload information found in dependencies"
        return $null
    }

    # Return structured information
    return @{
        XcodeVersionRange = $xcodeVersionRange
        XcodeRecommendedVersion = $xcodeRecommendedVersion
        XcodeMajorVersion = $xcodeMajorVersion
        IOSSdkVersion = $iOSSdkVersion
    }
}

function Get-TvOSWorkloadInfo {
    param (
        [PSObject]$Dependencies,
        [string]$DockerPlatform
    )

    $xcodeVersionRange = $null
    $xcodeRecommendedVersion = $null
    $xcodeMajorVersion = $null
    $tvOsSdkVersion = $null

    Write-Host "Processing dependency information for Microsoft.NET.Sdk.tvOS"

    $tvInfo = $Dependencies."microsoft.net.sdk.tvos"
    if (-not $tvInfo) {
        Write-Warning "No tvOS workload information found in dependencies"
        return $null
    }

    if ($tvInfo.xcode -and $tvInfo.xcode -isnot [string]) {
        $xcodeObject = $tvInfo.xcode.PSObject
        $versionProperty = $xcodeObject.Properties['version']
        if ($versionProperty) {
            $xcodeVersionRange = $versionProperty.Value
        }
        $recommendedProperty = $xcodeObject.Properties['recommendedVersion']
        if ($recommendedProperty) {
            $xcodeRecommendedVersion = $recommendedProperty.Value
        }

        Write-Host "Found tvOS Xcode info:"
        Write-Host "  Version Range: $xcodeVersionRange"
        Write-Host "  Recommended Version: $xcodeRecommendedVersion"

        if ($xcodeRecommendedVersion -match '^(\d+)') {
            $xcodeMajorVersion = [int]$Matches[1]
            Write-Host "  Extracted Xcode major version: $xcodeMajorVersion"
        }
    }

    if ($tvInfo.sdk -and $tvInfo.sdk.version) {
        $tvOsSdkVersion = $tvInfo.sdk.version
        Write-Host "Found tvOS SDK version: $tvOsSdkVersion"
    }

    return @{
        XcodeVersionRange = $xcodeVersionRange
        XcodeRecommendedVersion = $xcodeRecommendedVersion
        XcodeMajorVersion = $xcodeMajorVersion
        TvOsSdkVersion = $tvOsSdkVersion
    }
}

# Function to get workload set information including versions and dependencies
function Get-WorkloadSetInfo {
    param (
        [string]$DotnetVersion,
        [string]$WorkloadSetVersion = "",
        [string[]]$WorkloadNames = @("Microsoft.NET.Sdk.Android"),
        [bool]$IncludePrerelease = $false
    )
    
    # Extract major version (e.g., "9.0" from "9.0.100") for package ID construction
    $majorVersion = $DotnetVersion
    if ($DotnetVersion -match '^(\d+\.\d+)') {
        $majorVersion = $Matches[1]
    }
    
    # Find the latest workload set if not specified
    if (-not $WorkloadSetVersion) {
        $latestWorkloadSet = Find-LatestWorkloadSet -DotnetVersion $majorVersion -IncludePrerelease $IncludePrerelease -AutoDetectPrerelease $true
        if ($latestWorkloadSet) {
            $WorkloadSetVersion = $latestWorkloadSet.version
            $WorkloadSetId = $latestWorkloadSet.id  # Use the actual package ID from search results
            Write-Host "Using workload set: $WorkloadSetId v$WorkloadSetVersion"
        } else {
            Write-Error "Failed to find a valid workload set. Please specify WorkloadSetVersion manually."
            return $null
        }
    } else {
        # Find the workload set with the specified version
        $specificWorkloadSet = Find-LatestWorkloadSet -DotnetVersion $majorVersion -WorkloadSetVersion $WorkloadSetVersion -IncludePrerelease $IncludePrerelease -AutoDetectPrerelease $true
        if ($specificWorkloadSet) {
            $WorkloadSetId = $specificWorkloadSet.id  # Use the actual package ID from search results
            Write-Host "Using specified workload set: $WorkloadSetId v$WorkloadSetVersion"
        } else {
            Write-Error "Failed to find workload set with version $WorkloadSetVersion for .NET $majorVersion"
            return $null
        }
    }

    # Convert the WorkloadSetVersion to the format expected by dotnet workload CLI commands
    $DotnetCommandWorkloadSetVersion = Convert-ToWorkloadVersion -NuGetVersion $WorkloadSetVersion
    Write-Host "Using dotnet workload CLI version: $DotnetCommandWorkloadSetVersion"

    # Download and parse the workload set JSON
    $workloadSetJsonContent = Get-NuGetPackageContent -PackageId $WorkloadSetId -Version $WorkloadSetVersion -FilePath "data/microsoft.net.workloads.workloadset.json"
    $workloadSetData = $workloadSetJsonContent | ConvertFrom-Json

    Write-Host "Parsing workload information from workload set..."

    # Create result object
    $result = @{
        DotnetVersion = $DotnetVersion
        WorkloadSetId = $WorkloadSetId
        WorkloadSetVersion = $WorkloadSetVersion
        DotnetCommandWorkloadSetVersion = $DotnetCommandWorkloadSetVersion
        Workloads = @{}
    }

    # Process each requested workload
    foreach ($workloadName in $WorkloadNames) {
        $versionInfo = $workloadSetData.$workloadName
        
        # Check if we found the workload
        if (-not $versionInfo) {
            Write-Warning "Could not find workload '$workloadName' in the workload set."
            continue
        }

        # Parse version information
        $info = Parse-VersionInfo -VersionString $versionInfo -WorkloadName $workloadName
        if (-not $info) {
            Write-Warning "Failed to parse version information for $workloadName"
            continue
        }

        $version = $info.Version
        $sdkBand = $info.SdkBand

        Write-Host "Found workload '$workloadName': version=$version, sdk-band=$sdkBand"

        # Build manifest ID
        $manifestId = "$workloadName.Manifest-$sdkBand"

        # Get the manifest content
        $manifestContent = Get-NuGetPackageContent -PackageId $manifestId -Version $version -FilePath "data/WorkloadManifest.json"

        # Get the dependencies content
        $dependenciesContent = Get-NuGetPackageContent -PackageId $manifestId -Version $version -FilePath "data/WorkloadDependencies.json"

        # Parse the dependencies into objects
        $dependencies = $dependenciesContent | ConvertFrom-Json

        # Add to result
        $result.Workloads[$workloadName] = @{
            Id = $workloadName
            Version = $version
            SdkBand = $sdkBand
            ManifestId = $manifestId
            Dependencies = $dependencies
        }
    }

    return $result
}

# Comprehensive function to get all workload information in one call
function Get-WorkloadInfo {
    param (
        [string]$DotnetVersion,
        [string]$WorkloadSetVersion = "",
        [switch]$IncludeAndroid,
        [switch]$IncludeiOS,
        [switch]$IncludeTvOS,
        [switch]$IncludeMaui,
        [string]$DockerPlatform
    )

    # Determine which workloads to include
    $workloadNames = @()
    if ($IncludeAndroid) {
        $workloadNames += "Microsoft.NET.Sdk.Android"
    }
    if ($IncludeiOS) {
        $workloadNames += "Microsoft.NET.Sdk.iOS"
    }
    if ($IncludeTvOS) {
        $workloadNames += "Microsoft.NET.Sdk.tvOS"
    }
    if ($IncludeMaui) {
        $workloadNames += "Microsoft.NET.Sdk.Maui"
    }
    
    # If no specific workloads selected, include all supported ones
    if ($workloadNames.Count -eq 0) {
        $workloadNames = @("Microsoft.NET.Sdk.Android", "Microsoft.NET.Sdk.iOS", "Microsoft.NET.Sdk.tvOS", "Microsoft.NET.Sdk.Maui")
        Write-Host "No specific workloads selected, including all supported workloads."
    }
    
    Write-Host "Getting workload information for: $($workloadNames -join ', ')"
    
    # Get the basic workload set information
    $workloadSetInfo = Get-WorkloadSetInfo -DotnetVersion $DotnetVersion -WorkloadSetVersion $WorkloadSetVersion -WorkloadNames $workloadNames
    
    if (-not $workloadSetInfo) {
        Write-Error "Failed to get workload set information."
        return $null
    }
    
    # Create the result object
    $result = @{
        DotnetVersion = $workloadSetInfo.DotnetVersion
        WorkloadSetId = $workloadSetInfo.WorkloadSetId
        WorkloadSetVersion = $workloadSetInfo.WorkloadSetVersion
        DotnetCommandWorkloadSetVersion = $workloadSetInfo.DotnetCommandWorkloadSetVersion
        Workloads = @{}
    }
    
    # Process each workload to get detailed dependency information
    foreach ($workloadName in $workloadNames) {
        $workload = $workloadSetInfo.Workloads[$workloadName]
        
        if (-not $workload) {
            Write-Warning "Workload '$workloadName' not found in workload set, skipping."
            continue
        }
        
        Write-Host "Processing dependency information for $workloadName"
        
        # Create a workload entry with basic info
        $workloadResult = @{
            Id = $workload.Id
            Version = $workload.Version
            SdkBand = $workload.SdkBand
            ManifestId = $workload.ManifestId
            Dependencies = $workload.Dependencies
        }
        
        # Get specific information based on the workload type
        switch ($workloadName) {
            "Microsoft.NET.Sdk.Android" {
                if ($IncludeAndroid) {
                    $androidInfo = Get-AndroidWorkloadInfo -Dependencies $workload.Dependencies -DockerPlatform $DockerPlatform
                    $workloadResult.Details = $androidInfo
                }
            }
            "Microsoft.NET.Sdk.iOS" {
                if ($IncludeiOS) {
                    $iOSInfo = Get-iOSWorkloadInfo -Dependencies $workload.Dependencies -DockerPlatform $DockerPlatform
                    $workloadResult.Details = $iOSInfo
                }
            }
            "Microsoft.NET.Sdk.tvOS" {
                if ($IncludeTvOS) {
                    $tvOsInfo = Get-TvOSWorkloadInfo -Dependencies $workload.Dependencies -DockerPlatform $DockerPlatform
                    $workloadResult.Details = $tvOsInfo
                }
            }
            "Microsoft.NET.Sdk.Maui" {
                if ($IncludeMaui) {
                    # For future implementation - MAUI-specific info parser
                    # $mauiInfo = Get-MauiWorkloadInfo -Dependencies $workload.Dependencies -DockerPlatform $DockerPlatform
                    # $workloadResult.Details = $mauiInfo
                }
            }
        }
        
        # Add the workload to the result
        $result.Workloads[$workloadName] = $workloadResult
    }
    
    return $result
}

# ============================================================================
# Cirrus Labs Base Image Selection Functions
# ============================================================================

# Function to parse NuGet/Maven version range notation
# Supports: [min,max], (min,max), [min,max), (min,max], [min,), (min,), etc.
function Parse-NuGetVersionRange {
    param(
        [Parameter(Mandatory=$true)]
        [string]$VersionRange
    )

    Write-Host "Parsing version range: $VersionRange"

    # Handle empty or null
    if ([string]::IsNullOrWhiteSpace($VersionRange)) {
        Write-Warning "Empty version range provided"
        return $null
    }

    # Regex to parse version range: [16.0,17.0) or (16.0,17.0] etc.
    # Captures: opening bracket, min version, max version (optional), closing bracket
    $pattern = '^([\[\(])([^,\]\)]+)(?:,([^\]\)]*))?([\]\)])$'

    if ($VersionRange -match $pattern) {
        $openBracket = $Matches[1]
        $minVersionStr = $Matches[2].Trim()
        $maxVersionStr = if ($Matches[3]) { $Matches[3].Trim() } else { $null }
        $closeBracket = $Matches[4]

        # Parse versions
        $minVersion = $null
        $maxVersion = $null

        if (-not [string]::IsNullOrWhiteSpace($minVersionStr)) {
            try {
                $minVersion = [Version]$minVersionStr
            } catch {
                Write-Warning "Failed to parse min version: $minVersionStr"
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($maxVersionStr)) {
            try {
                $maxVersion = [Version]$maxVersionStr
            } catch {
                Write-Warning "Failed to parse max version: $maxVersionStr"
            }
        }

        $result = @{
            MinVersion = $minVersion
            MaxVersion = $maxVersion
            MinInclusive = ($openBracket -eq '[')
            MaxInclusive = ($closeBracket -eq ']')
            OriginalRange = $VersionRange
        }

        Write-Host "  Min: $($result.MinVersion) (inclusive: $($result.MinInclusive))"
        Write-Host "  Max: $($result.MaxVersion) (inclusive: $($result.MaxInclusive))"

        return $result
    } else {
        Write-Warning "Version range '$VersionRange' does not match expected format"
        return $null
    }
}

# Function to test if a version satisfies a parsed version range
function Test-VersionInRange {
    param(
        [Parameter(Mandatory=$true)]
        [Version]$Version,

        [Parameter(Mandatory=$true)]
        [hashtable]$VersionRange
    )

    # Check minimum bound
    if ($VersionRange.MinVersion) {
        if ($VersionRange.MinInclusive) {
            if ($Version -lt $VersionRange.MinVersion) {
                return $false
            }
        } else {
            if ($Version -le $VersionRange.MinVersion) {
                return $false
            }
        }
    }

    # Check maximum bound
    if ($VersionRange.MaxVersion) {
        if ($VersionRange.MaxInclusive) {
            if ($Version -gt $VersionRange.MaxVersion) {
                return $false
            }
        } else {
            if ($Version -ge $VersionRange.MaxVersion) {
                return $false
            }
        }
    }

    return $true
}

# Function to get mapping between macOS versions, Cirrus Labs tags, and Xcode versions
function Get-CirrusLabsXcodeMapping {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MacOSVersion  # e.g., "tahoe", "sequoia"
    )

    # Mapping of macOS versions to their internal version numbers and Xcode base versions
    # Cirrus Labs naming: macos-{version}-xcode:{internal_version}.{xcode_minor}
    # For Tahoe: internal version is 26, Xcode base is 16
    # Tag "26" = Xcode 16.0, "26.1" = Xcode 16.1, "26.2" = Xcode 16.2
    $macOSMappings = @{
        "tahoe" = @{
            InternalVersion = 26
            XcodeBaseVersion = 16
            MacOSVersion = "16"
        }
        "sequoia" = @{
            InternalVersion = 15  # Sequoia uses different scheme
            XcodeBaseVersion = 16
            MacOSVersion = "15"
        }
    }

    $mapping = $macOSMappings[$MacOSVersion.ToLower()]
    if (-not $mapping) {
        Write-Warning "Unknown macOS version: $MacOSVersion. Supported: $($macOSMappings.Keys -join ', ')"
        return $null
    }

    return @{
        MacOSVersion = $MacOSVersion
        InternalVersion = $mapping.InternalVersion
        XcodeBaseVersion = $mapping.XcodeBaseVersion
    }
}

# Function to convert a Cirrus Labs tag to an Xcode version
function Convert-CirrusTagToXcodeVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Tag,

        [Parameter(Mandatory=$true)]
        [hashtable]$Mapping
    )

    # Parse the tag: "26" -> 26.0, "26.1" -> 26.1, "26.1.1" -> 26.1.1
    $tagParts = $Tag -split '\.'

    $internalMajor = [int]$tagParts[0]
    $minor = if ($tagParts.Count -gt 1) { $tagParts[1] } else { "0" }
    $patch = if ($tagParts.Count -gt 2) { $tagParts[2] } else { $null }

    # Calculate Xcode version based on the mapping
    # For Tahoe: tag 26.x -> Xcode 16.x
    $xcodeVersionDiff = $internalMajor - $Mapping.InternalVersion
    $xcodeMajor = $Mapping.XcodeBaseVersion + $xcodeVersionDiff

    if ($patch) {
        return "$xcodeMajor.$minor.$patch"
    } else {
        return "$xcodeMajor.$minor"
    }
}

# Function to convert an Xcode version to a Cirrus Labs tag
function Convert-XcodeVersionToCirrusTag {
    param(
        [Parameter(Mandatory=$true)]
        [string]$XcodeVersion,

        [Parameter(Mandatory=$true)]
        [hashtable]$Mapping
    )

    $versionParts = $XcodeVersion -split '\.'
    $xcodeMajor = [int]$versionParts[0]
    $minor = if ($versionParts.Count -gt 1) { $versionParts[1] } else { "0" }
    $patch = if ($versionParts.Count -gt 2) { $versionParts[2] } else { $null }

    # Calculate Cirrus tag from Xcode version
    # For Tahoe: Xcode 16.x -> tag 26.x
    $tagMajor = $Mapping.InternalVersion + ($xcodeMajor - $Mapping.XcodeBaseVersion)

    if ($patch -and $patch -ne "0") {
        return "$tagMajor.$minor.$patch"
    } elseif ($minor -ne "0") {
        return "$tagMajor.$minor"
    } else {
        return "$tagMajor"
    }
}

# Function to query available Cirrus Labs base image tags from GHCR
function Get-CirrusLabsAvailableTags {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MacOSVersion  # e.g., "tahoe", "sequoia"
    )

    $repository = "ghcr.io/cirruslabs/macos-$MacOSVersion-xcode"
    Write-Host "Querying available tags from: $repository"

    # Parse repository for GHCR API call
    if ($repository -match '^ghcr\.io/([^/]+)/(.+)$') {
        $owner = $Matches[1]
        $packageName = $Matches[2]

        $ghcrUri = "https://api.github.com/orgs/$owner/packages/container/$packageName/versions?per_page=100"
        Write-Host "Querying GitHub Container Registry API: $ghcrUri"

        $headers = @{
            Accept = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }

        # Add auth token if available (required for GHCR packages API)
        if ($env:GITHUB_TOKEN) {
            $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
        }

        try {
            $response = Invoke-RestMethod -Uri $ghcrUri -Headers $headers -TimeoutSec 30

            # Extract all tags from the response
            $tags = @()
            foreach ($version in $response) {
                if ($version.metadata -and $version.metadata.container -and $version.metadata.container.tags) {
                    $tags += $version.metadata.container.tags
                }
            }

            # Remove duplicates, filter out non-version tags, and sort
            $versionTags = $tags | Where-Object { $_ -match '^\d+(\.\d+)*$' } | Sort-Object -Unique

            Write-Host "Found $($versionTags.Count) version tags: $($versionTags -join ', ')"
            return $versionTags
        }
        catch {
            Write-Warning "Failed to query GHCR API: $($_.Exception.Message)"
            Write-Host "Note: GHCR packages API requires GITHUB_TOKEN. Falling back to known tags..."

            # Fallback: Try to probe known tags using docker manifest
            return Get-CirrusLabsKnownTags -MacOSVersion $MacOSVersion
        }
    } else {
        Write-Warning "Invalid repository format: $repository"
        return @()
    }
}

# Fallback function to probe known Cirrus Labs tags when API is unavailable
function Get-CirrusLabsKnownTags {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MacOSVersion
    )

    Write-Host "Probing for known Cirrus Labs tags..."

    # Known tag patterns for Cirrus Labs macOS images
    $knownPatterns = switch ($MacOSVersion.ToLower()) {
        "tahoe" { @("26", "26.1", "26.1.1", "26.2", "26.2.1", "26.3") }
        "sequoia" { @("16", "16.1", "16.2", "16.3", "16.4") }
        default { @() }
    }

    $availableTags = @()
    $repository = "ghcr.io/cirruslabs/macos-$MacOSVersion-xcode"

    foreach ($tag in $knownPatterns) {
        try {
            # Use docker manifest inspect to check if tag exists
            $result = & docker manifest inspect "${repository}:${tag}" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $availableTags += $tag
                Write-Host "  Found tag: $tag"
            }
        } catch {
            # Tag doesn't exist, skip
        }
    }

    Write-Host "Found $($availableTags.Count) available tags via probing"
    return $availableTags
}

# Function to get SHA256 digest for a specific Cirrus Labs image tag
function Get-CirrusLabsImageDigest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MacOSVersion,

        [Parameter(Mandatory=$true)]
        [string]$Tag
    )

    $repository = "ghcr.io/cirruslabs/macos-$MacOSVersion-xcode"
    Write-Host "Getting digest for: ${repository}:${Tag}"

    # Parse repository for GHCR API call
    if ($repository -match '^ghcr\.io/([^/]+)/(.+)$') {
        $owner = $Matches[1]
        $packageName = $Matches[2]

        $ghcrUri = "https://api.github.com/orgs/$owner/packages/container/$packageName/versions?per_page=100"

        $headers = @{
            Accept = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }

        if ($env:GITHUB_TOKEN) {
            $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
        }

        try {
            $response = Invoke-RestMethod -Uri $ghcrUri -Headers $headers -TimeoutSec 30

            # Find the version with the matching tag
            foreach ($version in $response) {
                if ($version.metadata -and $version.metadata.container -and $version.metadata.container.tags) {
                    if ($version.metadata.container.tags -contains $Tag) {
                        # The version name is the digest
                        $digest = $version.name
                        Write-Host "Found digest for tag '$Tag': $digest"
                        return $digest
                    }
                }
            }

            Write-Warning "Tag '$Tag' not found in repository"
            return $null
        }
        catch {
            Write-Warning "Failed to get digest from GHCR API: $($_.Exception.Message)"
            Write-Host "Falling back to docker manifest inspect..."

            # Fallback: Use docker manifest inspect
            return Get-ImageDigestViaDocker -Repository $repository -Tag $Tag
        }
    } else {
        Write-Warning "Invalid repository format: $repository"
        return $null
    }
}

# Fallback function to get image digest using docker manifest inspect
function Get-ImageDigestViaDocker {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Repository,

        [Parameter(Mandatory=$true)]
        [string]$Tag
    )

    try {
        $imageRef = "${Repository}:${Tag}"
        Write-Host "Using docker manifest inspect for: $imageRef"

        $output = & docker manifest inspect $imageRef --verbose 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "docker manifest inspect failed: $output"
            return $null
        }

        # Parse the JSON output to get the digest
        $manifest = $output | ConvertFrom-Json
        if ($manifest.Descriptor -and $manifest.Descriptor.digest) {
            $digest = $manifest.Descriptor.digest
            Write-Host "Found digest via docker: $digest"
            return $digest
        }

        Write-Warning "Could not parse digest from docker manifest output"
        return $null
    } catch {
        Write-Warning "Error getting digest via docker: $($_.Exception.Message)"
        return $null
    }
}

# Main orchestrator function to find the best Cirrus Labs base image
function Find-BestCirrusLabsImage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$MacOSVersion,

        [string]$XcodeVersionRange,        # e.g., "[16.0,17.0)" or "[26.2,)"
        [string]$XcodeRecommendedVersion,  # e.g., "16.2" or "26.2"
        [switch]$IncludeDigest,
        [switch]$PreferHighest             # Prefer highest compatible instead of recommended
    )

    Write-Host ""
    Write-Host "Finding best Cirrus Labs image for macOS $MacOSVersion"
    Write-Host "  Xcode/SDK version range: $XcodeVersionRange"
    Write-Host "  Xcode/SDK recommended: $XcodeRecommendedVersion"

    # Get the version mapping for this macOS version
    $mapping = Get-CirrusLabsXcodeMapping -MacOSVersion $MacOSVersion
    if (-not $mapping) {
        throw "Unknown macOS version: $MacOSVersion"
    }

    # Detect versioning scheme: SDK versions (26.x) or Xcode versions (16.x)
    # If recommended version starts with the internal macOS version (26 for Tahoe), use direct comparison
    $useDirectComparison = $false
    if ($XcodeRecommendedVersion) {
        $recommendedMajor = [int]($XcodeRecommendedVersion -split '\.')[0]
        if ($recommendedMajor -eq $mapping.InternalVersion) {
            $useDirectComparison = $true
            Write-Host "  Detected SDK versioning scheme (26.x) - using direct tag comparison"
        } else {
            Write-Host "  Detected Xcode versioning scheme (16.x) - using version mapping"
        }
    }

    # Parse the version range
    $parsedRange = $null
    if ($XcodeVersionRange) {
        $parsedRange = Parse-NuGetVersionRange -VersionRange $XcodeVersionRange
    }

    # Get available tags from GHCR
    $availableTags = Get-CirrusLabsAvailableTags -MacOSVersion $MacOSVersion
    if ($availableTags.Count -eq 0) {
        throw "No Cirrus Labs images found for macOS $MacOSVersion"
    }

    # Build list of compatible versions
    $compatibleImages = @()
    foreach ($tag in $availableTags) {
        # Determine which version to use for comparison
        if ($useDirectComparison) {
            # SDK versioning: tag IS the version (26.2 = 26.2)
            $comparisonVersion = $tag
            $xcodeVersion = Convert-CirrusTagToXcodeVersion -Tag $tag -Mapping $mapping
        } else {
            # Xcode versioning: convert tag to Xcode version (26.2 -> 16.2)
            $xcodeVersion = Convert-CirrusTagToXcodeVersion -Tag $tag -Mapping $mapping
            $comparisonVersion = $xcodeVersion
        }

        # Parse version for comparison (handle single-component versions like "26")
        try {
            # Add .0 suffix if version has no minor component
            $versionToParse = if ($comparisonVersion -notmatch '\.') { "$comparisonVersion.0" } else { $comparisonVersion }
            $comparisonVersionObj = [Version]$versionToParse
        } catch {
            Write-Host "  Skipping tag '$tag' - cannot parse version '$comparisonVersion'"
            continue
        }

        # Check if within range (if range specified)
        $isCompatible = $true
        if ($parsedRange) {
            $isCompatible = Test-VersionInRange -Version $comparisonVersionObj -VersionRange $parsedRange
        }

        if ($isCompatible) {
            # Check if this is the recommended version
            $isRecommended = $false
            if ($useDirectComparison) {
                # Compare tag directly with recommended
                $isRecommended = ($tag -eq $XcodeRecommendedVersion) -or
                                ($tag -eq "$XcodeRecommendedVersion.0") -or
                                ("$tag.0" -eq $XcodeRecommendedVersion)
            } else {
                # Compare Xcode version with recommended
                $isRecommended = ($xcodeVersion -eq $XcodeRecommendedVersion) -or
                                ($xcodeVersion -eq "$XcodeRecommendedVersion.0") -or
                                ("$xcodeVersion.0" -eq $XcodeRecommendedVersion)
            }

            $compatibleImages += @{
                Tag = $tag
                XcodeVersion = $xcodeVersion
                ComparisonVersion = $comparisonVersion
                ComparisonVersionObj = $comparisonVersionObj
                IsRecommended = $isRecommended
            }
            Write-Host "  Compatible: tag '$tag' -> Xcode $xcodeVersion$(if ($isRecommended) { ' (RECOMMENDED)' })"
        }
    }

    if ($compatibleImages.Count -eq 0) {
        throw "No compatible Cirrus Labs images found for version range $XcodeVersionRange"
    }

    # Select the best image
    $selectedImage = $null

    if (-not $PreferHighest) {
        # First, try to find the recommended version
        $selectedImage = $compatibleImages | Where-Object { $_.IsRecommended } | Select-Object -First 1
    }

    if (-not $selectedImage) {
        # Fall back to highest compatible version
        $selectedImage = $compatibleImages | Sort-Object { $_.ComparisonVersionObj } -Descending | Select-Object -First 1
    }

    Write-Host ""
    Write-Host "Selected: tag '$($selectedImage.Tag)' -> Xcode $($selectedImage.XcodeVersion)"

    # Build result
    $result = @{
        Tag = $selectedImage.Tag
        XcodeVersion = $selectedImage.XcodeVersion
        IsRecommended = $selectedImage.IsRecommended
        IsCompatible = $true
        BaseImageUrl = "ghcr.io/cirruslabs/macos-$MacOSVersion-xcode:$($selectedImage.Tag)"
        MacOSVersion = $MacOSVersion
    }

    # Get digest if requested
    if ($IncludeDigest) {
        $digest = Get-CirrusLabsImageDigest -MacOSVersion $MacOSVersion -Tag $selectedImage.Tag
        if ($digest) {
            $result.Digest = $digest
            $result.PinnedImageUrl = "ghcr.io/cirruslabs/macos-$MacOSVersion-xcode@$digest"
        } else {
            Write-Warning "Could not retrieve digest for tag '$($selectedImage.Tag)'"
        }
    }

    return $result
}

# Function to get the latest version of an npm package
function Get-LatestNpmPackageVersion {
    param (
        [string]$PackageName
    )
    
    Write-Host "Getting latest version for npm package: $PackageName"
    
    try {
        # Use npm registry API to get package information
        $registryUrl = "https://registry.npmjs.org/$PackageName"
        $response = Invoke-RestMethod -Uri $registryUrl -Headers @{ "Accept" = "application/json" }
        
        # Get the latest version from the dist-tags
        $latestVersion = $response.'dist-tags'.latest
        
        if ($latestVersion) {
            Write-Host "Latest version of ${PackageName}: $latestVersion"
            return $latestVersion
        } else {
            Write-Warning "Could not find latest version for package: $PackageName"
            return $null
        }
    }
    catch {
        Write-Warning "Error getting npm package version for ${PackageName}: $($_.Exception.Message)"
        return $null
    }
}

# Function to get latest Appium-related package versions
function Get-LatestAppiumVersions {
    Write-Host "Getting latest Appium package versions from npm..."

    $appiumVersion = Get-LatestNpmPackageVersion -PackageName "appium"
    $uiAutomator2Version = Get-LatestNpmPackageVersion -PackageName "appium-uiautomator2-driver"

    return @{
        AppiumVersion = $appiumVersion
        UIAutomator2DriverVersion = $uiAutomator2Version
    }
}

function Get-LatestGitHubActionsRunnerVersion {
    Write-Host "Getting latest GitHub Actions runner version..."

    try {
        $apiUrl = "https://api.github.com/repos/actions/runner/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{
            "Accept" = "application/vnd.github+json"
            "User-Agent" = "maui-containers-build-script"
        }

        # Extract version number (remove 'v' prefix if present)
        $version = $response.tag_name -replace '^v', ''
        Write-Host "Found latest GitHub Actions runner version: $version"

        return $version
    }
    catch {
        Write-Warning "Failed to get latest GitHub Actions runner version: $_"
        Write-Warning "Falling back to default version: 2.323.0"
        return "2.323.0"
    }
}

#Get-NuGetPackageContent -PackageId 'Microsoft.NET.Workloads.9.0.300' -Version '9.301.1' -FilePath 'data/WorkloadManifest.json' 
