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
# Add fpm hook directory.
# ----------------------------------------------------------------

mkdir -p "$INSTALL_ROOT/../fpm"

# ----------------------------------------------------------------
# List file to exclude
# ----------------------------------------------------------------

touch "$INSTALL_ROOT/../fpm/exclude.conf"
case "$DISTRO_ID" in
"centos" | "fedora" | "rhel")
    (
        set -e
        for i in filesystem; do
            # Too many files in "/usr/share/{locale,man}" (~14k currently) causes performance issue.
            # See https://github.com/jordansissel/fpm/issues/1674
            rpm -q "$i" > /dev/null && rpm -ql "$i" \
            | grep -v '^/usr/share/locale/*[^/]'    \
            | grep -v '^/usr/share/man/*[^/]'       \
            | sed 's/^\///'                         \
            | sed 's/$/\//'                         \
            >> "$INSTALL_ROOT/../fpm/exclude.conf"
        done
    ) &
    ;;
esac

# ----------------------------------------------------------------
# Copy source code
# ----------------------------------------------------------------

mkdir -p "$INSTALL_ABS/src/$(basename "$(pwd)")"

(
    set +xe
    case "$DISTRO_ID" in
    "centos" | "fedora" | "rhel")
        . scl_source enable rh-git218 || exit 1
        ;;
    esac
    set -xe
    git gc --aggressive --force
)

ls -A -I"$(basename "$(dirname "$INSTALL_ROOT")")" \
| xargs cp --reflink=auto -aft "$INSTALL_ABS/src/$(basename "$(pwd)")/"
