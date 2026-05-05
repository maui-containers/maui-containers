#!/usr/bin/env bash
set -euo pipefail

# Script to generate software manifest for MAUI Tart VM images
# Generates a stable inventory of installed tools and versions

OUTPUT_FILE="${1:-/usr/local/share/installed-software.md}"
TEMP_FILE=$(mktemp)

echo "Generating software manifest..."

# Header
cat > "${TEMP_FILE}" << 'EOF'
# MAUI Development VM - Installed Software

This document describes the software and tools installed on the MAUI development VM image.

## Operating System

EOF

# OS Information
echo "- **macOS Version:** $(sw_vers -productVersion) ($(sw_vers -buildVersion))" >> "${TEMP_FILE}"
echo "- **Kernel Version:** $(uname -r)" >> "${TEMP_FILE}"
echo "- **Architecture:** $(uname -m)" >> "${TEMP_FILE}"
echo "- **Image Build Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "${TEMP_FILE}"
echo "" >> "${TEMP_FILE}"

# Xcode
cat >> "${TEMP_FILE}" << 'EOF'
## Xcode

EOF

if command -v xcodebuild >/dev/null 2>&1; then
  echo "### Default Xcode" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  xcodebuild -version >> "${TEMP_FILE}" 2>/dev/null || echo "Xcode information unavailable" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"

  # All installed Xcode versions
  if command -v xcodes >/dev/null 2>&1; then
    echo "### All Installed Xcode Versions" >> "${TEMP_FILE}"
    echo '```' >> "${TEMP_FILE}"
    xcodes installed 2>/dev/null || echo "xcodes CLI unavailable" >> "${TEMP_FILE}"
    echo '```' >> "${TEMP_FILE}"
    echo "" >> "${TEMP_FILE}"
  fi

  # SDKs
  echo "### Xcode SDKs" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  xcodebuild -showsdks 2>/dev/null | head -20 >> "${TEMP_FILE}" || echo "SDK information unavailable" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
fi

# .NET
cat >> "${TEMP_FILE}" << 'EOF'
## .NET

EOF

if command -v dotnet >/dev/null 2>&1; then
  echo "### .NET SDK" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  dotnet --version >> "${TEMP_FILE}" 2>/dev/null || echo ".NET SDK unavailable" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"

  echo "### .NET SDKs Installed" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  dotnet --list-sdks 2>/dev/null >> "${TEMP_FILE}" || echo "No SDKs found" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"

  echo "### .NET Runtimes Installed" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  dotnet --list-runtimes 2>/dev/null >> "${TEMP_FILE}" || echo "No runtimes found" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"

  echo "### .NET Workloads" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  dotnet workload list 2>/dev/null >> "${TEMP_FILE}" || echo "No workloads installed" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"

  echo "### .NET Global Tools" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  dotnet tool list -g 2>/dev/null >> "${TEMP_FILE}" || echo "No global tools installed" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
fi

# Android SDK
cat >> "${TEMP_FILE}" << 'EOF'
## Android

