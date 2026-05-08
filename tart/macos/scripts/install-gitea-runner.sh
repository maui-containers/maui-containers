#!/usr/bin/env bash
set -euo pipefail

echo 'Installing Gitea Actions runner...'
mkdir -p /Users/admin/gitea-runner
cd /Users/admin/gitea-runner

# Detect architecture
ARCH=$(uname -m)
if [ "${ARCH}" = "arm64" ]; then
  DOWNLOAD_ARCH="arm64"
else
  DOWNLOAD_ARCH="amd64"
fi
echo "Detected architecture: ${ARCH} (downloading ${DOWNLOAD_ARCH})"

# Get latest release and extract the correct download URL from assets
RELEASES_FILE=$(mktemp)
trap 'rm -f "${RELEASES_FILE}"' EXIT
curl -fsSL https://gitea.com/api/v1/repos/gitea/act_runner/releases -o "${RELEASES_FILE}"
LATEST_VERSION=$(jq -r '.[0].tag_name' "${RELEASES_FILE}")
# Remove 'v' prefix from version for filename matching
VERSION_NO_V=$(echo "${LATEST_VERSION}" | sed 's/^v//')

PREFERRED_ASSET="gitea-runner-${VERSION_NO_V}-darwin-${DOWNLOAD_ARCH}"
LEGACY_ASSET="act_runner-${VERSION_NO_V}-darwin-${DOWNLOAD_ARCH}"

if ! DOWNLOAD_INFO=$(jq -er \
  --arg preferred "${PREFERRED_ASSET}" \
  --arg legacy "${LEGACY_ASSET}" \
  '.[0].assets // [] | map(select(.name == $preferred or .name == $legacy)) | .[0] | select(. != null and .browser_download_url != null and .browser_download_url != "") | [.name, .browser_download_url] | @tsv' \
  "${RELEASES_FILE}"); then
  echo "Could not find a darwin ${DOWNLOAD_ARCH} runner asset named '${PREFERRED_ASSET}' or '${LEGACY_ASSET}'." >&2
  echo "Available assets:" >&2
  jq -r '.[0].assets[]?.name | "  - \(.)"' "${RELEASES_FILE}" >&2
  exit 1
fi

DOWNLOAD_ASSET=${DOWNLOAD_INFO%%$'\t'*}
DOWNLOAD_URL=${DOWNLOAD_INFO#*$'\t'}

echo "Latest Gitea runner version: ${LATEST_VERSION}"
echo "Downloading asset: ${DOWNLOAD_ASSET}"
echo "Downloading from: ${DOWNLOAD_URL}"
curl -fsSL "${DOWNLOAD_URL}" -o act_runner
chmod +x act_runner

# Move helper script into place
mv /tmp/gitea-runner.sh /Users/admin/gitea-runner/gitea-runner.sh
chmod +x /Users/admin/gitea-runner/gitea-runner.sh
chown -R admin:staff /Users/admin/gitea-runner

echo 'Gitea Actions runner installed'
echo 'Runner binary: /Users/admin/gitea-runner/act_runner'
echo 'Runner helper script: /Users/admin/gitea-runner/gitea-runner.sh'
