#!/usr/bin/bash

set -euo pipefail

log() {
  echo "[runner] $*"
}

log "MAUI Image - Runner initialization"

# Check for and execute initialization scripts if they exist
INIT_PWSH_SCRIPT=${INIT_PWSH_SCRIPT:-""}
INIT_BASH_SCRIPT=${INIT_BASH_SCRIPT:-""}

if [ -f "$INIT_BASH_SCRIPT" ]; then
  log "Found initialization script at $INIT_BASH_SCRIPT, executing..."
  /usr/bin/bash "$INIT_BASH_SCRIPT"
  log "Initialization script executed successfully."
fi

if [ -f "$INIT_PWSH_SCRIPT" ]; then
  log "Found initialization script at $INIT_PWSH_SCRIPT, executing..."
  /usr/bin/pwsh "$INIT_PWSH_SCRIPT"
  log "Initialization script executed successfully."
fi

# GitHub Actions Runner Configuration
GITHUB_ORG=${GITHUB_ORG:-""}
GITHUB_REPO=${GITHUB_REPO:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

# Gitea Actions Runner Configuration
GITEA_INSTANCE_URL=${GITEA_INSTANCE_URL:-""}
GITEA_RUNNER_TOKEN=${GITEA_RUNNER_TOKEN:-""}
GITEA_RUNNER_NAME=${GITEA_RUNNER_NAME:-""}

# Determine which runners to start
GITHUB_RUNNER_ENABLED=false
GITEA_RUNNER_ENABLED=false

if [ -n "$GITHUB_ORG" ] && [ -n "$GITHUB_TOKEN" ]; then
  GITHUB_RUNNER_ENABLED=true
  log "GitHub Actions runner will be configured and started"
fi

if [ -n "$GITEA_INSTANCE_URL" ] && [ -n "$GITEA_RUNNER_TOKEN" ]; then
  GITEA_RUNNER_ENABLED=true
  log "Gitea Actions runner will be configured and started"
fi

if [ "$GITHUB_RUNNER_ENABLED" = false ] && [ "$GITEA_RUNNER_ENABLED" = false ]; then
  log "No runner credentials provided. Skipping runner configuration."
  log "To enable GitHub runner, set GITHUB_ORG and GITHUB_TOKEN"
  log "To enable Gitea runner, set GITEA_INSTANCE_URL and GITEA_RUNNER_TOKEN"
  log "Container will remain running for development use."
  # Exit - the container stays alive via the CMD
  exit 0
fi

# Function to configure and run GitHub Actions runner
start_github_runner() {
  log "Configuring GitHub Actions runner..."
  
  # Check if GITHUB_REPO is specified and use the appropriate API endpoint
  if [ -z "$GITHUB_REPO" ] || [ "$GITHUB_REPO" == "" ]; then
    log "No repository specified, registering runner at organization level"
    REG_TOKEN=$(curl -X POST -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token | jq .token --raw-output)
    RUNNER_URL="https://github.com/${GITHUB_ORG}"
  else
    log "Repository specified, registering runner at repository level"
    REG_TOKEN=$(curl -X POST -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}/actions/runners/registration-token | jq .token --raw-output)
    RUNNER_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
  fi

  # Check if the registration token is empty
  if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" == "null" ]; then
    log "ERROR: Failed to obtain GitHub registration token. Skipping GitHub runner."
    return 1
  fi

  cd /home/mauiusr/actions-runner

  # Clean up any pre-existing runner configuration to prevent stale token errors
  # This allows the runner to work correctly across container restarts
  if [ -f ".runner" ] || [ -f ".credentials" ] || [ -f ".credentials_rsaparams" ]; then
    log "Cleaning up pre-existing GitHub runner configuration"
    rm -f .runner .credentials .credentials_rsaparams
    log "Old GitHub configuration removed"
  fi

  # Create .env file with Android SDK environment variables
  # This ensures ANDROID_HOME is available to all runner jobs
  log "Creating .env file with ANDROID_HOME environment variable"
  cat > .env << EOF
ANDROID_HOME=${ANDROID_HOME}
ANDROID_SDK_HOME=${ANDROID_SDK_HOME}
ANDROID_SDK_ROOT=${ANDROID_HOME}
EOF
  log ".env file created with ANDROID_HOME=${ANDROID_HOME}"

  _RANDOM_RUNNER_SUFFIX=${RANDOM_RUNNER_SUFFIX:="true"}
  _RUNNER_NAME=${RUNNER_NAME:-${RUNNER_NAME_PREFIX:-github-runner}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')}
  if [[ ${RANDOM_RUNNER_SUFFIX} != "true" ]]; then
    # In some cases this file does not exist
    if [[ -f "/etc/hostname" ]]; then
      # in some cases it can also be empty
      if [[ $(stat --printf="%s" /etc/hostname) -ne 0 ]]; then
        _RUNNER_NAME=${RUNNER_NAME:-${RUNNER_NAME_PREFIX:-github-runner}-$(cat /etc/hostname)}
        log "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists and has content. Setting runner name to ${_RUNNER_NAME}"
      else
        log "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} ./etc/hostname exists but is empty. Not using /etc/hostname."
      fi
    else
      log "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} but /etc/hostname does not exist. Not using /etc/hostname."
    fi
  fi

  _RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work/${_RUNNER_NAME}}
  _LABELS=${LABELS:-default}
  _RUNNER_GROUP=${RUNNER_GROUP:-Default}

  ARGS=()

  # shellcheck disable=SC2153
  if [ -n "${EPHEMERAL}" ]; then
    log "Ephemeral option is enabled"
    ARGS+=("--ephemeral")
    # Auto-disable updates for ephemeral runners unless explicitly overridden
    if [ -z "${DISABLE_AUTO_UPDATE}" ]; then
      log "Auto-disabling updates for ephemeral runner"
      DISABLE_AUTO_UPDATE="true"
    fi
  fi

  if [ -n "${DISABLE_AUTO_UPDATE}" ]; then
    log "Disable auto update option is enabled"
    ARGS+=("--disableupdate")
  fi

  if [ -n "${NO_DEFAULT_LABELS}" ]; then
    log "Disable adding the default self-hosted, platform, and architecture labels"
    ARGS+=("--no-default-labels")
  fi

  # Ensure workdir exists and has the correct permissions
  [[ ! -d "${_RUNNER_WORKDIR}" ]] && sudo mkdir -p "${_RUNNER_WORKDIR}"
  sudo chown -R 1400:1401 "${_RUNNER_WORKDIR}"

  log "Configuring GitHub runner '${_RUNNER_NAME}'"
  ./config.sh \
      --url "${RUNNER_URL}" \
      --token "${REG_TOKEN}" \
      --name "${_RUNNER_NAME}" \
      --work "${_RUNNER_WORKDIR}" \
      --labels "${_LABELS}" \
      --runnergroup "${_RUNNER_GROUP}" \
      --unattended \
      --replace \
      "${ARGS[@]}"

  cleanup_github() {
    log "Removing GitHub runner..."
    ./config.sh remove --token ${REG_TOKEN}
  }

  trap 'cleanup_github; exit 130' INT
  trap 'cleanup_github; exit 143' TERM

  log "Starting GitHub Actions runner"
  ./run.sh
}

