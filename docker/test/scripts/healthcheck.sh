#!/usr/bin/bash
# Lightweight healthcheck: emulator booted + Appium listening.
# Used by HEALTHCHECK in Dockerfile and external orchestrators.

ADB="/home/mauiusr/.android/platform-tools/adb"
EMULATOR_PORT=${EMULATOR_PORT:-5554}
APPIUM_PORT=${APPIUM_PORT:-4723}

# 1. Emulator must report boot completed
BOOT=$($ADB -s emulator-${EMULATOR_PORT} shell getprop sys.boot_completed 2>/dev/null || true)
if [ "$(echo "$BOOT" | tr -d '[:space:]')" != "1" ]; then
    exit 1
fi

# 2. Appium /status must respond
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${APPIUM_PORT}/status" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "200" ]; then
    exit 1
fi

exit 0
