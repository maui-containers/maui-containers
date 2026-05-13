#!/usr/bin/env bash
set -euo pipefail

# Script to generate machine-readable JSON software manifest
# Companion to generate-software-manifest.sh

OUTPUT_FILE="${1:-/usr/local/share/installed-software.json}"
TEMP_FILE=$(mktemp)

echo "Generating JSON software manifest..."

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to generate the software manifest" >&2
  exit 1
fi

validate_json_segment() {
  local segment_name="$1"
  local json_payload="$2"
  local jq_error

  if ! jq_error=$(printf '%s' "${json_payload}" | jq empty 2>&1 >/dev/null); then
    echo "ERROR: Invalid JSON detected in segment '${segment_name}'" >&2
    printf '%s\n' "${json_payload}" >&2
    echo "" >&2
    echo "jq validation error:" >&2
    printf '%s\n' "${jq_error}" >&2
    exit 1
  fi
}

GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Operating system information
PRODUCT_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "")
BUILD_VERSION=$(sw_vers -buildVersion 2>/dev/null || echo "")
KERNEL_VERSION=$(uname -r 2>/dev/null || echo "")
ARCHITECTURE=$(uname -m 2>/dev/null || echo "")

OS_JSON=$(jq -n \
  --arg productVersion "${PRODUCT_VERSION:-unknown}" \
  --arg buildVersion "${BUILD_VERSION:-unknown}" \
  --arg kernelVersion "${KERNEL_VERSION:-unknown}" \
  --arg architecture "${ARCHITECTURE:-unknown}" \
  '{
    productVersion: $productVersion,
    buildVersion: $buildVersion,
    kernelVersion: $kernelVersion,
    architecture: $architecture
  }')

validate_json_segment "operatingSystem" "${OS_JSON}"

# Xcode information
XCODE_DEFAULT_VERSION=""
XCODE_DEFAULT_BUILD=""
XCODE_INSTALLED_JSON='[]'
XCODE_SDKS_JSON='[]'

if command -v xcodebuild >/dev/null 2>&1; then
  XCODE_DEFAULT_VERSION=$(xcodebuild -version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "")
  XCODE_DEFAULT_BUILD=$(xcodebuild -version 2>/dev/null | awk '/Build version/ {print $3}' || echo "")

  if command -v xcodes >/dev/null 2>&1; then
    XCODE_INSTALLED_JSON=$(xcodes installed 2>/dev/null | tail -n +2 | awk '{print $1}' | jq -R . | jq -s . 2>/dev/null || true)
    [[ -z "${XCODE_INSTALLED_JSON}" ]] && XCODE_INSTALLED_JSON='[]'
  fi

  XCODE_SDKS_JSON=$(xcodebuild -showsdks 2>/dev/null | awk '/-sdk/ {print $NF}' | jq -R . | jq -s . 2>/dev/null || true)
  [[ -z "${XCODE_SDKS_JSON}" ]] && XCODE_SDKS_JSON='[]'
fi

XCODE_JSON=$(jq -n \
  --arg defaultVersion "${XCODE_DEFAULT_VERSION}" \
  --arg defaultBuild "${XCODE_DEFAULT_BUILD}" \
  --argjson installedVersions "${XCODE_INSTALLED_JSON}" \
  --argjson sdks "${XCODE_SDKS_JSON}" \
  '{
    defaultVersion: (if $defaultVersion == "" then null else $defaultVersion end),
    defaultBuild: (if $defaultBuild == "" then null else $defaultBuild end),
    installedVersions: $installedVersions,
    sdks: $sdks
  }')

validate_json_segment "xcode" "${XCODE_JSON}"

# .NET information
DOTNET_VERSION=""
DOTNET_SDKS_JSON='[]'
DOTNET_RUNTIMES_JSON='[]'
DOTNET_WORKLOADS_JSON='[]'
DOTNET_GLOBAL_TOOLS_JSON='[]'

