#!/bin/bash
# Entrypoint script for MAUI Linux container
# Starts runners in background, then executes the CMD

set -e

echo "MAUI Image - Linux Container"
echo "============================"

# Run custom init script if provided
if [ -f "$INIT_BASH_SCRIPT" ]; then
  echo "Running custom bash init script: $INIT_BASH_SCRIPT"
  bash "$INIT_BASH_SCRIPT"
fi

if [ -f "$INIT_PWSH_SCRIPT" ]; then
  echo "Running custom PowerShell init script: $INIT_PWSH_SCRIPT"
  pwsh "$INIT_PWSH_SCRIPT"
fi

# Start runner script in background
echo "Starting runner management in background..."
/usr/bin/bash /home/mauiusr/runner.sh &

# Execute whatever CMD was provided (or default)
echo "Executing CMD: $@"
exec "$@"
