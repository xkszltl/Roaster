#!/bin/bash

# ================================================================
# Pre-build Script
# ================================================================

# ----------------------------------------------------------------
# Create temporary directory for installation
# ----------------------------------------------------------------

[ "$INSTALL_PREFIX" ] || export INSTALL_PREFIX="/usr/local"
export INSTALL_ROOT="$(mktemp -dp . 'install.XXXXXXXXXX')/root"
mkdir -p "$INSTALL_ROOT"
export INSTALL_REL="$INSTALL_ROOT/$INSTALL_PREFIX"
mkdir -p "$INSTALL_REL"
export INSTALL_ABS=$(readlink -e "$INSTALL_REL")

# ----------------------------------------------------------------
# List file to exclude
# ----------------------------------------------------------------

rpm -q filesystem > /dev/null && rpm -ql filesystem > "$INSTALL_ROOT/../exclude.conf" &