if command -v dotnet >/dev/null 2>&1; then
  DOTNET_VERSION=$(dotnet --version 2>/dev/null || echo "")

  DOTNET_SDKS_JSON=$(dotnet --list-sdks 2>/dev/null | awk '{print $1 "|" $2}' | jq -R 'select(length>0) | split("|") | {version: .[0], path: (.[1] | gsub("^\\[|\\]$"; ""))}' | jq -s . 2>/dev/null || true)
  [[ -z "${DOTNET_SDKS_JSON}" ]] && DOTNET_SDKS_JSON='[]'

  DOTNET_RUNTIMES_JSON=$(dotnet --list-runtimes 2>/dev/null | awk '{print $1 "|" $2}' | jq -R 'select(length>0) | split("|") | {name: .[0], version: .[1]}' | jq -s . 2>/dev/null || true)
  [[ -z "${DOTNET_RUNTIMES_JSON}" ]] && DOTNET_RUNTIMES_JSON='[]'

  WORKLOAD_LIST_OUTPUT=$(dotnet workload list 2>/dev/null || true)
  if [[ -n "${WORKLOAD_LIST_OUTPUT}" ]]; then
    DOTNET_WORKLOADS_JSON=$(printf '%s\n' "${WORKLOAD_LIST_OUTPUT}" | awk 'NF >= 2 && $2 ~ /^[0-9]/ {print $1}' | jq -R . | jq -s . 2>/dev/null || true)
    [[ -z "${DOTNET_WORKLOADS_JSON}" ]] && DOTNET_WORKLOADS_JSON='[]'
  fi

  DOTNET_GLOBAL_TOOLS_JSON=$(dotnet tool list -g 2>/dev/null | tail -n +3 | awk 'NF >= 2 {print $1 "|" $2}' | jq -R 'select(length>0) | split("|") | {name: .[0], version: .[1]}' | jq -s . 2>/dev/null || true)
  [[ -z "${DOTNET_GLOBAL_TOOLS_JSON}" ]] && DOTNET_GLOBAL_TOOLS_JSON='[]'
fi

DOTNET_JSON=$(jq -n \
  --arg version "${DOTNET_VERSION}" \
  --argjson sdks "${DOTNET_SDKS_JSON}" \
  --argjson runtimes "${DOTNET_RUNTIMES_JSON}" \
  --argjson workloads "${DOTNET_WORKLOADS_JSON}" \
  --argjson globalTools "${DOTNET_GLOBAL_TOOLS_JSON}" \
  '{
    version: (if $version == "" then null else $version end),
    sdks: $sdks,
    runtimes: $runtimes,
    workloads: $workloads,
    globalTools: $globalTools
  }')

validate_json_segment ".net" "${DOTNET_JSON}"

# Android information
DEFAULT_ANDROID_HOME="${HOME}/Library/Android/sdk"
ANDROID_HOME="${ANDROID_HOME:-${DEFAULT_ANDROID_HOME}}"
[[ -d "${ANDROID_HOME}" ]] || ANDROID_HOME=""

ANDROID_PLATFORMS_JSON='[]'
ANDROID_BUILD_TOOLS_JSON='[]'

if [[ -n "${ANDROID_HOME}" ]]; then
  SDKMANAGER="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
  if [[ -x "${SDKMANAGER}" ]]; then
    ANDROID_PLATFORMS_JSON=$("${SDKMANAGER}" --list_installed 2>/dev/null | awk '/platforms;/{print $1}' | jq -R . | jq -s . 2>/dev/null || true)
    [[ -z "${ANDROID_PLATFORMS_JSON}" ]] && ANDROID_PLATFORMS_JSON='[]'

    ANDROID_BUILD_TOOLS_JSON=$("${SDKMANAGER}" --list_installed 2>/dev/null | awk '/build-tools;/{print $1}' | jq -R . | jq -s . 2>/dev/null || true)
    [[ -z "${ANDROID_BUILD_TOOLS_JSON}" ]] && ANDROID_BUILD_TOOLS_JSON='[]'
  fi
fi

ANDROID_JSON=$(jq -n \
  --arg sdkRoot "${ANDROID_HOME}" \
  --argjson platforms "${ANDROID_PLATFORMS_JSON}" \
  --argjson buildTools "${ANDROID_BUILD_TOOLS_JSON}" \
  '{
    sdkRoot: (if $sdkRoot == "" then null else $sdkRoot end),
    platforms: $platforms,
    buildTools: $buildTools
  }')

validate_json_segment "android" "${ANDROID_JSON}"

# Language runtimes
if command -v node >/dev/null 2>&1; then
  LANG_NODE=$(node --version 2>/dev/null | sed 's/^v//')
else
  LANG_NODE=""
fi

if command -v npm >/dev/null 2>&1; then
  LANG_NPM=$(npm --version 2>/dev/null)
else
  LANG_NPM=""
fi

if command -v python3 >/dev/null 2>&1; then
  LANG_PYTHON=$(python3 --version 2>/dev/null | awk '{print $2}')
else
  LANG_PYTHON=""
fi

if command -v pip3 >/dev/null 2>&1; then
  LANG_PIP=$(pip3 --version 2>/dev/null | awk '{print $2}')
else
  LANG_PIP=""
