#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[bootstrap] $*"
  logger -t "maui-bootstrap" "$*"
}

log "Starting MAUI VM bootstrap initialization"

# Standard location for user-provided configuration
CONFIG_DIR="/Volumes/My Shared Files/config"
INIT_SCRIPT="${CONFIG_DIR}/init.sh"

# Run custom initialization script if provided
if [[ -f "${INIT_SCRIPT}" ]]; then
  log "Found custom init script at ${INIT_SCRIPT}"
  log "Executing custom initialization script"

  chmod +x "${INIT_SCRIPT}"

  if /bin/bash "${INIT_SCRIPT}"; then
    log "Custom init script completed successfully"
  else
    log "WARNING: Custom init script exited with error code $?"
  fi
else
  log "No custom init script found at ${INIT_SCRIPT}"
fi

log "Bootstrap initialization complete"

exit 0
