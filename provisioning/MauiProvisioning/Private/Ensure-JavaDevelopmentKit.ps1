function Ensure-JavaDevelopmentKit {
    param(
        [Parameter(Mandatory=$true)]
        [int]$JdkMajorVersion,
        [string]$RecommendedVersion = $null
    )

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun
    $platform = Get-Platform
    $platformPaths = Get-PlatformPaths

    Write-Host "Ensuring JDK $JdkMajorVersion is installed..."

    switch ($platform) {
        "macOS" {
            return Ensure-MacOSJdk -JdkMajorVersion $JdkMajorVersion -RecommendedVersion $RecommendedVersion
        }
        "Windows" {
            return Ensure-WindowsJdk -JdkMajorVersion $JdkMajorVersion -RecommendedVersion $RecommendedVersion
        }
        "Linux" {
            return Ensure-LinuxJdk -JdkMajorVersion $JdkMajorVersion -RecommendedVersion $RecommendedVersion
        }
        default {
            Write-Warning "JDK installation not implemented for platform: $platform"
            return $false
        }
    }
}

function Ensure-MacOSJdk {
    param(
        [int]$JdkMajorVersion,
        [string]$RecommendedVersion
    )

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun

    $microsoftOpenJdkCask = "microsoft-openjdk@$JdkMajorVersion"
    $installedJdkVersion = Get-InstalledBrewCaskVersion -Cask $microsoftOpenJdkCask
    $jdkInstallAction = "install"

    if ($installedJdkVersion) {
        Write-Host "Detected Microsoft OpenJDK $installedJdkVersion already installed"
        $jdkInstallAction = "none"

        if ($RecommendedVersion) {
            $installedVersionObj = Convert-ToVersionOrNull $installedJdkVersion
            $desiredVersionObj = Convert-ToVersionOrNull $RecommendedVersion

            if ($installedVersionObj -and $desiredVersionObj) {
                if ($installedVersionObj -ne $desiredVersionObj) {
                    Write-Host "Installed JDK version differs from recommended $RecommendedVersion"
                    $jdkInstallAction = "upgrade"
                }
            } elseif ($installedJdkVersion -ne $RecommendedVersion) {
                Write-Host "Installed JDK version '$installedJdkVersion' differs from recommended '$RecommendedVersion'"
                $jdkInstallAction = "upgrade"
            }
        }
    } else {
        Write-Host "Microsoft OpenJDK cask not found. Will install $microsoftOpenJdkCask"
    }

    switch ($jdkInstallAction) {
        "install" {
            if ($isDryRun) {
                Write-Host "[DryRun] Would install Microsoft OpenJDK cask $microsoftOpenJdkCask"
            } else {
                Invoke-ExternalCommand -Command "brew" -Arguments @("install", "--cask", $microsoftOpenJdkCask)
            }
        }
        "upgrade" {
            if ($isDryRun) {
                Write-Host "[DryRun] Would upgrade Microsoft OpenJDK cask $microsoftOpenJdkCask"
            } else {
                Invoke-ExternalCommand -Command "brew" -Arguments @("upgrade", "--cask", $microsoftOpenJdkCask)
            }
        }
        Default {
            Write-Host "Microsoft OpenJDK already matches the desired configuration"
        }
    }

    # Set JAVA_HOME
    if (-not $isDryRun) {
        $javaHome = & /usr/libexec/java_home -v $JdkMajorVersion
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($javaHome)) {
            throw "Failed to resolve JAVA_HOME for JDK $JdkMajorVersion"
        }
        $env:JAVA_HOME = $javaHome.Trim()
        Add-ToPath (Join-Path $env:JAVA_HOME "bin")
    }

    return $true
}

