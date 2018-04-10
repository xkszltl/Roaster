#!/bin/bash

# ================================================================
# Daemon to ping sudo before timeout
#   - Quit after disowned within weakly guranteed SLA.
# ================================================================

export SUDO_PING_HEARTBEAT_SEC=5
export SUDO_PING_SLA_SEC=1

if [ $PPID -le 1 ]; then
	echo "Refuse to start as a direct child of process $PPID."
	exit 1
fi

SUDO_PING_PID="$("$SHELL" -c 'echo $PPID' | xargs ps -o ppid= -p)"

# ----------------------------------------------------------------

while [ $(ps -o ppid= -p "$SUDO_PING_PID") -eq $PPID ]; do
    SUDO_PING_DDL="$(expr "$(date +%s)" + "$SUDO_PING_HEARTBEAT_SEC" - "$SUDO_PING_SLA_SEC")"
    sudo -v
    while [ $(ps -o ppid= -p "$SUDO_PING_PID") -eq $PPID ] && [ "$(date +%s)" -lt "$SUDO_PING_DDL" ]; do
    	sleep "$SUDO_PING_SLA_SEC"
    done
done &
