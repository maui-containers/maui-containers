function Invoke-MauiProvisioning {
    [CmdletBinding()]
    param(
        [string]$DotnetChannel = "10.0",
        [string]$WorkloadSetVersion = "",
        [string]$DotnetInstallDir,
        [string]$AndroidHome,
        [string]$LogDirectory,
        [switch]$SkipBrewUpdate,
        [switch]$SkipAndroid,
        [switch]$SkipIOS,
        [switch]$SkipTvOS,
        [switch]$DryRun
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    $platform = Get-Platform
    Write-Host "Running MAUI provisioning on $platform"

    # Platform-specific validations
    if (Test-IsMacOS) {
        # macOS-specific setup
    } elseif (Test-IsWindows) {
        # Windows-specific setup
        if (-not $SkipIOS -and -not $SkipTvOS) {
            Write-Warning "iOS and tvOS development is not supported on Windows. Use -SkipIOS and -SkipTvOS to suppress this warning."
            $SkipIOS = $true
            $SkipTvOS = $true
        }
    } elseif (Test-IsLinux) {
        # Linux-specific setup
        if (-not $SkipIOS -and -not $SkipTvOS) {
            Write-Warning "iOS and tvOS development is not supported on Linux. Use -SkipIOS and -SkipTvOS to suppress this warning."
            $SkipIOS = $true
            $SkipTvOS = $true
        }
    } else {
        throw "This provisioning routine supports Windows, macOS, and Linux only."
    }

    $isDryRun = $DryRun.IsPresent
    $userHome = [System.Environment]::GetFolderPath("UserProfile")
    $platformPaths = Get-PlatformPaths

    if (-not $DotnetInstallDir) {
        $DotnetInstallDir = $platformPaths.DotnetDefaultDir
    }
    if (-not $AndroidHome) {
        $AndroidHome = $platformPaths.AndroidDefaultHome
    }
    if (-not $LogDirectory) {
        $LogDirectory = $platformPaths.LogDefaultDir
    }

    $context = @{
        DryRun = $isDryRun
        DotnetInstallDir = $DotnetInstallDir
        AndroidHome = $AndroidHome
        LogDirectory = $LogDirectory
    }
    Set-ProvisionContext -Context $context

    # Platform-specific development tools check
    if (Test-IsMacOS) {
        if ($isDryRun) {
            Write-Host "[DryRun] Would verify Xcode command line tools availability"
        } else {
            $xcodePath = & xcode-select -p 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($xcodePath)) {
                Write-Warning "Xcode command line tools were not detected. Install them with 'xcode-select --install' before building iOS projects."
            }
        }
    } elseif (Test-IsWindows) {
        # Windows-specific checks (Visual Studio, etc.) could be added here
        Write-Host "Windows development environment detected"
    } elseif (Test-IsLinux) {
        # Linux-specific checks could be added here
        Write-Host "Linux development environment detected"
    }

    foreach ($path in @($DotnetInstallDir, $AndroidHome, $LogDirectory)) {
        if (-not (Test-Path $path)) {
            if ($isDryRun) {
                Write-Host "[DryRun] Would create directory: $path"
            } else {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
        }
    }

    $moduleRoot = Get-ModuleRoot
    $macosRoot = Split-Path -Parent $moduleRoot
    $commonFunctionsCandidate = [System.IO.Path]::Combine($macosRoot, "..", "common-functions.ps1")
    $commonFunctionsPath = [System.IO.Path]::GetFullPath($commonFunctionsCandidate)

    if (Test-Path $commonFunctionsPath) {
        . $commonFunctionsPath
    } else {
        throw "Unable to locate common-functions.ps1 at $commonFunctionsPath"
    }

    Write-Host "Resolving workload details for .NET channel $DotnetChannel"
    $workloadParams = @{
        DotnetVersion = $DotnetChannel
        WorkloadSetVersion = $WorkloadSetVersion
        IncludeAndroid = $true
        DockerPlatform = "linux/amd64"
    }
    if (-not $SkipIOS) {
        $workloadParams.IncludeIOS = $true
    }
    if (-not $SkipTvOS) {
        $workloadParams.IncludeTvOS = $true
    }

    $workloadInfo = Get-WorkloadInfo @workloadParams
    if (-not $workloadInfo) {
        throw "Failed to resolve workload metadata for .NET $DotnetChannel"
    }

    $androidWorkload = $workloadInfo.Workloads["Microsoft.NET.Sdk.Android"]
    $androidDetails = $androidWorkload.Details
    if (-not $androidDetails) {
        throw "Unable to determine Android workload details."
    }

    $iOSWorkload = $null
    $iOSDetails = $null
    $tvOsWorkload = $null
    $tvOsDetails = $null
    if (-not $SkipIOS) {
        if ($workloadInfo.Workloads.ContainsKey("Microsoft.NET.Sdk.iOS")) {
            $iOSWorkload = $workloadInfo.Workloads["Microsoft.NET.Sdk.iOS"]
            $iOSDetails = $iOSWorkload.Details
        }
    }
    if (-not $SkipTvOS) {
        if ($workloadInfo.Workloads.ContainsKey("Microsoft.NET.Sdk.tvOS")) {
            $tvOsWorkload = $workloadInfo.Workloads["Microsoft.NET.Sdk.tvOS"]
            $tvOsDetails = $tvOsWorkload.Details
        }
    }

    Write-Host "Provisioning .NET SDK channel: $DotnetChannel"
    Write-Host "Workload set version: $($workloadInfo.WorkloadSetVersion)"
    Write-Host "Workload CLI version: $($workloadInfo.DotnetCommandWorkloadSetVersion)"
    Write-Host "Android API level: $($androidDetails.ApiLevel)"
    Write-Host "Android build tools: $($androidDetails.BuildToolsVersion)"
    Write-Host "Android cmdline tools: $($androidDetails.CmdLineToolsVersion)"
    Write-Host "JDK major version: $($androidDetails.JdkMajorVersion)"
    if ($androidDetails.WorkloadJdkMajorVersion -and $androidDetails.WorkloadJdkMajorVersion -ne $androidDetails.JdkMajorVersion) {
        Write-Host "Workload JDK major version: $($androidDetails.WorkloadJdkMajorVersion) (using default minimum $($androidDetails.JdkMajorVersion))"
    }

    if ($iOSDetails) {
        Write-Host "Xcode recommended version: $($iOSDetails.XcodeRecommendedVersion)"
        Write-Host "Xcode version range: $($iOSDetails.XcodeVersionRange)"
        Write-Host "iOS SDK version: $($iOSDetails.IOSSdkVersion)"
    }

    # Ensure package manager is available
    if (-not (Ensure-PackageManager)) {
        throw "Required package manager not found or not supported on this platform."
    }

    if (-not $SkipBrewUpdate) {
        Update-PackageManager
    }

    # Platform-specific package manager setup
    if (Test-IsMacOS) {
        # homebrew/cask-versions was deprecated - no longer needed
    }

    # Install JDK using cross-platform approach
    $jdkMajor = $androidDetails.JdkMajorVersion
    $desiredJdkVersion = $null
    if ($androidDetails -and $androidDetails.PSObject.Properties.Match('JdkRecommendedVersion')) {
        $recommendedJdkVersion = $androidDetails.JdkRecommendedVersion
        if ($recommendedJdkVersion -match '^(\d+)') {
            $recommendedJdkMajor = [int]$Matches[1]
            if ($recommendedJdkMajor -eq [int]$jdkMajor) {
                $desiredJdkVersion = $recommendedJdkVersion
            } else {
                Write-Host "Skipping exact JDK recommendation $recommendedJdkVersion because effective JDK major version is $jdkMajor"
            }
        }
    }

    $jdkSuccess = Ensure-JavaDevelopmentKit -JdkMajorVersion $jdkMajor -RecommendedVersion $desiredJdkVersion
    if (-not $jdkSuccess) {
        Write-Warning "JDK installation failed, but continuing with other components"
    }

    # Provision Xcode if iOS workloads are enabled
    if (-not $SkipIOS -and $iOSDetails) {
        Write-Host "Provisioning Xcode for iOS development..."
        $xcodeRange = $iOSDetails.XcodeVersionRange
        $xcodeRecommended = $iOSDetails.XcodeRecommendedVersion
        if (-not $xcodeRecommended) {
            if ((-not $SkipTvOS) -and $tvOsDetails) {
                $xcodeRecommended = $tvOsDetails.XcodeRecommendedVersion
            }
        }
        if (-not $xcodeRange) {
            if ((-not $SkipTvOS) -and $tvOsDetails) {
                $xcodeRange = $tvOsDetails.XcodeVersionRange
            }
        }

        $xcodeSuccess = Ensure-XcodeVersion -RecommendedVersion $xcodeRecommended -VersionRange $xcodeRange
        if (-not $xcodeSuccess) {
            Write-Warning "Xcode provisioning failed, but continuing with other components"
        } else {
            $runtimeVersion = $iOSDetails.IOSSdkVersion
            if ($runtimeVersion) {
                $runtimeName = "iOS $runtimeVersion Simulator"
                $runtimeSuccess = Ensure-SimulatorRuntime -Platform 'iOS' -Version $runtimeVersion -DisplayName $runtimeName
                if (-not $runtimeSuccess) {
                    Write-Warning "Failed to ensure iOS simulator runtime $runtimeVersion"
                }
            } else {
                Write-Host "No recommended iOS simulator runtime version provided; skipping runtime installation"
            }

            if ((-not $SkipTvOS) -and $tvOsDetails -and $tvOsDetails.TvOsSdkVersion) {
                $tvRuntimeName = "tvOS $($tvOsDetails.TvOsSdkVersion) Simulator"
                $tvRuntimeSuccess = Ensure-SimulatorRuntime -Platform 'tvOS' -Version $tvOsDetails.TvOsSdkVersion -DisplayName $tvRuntimeName
                if (-not $tvRuntimeSuccess) {
                    Write-Warning "Failed to ensure tvOS simulator runtime $($tvOsDetails.TvOsSdkVersion)"
                }
            }
        }
    }

    $dotnetInstallScript = Join-Path $LogDirectory "dotnet-install.sh"
    if ($isDryRun) {
        Write-Host "[DryRun] Would download dotnet-install.sh to $dotnetInstallScript"
    } else {
        Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.sh" -OutFile $dotnetInstallScript
        Invoke-ExternalCommand -Command "chmod" -Arguments @("+x", $dotnetInstallScript)
    }

    $env:DOTNET_ROOT = $DotnetInstallDir
    Add-ToPath $DotnetInstallDir
    Add-ToPath (Join-Path $userHome ".dotnet/tools")

    $installedDotnetSdkVersions = Get-InstalledDotnetSdkVersions -InstallDir $DotnetInstallDir -Channel $DotnetChannel
    $dotnetSdkTargetVersion = $null

    if (-not $isDryRun) {
        try {
            $dryRunOutput = & bash $dotnetInstallScript --channel $DotnetChannel --install-dir $DotnetInstallDir --dry-run 2>$null
            if ($LASTEXITCODE -eq 0 -and $dryRunOutput) {
                foreach ($line in $dryRunOutput) {
                    if ($line -match 'Version\s*([0-9]+\.[0-9]+\.[0-9]+[^\s]*)') {
                        $dotnetSdkTargetVersion = $Matches[1]
                    }
                    if (-not $dotnetSdkTargetVersion -and $line -match 'version\s*([0-9]+\.[0-9]+\.[0-9]+[^\s]*)') {
                        $dotnetSdkTargetVersion = $Matches[1]
                    }
                }
            }
        } catch {
            Write-Warning "Failed to determine target .NET SDK version: $($_.Exception.Message)"
        }
    }

    $needsDotnetInstall = $true
    if ($installedDotnetSdkVersions -and $installedDotnetSdkVersions.Count -gt 0) {
        $needsDotnetInstall = $false
        if ($dotnetSdkTargetVersion) {
            if (-not ($installedDotnetSdkVersions -contains $dotnetSdkTargetVersion)) {
                Write-Host ".NET SDK version $dotnetSdkTargetVersion not found in $DotnetInstallDir"
                $needsDotnetInstall = $true
            }
        }
    }

    if ($needsDotnetInstall) {
        if ($isDryRun) {
            $targetText = if ($dotnetSdkTargetVersion) { $dotnetSdkTargetVersion } else { $DotnetChannel }
            Write-Host "[DryRun] Would install .NET SDK channel $DotnetChannel (target $targetText)"
        } else {
            & bash $dotnetInstallScript --channel $DotnetChannel --install-dir $DotnetInstallDir
            if ($LASTEXITCODE -ne 0) {
                throw "dotnet-install failed with exit code $LASTEXITCODE"
            }
        }
    } else {
        $installedVersionText = if ($dotnetSdkTargetVersion) { $dotnetSdkTargetVersion } elseif ($installedDotnetSdkVersions -and $installedDotnetSdkVersions.Count -gt 0) { $installedDotnetSdkVersions[0] } else { $DotnetChannel }
        Write-Host ".NET SDK $installedVersionText already installed"
    }

    $dotnetExecutable = Join-Path $DotnetInstallDir "dotnet"

    if ($isDryRun) {
        Write-Host "[DryRun] Would run '$dotnetExecutable --info' and capture output"
        $dotnetForChecks = if (Get-Command dotnet -ErrorAction SilentlyContinue) { "dotnet" } else { $dotnetExecutable }
    } elseif (Test-Path $dotnetExecutable) {
        & $dotnetExecutable --info | Tee-Object -FilePath (Join-Path $LogDirectory "dotnet-info.log") | Out-Null
        $dotnetForChecks = $dotnetExecutable
    } else {
        throw ".NET CLI was not found at $dotnetExecutable after installation"
    }

    $installedWorkloads = Get-InstalledDotnetWorkloads -DotnetPath $dotnetForChecks
    $requiredWorkloads = @("maui")
    if (-not $SkipAndroid) {
        $requiredWorkloads += @("android")
    }
    if (-not $SkipIOS -and $iOSDetails) {
        $requiredWorkloads += @("ios", "maccatalyst")
    }
    if (-not $SkipIOS) {
        $requiredWorkloads += @("macos")
    }
    if (-not $SkipTvOS -and $tvOsDetails) {
        $requiredWorkloads += @("tvos")
    }
    $requiredWorkloads += @("wasm-tools")
    $workloadsToInstall = @()

    foreach ($workloadId in $requiredWorkloads) {
        $isInstalled = $installedWorkloads.ContainsKey($workloadId)
        if ($isInstalled) {
            Write-Host ".NET workload '$workloadId' already installed"
        } else {
            $workloadsToInstall += $workloadId
        }
    }

    if ($workloadsToInstall.Count -gt 0) {
        if ($isDryRun) {
            Write-Host "[DryRun] Would install .NET workloads: $($workloadsToInstall -join ', ')"
        } else {
            & $dotnetExecutable workload install @workloadsToInstall --version $($workloadInfo.DotnetCommandWorkloadSetVersion)
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install .NET workloads: $($workloadsToInstall -join ', ')"
            }
        }
    } else {
        Write-Host "Required .NET workloads already installed"
    }

    $installedTools = Get-InstalledDotnetTools -DotnetPath $dotnetForChecks
    $requiredTools = @("AndroidSdk.Tool", "AppleDev.Tools")

    foreach ($toolId in $requiredTools) {
        if ($installedTools.ContainsKey($toolId)) {
            Write-Host "Dotnet tool '$toolId' already installed"
            continue
        }

        if ($isDryRun) {
            Write-Host "[DryRun] Would install dotnet tool $toolId"
            continue
        }

        & $dotnetExecutable tool install -g $toolId
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install dotnet tool $toolId"
        }
    }

    $dotnetToolPath = $platformPaths.DotnetToolsDir
    Add-ToPath $dotnetToolPath

    if (-not $SkipAndroid) {
        $androidHomeResolved = if ($isDryRun) { $AndroidHome } else { (Resolve-Path $AndroidHome).Path }
        $env:ANDROID_HOME = $androidHomeResolved
        $env:ANDROID_SDK_ROOT = $androidHomeResolved

        if ($isDryRun) {
            Write-Host "[DryRun] Would configure Android SDK at $AndroidHome"
        }

        $installedAndroidPackages = Get-AndroidInstalledPackages -AndroidHome $androidHomeResolved
        $androidChangesMade = $false

        $cmdlineToolsPath = Join-Path $androidHomeResolved "cmdline-tools"
        $downloadRequired = $isDryRun -or -not (Test-Path $cmdlineToolsPath)

        if ($downloadRequired) {
            if ($isDryRun) {
                Write-Host "[DryRun] Would download Android SDK components to $androidHomeResolved"
            } else {
                & "android" sdk download --home $androidHomeResolved
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to download Android SDK"
                }
                $androidChangesMade = $true
            }
        } else {
            Write-Host "Android SDK base components already present at $androidHomeResolved"
        }

        $androidPackagesToEnsure = @()
        if ($androidDetails.Packages) {
            $androidRequiredPackages = $androidDetails.Packages | Where-Object { -not $_.Optional } | ForEach-Object { $_.Id }
            $androidOptionalPackages = $androidDetails.Packages | Where-Object { $_.Optional } | ForEach-Object { $_.Id }

            if ($androidRequiredPackages.Count -gt 0) {
                Write-Host "Ensuring required Android SDK packages: $($androidRequiredPackages -join ', ')"
                $androidPackagesToEnsure += $androidRequiredPackages
            }

            if ($androidOptionalPackages.Count -gt 0) {
                Write-Host "Ensuring optional Android SDK packages: $($androidOptionalPackages -join ', ')"
                $androidPackagesToEnsure += $androidOptionalPackages
            }

            $androidPackagesToEnsure = $androidPackagesToEnsure | Where-Object { $_ } | Select-Object -Unique
        }

        if (-not $androidPackagesToEnsure -or $androidPackagesToEnsure.Count -eq 0) {
            $androidPackagesToEnsure = @(
                "platform-tools",
                "build-tools;$($androidDetails.BuildToolsVersion)",
                "cmdline-tools;$($androidDetails.CmdLineToolsVersion)",
                "platforms;android-$($androidDetails.ApiLevel)"
            )
            Write-Host "Android workload metadata missing package list; falling back to required defaults: $($androidPackagesToEnsure -join ', ')"
        }

        foreach ($packageId in $androidPackagesToEnsure) {
            Ensure-AndroidPackage -PackageId $packageId -InstalledPackages $installedAndroidPackages -ChangesMade ([ref]$androidChangesMade) -AndroidHome $androidHomeResolved
        }

        $licenseFile = Join-Path (Join-Path $androidHomeResolved "licenses") "android-sdk-license"
        $licensesAccepted = -not $isDryRun -and (Test-Path $licenseFile)

        if ($licensesAccepted) {
            Write-Host "Android SDK licenses already accepted"
        } elseif ($isDryRun) {
            Write-Host "[DryRun] Would accept Android SDK licenses"
        } else {
            & "android" sdk accept-licenses --force --home $androidHomeResolved
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to accept Android licenses"
            }
            $androidChangesMade = $true
        }

        if (-not $isDryRun) {
            & "android" sdk info --format json | Out-File -FilePath (Join-Path $LogDirectory "android-sdk-info.json")
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to capture Android SDK environment info"
            }

            & "android" sdk list --installed --format json | Out-File -FilePath (Join-Path $LogDirectory "android-sdk-installed.json")
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to capture installed Android SDK packages"
            }
        }
    }

    Write-Host "macOS MAUI provisioning completed successfully."
}
