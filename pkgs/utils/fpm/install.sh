#!/bin/bash

# ================================================================
# Install Local-Built Package
# ================================================================

set -e

# ----------------------------------------------------------------
# Clean up install directory
# ----------------------------------------------------------------

rm -rf "$INSTALL_ABS" &

# ----------------------------------------------------------------
# Identify package path
# ----------------------------------------------------------------

[ "$PKG_NAME" ] || export PKG_NAME="codingcafe-$(basename $(pwd))"

export PKG_PATH="$(find . -maxdepth 1 -type f -name "$PKG_NAME-*.rpm" | xargs readlink -e)"

if [ ! "$PKG_PATH" ]; then
    echo "No package file found for \"$PKG_NAME\"."
    echo "    Might have error occured during packaging."
    exit 1
elif [ $(wc -l <<<"$PKG_NAME") -gt 1 ]; then
    echo "Multiple candidates detected:"
    sed 's/^/    /' <<<"$PKG_PATH"
    echo "Please update the search condition to narrow it down."
    exit 1
fi

# ----------------------------------------------------------------
# Install
# ----------------------------------------------------------------

if rpm -q "$PKG_NAME"; then
    sudo yum reinstall -y "$PKG_PATH" || sudo yum update -y "$PKG_PATH" || sudo yum downgrade -y "$PKG_PATH"
else
    sudo yum install -y "$PKG_PATH"
fi

# ----------------------------------------------------------------
# Wait for clean up
# ----------------------------------------------------------------

wait
