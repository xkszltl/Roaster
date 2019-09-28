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

[ "$PKG_NAME" ] || export PKG_NAME="roaster-$(basename $(pwd) | tr '[:upper:]' '[:lower:]')"

case "$DISTRO_ID" in
"centos" | "fedora" | "rhel")
    export PKG_TYPE=rpm
    ;;
"debian" | "ubuntu")
    export PKG_TYPE=deb
    ;;
*)
    export PKG_TYPE=sh
    ;;
esac

export PKG_PATH="$(find "$INSTALL_ROOT/.." -maxdepth 1 -type f -name "$PKG_NAME[\\-_]*.$PKG_TYPE" | xargs readlink -e)"

if [ ! "$PKG_PATH" ]; then
    echo "[ERROR] No package file found for \"$PKG_NAME\"."
    echo "[ERROR]     Might have error occured during packaging."
    exit 1
elif [ $(wc -l <<<"$PKG_NAME") -gt 1 ]; then
    echo "[ERROR] Multiple candidates detected:"
    sed 's/^/[ERROR]     /' <<<"$PKG_PATH"
    echo "[ERROR] Please update the search condition to narrow it down."
    exit 1
fi

echo '----------------------------------------------------------------'
echo " Package Summary"
echo '----------------------------------------------------------------'

case "$PKG_TYPE" in
"rpm")
    rpm -qlp "$PKG_PATH" | sed 's/^/     /'
    ;;
"deb")
    dpkg -c "$PKG_PATH" | sed 's/^/     /'
    ;;
esac

echo '----------------------------------------------------------------'
ls -lh "$PKG_PATH" | sed 's/^/     /'
echo '----------------------------------------------------------------'

# ----------------------------------------------------------------
# Install
# ----------------------------------------------------------------

case "$PKG_TYPE" in
"rpm")
    PKG_YUM_SEQ="install reinstall downgrade update"
    rpm -q "$PKG_NAME" || PKG_YUM_SEQ="install"

    # Remove legacy.
    sudo yum remove -y "$(sed 's/^[^\-]*\-/codingcafe\-/' <<< "$PKG_NAME")" || true

    for i in $PKG_YUM_SEQ _; do
        [ "$i" != '_' ]
        echo "[INFO] Trying with \"yum $i\"."
        if [ "$i" = "reinstall" ]; then
            sudo yum remove -y "$PKG_NAME" && sudo yum install -y "$PKG_PATH" && break
        else
            sudo yum "$i" -y "$PKG_PATH" && break
        fi
        echo "[INFO] Does not succeed with \"yum $i\"."
    done
    ;;
"deb")
    PKG_APT_SEQ="install reinstall upgrade"

    # Remove legacy.
    sudo apt-get remove -y "$(sed 's/^[^\-]\-/codingcafe\-/' <<< "$PKG_NAME")" || true

    for i in $PKG_APT_SEQ _; do
        [ "$i" != '_' ]
        echo "[INFO] Trying with \"apt-get $i\"."
        if [ "$i" = "reinstall" ]; then
            sudo apt-get remove -y "$PKG_NAME" && sudo apt-get install -y "$PKG_PATH" && break
        else
            sudo apt-get "$i" -y "$PKG_PATH" && break
        fi
        echo "[INFO] Does not succeed with \"apt-get $i\"."
    done
    sudo apt-get install -fy
    ;;
esac
# ----------------------------------------------------------------
# Publish
# ----------------------------------------------------------------

export RPM_PUB_DIR='/var/www/repos/codingcafe'

if [ -d "$RPM_PUB_DIR" ]; then
    pushd "$RPM_PUB_DIR"
    sudo mkdir -p "rhel$DISTRO_VERSION_ID/$(uname -i)"
    pushd "$_"
    find . -maxdepth 1 -name "$PKG_NAME-*" -type f | xargs sudo rm -f
    sudo install -m664 -t . "$PKG_PATH"
    popd
    popd
fi

