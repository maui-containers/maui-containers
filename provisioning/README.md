# MAUI Host Provisioning

The `provision.ps1` script bootstraps a developer workstation with the same tooling that ships in the Docker base images. It primarily targets macOS hosts (installing .NET, Android, and Apple tooling) but the module scaffolding also sets the stage for Windows and Linux support.

## Prerequisites
- macOS 13 or newer with administrative privileges for Homebrew cask installs
- [Homebrew](https://brew.sh) installed and available on the `PATH`
- Xcode command line tools (`xcode-select --install`) for iOS builds
- PowerShell 7 (`brew install powershell`) to run the script

## Usage
```powershell
pwsh ./provisioning/provision.ps1 -DotnetChannel 9.0
```

Key parameters:
- `-DotnetChannel` (default `9.0`): .NET channel to install. The script resolves the matching workload set automatically.
- `-WorkloadSetVersion`: Pin to a specific workload set version if you do not want the latest published value.
- `-DotnetInstallDir`: Override where the .NET SDK is laid down. Defaults to `~/.dotnet`.
- `-AndroidHome`: Override where Android SDK components are stored. Defaults to `~/Library/Android/sdk`.
- `-SkipBrewUpdate`: Skip `brew update` when you know taps are current.
- `-SkipAndroid`: Bypass Android SDK installation when you only need .NET tooling.
- `-SkipIOS`: Skip Xcode, iOS, macOS catalyst workloads, and their simulators when not targeting Apple mobile/Desktop workloads.
- `-SkipTvOS`: Skip tvOS simulator provisioning while still configuring other Apple workloads.
- `-DryRun`: Print the actions without executing them.

The script inspects existing installations and only installs or upgrades components when the requested version is missing, so repeated executions stay fast.

## PowerShell Module Layout
The automation lives in the `MauiProvisioning` module under `provisioning/`. The module follows the standard `Public/` and `Private/` folder pattern so you can reuse the functions in other scripts:

```powershell
Import-Module ./provisioning/MauiProvisioning/MauiProvisioning.psd1
Invoke-MauiProvisioning -DotnetChannel 9.0 -DryRun
```

`Invoke-MauiProvisioning` is the public entry point used by `provision.ps1`; helper functions such as `Ensure-BrewTap` and `Get-AndroidInstalledPackages` live in the `Private/` folder for easier maintenance.

## Installed Components
- Latest .NET SDK for the specified channel using `dotnet-install`
- Workload set aligned MAUI workloads (`maui`, `wasm-tools`)
- Android SDK command line packages: platform-tools, build-tools, cmdline-tools, and the target platform API
- Microsoft OpenJDK (`microsoft-openjdk@17` cask by default)
- `AndroidSdk.Tool` and `AppleDev.Tools` dotnet global tools
- Recommended Xcode version and matching iOS/tvOS simulator runtimes (installed via `xcodes`)
- Accepted Android SDK licenses plus `android-sdk-info.json` and `android-sdk-installed.json` logs under `~/Library/Logs/maui-macos-provisioning`

## Post-Setup
The script updates the current session `PATH` so that `dotnet` and the `android` CLI are available immediately. To make the change permanent, add the following to your shell profile:

```sh
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
```

## Validation
After provisioning, run a quick smoke test:
```powershell
pwsh ./docker/test/build.ps1 -AndroidSdkApiLevel 35 -Load
pwsh ./docker/test/run.ps1 -AndroidSdkApiLevel 35
```
Confirm `dotnet --info`, `android sdk list --installed`, and `xcodebuild -version` all succeed.