# Function to configure and run Gitea Actions runner
start_gitea_runner() {
  log "Configuring Gitea Actions runner..."
  
  cd /home/mauiusr/gitea-runner

  # Generate runner name if not provided
  _RANDOM_RUNNER_SUFFIX=${RANDOM_RUNNER_SUFFIX:="true"}
  if [ -z "$GITEA_RUNNER_NAME" ]; then
    _RUNNER_NAME_PREFIX=${GITEA_RUNNER_NAME_PREFIX:-gitea-runner}
    if [[ ${RANDOM_RUNNER_SUFFIX} == "true" ]]; then
      _RUNNER_NAME=${_RUNNER_NAME_PREFIX}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
    else
      # In some cases this file does not exist
      if [[ -f "/etc/hostname" ]]; then
        # in some cases it can also be empty
        if [[ $(stat --printf="%s" /etc/hostname) -ne 0 ]]; then
          _RUNNER_NAME=${_RUNNER_NAME_PREFIX}-$(cat /etc/hostname)
          log "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists and has content. Setting runner name to ${_RUNNER_NAME}"
        else
          log "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists but is empty. Using random suffix."
          _RUNNER_NAME=${_RUNNER_NAME_PREFIX}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
        fi
      else
        log "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} but /etc/hostname does not exist. Using random suffix."
        _RUNNER_NAME=${_RUNNER_NAME_PREFIX}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
      fi
    fi
  else
    _RUNNER_NAME=$GITEA_RUNNER_NAME
  fi

  _LABELS=${GITEA_RUNNER_LABELS:-maui,linux,amd64}

  # Clean up any pre-existing runner configuration to prevent stale token errors
  # This allows the runner to work correctly across container restarts
  if [ -f ".runner" ]; then
    log "Cleaning up pre-existing Gitea runner configuration"
    rm -f .runner
    log "Old Gitea configuration removed"
  fi

  # Create .env file with Android SDK environment variables
  # This ensures ANDROID_HOME is available to all runner jobs
  log "Creating .env file with ANDROID_HOME environment variable"
  cat > .env << EOF
ANDROID_HOME=${ANDROID_HOME}
ANDROID_SDK_HOME=${ANDROID_SDK_HOME}
ANDROID_SDK_ROOT=${ANDROID_HOME}
EOF
  log ".env file created with ANDROID_HOME=${ANDROID_HOME}"

  log "Registering Gitea runner: ${_RUNNER_NAME}"
  log "Labels: ${_LABELS}"

  # Register the runner (always, since we clean up above)
  log "Registering runner with Gitea..."
  ./act_runner register \
    --instance "${GITEA_INSTANCE_URL}" \
    --token "${GITEA_RUNNER_TOKEN}" \
    --name "${_RUNNER_NAME}" \
    --labels "${_LABELS}" \
    --no-interactive

  if [ $? -ne 0 ]; then
    log "ERROR: Failed to register runner with Gitea. Skipping Gitea runner."
    return 1
  fi

  log "Runner registered successfully"

  cleanup_gitea() {
    log "Shutting down Gitea runner..."
    # Gitea runner doesn't have a built-in removal command like GitHub
    # The runner will just stop and can be removed from Gitea UI if needed
  }

  trap 'cleanup_gitea; exit 130' INT
  trap 'cleanup_gitea; exit 143' TERM

  log "Starting Gitea runner daemon..."
  ./act_runner daemon
}

# Start runners based on configuration
# If both are enabled, we'll run them in parallel using background processes
if [ "$GITHUB_RUNNER_ENABLED" = true ] && [ "$GITEA_RUNNER_ENABLED" = true ]; then
  log "Both GitHub and Gitea runners are enabled. Starting both..."
  
  # Start GitHub runner in background
  (start_github_runner) &
  GITHUB_PID=$!
  
  # Start Gitea runner in background
  (start_gitea_runner) &
  GITEA_PID=$!
  
  # Wait for both processes
  wait $GITHUB_PID $GITEA_PID
  
elif [ "$GITHUB_RUNNER_ENABLED" = true ]; then
  start_github_runner
  
elif [ "$GITEA_RUNNER_ENABLED" = true ]; then
  start_gitea_runner
fi

log "Runner(s) stopped"
