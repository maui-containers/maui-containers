Param(
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

$moduleDirectory = Join-Path $PSScriptRoot "MauiProvisioning"
$moduleManifest = Join-Path $moduleDirectory "MauiProvisioning.psd1"

if (-not (Test-Path $moduleManifest)) {
    throw "Failed to locate MauiProvisioning module manifest at $moduleManifest"
}

Import-Module $moduleManifest -Force

Invoke-MauiProvisioning @PSBoundParameters