fi

if command -v ruby >/dev/null 2>&1; then
  LANG_RUBY=$(ruby --version 2>/dev/null | awk '{print $2}')
else
  LANG_RUBY=""
fi

if command -v java >/dev/null 2>&1; then
  LANG_JAVA=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
else
  LANG_JAVA=""
fi

if command -v git >/dev/null 2>&1; then
  LANG_GIT=$(git --version 2>/dev/null | awk '{print $3}')
else
  LANG_GIT=""
fi

LANGUAGES_JSON=$(jq -n \
  --arg node "${LANG_NODE}" \
  --arg npm "${LANG_NPM}" \
  --arg python "${LANG_PYTHON}" \
  --arg pip "${LANG_PIP}" \
  --arg ruby "${LANG_RUBY}" \
  --arg java "${LANG_JAVA}" \
  --arg git "${LANG_GIT}" \
  '{
    node: (if $node == "" then null else $node end),
    npm: (if $npm == "" then null else $npm end),
    python: (if $python == "" then null else $python end),
    pip: (if $pip == "" then null else $pip end),
    ruby: (if $ruby == "" then null else $ruby end),
    java: (if $java == "" then null else $java end),
    git: (if $git == "" then null else $git end)
  }')

validate_json_segment "languages" "${LANGUAGES_JSON}"

# Package managers
if command -v brew >/dev/null 2>&1; then
  PM_HOMEBREW=$(brew --version 2>/dev/null | head -n 1 | awk '{print $2}')
else
  PM_HOMEBREW=""
fi

if command -v gem >/dev/null 2>&1; then
  PM_GEM=$(gem --version 2>/dev/null)
else
  PM_GEM=""
fi

if command -v pod >/dev/null 2>&1; then
  PM_COCOAPODS=$(pod --version 2>/dev/null)
else
  PM_COCOAPODS=""
fi

PACKAGE_MANAGERS_JSON=$(jq -n \
  --arg homebrew "${PM_HOMEBREW}" \
  --arg gem "${PM_GEM}" \
  --arg cocoapods "${PM_COCOAPODS}" \
  '{
    homebrew: (if $homebrew == "" then null else $homebrew end),
    gem: (if $gem == "" then null else $gem end),
    cocoapods: (if $cocoapods == "" then null else $cocoapods end)
  }')

validate_json_segment "packageManagers" "${PACKAGE_MANAGERS_JSON}"

# Development tools
get_tool_version_last_field() {
  local command_name="$1"
  if command -v "${command_name}" >/dev/null 2>&1; then
    "${command_name}" --version 2>/dev/null | head -n 1 | awk '{print $NF}'
  else
    echo ""
  fi
}

TOOL_CURL=$(get_tool_version_last_field curl)
TOOL_WGET=$(get_tool_version_last_field wget)
TOOL_JQ=$(jq --version 2>/dev/null)
TOOL_GH=$(get_tool_version_last_field gh)
TOOL_CMAKE=$(get_tool_version_last_field cmake)

if command -v fastlane >/dev/null 2>&1; then
  TOOL_FASTLANE=$(fastlane --version 2>/dev/null | head -n 1 | awk '{print $NF}')
else
  TOOL_FASTLANE=""
fi

if command -v xcbeautify >/dev/null 2>&1; then
  TOOL_XCBEAUTIFY=$(xcbeautify --version 2>/dev/null | awk '{print $NF}')
else
  TOOL_XCBEAUTIFY=""
fi

TOOLS_JSON=$(jq -n \
  --arg curl "${TOOL_CURL}" \
  --arg wget "${TOOL_WGET}" \
  --arg jqTool "${TOOL_JQ}" \
  --arg gh "${TOOL_GH}" \
  --arg cmake "${TOOL_CMAKE}" \
  --arg fastlane "${TOOL_FASTLANE}" \
  --arg xcbeautify "${TOOL_XCBEAUTIFY}" \
  '{
    curl: (if $curl == "" then null else $curl end),
    wget: (if $wget == "" then null else $wget end),
    jq: (if $jqTool == "" then null else $jqTool end),
    gh: (if $gh == "" then null else $gh end),
    cmake: (if $cmake == "" then null else $cmake end),
    fastlane: (if $fastlane == "" then null else $fastlane end),
    xcbeautify: (if $xcbeautify == "" then null else $xcbeautify end)
  }')

validate_json_segment "tools" "${TOOLS_JSON}"

