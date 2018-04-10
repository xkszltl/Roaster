#!/bin/bash

# ================================================================
# Daemon to ping sudo before timeout
#   - Quit after disowned within weakly guranteed SLA.
# ================================================================

set -e

export SUDO_PING_HEARTBEAT_SEC=5
export SUDO_PING_SLA_SEC=1

# Store PID of biological parent for suicide as orphan.
export PPID_BIO="$PPID"

if [ ! "$PPID_BIO" ]; then
	echo "Failed to retrieve \$PPID."
	echo "    Check your shell configuration."
	echo "    Using \"$SHELL\" currently"
	exit 1
fi

if [ "$PPID_BIO" -le 1 ]; then
	echo "Refuse to start as a direct child of process $PPID_BIO."
	exit 1
fi

# ----------------------------------------------------------------

sudo -llp "
----------------------------------------------------------------
 We would like to pre-activate a sudo session.
 Please provide your password.
 Session may still timeout, depending on system configuration.
 You will be asked for password again at that time.
----------------------------------------------------------------
[sudo] password for $(whoami): "

# ----------------------------------------------------------------

while [ "$(eval 'echo $PPID')" -eq "$PPID_BIO" ]; do
    DDL="$(expr "$(date +%s)" + "$SUDO_PING_HEARTBEAT_SEC" - "$SUDO_PING_SLA_SEC")"
    sudo -v
    while [ "$(eval 'echo $PPID')" -eq "$PPID_BIO" ] && [ "$(date +%s)" -lt "$DDL" ]; do
    	sleep "$SUDO_PING_SLA_SEC"
    done
done