function Ensure-WindowsJdk {
    param(
        [int]$JdkMajorVersion,
        [string]$RecommendedVersion
    )

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun
    $platformPaths = Get-PlatformPaths

    # Check if JDK is already installed
    $javaHome = $env:JAVA_HOME
    if (-not $javaHome) {
        # Try to find Java installation
        $javaCmd = Get-Command java -ErrorAction SilentlyContinue
        if ($javaCmd) {
            $javaVersion = & java -version 2>&1 | Select-String "version" | Select-Object -First 1
            if ($javaVersion -and $javaVersion -match "version `"([^`"]+)`"") {
                $versionString = $Matches[1]
                if ($versionString -match "^$JdkMajorVersion\.") {
                    Write-Host "JDK $JdkMajorVersion already installed and available in PATH"
                    return $true
                }
            }
        }
    }

    if ($isDryRun) {
        Write-Host "[DryRun] Would install Microsoft OpenJDK $JdkMajorVersion using $($platformPaths.PackageManager)"
        return $true
    }

    # Install using package manager
    switch ($platformPaths.PackageManager) {
        "choco" {
            $specificPackageName = "microsoft-openjdk$JdkMajorVersion"
            $specificPackage = & choco search $specificPackageName --exact --limit-output
            if ($specificPackage | Where-Object { $_.StartsWith($specificPackageName + '|') } | Select-Object -First 1) {
                Invoke-ExternalCommand -Command "choco" -Arguments ($platformPaths.PackageManagerInstallCmd + $specificPackageName)
                break
            }

            $genericPackageName = "microsoft-openjdk"
            $matchingPackageVersion = & choco search $genericPackageName --exact --all-versions --limit-output |
                ForEach-Object {
                    $packageParts = $_.Split('|')
                    if ($packageParts.Length -eq 2 -and $packageParts[0] -eq $genericPackageName -and $packageParts[1].StartsWith("$JdkMajorVersion.")) {
                        $packageParts[1]
                    }
                } |
                Sort-Object { [version]$_ } -Descending |
                Select-Object -First 1

            if (-not $matchingPackageVersion) {
                throw "Could not find Microsoft OpenJDK Chocolatey package version for JDK $JdkMajorVersion"
            }

            Invoke-ExternalCommand -Command "choco" -Arguments ($platformPaths.PackageManagerInstallCmd + $genericPackageName + "--version=$matchingPackageVersion")
        }
        "winget" {
            $packageName = "Microsoft.OpenJDK.$JdkMajorVersion"
            Invoke-ExternalCommand -Command "winget" -Arguments ($platformPaths.PackageManagerInstallCmd + $packageName)
        }
        default {
            Write-Warning "Unsupported package manager for Windows JDK installation: $($platformPaths.PackageManager)"
            return $false
        }
    }

    # Try to set JAVA_HOME
    $possibleJavaHomes = @(
        "${env:ProgramFiles}\Microsoft\jdk-$JdkMajorVersion*",
        "${env:ProgramFiles(x86)}\Microsoft\jdk-$JdkMajorVersion*"
    )

    foreach ($pattern in $possibleJavaHomes) {
        $javaDirs = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        if ($javaDirs) {
            $env:JAVA_HOME = $javaDirs[0].FullName
            Add-ToPath (Join-Path $env:JAVA_HOME "bin")
            Write-Host "Set JAVA_HOME to $($env:JAVA_HOME)"
            return $true
        }
    }

    Write-Warning "Could not automatically set JAVA_HOME after JDK installation"
    return $false
}

function Ensure-LinuxJdk {
    param(
        [int]$JdkMajorVersion,
        [string]$RecommendedVersion
    )

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun
    $platformPaths = Get-PlatformPaths

    # Check if JDK is already installed
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) {
        $javaVersion = & java -version 2>&1 | Select-String "version" | Select-Object -First 1
        if ($javaVersion -and $javaVersion -match "version `"([^`"]+)`"") {
            $versionString = $Matches[1]
            if ($versionString -match "^$JdkMajorVersion\.") {
                Write-Host "JDK $JdkMajorVersion already installed and available in PATH"
                return $true
            }
        }
    }

    if ($isDryRun) {
        Write-Host "[DryRun] Would install OpenJDK $JdkMajorVersion using $($platformPaths.PackageManager)"
        return $true
    }

    # Install using package manager
    switch ($platformPaths.PackageManager) {
        "apt" {
            $packageName = "openjdk-$JdkMajorVersion-jdk"
            Invoke-ExternalCommand -Command "sudo" -Arguments (@("apt") + $platformPaths.PackageManagerInstallCmd + $packageName)
        }
        "dnf" {
            $packageName = "java-$JdkMajorVersion-openjdk-devel"
            Invoke-ExternalCommand -Command "sudo" -Arguments (@("dnf") + $platformPaths.PackageManagerInstallCmd + $packageName)
        }
        "yum" {
            $packageName = "java-$JdkMajorVersion-openjdk-devel"
            Invoke-ExternalCommand -Command "sudo" -Arguments (@("yum") + $platformPaths.PackageManagerInstallCmd + $packageName)
        }
        "pacman" {
            $packageName = "jdk$JdkMajorVersion-openjdk"
            Invoke-ExternalCommand -Command "sudo" -Arguments (@("pacman") + $platformPaths.PackageManagerInstallCmd + $packageName)
        }
        default {
            Write-Warning "Unsupported package manager for Linux JDK installation: $($platformPaths.PackageManager)"
            return $false
        }
    }

    # Try to set JAVA_HOME
    $possibleJavaHomes = @(
        "/usr/lib/jvm/java-$JdkMajorVersion-openjdk*",
        "/usr/lib/jvm/jdk-$JdkMajorVersion*"
    )

    foreach ($pattern in $possibleJavaHomes) {
        $javaDirs = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        if ($javaDirs) {
            $env:JAVA_HOME = $javaDirs[0].FullName
            Add-ToPath (Join-Path $env:JAVA_HOME "bin")
            Write-Host "Set JAVA_HOME to $($env:JAVA_HOME)"
            return $true
        }
    }

    Write-Warning "Could not automatically set JAVA_HOME after JDK installation"
    return $false
}
