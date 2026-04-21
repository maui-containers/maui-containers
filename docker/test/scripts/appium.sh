#!/usr/bin/bash
set -euo pipefail

READY_FILE="/tmp/.emulator-ready"
APPIUM_LOG_LEVEL=${APPIUM_LOG_LEVEL:-debug}
APPIUM_PORT=${APPIUM_PORT:-4723}

echo "Waiting for emulator readiness before starting Appium..."

# Wait for the emulator ready signal with a reasonable timeout
WAIT=0
TIMEOUT=660
while [ ! -f "$READY_FILE" ] && [ "$WAIT" -lt "$TIMEOUT" ]; do
    sleep 2
    WAIT=$((WAIT + 2))
    if [ $((WAIT % 30)) -eq 0 ]; then
        echo "  Appium waiting for emulator... ${WAIT}s elapsed"
    fi
done

if [ ! -f "$READY_FILE" ]; then
    echo "ERROR: Emulator never became ready after ${TIMEOUT}s — not starting Appium"
    exit 1
fi

echo "Emulator is ready — starting Appium on port $APPIUM_PORT"

exec appium \
  --session-override \
  --log-level "$APPIUM_LOG_LEVEL" \
  --log-timestamp \
  --port "$APPIUM_PORT" \
  --allow-insecure *:chromedriver_autodownload