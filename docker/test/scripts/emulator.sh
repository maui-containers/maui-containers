#!/usr/bin/bash
set -euo pipefail

export ANDROID_TOOL_PROCESS_RUNNER_LOG_PATH=/logs/androidsdktool.log

ADB="/home/mauiusr/.android/platform-tools/adb"
EMULATOR="/home/mauiusr/.android/emulator/emulator"

# Configurable via environment variables
EMULATOR_BOOT_TIMEOUT=${EMULATOR_BOOT_TIMEOUT:-600}
EMULATOR_PORT=${EMULATOR_PORT:-5554}
EMULATOR_WIPE_DATA=${EMULATOR_WIPE_DATA:-true}
EMULATOR_SNAPSHOT_MODE=${EMULATOR_SNAPSHOT_MODE:-none}
EMULATOR_EXTRA_ARGS=${EMULATOR_EXTRA_ARGS:-}
AVD_NAME=${AVD_NAME:-Emulator_${ANDROID_SDK_API_LEVEL}}
DISABLE_ANIMATIONS=${DISABLE_ANIMATIONS:-true}
DISABLE_SPELLCHECKER=${DISABLE_SPELLCHECKER:-false}
ENABLE_HW_KEYBOARD=${ENABLE_HW_KEYBOARD:-false}

# Readiness marker used by downstream services (Appium, healthcheck)
READY_FILE="/tmp/.emulator-ready"
rm -f "$READY_FILE"

echo "=== Emulator configuration ==="
echo "  AVD:                $AVD_NAME"
echo "  Port:               $EMULATOR_PORT"
echo "  Boot timeout:       ${EMULATOR_BOOT_TIMEOUT}s"
echo "  Wipe data:          $EMULATOR_WIPE_DATA"
echo "  Snapshot mode:      $EMULATOR_SNAPSHOT_MODE"
echo "  Disable animations: $DISABLE_ANIMATIONS"
echo "  Disable spellcheck: $DISABLE_SPELLCHECKER"
echo "  HW keyboard:        $ENABLE_HW_KEYBOARD"
echo "  Extra args:         $EMULATOR_EXTRA_ARGS"

# Permissions for KVM
sudo chown 1400:1401 /dev/kvm

# Restart adb to generate keys
$ADB kill-server
$ADB start-server

# Build emulator launch arguments
LAUNCH_ARGS="-avd $AVD_NAME -port $EMULATOR_PORT -grpc 8554 -gpu swiftshader_indirect -accel on -no-window -no-audio -no-boot-anim"

if [ "$EMULATOR_WIPE_DATA" = "true" ]; then
    LAUNCH_ARGS="$LAUNCH_ARGS -wipe-data"
fi

# Snapshot mode: none = disable load/save, load = load snapshot, save = save on exit, full = load+save
case "$EMULATOR_SNAPSHOT_MODE" in
    none)
        LAUNCH_ARGS="$LAUNCH_ARGS -no-snapshot-load -no-snapshot-save"
        ;;
    load)
        LAUNCH_ARGS="$LAUNCH_ARGS -no-snapshot-save"
        ;;
    save)
        LAUNCH_ARGS="$LAUNCH_ARGS -no-snapshot-load"
        ;;
    full)
        # Default snapshot behavior — load and save
        ;;
    *)
        echo "WARNING: Unknown EMULATOR_SNAPSHOT_MODE '$EMULATOR_SNAPSHOT_MODE', defaulting to none"
        LAUNCH_ARGS="$LAUNCH_ARGS -no-snapshot-load -no-snapshot-save"
        ;;
esac

if [ -n "$EMULATOR_EXTRA_ARGS" ]; then
    LAUNCH_ARGS="$LAUNCH_ARGS $EMULATOR_EXTRA_ARGS"
fi

echo "Starting emulator: $EMULATOR $LAUNCH_ARGS"
$EMULATOR $LAUNCH_ARGS &
EMULATOR_PID=$!

# Wait for emulator to boot by polling sys.boot_completed
echo "Waiting for emulator to boot (timeout: ${EMULATOR_BOOT_TIMEOUT}s)..."
BOOT_WAIT=0
RETRY_INTERVAL=2
BOOTED=false

while [ "$BOOT_WAIT" -lt "$EMULATOR_BOOT_TIMEOUT" ]; do
    RESULT=$($ADB -s emulator-${EMULATOR_PORT} shell getprop sys.boot_completed 2>/dev/null || true)
    if [ "$(echo "$RESULT" | tr -d '[:space:]')" = "1" ]; then
        BOOTED=true
        break
    fi
    sleep $RETRY_INTERVAL
    BOOT_WAIT=$((BOOT_WAIT + RETRY_INTERVAL))
    if [ $((BOOT_WAIT % 30)) -eq 0 ]; then
        echo "  Still waiting... ${BOOT_WAIT}s elapsed"
    fi
done

if [ "$BOOTED" != "true" ]; then
    echo "ERROR: Emulator failed to boot within ${EMULATOR_BOOT_TIMEOUT}s"
    exit 1
fi

echo "Emulator booted successfully in ~${BOOT_WAIT}s"

# Unlock screen
$ADB -s emulator-${EMULATOR_PORT} shell input keyevent 82 || true

# Post-boot device tuning (inspired by ReactiveCircus/android-emulator-runner)
if [ "$DISABLE_ANIMATIONS" = "true" ]; then
    echo "Disabling animations..."
    $ADB -s emulator-${EMULATOR_PORT} shell settings put global window_animation_scale 0.0 || true
    $ADB -s emulator-${EMULATOR_PORT} shell settings put global transition_animation_scale 0.0 || true
    $ADB -s emulator-${EMULATOR_PORT} shell settings put global animator_duration_scale 0.0 || true
fi

if [ "$DISABLE_SPELLCHECKER" = "true" ]; then
    echo "Disabling spellchecker..."
    $ADB -s emulator-${EMULATOR_PORT} shell settings put secure spell_checker_enabled 0 || true
fi

if [ "$ENABLE_HW_KEYBOARD" = "true" ]; then
    echo "Suppressing IME with hardware keyboard..."
    $ADB -s emulator-${EMULATOR_PORT} shell settings put secure show_ime_with_hard_keyboard 0 || true
fi

# Execute optional post-boot hook
POST_BOOT_SCRIPT=${POST_BOOT_SCRIPT:-}
if [ -n "$POST_BOOT_SCRIPT" ] && [ -f "$POST_BOOT_SCRIPT" ]; then
    echo "Running post-boot script: $POST_BOOT_SCRIPT"
    /usr/bin/bash "$POST_BOOT_SCRIPT"
fi

# Signal readiness
touch "$READY_FILE"
echo "Emulator is ready — signalled downstream services"

# Keep foreground so supervisord can manage the process
wait $EMULATOR_PID