# Homebrew packages
if command -v brew >/dev/null 2>&1; then
  HOMEBREW_PACKAGES_JSON=$(brew list --versions 2>/dev/null | awk 'NF >= 2 {print $1 "|" $2}' | jq -R 'select(length>0) | split("|") | {name: .[0], version: .[1]}' | jq -s . 2>/dev/null || true)
  [[ -z "${HOMEBREW_PACKAGES_JSON}" ]] && HOMEBREW_PACKAGES_JSON='[]'
else
  HOMEBREW_PACKAGES_JSON='[]'
fi

validate_json_segment "homebrewPackages" "${HOMEBREW_PACKAGES_JSON}"

# Environment variables and startup metadata
ENVIRONMENT_VARIABLES_JSON=$(jq -n '{
  DOTNET_ROOT: "/Users/admin/.dotnet",
  ANDROID_HOME: "~/Library/Android/sdk",
  ANDROID_SDK_ROOT: "~/Library/Android/sdk"
}')

STARTUP_JSON=$(jq -n '{
  initScript: "/Volumes/My Shared Files/config/init.sh",
  configurationMethod: "Mount config directory with --dir config:/path/to/config"
}')

# Optional build metadata
BUILD_INFO_JSON='null'
if [[ -f /usr/local/share/build-info.json ]]; then
  if BUILD_INFO_JSON=$(jq '.' /usr/local/share/build-info.json 2>/dev/null); then
    :
  else
    echo "WARNING: Skipping malformed build-info manifest at /usr/local/share/build-info.json" >&2
    BUILD_INFO_JSON='null'
  fi
fi

validate_json_segment "environmentVariables" "${ENVIRONMENT_VARIABLES_JSON}"
validate_json_segment "startup" "${STARTUP_JSON}"
[[ "${BUILD_INFO_JSON}" != "null" ]] && validate_json_segment "buildInfo" "${BUILD_INFO_JSON}"

# Assemble final JSON manifest
if ! jq -n \
   --arg manifestVersion "1.0" \
   --arg imageType "maui-development" \
   --arg generatedAt "${GENERATED_AT}" \
   --argjson operatingSystem "${OS_JSON}" \
  --argjson xcode "${XCODE_JSON}" \
  --argjson dotnet "${DOTNET_JSON}" \
  --argjson android "${ANDROID_JSON}" \
  --argjson languages "${LANGUAGES_JSON}" \
  --argjson packageManagers "${PACKAGE_MANAGERS_JSON}" \
  --argjson tools "${TOOLS_JSON}" \
  --argjson homebrewPackages "${HOMEBREW_PACKAGES_JSON}" \
  --argjson environmentVariables "${ENVIRONMENT_VARIABLES_JSON}" \
  --argjson startup "${STARTUP_JSON}" \
  --argjson buildInfo "${BUILD_INFO_JSON}" \
  '{
    manifestVersion: $manifestVersion,
    imageType: $imageType,
    generatedAt: $generatedAt,
    operatingSystem: $operatingSystem,
    xcode: $xcode,
    dotnet: $dotnet,
    android: $android,
    languages: $languages,
    packageManagers: $packageManagers,
    tools: $tools,
    homebrewPackages: $homebrewPackages,
    environmentVariables: $environmentVariables,
    startup: $startup
  } + (if $buildInfo == null then {} else {buildInfo: $buildInfo} end)' 2>"${TEMP_FILE}.builderr" > "${TEMP_FILE}"; then
  echo "ERROR: Failed to assemble final software manifest JSON" >&2
  [[ -s "${TEMP_FILE}.builderr" ]] && cat "${TEMP_FILE}.builderr" >&2
  rm -f "${TEMP_FILE}.builderr"
  exit 1
fi
rm -f "${TEMP_FILE}.builderr"

# Validate JSON with jq to surface helpful errors
if ! jq empty "${TEMP_FILE}" >/dev/null 2>"${TEMP_FILE}.jqerr"; then
  echo "ERROR: Generated invalid JSON" >&2
  cat "${TEMP_FILE}" >&2
  echo "" >&2
  echo "jq validation error:" >&2
  cat "${TEMP_FILE}.jqerr" >&2
  rm -f "${TEMP_FILE}.jqerr"
  exit 1
fi
rm -f "${TEMP_FILE}.jqerr"

# Pretty-print JSON
jq . "${TEMP_FILE}" > "${TEMP_FILE}.pretty"
mv "${TEMP_FILE}.pretty" "${TEMP_FILE}"

# Move to final location
sudo mv "${TEMP_FILE}" "${OUTPUT_FILE}"
sudo chmod 644 "${OUTPUT_FILE}"

echo "JSON software manifest generated: ${OUTPUT_FILE}"
