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
export INSTALL_ROOT="$(readlink -e "$INSTALL_ROOT")"

# ----------------------------------------------------------------
# List file to exclude
# ----------------------------------------------------------------

rpm -q filesystem > /dev/null && rpm -ql filesystem | sed 's/^\///' | sed 's/$/\//' > "$INSTALL_ROOT/../exclude.conf" &

# ----------------------------------------------------------------
# Copy source code
# ----------------------------------------------------------------

mkdir -p "$INSTALL_ABS/src/$(basename "$(pwd)")"

ls -A -I".git" -I"$(basename "$(dirname "$INSTALL_ROOT")")" \
| xargs cp --reflink=auto -aft "$INSTALL_ABS/src/$(basename "$(pwd)")/"
