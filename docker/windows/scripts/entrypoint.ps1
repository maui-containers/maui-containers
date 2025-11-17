# Entrypoint script for MAUI Windows container
# Starts runners in background, then executes the CMD

$ErrorActionPreference = 'Stop'

Write-Host "MAUI Image - Windows Container"
Write-Host "==============================="

# Run custom init script if provided
if (Test-Path $env:INIT_PWSH_SCRIPT) {
    Write-Host "Running custom PowerShell init script: $($env:INIT_PWSH_SCRIPT)"
    & $env:INIT_PWSH_SCRIPT
}

# Start runner script in background job
Write-Host "Starting runner management in background..."
Start-Job -ScriptBlock {
    & C:\runner.ps1
} | Out-Null

# Execute whatever CMD was provided (or default)
Write-Host "Executing CMD: $args"
if ($args.Count -gt 0) {
    & $args[0] $args[1..($args.Count-1)]
} else {
    # Default: keep container alive
    Write-Host "No CMD provided, keeping container alive..."
    while ($true) {
        Start-Sleep -Seconds 30
    }
}
