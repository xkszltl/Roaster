#!/bin/bash

set -e

if [ ! "$ROOT_DIR" ]; then
    echo '$ROOT_DIR is not defined.'
    echo 'Running in standalone mode.'
    export ROOT_DIR="$(readlink -e "$(dirname "$0")")"
    until [ -x "$ROOT_DIR/setup.sh" ] && [ -d "$ROOT_DIR/pkgs" ]; do export ROOT_DIR=$(readlink -e "$ROOT_DIR/.."); done
    [ "_$ROOT_DIR" != "_$(readlink -f "$ROOT_DIR/..")" ]
    echo 'Set $ROOT_DIR to "'"$ROOT_DIR"'".'
fi

for i in pypa/setuptools,v pypa/{pip,wheel} $@; do
    PKG="$(basename "$(cut -d, -f1 <<< "$i,")")"
    . "$ROOT_DIR/pkgs/utils/git/version.sh" "$i"
    URL="git+$GIT_REPO@$GIT_TAG"
    if grep 'pypa/setuptools' <<< "$i" > /dev/null; then
        echo "Cannot build $PKG from source. Install it from wheel instead."
        URL="$PKG"
    fi
    if grep '/protobuf' <<< "$i" > /dev/null; then
        echo "Cannot build $PKG from source. Install it from wheel instead."
        URL="$PKG"
    fi
    for py in $(which python{,3}); do
        # Not exactly correct since the actual package name is defined by "setup.py".
        if [ "_$("$py" -m pip freeze --all | tr '[:upper:]' '[:lower:]' | sed -n "s/^$(tr '[:upper:]' '[:lower:]' <<< "$PKG")==//p")" = "_$GIT_TAG_VER" ]; then
            echo "Package \"$PKG\" for \"$py\" is already up-to-date ($GIT_TAG_VER). Skip."
            continue
        fi
        sudo "$py" -m pip install -U "$URL" || sudo "$py" -m pip install -IU "$URL"
    done
done
