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

# ----------------------------------------------------------------

export SUDO_PING_PID="$("$SHELL" -c 'echo $PPID' | xargs ps -o ppid= -p | sed 's/[[:space:]]//g')"
# Assert numerical
    if [ ! "$SUDO_PING_PID" ] || [ "$(sed 's/[0-9]//g' <<< "$SUDO_PING_PID")" ]; then
    echo "[ERROR] Non-numerical \$SUDO_PING_PID \"$SUDO_PING_PID\"."
    exit 1
fi

# Assert consistent
if [ "$BASHPID" ]; then
    if [ "$(sed 's/[0-9]//g' <<< "$BASHPID")" ]; then
        echo "[ERROR] Non-numerical \$BASHPID \"$BASHPID\"."
        exit 1
    fi
    if [ "_$SUDO_PING_PID" != "_$BASHPID" ]; then
        echo "[ERROR] Inconsistent \$SUDO_PING_PID vs. \$BASHPID \"$SUDO_PING_PID\" != \"$BASHPID\"."
        exit 1
    fi
fi

echo "Daemon sudo_ping is monitoring process $SUDO_PING_PID for zombie."

(
    set -e

    # Append '0' because ps may not be able to found the process itself as zombie.
    while [ "_$(ps -o ppid= -p "$SUDO_PING_PID" | sed 's/[[:space:]]//g')" = "_$PPID" ]; do
        SUDO_PING_DDL="$(expr "$(date +%s)" + "$SUDO_PING_HEARTBEAT_SEC" - "$SUDO_PING_SLA_SEC")"
        sudo -n true || SUDO_PING_DDL="$(expr "$(date +%s)" + "$SUDO_PING_SLA_SEC")"
        while [ "_$(ps -o ppid= -p "$SUDO_PING_PID" | sed 's/[[:space:]]//g')" = "_$PPID" ] && [ "$(date +%s)" -lt "$SUDO_PING_DDL" ]; do
    	    sleep "$SUDO_PING_SLA_SEC"
        done
    done

    echo '[INFO] sudo_ping deamon quit automatically (Reason: zombie)'
) &
