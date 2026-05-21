Param([String]$DotnetVersion="10.0",
    [String]$WorkloadSetVersion="",
    [String]$DockerRepository="ghcr.io/maui-containers",
    [String]$Version="latest",
    [switch]$Load,
    [switch]$Push) 

# Use a more reliable method to import the common functions module
# This handles paths with spaces better and is more explicit
$buildPath = Join-Path -Path $PSScriptRoot -ChildPath "..\build.ps1" -Resolve -ErrorAction SilentlyContinue
. $buildPath -DotnetVersion $DotnetVersion `
    -WorkloadSetVersion $WorkloadSetVersion `
    -DockerRepository $DockerRepository `
    -DockerPlatform "windows/amd64" `
    -Version $Version `
    -Push $Push
