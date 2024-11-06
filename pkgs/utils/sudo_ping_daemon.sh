#!/bin/bash

# ================================================================
# Daemon to ping sudo before timeout
#   - Quit after disowned within weakly guranteed SLA.
# ================================================================

export SUDO_PING_HEARTBEAT_SEC=5
export SUDO_PING_SLA_SEC=1

if [ ! "$PPID" ] || ! printf '%s\n' "$PPID" | grep -q '^[0-9][0-9]*$'; then
    printf '\033[31[ERROR] Invalid parent pid "%s".\033[0m\n' "$PPID" >&2
    exit 1
fi
if [ "$PPID" -le 1 ]; then
    printf '\033[31[ERROR] Refuse to start as a direct child of process %s.\033[0m\n' "$PPID" >&2
    exit 1
fi

# ----------------------------------------------------------------

export SUDO_PING_PID="$('/bin/sh' -c 'echo "$PPID"' | xargs -r ps -o ppid= -p | sed 's/[[:space:]]//g')"
# Assert numerical
if [ ! "$SUDO_PING_PID" ] || ! printf '%s\n' "$SUDO_PING_PID" | grep -q '^[0-9][0-9]*$'; then
    printf '\033[31m[ERROR] Non-numerical $SUDO_PING_PID "%s".\033[0m\n' "$SUDO_PING_PID" >&2
    exit 1
fi

# Assert consistent
if [ "$BASHPID" ]; then
    if [ "$(sed 's/[0-9]//g' <<< "$BASHPID")" ]; then
        printf '\033[31m[ERROR] Non-numerical $BASHPID "%s".\033[0m\n' "$BASHPID" >&2
        exit 1
    fi
    if [ "_$SUDO_PING_PID" != "_$BASHPID" ]; then
        printf '\033[31m[ERROR] Inconsistent $SUDO_PING_PID (%s) vs. $BASHPID (%s).\033[0m\n' "$SUDO_PING_PID" "$BASHPID" >&2
        exit 1
    fi
fi

printf '\033[36m[INFO] Daemon sudo_ping is monitoring process %s for zombie.\033[0m\n' "$SUDO_PING_PID" >&2

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

    [ 'Silent termination' ] || printf '\033[36m[INFO] sudo_ping deamon quit automatically (Reason: zombie)\033[0m.\n' >&2
) &
