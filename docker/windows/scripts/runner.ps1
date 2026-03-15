# PowerShell script for combined GitHub and Gitea Actions runner management

function Write-Log {
    param([string]$Message)
    Write-Host "[runner] $Message"
}

Write-Log "MAUI Image - Runner initialization"

# Check for and execute initialization script if it exists
$initPwshPath = $env:INIT_PWSH_SCRIPT

if (Test-Path $initPwshPath) {
    Write-Log "Found initialization script at $initPwshPath, executing..."
    try {
        & $initPwshPath
        Write-Log "Initialization script executed successfully."
    } catch {
        Write-Log "Error executing initialization script: $_"
    }
}

# GitHub Actions Runner Configuration
$GITHUB_ORG = $env:GITHUB_ORG
$GITHUB_REPO = $env:GITHUB_REPO
$GITHUB_TOKEN = $env:GITHUB_TOKEN

# Gitea Actions Runner Configuration
$GITEA_INSTANCE_URL = $env:GITEA_INSTANCE_URL
$GITEA_RUNNER_TOKEN = $env:GITEA_RUNNER_TOKEN
$GITEA_RUNNER_NAME = $env:GITEA_RUNNER_NAME

# Determine which runners to start
$GITHUB_RUNNER_ENABLED = $false
$GITEA_RUNNER_ENABLED = $false

if (-not [string]::IsNullOrEmpty($GITHUB_ORG) -and -not [string]::IsNullOrEmpty($GITHUB_TOKEN)) {
    $GITHUB_RUNNER_ENABLED = $true
    Write-Log "GitHub Actions runner will be configured and started"
}

if (-not [string]::IsNullOrEmpty($GITEA_INSTANCE_URL) -and -not [string]::IsNullOrEmpty($GITEA_RUNNER_TOKEN)) {
    $GITEA_RUNNER_ENABLED = $true
    Write-Log "Gitea Actions runner will be configured and started"
}

if (-not $GITHUB_RUNNER_ENABLED -and -not $GITEA_RUNNER_ENABLED) {
    Write-Log "No runner credentials provided. Skipping runner configuration."
    Write-Log "To enable GitHub runner, set GITHUB_ORG and GITHUB_TOKEN"
    Write-Log "To enable Gitea runner, set GITEA_INSTANCE_URL and GITEA_RUNNER_TOKEN"
    Write-Log "Container will remain running for development use."
    # Exit - the container stays alive via the CMD
    return
}

# Function to configure and run GitHub Actions runner
function Start-GitHubRunner {
    Write-Log "Configuring GitHub Actions runner..."
    
    # Check if GitHub repo is specified and use the appropriate API endpoint
    if ([string]::IsNullOrEmpty($GITHUB_REPO)) {
        Write-Log "No repository specified, registering runner at organization level"
        $headers = @{
            Authorization = "Bearer $GITHUB_TOKEN"
            Accept = "application/vnd.github+json"
        }
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/orgs/$GITHUB_ORG/actions/runners/registration-token" -Method Post -Headers $headers
            $REG_TOKEN = $response.token
            $RUNNER_URL = "https://github.com/$GITHUB_ORG"
        } catch {
            Write-Log "ERROR: Failed to obtain GitHub registration token. Skipping GitHub runner."
            Write-Log "Error: $_"
            return $false
        }
    } else {
        Write-Log "Repository specified, registering runner at repository level"
        $headers = @{
            Authorization = "Bearer $GITHUB_TOKEN"
            Accept = "application/vnd.github+json"
        }
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/actions/runners/registration-token" -Method Post -Headers $headers
            $REG_TOKEN = $response.token
            $RUNNER_URL = "https://github.com/$GITHUB_ORG/$GITHUB_REPO"
        } catch {
            Write-Log "ERROR: Failed to obtain GitHub registration token. Skipping GitHub runner."
            Write-Log "Error: $_"
            return $false
        }
    }

    if ([string]::IsNullOrEmpty($REG_TOKEN)) {
        Write-Log "ERROR: Failed to obtain registration token."
        return $false
    }

    Set-Location -Path "C:\actions-runner"

    # Clean up any pre-existing runner configuration to prevent stale token errors
    # This allows the runner to work correctly across container restarts
    if ((Test-Path ".runner") -or (Test-Path ".credentials") -or (Test-Path ".credentials_rsaparams")) {
        Write-Log "Cleaning up pre-existing GitHub runner configuration"
        Remove-Item -Path ".runner", ".credentials", ".credentials_rsaparams" -ErrorAction SilentlyContinue -Force
        Write-Log "Old GitHub configuration removed"
    }

    # Create .env file with Android SDK environment variables
    # This ensures ANDROID_HOME is available to all runner jobs
    Write-Log "Creating .env file with ANDROID_HOME environment variable"
    $envContent = @"
