#!/bin/bash
set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

ensure_required_runtimes() {
  if ! command -v xcodes >/dev/null 2>&1; then
    echo "Warning: xcodes CLI not available; skipping runtime installation"
    return
  fi

  echo "Ensuring required iOS and tvOS runtimes are installed via xcodes..."
  REQUIRED_RUNTIMES="iOS tvOS"
  for runtime in $REQUIRED_RUNTIMES; do
    echo "Checking runtime: $runtime"
    if xcodes runtimes | grep -q "$runtime (Installed)"; then
      echo "Runtime $runtime already installed"
    else
      echo "Installing latest $runtime runtime..."
      # Get the latest available version for this runtime platform
      LATEST_VERSION=$(xcodes runtimes 2>/dev/null | grep "^$runtime" | grep -v "(Installed)" | tail -1 | sed 's/ *$//')
      if [ -n "$LATEST_VERSION" ]; then
        echo "Found latest: $LATEST_VERSION"
        if ! sudo xcodes runtimes install "$LATEST_VERSION"; then
          echo "Warning: Failed to install runtime $LATEST_VERSION (may require Apple ID or be unavailable)."
        fi
      else
        echo "Warning: Could not determine latest $runtime runtime version."
      fi
    fi
  done
}

ADDITIONAL_XCODES="$1"

if [ -n "$ADDITIONAL_XCODES" ]; then
  echo "Installing additional Xcode versions: $ADDITIONAL_XCODES"
  echo "Note: Some Xcode versions may require Apple ID credentials and will be skipped if not available"

  # Convert comma-separated list to space-separated
  XCODE_LIST=$(echo "$ADDITIONAL_XCODES" | tr ',' ' ')

  for version in $XCODE_LIST; do
    echo "Installing Xcode $version..."
    # Try to install, but don't fail if it requires Apple ID
    if xcodes install $version --no-superuser --experimental-unxip 2>&1 | tee /tmp/xcode-install.log; then
      echo "Successfully installed Xcode $version"
    else
      if grep -q "Apple ID" /tmp/xcode-install.log; then
        echo "Info: Xcode $version requires Apple ID authentication and was skipped"
      else
        echo "Warning: Failed to install Xcode $version"
      fi
    fi
  done

  echo "Additional Xcode installations completed"
  echo "Installed Xcode versions:"
  xcodes installed
else
  echo "No additional Xcode versions to install"
fi

ensure_required_runtimes
