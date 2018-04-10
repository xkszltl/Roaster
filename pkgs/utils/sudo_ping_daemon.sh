#!/bin/bash

# ================================================================
# Daemon to ping sudo before timeout
#   - Quit after disowned within weakly guranteed SLA.
# ================================================================

set -e

export SUDO_PING_HEARTBEAT_SEC=5
export SUDO_PING_SLA_SEC=1

if [ $PPID -le 1 ]; then
	echo "Refuse to start as a direct child of process $PPID."
	exit 1
fi

PID="$("$SHELL" -c 'echo $PPID' | xargs ps -o ppid= -p)"

# ----------------------------------------------------------------

while [ $(ps -o ppid= -p "$PID") -eq $PPID ]; do
    DDL="$(expr "$(date +%s)" + "$SUDO_PING_HEARTBEAT_SEC" - "$SUDO_PING_SLA_SEC")"
    sudo -v
    while [ $(ps -o ppid= -p "$PID") -eq $PPID ] && [ "$(date +%s)" -lt "$DDL" ]; do
    	sleep "$SUDO_PING_SLA_SEC"
    done
done