ANDROID_HOME=$env:ANDROID_HOME
ANDROID_SDK_HOME=$env:ANDROID_SDK_HOME
ANDROID_SDK_ROOT=$env:ANDROID_HOME
"@
    Set-Content -Path ".env" -Value $envContent
    Write-Log ".env file created with ANDROID_HOME=$env:ANDROID_HOME"

    # Set runner name with appropriate suffix
    $RANDOM_RUNNER_SUFFIX = if ($env:RANDOM_RUNNER_SUFFIX) { $env:RANDOM_RUNNER_SUFFIX } else { "true" }
    $RUNNER_NAME_PREFIX = if ($env:RUNNER_NAME_PREFIX) { $env:RUNNER_NAME_PREFIX } else { "github-runner" }

    if ($env:RUNNER_NAME) {
        $_RUNNER_NAME = $env:RUNNER_NAME
    } else {
        if ($RANDOM_RUNNER_SUFFIX -ne "true") {
            if (Test-Path -Path "C:\Windows\System32\hostname.exe") {
                $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(hostname)"
                Write-Log "RANDOM_RUNNER_SUFFIX is $RANDOM_RUNNER_SUFFIX. Using hostname for runner name: $_RUNNER_NAME"
            } else {
                $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(New-Guid | Select-Object -ExpandProperty Guid)"
                Write-Log "RANDOM_RUNNER_SUFFIX is $RANDOM_RUNNER_SUFFIX but hostname command not available. Using random GUID."
            }
        } else {
            $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(New-Guid | Select-Object -ExpandProperty Guid)"
        }
    }

    $_RUNNER_WORKDIR = if ($env:RUNNER_WORKDIR) { $env:RUNNER_WORKDIR } else { "C:\actions-runner\_work\$_RUNNER_NAME" }
    $_LABELS = if ($env:LABELS) { $env:LABELS } else { "default" }
    $_RUNNER_GROUP = if ($env:RUNNER_GROUP) { $env:RUNNER_GROUP } else { "Default" }

    $configArgs = @(
        "--url", $RUNNER_URL,
        "--token", $REG_TOKEN,
        "--name", $_RUNNER_NAME,
        "--work", $_RUNNER_WORKDIR,
        "--labels", $_LABELS,
        "--runnergroup", $_RUNNER_GROUP,
        "--unattended",
        "--replace"
    )

    if ($env:EPHEMERAL) {
        Write-Log "Ephemeral option is enabled"
        $configArgs += "--ephemeral"
        # Auto-disable updates for ephemeral runners unless explicitly overridden
        if (-not $env:DISABLE_AUTO_UPDATE) {
            Write-Log "Auto-disabling updates for ephemeral runner"
            $env:DISABLE_AUTO_UPDATE = "true"
        }
    }

    if ($env:DISABLE_AUTO_UPDATE) {
        Write-Log "Disable auto update option is enabled"
        $configArgs += "--disableupdate"
    }

    if ($env:NO_DEFAULT_LABELS) {
        Write-Log "Disable adding the default self-hosted, platform, and architecture labels"
        $configArgs += "--no-default-labels"
    }

    if (-not (Test-Path -Path $_RUNNER_WORKDIR)) {
        New-Item -Path $_RUNNER_WORKDIR -ItemType Directory -Force | Out-Null
    }

    Write-Log "Configuring GitHub runner '$_RUNNER_NAME'"
    & .\config.cmd @configArgs

    $script:GitHubCleanupToken = $REG_TOKEN
    
    Write-Log "Starting GitHub Actions runner"
    & .\run.cmd
}