EOF

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [[ -d "${ANDROID_HOME}" ]]; then
  echo "**Android SDK Root:** \`${ANDROID_HOME}\`" >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"

  if [[ -x "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]]; then
    echo "### Installed Android Platforms" >> "${TEMP_FILE}"
    echo '```' >> "${TEMP_FILE}"
    "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --list_installed 2>/dev/null | grep "platforms;" | head -20 >> "${TEMP_FILE}" || echo "No platforms found" >> "${TEMP_FILE}"
    echo '```' >> "${TEMP_FILE}"
    echo "" >> "${TEMP_FILE}"

    echo "### Installed Build Tools" >> "${TEMP_FILE}"
    echo '```' >> "${TEMP_FILE}"
    "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --list_installed 2>/dev/null | grep "build-tools;" | head -20 >> "${TEMP_FILE}" || echo "No build tools found" >> "${TEMP_FILE}"
    echo '```' >> "${TEMP_FILE}"
    echo "" >> "${TEMP_FILE}"
  fi
else
  echo "Android SDK not found" >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
fi

# Language Versions
cat >> "${TEMP_FILE}" << 'EOF'
## Languages and Runtimes

EOF

# Node.js
if command -v node >/dev/null 2>&1; then
  echo "- **Node.js:** $(node --version 2>/dev/null || echo 'unavailable')" >> "${TEMP_FILE}"
  echo "- **npm:** $(npm --version 2>/dev/null || echo 'unavailable')" >> "${TEMP_FILE}"
fi

# Python
if command -v python3 >/dev/null 2>&1; then
  echo "- **Python:** $(python3 --version 2>/dev/null | awk '{print $2}' || echo 'unavailable')" >> "${TEMP_FILE}"
  echo "- **pip:** $(pip3 --version 2>/dev/null | awk '{print $2}' || echo 'unavailable')" >> "${TEMP_FILE}"
fi

# Ruby
if command -v ruby >/dev/null 2>&1; then
  echo "- **Ruby:** $(ruby --version 2>/dev/null | awk '{print $2}' || echo 'unavailable')" >> "${TEMP_FILE}"
fi

# Java
if command -v java >/dev/null 2>&1; then
  JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
  echo "- **Java:** ${JAVA_VERSION:-unavailable}" >> "${TEMP_FILE}"
fi

# Git
if command -v git >/dev/null 2>&1; then
  echo "- **Git:** $(git --version 2>/dev/null | awk '{print $3}' || echo 'unavailable')" >> "${TEMP_FILE}"
fi

echo "" >> "${TEMP_FILE}"

# Package Managers
cat >> "${TEMP_FILE}" << 'EOF'
## Package Managers

EOF

if command -v brew >/dev/null 2>&1; then
  echo "- **Homebrew:** $(brew --version 2>/dev/null | head -n 1 | awk '{print $2}' || echo 'unavailable')" >> "${TEMP_FILE}"
fi

if command -v gem >/dev/null 2>&1; then
  echo "- **RubyGems:** $(gem --version 2>/dev/null || echo 'unavailable')" >> "${TEMP_FILE}"
fi

if command -v pod >/dev/null 2>&1; then
  echo "- **CocoaPods:** $(pod --version 2>/dev/null || echo 'unavailable')" >> "${TEMP_FILE}"
fi

echo "" >> "${TEMP_FILE}"

# Utilities and Tools
cat >> "${TEMP_FILE}" << 'EOF'
## Development Tools and Utilities

EOF

# List key development tools
TOOLS=(
  "curl"
  "wget"
  "jq"
  "gh"
  "cmake"
  "fastlane"
  "xcbeautify"
)

for tool in "${TOOLS[@]}"; do
  if command -v "${tool}" >/dev/null 2>&1; then
    VERSION=$("${tool}" --version 2>/dev/null | head -n 1 || echo "installed")
    echo "- **${tool}:** ${VERSION}" >> "${TEMP_FILE}"
  fi
done

echo "" >> "${TEMP_FILE}"

# Homebrew packages
if command -v brew >/dev/null 2>&1; then
  cat >> "${TEMP_FILE}" << 'EOF'
### Homebrew Packages

<details>
<summary>Click to expand installed packages</summary>

```
EOF
  brew list --versions 2>/dev/null | sort >> "${TEMP_FILE}" || echo "No packages found" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
  echo "</details>" >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
fi

# iOS Simulators
if command -v xcrun >/dev/null 2>&1; then
  cat >> "${TEMP_FILE}" << 'EOF'
## iOS Simulators

<details>
<summary>Click to expand available simulators</summary>

```
EOF
  xcrun simctl list devices available 2>/dev/null >> "${TEMP_FILE}" || echo "No simulators found" >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
  echo "</details>" >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
fi

# Environment Variables
cat >> "${TEMP_FILE}" << 'EOF'
## Environment Variables

Key environment variables configured for development:

| Name | Value |
| ---- | ----- |
| DOTNET_ROOT | /Users/admin/.dotnet |
| ANDROID_HOME | ~/Library/Android/sdk |
| ANDROID_SDK_ROOT | ~/Library/Android/sdk |
| JAVA_HOME | (set by Xcode) |

EOF

# Image Information
if [[ -f /usr/local/share/build-info.json ]]; then
  cat >> "${TEMP_FILE}" << 'EOF'
## Build Information

<details>
<summary>Click to expand build details</summary>

```json
EOF
  cat /usr/local/share/build-info.json >> "${TEMP_FILE}"
  echo '```' >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
  echo "</details>" >> "${TEMP_FILE}"
  echo "" >> "${TEMP_FILE}"
fi

# Footer
cat >> "${TEMP_FILE}" << 'EOF'

---

**Image Type:** MAUI Development VM
**Virtualization:** Tart (Cirrus Labs)
**Base Image:** Cirrus Labs macOS with Xcode

For more information about the base image, see [cirruslabs/macos-image-templates](https://github.com/cirruslabs/macos-image-templates).

EOF

# Move to final location
sudo mv "${TEMP_FILE}" "${OUTPUT_FILE}"
sudo chmod 644 "${OUTPUT_FILE}"

echo "Software manifest generated: ${OUTPUT_FILE}"
