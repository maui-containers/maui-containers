# Initialization script for MAUI development environment
Write-Host "MAUI Image - Windows"
Write-Host "===================="

Write-Host "Initialization complete."
Write-Host "This is a MAUI development image with .NET $($env:DOTNET_VERSION), Android SDK, and Java $($env:JDK_MAJOR_VERSION)"
Write-Host "You can now run your MAUI Android development tasks."
Write-Host ""
Write-Host "This image includes GitHub Actions and Gitea Actions runner capabilities."
Write-Host "To enable runners, set the appropriate environment variables:"
Write-Host "  - GitHub: GITHUB_ORG and GITHUB_TOKEN"
Write-Host "  - Gitea: GITEA_INSTANCE_URL and GITEA_RUNNER_TOKEN"
Write-Host ""

# Start the runner script which handles both GitHub and Gitea runners
# The runner script will also execute any custom initialization scripts
& C:\runner.ps1