# Function to configure and run Gitea Actions runner
function Start-GiteaRunner {
    Write-Log "Configuring Gitea Actions runner..."
    
    Set-Location -Path "C:\gitea-runner"

    # Generate runner name if not provided
    $RANDOM_RUNNER_SUFFIX = if ($env:RANDOM_RUNNER_SUFFIX) { $env:RANDOM_RUNNER_SUFFIX } else { "true" }
    $RUNNER_NAME_PREFIX = if ($env:GITEA_RUNNER_NAME_PREFIX) { $env:GITEA_RUNNER_NAME_PREFIX } else { "gitea-runner" }

    if ([string]::IsNullOrEmpty($GITEA_RUNNER_NAME)) {
        if ($RANDOM_RUNNER_SUFFIX -ne "true") {
            if (Test-Path -Path "C:\Windows\System32\hostname.exe") {
                $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(hostname)"
                Write-Log "RANDOM_RUNNER_SUFFIX is $RANDOM_RUNNER_SUFFIX. Using hostname for runner name: $_RUNNER_NAME"
            } else {
                $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(New-Guid | Select-Object -ExpandProperty Guid)"
                Write-Log "RANDOM_RUNNER_SUFFIX is $RANDOM_RUNNER_SUFFIX but hostname command not available. Using random GUID."
            }
        } else {
            $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(New-Guid | Select-Object -ExpandProperty Guid)"
        }
    } else {
        $_RUNNER_NAME = $GITEA_RUNNER_NAME
    }

    $_LABELS = if ($env:GITEA_RUNNER_LABELS) { $env:GITEA_RUNNER_LABELS } else { "maui,windows,amd64" }

    # Clean up any pre-existing runner configuration to prevent stale token errors
    # This allows the runner to work correctly across container restarts
    if (Test-Path -Path ".runner") {
        Write-Log "Cleaning up pre-existing Gitea runner configuration"
        Remove-Item -Path ".runner" -ErrorAction SilentlyContinue -Force
        Write-Log "Old Gitea configuration removed"
    }

    # Create .env file with Android SDK environment variables
    # This ensures ANDROID_HOME is available to all runner jobs
    Write-Log "Creating .env file with ANDROID_HOME environment variable"
    $envContent = @"
ANDROID_HOME=$env:ANDROID_HOME
ANDROID_SDK_HOME=$env:ANDROID_SDK_HOME
ANDROID_SDK_ROOT=$env:ANDROID_HOME
"@
    Set-Content -Path ".env" -Value $envContent
    Write-Log ".env file created with ANDROID_HOME=$env:ANDROID_HOME"

    Write-Log "Registering Gitea runner: $_RUNNER_NAME"
    Write-Log "Labels: $_LABELS"

    # Register the runner (always, since we clean up above)
    Write-Log "Registering runner with Gitea..."

    $registerArgs = @(
        "register",
        "--instance", $GITEA_INSTANCE_URL,
        "--token", $GITEA_RUNNER_TOKEN,
        "--name", $_RUNNER_NAME,
        "--labels", $_LABELS,
        "--no-interactive"
    )

    & .\act_runner.exe @registerArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: Failed to register runner with Gitea. Skipping Gitea runner."
        return $false
    }

    Write-Log "Runner registered successfully"

    Write-Log "Starting Gitea runner daemon..."
    & .\act_runner.exe daemon
}

# Cleanup function
function Invoke-Cleanup {
    Write-Log "Cleaning up runners..."
    
    if ($script:GitHubCleanupToken) {
        try {
            Set-Location -Path "C:\actions-runner"
            & .\config.cmd remove --token $script:GitHubCleanupToken
        } catch {
            Write-Log "Error during GitHub runner cleanup: $_"
        }
    }
    
    Write-Log "Cleanup complete"
}

# Set up cleanup on script termination
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Invoke-Cleanup } -SupportEvent

# Trap Ctrl+C
[Console]::TreatControlCAsInput = $true
$timer = New-Object System.Timers.Timer
$timer.Interval = 1000
$timer.Start()
Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "C" -and $key.Modifiers -eq "Control") {
            Write-Log "Ctrl+C pressed, cleaning up..."
            Invoke-Cleanup
            exit 130
        }
    }
} | Out-Null

# Start runners based on configuration
if ($GITHUB_RUNNER_ENABLED -and $GITEA_RUNNER_ENABLED) {
    Write-Log "Both GitHub and Gitea runners are enabled. Starting both..."
    
    # Start GitHub runner in background job
    $githubJob = Start-Job -ScriptBlock ${function:Start-GitHubRunner}
    
    # Start Gitea runner in background job
    $giteaJob = Start-Job -ScriptBlock ${function:Start-GiteaRunner}
    
    # Wait for both jobs and display output
    Write-Log "Waiting for runners to complete..."
    $githubJob, $giteaJob | Wait-Job | Receive-Job
    
} elseif ($GITHUB_RUNNER_ENABLED) {
    Start-GitHubRunner
    
} elseif ($GITEA_RUNNER_ENABLED) {
    Start-GiteaRunner
}

Write-Log "Runner(s) stopped"
