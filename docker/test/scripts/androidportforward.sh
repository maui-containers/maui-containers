#!/usr/bin/bash

EMULATOR_PORT=${EMULATOR_PORT:-5554}
ADB_PORT=$((EMULATOR_PORT + 1))

# Get the local IP address
local_ip=$(hostname -I | awk '{print $1}')

# Forward the ports for adb/emulator so we can connect from the host
/usr/bin/socat tcp-listen:${EMULATOR_PORT},bind=${local_ip},fork tcp:127.0.0.1:${EMULATOR_PORT} &
/usr/bin/socat tcp-listen:${ADB_PORT},bind=${local_ip},fork tcp:127.0.0.1:${ADB_PORT}
