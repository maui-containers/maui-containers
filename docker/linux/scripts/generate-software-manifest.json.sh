#!/usr/bin/env bash
set -euo pipefail

# Script to generate machine-readable JSON software manifest for Docker images
# Similar to Tart VM manifest but adapted for Linux containers

OUTPUT_FILE="${1:-/usr/local/share/installed-software.json}"
TEMP_FILE=$(mktemp)

echo "Generating JSON software manifest..."

# Start JSON structure
cat > "${TEMP_FILE}" << 'EOF'
{
  "manifestVersion": "1.0",
  "imageType": "maui-docker-development",
  "generatedAt": "
EOF

echo -n "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${TEMP_FILE}"

cat >> "${TEMP_FILE}" << 'EOF'
",
  "operatingSystem": {
EOF

# OS Information (Ubuntu/Debian in container)
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  echo "    \"distribution\": \"${ID}\"," >> "${TEMP_FILE}"
  echo "    \"version\": \"${VERSION_ID}\"," >> "${TEMP_FILE}"
  echo "    \"versionCodename\": \"${VERSION_CODENAME:-unknown}\"," >> "${TEMP_FILE}"
else
  echo "    \"distribution\": \"unknown\"," >> "${TEMP_FILE}"
  echo "    \"version\": \"unknown\"," >> "${TEMP_FILE}"
  echo "    \"versionCodename\": \"unknown\"," >> "${TEMP_FILE}"
fi

echo "    \"kernelVersion\": \"$(uname -r)\"," >> "${TEMP_FILE}"
echo "    \"architecture\": \"$(uname -m)\"" >> "${TEMP_FILE}"

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "dotnet": {
EOF

if command -v dotnet >/dev/null 2>&1; then
  DOTNET_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
  echo "    \"version\": \"${DOTNET_VERSION}\"," >> "${TEMP_FILE}"

  # SDKs
  echo "    \"sdks\": [" >> "${TEMP_FILE}"
  dotnet --list-sdks 2>/dev/null | awk '{print "      {\"version\": \"" $1 "\", \"path\": \"" $2 "\"}"}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]," >> "${TEMP_FILE}"

  # Runtimes
  echo "    \"runtimes\": [" >> "${TEMP_FILE}"
  dotnet --list-runtimes 2>/dev/null | awk '{print "      {\"name\": \"" $1 "\", \"version\": \"" $2 "\"}"}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]," >> "${TEMP_FILE}"

  # Workloads
  echo "    \"workloads\": [" >> "${TEMP_FILE}"
  dotnet workload list 2>/dev/null | tail -n +3 | head -n -2 | awk 'NF && $1 !~ /^-+$/ && $1 != "Installed" {print "      \"" $1 "\""}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]," >> "${TEMP_FILE}"

  # Global tools
  echo "    \"globalTools\": [" >> "${TEMP_FILE}"
  dotnet tool list -g 2>/dev/null | tail -n +3 | awk '{print "      {\"name\": \"" $1 "\", \"version\": \"" $2 "\"}"}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]" >> "${TEMP_FILE}"
else
  echo "    \"version\": null," >> "${TEMP_FILE}"
  echo "    \"sdks\": []," >> "${TEMP_FILE}"
  echo "    \"runtimes\": []," >> "${TEMP_FILE}"
  echo "    \"workloads\": []," >> "${TEMP_FILE}"
  echo "    \"globalTools\": []" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "android": {
EOF

ANDROID_HOME="${ANDROID_HOME:-/home/mauiusr/.android}"
if [[ -d "${ANDROID_HOME}" ]]; then
  echo "    \"sdkRoot\": \"${ANDROID_HOME}\"," >> "${TEMP_FILE}"

  # Use android tool to get installed packages
  if command -v android >/dev/null 2>&1; then
    # Platforms
    echo "    \"platforms\": [" >> "${TEMP_FILE}"
    android sdk list --installed --format=json 2>/dev/null | jq -r '.installed[]? | select(.path | startswith("platforms;")) | .path' 2>/dev/null | awk '{print "      \"" $1 "\""}' | paste -sd ',' - >> "${TEMP_FILE}" 2>/dev/null || echo -n '' >> "${TEMP_FILE}"
    echo "" >> "${TEMP_FILE}"
    echo "    ]," >> "${TEMP_FILE}"

    # Build tools
    echo "    \"buildTools\": [" >> "${TEMP_FILE}"
    android sdk list --installed --format=json 2>/dev/null | jq -r '.installed[]? | select(.path | startswith("build-tools;")) | .path' 2>/dev/null | awk '{print "      \"" $1 "\""}' | paste -sd ',' - >> "${TEMP_FILE}" 2>/dev/null || echo -n '' >> "${TEMP_FILE}"
    echo "" >> "${TEMP_FILE}"
    echo "    ]" >> "${TEMP_FILE}"
  else
    echo "    \"platforms\": []," >> "${TEMP_FILE}"
    echo "    \"buildTools\": []" >> "${TEMP_FILE}"
  fi
else
  echo "    \"sdkRoot\": null," >> "${TEMP_FILE}"
  echo "    \"platforms\": []," >> "${TEMP_FILE}"
  echo "    \"buildTools\": []" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "java": {
EOF

echo -n "    \"version\": " >> "${TEMP_FILE}"
if command -v java >/dev/null 2>&1; then
  JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
  echo "\"${JAVA_VERSION}\"," >> "${TEMP_FILE}"

  echo -n "    \"home\": " >> "${TEMP_FILE}"
  if [[ -n "${JAVA_HOME:-}" ]]; then
    echo "\"${JAVA_HOME}\"" >> "${TEMP_FILE}"
  else
    echo "null" >> "${TEMP_FILE}"
  fi
else
  echo "null," >> "${TEMP_FILE}"
  echo "    \"home\": null" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "languages": {
EOF

# Language versions (common in Linux containers)
echo -n "    \"python\": " >> "${TEMP_FILE}"
if command -v python3 >/dev/null 2>&1; then
  echo "\"$(python3 --version 2>/dev/null | awk '{print $2}')\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"pip\": " >> "${TEMP_FILE}"
if command -v pip3 >/dev/null 2>&1; then
  echo "\"$(pip3 --version 2>/dev/null | awk '{print $2}')\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"git\": " >> "${TEMP_FILE}"
if command -v git >/dev/null 2>&1; then
  echo "\"$(git --version 2>/dev/null | awk '{print $3}')\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"bash\": " >> "${TEMP_FILE}"
if command -v bash >/dev/null 2>&1; then
  echo "\"$(bash --version 2>/dev/null | head -n 1 | awk '{print $4}' | cut -d'(' -f1)\"" >> "${TEMP_FILE}"
else
  echo "null" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "tools": {
EOF

# Development tools
TOOLS=(curl wget jq sudo pwsh)
TOOL_COUNT=${#TOOLS[@]}
CURRENT=0

for tool in "${TOOLS[@]}"; do
  CURRENT=$((CURRENT + 1))
  echo -n "    \"${tool}\": " >> "${TEMP_FILE}"

  if command -v "${tool}" >/dev/null 2>&1; then
    case "${tool}" in
      pwsh)
        VERSION=$("${tool}" --version 2>/dev/null | head -n 1 | awk '{print $NF}' || echo "installed")
        ;;
      curl|wget)
        VERSION=$("${tool}" --version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "installed")
        ;;
      *)
        VERSION=$("${tool}" --version 2>/dev/null | head -n 1 | awk '{print $NF}' || echo "installed")
        ;;
    esac
    echo -n "\"${VERSION}\"" >> "${TEMP_FILE}"
  else
    echo -n "null" >> "${TEMP_FILE}"
  fi

  if [[ ${CURRENT} -lt ${TOOL_COUNT} ]]; then
    echo "," >> "${TEMP_FILE}"
  else
    echo "" >> "${TEMP_FILE}"
  fi
done

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "environmentVariables": {
    "ANDROID_HOME": "${ANDROID_HOME:-/home/mauiusr/.android}",
    "ANDROID_SDK_HOME": "${ANDROID_SDK_HOME:-/home/mauiusr/.android}",
    "JAVA_HOME": "${JAVA_HOME:-/usr/lib/jvm/msopenjdk}"
  }
EOF

# Close JSON
echo "}" >> "${TEMP_FILE}"

# Validate JSON before moving
if command -v jq >/dev/null 2>&1; then
  if ! jq empty "${TEMP_FILE}" 2>/dev/null; then
    echo "ERROR: Generated invalid JSON" >&2
    cat "${TEMP_FILE}"
    exit 1
  fi
  # Pretty-print with jq
  jq . "${TEMP_FILE}" > "${TEMP_FILE}.pretty"
  mv "${TEMP_FILE}.pretty" "${TEMP_FILE}"
fi

# Move to final location (use sudo only if needed)
OUTPUT_DIR=$(dirname "${OUTPUT_FILE}")
if [[ -w "${OUTPUT_DIR}" ]] || [[ ! -d "${OUTPUT_DIR}" && -w "$(dirname "${OUTPUT_DIR}")" ]]; then
  mkdir -p "${OUTPUT_DIR}" 2>/dev/null || true
  mv "${TEMP_FILE}" "${OUTPUT_FILE}"
  chmod 644 "${OUTPUT_FILE}" 2>/dev/null || true
else
  sudo mkdir -p "${OUTPUT_DIR}" 2>/dev/null || true
  sudo mv "${TEMP_FILE}" "${OUTPUT_FILE}"
  sudo chmod 644 "${OUTPUT_FILE}"
fi

echo "JSON software manifest generated: ${OUTPUT_FILE}"
