
$buildArgs = @{
  DotNetVersion     = "10.0"
  Version           = "16091125574"
  DockerRepository  = "ghcr.io/maui-containers"
  DockerPlatform    = "linux/amd64"
  Load              = $true
}
if ("refs/heads/main" -eq "refs/heads/main") {
  $buildArgs.Push = $true
}
# Add workload set version if specified

$buildArgs.WorkloadSetVersion = "10.300.3"
./build.ps1 @buildArgs
