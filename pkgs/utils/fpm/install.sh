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
"centos" | "fedora" | "rhel" | 'scientific')
    export PKG_TYPE='rpm'
    ;;
"debian" | "ubuntu")
    export PKG_TYPE='deb'
    ;;
*)
    export PKG_TYPE='sh'
    ;;
esac

export PKG_PATH="$(find "$INSTALL_ROOT/.." -maxdepth 1 -type f -name "$PKG_NAME[\\-_]*.$PKG_TYPE" | xargs realpath -e)"

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

# Note:
#   - yum/dnf skip install with exit code 0 when package with the same version exist.
#   - apt-get install regardless in this case.
#   - apt-get does not have reinstall command.
case "$PKG_TYPE" in
"rpm")
    PKG_YUM_SEQ="reinstall install downgrade update"
    rpm -q "$PKG_NAME" || PKG_YUM_SEQ="install"
    PKG_YUM_CMD="$(which dnf >/dev/null 2>&1 && echo 'dnf' || echo 'yum')"

    # Remove legacy.
    sudo "$PKG_YUM_CMD" remove -y "$(sed 's/^[^\-]*\-/codingcafe\-/' <<< "$PKG_NAME")" || true

    for i in $PKG_YUM_SEQ _; do
        [ "$i" != '_' ]
        echo "[INFO] Trying with \"$PKG_YUM_CMD $i\"."
        sudo "$PKG_YUM_CMD" "$i" -y "$PKG_PATH" && break
        echo "[INFO] Does not succeed with \"$PKG_YUM_CMD $i\"."
    done
    ;;
"deb")
    PKG_APT_SEQ="install reinstall upgrade"

    # Remove legacy.
    sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y "$(sed 's/^[^\-]\-/codingcafe\-/' <<< "$PKG_NAME")" || true

    for i in $PKG_APT_SEQ _; do
        [ "$i" != '_' ]
        echo "[INFO] Trying with \"apt-get $i\"."
        if [ "$i" = "reinstall" ]; then
            sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y "$PKG_NAME" && sudo apt-get install -y "$PKG_PATH" && break
        else
            sudo DEBIAN_FRONTEND=noninteractive apt-get "$i" -y "$PKG_PATH" && break
        fi
        echo "[INFO] Does not succeed with \"apt-get $i\"."
    done
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -fy
    ;;
esac
# ----------------------------------------------------------------
# Publish
# ----------------------------------------------------------------

export RPM_PUB_DIR='/var/www/repos/codingcafe'

if [ -d "$RPM_PUB_DIR" ]; then
    pushd "$RPM_PUB_DIR"
    sudo mkdir -p "rhel$DISTRO_VERSION_ID/$(uname -m)"
    pushd "$_"
    find . -maxdepth 1 -name "$PKG_NAME-*" -type f | xargs sudo rm -f
    sudo install -m664 -t . "$PKG_PATH"
    popd
    popd
fi

