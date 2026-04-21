Param(
    [String]$AndroidSdkApiLevel = 35,
    [String]$DotnetVersion = "9.0",
    [String]$DockerRepository = "maui-containers/maui-emulator-linux",
    [String]$AdbKeyFolder = "$env:USERPROFILE/.android",
    [Int]$AdbPortMapping = 5555,
    [Int]$EmulatorPortMapping = 5554,
    [Int]$GrpcPortMapping = 8554,
    [Int]$AppiumPortMapping = 4723,
    [switch]$BindAdbKeys,
    # Runtime configuration environment variables
    [Int]$EmulatorBootTimeout = 0,
    [String]$EmulatorSnapshotMode = "",
    [switch]$NoWipeData,
    [switch]$DisableAnimations,
    [switch]$DisableSpellchecker,
    [switch]$EnableHwKeyboard,
    [String]$EmulatorExtraArgs = "",
    [String]$AvdName = ""
)

$runArgs = @(
    "run", "-d",
    "--device", "/dev/kvm",
    "-p", "${AdbPortMapping}:5555/tcp",
    "-p", "${EmulatorPortMapping}:5554/tcp",
    "-p", "${GrpcPortMapping}:8554/tcp",
    "-p", "${AppiumPortMapping}:4723/tcp"
)

if ($BindAdbKeys) {
    $runArgs += "--mount", "type=bind,src=${AdbKeyFolder}/adbkey,dst=/home/mauiusr/.android/adbkey,readonly"
    $runArgs += "--mount", "type=bind,src=${AdbKeyFolder}/adbkey.pub,dst=/home/mauiusr/.android/adbkey.pub,readonly"
}

# Pass runtime config as environment variables (only when explicitly set)
if ($EmulatorBootTimeout -gt 0) {
    $runArgs += "-e", "EMULATOR_BOOT_TIMEOUT=$EmulatorBootTimeout"
}
if ($EmulatorSnapshotMode -ne "") {
    $runArgs += "-e", "EMULATOR_SNAPSHOT_MODE=$EmulatorSnapshotMode"
}
if ($NoWipeData) {
    $runArgs += "-e", "EMULATOR_WIPE_DATA=false"
}
if ($DisableAnimations) {
    $runArgs += "-e", "DISABLE_ANIMATIONS=true"
}
if ($DisableSpellchecker) {
    $runArgs += "-e", "DISABLE_SPELLCHECKER=true"
}
if ($EnableHwKeyboard) {
    $runArgs += "-e", "ENABLE_HW_KEYBOARD=true"
}
if ($EmulatorExtraArgs -ne "") {
    $runArgs += "-e", "EMULATOR_EXTRA_ARGS=$EmulatorExtraArgs"
}
if ($AvdName -ne "") {
    $runArgs += "-e", "AVD_NAME=$AvdName"
}

$imageTag = "${DockerRepository}:android${AndroidSdkApiLevel}-dotnet${DotnetVersion}"
$runArgs += $imageTag

Write-Host "Starting emulator container: docker $($runArgs -join ' ')"
& docker $runArgs