#!/usr/bin/bash

INIT_PWSH_SCRIPT=${INIT_PWSH_SCRIPT:-""}
INIT_BASH_SCRIPT=${INIT_BASH_SCRIPT:-""}
PRE_EMULATOR_LAUNCH_SCRIPT=${PRE_EMULATOR_LAUNCH_SCRIPT:-""}

echo "init.sh checking for scripts..."

# Check for and execute initialization scripts if they exist
if [ -f "$INIT_BASH_SCRIPT" ]; then
  echo "Found initialization script at $INIT_BASH_SCRIPT, executing..."
  /usr/bin/bash "$INIT_BASH_SCRIPT"
  echo "Initialization script executed successfully."
fi

if [ -f "$INIT_PWSH_SCRIPT" ]; then
  echo "Found initialization script at $INIT_PWSH_SCRIPT, executing..."
  /usr/bin/pwsh "$INIT_PWSH_SCRIPT"
  echo "Initialization script executed successfully."
fi

# Run pre-emulator-launch script (runs after init but before the emulator starts)
if [ -n "$PRE_EMULATOR_LAUNCH_SCRIPT" ] && [ -f "$PRE_EMULATOR_LAUNCH_SCRIPT" ]; then
  echo "Found pre-emulator-launch script at $PRE_EMULATOR_LAUNCH_SCRIPT, executing..."
  /usr/bin/bash "$PRE_EMULATOR_LAUNCH_SCRIPT"
  echo "Pre-emulator-launch script executed successfully."
fi

echo "init.sh script executed successfully."