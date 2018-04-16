#!/bin/bash

# ================================================================
# Install Locally-built Package
# ================================================================

set -e

# ----------------------------------------------------------------
# Clean up install directory
# ----------------------------------------------------------------

rm -rf "$INSTALL_ABS"

# ----------------------------------------------------------------
# Identify package path
# ----------------------------------------------------------------

[ "$PKG_NAME" ] || export PKG_NAME="codingcafe-$(basename $(pwd))"

export PKG_PATH="$(find "$INSTALL_ROOT/.." -maxdepth 1 -type f -name "$PKG_NAME-*.rpm" | xargs readlink -e)"

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

rpm -qlp "$PKG_PATH"

# ----------------------------------------------------------------
# Install
# ----------------------------------------------------------------

if rpm -q "$PKG_NAME"; then
    export PKG_YUM_SEQ="update reinstall downgrade"
else
    export PKG_YUM_SEQ="install"
fi

for i in $PKG_YUM_SEQ _; do
    [ "$i" != '_' ]
    sudo yum "$i" -y "$PKG_PATH" && break
done
